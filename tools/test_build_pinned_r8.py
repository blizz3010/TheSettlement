#!/usr/bin/env python3
"""Focused exporter safety tests; no game, editor import, or player profile."""
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

import build_pinned_r8 as build


def contract(files):
    return {"schema": 1, "snapshot": "v0.100-r8-recovered-public",
            "source_commit": "48e2b75d9f3e314d5b54eac62e12a384a5ed95df",
            "engine_version": "4.6.3", "native_verified": False, "files": files, "crlf_restorations": {}}


class ExportSafety(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.project = self.root / "project"
        self.project.mkdir()
        source = b"extends RefCounted\n"
        resources = {"project.godot": b"config_version=5\n", "main.tscn": b"[gd_scene format=3]\n",
                     "title_menu.tscn": b"[gd_scene format=3]\n", "scripts/sample.gd": source}
        resources[build.GUARD] = json.dumps({"source_sha256": {"res://scripts/sample.gd": build.sha(source)}}).encode()
        for name, data in resources.items():
            target = self.project / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        self.manifest = contract({name: build.sha(data) for name, data in resources.items()})
        self.write_manifest()

    def tearDown(self):
        self.temp.cleanup()

    def write_manifest(self):
        path = self.project / build.MANIFEST
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.manifest), encoding="utf-8")

    def test_check_is_read_only(self):
        before = {str(p.relative_to(self.project)): p.read_bytes() for p in self.project.rglob("*") if p.is_file()}
        manifest = build.load_manifest(self.project)
        count, guards = build.stage_inputs(self.project, manifest)
        self.assertGreater(count, 0)
        self.assertEqual(guards, 1)
        after = {str(p.relative_to(self.project)): p.read_bytes() for p in self.project.rglob("*") if p.is_file()}
        self.assertEqual(before, after)

    def test_corrupt_source_stops_before_godot_or_output(self):
        (self.project / "scripts/sample.gd").write_bytes(b"different")
        with self.assertRaisesRegex(build.BuildError, "differs from pinned"):
            build.stage_inputs(self.project, build.load_manifest(self.project))

    def test_missing_source_fails_closed(self):
        (self.project / "main.tscn").unlink()
        with self.assertRaisesRegex(build.BuildError, "Missing runtime"):
            build.stage_inputs(self.project, build.load_manifest(self.project))

    def test_unsafe_and_unexpected_paths(self):
        for path in ("../secret", "assets/../secret", "C:/secret", "assets\\file", "tools/unexpected", ".godot/editor/state"):
            with self.subTest(path=path):
                self.manifest["files"][path] = "a" * 64
                self.write_manifest()
                with self.assertRaises(build.BuildError):
                    build.load_manifest(self.project)
                del self.manifest["files"][path]

    def test_symlink_input_is_rejected(self):
        path = self.project / "scripts/sample.gd"
        target = self.root / "outside.gd"
        target.write_bytes(path.read_bytes())
        path.unlink()
        try:
            path.symlink_to(target)
        except (OSError, NotImplementedError):
            self.skipTest("Symlinks are unavailable on this platform")
        with self.assertRaisesRegex(build.BuildError, "Symlink"):
            build.stage_inputs(self.project, build.load_manifest(self.project))

    def test_duplicate_json_keys_fail(self):
        with self.assertRaisesRegex(build.BuildError, "Duplicate JSON"):
            build.parse_json('{"files":{},"files":{}}')

    def test_missing_guarded_file_fails(self):
        del self.manifest["files"]["scripts/sample.gd"]
        self.write_manifest()
        with self.assertRaisesRegex(build.BuildError, "Guarded resource"):
            build.stage_inputs(self.project, build.load_manifest(self.project))

    def test_existing_output_is_not_touched(self):
        output = self.root / "existing.pck"
        output.write_bytes(b"preserve me")
        with self.assertRaisesRegex(build.BuildError, "already exists"):
            build.build(self.project, output, "not-a-godot-executable")
        self.assertEqual(output.read_bytes(), b"preserve me")

    def test_output_inside_checkout_is_rejected(self):
        with self.assertRaisesRegex(build.BuildError, "outside the source"):
            build.build(self.project, self.project / "unsafe.pck", "not-a-godot-executable")

    def test_hash_checks_survive_optimized_python(self):
        (self.project / "scripts/sample.gd").write_bytes(b"different")
        command = [sys.executable, "-O", str(Path(build.__file__).resolve()), "--project", str(self.project), "--check"]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("differs from pinned", result.stderr)

    def test_pack_hash_checks_and_header_flags(self):
        # Tiny standalone v3 fixture follows Godot 4.6.3's relative file base.
        content = b"checked bytes"
        name = b"scripts/sample.gd\0"
        name += b"\0" * (-len(name) % 4)
        data = bytearray(128)
        directory = 128 + len(content)
        struct.pack_into("<6I2Q", data, 0, 0x43504447, 3, 4, 6, 3, 2, 128, directory)
        data += content + struct.pack("<II", 1, len(name)) + name
        data += struct.pack("<QQ", 0, len(content)) + hashlib.md5(content).digest() + struct.pack("<I", 0)
        path = self.root / "fixture.pck"
        path.write_bytes(data)
        expected = {"scripts/sample.gd": build.sha(content)}
        self.assertEqual(build.verify_pack(path, expected)[0], build.sha(data))
        data[128] ^= 1
        path.write_bytes(data)
        with self.assertRaisesRegex(build.BuildError, "Packed resource differs"):
            build.verify_pack(path, expected)
        struct.pack_into("<I", data, 20, 3)
        path.write_bytes(data)
        with self.assertRaisesRegex(build.BuildError, "Unsupported pack flags"):
            build.verify_pack(path, expected)

    def test_only_pinned_notice_line_endings_are_restored(self):
        name = "assets/plaza_islands/STAYATHOMEDEV-LICENSE.txt"
        public = b"License\nText\n"
        original = b"License\r\nText\r\n"
        source = self.project / name
        source.parent.mkdir(parents=True, exist_ok=True)
        source.write_bytes(public)
        self.manifest["files"][name] = build.sha(original)
        self.manifest["crlf_restorations"][name] = build.sha(public)
        self.write_manifest()
        staged = self.root / "staged"
        build.stage_inputs(self.project, build.load_manifest(self.project), staged)
        self.assertEqual((staged / name).read_bytes(), original)
        self.assertEqual(source.read_bytes(), public)
        self.manifest["files"][name] = "a" * 64
        self.write_manifest()
        with self.assertRaisesRegex(build.BuildError, "existing authority"):
            build.stage_inputs(self.project, build.load_manifest(self.project))

    def test_arbitrary_line_ending_transform_is_rejected(self):
        self.manifest["crlf_restorations"] = {"scripts/sample.gd": self.manifest["files"]["scripts/sample.gd"]}
        self.write_manifest()
        with self.assertRaisesRegex(build.BuildError, "Unsupported line-ending"):
            build.load_manifest(self.project)


if __name__ == "__main__":
    unittest.main()
