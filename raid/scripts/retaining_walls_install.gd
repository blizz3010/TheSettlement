extends RefCounted
## TASKS item 5 (d), PR B: Artie's stone retaining-wall snap kit, render-side at runtime, no pinned edits.
##  Hideout terrace, Option A: no deletions. The mortar plane sits 0.12 m outside the old box faces, so the
##  old courses, coping, drip strip and base course all end up inside the new wall. Terrace modules are
##  scaled (1.015, 1, 1.015) for the 16.24 m faces. The off-grid east face (stair opening z 13.4..16.6) is
##  nudged: both runs that meet the stairs end GAP (0.05 m) short of the stair guard lines, so the quoined
##  end faces (1.09 m incl. the quoin) no longer reach into the top step and the rail posts (they did by
##  0.09-0.11 m). East main run x scale 6.2 %, porch strip 12.8 % (was 28 %). See segments().
##  Modules live under world/P2RetainingWalls (outside RaisedHideoutTerrace, whose collision shapes
##  path_foliage_finish.gd reads). Their _col boxes are kept on the terrace (12 cm proud of the old face).
##  Ship pad: 30 modules at R 8.02 shell the wall baked into launchpad_ship.glb (glb untouched), leaving the
##  ramp gap at +-11.25 deg (RampRail x +-1.56). The pad _col boxes are dropped: PadDeck already blocks, and
##  the #31 boarding route, ring and ramp-side pocket beds must not change.
##  Dressing that sat on the old faces moves out with the new face: the style-test ivy (+0.15 m), the hanging
##  baskets (+0.17 m) and the "Your Home" plaque (+0.10 m). Ground foliage instances (path_foliage_finish.gd
##  and the border batches) whose origin falls inside the new wall band are pushed out of it.
## Called by p2_walls_fixes.gd once every startup controller has settled.

const DIR := "res://assets/retaining_walls/"
const NAME := "P2RetainingWalls"
const S := 1.015
const PAD_R := 8.02
const PAD_D := deg_to_rad(11.25)
const LOD0_END := 30.0
const LOD_MARGIN := 2.0
const TIMEOUT_MS := 900000
const DRESS_SHIFT := 0.17
const IVY_SHIFT := 0.15
const END_LEN := 1.09   # end module run incl. the quoined end face (_col max x)
const GAP := 0.05      # clearance kept from the stair guard lines z 13.4 / 16.6
const BAND := 0.30     # foliage band outside the old faces (new face 0.12 + stones + coping 0.21)
const FOLIAGE_HOLDERS := ["NaturalBorder", "SouthernGroundcover", "WalkwayPlanting", "RouteGardens", "RaisedHideoutTerrace"]
const PLAQUE_SHIFT := 0.10

## Hideout runs: [label, start corner, run direction, outward normal, modules]
## modules: [id, u (m along the run), x scale, z scale, mirrored]
static func segments() -> Array:
	var out := []
	var clean := []   # corner return (from the previous face) + 7 straights + corner
	for i in 7: clean.append(["retaining_wall_straight", S * (1 + 2 * i), S, S, false])
	clean.append(["retaining_wall_corner", S * 15, S, S, false])
	out.append(["south", Vector3(-32.12, 0, 23.12), Vector3(1, 0, 0), Vector3(0, 0, 1), clean])
	out.append(["north", Vector3(-15.88, 0, 6.88), Vector3(-1, 0, 0), Vector3(0, 0, -1), clean])
	out.append(["west", Vector3(-32.12, 0, 6.88), Vector3(0, 0, 1), Vector3(-1, 0, 0), clean])
	# East face (run -Z from z 23.12): the south corner's return covers 23.12 -> 22.105.
	# Porch strip 17.88 -> 16.6 (1.28 m): one right-hand end, its quoin stopping GAP short of z 16.6.
	var ps := (23.12 - 16.6 - GAP - (23.12 - 17.88)) / END_LEN
	out.append(["east_porch_strip", Vector3(-15.88, 0, 23.12), Vector3(0, 0, -1), Vector3(1, 0, 0),
		[["retaining_wall_end", 23.12 - 17.88, ps, S, false]]])
	# Stairs side 13.4 -> 6.88: mirrored left-hand end (quoin GAP short of z 13.4) + 2 straights + corner,
	# the corner's outer face on the north face line (u 16.24): a + GAP + 1.09 e + 5 e = 16.24.
	var a := 23.12 - 13.4
	var e := (16.24 - a - GAP) / (END_LEN + 5.0)
	var u0 := a + GAP + END_LEN * e
	out.append(["east_main", Vector3(-15.88, 0, 23.12), Vector3(0, 0, -1), Vector3(1, 0, 0),
		[["retaining_wall_end", u0, e, S, true], ["retaining_wall_straight", u0, e, S, false],
		["retaining_wall_straight", u0 + 2 * e, e, S, false], ["retaining_wall_corner", u0 + 4 * e, e, S, false]]])
	# Stash porch (x -16..-13, z 18..22): south 3.0 m, east 4.24 m, north 3.0 m.
	var pe := 4.24 / 4.0
	out.append(["porch_south", Vector3(-15.88, 0, 22.12), Vector3(1, 0, 0), Vector3(0, 0, 1),
		[["retaining_wall_straight", 0.0, 1.0, pe, false], ["retaining_wall_corner", 2.0, 1.0, pe, false]]])
	out.append(["porch_east", Vector3(-12.88, 0, 22.12), Vector3(0, 0, -1), Vector3(1, 0, 0),
		[["retaining_wall_straight", pe, pe, 1.0, false], ["retaining_wall_corner", 3 * pe, pe, 1.0, false]]])
	out.append(["porch_north", Vector3(-12.88, 0, 17.88), Vector3(-1, 0, 0), Vector3(0, 0, -1),
		[["retaining_wall_straight", 1.0, 1.0, 1.0, false]]])
	return out


static func put(parent: Node3D, id: String, origin: Vector3, theta: float, sx: float, sz: float, mirror: bool) -> Node3D:
	var n := (load(DIR + id + ".gltf") as PackedScene).instantiate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, theta) * Basis.from_scale(Vector3(-sx if mirror else sx, 1, sz)), origin)
	for mi in n.find_children("*_LOD?", "MeshInstance3D", true, false):
		var k := int(String(mi.name).right(1))
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if k == 0:
			mi.visibility_range_end = LOD0_END; mi.visibility_range_end_margin = LOD_MARGIN
		else:
			mi.visibility_range_begin = LOD0_END; mi.visibility_range_begin_margin = LOD_MARGIN
	parent.add_child(n)
	return n

static func drop_col(n: Node) -> int:
	var c := 0
	for body in n.find_children("*", "StaticBody3D", true, false):
		var holder := body.get_parent()
		if holder is MeshInstance3D and not String(holder.name).contains("_LOD"):
			holder.get_parent().remove_child(holder); holder.free()
		else:
			body.get_parent().remove_child(body); body.free()
		c += 1
	return c

static func tris(root: Node, lod: int) -> int:
	var t := 0
	for mi in root.find_children("*_LOD%d" % lod, "MeshInstance3D", true, false):
		t += (mi as MeshInstance3D).mesh.get_faces().size() / 3
	return t

static func apply(world: Node3D) -> Dictionary:
	if world.has_node(NAME):
		return world.get_node(NAME).get_meta("p2", {"ok": true, "reused": true})
	var terrace := world.get_node_or_null("RaisedHideoutTerrace") as Node3D
	var ship := world.get_node_or_null("LaunchpadShip") as Node3D
	if terrace == null or ship == null:
		return {"ok": false, "reason": "RaisedHideoutTerrace or LaunchpadShip missing"}
	var t0 := Time.get_ticks_usec()
	var root := Node3D.new(); root.name = NAME
	world.add_child(root)
	var hideout := Node3D.new(); hideout.name = "Hideout"; root.add_child(hideout)
	var n_hide := 0
	for seg in segments():
		var start: Vector3 = seg[1]; var run: Vector3 = seg[2]; var nrm: Vector3 = seg[3]
		var theta := atan2(nrm.x, nrm.z)
		var holder := Node3D.new(); holder.name = String(seg[0]); hideout.add_child(holder)
		for m in seg[4]:
			var o: Vector3 = start + run * float(m[1])
			put(holder, m[0], o, theta, m[2], m[3], m[4]); n_hide += 1
	# pad ring, pad-local (Artie's loop); parented to the ship root so it follows its transform
	var pad := Node3D.new(); pad.name = "P2PadRetainingWall"; ship.add_child(pad)
	var dropped := 0; var n_pad := 0
	for k in range(1, 31):
		var id := "retaining_wall_pad_curve"; var a := k * PAD_D; var mirror := false
		if k == 1:
			id = "retaining_wall_pad_end"; a = 2 * PAD_D; mirror = true
		elif k == 30:
			id = "retaining_wall_pad_end"
		var m := put(pad, id, Basis(Vector3.UP, a) * Vector3(0, 0, PAD_R), a, 1.0, 1.0, mirror)
		dropped += drop_col(m); n_pad += 1
	var moved := move_dressing(world)
	var foliage := clear_foliage_band(world)
	var res := {"ok": true, "hideout_modules": n_hide, "pad_modules": n_pad, "pad_col_dropped": dropped,
		"hideout_lod0_tris": tris(hideout, 0), "pad_lod0_tris": tris(pad, 0), "dressing_moved": moved,
		"foliage_pushed": foliage, "east_scales": east_scales(),
		"install_ms": (Time.get_ticks_usec() - t0) / 1000.0}
	root.set_meta("p2", res)
	return res

## Outward direction for a point hugging one of the old terrace / porch faces, else ZERO.
static func face_out(p: Vector3) -> Vector3:
	if absf(p.x + 15.9) < 0.5 and p.z > 6.5 and p.z < 23.5: return Vector3.RIGHT
	if absf(p.x + 12.85) < 0.5 and p.z > 17.5 and p.z < 22.5: return Vector3.RIGHT
	if absf(p.x + 32.1) < 0.5 and p.z > 6.5 and p.z < 23.5: return Vector3.LEFT
	if absf(p.z - 23.1) < 0.5 and p.x > -32.5 and p.x < -15.5: return Vector3.BACK
	if absf(p.z - 6.9) < 0.5 and p.x > -32.5 and p.x < -15.5: return Vector3.FORWARD
	return Vector3.ZERO

static func move_dressing(world: Node3D) -> Dictionary:
	var out := {"ivy_instances": 0, "baskets": 0, "plaque": false}
	var style := world.find_child("IvyLeaves", true, false) as MultiMeshInstance3D
	if style and style.multimesh:
		var mm := style.multimesh
		for i in mm.instance_count:
			var t := mm.get_instance_transform(i)
			var g := style.global_transform * t
			var d := face_out(g.origin)
			if d != Vector3.ZERO:
				g.origin += d * IVY_SHIFT
				mm.set_instance_transform(i, style.global_transform.affine_inverse() * g)
				out.ivy_instances += 1
	for b in world.find_children("HangingBasket*", "Node3D", true, false):
		var d := face_out((b as Node3D).global_position)
		if d != Vector3.ZERO:
			(b as Node3D).global_position += d * DRESS_SHIFT
			out.baskets += 1
	var plaque := world.find_child("YourHomePhysicalSign", true, false) as Node3D
	if plaque and face_out(plaque.global_position) == Vector3.RIGHT:
		plaque.global_position += Vector3.RIGHT * PLAQUE_SHIFT
		out.plaque = true
	return out

static func east_scales() -> Dictionary:
	var out := {}
	for seg in segments():
		if String(seg[0]).begins_with("east"):
			out[seg[0]] = snappedf(float(seg[4][0][2]), 0.0001)
	return out

## Signed distance outside the old terrace / porch face a point hugs (0 if not near one).
static func band_depth(p: Vector3, extra := 0.0) -> Dictionary:
	if p.y > 2.0: return {}   # only ground planting at the wall foot, never the terrace top
	var faces := [[Vector3.RIGHT, -16.0, p.x, p.z > 6.5 and p.z < 23.5 and not (p.z > 18.0 and p.z < 22.0)],
		[Vector3.RIGHT, -13.0, p.x, p.z > 17.7 and p.z < 22.3],
		[Vector3.LEFT, 32.0, -p.x, p.z > 6.5 and p.z < 23.5],
		[Vector3.BACK, 23.0, p.z, p.x > -32.5 and p.x < -15.5],
		[Vector3.FORWARD, -7.0, -p.z, p.x > -32.5 and p.x < -15.5],
		[Vector3.BACK, 22.0, p.z, p.x > -16.2 and p.x < -12.7],
		[Vector3.FORWARD, -18.0, -p.z, p.x > -16.2 and p.x < -12.7]]
	for f in faces:
		var d: float = float(f[2]) - float(f[1])
		if f[3] and d > -0.05 and d < BAND + extra:
			if f[0] == Vector3.RIGHT and f[1] == -16.0 and p.z > 13.35 and p.z < 16.65:
				continue   # stair opening: no new wall there
			return {"n": f[0], "d": d}
	return {}

## path_foliage_finish.gd moved the shrub and low-flora batches (same holders, same predicate as below)
## off the OLD terrace collision faces before this kit existed, so some now stand inside the new wall
## band. Push those instances just outside it and keep each batch's `source_transforms` authority (the
## metadata path_foliage_finish.gd itself maintains) in step, so nothing re-applies the old spots.
## Shrubs keep 0.25 m more clearance (canopy). Batches path_foliage_finish.gd does not touch are left alone.
static func clear_foliage_band(world: Node3D) -> Dictionary:
	var out := {"instances": 0, "batches": [], "reference_shrubs": 0}
	for h in FOLIAGE_HOLDERS:
		var holder := world.get_node_or_null(h)
		if holder == null: continue
		for batch in holder.find_children("*", "MultiMeshInstance3D", true, false):
			var nm := String(batch.name)
			var is_shrub := nm.contains("shrub")
			var is_low_flora := nm.contains("ground_") and not nm.contains("grass") and batch.has_meta("source_transforms")
			if not is_shrub and not is_low_flora: continue
			var mm := (batch as MultiMeshInstance3D).multimesh
			if mm == null: continue
			var gt := (batch as Node3D).global_transform
			var authority: Array = batch.get_meta("source_transforms", []).duplicate()
			var extra := 0.25 if is_shrub else 0.0
			var touched := 0
			for i in mm.instance_count:
				var g := gt * mm.get_instance_transform(i)
				var b := band_depth(g.origin, extra)
				if b.is_empty(): continue
				g.origin += (b.n as Vector3) * (BAND + extra + 0.01 - float(b.d))
				var local := gt.affine_inverse() * g
				mm.set_instance_transform(i, local)
				if i < authority.size(): authority[i] = local
				touched += 1
			if touched > 0:
				if batch.has_meta("source_transforms"): batch.set_meta("source_transforms", authority)
				out.instances += touched
				(out.batches as Array).append("%s:%d" % [world.get_path_to(batch), touched])
	var ref := world.get_node_or_null("ReferenceFoliage")
	if ref:
		for shrub in ref.get_children():
			if not String(shrub.name).begins_with("Shrub") or not shrub is Node3D: continue
			var b := band_depth((shrub as Node3D).global_position, 0.25)
			if b.is_empty(): continue
			(shrub as Node3D).global_position += (b.n as Vector3) * (BAND + 0.26 - float(b.d))
			out.reference_shrubs += 1
	return out
