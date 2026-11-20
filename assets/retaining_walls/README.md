# retaining_walls — stone retaining-wall snap kit (P2 "Blocky stone retaining walls", shots 107/110/170/174)

Original design. Fixes the findings.md P2: the hideout terrace wall in shots 107/110 (stone courses, bronze rail,
ivy, "east of the inn path") and the ship-pad wall in 170/174 both used flat box blocks. This kit gives them
mid-poly pitch-faced coursed stone, a tooled capstone coping, and quoined corners and ends.
It shares one texture set and one coping profile across both walls.

## What the repo actually needs (measured from code, read-only)
| Wall | Source | Numbers used |
|---|---|---|
| Hideout terrace ("inn approach" wall in 107/110) | `scripts/hideout_terrace.gd`, `scripts/home_finish_v094.gd` | body box x -32..-16, z 7..23 (16 m faces), deck 3.0 m; old courses 0.94 x 0.45 x 0.11 at ±8.015 (face to +0.07); old coping 0.22 x 0.18 at 2.82–3.0 (to +0.09 N/S, +0.11 W); drip strip at +0.098, base contact course to +0.1125; two 9-riser flights, 1/6 m risers, 0.34 m treads (1.5 m rise / 3.06 m run each), 1.6 m landing, opening z 13.4–16.6; stash porch 3 x 4 x 3 m |
| Ship pad | `scripts/launchpad_ship.gd`, `scripts/ship_pad_finish_v094.gd`, `assets/kit/launchpad_ship.glb` | wall face r 8.0, top 1.28 (glb surface 0 "Warm stone concrete", +0.18 node offset); PadDeck collider r 7.9 h 1.28; 32 EdgeRail sectors at r 7.65 with sectors 23/24 open = ramp gap ±11.25° about pad +Z (= RampRail x ±1.56); foliage reserve r 8.45 |
| Build grid | `scripts/build_snap.gd`, `assets/kit/wall.glb` | 2.0 m cells; kit wall 2.0 x 3.0 m |

So: **run module 2.0 m, horizontal grid 1.0 m, deck level 3.0 m, vertical course period 1.5 m (= one stair flight).**
Pad: **11.25° arc modules (32 per ring) at R 8.02, deck level 1.29.**

## Modules (one glTF each; nodes `<id>_LOD0`, `<id>_LOD1`, `<id>_col`)
| id | run | deck level | notes |
|---|---|---|---|
| retaining_wall_straight | 2.0 m | 3.0 | tiles with itself at any count |
| retaining_wall_corner | 1.0 m front + 1.0 m return | 3.0 | outer 90° corner, returns to local -Z; alternating long/short quoins |
| retaining_wall_end | 1.0 m + 0.45 m quoined end face | 3.0 | right-hand end; **left-hand end = scale.x -1** |
| retaining_wall_stair_side | 3.0 m | 1.5 → 3.0 (1:2, hideout pitch) | stair cheek; lower flight = place at y -1.5; other side of a stair = scale.x -1; hideout run 3.06 m = scale.x 1.02 |
| retaining_wall_pad_curve | 11.25° arc (1.575 m at the face) | 1.29 | 28 per pad ring |
| retaining_wall_pad_end | 11.25° arc + 0.45 m quoined end face | 1.29 | ramp opening; one normal, one mirrored |

### Snap point / axes (all modules)
* **Origin = bottom of the mortar plane (front face) at the module's start, deck-grid level 0.** Stones continue 0.25 m below
  the origin as buried footing.
* Godot: run along **+X**, front faces **+Z**, body 0.45 m deep toward -Z, coping overhangs +Z by 0.09 m and tops out
  **0.04 m above deck level** (3.04 / 1.33). Next module origin = this origin + 2.0 (straight) / 3.0 (stair) along +X.
  After a corner, next origin = corner origin + (1, 0, -1) with the next run rotated -90° (Basis(UP, θ+π/2)).
* Orientation for a face with outward normal n: `theta = atan2(n.x, n.z)` → `Basis(Vector3.UP, theta)`.
* Vertical: offset modules only by multiples of **1.5 m** where two modules share a face (courses line up).
* Mirroring (scale.x -1) is fine. Godot flips the winding for negative scale.

### Why the seams don't show
Stone joints are periodic, with a 1.0 m period on the terrace and one module per period on the pad, and 6 courses in 1.5 m. Every stone
that crosses a module boundary comes from the same canonical seed on both sides: same relief, same UV offset,
and analytic normals. The cut is a straight line through one continuous stone. Coping joints fall on the module
boundaries. See `retaining_walls_seam.jpg`: raking light, two boundaries in frame.

## Placement
### Hideout terrace — Option A (no deletions; enclose the old wall)
The old courses, coping, drip strip and base course stick out up to 0.1125 m from the box face. Put the mortar plane
**0.12 m outside** the old faces and scale every terrace module **(1.015, 1, 1.015)**, because the faces become 16.24 m.
All old geometry then sits inside the new wall, with no z-fighting and no script edits. Faces (run, outward, start corner):
S: +X, +Z, (-32.12, 0, 23.12) · E: -Z, +X, (-15.88, 0, 23.12) · N: -X, -Z, (-15.88, 0, 6.88) · W: +Z, -X, (-32.12, 0, 6.88).
Each clean face = corner-return (1) + 7 straights at u = 1,3,…,13 + corner at u = 15 (u in metres x 1.015 along the run).
The S, W and N faces plus the porch's three faces (3 m = straight + corner; 4 m = return + straight + corner) tile exactly.

### Hideout terrace — Option B (cleaner)
Stop building `Retaining stone courses`, the three `Retaining … coping` boxes (hideout_terrace.gd), and the
`Coping drip shadow` / `Base contact course` boxes (home_finish_v094.gd). Then put the mortar plane on the old box faces at scale 1.0
(16 m faces, exact 2 m grid).

### Ship pad (pad-local, LaunchpadShip root at (22,0,-16))
Module k (k = 0..31) covers polar angles [k·11.25°, (k+1)·11.25°] measured from +Z toward +X; the ramp gap is k = 31 and 0.
```gdscript
const R := 8.02; const D := deg_to_rad(11.25)
for k in range(1, 31):
    var id := "retaining_wall_pad_curve"; var a := k * D; var sx := 1.0
    if k == 1: id = "retaining_wall_pad_end"; a = 2 * D; sx = -1.0   # mirrored, end face at +11.25°
    elif k == 30: id = "retaining_wall_pad_end"                       # end face at -11.25°
    var n := (load("res://assets/retaining_walls/%s.gltf" % id) as PackedScene).instantiate()
    n.transform = Transform3D(Basis(Vector3.UP, a) * Basis.from_scale(Vector3(sx, 1, 1)), Basis(Vector3.UP, a) * Vector3(0, 0, R))
    pad.add_child(n)
```
The mortar plane at R 8.02 sits 2 cm outside the old glb wall face (r 8.0). The coping (r 8.11 → 7.57, top 1.33) caps the old
1.28 top edge, so the glb stays untouched.
Tested headless in Godot 4.6.3 (`build/place_rw.gd`): adjacent snap points meet within 2e-6 m, and the end faces land at ±11.25°.

## Specs
* Budgets: LOD0 2.7k–8.2k tris per module, LOD1 = 39–42% of LOD0. LOD1 is a coarser procedural rebuild, not a decimation, so its
  seams stay closed too. Exact counts are in BUILD-REPORT.json.
* Materials (3, shared by all six): RW_Stone (rw_stone set), RW_Cap (rw_cap set), RW_Mortar (rw_cap x baseColorFactor
  0.50/0.48/0.44). Single-sided, opaque. Textures 1024², tileable, 1 tile = 1.0 m; ORM = R occl / G rough / B metal (0);
  normal OpenGL.
* Collision `<id>_col`: boxes hidden via KHR_node_visibility. Godot builds a static trimesh body from them, same as
  the other kits. Straight/end = 1 box; corner = 2; stair_side = 6 stepped boxes following the 1:2 coping; pad = 1 chord box.
* Units metres, +Y up, transforms applied, every mesh node at identity.

## Rebuild
    python3 build/make_textures_rw.py textures
    RW_TEX=textures blender -b --factory-startup -P build/build_retaining_walls.py -- <out_dir> [ids]
    blender -b --factory-startup -P build/render_previews.py -- <out_dir> <preview_dir> [views] [samples] [LOD0|LOD1]
    python3 build/make_report.py <handoff_dir>

## Integration flags
1. **Pad wall is baked into `launchpad_ship.glb`** (surface 0, shared with the deck and ramp). `ship_construction_v096.gd`
   asserts 10 surfaces and `ship_pad_finish_v094.gd` asserts surface 5, so don't edit the glb. The modules shell
   the old wall instead (2 cm outside it). glb rail posts at r ≈ 7.65 rise through the coping, which is intended.
2. **Pad collision:** `PadDeck` (cylinder r 7.9) already blocks. The module `_col` boxes reach r 8.11 and 1.33 m. Keep them, or
   skip the pad `_col` nodes if you don't want doubled colliders. The 8.45 m foliage reserve (`reconcile_border`) still clears.
3. **Hideout Option A adds 0.12 m per side** (footprint 16.24 m, coping out to +0.21 m). Nothing in hideout_terrace's
   reservations (16.5 m box at -32.5) is crossed, but `path_foliage_finish.gd` reads the terrace's CollisionShape3Ds. The
   new module bodies are separate scenes, so add them outside `RaisedHideoutTerrace`, or check that script's expectations.
   `batch_static_visuals()` only batches BoxMesh MeshInstances, so glTF modules under the terrace root are left alone.
4. **East face of the hideout is off-grid:** the stair opening z 13.4–16.6, the 1.6 m landing, and the 1.4 m / 5.4 m wall
   pieces aren't 1 m multiples. Either nudge them in `hideout_terrace.gd` (landing 1.6 → 2.0, opening to a 1 m multiple)
   or X-scale the few modules there (≤ 10%). Equal scales on neighbours keep the seam clean; a scaled module next to an
   unscaled one shows a few-mm head-joint offset at that one joint. Stair flights: stair_side at scale.x 1.02 (3.06 m run).
5. **Stair cheek back face** (stair side) is a flat textured plane, like every module's back. In the hideout it's
   hidden by the solid step blocks except the coping. In a free-standing use, the back would read flat.
6. **Joint layout repeats every 1.0 m** horizontally and 1.5 m vertically. Stone relief, tone and UV offset vary per stone inside
   a module, so it reads as coursed ashlar rather than a tiled texture (see tiled_run / run_front). Ivy from
   `settlement_visuals_style_test.gd` sits at x -15.80 (0.20 m out). With Option A the new face is at -15.88 + stones,
   so move that ivy out ~0.15 m or it intersects.
7. Collision imports as trimesh StaticBody3D (Godot `_col` convention), same as the previous kits.
