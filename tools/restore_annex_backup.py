#!/usr/bin/env python3
"""Reconstruct exact Research Annex assets from the lossless backup parts.

Run before importing Godot. --check validates without writing. Existing files
are accepted only when their bytes match; differing files are never overwritten.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def checked_path(name):
    relative = PurePosixPath(name)
    if relative.is_absolute() or not relative.parts or ".." in relative.parts:
        raise ValueError("Unsafe manifest path: " + name)
    path = ROOT.joinpath(*relative.parts)
    try:
        path.resolve().relative_to(ROOT)
    except ValueError:
        raise ValueError("Path leaves the checkout: " + name)
    return path


def digest(path):
    result = hashlib.sha256()
    size = 0
    with path.open("rb") as source:
        for data in iter(lambda: source.read(1024 * 1024), b""):
            size += len(data)
            result.update(data)
    return size, result.hexdigest()


def verify(path, record):
    if digest(path) != (record["size"], record["sha256"]):
        raise ValueError("Size or SHA-256 mismatch: " + str(path.relative_to(ROOT)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify without creating files")
    args = parser.parse_args()
    manifest = json.loads((ROOT / "ANNEX-BACKUP-MANIFEST.json").read_text())
    if manifest.get("schema") != 1:
        raise ValueError("Unsupported Annex backup manifest")
    records = manifest["chunked_files"]
    # Validate every source part and existing destination before making changes.
    for record in records:
        target = checked_path(record["path"])
        for part in record["parts"]:
            verify(checked_path(part["path"]), part)
        if target.exists():
            verify(target, record)
        elif args.check:
            raise ValueError("Missing reconstructed file: " + record["path"])
    for record in records:
        target = checked_path(record["path"])
        if target.exists():
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        staging = None
        try:
            with tempfile.NamedTemporaryFile(dir=target.parent, prefix=".annex-restore-", delete=False) as output:
                staging = Path(output.name)
                for part in record["parts"]:
                    with checked_path(part["path"]).open("rb") as source:
                        for data in iter(lambda: source.read(1024 * 1024), b""):
                            output.write(data)
                output.flush()
                os.fsync(output.fileno())
            verify(staging, record)
            # Atomic create-if-absent: never replace a file another writer made.
            os.link(staging, target)
        finally:
            if staging is not None:
                staging.unlink(missing_ok=True)
        verify(target, record)
        print("Restored " + record["path"])
    print("ANNEX_BACKUP_RESTORE_OK: " + str(len(records)) + " exact files verified")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise SystemExit("Annex restore refused: " + str(error))
