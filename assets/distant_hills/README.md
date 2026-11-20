# distant_hills — smooth far-hill chunks (P2 "Distant scenery on Medium: faceted mountains", visualpass shot 79 / 185)

Original work, generated procedurally (Blender 4.2.9 + numpy). There are no third-party assets and no licence changes.

## What it replaces (reference repo, read-only)

| new set | replaces | where it is built |
|---|---|---|
| `distant_hills_foothills` | `ValleyBackdrop/OuterFoothills`: ring at r 180–490 m, crest r 300, up to ~54 m. 384×12 grid, **9,216 flat-shaded tris** | `scripts/distant_mountains.gd` (sha-pinned), called from `scripts/valley_backdrop.gd` (sha-pinned) |
| `distant_hills_alpine` | `ValleyBackdrop/DistantAlpineRange`: ring at r 370–850 m, crest r 570, up to ~184 m. **9,216 flat tris** | same |
| `distant_hills_ridges` | `FarScenery/FarSceneryLayerRidges`: rings at r 320 / h 72 (40 segs) and r 510 / h 118 (36 segs). **608 flat tris**, visibility end 1,400 m | `raid/scripts/far_scenery_options.gd` (option B, on by default) |

- **Why it looks faceted.** `distant_mountains.gd` splits every triangle on purpose ("visible rocky facets"). On top of that, `far_terrain_paint_v100` shades with that flat `NORMAL`.
- **Why Medium makes it worse.** On Medium, the `distant_scenery_quality` forests (`distant_valley_v093`, `north_woodland_stage2_v094`, `north_trees_stage3`) drop to 35–50% density and collapse beyond 350 m. That leaves the bare, faceted rings exposed.

## Files

- **glTF sets.** Each set is `<id>.gltf` + `.bin` (glTF separate, metres, +Y up, transforms applied).
  - The root node `<id>` sits at the world origin.
  - Under it are 16 sector chunks `<id>_sNN_LOD0/1/2`. Each chunk node sits at its sector centroid on y = 0. Sector k covers 22.5° × [k, k+1], measured from +X toward +Z.
  - Ridges have `_near` and `_far` rings, so 32 chunks.
  - There is **no `_col`**: the hills can't be reached, and the originals had no collision either.
- **Textures** (`textures/`, shared by all three sets, 1024², tileable, 1 tile = 48 m):
  - `dh_ground_*`: canopy clumps and meadow gaps. It reads as forested hillside when Medium thins out the real trees.
  - `dh_rock_*`: broad strata and downslope gullies, for the alpine range and steep faces.
  - Each set has base (sRGB), ORM (R occlusion / G roughness / B metal) and an OpenGL normal map.
  - The base maps have neutral luminance (linear mean 0.80). They are **multiplied by `COLOR_0`**, which carries the current far-paint palette and aerial haze, evaluated per vertex from a 1:1 port of `far_terrain_paint_v100` / `far_ridge_silhouette_v100`.
  - 2048 isn't justified: at 180–850 m, 1024 over 48 m is already about 4.7 cm per texel.
- **Install helper:** `build/place_distant_hills.gd`. Copy it to `res://scripts/place_distant_hills.gd`.
- **Previews** (`previews/`, JPEG q88; "before" uses the current geometry and paint, "after" uses these chunks at Medium ranges):
  - Game-camera views: eye at 1.68 m, vertical FOV 76°, 1440×900.
    - `compare_shot79` / `shot79_medium_*`: from Dan's Marketplace.
    - `compare_east185` / `east185_medium_*`: from the plaza, looking east.
  - `compare_close` / `close_telephoto_*`: the same spot through a 120 mm zoom.
  - `scale_reference`: `kit/reference_broadleaf_tree_a` and Dan at the foot of the foothills, with the real far-cluster trees.
  - `lod0/1/2`: one alpine chunk at each LOD, same camera.
- **Build scripts** (`build/`):
  - `farfuncs.py`: numpy port of the ring, ridge and paint functions. It matches Godot's exported vertices to within 4e-5 m.
  - `make_textures_dh.py`, `build_distant_hills.py`, `render_previews.py`, `deviation.py`, `make_report.py`, `meshio.py`.
  - `dump_far.gd`: dumps the current far meshes headless.
  - `check_dh.gd`: Godot import and runtime check.

## Geometry and shading

- **Same height functions as the game.** The chunks use the same functions as `distant_mountains.gd` and `far_scenery_options.gd`, so the footprint and placement match.
- **Rounding.** Only the sharp "teeth" kinks are rounded, by at most about 0.6 m.
- **Ridges.** The ridge silhouette is a periodic Catmull-Rom curve **through the original ring vertices**, so the skyline keeps its peaks.
- **Measured vertical difference from the original triangulated rings** (in `BUILD-REPORT.json`):

  | ring | p95 | max | other |
  |---|---|---|---|
  | foothills | 0.27 m | 0.51 m | at the 1,559 far-cluster trees standing on it: p95 0.16 m; worst case the tree floats 0.06 m, since trees are sunk 0.30 m |
  | alpine | 0.68 m | 1.6 m | — |
  | ridges | 7.8 m | 15.9 m | silhouette-only rings; the 40/36-segment polygons are replaced by curves |

- **Normals.** Normals are baked from the analytic surface (finite differences on the full-resolution function). LOD0, LOD1 and LOD2 share one normal field, so a LOD switch changes the silhouette slightly but not the shading.
- **No cracks.** The sector side edges carry a 6 m two-sided skirt, so no gaps open between neighbouring chunks at different LODs.
- **Materials.** `DH_Ground` / `DH_Rock` are opaque with back-face culling. The originals were drawn cull-disabled with wrong-way winding; ours face up and out.

## Budgets (exported tris; see `BUILD-REPORT.json`)

| set | LOD0 (per chunk) | LOD1 | LOD2 | original |
|---|---|---|---|---|
| foothills | 41,472 (2,592) | 16,896 (0.41) | 3,840 (0.09) | 9,216 |
| alpine | 66,560 (4,160) | 28,288 (0.43) | 5,120 (0.08) | 9,216 |
| ridges | 21,504 (672) | 10,240 (0.48) | 2,560 (0.12) | 608 |

- **LOD ranges by `scenery_quality`** (`[LOD0 end, LOD1 end]`, 15 m margin; LOD2 has no end):

  | Low | Medium | High | Ultra |
  |---|---|---|---|
  | 300/650 | 450/900 | 650/1200 | 900/1600 |

- **Medium, what is actually drawn** (frustum-culled chunks): about 32k tris in 31 draw calls from the shot-79 spot, and about 27k tris in 23 draw calls looking east. The originals drew 19k tris in 3 draw calls, with no culling.
- **Runtime size:** 6.7 MB (gltf + bin + textures).

## Install

Gamer adds one line in `raid/scripts/ship_settlement_preview.gd`, directly after `far_scenery_options.apply(self)`:

```gdscript
if world_activated: preload("res://scripts/place_distant_hills.gd").install(self)
```

What the helper does:
- Adds a `DistantHills` node under the world and loads the three sets from `res://assets/distant_hills/`.
- Hides `OuterFoothills`, `DistantAlpineRange` and `FarSceneryLayerRidges`. They stay in the tree, so `terrain_vertices`, tree grounding, lake joins and tests are untouched.
- Turns shadows and GI off on the chunks, as on the originals.
- Joins the `distant_scenery_quality` group, so `game_settings.apply_scenery_quality()` drives `set_quality()`.
- Welds and smooths the normals of `MiddleRidge` and `ScenicGroundApron` in place. The vertices, face order and paint material stay the same.
- `DISTANT_HILLS=off` skips everything.
- It can't install twice.

Godot 4.6.3 headless check:
- 192 chunks.
- Materials import with vertex-colour albedo, linear colour, back culling, and normal + AO + roughness maps.
- 0 colliders.
- `MiddleRidge.get_faces()` is identical before and after; `terrain_vertices` is unchanged.
- The quality switch is verified at all 4 levels.
- Install takes about 0.2–0.4 s, once, at world activation.
