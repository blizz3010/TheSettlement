#!/usr/bin/env python3
"""Run bounded headless candidate checks with fresh, isolated disposable profiles.

Usage: python3 raid/tests/run_relay_candidate_checks.py /absolute/output-directory
Godot 4.6.3 must be on PATH. This never restores imports or exports a build.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

PROJECT = Path(__file__).resolve().parents[2]
TESTS = [
    ("test_research_annex", "RESEARCH_ANNEX_TESTS "),
    ("test_research_annex_asset", "RESEARCH_ANNEX_ASSET_TESTS "),
    ("test_raid_wayfinding", "RAID_WAYFINDING_TESTS "),
    ("test_obsidian_archive", "OBSIDIAN_ARCHIVE_TESTS "),
    ("test_obsidian_independent", "OBSIDIAN_INDEPENDENT_TESTS "),
    ("test_relay_contracts", "RELAY_CONTRACTS "),
    ("test_relay_scene", "RELAY_SCENE_TESTS "),
    ("test_ship_startup_contract", "SHIP_STARTUP_CONTRACT_TESTS "),
    ("test_ship_contract", "Ship contract: "),
    ("test_ship_flow", "Ship flow: "),
    ("test_ship_boarding_geometry", "SHIP_BOARDING_GEOMETRY_TESTS "),
    ("test_ship_live_maps", "SHIP_LIVE_MAP_TESTS "),
    ("test_relay_walkthrough", "RELAY_WALKTHROUGH_TESTS "),
    ("test_relay_extraction", "RELAY_EXTRACTION_TESTS "),
    ("test_relay_readiness", "RELAY_READINESS_TESTS "),
    ("test_relay_extraction_schedule", "RELAY_EXTRACTION_SCHEDULE_TESTS "),
    ("test_ship_selection", "RELAY_SHIP_SELECTION_TESTS "),
    ("test_cinder_contracts", "CINDER_CONTRACTS "),
    ("test_cinder_scene", "CINDER_SCENE_TESTS "),
    ("test_cinder_walkthrough", "CINDER_WALKTHROUGH_TESTS "),
    ("test_cinder_extraction", "CINDER_EXTRACTION_TESTS "),
    ("test_cinder_extraction_schedule", "CINDER_EXTRACTION_SCHEDULE_TESTS "),
    ("test_cinder_readiness", "CINDER_READINESS_TESTS "),
    ("test_glasskiln_campus", "GLASSKILN_CAMPUS_TESTS "),
    ("test_raid_audio", "RAID_AUDIO_TESTS "),
    ("test_biome_vegetation", "BIOME_VEGETATION_TESTS "),
    ("test_relay_landmark", "RELAY_LANDMARK_TESTS "),
    ("test_cinder_landmarks", "CINDER_LANDMARK_TESTS "),
    ("test_raid_props", "RAID_PROPS_TESTS "),
    ("test_puzzle_controls", "PUZZLE_CONTROLS_TESTS "),
    ("test_field_supplies", "FIELD_SUPPLIES_TESTS "),
    ("test_cargo_scenery", "CARGO_SCENERY_TESTS "),
    ("test_raid_ui_lifecycle", "RAID_UI_LIFECYCLE_TESTS "),
]

def main():
    if len(sys.argv) != 2 or not Path(sys.argv[1]).is_absolute():
        raise SystemExit("Supply an absolute output directory.")
    output = Path(sys.argv[1])
    output.mkdir(parents=True, exist_ok=True)
    profiles = Path(tempfile.mkdtemp(prefix="relay-candidate-checks-"))
    results = []

    def invoke(name, args):
        env = os.environ.copy()
        for variable, directory in [("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")]:
            path = profiles / name / directory
            path.mkdir(parents=True)
            env[variable] = str(path)
        try:
            process = subprocess.run(["godot", *args], cwd=PROJECT, env=env, capture_output=True, text=True, timeout=180)
            log = process.stdout + process.stderr
            code = process.returncode
        except subprocess.TimeoutExpired as error:
            log = "CHECK TIMED OUT\n" + str(error)
            code = -1
        (output / f"{name}.log").write_text(log)
        return code, log

    version_code, version = invoke("engine-version", ["--version"])
    if version_code or not version.startswith("4.6.3."):
        raise SystemExit("Godot 4.6.3 required. See engine-version.log.")
    tests = list(TESTS)
    tests += [(f"{biome}-matrix-case-{i}", f"{biome.upper()}_SEED_MATRIX_TESTS ") for biome in ("relay", "cinder") for i in range(6)]
    for name, marker in tests:
        matrix = "-matrix-case-" in name
        script = "test_" + name.split("-", 1)[0] + "_seed_matrix" if matrix else name
        args = ["--headless", "--fixed-fps", "60", "--path", str(PROJECT), "--script", f"res://raid/tests/{script}.gd"]
        if matrix:
            args += ["--", f"--matrix-index={name.rsplit('-', 1)[1]}"]
        code, log = invoke(name, args)
        line = next((line for line in log.splitlines() if line.startswith(marker)), "")
        result = {"test": name, "exit_code": code, "marker_found": bool(line), "checks": 0}
        result["errors"] = [line for line in log.splitlines() if re.match(r"^(SCRIPT ERROR|ERROR):", line)]
        try:
            payload = line[len(marker):]
            if marker.startswith("Ship "):
                count = re.search(r"PASS \((\d+) checks", payload)
                result["checks"] = int(count.group(1)) if count else 0
                result["pass"] = bool(count)
            else:
                data = json.loads(payload)
                result["checks"] = data["checks"]
                result["pass"] = result["checks"] > 0 and not data["failures"]
        except (ValueError, KeyError, TypeError):
            result["pass"] = False
        result["pass"] = bool(result["pass"] and code == 0 and not result["errors"])
        results.append(result)
        print(f"{name}: {'PASS' if result['pass'] else 'FAIL'} ({result['checks']} checks)", flush=True)
    summary = {
        "engine": version.strip(), "checks": sum(item["checks"] for item in results),
        "pass": all(item["pass"] for item in results), "results": results,
        "disposable_profile_root": str(profiles), "rendered_acceptance": False,
        "native_input_acceptance": False, "windows_acceptance": False,
        "real_settlement_save_reload_acceptance": False, "performance_acceptance": False,
    }
    (output / "aggregate-results.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"Profiles retained: {profiles}\nResults: {output / 'aggregate-results.json'}")
    return 0 if summary["pass"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
