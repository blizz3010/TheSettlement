# Two-map raid development candidate

Version 0.4 source candidate, November 10, 2026. Relay Ridge and Cinder Basin. Additive candidate for The Settlement's recovered
Godot 4.6.3 r8 source. This is a working environment/interaction prototype, not a
finished raid, production patch or native playtest approval. All original source
files and the source project default launch remain unchanged. A separately staged
Windows review package can use a candidate-only startup/profile override; see
that package's launch instructions. It is not a fresh Windows export or Windows test.

## What is built

See [raid wayfinding](WAYFINDING-UPDATE.md) for session-only map pins, compass guidance and Archive floor/stair cues.

Relay Ridge remains the woodland first map. Cinder Basin adds a separate salt-flat
and basalt biome with six new POIs, a solar array, kiln, archive and valve puzzle.
Glasskiln Works now has five explorable industrial buildings, a cargo yard and
two-ended elevated service routes; see [campus update](GLASSKILN-UPDATE.md).
Each map now has six distinct procedural plant species inspired by its supplied
concept sheet; see the [vegetation update](VEGETATION-UPDATE.md).
The supplied biome-specific loot caches and extraction beacons are integrated in
this separate source candidate; see [prop update](PROPS-UPDATE.md).
The supplied Echo Cistern valves and Weather Station relay levers now animate on
the existing puzzle targets; see [control update](PUZZLE-CONTROLS-UPDATE.md).
See [Cinder Basin](CINDER-BASIN.md) for its layout and generation details. The ship
now opens a two-destination selector before saving and deploying. Cancel is free,
and the selected destination is revalidated at confirmation.

The maps share timed extraction, raid-only discovery/cache tracking, and user-supplied
interaction sounds. Thirteen cues are wired, including three Cinder-only valve
variants; Relay Ridge keeps its electrical relay click. The long heavy-door cue is
included but reserved until there is matching door motion. See [audio notes](audio/README.md).

Relay Ridge details:

- A seed-controlled terrain mesh with matching triangle collision, rolling ridge,
  screened outer terrain, colored trails and POI clearings. The rendered terrain
  covers 384 × 384 m; the intended playable region is about 292 × 292 m.
- Independent deterministic tree, grass, shrub and rock placement. Preserves existing
  placement streams with species-specific procedural meshes, chunked MultiMesh rendering, distance
  culling and trunk/rock collision. Clearings, trails, steep slopes and landing/
  extraction areas exclude foliage. No new plugins or asset purchases.
- A travel preflight samples the exact terrain-triangle slopes along the trail
  centre and a 1.2 m-wide corridor, at intervals no larger than 0.5 m. Grades
  above 0.7 are refused before terrain/player activation, with a return option.
  The ship loader shows the refusal immediately. This checks authored trails,
  not every off-trail location or every possible designer change.
- Six fixed POI layouts with distinct landmark blockouts: Survey Camp, West
  Substation, Relay Tower, Research Annex, Salvage Yard and Weather Station.
  These buildings and props use simple development geometry, not final artwork.
- Connected perimeter and cross-map trails. Important trails use forecourts and
  go around building/prop footprints instead of running through locked buildings.
  Two extraction beacons have separate approaches and marked 4 m zones. Confirm
  extraction, then stay grounded inside the markers for eight seconds. Leaving,
  jumping, interacting again, opening a menu or losing focus cancels the timer.
  Ship flight animation is not implemented yet.
- Adjustable per-POI loot-quality bands on a prototype 1–5 scale. Relay Tower and
  Research Annex are the two top sites (4–5). Camp is 1–2, Substation and Weather
  Station are 2–3, Yard is 2–4. A cache rolls once per raid within its site's band.
  These are sample quality rolls, not actual item drops or persistent rewards.
- Key door, keycard door and code door. Their key/card/note are collectible at
  field supplies in the respective POI, outside the locked room. The four-digit
  note matches that seed's door; the code panel rejects an incorrect code.
- An early concealed weather archive partition opened by a three-switch sequence.
  Its clue is retained in field notes. Discovery/artwork/puzzle difficulty are
  provisional; this is one small puzzle example, not a complete puzzle system.
- First-person movement reuses the production player. M opens the map, Tab opens
  field notes, E interacts and Escape pauses (movement/map/Interact respect saved
  bindings). Focus loss releases controls. The map shows real POI/trail positions.
- A raid-only exploration ledger tracks the six visited sites and searched caches.
  Map rings mark visited sites; searched caches are labeled. Field notes combine
  credentials and a scrollable route checklist. Successful extraction shows an
  active-time and cache-quality summary before returning. No reward is persisted.
- Optional ship entry via a separate title/settlement adapter. It saves before
  departure and reloads the same character through the original startup gates on
  return. Return currently uses the Town Hall login. See SHIP-INTEGRATION.md.

Default seed 241107 produces 144 terrain chunks / 73,728 triangles, 591 trees,
6,315 grass clumps, 317 shrubs and 205 rocks. Natural generation is version 1 (appearance version 1)
and pinned to Godot 4.6.3. It is not guaranteed byte-identical across engine versions.

## Use in a development copy

Copy this archive's `raid/` directory into the recovered r8 project. Keep its
existing `project.godot`, scenes, scripts, assets and guards. Follow that project's
approved-import restoration instructions. Use a disposable development profile.
Do not use real saves or run alongside a production build sharing the profile.

Standalone map (no settlement save reads/writes):

```sh
XDG_DATA_HOME=/tmp/relay-review/data \
XDG_CONFIG_HOME=/tmp/relay-review/config \
XDG_CACHE_HOME=/tmp/relay-review/cache \
godot --path /path/to/development-project res://raid/relay_ridge.tscn
```

Ship workflow (this DOES save the disposable settlement before leaving):

```sh
XDG_DATA_HOME=/tmp/relay-review/data \
XDG_CONFIG_HOME=/tmp/relay-review/config \
XDG_CACHE_HOME=/tmp/relay-review/cache \
godot --path /path/to/development-project res://raid/ship_title_preview.tscn
```

A standalone map's Return button exits the preview; the optional ship host returns
through the title loader. Do not launch the ship settlement scene directly.
The Windows build/export and normal-start travel acceptance are still pending.

## Tune the generation

Edit `raid/relay_settings.tres` for seed, terrain amplitude and per-layer density.
Edit `scripts/relay_config.gd` for POI locations/radii, loot bands and trail nodes.
The scene loads that settings resource. Each layer has its own RNG stream, so
reducing grass does not move trees. POIs and routes stay fixed when changing the
natural seed. Run the tests and a rendered walkthrough after changes; arbitrary
seeds/densities/amplitudes have not all been playtested. An allowed numeric setting
can still be refused by the travel check. In particular, seeds 7 and 42 at
amplitude 12 exceed the trail-grade budget. Lower amplitude or choose another
seed if that happens; do not disable the travel check to force a playable start.

## Verification

Godot 4.6.3 tests in an isolated Linux headless profile:

- `test_relay_contracts.gd`: 145 checks passed. Determinism, independent density,
  exclusions/slope/ground placement, fixed footprints/routes, unique POIs, two
  top-tier sites, all lock types, wrong/missing credentials, notes, puzzle sequence,
  bounded loot rolls, duplicate-cache protection and reset behavior.
- `test_relay_scene.gd`: 23 checks passed on the actual generated scene. Spawn
  readiness and collision, 590 trail samples, standing-capsule clearance on those
  samples, physical door blocking/removal, repeated UI open/close, code entry,
  focus loss and a 30 m traversal using the production player motion.
- `test_ship_contract.gd`: 11 checks passed with doubles.
- `test_ship_flow.gd`: 14 checks passed using the real adapter/host with doubles.
- `test_ship_selection.gd`: 55 checks passed, including both allowlisted scenes,
  confirmation/cancel, repeated/stale input, focus/close and logical UI bounds.
- `test_relay_walkthrough.gd`: 90 checks passed. Production-controller traversal
  over all seven trails in both directions and all six POI visits, including real
  camera/raycast targeting and interaction handlers. Total tested walking: 3,665 m.
- `test_relay_extraction.gd`: 58 checks passed. Countdown, cancellation, repeated
  input, stale confirmation, discovery/results, once-only return and UI bounds at
  1280×720 and 1440×900. Bounds assertions are not a rendered visual review.
- `test_relay_readiness.gd`: 22 checks passed. Default preflight, two unsafe
  seed/amplitude combinations and invalid settings, clear standalone refusal,
  immediate ship-host refusal and one-shot return.

- `test_relay_extraction_schedule.gd`: 8 checks passed. Scheduled final-tick
  jump/zone-exit cancellation and stationary completion use production movement
  from a test driver. This protects callback ordering, not native input capture.
- `test_relay_seed_matrix.gd`: 332 checks passed across six configurations. Four
  accepted configurations passed 21,240 support/standing-capsule samples and 48
  selected-segment walks (2,174 m). Two excessive-amplitude cases correctly
  refused entry. This is not a claim that every configuration is playable.

The combined runner also checks all Cinder suites, the expanded Glasskiln campus,
both six-case procedural
matrices, audio across both maps and dedicated biome-vegetation checks. Its JSON result records the final aggregate
count and whether every suite returned a valid pass marker without runtime errors.
Maximum default Relay trail direction grade was 0.354 (about 19.5°); its maximum
sampled full triangle grade was 0.5903.
Ground mesh vs sampler discrepancy was under 4.8 cm at tested trail samples.
The final source audit found zero changes to original non-cache r8 files.
These are focused headless results, not a full game regression or rendered proof.

Run all combined checks with automatically isolated per-test profiles:

```sh
python3 raid/tests/run_relay_candidate_checks.py /absolute/output/raid-checks
```

Or run individual Relay tests with the same isolated XDG variables:

```sh
godot --headless --path . --script res://raid/tests/test_relay_contracts.gd
godot --headless --path . --script res://raid/tests/test_relay_scene.gd
godot --headless --path . --script res://raid/tests/test_ship_contract.gd
godot --headless --path . --script res://raid/tests/test_ship_flow.gd
godot --headless --path . --fixed-fps 60 --script res://raid/tests/test_relay_walkthrough.gd
godot --headless --path . --fixed-fps 60 --script res://raid/tests/test_relay_extraction.gd
godot --headless --path . --fixed-fps 60 --script res://raid/tests/test_relay_readiness.gd
godot --headless --path . --fixed-fps 60 --script res://raid/tests/test_relay_extraction_schedule.gd
bash raid/tests/run_relay_seed_matrix.sh /absolute/output/relay-matrix
```

## Remaining work / limitations

Relay Tower, Helion Mirror Array and Obsidian Archive now have concept-inspired
procedural landmark art, retaining their functional room and route footprints.
These are not finished production assets. See LANDMARK-UPDATE.md for the three
landmarks, unchanged gameplay, new geometry checks and review limitations.

- Rendered art, foliage appearance, draw-call/frame-time budgets, audio and Windows
  control acceptance are unverified. The vegetation pass uses original procedural
  geometry, without additional imported resources. No guard or fingerprint was
  weakened to make this pass.
- A whole-project editor import was killed by the environment; approved imported
  assets were restored and all 346 pinned outputs verified before the final tests.
  The earlier display-server attempt failed. No new workaround was attempted in
  this batch, and no gameplay screenshot or rendered pass is claimed.
- No enemies, combat, multiplayer, damage, actual item loot, death/loss policy,
  loot persistence, cooldowns, access-item consumption or progression.
  All raid keys, codes, doors, puzzle, discovery and sample-roll state reset on
  leaving the preview.
- Key/card/clue placement is intentionally easy to find for initial testing.
  Placement variants, art dressing and a more discoverable hidden-room puzzle follow.
- The 144 terrain chunks and simple colliders are a bounded first implementation,
  not a streaming large-world architecture or optimized production terrain system.
- Ship physical boarding, real save/reload and return-camera/audio checks must pass
  in a normal rendered disposable session before this is wired into the main release.
- The existing exact-r8 exporter intentionally does not package this candidate.
  A separate reviewed candidate build manifest/export is needed for a Windows build.

`Relay-Ridge-Layout-Preview.png` was generated from the actual terrain sampler,
trail nodes and tree placements. It is a layout diagram, not a gameplay screenshot.
