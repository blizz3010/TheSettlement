# NOTE FOR GAMER: settlement_townhall_ceiling (Town Hall ceiling (trusses, coffered liner) and hanging lamps), FINAL, Thu Nov 19 2026 ~10:57 PM New York time

Folder: /workspace/artie_handoff/settlement_townhall_ceiling/ (5 glTF + bin pairs, 9 textures, about 4.6 MB, README.md and BUILD-REPORT.json inside). Nothing was pushed, nothing in the repo.

## Doc check (06_assets.md, 01 section 1.7, 02, 05, city_asset_plan.md)
- Repo as built on main (HEAD 8d862ff, read-only): the roof slab is a bare dark underside above the runtime purlins, the only ceiling lights are the six amber lanterns at the column lines (two of them intersect columns in the repo, left as is) and no trusses, beams or coffers exist (`hall_review_finish.gd` TH04 even speaks of 'visible purlins between the major trusses', and the trusses are what this folder adds). Dimensions and placement transforms above.

## What to wire
1. Instance at y = 0 in the repo frame (anchor-local z in brackets): `truss` at world z -14.5 / -18.7 / -23 / -27.3 / -31.5; `bay_4p2` at z -16.6 and -29.4; `bay_4p3` at z -20.85 and -25.15; all at x = 0, no rotation (they are symmetric about x = 0 and about their centre).
2. Instance lamps from the `mk_prop_lamp_*` markers of the bays (the previews do: marker global transform = prop transform): 2 chandeliers, 8 pendants.
3. At dusk put an OmniLight3D (no shadow) at every `mk_light` and scale the lamp-glass emission with the day / night controller; keep the repo's own lantern lights as they are.
4. No collision is needed. If the repo's runtime purlins are ever removed, the coffer frames still work (the underlay is continuous).

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

## Day / night
Every material reads in full daylight (timber, plank, bronze, iron carry the look). The only emissive surface is the lamp glass (SS_LampGlass: flat warm `#ffc174`, the repo's lantern glow, emission energy 0.65): it ships lit; scale `emission_energy_multiplier` down by day (previews: 0.25 by day, 1.6 at dusk). No light nodes are inside the assets: put a warm OmniLight3D at every `mk_light` marker at dusk (previews: chandelier 3.4 energy / 11 m, pendant 2.0 / 6.5 m, colour `#ffb366`, no shadows, like the repo's existing `TownHallLanternLights`). `mk_lamp_lit_N` mark the individual lit lamp cages of the chandelier (use them for per-lamp glows or flicker).

## Checks (all pass)
Godot 4.6.3 import of all 5 files; strict back-face culling renders (12 previews, JPEG q88, day and dusk, 1.75 m adult + road kit); winding 5 / 5; two fresh builds and a build from the shipped tools byte-identical, the textures are byte-identical to the copies in `screens_planters`, `city_atm` and `tailor_dyes_stall`.

## Flags for you
1. **Textures**: no new texture and no 2048. Three 1024 sets are reused (sp_timber, ct_dark, tds_metal).
2. **Lowest part**: aisle ties at y 5.98 (0.32 m above the bookcases at 5.66, measured from the repo numbers; I did not check the bookcase x extents against the ties in 3D).
3. **Two existing lanterns intersect columns** (z -23, repo defect): not touched; the truss at z -23 sits above them and does not collide.
4. **Coffer bosses** are small bronze pads placed in the field centres; no emissive on them.
5. **Lamp lights are yours**: the glass ships lit, the Omni lights are not in the assets.
