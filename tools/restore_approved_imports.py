#!/usr/bin/env python3
"""Restore the existing pinned resources without changing their authority.

Run with Godot closed. --check reads and verifies the full input set without
writing. A normal restore stages and verifies every output before installing
anything. Each replacement is atomic; an OS error partway through installation
can leave a mixture of complete old/new files. Fix the error and rerun.
"""

import argparse
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
import tempfile


class RestoreError(ValueError):
    """A bad manifest, unsafe path, or invalid asset stops restoration."""


@dataclass(frozen=True)
class Part:
    path: str
    sha256: str


@dataclass(frozen=True)
class Asset:
    destination: str
    sha256: str
    parts: tuple


def relative(value):
    if not isinstance(value, str) or not value or "\\" in value or ":" in value:
        raise RestoreError("Expected a project-relative POSIX path")
    path = PurePosixPath(value)
    if path.is_absolute() or any(p in ("", ".", "..") for p in value.split("/")):
        raise RestoreError("Unsafe path: " + value)
    # These characters are not usable in Windows checkout paths either.
    if any(ord(c) < 32 or c in '<>"|?*' for c in value):
        raise RestoreError("Unsupported path: " + value)
    return value


def checked_path(root, name):
    """Reject symlinks in inputs and outputs, including existing parents."""
    path = root
    for component in relative(name).split("/"):
        path = path / component
        if path.is_symlink():
            raise RestoreError("Symlink is not allowed: " + name)
    return path


def digest(value):
    if not isinstance(value, str) or re.fullmatch(r"[0-9a-f]{64}", value) is None:
        raise RestoreError("Expected a lowercase SHA-256 digest")
    return value


def read_manifest(root, name):
    data = json.loads(checked_path(root, name).read_text(encoding="utf-8"))
    if not isinstance(data, list) or not data:
        raise RestoreError("Expected a nonempty manifest array: " + name)
    return data


def record(item, fields):
    if not isinstance(item, dict) or set(item) != set(fields):
        raise RestoreError("Unexpected manifest record fields")
    return item


def plan_restore(root):
    assets = []
    for directory, imported in (("approved-runtime-imports", True),
                                ("approved-import-metadata", False)):
        prefix = "vendor/" + directory + "/"
        for item in read_manifest(root, prefix + "manifest.json"):
            record(item, ("path", "sha256"))
            name, sha = relative(item["path"]), digest(item["sha256"])
            if imported:
                if "/" in name:
                    raise RestoreError("Pinned runtime imports must be filenames")
                destination = ".godot/imported/" + name
            else:
                if not name.startswith(("assets/", "models/")) or not name.endswith(".import"):
                    raise RestoreError("Unexpected import descriptor destination: " + name)
                destination = name
            assets.append(Asset(destination, sha, (Part(prefix + name, sha),)))

    for item in read_manifest(root, "vendor/large-assets/manifest.json"):
        record(item, ("destination", "sha256", "parts"))
        name, sha = relative(item["destination"]), digest(item["sha256"])
        if not name.startswith(("assets/", "models/")):
            raise RestoreError("Unexpected large asset destination: " + name)
        if not isinstance(item["parts"], list) or not item["parts"]:
            raise RestoreError("Large asset has no parts: " + name)
        parts = []
        for part in item["parts"]:
            record(part, ("path", "sha256"))
            source = relative(part["path"])
            if not source.startswith("vendor/large-assets/"):
                raise RestoreError("Unexpected chunk source: " + source)
            parts.append(Part(source, digest(part["sha256"])))
        if len({part.path.casefold() for part in parts}) != len(parts):
            raise RestoreError("Duplicate chunk source: " + name)
        assets.append(Asset(name, sha, tuple(parts)))

    destinations = set()
    for asset in assets:
        key = asset.destination.casefold()
        if key in destinations:
            raise RestoreError("Duplicate destination: " + asset.destination)
        destinations.add(key)
        target = checked_path(root, asset.destination)
        if target.exists() and not target.is_file():
            raise RestoreError("Destination is not a regular file: " + asset.destination)
        # Reject a regular file used as a destination parent before any writes.
        for parent in target.parents:
            if parent == root:
                break
            if parent.exists() and not parent.is_dir():
                raise RestoreError("Destination parent is not a directory: " + str(parent))
        for part in asset.parts:
            if not checked_path(root, part.path).is_file():
                raise RestoreError("Missing input: " + part.path)
    return assets


def verify_asset(root, asset, output=None):
    whole = hashlib.sha256()
    size = 0
    for part in asset.parts:
        chunk_hash = hashlib.sha256()
        with checked_path(root, part.path).open("rb") as source:
            while block := source.read(1024 * 1024):
                chunk_hash.update(block)
                whole.update(block)
                size += len(block)
                if output is not None:
                    output.write(block)
        if chunk_hash.hexdigest() != part.sha256:
            raise RestoreError("Input SHA-256 mismatch: " + part.path)
    if whole.hexdigest() != asset.sha256:
        raise RestoreError("Assembled SHA-256 mismatch: " + asset.destination)
    return size


def file_digest(path):
    h = hashlib.sha256()
    with path.open("rb") as source:
        while block := source.read(1024 * 1024):
            h.update(block)
    return h.hexdigest()


def restore(root, check=False):
    root = Path(root).resolve(strict=True)
    assets = plan_restore(root)
    if check:
        total = sum(verify_asset(root, asset) for asset in assets)
        return {"mode": "check", "verified_files": len(assets),
                "verified_bytes": total, "installed": 0}

    # Stage under the project, not the user's system temporary volume, so
    # replacements use the same filesystem in a normal checkout.
    installed = unchanged = total = 0
    phase = "creating temporary staging files"
    try:
        with tempfile.TemporaryDirectory(prefix=".settlement-restore-", dir=root) as work:
            phase = "staging verified assets"
            staged = []
            for index, asset in enumerate(assets):
                temporary = Path(work) / str(index)
                with temporary.open("xb") as output:
                    total += verify_asset(root, asset, output)
                # Read staged bytes back before publishing any destination.
                if file_digest(temporary) != asset.sha256:
                    raise RestoreError("Staged SHA-256 mismatch: " + asset.destination)
                staged.append((asset, temporary))

            for asset, temporary in staged:
                try:
                    destination = checked_path(root, asset.destination)
                    if destination.is_file() and file_digest(destination) == asset.sha256:
                        unchanged += 1
                        continue
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    checked_path(root, asset.destination)
                    os.replace(temporary, destination)
                    installed += 1
                except (OSError, RestoreError) as error:
                    raise RestoreError(
                        f"Installation stopped at {asset.destination} after {installed} "
                        "complete replacements. No partial file was published; this is "
                        "not a whole-project rollback. Close Godot, resolve the error, "
                        f"and rerun. Cause: {error}"
                    ) from error
            phase = "cleaning temporary staging files"
    except OSError as error:
        raise RestoreError(
            f"Restore stopped while {phase}, after {installed} complete replacements "
            f"and {unchanged} unchanged files. Resolve the filesystem error and "
            f"rerun; no whole-project rollback is implied. Cause: {error}"
        ) from error
    return {"mode": "restore", "verified_files": len(assets),
            "verified_bytes": total, "installed": installed, "unchanged": unchanged}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--check", action="store_true", help="Verify all inputs without writing")
    args = parser.parse_args()
    try:
        result = restore(args.project, args.check)
    except (OSError, ValueError) as error:
        print("Restore refused: " + str(error), file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
