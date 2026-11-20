# NOTE FOR GAMER: settlement_inn_door (Inn front doors (two-leaf main door + east side door)), FINAL, Thu Nov 19 2026 ~10:38 PM New York time

Folder: /workspace/artie_handoff/settlement_inn_door/ (2 glTF + bin pairs, 9 textures, about 3.2 MB, README.md and BUILD-REPORT.json inside). Nothing was pushed, nothing in the repo.

## Doc check (06_assets.md, 01 section 1.7, 02, 05, city_asset_plan.md)
- Settlement docs / repo (`/workspace/settlement_bundle/repo` as built on main, HEAD 8d862ff, read-only): the Inn front doorway and the east side door have **no door leaves** (the openings are only cut into the wall solids), so these are new pieces. Dimensions above were read from `inn_architecture.gd`, `inn_front_v087.gd` and `inn_lake_v088.gd`. Done: leaves open / close at the real hinge lines, opening size exactly the repo's. Nothing else in the repo changes.

## What to wire
1. Instance `settlement_inn_door_main` as a child of the Inn node at `(0, 0, -5.9)`, `rotation.y = 180 deg`; instance `settlement_inn_door_side` at `(7.8, 0, 2.0)`, `rotation.y = 90 deg`.
2. Animate the leaf nodes only (`*_leaf_l_LOD0/1/2` etc. share one pivot: rotate the node group; the importer gives one node per LOD with the same transform, so rotate all three or put them under one Node3D). Open angles: main leaves 0 .. +-100 deg outward (left -, right +), side leaf 0 .. -95 deg (outward). Collision bodies are children of the leaf nodes.
3. At dusk place a warm light at each `mk_light_*` marker; scale the lamp-glass emission with the day / night controller.
4. If you keep the repo's `EntryLintel`, nothing else needs to change; to reuse the frame trim without the doors just hide the leaf nodes.

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

## Day / night
Every material reads in full daylight. The only emissive surface is the lamp glass (SS_LampGlass: flat warm `#ffc174`, the same warm amber as the repo's lantern glow, emission energy 0.65) in the lattice panes of the front door: it ships lit; by day the game scales `emission_energy_multiplier` down (to about 0.15-0.2) and at dusk back up. The assets contain no light nodes: put a warm OmniLight3D at `mk_light_l` / `mk_light_r` / `mk_light` at dusk, and (optionally) a small one behind `mk_pane_glow_l/r` on the inside.

## Checks (all pass)
Godot 4.6.3 import of all 2 files; strict back-face culling renders (17 previews, JPEG q88, day and dusk, 1.75 m adult + road kit); winding 2 / 2; two fresh builds and a build from the shipped tools byte-identical, the textures are byte-identical to the copies in `screens_planters`, `city_atm` and `tailor_dyes_stall`.

## Flags for you
1. **Textures**: no new texture and no 2048. Everything reuses earlier sets (sp_timber, ct_dark, tds_metal), shown in the table.
2. **Door leaf nodes**: the glTF has one mesh node per LOD for each leaf (`_leaf_l_LOD0` etc.), all with the pivot at the hinge; rotate them together.
3. **Doors open outward** (porch side / east side); flip the sign if you want them to swing in. The inside has ledges but no handles on the main door's left leaf (it is the passive leaf; the right leaf has the ring pull and latch).
4. **Assumed**: leaf thickness 6 cm and surround depth proud 4.5 cm (the repo gives only the wall solids).
