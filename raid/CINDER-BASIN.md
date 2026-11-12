# Cinder Basin: second raid development preview

November 10, 2026. Additive Godot 4.6.3 candidate, alongside Relay Ridge. This is
an explorable, deterministic environment/interaction prototype. It is not a
finished raid, a Windows build, a rendered playtest approval or persistent loot.
Normal Settlement startup, original assets/scripts, saves and r8 guards are intact.

## Biome and sites

Cinder Basin replaces Relay Ridge's green wooded ridgeline with an open pale salt
basin, low ash dunes, dark basalt rocks, sparse juniper/yucca, salt shrubs and
samphire, warm dust haze and abandoned desert industry. No woodland species are
used. Vegetation and geology are
built from original procedural meshes using chunked MultiMesh batches and bounded
collision. The terrain is 384 × 384 m, with an intended playable region of roughly
292 × 292 m. The basin has its own landform, seven connected routes, insertion
point and two extraction sites, rather than a recolored copy of the first layout.

Six fixed authored sites have distinct silhouettes and prototype loot-quality bands:

- **Siltway Caravan**, 1–2: open awning shelter, cargo cabins and a wind pennant.
  Open-access cache and the first stop from the southeast insertion.
- **Glasskiln Works**, 2–3: an expanded five-building industrial campus with a
  twin-furnace hall, control house, warehouse, maintenance workshop and power shed.
  A staggered cargo yard leads to multiple ground entrances. Two 2.6 m-wide
  stairways reach a 4.2 m-high service gantry and galleries in three buildings.
  A glasskiln service key still opens the single workshop cache room. The original
  21 m clearing is now a 45 m reserved pad, with the east/west trails routed around
  the campus. See GLASSKILN-UPDATE.md for the new floor plan and verification.
- **Helion Mirror Array**, 4–5: four angled mirror wings around a solar receiver.
  A seed-specific four-digit calibration note opens its control-room cache.
- **Obsidian Archive**, 4–5: tiered dark facade with blue clearance ribs.
  An archive clearance card opens the secure records cache.
- **Wreckwater Sump**, 2–4: open service shed, salvage tanks and elevated pipework.
  Open-access cache, reached by a trail skirting the western tank footprint.
- **Echo Cistern**, 2–3: elevated reservoir and a partitioned archive room.
  Three service valves use the clue STEAM → PRIME → RETURN (3, 1, 2). Wrong
  inputs reset progress; the clue remains in field notes. This is an early, easy
  puzzle example, not final hidden-room art or a complex puzzle system.

All required credentials/clues are in field supplies inside their own site's
clearing, outside its locked room. Exactly two sites reach quality 5. Rolls are
bounded samples, once per cache per raid; no real item tables, reward economy,
settlement inventory changes, combat, enemies or loss mechanics are implemented.

## Travel and interactions

The seven trails form a connected perimeter and cross-basin network. Both Siltway
Lift Extract (southwest) and Caldera Rim Extract (northeast) have two authored
approaches. Routes avoid the physical building and prop footprints. The shared
preflight refuses unsafe terrain before constructing the world/player, sampling
the actual mesh triangles across a 1.2 m corridor every 0.5 m or less, at a maximum
grade of 0.7. It is not an off-trail or all-configurations playability guarantee.

Cinder uses the same production movement controller and raid lifecycle as Relay:
remappable movement/map/interact, Tab notes, Escape pause, discovery and cache
ledger, code validation, physical door removal, and eight-second grounded
extraction. Leaving the markers, jumping, interacting again, opening a menu or
losing focus cancels extraction. Results are disposable. Every fresh scene resets
credentials, puzzle, loot, discovery and extraction state.

The optional ship adapter offers map selection without changing normal startup.
Both scenes expose the same readiness/failure/return contract. Save/reload and
normal rendered ship boarding still need user-run acceptance in the broader push.
See SHIP-INTEGRATION.md. Do not use production profiles for this preview.

## Launch and tune

Standalone map, with an isolated disposable profile:

```sh
XDG_DATA_HOME=/tmp/cinder-review/data \
XDG_CONFIG_HOME=/tmp/cinder-review/config \
XDG_CACHE_HOME=/tmp/cinder-review/cache \
godot --path /path/to/development-project res://raid/cinder_basin.tscn
```

Edit `cinder_settings.tres` for seed/amplitude/densities and `cinder_config.gd` for
sites, quality bands and routes. The familiar density names preserve shared test
and tooling contracts: `tree` controls juniper/yucca, `grass` samphire, `shrub`
glassplume/bonebrush/agave, and `rock` basalt stones. Each has its own deterministic RNG
stream; changing one layer's density leaves the others unchanged. POIs/routes are
fixed authored layouts, while terrain and natural placements vary by seed. Output
is pinned to Godot 4.6.3, not promised identical across different engine versions.

Default seed 611204 produces 144 terrain chunks / 73,728 triangles, 155 tall
plants, 990 samphire mats, 212 shrubs and 406 rocks in 400 natural-mesh
batches. These counts are not a frame-time/performance acceptance claim. Default
maximum sampled triangle grade is 0.3590. Numerically valid settings may still be
refused: seeds 7 and 2 at amplitude 12 exceed the travel budget. Lower amplitude
or change seed rather than disabling the travel guard.

## Automated verification

Godot 4.6.3, isolated Linux headless profiles:

- `test_cinder_contracts.gd`: 150 checks. Distinct IDs/routes, settings-driven pads,
  determinism, independent layers, exclusions, terrain, lock types, local clues,
  unique top-tier bands, once-only bounded rolls and disposable-state reset.
- `test_cinder_scene.gd`: 25 checks. Generated terrain/spawn readiness, 591 path
  support and standing-capsule samples, physical doors, UI repetition/focus and
  a 30 m traversal using the production player. Maximum sampled terrain/mesh
  discrepancy was under 2 cm.
- `test_cinder_walkthrough.gd`: 90 checks. Seven complete trails in both directions,
  all six POI approaches/doors/interiors/caches/exits, all access-item interactions,
  wrong/right code entry, valve puzzle, repeat-cache protection and both extracts.
  3,708 m walked using production movement; real camera/raycast selection followed
  by the interaction handler. Native keyboard/mouse capture was not tested.
- `test_cinder_extraction.gd`: 58 checks. Countdown and interruption, repeated input,
  stale confirmation, live ledger/results, once-only return and programmatic UI
  bounds at 1280×720 and 1440×900. Bounds checks are not rendered visual review.
- `test_cinder_extraction_schedule.gd`: 8 checks. Scheduled final-tick jump/exit
  cancellation and stationary completion after the production-motion driver.
- `test_cinder_readiness.gd`: 22 checks. Safe default, two unsafe seed/amplitude
  combinations, invalid settings, pre-world refusal and one-shot standalone/host
  return. Host check uses a test double, not real settlement save I/O.

- `test_cinder_seed_matrix.gd`: six configurations. Four safe
  configurations cover three-column support/standing-capsule samples
  and selected-segment walks through both approaches to each extraction. Two excessive-amplitude
  configurations refused entry before world activation. The matrix includes zero
  density/noise, alternate and adjacent seeds, and the maximum supported seed.

The expanded campus also adds `test_glasskiln_campus.gd`: 43 checks, 601 m of production movement,
all five building approaches, both stair directions, gallery branches and a
physical guardrail, including both edges of both side-gallery tips. These do not replace a full game regression
or rendered/native acceptance.

Run each with the same isolated XDG variables and:

```sh
godot --headless --path . --fixed-fps 60 --script res://raid/tests/test_cinder_contracts.gd
# Repeat for each named test above.
bash raid/tests/run_cinder_seed_matrix.sh /absolute/output/cinder-matrix
```

The layout preview image is generated from the real heightfield, route nodes,
POIs, spawn, extraction pads and basalt-spire placement data. It is a diagram,
not a screenshot or proof of gameplay appearance.

## Deliberate limits

Art is original procedural development geometry, not final dressed assets. Audio,
actual GPU rendering/occlusion, draw-call/frame-time budgets, native controls,
Windows export and real title → ship → raid → settlement save/reload remain
unverified. Existing source/asset guards are not weakened. No multiplayer, hazards,
ship flight animation, reward persistence, consumable access items or progression
is implied. Native/Windows playtesting is left for the user's broader update,
without requiring an incremental playtest before continued development.

## Vegetation update

The initial geological column/tussock placeholders are now replaced by six
procedural salt-basin species plus basalt rocks. Natural placement and route
exclusions remain unchanged. See [vegetation update](VEGETATION-UPDATE.md) for
scale, retained collision proxies and the source-only acceptance limits.

## Landmark art update

Helion now has framed segmented mirrors, layered pedestals, a faceted receiver
crown and a detailed control-house facade. Obsidian has four-tier basalt wings,
blue-trim facility detailing and a clearly depicted keycard reader. Existing
room/entrance geometry, targets, routes and access rules remain unchanged.
See LANDMARK-UPDATE.md for verification scope and remaining review limitations.
