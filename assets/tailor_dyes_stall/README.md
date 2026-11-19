# tailor_dyes_stall: hand-off notes (Artie)
Replaces the box-primitive Tailor & Dyes blockout (scripts/tailor_atelier.gd and tailor_frontage_v097.gd). Original design.
- Drop-in: parent the scene under `TailorAtelier` with an identity local transform. The node already sits at ANCHOR (-27.25,0,-4) with rotation.y=PI/2. The front faces local +Z, and the floor is 4.8 x 4.5 m centred on the origin with its top at y=0.063.
- Left empty on purpose: the dress-form swap region (midstyle_swap.gd drops tailor_dress_form.gltf there) and the Tailor actor spot (.70,.055,-.30). The accessibility ray to TARGET stays clear.
- The painted sign already reads "TAILOR & DYES". The TailorIdentitySign Label3D (z 2.245) would sit 1 cm in front of the board, so hide it or keep it as an inspector-only node.
- Not modelled any more and should be removed when this asset goes in: the blockout boxes, the v097 canopy/valance/sign frame, the relocated rail and clothing display, and the bolts, jars, spools and dye basin that the mesh now replaces. Keep the work OmniLight. The mesh lantern sits at (.45,2.55,1.28).
- LODs: both mesh nodes import visible, so set visibility_range on LOD0 and LOD1 (for example LOD0 0-25 m, LOD1 from 25 m).
- Collision: `tailor_dyes_stall_col` is a union of closed boxes. Godot's `_col` suffix turns it into a trimesh StaticBody3D and strips the suffix from the node name, which becomes `tailor_dyes_stall`. The node carries KHR_node_visibility=false, so the box mesh imports hidden (checked in Godot 4.6.3).
- Rebuild: `python3 build/make_textures_tds.py <dir>/textures`, then `TDS_TEX=<dir>/textures blender -b --factory-startup -P build/build_tailor_dyes_stall.py -- <out>`. The output is deterministic (identical .bin across builds).
