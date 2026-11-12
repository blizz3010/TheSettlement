# Ship boarding and loading acceptance update

November 11, 2026. Additive source candidate on the Research Annex combination.
The previous combined Windows review package already contains the ship selector.
This update strengthens automated verification and fixes cancelled-load cleanup.
It is not a new Windows build or native playtest approval.

## Existing playable review route

In the combined Windows review package, the EXE's default scene is the
ship-enabled title. Launch-Ship-Selector.cmd explicitly chooses the same route.
The two direct map launchers skip the settlement and ship for quick map testing.
The source project's unchanged default scene is still the original r8 title.

Use a disposable profile. Select a character, enter the settlement, walk up the
ship's southern ramp, and use the remappable Interact key to select Relay Ridge
or Cinder Basin. Cancel does not save or travel. Deploy rechecks eligibility,
saves the settlement, and loads the chosen map behind a readiness cover.
Extraction returns through the same-character title loader at Town Hall.
Raid keys, sample cache rolls and discovery progress remain session-only.

## Changes

- The existing physical boarding predicate is now a separate method called by
  the unchanged eligibility chain. No startup, grounded, character, modal,
  mouse-capture, service-priority, save or geometry guard was removed.
- Map initialization now uses two node-bound, one-shot physics-frame callbacks
  instead of leaving _ready suspended across two awaits. The same collision and
  capsule checks still run before activation. Freeing a loading map disconnects
  its callbacks automatically.
- This fixes a reproduced Godot 4.6.3 cancellation leak: freeing a map during the
  old suspended initialization retained temporary game-settings resources and a
  Variant stack, producing resource/PagedAllocator shutdown errors. Moving the
  settings object alone was insufficient; removing the suspended stack resolves
  the tested cancellation cases.
- Ship mesh/collision, maps, loot rules, saves, normal r8 scripts and guard
  fingerprints remain unchanged. Only the additive raid code is changed.

## New focused tests

- test_ship_boarding_geometry.gd uses the actual ship assembly and collision,
  unchanged production player movement, and production physical predicate. It
  walks up and down the existing southern ramp in three lanes at 2.4, 4.2 and
  7 m/s, checks real deck support, and rejects off-deck and obstructed positions.
  Its flat ground is a small fixture, not the full settlement.
- test_ship_live_maps.gd loads both actual generated maps through the real ship
  transition host. It checks the two-physics-tick readiness barrier, selected
  scene, active camera/player, duplicate opening, the actual map return signal,
  and loading cancellation both immediately and after the first physics tick.
  Only final title restoration is intercepted. It does not exercise settlement
  save I/O, the full title asset gate, or a real save reload.
- Both are included in run_relay_candidate_checks.py with the existing map,
  ship, extraction, UI, building, asset and seed-matrix suites. A pass requires a
  valid result marker, successful exit and no runtime error lines.

## Still required

1. A normal rendered Windows title → character → physical ship interaction →
   each raid → extraction → same-character Town Hall return, including repeated
   trips, focus changes, loading cancellation and disposable save integrity.
2. Native controls, lighting, glass, audio mix, performance and ordinary quitting.
3. A fresh candidate package and actual packed-code rechecks before distributing
   this source update as a new Windows review. The previous ZIP is unchanged.
4. Production gameplay remains separate: enemies/combat/damage, real item drops,
   persistent loot transfer and death/loss rules, economy/progression, multiplayer,
   and animated boarding/departure are not added here.

Neither the physics fixtures nor the existing automated map walkthroughs count
as a native/full-game approval. Do not bypass the original settlement gates or
use production saves to force acceptance.
