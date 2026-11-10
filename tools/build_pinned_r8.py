#!/usr/bin/env python3
"""Build a pinned recovered-r8 PCK without importing assets or rewriting guards.

This is a source-packaging path, not a raw-assets rebuild or native acceptance.
Run restore_approved_imports.py first. Godot and other writers must be closed.
Only the exact public r8 snapshot is supported. Output must be a NEW file
outside the checkout. The tool never starts a game or accesses player saves.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import struct
import subprocess
import sys
import tempfile


class BuildError(ValueError):
    pass


GUARD = "assets/planting_review/verified-native-foliage.json"
MANIFEST = "tools/pinned-r8-runtime.json"
CRLF_NOTICES = {
    "assets/plaza_islands/STAYATHOMEDEV-LICENSE.txt",
    "assets/quaternius/License_Standard.txt",
}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise BuildError("Duplicate JSON key: " + key)
        result[key] = value
    return result


def parse_json(data):
    return json.loads(data, object_pairs_hook=unique_object)


def relative(value):
    if not isinstance(value, str) or not value or "\\" in value or ":" in value:
        raise BuildError("Expected a project-relative POSIX path")
    if PurePosixPath(value).is_absolute() or any(p in ("", ".", "..") for p in value.split("/")):
        raise BuildError("Unsafe path: " + value)
    if any(ord(c) < 32 or c in '<>"|?*' for c in value):
        raise BuildError("Unsupported path: " + value)
    return value


def checked_path(root, name):
    path = root
    for component in relative(name).split("/"):
        path = path / component
        if path.is_symlink():
            raise BuildError("Symlink is not allowed: " + name)
    return path


def sha(data):
    return hashlib.sha256(data).hexdigest()


def load_manifest(project):
    contract = parse_json(checked_path(project, MANIFEST).read_bytes())
    if not isinstance(contract, dict) or set(contract) != {
        "schema", "snapshot", "source_commit", "engine_version", "files", "native_verified", "crlf_restorations"
    }:
        raise BuildError("Unsupported runtime manifest")
    if (contract["schema"] != 1 or contract["snapshot"] != "v0.100-r8-recovered-public"
            or contract["engine_version"] != "4.6.3" or contract["native_verified"] is not False
            or contract["source_commit"] != "48e2b75d9f3e314d5b54eac62e12a384a5ed95df"):
        raise BuildError("This tool supports only the pinned public r8 snapshot")
    files = contract["files"]
    if not isinstance(files, dict) or not files:
        raise BuildError("Empty or invalid runtime file list")
    names = set()
    for name, expected in files.items():
        relative(name)
        if name.casefold() in names:
            raise BuildError("Case-insensitive duplicate path: " + name)
        names.add(name.casefold())
        if not isinstance(expected, str) or re.fullmatch(r"[0-9a-f]{64}", expected) is None:
            raise BuildError("Invalid SHA-256 for " + name)
        if not (name.startswith(("scripts/", "shaders/", "models/", "assets/", ".godot/imported/"))
                or name in ("project.godot", "main.tscn", "title_menu.tscn")):
            raise BuildError("Unexpected runtime path: " + name)
    if not {GUARD, "project.godot", "main.tscn", "title_menu.tscn"}.issubset(files):
        raise BuildError("Missing required project or authority files")
    restorations = contract["crlf_restorations"]
    if not isinstance(restorations, dict) or not set(restorations).issubset(CRLF_NOTICES):
        raise BuildError("Unsupported line-ending restoration")
    for name, expected in restorations.items():
        if name not in files or not isinstance(expected, str) or re.fullmatch(r"[0-9a-f]{64}", expected) is None:
            raise BuildError("Invalid notice restoration: " + name)
    return contract


def stage_inputs(project, contract, destination=None):
    """Read each exact file once; optional staging never changes the checkout."""
    total = 0
    guard_bytes = None
    for name, expected in sorted(contract["files"].items()):
        path = checked_path(project, name)
        if not path.is_file():
            raise BuildError("Missing runtime input: " + name + "; restore pinned imports first")
        data = path.read_bytes()
        if sha(data) != contract["crlf_restorations"].get(name, expected):
            raise BuildError("Runtime input differs from pinned r8: " + name)
        if name in contract["crlf_restorations"]:
            # The public upload normalized these two notices to LF. Restore
            # the original guard-approved CRLF bytes only in temporary staging.
            if b"\r" in data:
                raise BuildError("Unexpected public notice line endings: " + name)
            data = data.replace(b"\n", b"\r\n")
            if sha(data) != expected:
                raise BuildError("Restored notice does not match existing authority: " + name)
        if name == GUARD:
            guard_bytes = data
        if destination is not None:
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("xb") as output:
                output.write(data)
        total += len(data)
    authority = parse_json(guard_bytes)
    guards = authority.get("source_sha256") if isinstance(authority, dict) else None
    if not isinstance(guards, dict) or not guards:
        raise BuildError("Missing source authority")
    for resource, expected in guards.items():
        if not isinstance(resource, str) or not resource.startswith("res://"):
            raise BuildError("Invalid guarded resource")
        if contract["files"].get(relative(resource[6:])) != expected:
            raise BuildError("Guarded resource is absent or mismatched: " + resource)
    return total, len(guards)


def verify_pack(path, expected):
    """Verify the engine-produced unencrypted v3 pack against all staged bytes."""
    data = path.read_bytes()
    if len(data) < 100 or struct.unpack_from("<5I", data) != (0x43504447, 3, 4, 6, 3):
        raise BuildError("Unexpected Godot pack header")
    # Standalone v3 packs use PACK_REL_FILEBASE (2), without encryption.
    if struct.unpack_from("<I", data, 20)[0] != 2:
        raise BuildError("Unsupported pack flags")
    base, directory = struct.unpack_from("<QQ", data, 24)
    if directory < 96 or directory + 4 > len(data):
        raise BuildError("Invalid pack directory")
    count = struct.unpack_from("<I", data, directory)[0]
    if count != len(expected):
        raise BuildError("Unexpected packed file count")
    at = directory + 4
    seen = set()
    for _ in range(count):
        if at + 4 > len(data):
            raise BuildError("Truncated pack directory")
        length = struct.unpack_from("<I", data, at)[0]
        at += 4
        if length < 1 or length > 4096 or at + length + 36 > len(data):
            raise BuildError("Invalid packed name length")
        raw_name = data[at:at + length]
        at += length
        name = relative(raw_name.rstrip(b"\0").decode("utf-8"))
        if b"\0" in raw_name.rstrip(b"\0") or name in seen or name not in expected:
            raise BuildError("Unexpected or duplicate packed resource: " + name)
        seen.add(name)
        offset, size = struct.unpack_from("<QQ", data, at)
        md5 = data[at + 16:at + 32]
        flags = struct.unpack_from("<I", data, at + 32)[0]
        at += 36
        if flags or base + offset + size > len(data):
            raise BuildError("Invalid packed data: " + name)
        content = data[base + offset:base + offset + size]
        if hashlib.md5(content).digest() != md5 or sha(content) != expected[name]:
            raise BuildError("Packed resource differs: " + name)
    return sha(data), len(data)


def build(project, output, godot):
    project = project.resolve(strict=True)
    contract = load_manifest(project)
    if output.suffix.lower() != ".pck":
        raise BuildError("Output must end in .pck")
    if output.is_symlink() or output.exists():
        raise BuildError("Output already exists; choose a new PCK path")
    output = output.parent.resolve(strict=True) / output.name
    if project == output.parent or project in output.parents:
        raise BuildError("Keep output outside the source checkout")
    executable = shutil.which(str(godot))
    if executable is None:
        raise BuildError("Godot executable was not found")
    with tempfile.TemporaryDirectory(prefix="settlement-r8-build-", dir=output.parent) as temp:
        work = Path(temp)
        source = work / "runtime"
        source.mkdir()
        total, guards = stage_inputs(project, contract, source)
        empty = work / "empty"
        empty.mkdir()
        (empty / "project.godot").write_text("config_version=5\n", encoding="utf-8")
        env = os.environ.copy()
        for variable in ("HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            profile = work / ("isolated-" + variable.lower())
            profile.mkdir()
            env[variable] = str(profile)
        version = subprocess.run([executable, "--version"], env=env, capture_output=True, text=True, timeout=30, check=True).stdout.strip()
        if not version.startswith("4.6.3.stable."):
            raise BuildError("Godot 4.6.3 stable is required, found: " + version)
        pack = work / "runtime.pck"
        script = work / "pack.gd"
        lines = ["extends SceneTree", "func _initialize():", "\tvar pack = PCKPacker.new()",
                 "\tif pack.pck_start(%s) != OK: quit(2); return" % json.dumps(str(pack))]
        for name in sorted(contract["files"]):
            lines.append("\tif pack.add_file(%s, %s) != OK: quit(3); return" % (json.dumps(name), json.dumps(str(source / name))))
        lines.extend(["\tif pack.flush() != OK: quit(4); return", '\tprint("PINNED_R8_PACK_WRITTEN")', "\tquit(0)"])
        script.write_text("\n".join(lines) + "\n", encoding="utf-8")
        result = subprocess.run([executable, "--headless", "--audio-driver", "Dummy", "--path", str(empty), "--script", str(script)],
                                env=env, capture_output=True, text=True, timeout=300, check=True)
        if "PINNED_R8_PACK_WRITTEN" not in result.stdout:
            raise BuildError("Godot did not confirm packaging")
        digest, size = verify_pack(pack, contract["files"])
        # Exclusive publication on the same filesystem. Never overwrite or
        # expose partially copied output. Filesystems lacking hard links fail.
        os.link(pack, output)
        return {"output": str(output), "sha256": digest, "bytes": size,
                "runtime_files": len(contract["files"]), "input_bytes": total,
                "unchanged_guarded_resources": guards, "source_commit": contract["source_commit"],
                "restored_notice_line_endings": len(contract["crlf_restorations"]),
                "godot_version": version, "native_verified": False,
                "packaging_only": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--check", action="store_true", help="Read-only source/guard verification; no Godot process")
    args = parser.parse_args()
    try:
        if args.check:
            if args.output is not None:
                raise BuildError("--check does not take --output")
            project = args.project.resolve(strict=True)
            contract = load_manifest(project)
            total, guards = stage_inputs(project, contract)
            print(json.dumps({"checked_files": len(contract["files"]), "input_bytes": total,
                              "unchanged_guarded_resources": guards, "writes": 0, "native_verified": False}, indent=2))
        else:
            if args.output is None:
                raise BuildError("Specify a new --output path outside the checkout")
            print(json.dumps(build(args.project, args.output, args.godot), indent=2))
    except (BuildError, OSError, ValueError, subprocess.SubprocessError) as error:
        print("Build stopped: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
