"""Focused recovery-tool checks. No Godot launch or player profiles are used."""

import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


TOOL = Path(__file__).with_name("restore_approved_imports.py")
spec = importlib.util.spec_from_file_location("restore_approved_imports", TOOL)
restore = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = restore
spec.loader.exec_module(restore)


def sha(data):
    return hashlib.sha256(data).hexdigest()


class RestoreTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "project"
        self.root.mkdir()
        self.runtime = "vendor/approved-runtime-imports/scene.scn"
        self.metadata = "vendor/approved-import-metadata/assets/scene.glb.import"
        self.chunk1 = "vendor/large-assets/asset00.part01"
        self.chunk2 = "vendor/large-assets/asset00.part02"
        self.expected = {
            ".godot/imported/scene.scn": b"pinned-scene",
            "assets/scene.glb.import": b"pinned-import",
            "assets/large.scn": b"first-second",
        }
        self.write(self.runtime, b"pinned-scene")
        self.write(self.metadata, b"pinned-import")
        self.write(self.chunk1, b"first-")
        self.write(self.chunk2, b"second")
        self.manifests = {
            "vendor/approved-runtime-imports/manifest.json": [
                {"path": "scene.scn", "sha256": sha(b"pinned-scene")}],
            "vendor/approved-import-metadata/manifest.json": [
                {"path": "assets/scene.glb.import", "sha256": sha(b"pinned-import")}],
            "vendor/large-assets/manifest.json": [{
                "destination": "assets/large.scn", "sha256": sha(b"first-second"),
                "parts": [{"path": self.chunk1, "sha256": sha(b"first-")},
                          {"path": self.chunk2, "sha256": sha(b"second")}]}],
        }
        self.save_manifests()

    def write(self, name, data):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def save_manifests(self):
        for path, value in self.manifests.items():
            self.write(path, json.dumps(value).encode())

    def snapshot(self):
        return {str(p.relative_to(self.root)): p.read_bytes()
                for p in self.root.rglob("*") if p.is_file() and not p.is_symlink()}

    def seed_old_outputs(self):
        for path in self.expected:
            self.write(path, b"old bytes")

    def test_check_is_read_only(self):
        before = self.snapshot()
        result = restore.restore(self.root, check=True)
        self.assertEqual(result["verified_files"], 3)
        self.assertEqual(result["installed"], 0)
        self.assertEqual(self.snapshot(), before)
        self.assertFalse((self.root / ".godot").exists())

    def test_restore_exact_and_idempotent(self):
        self.seed_old_outputs()
        result = restore.restore(self.root)
        self.assertEqual(result["installed"], 3)
        for path, data in self.expected.items():
            self.assertEqual((self.root / path).read_bytes(), data)
        mtimes = {path: (self.root / path).stat().st_mtime_ns for path in self.expected}
        result = restore.restore(self.root)
        self.assertEqual(result["installed"], 0)
        self.assertEqual(result["unchanged"], 3)
        self.assertEqual(mtimes, {p: (self.root / p).stat().st_mtime_ns for p in self.expected})
        self.assertFalse(list(self.root.glob(".settlement-restore-*")))

    def test_corrupt_last_chunk_leaves_every_output_unchanged(self):
        self.seed_old_outputs()
        self.write(self.chunk2, b"corrupted")
        before = self.snapshot()
        with self.assertRaisesRegex(restore.RestoreError, "Input SHA-256 mismatch"):
            restore.restore(self.root)
        self.assertEqual(self.snapshot(), before)
        self.assertFalse(list(self.root.glob(".settlement-restore-*")))

    def test_missing_chunk_leaves_every_output_unchanged(self):
        self.seed_old_outputs()
        (self.root / self.chunk2).unlink()
        before = self.snapshot()
        with self.assertRaisesRegex(restore.RestoreError, "Missing input"):
            restore.restore(self.root)
        self.assertEqual(self.snapshot(), before)

    def test_assembled_hash_checked_independently(self):
        self.manifests["vendor/large-assets/manifest.json"][0]["sha256"] = "0" * 64
        self.save_manifests()
        with self.assertRaisesRegex(restore.RestoreError, "Assembled SHA-256 mismatch"):
            restore.restore(self.root)
        self.assertFalse((self.root / ".godot").exists())

    def test_optimized_python_does_not_disable_checks(self):
        self.write(self.runtime, b"corrupt runtime")
        before = self.snapshot()
        result = subprocess.run([sys.executable, "-O", str(TOOL), "--project", str(self.root)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("Input SHA-256 mismatch", result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_paths_reject_traversal_windows_and_empty_components(self):
        for path in ("../escape", "/tmp/escape", "C:/escape", "C:\\escape",
                     "assets/../escape", "assets//escape", "assets/./escape", "assets/a\x00b"):
            with self.subTest(path=path), self.assertRaises(restore.RestoreError):
                restore.relative(path)

    def test_duplicate_casefolded_destinations_rejected(self):
        data = self.manifests["vendor/large-assets/manifest.json"]
        data.append({**data[0], "destination": "assets/LARGE.scn"})
        self.save_manifests()
        with self.assertRaisesRegex(restore.RestoreError, "Duplicate destination"):
            restore.restore(self.root)

    def test_symlink_input_and_output_rejected(self):
        outside = self.root.parent / "outside"
        outside.write_bytes(b"pinned-scene")
        (self.root / self.runtime).unlink()
        try:
            (self.root / self.runtime).symlink_to(outside)
        except OSError as error:
            self.skipTest("Symlinks unavailable: " + str(error))
        with self.assertRaisesRegex(restore.RestoreError, "Symlink"):
            restore.restore(self.root)
        (self.root / self.runtime).unlink()
        self.write(self.runtime, b"pinned-scene")
        outside_dir = self.root.parent / "outside-directory"
        outside_dir.mkdir()
        (self.root / ".godot").symlink_to(outside_dir, target_is_directory=True)
        with self.assertRaisesRegex(restore.RestoreError, "Symlink"):
            restore.restore(self.root)
        self.assertEqual(list(outside_dir.iterdir()), [])

    def test_destination_parent_file_rejected_before_install(self):
        (self.root / ".godot").write_bytes(b"not a directory")
        before = self.snapshot()
        with self.assertRaisesRegex(restore.RestoreError, "parent is not a directory"):
            restore.restore(self.root)
        self.assertEqual(self.snapshot(), before)

    def test_staging_readback_failure_prevents_install(self):
        self.seed_old_outputs()
        before = self.snapshot()
        with mock.patch.object(restore, "file_digest", return_value="0" * 64):
            with self.assertRaisesRegex(restore.RestoreError, "Staged SHA-256 mismatch"):
                restore.restore(self.root)
        self.assertEqual(self.snapshot(), before)

    def test_cleanup_failure_reports_completed_installation(self):
        real_cleanup = restore.tempfile.TemporaryDirectory.cleanup

        def cleanup_then_fail(temporary):
            real_cleanup(temporary)
            raise PermissionError("fixture cleanup lock")

        with mock.patch.object(restore.tempfile.TemporaryDirectory, "cleanup", cleanup_then_fail):
            with self.assertRaisesRegex(restore.RestoreError, "cleaning.*after 3 complete replacements"):
                restore.restore(self.root)
        for path, data in self.expected.items():
            self.assertEqual((self.root / path).read_bytes(), data)

    def test_install_failure_reports_partial_progress_without_truncation(self):
        self.seed_old_outputs()
        real_replace = restore.os.replace
        calls = []

        def fail_second(source, destination):
            calls.append(destination)
            if len(calls) == 2:
                raise PermissionError("fixture write lock")
            real_replace(source, destination)

        with mock.patch.object(restore.os, "replace", side_effect=fail_second):
            with self.assertRaisesRegex(restore.RestoreError, "after 1 complete replacements"):
                restore.restore(self.root)
        self.assertEqual((self.root / ".godot/imported/scene.scn").read_bytes(), b"pinned-scene")
        self.assertEqual((self.root / "assets/scene.glb.import").read_bytes(), b"old bytes")
        self.assertEqual((self.root / "assets/large.scn").read_bytes(), b"old bytes")
        self.assertEqual(restore.restore(self.root)["installed"], 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
