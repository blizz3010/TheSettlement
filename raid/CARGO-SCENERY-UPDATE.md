# Cargo scenery integration candidate

This separate development copy extends the validated field-supplies candidate.
It does not replace previous sources, delivered builds, or real player saves.
It contains no settlement economy, inventory, progression or persistence change.

## Placement

Five Salvage Yard primitive boxes are replaced with olive containers: three
intact and two lightly dented. Their positions, 3.5 x 2.4 x 5.0 m solid collision
boxes, unrotated bases and forward +Z orientation remain unchanged. Container
art is offset downward by 1.2 m from each existing collision body's centre.
These are sealed scenery, not enterable rooms or interactive doors.

Glasskiln's warehouse has three large sand stacks on its east wall and three
small sand pallet stacks on its west wall. Their original 2.2 x 2.2 x 2.8 m and
1.6 x 1.5 x 2.3 m collision boxes and exact positions are retained. Art is placed
at unit scale with ground-centred pivots, offset by half the existing height.
The central aisle, doors, gallery and stair approaches are unchanged.

All eight GLBs are imported and supported by the wrapper. Four are currently
placed, following the existing woodland/salt-flat palettes. Sand containers and
olive stacks remain available for later authored scenes. No extra prop bodies
are added just to demonstrate every color variant. Glasskiln's three outdoor
cargo islands retain their existing art because these models do not match
their envelopes; stretching them would degrade the supplied proportions.

Simple collision intentionally remains conservative: visually empty gaps
between straps, sacks and boxes do not become new climb-through spaces. No
loot targets, opening animation, generated text or gameplay state is added.

## Independently verified source data and import

The 18,646,341-byte uploaded cargo_pack.zip passes CRC, unsafe-path, duplicate
path and symlink checks. Its eight intended GLBs are identical to their copies
under the archive's godot_test folder. Only GLBs were imported. Supplied Python,
GDScript, import sidecars and Blender scripts were not executed; Blend files
were not opened. Editable sources stay in the original archive. No blanket
asset license is assigned by this integration.

Actual imported dimensions are X width / Y height / Z depth, in metres:

- Intact container, both palettes: 3.5 / 2.4 / 5.0; 4,020 triangles, 4 surfaces.
- Dented container, both palettes: same envelope/counts, different vertices.
- Large stack, both palettes: 2.2 / 2.2 / 2.8; 2,976 triangles, 7 surfaces.
- Pallet stack, both palettes: 1.6 / 1.5 / 2.3; 1,444 triangles, 7 surfaces.

All are Y-up, bottom-centred with identity mesh transforms, one mesh, and no
embedded collision, animations, cameras, lights, scripts, UVs or textures.
There are no degenerate triangles. All materials are opaque and double-sided.
The four locking rods' binary coordinates independently confirm doors face +Z.
Dents move inward only within the original envelope (numerical tolerance):
maximum displacement 10.89 cm at the roof corner, about 1.31 cm at the door
region. Both palettes share geometry within each model state.

Fresh isolated Godot 4.6.3 imports use both name-suffix conversion options set
to false and no import script. Only these eight newly generated import scenes
and cache sidecars are copied into this candidate. Existing approved imports
are not regenerated, rebound or modified.

## Verification scope

The dedicated 480-check cargo suite covers all eight imported scenes, sizes,
triangle/surface counts, material palettes, origins/transforms, suffix settings,
absence of hidden behavior, eleven exact placements, unchanged solid boxes,
physics-ray boundaries, original interaction counts and six real production-
movement routes through warehouse aisles and Salvage Yard flanks/gaps.

An independently authored whole-world comparison confirms exact collision-data
identity, including typed transforms, all stored shape data, terrain, layers,
masks and disabled state, as well as target and door/extraction transforms:
Relay Ridge has 1,030 bodies and 1,030 shapes; Cinder Basin has 941 and 941.
Each world has the same 19 logical targets. Generator and state scripts are
unchanged. The accompanying validation record contains the complete regression
results, source audit and import measurements.

Headless testing is not rendered visual approval or native mouse/keyboard
acceptance. Windows execution, frame-rate, audible mix, real-save roundtrip and
complete game acceptance remain untested. No new Windows build is generated
for this incremental source candidate. Keep the larger-update review cadence;
the user handles Windows playtesting.

## Art assessment

The supplied render pixels show a clear improvement over primitive boxes:
corrugated shells, corner castings, locking rods, pallet construction and
varied stack silhouettes are coherent stylized low-to-mid poly scenery.
The intact/dented distinction is deliberately subtle, not heavy wreckage.

Close-up polish remains provisional. Surfaces look clean and flat for salvage;
weathering consists of sparse modeled accents rather than textured wear. Sand
paint/metal contrast is limited. Large-stack straps sometimes read as a rigid
framework spanning air gaps, and sacks have minimal fabric detail. Thin dark
straps may alias in motion. Highly metallic parts depend on representative
lighting/reflections, so bright Cycles renders cannot establish Godot quality.

For the coordinated art pass, review both palettes under actual map lighting,
prioritize material separation and selective believable wear, inspect strap
contact and sack silhouettes, and check normal/edge highlights close up. Avoid
adding filler subdivisions to meet an arbitrary triangle count. Each mesh has
multiple material surfaces, so draw calls and shadow cost matter alongside
triangles; this batch adds 20,100 full-resolution cargo triangles/20 surfaces
in Salvage Yard and 13,260 triangles/42 surfaces in Glasskiln's warehouse before
LOD, shadows and other passes. Performance has not been measured.
