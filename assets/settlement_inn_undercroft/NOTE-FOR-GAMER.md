# NOTE FOR GAMER: settlement_inn_undercroft (Inn balcony undercroft (bays, pile dressing, landing, props)), FINAL, Thu Nov 19 2026 ~10:49 PM New York time

Folder: /workspace/artie_handoff/settlement_inn_undercroft/ (12 glTF + bin pairs, 15 textures, about 7.2 MB, README.md and BUILD-REPORT.json inside). Nothing was pushed, nothing in the repo.

## Doc check (06_assets.md, 01 section 1.7, 02, 05, city_asset_plan.md)
- Repo as built on main (HEAD 8d862ff, read-only): the rear / east balconies of the Inn are bare slabs on piles (`inn_lake_v088.gd`, `inn_joined_decks_v098.gd`); there is no underside dressing, no landing and no storage props below, so this is a new dressed underside. Measured dimensions and the placement transforms are listed above. The docs list no budget for it (see the budget note in the numbers).

## What to wire
1. Under the **rear balcony**: instance `bay_4m` at world (cx, 3.12, 58.7), rot 0, for cx = -6, -2, 2, 6 (and 10); `pile_dressing_28` at (x, 3.12, 62.6) for x = -8, -4, 0, 4, 8; `pile_dressing_35` at (x, 3.12, 60) for x = -8.7, 0, 8.7 and at the corner pile (11.6, 3.12, 62.6). In the Inn's local frame: y = -0.28, z = 6.0 (bays) / 9.9 and 7.3 (piles).
2. Under the **east balcony**: `bay_3p25` at (7.9, 3.12, 54.925) and (7.9, 3.12, 58.15), rot Y +90 deg; `pile_dressing_28` at (11.6, 3.12, 53.3 / 56.5 / 59.8).
3. Instance the props from the `mk_prop_*` markers of each bay (the previews do: marker global transform = prop transform); you choose which slots to fill. The marker y is the landing top for floor props and the joist / girder underside for the boat and lanterns.
4. At dusk put a warm light at each lantern's `mk_light`; scale the lamp-glass emission with the day / night controller.
5. Collision: bay `_col` is the walkable landing. Add a ramp / ladder (`ladder_dock`) or the inn's own dock to reach it; the lake / water is the repo's.

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

## Day / night
Every material reads in full daylight. The only emissive surface is the lamp glass of `lantern_hung` (SS_LampGlass: flat warm `#ffc174`, the repo's lantern glow colour, emission energy 0.65): it ships lit; scale `emission_energy_multiplier` down by day (the previews use 0.2 by day, 1.6 at dusk). The assets contain no light nodes: put a warm OmniLight3D (previews: 2.6 energy, 7.5 m, `#ffb366`) at every `mk_light` marker of each lantern at dusk.

## Checks (all pass)
Godot 4.6.3 import of all 12 files; strict back-face culling renders (18 previews, JPEG q88, day and dusk, 1.75 m adult + road kit); winding 12 / 12; two fresh builds and a build from the shipped tools byte-identical, the textures are byte-identical to the copies in `screens_planters`, `city_atm` and `tailor_dyes_stall`.

## Flags for you
1. **Textures**: no new texture and no 2048. Five 1024 sets reused (sp_timber, sp_wicker, ct_dark, tds_metal, tds_stone); every asset uses 2-5 of them (see the VRAM column).
2. **Rear run ends**: x -8.7..-8 is not covered by a bay (0.7 m past the last pile), and the 8..12 bay ends at the corner pile (11.6) not 12. Say if you want an end-cap piece.
3. **Landing height**: 0.5 m above the water (world y 1.15) is my choice (the repo has no landing); change the water-to-landing height by moving the bay's landing, not the piles.
4. **Headroom** over the landing is 1.79 m; fine for a 1.75 m capsule but not for a taller player scale.
5. **Boat** hangs keel-up in the 1.75 m gap between the wall and the landing (over the water), above head height of anyone on the landing.
