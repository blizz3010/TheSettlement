# settlement_inn_door: Inn front doors (two-leaf main door + east side door)

Built Thu Nov 19 2026 ~10:38 PM (America/New_York). Blender 4.2.9 -> glTF 2.0 (separate .gltf + .bin + `textures/`), checked in Godot 4.6.3 (Compatibility renderer, strict back-face culling). Near-future look, mid-to-high poly, original English branding only (none (no text or logos); no real brands). Hand LODs, hand `_col` (doors included), `mk_*` markers, no lights or scripts inside the assets.

## What is here
- **Design (mine, original):** plank-and-batten doors with iron strap hinges, a lattice-glazed upper panel (the front door) and bronze kick plates, in the settlement's timber / iron / bronze look. **Measured against the repo as built on main (HEAD 8d862ff, read-only):** the Inn front wall is at inn-local z = -5.9 (faces -Z), 0.20 thick (z -6.0 .. -5.8); the main doorway is a clear x -1.2 .. 1.2, 2.6 m tall with **no door leaf** (`inn_architecture.gd`: `EntryLintel` 2.4 x 0.5 x 0.20 at y 2.85, porch posts x +-2.45 / z -8.0, lanterns at (+-1.55, 2.35, -6.15)); the side door is in the east wall x = 7.8, z 1.375 .. 2.625 (1.25 wide, 2.6 tall; `inn_front_v087.gd`: `SideDoorLintel` above it), with cosmetic exterior jambs at x 7.93 and `SideEntryLantern` at (7.98, 2.1, 3.1). Inn-local y = 0 is the floor top; the Inn node sits at world (0, 3.4, 52.7).
- `settlement_inn_door_main`: the **2.4 x 2.6 m two-leaf front door**. Origin = centre of the doorway at floor level, the wall plane is z = 0 (wall faces at z +-0.10), **outside = +Z**. Leaves are separate nodes `leaf_l` / `leaf_r` (1.19 m each) with **pivots at the hinges (x = -1.2 / +1.2, y 0, z 0)**: rotate Y to open (left: negative angle, right: positive angle opens outward, about 100 deg max; the previews use +-100). Each leaf: stiles / rails, vertical plank infill with V joints, lattice-glazed upper panel (flat emissive lamp glass), three strap hinges with studs, hinge knuckles, kick plate, ledges on the inside; the right leaf carries the bronze ring pull, rosette, latch and escutcheon. Fixed parts: outside and inside surround (jambs, header with cap, corbels, pintle plates) that stand 4.5 cm proud of the wall faces **outside** the clear opening, plus a bronze threshold plate.
- `settlement_inn_door_side`: the **1.25 x 2.6 m single-leaf east door** (plank infill, no glazing), leaf node `leaf` with its **pivot at the hinge (x = -0.625)**, the inside surround only (the repo's exterior jambs / header stay), threshold plate. Placed with rot Y +90 deg it faces +X.
- **How they fit (inn-local):** main door `position (0, 0, -5.9)`, `rotation.y = 180 deg` (asset +Z -> inn -Z; world (0, 3.4, 46.8)). Side door `position (7.8, 0, 2.0)`, `rotation.y = +90 deg` (asset +Z -> inn +X; world (7.8, 3.4, 54.7)). The clear opening of both assets equals the repo opening exactly (2.4 / 1.25 wide, 2.6 tall); the main door's header (y 2.6 .. 2.74, x +-1.46) sits in front of the lower edge of the repo's `EntryLintel` (proud 4.5 cm both sides, no z-fight); the lanterns, porch posts and the repo's exterior side jambs are untouched (`mk_light_l/r` = (+-1.55, 2.35, +0.25) are the lantern positions in asset frame).
- Collision: `settlement_inn_door_main_leaf_l_col` / `_leaf_r_col` and `settlement_inn_door_side_leaf_col` are children of the leaf nodes (they swing with the leaf). The frame has none: the repo's wall collision stays as built and the opening stays clear. Open the leaves (or disable the leaf colliders) to let the player walk through.
- `textures/`: nothing new, byte copies of earlier hand-off sets (`screens_planters` sp_timber, `city_atm` ct_dark, `tailor_dyes_stall` tds_metal); `tools/collect_textures.sh` copies them. The bronze / iron / plank variants are tinted with base-colour factors; no 2048 set.

2 glTF + .bin pairs, 9 textures, 17 previews (JPEG q88), about 3.2 MB.

## Numbers (Godot import counts; all LODs, every node)
| Asset | LOD0 / LOD1 / LOD2 tris | `_col` tris | Materials | Draws LOD0 (est) | Texture VRAM MB (unc / comp est) |
|---|---|---|---|---|---|
| settlement_inn_door_main | 8,096 / 852 / 60 | 24 | 5 (SS_Timber, SS_Bronze, SS_Plank, SS_LampGlass, SS_Iron) | 13 | 50.3 / 12.6 |
| settlement_inn_door_side | 4,192 / 508 / 24 | 12 | 4 (SS_Timber, SS_Bronze, SS_Plank, SS_Iron) | 6 | 50.3 / 12.6 |

Per-asset VRAM counts shared textures once per asset; the whole folder is **50.3 MB uncompressed / 12.6 MB compressed est. (3.4% / 0.8% of the Low 1.5 GB budget)**. New in this folder: no new texture set (0 MB uncompressed new to the city). Every texture is a byte-for-byte copy from an earlier hand-off (screens_planters, city_atm, tailor_dyes_stall); no new 2048.

**Store totals vs doc budget (no per-prop budget in the docs for settlement doors; own ceiling 30k LOD0 / 6k LOD1 for the pair (mid-high poly)):**
- Shell + interior: **12,288 / 1,360 / 60** tris, 19 draws at LOD0 (est.).
- Fully dressed as in the previews (both doors of the Inn: the 2-leaf front door and the east side door): **12,288 LOD0 / 1,360 LOD1**, about 19 draws at LOD0 / 17 at LOD1 without instancing. Target own ceiling 30k LOD0 / 6k LOD1 (no doc budget): **LOD0 inside the range, LOD1 inside the budget**.
- City-wide texture VRAM over all hand-offs: **734.0 MB uncompressed / 183.5 MB compressed est.** (plan target 200 / 60; the held pavers / brick / asphalt cuts are not applied).

## Conventions
+Y up, front = +Z, 1 unit = 1 m, 1.75 m adult. Nodes `<id>_LOD0/_LOD1/(_LOD2)`, `<id>_col` hidden via KHR_node_visibility (Godot: hidden MeshInstance + StaticBody3D / Concave); door leaves (and any other moving part) carry `<id>_<leaf>_col` parented to the leaf so collision moves with it. Interaction markers: +Z faces the player. Stand / seat markers (`mk_npc_*`, `mk_seat_*`, `mk_cook_*`): +Z = actor facing. `mk_prop_*`: +Z = the way the prop faces. Door frame: origin = doorway centre at floor level, wall centre plane z = 0, outside = +Z, leaf pivots at the hinges.

## Markers
Main door: `mk_door_hinge_l` / `mk_door_hinge_r` (hinge axes, +Y), `mk_door_handle`, `mk_door_interact_out` / `mk_door_interact_in` (+Z faces the player), `mk_door_stand_out` / `mk_door_stand_in` (1.1 m from the wall, +Z = actor facing), `mk_light_l` / `mk_light_r` (lantern mounts), `mk_pane_glow_l` / `mk_pane_glow_r` (interior glow behind the lattice). Side door: `mk_door_hinge`, `mk_door_handle`, `mk_door_interact_out/in`, `mk_door_stand_out/in`, `mk_light`. Every `mk_light_*` is a lamp mount: no light nodes are inside the assets.

## Day / night
Every material reads in full daylight. The only emissive surface is the lamp glass (SS_LampGlass: flat warm `#ffc174`, the same warm amber as the repo's lantern glow, emission energy 0.65) in the lattice panes of the front door: it ships lit; by day the game scales `emission_energy_multiplier` down (to about 0.15-0.2) and at dusk back up. The assets contain no light nodes: put a warm OmniLight3D at `mk_light_l` / `mk_light_r` / `mk_light` at dusk, and (optionally) a small one behind `mk_pane_glow_l/r` on the inside.

## Checks
- Godot 4.6.3 import of every file (`check_result.json`): meshes, nodes, markers, materials, `_col` bodies (incl. under-leaf bodies), culling.
- Strict back-face culling renders: 17 previews in `previews/` (front door closed / open / hardware close-ups, inside view, side door closed / open, LOD1 / LOD2; day and dusk), each with the 1.75 m adult capsule and the road kit (cream inn wall, porch, 1.75 m adults).
- Winding check (`winding.json`): 2 / 2 pass.
- Rebuild (`rebuild_check.json`): two fresh builds and a build from the shipped tools are byte-identical on every file; the textures are byte-identical to the copies in `screens_planters`, `city_atm` and `tailor_dyes_stall`.

## Rebuild
`sh tools/build_all.sh <out_dir>` (Blender 4.2.9 + Pillow), `sh tools/run_godot_checks.sh <handoff> <scratch> <out>`, `sh tools/run_previews.sh <handoff> <scratch> <out>`, `sh tools/rebuild_check.sh <handoff> <scratch> <out.json>`, `python3 tools/finalize_report.py <handoff>`. Textures: nothing is generated here; `tools/collect_textures.sh <dest> [handoff_root]` copies the reused sets byte for byte.
