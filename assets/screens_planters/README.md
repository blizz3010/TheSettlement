# screens_planters — woven board/screen + plaza planters (visualpass P2 "Boxy thatch/wicker screens and flat-lid planters")

Original designs. glTF separate (.gltf + .bin), shared textures in `textures/` (5 sets × base/ORM/normal, 1024²,
ORM = R occl / G rough / B metal, OpenGL normal). Meters, +Y up, origin base centre on the ground, front = +Z.
Each file: `<id>_LOD0`, `<id>_LOD1` (~40%), `<id>_col` (simple boxes, hidden with KHR_node_visibility; Godot 4.6
still builds the StaticBody3D and the visible mesh stays hidden; verified).

| asset_id | replaces | LOD0 | LOD1 | col | size x × h × z (m) |
|---|---|---|---|---|---|
| request_board_woven | midstyle_rollout2/request_board.gltf (26.1k tris) | 6,124 | 2,448 | 36 (3 boxes) | 2.04 × 2.22 × 0.36 |
| woven_screen | — (optional freestanding hurdle screen) | 5,524 | 2,208 | 12 | 1.36 × 1.80 × 0.11 |
| plaza_planter | kit/planter.glb (6,428 tris) | 3,612 | 1,443 | 12 | 1.49 × 1.13 × 1.49 (pot 1.0 × 0.56 × 1.0) |
| plaza_planter_fern | kit/planter_fern_variant.glb (4,556 tris) | 6,796 | 2,718 | 12 | 1.27 × 1.03 × 1.28 (pot 1.0 × 0.56 × 1.0) |

## What the "thatch screens" are
There is no screen asset in the repo. The tall "thatch/wicker screen" in shots 38/41/45 is the plaza **RequestBoard**
(settlement.gd: `BOARD = Vector3(-5.8,0,-9.1)`, yaw `atan2(-x,-z)`, faces the fountain), drawn by
`raid/scripts/midstyle_rollout2.gd` with `assets/midstyle_rollout2/request_board.gltf`. Its back is a flat streaky
timber slab, which looks like a thatch box from the hall/fountain side. `request_board_woven` keeps that envelope
(posts ±0.92, panel 0.60–1.70, header 1.74–2.10, roof to 2.22, front notices) and replaces the slab with a
framed over/under splint weave you can see through from both sides. `woven_screen` is the same weave as a freestanding
hurdle, for the plaza-edge grass strips if you want real screens there.

## Planters
Same pot as the kit: limestone body 0.9 sq, coping 1.0 sq, top at 0.56. The soil is now a shallow textured
dish (0.47 at the rim rising to ~0.50) sitting about 6–9 cm below a mitred timber coping with bronze corner
caps, with a few pebbles. It is no longer a flat lid at 0.575. Foliage is original and kept inside the old plan
envelope (planter ±0.75, fern ±0.65 vs old ±0.81 / ±0.66). It is about 0.45 m lower than the old planting
(1.13 / 1.03 vs 1.61 / 1.54). plaza_planter leaves a clear centre for the ring-planter lantern that settlement.gd
puts at +0.2 m.

## Integration notes / flags
- **Paths and filename checks.** `settlement.gd asset()` loads `res://assets/kit/<file>.glb`. Four scripts find
  planters by `scene_file_path` ending in `/planter.glb` or `/planter_fern_variant.glb`:
  `west_path_planter_clearance.gd` (asserts exactly 1 match per move), `market_landscape.gd`,
  `settlement_terrain.gd` (×2) and `plaza_lantern_reconciliation.gd`. Update those checks, or wrap the new
  gltf in scenes saved under the old names. I checked the new bounds against the west_path asserts and they still pass.
- **style_courtyard().** It only re-materials `Limestone_*` / `Weathered_Bronze`. The new materials are `SP_*`,
  so the new textures are kept.
- **Two visible LOD nodes.** LOD0 and LOD1 are separate nodes and both import visible. Set visibility_range
  (e.g. LOD0 0–20 m, LOD1 20 m+) or hide LOD1. midstyle_rollout2 `_triangles()` counts both.
- **Planter collision is new.** The kit planters had none (players walk through). `_col` is a 1.0 × 0.56 × 1.0 box.
  Drop it if planters must stay walk-through.
- **RequestBoard collision.** The original 1.8 × 1.5 × 0.15 collider stays when midstyle_rollout2 swaps the art,
  so this file's `_col` would duplicate it (harmless overlap). Ignore one of them.
- **No triangle caps** apply to these props. Totals: the plaza ring (7 planter + 8 fern) is ~79.6k LOD0 vs ~81.4k
  before, and the board is 6.1k vs 26.1k.

## Rebuild
    python3 build/make_textures_sp.py                 # ./textures next to the script (or pass a dir)
    SP_TEX=<textures dir> blender -b --factory-startup -P build/build_screens_planters.py -- <out_dir> [ids]
    blender -b --factory-startup -P build/render_previews.py -- <out_dir> <preview_dir> [views] [samples] [LOD0|LOD1]
    python3 build/make_report.py <handoff_dir>
Blender 4.2.9; Cycles previews 128 spp, JPEG q88; validated in Godot 4.6.3.

## Previews
- previews/screens_planters_lineup.jpg — woven_screen, request_board_woven, plaza_planter (+ kit lantern), plaza_planter_fern
- previews/screens_planters_weave_close.jpg — weave + notices close-up
- previews/screens_planters_planter_close.jpg — soil dish, rim, planting
- previews/screens_planters_scale_beside_reference.jpg — old kit planter + midstyle board (left) vs new (right), Dan for scale
- previews/extra/screens_planters_board_back.jpg (back side, the angle from shots 38/41), screens_planters_lineup_LOD1.jpg
