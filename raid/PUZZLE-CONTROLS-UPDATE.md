# Echo Cistern and Weather Station control art

Separate source candidate on top of the cache/beacon integration. Earlier source
and Windows review packages are preserved. This is a visual/animation addition,
not a new puzzle system or a native-playtest approval.

## Imported art and actual import verification

The two user-supplied ZIPs passed CRC and safe-path checks. Only the self-contained
GLBs are used by the game. Uploaded Python scripts and Blender files were never
executed. No external images/buffers, embedded scripts, cameras, animation tracks
or lights are needed. No new blanket license is asserted; keep the supplied
archives for source authoring and provenance.

A small isolated project imported the assets with Godot 4.6.3 at the final
`res://raid/assets/puzzle_controls/` paths. Matching generated scenes and remaps
were then copied into the full candidate to avoid reimporting protected settlement
assets. The imported scenes were tested from that full candidate.

Default Godot import was explicitly tested: it transforms `Valve_Wheel` into a
`VehicleWheel3D` named `Valve`. The shipped candidate disables BOTH
`nodes/use_name_suffixes` and `nodes/use_node_type_suffixes`, preserving a normal
`MeshInstance3D` named `Valve_Wheel`. Both import-script fields remain empty.

- Valve: 1,500 triangles, including a 460-triangle wheel. Local Z pivot
  `(0, 1.45, 0.36)`. Full rest dimensions 0.90 × 1.90 × 0.735 m (X/Y/Z).
  Wheel and stationary pedestal have at least 6 mm depth separation at tested
  angles. Scale stays 1 and the art faces +Z.
- Relay: 1,014 triangles. Separate housing, lever, and amber indicator meshes.
  Local X hinge `(0, 1.20, 0.40)` with a -40° to +40° throw. Full neutral
  dimensions 0.60 × 1.80 × 0.738 m. The indicator alone owns the amber emissive
  material with imported energy 6.
- Both stationary housings fit the original 0.60 × 1.80 × 0.60 m collision box.

Bounds caveat: rotating an imported mesh AABB overestimates its visible shape.
At a 45° valve rotation the transformed AABB is about 1.273 m wide, but measured
mesh vertices still stay within the 0.90 m wheel diameter. This is not geometry
growth or evidence that LOD changes the wheel. Relay raw vertex depth at +40° is
about 0.898 m; the conservative transformed AABB is about 0.912 m. The front
approach stays clear. This pass does not claim a triangle-overlap proof for the
relay pocket at every possible angle.

## Visual feedback and preserved gameplay

The three Echo Cistern blocks and primitive wheel discs are replaced by supplied
valves. Each press turns the wheel 90° around local Z over 0.36 seconds.

The three Weather Station blocks are replaced by supplied relay controls. Each
press throws the lever from -40° to +40° and returns it to -40°, taking 0.40 s.
Only that relay's lamp briefly brightens, then returns to energy 6. Each lamp has
its own material copy; steel/housing materials and neighboring lamps are untouched.
This is momentary activation feedback, not a latched display of puzzle progress.
Visible bloom depends on the renderer/environment; emission is not a local light.

Fast repeated input replaces the previous tween from the visible pose. It does
not queue motion, block input, delay puzzle evaluation, or add gameplay timers.
Freeing a map during motion also frees its bound tweens. New instances start at
their idle pose. Existing electrical clicks, distinct valve sounds, and solved
cue remain in the original interaction flow.

Control positions, labels, numbers, target centres, simple static collision,
raycasting, clues, both distinct three-step sequences, reset rules, separate door
interaction, loot, extraction, terrain, vegetation, POIs and settlement files are
unchanged. Moving parts intentionally have no extra collision, matching the
existing simple proxy approach. The thin rim/lever overhang is not a detailed
player collider. No platform, ring, new label or puzzle hint was added by the art.

## Verification and remaining acceptance

`test_puzzle_controls.gd` verifies imported node types/names, suffix settings,
triangles, pivots, stationary housings, sampled pose/vertex bounds, separation,
per-instance lamps, initial/final motion, rapid/repeated actions, unchanged state
transitions, actual camera/raycast selection, front approach clearance, original
collision, door behavior, post-solve actions and disposal during motion.

The combined runner includes this suite and all previous raid checks. See the
accompanying validation report for final counts and individual suite outcomes.
All testing uses isolated disposable profiles. No rendered, audible-mix,
native-input, Windows, performance, full-game or real-save acceptance is claimed.
No new Windows package is built in this source pass. Keep the larger-update
playtest cadence rather than requesting another small-change manual test.

For future packaging include both GLBs, their import metadata, and matching
generated imported scenes listed in `assets/puzzle_controls/ASSET-MANIFEST.json`.
Fresh development imports must keep both suffix flags disabled, use Godot 4.6.3,
and follow the recovered project's approved-import restoration instructions.
