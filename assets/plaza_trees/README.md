# plaza_trees: plaza tree set (P2 "Near-tree style clash", shots 37/41/36)

Original design: procedural broadleaf trees with no third-party meshes or textures. They replace the two bright lime Quaternius
`CommonTree_1` "lollipop" trees beside the fountain. The new trees use the sage/teal palette of the darker reference tree
(`kit/reference_broadleaf_tree_a`) and a real branching structure with layered alpha leaf-cluster cards.

## What is in the repo (measured from code/scenes, read-only)
| | Lime "lollipops" (to replace) | Darker reference tree |
|---|---|---|
| File | `assets/quaternius/CommonTree_1.gltf`, **embedded** in `assets/plaza_islands/composition.scn` (mesh `CommonTree_1_tree_023`) | `assets/kit/reference_broadleaf_tree_a.glb` (also copied in `foliage_wind/`; embedded in `approved_gardens_v086.scn`, `home_garden.scn`) |
| Nodes / placements | `PlazaIslandComposition/Tree_left` (4.9, 0.241, 11.7), yaw 20°, scale (1.5, 1.2, 1.5); `Tree_right` (11.0, 0.193, 5.5), yaw 114.6°, scale (1.1, 1.0, 1.1); root bottoms at ground y -0.05 | `landscape_four_gardens.gd` REGIONS: PlazaApproach (-3.5, 12.1), ShipViewIsland (5.6, 11.8)\*, FountainEastBorder (10.7, -4.1)\*, DanStairGarden (-3.3, 21.0); `reference_foliage.gd` TREES (13,-9), (-15,-11.5), (-13.5,-21), (13.5,-28). \*hidden by `plaza_island_landscape.gd replace_old_planting()` |
| Size | Tree_left: leaves 6.5–6.9 m wide, 2.8–8.4 m high (world AABB 8.43 x 8.72 x 8.67, rotated). Tree_right: leaves 4.7–5.0 m wide, 2.35–7.0 m high (AABB 6.55 x 7.26 x 6.41) | 5.73 x 5.32 x 5.70 m; canopy from 3.3 m; trunk r 0.53 at the flare |
| Tris | 6,265 (bark 4,345 + leaves 1,920), 2 surfaces, alpha-scissor textures | 13,024, 1 surface, vertex colour (`SETTLEMENT_Foliage_Vertex`) |
| Palette (sRGB) | leaves texture mean (88, 123, **0**) = lime | leaves mean (101, 128, 85), bark (88, 69, 53) |
| Collision | `TreeSolid_left/right`: ConcavePolygonShape3D of the whole bark mesh (4,345 faces each) | scripts add trunk cylinders (r 0.48 h 2.5 / r 0.25 h 2.1) |
| Referenced by name | `paths_gardens_v094.gd finish_roots()` → `world.find_child('Tree_left'/'Tree_right')` (0.60 m root pocket at its global_position) | `landscape_four_gardens.gd` requires exactly 1 direct-child MeshInstance3D with identity transform (else "Unexpected tree hierarchy" → garden freed); `market_edge_gardens.gd` uses CommonTree_1/_3 too (West avenue, needs 1 mesh / 2 surfaces / `Bark_NormalTree_Normal`) |
| Caps / pins | No tree tri cap found. `composition.scn` is sha256-pinned in `vendor/large-assets/manifest.json` (+ `tools/pinned-r8-runtime.json`, `assets/planting_review/verified-native-foliage.json`), so swap at runtime instead of re-saving it. `intentional_planting_pockets.gd` MAX_TRIANGLES 40000 applies only to its pockets. | |

## Assets (one glTF each; nodes `<id>_LOD0`, `<id>_LOD1`, `<id>_LOD2`, `<id>_col`)
| id | replaces | canopy W x D, bottom → top | LOD0 / LOD1 / LOD2 tris | col |
|---|---|---|---|---|
| plaza_tree_a | Tree_left (broad, 4 scaffold limbs, open vase fork) | 6.48 x 6.89 m, 2.63 → 8.50 m | 11,681 / 4,672 (0.40) / 615 | prism r 0.34→0.23, 2.65 m |
| plaza_tree_b | Tree_right (upright, central leader) | 4.97 x 4.72 m, 2.58 → 7.04 m | 10,997 / 4,342 (0.39) / 566 | r 0.235→0.16, 2.4 m |
| plaza_tree_c | spare (reference footprint; compact, wide) | 5.75 x 5.53 m, 2.25 → 5.88 m | 11,267 / 4,472 (0.40) / 587 | r 0.25→0.165, 2.3 m |

* **Budget:** LOD0 ≤ 16k for a hero plaza tree (actual 11.0–11.7k: bark ~2.0–2.6k plus 560–620 leaf cards). LOD1 is about 40% (fewer, 18% larger, single-fold
  cards, coarser limbs, no twigs). LOD2 is about 5% (the distance mesh: ~120 large flat cards on the crown shell plus the trunk and scaffolds; no impostor needed).
  Every LOD is a procedural rebuild from the same skeleton, not a decimation.
* **Footprint:** the crowns were fitted to the lollipops. Placed by `place_plaza_trees.gd`, the LOD0 world AABB is Tree_left 8.45 x 8.71 x 8.70 (old 8.43 x 8.72 x 8.67)
  and Tree_right 6.36 x 7.22 x 6.49 (old 6.55 x 7.26 x 6.41). Canopy bottoms are ≥ 2.25 m (walk-under; Dan is about 1.8 m).
* **Origin:** trunk base centre on the ground. The trunk and root flare sink 0.15 m below so slopes don't show a gap. Godot +Y up, transforms applied, metres.
* **Materials (2, shared):** `PT_Bark` (pt_bark set, opaque, single-sided, tileable, 1 tile = 1 m along the branch). `PT_Leaf` (pt_leaf set,
  **alphaMode MASK 0.5**, single-sided). The leaf atlas has 2 x 2 cluster cells: top row sunlit, bottom row shade, used for inner and lower cards.
  The leaf cards are **two-sided in geometry**: a reversed back copy sits 2 mm behind each card, and both copies carry canopy-spherical normals. The crown then shades as one soft mass from
  every side, with no back-face normal flip, so keep the material cull-back (Godot imports it that way).
* **Textures:** 1024². ORM = R occlusion / G roughness / B metal (0); normal maps are OpenGL. **Exception: `pt_leaf_base.png` is RGBA PNG**, because the
  alpha cut-out needs it; everything else is JPG.
* **Collision:** `<id>_col` is an 8-sided tapered prism (28 tris) from 0.1 m below ground up to the fork, hidden via KHR_node_visibility. Godot imports it as a
  StaticBody3D with a ConcavePolygonShape3D under a hidden MeshInstance3D named `<id>`, the same as the earlier kits. Branches and leaves have no collision.

## Placement (`build/place_plaza_trees.gd`, tested headless on a copy of composition.scn)
```gdscript
# plaza_island_landscape.gd, right after: visual=SCENE.instantiate();visual.name='PlazaIslandComposition'
preload('res://scripts/place_plaza_trees.gd').apply(visual)
```
The helper reads each old tree's yaw and ground contact (root AABB bottom, y -0.05), then frees `Tree_left/right` and `TreeSolid_left/right`. It instances
plaza_tree_a/b at the same x, z and yaw at unit scale, names them **`Tree_left`/`Tree_right`** (so `paths_gardens_v094.finish_roots` still finds them),
and sets the LOD visibility ranges: LOD0 0–32 m, LOD1 32–75 m, LOD2 75 m+, 2 m margins, fade off. The asset path is `res://assets/plaza_trees/`.

## Previews (`previews/`, Cycles, JPEG q88; the exported glTFs were re-imported)
lineup (a, b, c with Dan), lods (a: LOD0 / LOD1 / LOD2), close (under plaza_tree_a with Dan), scale (reference_broadleaf_tree_a | b | a | Dan),
before (same framing with the lollipops at their scene scales), footprint (top-down, new crowns over magenta lollipops),
plaza_after / plaza_before (shot-37-style: fountain stand-in, both trees at their composition transforms, PlazaApproach reference tree).
The preview script emulates Godot back-face culling on PT_Leaf, because Cycles has none.

## Rebuild
```
python3 build/make_textures_pt.py
blender -b --factory-startup -P build/build_plaza_trees.py -- <out_dir>
blender -b --factory-startup -P build/render_previews.py -- <out_dir> <preview_dir>
python3 build/make_report.py <handoff_dir>
```
(The scripts expect `textures/` beside them, as in /workspace/artie/plaza_trees/. `check_pt.gd` is the headless Godot check harness and uses res://pt/.)
