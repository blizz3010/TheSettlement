extends RefCounted
## TASKS item 5: Artie's P2 art handoffs, render-side swaps at runtime (no pinned script or scene edits).
##   tailor   - assets/tailor_dyes_stall   replaces the TailorAtelier blockout meshes (colliders kept)
##   rocks    - assets/bed_rocks a-e       replace planting_dense/small_rock_group MultiMesh batches
##   planters - assets/screens_planters    plaza_planter / plaza_planter_fern inside the kit planter nodes
##   board    - assets/screens_planters    request_board_woven replaces the RequestBoard art
##   trees    - assets/plaza_trees         place_plaza_trees.gd on PlazaIslandComposition (Tree_left/right)
## Distant hills (assets/distant_hills) install separately at activation (place_distant_hills.gd).
## The swaps wait until every startup controller has settled, so the inn / garden / tailor planners
## see exactly the scene they were written against. P2_ART=off skips all; P2_<ITEM>=off skips one.
## Each swap is idempotent and keeps the replaced nodes in the tree (hidden), so their consumers
## (grounding, journals, accessibility probes) are untouched.

const ITEMS := ["tailor", "rocks", "planters", "board", "trees"]
const TAILOR := "res://assets/tailor_dyes_stall/tailor_dyes_stall.gltf"
const ROCKS := ["a", "b", "c", "d", "e"]
const ROCK_DIR := "res://assets/bed_rocks/"
const SP_DIR := "res://assets/screens_planters/"
const PlazaTrees = preload("res://raid/scripts/place_plaza_trees.gd")
const DistantHills = preload("res://raid/scripts/place_distant_hills.gd")

# visibility ranges (metres): [LOD0 end, margin]; LOD1 draws from that end onward
const LOD_END := {"tailor": 25.0, "planters": 20.0, "board": 20.0, "rocks": 14.0}
const LOD_MARGIN := 1.5
const TIMEOUT_MS := 900000

static func enabled(item := "") -> bool:
	if OS.get_environment("P2_ART") == "off":
		return false
	return item == "" or OS.get_environment("P2_" + item.to_upper()) != "off"

## Called after far_scenery_options.apply in activate_loaded_world (distant hills) and at the end of
## both startup passes (deferred swaps). Safe to call any number of times.
static func install(world: Node3D) -> void:
	if not enabled() or not is_instance_valid(world) or not world.is_inside_tree():
		return
	if world.has_meta("p2_art") or world.has_meta("p2_art_pending"):
		return
	world.set_meta("p2_art_pending", true)
	var tree := world.get_tree()
	var state := {"cb": Callable(), "settled": 0, "activated_ms": -1}
	state.cb = func() -> void:
		if not is_instance_valid(world):
			tree.process_frame.disconnect(state.cb)
			return
		if world.get("world_activated") == true and state.activated_ms < 0:
			state.activated_ms = Time.get_ticks_msec()
		var settled := controllers_settled(world)
		state.settled = state.settled + 1 if settled else 0
		var timed_out: bool = state.activated_ms >= 0 and Time.get_ticks_msec() - state.activated_ms > TIMEOUT_MS
		if state.settled >= 3 or timed_out:
			tree.process_frame.disconnect(state.cb)
			var r := apply(world)
			r["after_settle"] = settled
			world.remove_meta("p2_art_pending")
			world.set_meta("p2_art", r)
	tree.process_frame.connect(state.cb)

static func install_distant_hills(world: Node3D) -> Dictionary:
	if not enabled("hills"):
		return {"ok": true, "skipped": true}
	var r: Dictionary = DistantHills.install(world)
	world.set_meta("p2_distant_hills", r)
	return r

static func controllers_settled(world: Node3D) -> bool:
	if world.get("world_activated") != true:
		return false
	for c in world.get_children():
		if not "attempted" in c:
			continue
		if not bool(c.get("attempted")):
			return false
		if "result" in c and c.get("result") is Dictionary and (c.get("result") as Dictionary).is_empty():
			return false
	return true

## Synchronous swap of every enabled item (tests and probes may call it directly).
static func apply(world: Node3D) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var out := {"ok": true}
	for item in ITEMS:
		if not enabled(item):
			out[item] = {"ok": true, "skipped": true}
			continue
		var r: Dictionary = {}
		match item:
			"tailor": r = tailor(world)
			"rocks": r = bed_rocks(world)
			"planters": r = planters(world)
			"board": r = board(world)
			"trees": r = plaza_trees(world)
		out[item] = r
		if not r.get("ok", false):
			out.ok = false
			push_warning("P2 art %s skipped: %s" % [item, str(r.get("reason", r))])
	out["install_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	return out

# ---------------------------------------------------------------- helpers
static func set_lods(root: Node, lod0_end: float) -> void:
	for mi in root.find_children("*_LOD?", "GeometryInstance3D", true, false):
		var k := int(String(mi.name).right(1))
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if k == 0:
			mi.visibility_range_begin = 0.0; mi.visibility_range_end = lod0_end
			mi.visibility_range_begin_margin = 0.0; mi.visibility_range_end_margin = LOD_MARGIN
		else:
			mi.visibility_range_begin = lod0_end; mi.visibility_range_end = 0.0
			mi.visibility_range_begin_margin = LOD_MARGIN; mi.visibility_range_end_margin = 0.0

## Remove the imported `_col` bodies (hidden mesh + StaticBody3D) where the original collider stays.
static func drop_col(root: Node) -> int:
	var n := 0
	for body in root.find_children("*", "StaticBody3D", true, false):
		var holder := body.get_parent()
		if holder is MeshInstance3D and not String(holder.name).contains("_LOD"):
			holder.get_parent().remove_child(holder); holder.free(); n += 1
		else:
			body.get_parent().remove_child(body); body.free(); n += 1
	return n

static func tris(root: Node, lod := 0) -> int:
	var t := 0
	for mi in root.find_children("*_LOD%d" % lod, "MeshInstance3D", true, false):
		t += (mi as MeshInstance3D).mesh.get_faces().size() / 3
	return t

static func hide_meshes(root: Node, keep: Array) -> int:
	var hidden := 0
	for g in root.find_children("*", "GeometryInstance3D", true, false):
		if g is Label3D or g is Sprite3D or not (g as Node3D).visible:
			continue
		var skip := false
		for k in keep:
			if is_instance_valid(k) and (g == k or (k as Node).is_ancestor_of(g)):
				skip = true; break
		if skip:
			continue
		(g as Node3D).visible = false
		g.set_meta("p2_replaced", true)
		hidden += 1
	return hidden

# ---------------------------------------------------------------- (a) tailor
static func tailor(world: Node3D) -> Dictionary:
	var r := world.get_node_or_null("TailorAtelier") as Node3D
	if r == null:
		return {"ok": false, "reason": "TailorAtelier missing"}
	if r.has_node("P2TailorDyesStall"):
		return r.get_node("P2TailorDyesStall").get_meta("p2", {"ok": true, "reused": true})
	if not ResourceLoader.exists(TAILOR):
		return {"ok": false, "reason": "missing tailor_dyes_stall.gltf"}
	# Keep: the Tailor actor, the midstyle dress form swap, our own art. Lights are not geometry.
	var keep := []
	for c in r.find_children("*", "Node3D", true, false):
		var nm := String(c.name)
		if nm.begins_with("Midstyle") or c.find_children("*", "Skeleton3D", true, false).size() > 0 or c is Skeleton3D:
			keep.append(c)
	var hidden := hide_meshes(r, keep)
	var sign := r.get_node_or_null("TailorIdentitySign") as Node3D
	if sign:
		sign.visible = false   # the painted board reads "TAILOR & DYES"; the label stays for inspectors
	var art := (load(TAILOR) as PackedScene).instantiate() as Node3D
	art.name = "P2TailorDyesStall"
	var cols := drop_col(art)  # the blockout's essential-shell colliders stay authoritative
	set_lods(art, LOD_END.tailor)
	for mi in art.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	r.add_child(art)
	var res := {"ok": true, "hidden": hidden, "dropped_col": cols, "lod0_tris": tris(art, 0), "lod1_tris": tris(art, 1),
		"surfaces": _surfaces(art, 0), "sign_hidden": sign != null}
	art.set_meta("p2", res)
	return res

static func _surfaces(root: Node, lod: int) -> int:
	var s := 0
	for mi in root.find_children("*_LOD%d" % lod, "MeshInstance3D", true, false):
		s += (mi as MeshInstance3D).mesh.get_surface_count()
	return s

# ---------------------------------------------------------------- (b) bed rocks
static func rock_meshes() -> Array:
	var out := []
	for v in ROCKS:
		var scn := (load(ROCK_DIR + "bed_rock_%s.gltf" % v) as PackedScene).instantiate()
		var l0 := scn.find_child("bed_rock_%s_LOD0" % v, true, false) as MeshInstance3D
		var l1 := scn.find_child("bed_rock_%s_LOD1" % v, true, false) as MeshInstance3D
		out.append([l0.mesh, l1.mesh])
		scn.free()
	return out

static func pick(t: Transform3D) -> int:
	var h := hash(Vector2i(roundi(t.origin.x * 20.0), roundi(t.origin.z * 20.0)))
	return absi(h) % ROCKS.size()

static func in_pockets(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if String(p.name).contains("IntentionalPlantingPocket"):
			return true
		p = p.get_parent()
	return false

static func bed_rocks(world: Node3D) -> Dictionary:
	var batches := []
	for mmi in world.find_children("small_rock_group*", "MultiMeshInstance3D", true, false):
		if mmi.has_meta("p2_bed_rocks") or mmi.has_meta("p2_rock_lod") or mmi.multimesh == null or not mmi.visible:
			continue
		batches.append(mmi)
	if batches.is_empty():
		return {"ok": true, "batches": 0, "instances": 0, "reused": world.find_children("BedRock_*", "MultiMeshInstance3D", true, false).size() > 0}
	var meshes := rock_meshes()
	var count := 0; var pocket_tris := 0; var pocket_old := 0; var made := 0
	for mmi in batches:
		var mm: MultiMesh = mmi.multimesh
		var pocket := in_pockets(mmi)
		var groups := {}
		for i in mm.instance_count:
			var t := mm.get_instance_transform(i)
			var k := pick(t)
			if not groups.has(k): groups[k] = []
			groups[k].append(i)
		for k in groups:
			# Pockets keep the cheap LOD1 only (MAX_TRIANGLES note); beds elsewhere get LOD0 near, LOD1 far.
			for lod in ([1] if pocket else [0, 1]):
				var nm := MultiMesh.new()
				nm.transform_format = MultiMesh.TRANSFORM_3D
				nm.use_colors = mm.use_colors
				nm.mesh = meshes[k][lod]
				nm.instance_count = groups[k].size()
				for j in groups[k].size():
					var i: int = groups[k][j]
					nm.set_instance_transform(j, mm.get_instance_transform(i))
					if mm.use_colors: nm.set_instance_color(j, mm.get_instance_color(i))
				var b := MultiMeshInstance3D.new()
				b.name = "BedRock_%s_LOD%d" % [ROCKS[k], lod]
				b.multimesh = nm
				b.transform = mmi.transform
				b.cast_shadow = mmi.cast_shadow
				b.layers = mmi.layers
				b.set_meta("p2_rock_lod", lod)
				if not pocket:
					b.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
					if lod == 0:
						b.visibility_range_end = LOD_END.rocks; b.visibility_range_end_margin = LOD_MARGIN
					else:
						b.visibility_range_begin = LOD_END.rocks; b.visibility_range_begin_margin = LOD_MARGIN
				mmi.get_parent().add_child(b)
				made += 1
				if pocket:
					pocket_tris += nm.instance_count * (nm.mesh.get_faces().size() / 3)
		if pocket:
			pocket_old += mm.instance_count * (mm.mesh.get_faces().size() / 3)
		count += mm.instance_count
		mmi.visible = false
		mmi.set_meta("p2_bed_rocks", true)
	return {"ok": true, "batches": batches.size(), "instances": count, "new_batches": made,
		"pocket_rock_tris_before": pocket_old, "pocket_rock_tris_after": pocket_tris}

# ---------------------------------------------------------------- (c) planters + board
static func is_planter(n: Node) -> String:
	var p := String(n.scene_file_path)
	if p.ends_with("/planter.glb"): return "plaza_planter"
	if p.ends_with("/planter_fern_variant.glb"): return "plaza_planter_fern"
	return ""

static func planters(world: Node3D) -> Dictionary:
	var done := 0; var reused := 0; var hidden := 0
	var packs := {}
	for n in world.find_children("*", "Node3D", true, false):
		var id := is_planter(n)
		if id == "":
			continue
		if n.has_node("P2Planter"):
			reused += 1; continue
		if not packs.has(id):
			packs[id] = load(SP_DIR + id + ".gltf")
		hidden += hide_meshes(n, [])
		var art := (packs[id] as PackedScene).instantiate() as Node3D
		art.name = "P2Planter"
		set_lods(art, LOD_END.planters)   # _col kept: a 1.0 x 0.56 x 1.0 pot box (was walk-through)
		n.add_child(art)
		done += 1
	if done + reused == 0:
		return {"ok": false, "reason": "no kit planters found"}
	return {"ok": true, "swapped": done, "reused": reused, "hidden": hidden}

static func board(world: Node3D) -> Dictionary:
	var b := world.get_node_or_null("RequestBoard") as Node3D
	if b == null:
		return {"ok": false, "reason": "RequestBoard missing"}
	if b.has_node("P2RequestBoardWoven"):
		return b.get_node("P2RequestBoardWoven").get_meta("p2", {"ok": true, "reused": true})
	var hidden := hide_meshes(b, [])
	var art := (load(SP_DIR + "request_board_woven.gltf") as PackedScene).instantiate() as Node3D
	art.name = "P2RequestBoardWoven"
	var cols := drop_col(art)   # the original 1.8 x 1.5 x 0.15 collider stays
	set_lods(art, LOD_END.board)
	b.add_child(art)
	var res := {"ok": true, "hidden": hidden, "dropped_col": cols, "lod0_tris": tris(art, 0)}
	art.set_meta("p2", res)
	return res

# ---------------------------------------------------------------- (e) plaza trees
static func plaza_trees(world: Node3D) -> Dictionary:
	var visual := world.find_child("PlazaIslandComposition", true, false) as Node3D
	if visual == null:
		return {"ok": false, "reason": "PlazaIslandComposition missing"}
	var placed: Array = PlazaTrees.apply(visual)
	var have := 0
	for nm in ["Tree_left", "Tree_right"]:
		var t := visual.get_node_or_null(nm)
		if t != null and t.find_child("plaza_tree_*_LOD0", true, false) != null:
			have += 1
	return {"ok": have == 2, "placed": placed.size(), "present": have, "reason": "" if have == 2 else "trees missing"}
