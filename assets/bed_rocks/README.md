# bed_rocks — rounded natural bed rocks (5 variants)

Replaces the faceted `assets/planting_dense/small_rock_group.glb` (84 tris, flat-shaded) flagged in
visualpass findings "P2 — Faceted low-poly rocks in the garden beds" (shots 56/57/58). Original design.

| file | LOD0 tris | LOD1 tris | size x × h × z (m, scale 1) | look |
|---|---|---|---|---|
| bed_rock_a.gltf | 4800 | 1920 | 0.48 × 0.25 × 0.40 | rounded river boulder |
| bed_rock_b.gltf | 4800 | 1920 | 0.63 × 0.18 × 0.46 | flat slab |
| bed_rock_c.gltf | 4332 | 1732 | 0.36 × 0.28 × 0.40 | weathered lump, soft cleavage |
| bed_rock_d.gltf | 4920 | 1968 | 0.66 × 0.23 × 0.37 | pair (large + small) |
| bed_rock_e.gltf | 5400 | 2160 | 0.70 × 0.20 × 0.53 | trio, same footprint as small_rock_group |

Old small_rock_group envelope at scale 1: 0.78 × 0.23 × 0.52 m. All variants fit inside it (e is the
closest drop-in), so the existing per-instance scales (.35 path_shoulder_gardens, .55 landscape_four_gardens,
.91–1.05 intentional_planting_pockets) keep the same visual size. Tallest (c) at pocket scale 1.047 = 0.29 m (< MAX_HEIGHT .45).

- glTF separate (.gltf + .bin), textures shared by all five: `textures/bed_rock_{base,orm,normal}.jpg` (1024², ORM = R occl / G rough / B metal, OpenGL normal).
- Each file: nodes `bed_rock_x_LOD0` and `bed_rock_x_LOD1` (identity transforms), one material `BedRock`, COLOR_0 vertex colour
  (cavity dirt, moss on top faces, damp base) multiplied into albedo — Godot 4.6.3 imports it with `vertex_color_use_as_albedo = true` (verified).
- Meters, +Y up, origin at base centre on the ground (min Y = 0). No `_col`: bed rocks have no colliders, like the original.
- Smooth shaded, no hard edges; reads rounded at game camera.

## Integration notes (scripts need small edits)
- path_shoulder_gardens.gd / landscape_four_gardens.gd / intentional_planting_pockets.gd assume the glb contains ONE
  MeshInstance3D with identity transform. These files have two (LOD0 + LOD1). Take the `*_LOD0` mesh by name (and
  `*_LOD1` for a far MultiMesh / visibility range), or rely on Godot's auto mesh LODs on LOD0.
- intentional_planting_pockets.gd `MAX_TRIANGLES = 40000`: current pocket content is ~38.1k (29 mounds × 540 +
  12 groundcover × 1832 + 6 rocks × 84). 6 rocks at LOD0 (~4.3–5.4k) → ~66–71k; at LOD1 (~1.7–2.2k) → ~49–51k.
  Raise the budget (or use LOD1 there) or the assert fires.
- To use variety, swap the single rock mesh for a pick among a–e per instance (e.g. hash of position).

## Rebuild
    python3 build/make_textures_bedrock.py                     # writes ./textures next to the script
    BED_ROCK_TEX=<textures dir> blender -b --factory-startup -P build/build_bed_rocks.py -- <out_dir>
    blender -b --factory-startup -P build/render_previews.py -- <out_dir> <preview_dir> [views] [samples] [LOD0|LOD1]
    python3 build/make_report.py <handoff_dir>
Blender 4.2.9, Cycles previews (128 spp, JPEG q88).

## Previews
- previews/bed_rocks_lineup.jpg — a, b, c, d, e left to right
- previews/bed_rocks_closeup.jpg — a, c, e close
- previews/bed_rocks_game_beside_reference.jpg — game-ish camera: old small_rock_group (left; scales 1.0/.55/.35) vs new (right, same scales), compact_broadleaf_mound + Dan for scale
- previews/extra/bed_rocks_lineup_LOD1.jpg, bed_rocks_game_LOD1.jpg — LOD1 check
