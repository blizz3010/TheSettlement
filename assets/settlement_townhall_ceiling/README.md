# settlement_townhall_ceiling: Town Hall ceiling (trusses, coffered liner) and hanging lamps

Built Thu Nov 19 2026 ~10:57 PM (America/New_York). Blender 4.2.9 -> glTF 2.0 (separate .gltf + .bin + `textures/`), checked in Godot 4.6.3 (Compatibility renderer, strict back-face culling). Near-future look, mid-to-high poly, original English branding only (none (no text or logos); no real brands). Hand LODs, hand `_col` (doors included), `mk_*` markers, no lights or scripts inside the assets.

## What is here
- **Design (mine, original):** a king-post timber ceiling for the nave (dark oiled oak): five trusses at the nave column lines (principal rafters following the roof, tie beam on the column caps, king post with braces, arch braces to the columns, aisle ties to the wall plates, iron straps and bronze pegs), between them a **coffered liner** (planked underlay under the roof slab, framed coffers with bronze bosses, ridge beam, break rails, wall plates), a **ridge chandelier** (8 + 4 lit lamp cages on a bronze ring, chain from the ridge) and **aisle pendant lanterns** hung from the purlin lines.
- **Measured against the repo as built on main (HEAD 8d862ff, read-only; `town_hall_geometry.gd`, `hall_review_finish.gd`, `hall_lantern_mounts.gd`):** Town Hall anchor (0, 0, -23) (the repo's y is absolute: floor top 0.24); walls at x +-8.8, 0.4 thick (interior +-8.6); roof slab 0.16 thick, whose underside profile is **y 6.2 at |x| 9.5, 7.1 at |x| 3, 9.0 at x 0** (the code's four segments; the roof is the dark bare underside the hall currently shows); nave columns 0.25 square at x +-3, z -14.5 / -18.7 / -23 / -27.3 / -31.5, tops y 7.05; runtime purlins (section 0.09 x 0.14, length 18.1) at |x| 1.5 / 5.0 / 7.6 with their centre at the profile y - 0.065; the existing amber lanterns at (+-3, 4.75, -17 / -23 / -29) hang on bronze rods up to y 7.10 with 0.18 x 0.06 rosettes (z -17 / -29); the west gallery deck is y 3.65 .. 4.0 with bookcases to 5.66.
- **Frame:** x across, **y = absolute height in the repo frame** (so the assets are placed at y = 0), z along the hall, origin = the module centre (a truss line or the middle of a bay), front +Z (entry side).
- `settlement_townhall_ceiling_truss` (depth 0.26 along z): one truss. **Place at (0, 0, z_world) for z = -14.5, -18.7, -23, -27.3, -31.5** (anchor-local z = +8.5, +4.3, 0, -4.3, -8.5). Rafter tops sit 5 cm under the slab, the tie beam (y 6.80 .. 7.04, x +-3.2) sits on the column caps (the column top 7.05 ends 1 cm above it), aisle ties at y 5.98 .. 6.18 run from the column faces (x +-3.12) to the wall faces (x +-8.56): 0.32 m above the gallery bookcases and 0.95 m over the lanterns' tops.
- `settlement_townhall_ceiling_bay_4p2` / `_bay_4p3`: the liner between two truss lines (4.2 / 4.3 m centre to centre, minus the 0.26 truss depth and a 4 mm gap). **Place bay_4p2 at z = -16.6 and -29.4, bay_4p3 at z = -20.85 and -25.15** (anchor-local +6.4 / -6.4 and +2.15 / -2.15). The underlay planking sits 1.5 .. 4.5 cm under the slab and spans wall to wall (x +-8.6); coffer frames stay 2.5 cm clear of the repo's runtime purlins (the purlins pass in front of the underlay and are not duplicated); a break rail at |x| 3 (the roof knee) and a ridge beam at x 0; wall plates at |x| 8.49 .. 8.6 (y 6.08 .. 6.31, under the slab at the wall). The break rail lies right under the existing lantern rods / rosettes at (+-3, z -17 / -29), so the rods now read as hung from the rail.
- `settlement_townhall_ceiling_lamp_chandelier`: ring chandelier, origin = the attach point at the ridge beam underside; the ceiling plate is at y 8.72 (hall frame), lamp ring at about y 5.2 (5 m over the floor), 1.4 m across. Slots: `mk_prop_lamp_chandelier_1` in the two 4.3 m bays (z -20.85 / -25.15).
- `settlement_townhall_ceiling_lamp_pendant`: bronze-capped iron lantern (0.28 m, chain 0.55 m), origin = the hook; slots `mk_prop_lamp_aisle_1/2` at (+-5.0, purlin underside y, bay centre) in every bay (8 in total); the glass bottom is about 1.2 m under the hook (y 5.5).
- Collision: none, everything is above 5.2 m (the repo's roof-slab collision stays). Nothing touches the walkable space; the lowest part is the aisle tie at y 5.98.
- `textures/`: nothing new, byte copies of earlier sets (`screens_planters` sp_timber, `city_atm` ct_dark, `tailor_dyes_stall` tds_metal); dark oak / bronze / plank are base-colour factors. No 2048 set.

5 glTF + .bin pairs, 9 textures, 12 previews (JPEG q88), about 4.6 MB.

## Numbers (Godot import counts; all LODs, every node)
| Asset | LOD0 / LOD1 / LOD2 tris | `_col` tris | Materials | Draws LOD0 (est) | Texture VRAM MB (unc / comp est) |
|---|---|---|---|---|---|
| settlement_townhall_ceiling_bay_4p2 | 6,000 / 1,068 / 60 | 0 | 4 (SS_Plank, SS_Oak, SS_Bronze, SS_Iron) | 4 | 50.3 / 12.6 |
| settlement_townhall_ceiling_bay_4p3 | 6,000 / 1,068 / 60 | 0 | 4 (SS_Plank, SS_Oak, SS_Bronze, SS_Iron) | 4 | 50.3 / 12.6 |
| settlement_townhall_ceiling_lamp_chandelier | 8,864 / 3,240 / 48 | 0 | 3 (SS_Iron, SS_Bronze, SS_LampGlass) | 3 | 33.6 / 8.4 |
| settlement_townhall_ceiling_lamp_pendant | 1,128 / 680 / 36 | 0 | 3 (SS_Iron, SS_Bronze, SS_LampGlass) | 3 | 33.6 / 8.4 |
| settlement_townhall_ceiling_truss | 2,196 / 204 / 96 | 0 | 3 (SS_Oak, SS_Iron, SS_Bronze) | 3 | 50.3 / 12.6 |

Per-asset VRAM counts shared textures once per asset; the whole folder is **50.3 MB uncompressed / 12.6 MB compressed est. (3.4% / 0.8% of the Low 1.5 GB budget)**. New in this folder: no new texture set (0 MB uncompressed new to the city). Every texture is a byte-for-byte copy from an earlier hand-off (screens_planters, city_atm, tailor_dyes_stall); no new 2048.

**Store totals vs doc budget (no per-prop budget in the docs for the Town Hall ceiling; own ceiling 75k LOD0 / 20k LOD1 for the whole hall):**
- Shell + interior: **24,188 / 6,260 / 96** tris, 17 draws at LOD0 (est.).
- Fully dressed as in the previews (the whole nave ceiling as in the previews: 5 trusses (at the nave column lines), 2 x bay_4p2 + 2 x bay_4p3, 2 chandeliers and 8 aisle pendants): **61,732 LOD0 / 17,212 LOD1**, about 61 draws at LOD0 / 43 at LOD1 without instancing. Target own ceiling 75k LOD0 / 20k LOD1 (no doc budget): **LOD0 inside the range, LOD1 inside the budget**.
- City-wide texture VRAM over all hand-offs: **734.0 MB uncompressed / 183.5 MB compressed est.** (plan target 200 / 60; the held pavers / brick / asphalt cuts are not applied).

## Conventions
+Y up, front = +Z, 1 unit = 1 m, 1.75 m adult. Nodes `<id>_LOD0/_LOD1/(_LOD2)`, `<id>_col` hidden via KHR_node_visibility (Godot: hidden MeshInstance + StaticBody3D / Concave); door leaves (and any other moving part) carry `<id>_<leaf>_col` parented to the leaf so collision moves with it. Interaction markers: +Z faces the player. Stand / seat markers (`mk_npc_*`, `mk_seat_*`, `mk_cook_*`): +Z = actor facing. `mk_prop_*`: +Z = the way the prop faces. Hall frame: x across, y absolute (floor top 0.24), z along, origin = module centre, front +Z.

## Markers
Truss: `snap_start` / `snap_end` (out -Z / +Z), `mk_column_a` / `mk_column_b` (column tops (+-3, 7.05)), `mk_ridge`, `mk_wall_a` / `mk_wall_b` (tie ends at the wall). Bays: `snap_start` / `snap_end`, prop slots `mk_prop_lamp_aisle_1` / `_2` (+Z faces down the hall) and, on the 4.3 m bay, `mk_prop_lamp_chandelier_1`. Chandelier: `mk_attach`, `mk_light`, `mk_lamp_lit_1..8` (the eight outer lit lamp cages). Pendant: `mk_attach`, `mk_light`, `mk_lamp_lit`. Every `mk_light` is a lamp mount: no light nodes are inside the assets.

## Day / night
Every material reads in full daylight (timber, plank, bronze, iron carry the look). The only emissive surface is the lamp glass (SS_LampGlass: flat warm `#ffc174`, the repo's lantern glow, emission energy 0.65): it ships lit; scale `emission_energy_multiplier` down by day (previews: 0.25 by day, 1.6 at dusk). No light nodes are inside the assets: put a warm OmniLight3D at every `mk_light` marker at dusk (previews: chandelier 3.4 energy / 11 m, pendant 2.0 / 6.5 m, colour `#ffb366`, no shadows, like the repo's existing `TownHallLanternLights`). `mk_lamp_lit_N` mark the individual lit lamp cages of the chandelier (use them for per-lamp glows or flicker).

## Checks
- Godot 4.6.3 import of every file (`check_result.json`): meshes, nodes, markers, materials, `_col` bodies (incl. under-leaf bodies), culling.
- Strict back-face culling renders: 12 previews in `previews/` (nave from the entry / aisle / truss front and close-up / coffers / chandelier / pendants, LOD1 / LOD2; day and dusk), each with the 1.75 m adult capsule and the road kit (hall test bed: walls, roof slab, runtime purlins, nave columns, existing lanterns).
- Winding check (`winding.json`): 5 / 5 pass.
- Rebuild (`rebuild_check.json`): two fresh builds and a build from the shipped tools are byte-identical on every file; the textures are byte-identical to the copies in `screens_planters`, `city_atm` and `tailor_dyes_stall`.

## Rebuild
`sh tools/build_all.sh <out_dir>` (Blender 4.2.9 + Pillow), `sh tools/run_godot_checks.sh <handoff> <scratch> <out>`, `sh tools/run_previews.sh <handoff> <scratch> <out>`, `sh tools/rebuild_check.sh <handoff> <scratch> <out.json>`, `python3 tools/finalize_report.py <handoff>`. Textures: nothing is generated here; `tools/collect_textures.sh <dest> [handoff_root]` copies the reused sets byte for byte.
