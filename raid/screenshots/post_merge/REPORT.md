# Item 14: post-merge check (main 3ac0bea)

Main after merging PRs #3, #4, #5, #8 and #9 (Nov 15, 2026, on Michael's explicit yes for each). PR #7 is not merged.

## Suite

`PATH=/tmp/gbin:$PATH python3 raid/tests/run_relay_candidate_checks.py <outdir>` on a clean checkout of main 3ac0bea, Godot 4.6.3-stable:
**48/48 tests pass, 5,709 checks** (`pass: true`).

| Test | Checks | Result |
|---|---:|---|
| test_research_annex | 36 | PASS |
| test_research_annex_asset | 1966 | PASS |
| test_raid_wayfinding | 191 | PASS |
| test_obsidian_archive | 29 | PASS |
| test_obsidian_independent | 62 | PASS |
| test_relay_contracts | 145 | PASS |
| test_relay_scene | 23 | PASS |
| test_ship_startup_contract | 17 | PASS |
| test_play_flow_entry | 23 | PASS |
| test_ship_contract | 11 | PASS |
| test_ship_flow | 15 | PASS |
| test_ship_boarding_geometry | 80 | PASS |
| test_ship_live_maps | 40 | PASS |
| test_relay_walkthrough | 83 | PASS |
| test_relay_extraction | 58 | PASS |
| test_relay_readiness | 22 | PASS |
| test_relay_extraction_schedule | 8 | PASS |
| test_ship_selection | 56 | PASS |
| test_ship_takeoff_cutscene | 43 | PASS |
| test_cinder_contracts | 150 | PASS |
| test_cinder_scene | 25 | PASS |
| test_cinder_walkthrough | 81 | PASS |
| test_cinder_extraction | 58 | PASS |
| test_cinder_extraction_schedule | 8 | PASS |
| test_cinder_readiness | 22 | PASS |
| test_glasskiln_campus | 43 | PASS |
| test_raid_audio | 112 | PASS |
| test_biome_vegetation | 123 | PASS |
| test_relay_landmark | 24 | PASS |
| test_cinder_landmarks | 29 | PASS |
| test_raid_props | 162 | PASS |
| test_puzzle_controls | 211 | PASS |
| test_field_supplies | 510 | PASS |
| test_cargo_scenery | 480 | PASS |
| test_raid_ui_lifecycle | 46 | PASS |
| test_health_damage | 49 | PASS |
| relay-matrix-case-0 | 63 | PASS |
| relay-matrix-case-1 | 63 | PASS |
| relay-matrix-case-2 | 63 | PASS |
| relay-matrix-case-3 | 63 | PASS |
| relay-matrix-case-4 | 40 | PASS |
| relay-matrix-case-5 | 40 | PASS |
| cinder-matrix-case-0 | 64 | PASS |
| cinder-matrix-case-1 | 64 | PASS |
| cinder-matrix-case-2 | 64 | PASS |
| cinder-matrix-case-3 | 64 | PASS |
| cinder-matrix-case-4 | 40 | PASS |
| cinder-matrix-case-5 | 40 | PASS |

## Merges and conflict resolutions

Every merge used the REST API with `merge_method: merge` and the head sha pinned. Where GitHub reported a conflict, main was merged into the PR branch with a normal merge commit (no rebase, no force-push), the suite was run on that result, and the branch was pushed normally.

| PR | Head merged | Merge commit | Suite on main afterwards |
|---|---|---|---|
| #3 takeoff cutscene | 115c1ac | 87de0ca | 46/46, 5,637 checks |
| #4 visuals | 545ab4e | b942672 | 46/46, 5,637 checks |
| #5 lake fix | 0c41e74 | 1d0612c | 46/46, 5,637 checks |
| #8 health and damage | 3aea514 | f3191b1 | 47/47, 5,686 checks |
| #9 play flow | 241f631 | 3ac0bea | 48/48, 5,709 checks |

- **#3, #4:** clean, no conflicts. #3 added `test_ship_takeoff_cutscene`, so the base became 46 tests.
- **#5** (`raid/scripts/ship_settlement_preview.gd`, `activate_loaded_world`): runs `super`, then #4's visuals, then #5's lake fix (only once the world is active). The visuals are additive decoration. The lake fix only reshapes the MiddleRidge hills and lowers trees standing on them (more than 68 m from the lake's centre), so both behaviours are kept. Branch suite: 46/46.
- **#8** (same file, the declarations at the top): kept #3's `ShipTakeoff` declarations and #8's `SettlementHealth` / `_initialize_world` health setup. Branch suite: 47/47, 5,686 checks.
- **#9** (`raid/scripts/ship_transition.gd`, `_restore_title`): kept #3's comment, noting that play_title extends ship_title_preview, and #9's load of `res://raid/play_title.tscn` on return from a raid. Branch suite: 48/48, 5,709 checks. `play_title.gd` overrides `_play()` to open the mockup A select; the `_play()` in `ship_title_preview.gd` (from PR #6) is still there for the opt-in preview entry.
- No MiddleRidge material conflict appeared among these PRs. feat/far-scenery (item 9) was not merged.

## Plain-launch screenshots

`godot --rendering-driver opengl3 --path .` (no scene argument) under Xvfb with llvmpipe, 1440x900. The capture driver (`raid/tests/play_flow_capture.gd`) was loaded through a temporary `override.cfg` autoload in a copy of main; `project.godot` was unchanged. The run exited 0. The main scene is `res://raid/play_title.tscn`. In the raid, the `RaidHealthHud` health bar is visible at 100/100.

1. `01_main_menu.png`: title menu
2. `02_character_select.png`, `02b_character_select_closeup.png`: mockup A character select
3. `03_settlement.png`: settlement (vitals HUD shows health 100/100)
4. `04a_spaceship_approach.png`, `04_spaceship_boarding.png`, `04b_ship_raid_selection.png`: walking up to the ship and picking a raid
5. `05_inside_raid.png`: Relay Ridge after the takeoff cutscene, with the health HUD bottom left

## Known issues

- **Lake capture tool:** `raid/tests/inn_lake_capture.gd` (item 10, not part of the suite) fails on this machine because the world is freed before it loads. It fails the same way on PR #5's original head e2aa02c, so the merge did not cause it, but there is no rendered check of the combined lake fix plus visuals result yet.
- **HUD text overlap:** in Relay Ridge, the yellow "Relay Ridge development preview" hint overlaps the controls line at the top left (see `05_inside_raid.png`). This looks like an existing HUD layout issue, not something introduced by these merges.
- **Cutscene speed on the software renderer:** on llvmpipe the takeoff cutscene took about 8 minutes of real time (click Deploy at t=966 s, raid ready by t=1475 s). Not measured on a real GPU, where it should be far faster.
