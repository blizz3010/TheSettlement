# settlement_inn_undercroft: Inn balcony undercroft (bays, pile dressing, landing, props)

Built Thu Nov 19 2026 ~10:49 PM (America/New_York). Blender 4.2.9 -> glTF 2.0 (separate .gltf + .bin + `textures/`), checked in Godot 4.6.3 (Compatibility renderer, strict back-face culling). Near-future look, mid-to-high poly, original English branding only (none (no text or logos); no real brands). Hand LODs, hand `_col` (doors included), `mk_*` markers, no lights or scripts inside the assets.

## What is here
- **Design (mine, original):** the underside of the Inn balconies dressed as a working boat landing: sway-braced piles, bearers and joists under the slab, a **hung service landing** (deck boards on bearers hung from the joists by iron rods) 0.5 m above the lake with bollards, and props for it (hung rowboat, hung lanterns, dock ladder, barrels, crates and sacks, crab pots, net rack, shelf unit). Weathered dark timber (`SS_Pile`) for the structure, the lighter settlement timber / plank for the landing and props.
- **Measured against the repo as built on main (HEAD 8d862ff, read-only; `inn_lake_v088.gd`, `inn_joined_decks_v098.gd`):** Inn node at world (0, 3.4, 52.7); rear balcony slab x -8.7..12, z 58.7..63 (inn-local z 6.0 .. 10.3), east balcony x 7.9..12, z 53..58.7; slab y 3.12 .. 3.38 (inn-local y -0.28 .. -0.02), water y 0.65, lake bed about -0.6. Existing piles (untouched, **not duplicated**): rear row r 0.28 at x -8 / -4 / 0 / 4 / 8, z 62.6; extended supports r 0.35 at x -8.7 / 0 / 8.7, z 60; east row r 0.28 at x 11.6, z 53.3 / 56.5 / 59.8; corner pile r 0.35 at (11.6, 62.6); pile tops y 3.30. The balconies are bare slabs on those piles (no bearers, joists, braces or landing), so everything below is new geometry that fits around them.
- **Bay frame:** origin x = bay centre, **y = 0 at the underside of the slab (world 3.12)**, z = 0 at the Inn wall face, +Z out over the lake (the slab edge is at z = D). The girder line z = D - 0.4 is exactly the repo's pile line (rear 3.9 = 62.6 - 58.7; east 3.7 = 11.6 - 7.9).
- `settlement_inn_undercroft_bay_4m` (4.0 x 4.3): rim beam on the slab edge, wall plate, 9 joists on a 0.4 m grid, noggins, an outer girder that butts the piles (x +-1.72), knee braces with iron plates, X sway braces between the piles, the hung landing (deck 1.8 m deep, top at y -1.97 = world 1.15, 0.5 m above the water; edges clear every existing pile), 3 bearers, 6 hanger rods with nuts and washers, toe board, 2 bollards. **Fits the rear run: place at world (cx, 3.12, 58.7), rot 0, cx = -6, -2, 2, 6 (x -8..8; a fifth at cx = 10 covers 8..12: its end pile is at 11.6 instead of 12, the girder end just disappears inside that pile).**
- `settlement_inn_undercroft_bay_3p25` (3.25 x 4.1, landing 1.85 m deep): same parts for the east run, rotated: place at world (7.9, 3.12, 54.925) and (7.9, 3.12, 58.15) with **rot Y +90 deg** (local +Z -> +X world, i.e. out over the lake); the repo's pile spacing there is 3.2 / 3.3 m, the 3.25 bay is within 5 cm.
- `settlement_inn_undercroft_pile_dressing_28` / `_35`: iron cap bands, bracket plates where the braces land (y -1.0), rope chafe wraps, and a staved waterline fender with two bands, for a pile of r 0.28 / 0.35. Origin = pile centre at slab underside height; place at each existing pile (x, 3.12, z). It wraps the pile; the pile mesh itself is the repo's.
- Props (origin on the landing top y = 0 unless noted): `barrel_stack` (6 barrels 3+2+1, chocks, runners), `crate_stack` (4 crates, 4 sacks, rope coil), `crab_pots` (3 wicker pots, 2 buoys, rope), `net_rack` (A-frames, rail, draped net with floats and lead weights), `shelf_unit` (1.6 x 0.42 x 1.9, jars, baskets, bottles, kegs), `boat_hung` (3.0 m clinker rowboat hung keel-up from two rope slings; **origin y = 0 at the joist underside**, hooks at x +-0.8 on joist lines), `lantern_hung` (chain, bronze cap, iron cage, flat emissive glass; origin = hook point, hung from the girder underside), `ladder_dock` (rails with deck hooks, 7 rungs, from 0.78 m above the landing to 1.0 m below it, into the water).
- **Clearances:** headroom over the landing 1.79 m (joist bottom -0.18 to deck -1.97, so the 1.75 m adult fits); landing 1.8 m deep, rods and bearers keep 0.25 m to the girder; no part of the bay enters the repo's pile cylinders.
- Collision: bays `_col` = landing slab (walkable), toe board, girder, rim beam, wall plate; props one to three boxes; piles / water are the repo's. Joists, braces and rods are visual only.
- `textures/`: nothing new, byte copies of earlier sets (`screens_planters` sp_timber + sp_wicker, `city_atm` ct_dark, `tailor_dyes_stall` tds_metal + tds_stone); `tools/collect_textures.sh` copies them. Weathering / rope / burlap are base-colour factors, no 2048 set.

12 glTF + .bin pairs, 15 textures, 18 previews (JPEG q88), about 7.2 MB.

## Numbers (Godot import counts; all LODs, every node)
| Asset | LOD0 / LOD1 / LOD2 tris | `_col` tris | Materials | Draws LOD0 (est) | Texture VRAM MB (unc / comp est) |
|---|---|---|---|---|---|
| settlement_inn_undercroft_barrel_stack | 8,024 / 2,576 / 48 | 36 | 3 (SS_Timber, SS_Iron, SS_Pile) | 3 | 33.6 / 8.4 |
| settlement_inn_undercroft_bay_3p25 | 5,280 / 536 / 36 | 60 | 4 (SS_Pile, SS_Iron, SS_Plank, SS_Timber) | 4 | 33.6 / 8.4 |
| settlement_inn_undercroft_bay_4m | 5,716 / 560 / 36 | 60 | 4 (SS_Pile, SS_Iron, SS_Plank, SS_Timber) | 4 | 33.6 / 8.4 |
| settlement_inn_undercroft_boat_hung | 4,888 / 884 / 24 | 12 | 4 (SS_Timber, SS_Plank, SS_Rope, SS_Iron) | 4 | 50.3 / 12.6 |
| settlement_inn_undercroft_crab_pots | 4,688 / 756 / 36 | 36 | 4 (SS_Wicker, SS_Rope, SS_Timber, SS_Iron) | 4 | 50.3 / 12.6 |
| settlement_inn_undercroft_crate_stack | 5,340 / 1,256 / 48 | 36 | 4 (SS_Plank, SS_Timber, SS_Burlap, SS_Rope) | 4 | 33.6 / 8.4 |
| settlement_inn_undercroft_ladder_dock | 888 / 192 / 36 | 12 | 2 (SS_Timber, SS_Iron) | 2 | 33.6 / 8.4 |
| settlement_inn_undercroft_lantern_hung | 1,236 / 548 / 36 | 0 | 3 (SS_Iron, SS_Bronze, SS_LampGlass) | 3 | 33.6 / 8.4 |
| settlement_inn_undercroft_net_rack | 5,720 / 1,096 / 48 | 24 | 5 (SS_Pile, SS_Timber, SS_Rope, SS_Wicker, SS_Iron) | 5 | 50.3 / 12.6 |
| settlement_inn_undercroft_pile_dressing_28 | 2,916 / 760 / 128 | 0 | 3 (SS_Iron, SS_Rope, SS_Pile) | 3 | 50.3 / 12.6 |
| settlement_inn_undercroft_pile_dressing_35 | 2,916 / 760 / 128 | 0 | 3 (SS_Iron, SS_Rope, SS_Pile) | 3 | 50.3 / 12.6 |
| settlement_inn_undercroft_shelf_unit | 8,596 / 1,876 / 108 | 12 | 8 (SS_Pile, SS_Plank, SS_Stone, SS_Wicker, SS_Iron, SS_Rope, SS_Bronze, SS_Timber) | 8 | 83.9 / 21.0 |

Per-asset VRAM counts shared textures once per asset; the whole folder is **83.9 MB uncompressed / 21.0 MB compressed est. (5.6% / 1.4% of the Low 1.5 GB budget)**. New in this folder: no new texture set (0 MB uncompressed new to the city). Every texture is a byte-for-byte copy from an earlier hand-off (screens_planters, city_atm, tailor_dyes_stall); no new 2048.

**Store totals vs doc budget (no per-prop budget in the docs for the undercroft; own ceiling for the dressed 16 m run: 120k LOD0 / 30k LOD1 (mid-high poly, mostly instanced repeats)):**
- Shell + interior: **16,828 / 2,616 / 36** tris, 14 draws at LOD0 (est.).
- Fully dressed as in the previews (the 16 m rear run as in the previews: 4 x bay_4m (x -8..8), 5 x pile_dressing_28 + 1 x pile_dressing_35, 2 shelf units, 2 barrel stacks, 2 crab-pot sets, 8 hung lanterns, 2 hung rowboats, 3 dock ladders (the east run of 2 x bay_3p25 is not counted)): **105,304 LOD0 / 23,944 LOD1**, about 102 draws at LOD0 / 96 at LOD1 without instancing. Target own ceiling 120k LOD0 / 30k LOD1 (no doc budget): **LOD0 inside the range, LOD1 inside the budget**.
- City-wide texture VRAM over all hand-offs: **734.0 MB uncompressed / 183.5 MB compressed est.** (plan target 200 / 60; the held pavers / brick / asphalt cuts are not applied).

## Conventions
+Y up, front = +Z, 1 unit = 1 m, 1.75 m adult. Nodes `<id>_LOD0/_LOD1/(_LOD2)`, `<id>_col` hidden via KHR_node_visibility (Godot: hidden MeshInstance + StaticBody3D / Concave); door leaves (and any other moving part) carry `<id>_<leaf>_col` parented to the leaf so collision moves with it. Interaction markers: +Z faces the player. Stand / seat markers (`mk_npc_*`, `mk_seat_*`, `mk_cook_*`): +Z = actor facing. `mk_prop_*`: +Z = the way the prop faces. Bay frame: x along the bay, y = 0 at the slab underside, z = 0 at the Inn wall face, +Z out over the lake.

## Markers
Bays: `snap_start` / `snap_end` (bay ends, out along -X / +X), `mk_deck_underside`, `mk_waterline` (y -2.47), `mk_pile_a` / `mk_pile_b` (pile centres at the bay ends on the girder line), `mk_landing_walk`, `mk_stand_landing` (+Z = actor facing the lake), `mk_swim_exit`, and prop slots `mk_prop_<id>_<n>` (+Z = the way the prop faces): bay_4m has `shelf_unit_1`, `barrel_stack_1`, `crab_pots_1`, `boat_hung_1`, `lantern_hung_1/2`, `ladder_dock_1`; bay_3p25 has `crate_stack_1`, `net_rack_1`, `boat_hung_1`, `lantern_hung_1/2`, `ladder_dock_1`. Pile dressings: `mk_pile_axis`, `mk_brace_x_pos/neg`, `mk_lantern_hook` (a lantern arm is modelled). Props: `mk_stand`, `mk_loot` (barrels, crates, pots, net rack, shelf); boat: `mk_hook_a/b`, `mk_loot`; lantern: `mk_light`, `mk_lamp_lit`; ladder: `mk_climb_top`, `mk_climb_bottom`, `mk_swim_exit`. Every `mk_light` is a lamp mount: no light nodes are inside the assets.

## Day / night
Every material reads in full daylight. The only emissive surface is the lamp glass of `lantern_hung` (SS_LampGlass: flat warm `#ffc174`, the repo's lantern glow colour, emission energy 0.65): it ships lit; scale `emission_energy_multiplier` down by day (the previews use 0.2 by day, 1.6 at dusk). The assets contain no light nodes: put a warm OmniLight3D (previews: 2.6 energy, 7.5 m, `#ffb366`) at every `mk_light` marker of each lantern at dusk.

## Checks
- Godot 4.6.3 import of every file (`check_result.json`): meshes, nodes, markers, materials, `_col` bodies (incl. under-leaf bodies), culling.
- Strict back-face culling renders: 18 previews in `previews/` (rear run from the lake / from above / from the landing with an adult / underside along the wall gap / props, east run, prop sheet, LOD1 / LOD2; day and dusk), each with the 1.75 m adult capsule and the road kit (Inn wall, slab, existing piles, lake).
- Winding check (`winding.json`): 12 / 12 pass.
- Rebuild (`rebuild_check.json`): two fresh builds and a build from the shipped tools are byte-identical on every file; the textures are byte-identical to the copies in `screens_planters`, `city_atm` and `tailor_dyes_stall`.

## Rebuild
`sh tools/build_all.sh <out_dir>` (Blender 4.2.9 + Pillow), `sh tools/run_godot_checks.sh <handoff> <scratch> <out>`, `sh tools/run_previews.sh <handoff> <scratch> <out>`, `sh tools/rebuild_check.sh <handoff> <scratch> <out.json>`, `python3 tools/finalize_report.py <handoff>`. Textures: nothing is generated here; `tools/collect_textures.sh <dest> [handoff_root]` copies the reused sets byte for byte.
