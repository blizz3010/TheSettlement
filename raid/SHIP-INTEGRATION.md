# Optional ship → raid review adapter

This is an additive review candidate for the recovered Godot **4.6.3 r8**
project. The normal title/main scenes, production scripts, source-integrity
hashes, assets, foliage surveys, save schema and exact pinned r8 exporter are
unchanged. Do not include this in, or weaken, the exact-r8 build contract.

The later combined Windows review package already includes this ship route as
its default title and an explicit Launch-Ship-Selector.cmd entry. Its direct map
launchers bypass the ship. Source default startup remains unchanged. See
[current ship-flow update](SHIP-FLOW-UPDATE.md) for new real-geometry/live-map
checks and the loading-cancellation fix; this source update is not yet packaged.

## Opt-in entry

Use the recovered-source setup instructions, restored approved imports and a
**disposable development profile**. Never point this preview at production saves.
From the project directory on Linux:

```sh
XDG_DATA_HOME=/tmp/settlement-raid-review/data \
XDG_CONFIG_HOME=/tmp/settlement-raid-review/config \
XDG_CACHE_HOME=/tmp/settlement-raid-review/cache \
godot --path . res://raid/ship_title_preview.tscn
```

This starts the original title and character-selection workflow, with its
original loading/asset/collision gates. Only the world scene target changes to
an additive settlement subclass. The same candidate path is used on return.
Do not launch `ship_settlement_preview.tscn` directly: the ship requires a bound
character and fully activated world. Normal `godot --path .` remains r8.

## Interaction and lifecycle

- Walk up the existing southern ship ramp onto the deck. The candidate boarding
  point is ship-local `(0, 1.28, 4.8)`, outside the hull and southern wing.
- The normal remappable Interact key opens **Select raid**, with **Relay Ridge**
  and **Cinder Basin** as the two choices. Relay Ridge is selected initially.
  Each map has its own description and a named **Deploy to …** button. The
  prompt uses `key_label`; existing services, doors, seats, fishing, build mode
  and modal UI take priority. Opening or changing a selection does not save.
- **Cancel** or **Escape** closes the selector without departing. Cancel gets
  initial keyboard focus. The remapped Interact key is consumed before GUI
  activation, including Enter/Space bindings. Repeated input, callbacks from a
  dismissed selector and unknown map IDs cannot initiate travel. Controls are
  disabled while selecting; map, quick-load and build shortcuts are blocked.
  Focus loss cancels the selection without recapturing the mouse; a window close
  retains the original Options/quit-confirmation flow.
- **Deploy** rechecks current boarding eligibility and the character slot, save
  path and appearance snapshot. Moving away or a newer modal/startup cancellation
  invalidates the action. A fixed scene allowlist routes the selected map; UI
  strings and external paths cannot choose arbitrary scenes.
- Require grounded player, vertical/horizontal bounds, a ray hitting the actual
  `Collision/PadDeck`, and clear sight to the boarding point. No teleport or
  ship collision/mesh changes are made. Actual capsule accessibility still needs
  a rendered walkthrough.
- Commit the existing settlement save before departure. Failure keeps the player
  in the settlement and allows retry; repeat/echo input cannot duplicate departure.
- Copy the exact character slot and appearance, then free the settlement, including
  all its UI, cameras, audio and notification handlers. Hiding or detaching the
  live world is deliberately avoided. No old settlement simulates during the raid.
- The host opens the selected `relay_ridge.tscn` or `cinder_basin.tscn`,
  shows that destination in its loading status, and keeps its cover until
  `is_raid_ready()` is true, and listens for `return_requested`. Generation owns
  its own player-input/readiness barrier. The host gives up after 60 seconds of
  yielded loading. A synchronous generation stall cannot be interrupted mid-frame.
  Explicit generation failures, including the trail-grade preflight, now stop
  loading immediately and show the reason with the saved-settlement return option.
- Cancel during loading, missing/invalid raid, or raid return all offer the same
  saved-settlement path. A close request exits with the pre-departure save intact.
- Either beacon now offers an eight-second, interruptible extraction countdown
  and a disposable result summary. Return from the pause menu remains available
  as an explicit early exit; it does not count as a successful extraction.
- Return creates a **new** title loader, reselects the same slot (including current
  catalogue validation), rejects changed appearance, and runs the full original
  startup gate again. Legacy remains legacy. No intro is replayed or marked seen.
  **Return spawn is the Town Hall login, not the ship.** This deliberately reuses
  the validated login readiness route rather than inventing an unchecked ship spawn.
- If the character/save has changed or the asset gate fails, the title reports
  the problem instead of forcing activation. Normal retry/selection remains available.
- Raid loot is disposable preview state. There are no persistent rewards, losses,
  credits, inventory transfers, enemy consequences or save migration.

## Focused checks run

Godot 4.6.3:

```sh
godot --headless --path . --script res://raid/tests/test_ship_contract.gd
godot --headless --path . --script res://raid/tests/test_ship_flow.gd
godot --headless --path . --script res://raid/tests/test_ship_selection.gd
```

Use the same disposable XDG variables for tests. Results: **11 contract checks,
14 flow checks and 55 selection checks passed**. The changed adapter, selector,
catalog and transition scripts also passed `--check-only`.
The contract suite checks blocked/save-failed/repeated departure, slot and legacy
binding, deep appearance copy and boarding-zone bounds. The flow suite exercises
the actual input adapter and host with fake world/raid behavior: rebound G vs old E,
key echo, stale eligibility, failed save, duplicate activation, readiness cover,
missing/invalid/pending raid, cancellation and repeated return.

The selection suite checks both real scene factories and their public contracts,
both map choices, details, unknown IDs, Cancel/Escape, stale callbacks, changed
character/save binding, focus/quit handling, other modal ownership, save failure,
once-only deployment and Interact rebound to Enter/Space. Logical viewport bounds
are checked at 640×480, 1280×720 and 1440×900, with both actions visible and the
body allowed to scroll. These are layout assertions, not rendered screenshots.

These are **test-double checks, not a real title→ship→raid→settlement playthrough**.
The suites do not prove production save I/O, real character reload, original title
asset gates, ray/capsule clearance, native rendering, audio or full travel. Existing
headless MultiMesh readback limitations remain; guards are not bypassed to make
this candidate start. A normal rendered desktop was unavailable for acceptance.

## Required rendered acceptance before production wiring

1. Normal title launch with disposable legacy, slot 1 and slot 2 saves; confirm
   exact selected appearance, save path and settlement state before travel.
2. Walk the southern ramp, verify prompt/pad support at real capsule height,
   verify blocked/hull/ground positions do not activate; test a remapped Interact.
   Choose each map and check its details. Cancel/Escape must not save or travel;
   Deploy must show the chosen destination, not silently launch Relay Ridge.
3. Confirm all higher-priority interactions, menus, build, seating, fishing,
   focus loss, repeated clicks and echo input cannot accidentally depart.
4. Force a save failure: remain in settlement with normal camera/input/audio.
5. Travel to each map, wait for terrain/spawn readiness, walk its route, and extract.
   Verify countdown interruption by leaving/jumping, map/notes/pause and focus loss,
   then complete eight grounded seconds and inspect the result summary. Return.
   Confirm Town Hall spawn, same character, no intro replay, no duplicate UI/audio,
   unchanged saved inventory/credits and no raid loot transfer. Repeat the trip.
6. Cancel while loading; exercise missing/failed raid and failed settlement gate;
   confirm save preservation and usable retry/selection UI. Close/reopen during raid.
7. Run the unchanged baseline checks and source-integrity audit. A candidate build
   needs its own reviewed manifest/export procedure, never an altered r8 pin.

To remove this integration, stop choosing `ship_title_preview.tscn`. No default
scene setting, baseline script or persistent save-format change needs undoing.
