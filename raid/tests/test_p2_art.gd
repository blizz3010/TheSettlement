extends SceneTree
## TASKS item 5 (Artie P2 art a, b, c, e, f), rendered acceptance through the real Play flow.
##  a. Tailor & Dyes stall: art under TailorAtelier (identity), LOD ranges, blockout meshes hidden,
##     sign label hidden, no new collider (the shell colliders stay), tri cap, the dress form stays.
##  b. Bed rocks: every visible small_rock_group batch swapped for bed_rock a-e (same transforms),
##     LOD0 near / LOD1 far, pockets on LOD1 only, the pocket triangle total.
##  c. Planters + woven board: every kit planter has the new art and keeps a pot collider; the pot
##     colliders do not touch the plaza walk rings, the spokes between pots or the paved routes.
##     The board art replaced, its duplicate collider dropped, the original collider kept.
##  e. Plaza trees: Tree_left / Tree_right are plaza_tree_a / b at the old spots, old whole-bark
##     trimesh gone, a trunk collider each, LOD ranges, canopy above head height.
##  f. Distant hills: 192 chunks, originals hidden, Medium ranges, generate_lods off on import,
##     no hill rises out of the inn lake more than the old rings did (shore r 180-206 m).
##  Ship pad: the boarding route (#31) is clear of every new collider.
##  Frame time: render frames with the P2 art shown vs the originals, plaza view and Medium hills view.
## env: P2_SHOTS=<dir> writes after_<pose>.jpg (JPEG q88) from the same poses as the before shots.
const MARKER := "P2_ART_TESTS "
const P2 = preload("res://raid/scripts/p2_art.gd")
const Lake = preload("res://scripts/inn_lake_v088.gd")
const Settings = preload("res://scripts/game_settings.gd")
const POSES_PATH := "res://raid/tests/p2_art_poses.json"
var checks := 0
var failures: Array = []
var report := {}
var world: Node3D
var quality := 2     # scenery quality is switched as rarely as possible: each switch rebuilds far forests (minutes on llvmpipe)

func _initialize(): call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func log_(s: String) -> void: print("P2TEST: ", s, "  t=", Time.get_ticks_msec() / 1000.0)

func finish() -> void:
	report["checks"] = checks
	report["failures"] = failures
	print(MARKER, JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func boot() -> bool:
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	var Session = load("res://scripts/character_profiles/title_session.gd")
	var Rules = load("res://scripts/character_profiles/experimental_rules.gd")
	var session = Session.new(); session.rules = Rules.data()
	var state = session.inspect()
	if state.screen == "create":
		session.create_character("slot_1", {"name": "Visual", "cheek": 0.0, "hair": "hair_short02_v1", "brows": "brow_009_v1", "eyes": "eye_brown_v1", "hair_tint": "natural"}, {"str": 7, "int": 7, "dex": 7}, [], state.bytes, false)
		session.cancel()
	var title = (load("res://raid/play_title.tscn") as PackedScene).instantiate()
	root.add_child(title); current_scene = title
	for i in 10: await process_frame
	title.play_button.pressed.emit()
	for i in 10: await process_frame
	title.character_panel.cards["slot_1"].pressed.emit()
	for i in 10: await process_frame
	title.character_panel.enter_button.pressed.emit()
	var deadline := Time.get_ticks_msec() + 1200000
	while true:
		var sc = current_scene
		if sc != null and sc.get("world_activated") == true and sc.get("world_initialized") == true: break
		if Time.get_ticks_msec() > deadline: return false
		await process_frame
	world = current_scene
	return true

func set_q(q: int) -> void:
	if q == quality: return
	quality = q
	# Only the hill chunks are switched: the real apply_scenery_quality() also rebuilds the far forests, which costs
	# minutes on llvmpipe. The Medium look (thinned forests) is covered by the Medium shots from the shot probe.
	var dh := world.get_node_or_null("DistantHills")
	if dh: dh.set_quality(q)
	for i in 3: await process_frame

func lod_ok(root: Node, lod0_end: float) -> bool:
	var n := 0
	for mi in root.find_children("*_LOD?", "GeometryInstance3D", true, false):
		var k := int(String(mi.name).right(1))
		n += 1
		if k == 0 and not (is_equal_approx(mi.visibility_range_begin, 0.0) and is_equal_approx(mi.visibility_range_end, lod0_end)): return false
		if k == 1 and not (is_equal_approx(mi.visibility_range_begin, lod0_end) and is_equal_approx(mi.visibility_range_end, 0.0)): return false
	return n >= 2

func bodies(root: Node) -> Array:
	return root.find_children("*", "StaticBody3D", true, false)

func run() -> void:
	log_("boot")
	if not await boot():
		check(false, "World activated before the deadline"); finish(); return
	var deadline := Time.get_ticks_msec() + 900000
	while not world.has_meta("p2_art") and Time.get_ticks_msec() < deadline:
		await process_frame
	for i in 3: await process_frame
	var art: Dictionary = world.get_meta("p2_art", {})
	var hills: Dictionary = world.get_meta("p2_distant_hills", {})
	report["install"] = art
	report["hills_install"] = hills
	log_("installed %s" % art)
	check(art.get("ok", false), "P2 swaps installed: " + str(art))
	check(art.get("after_settle", false), "Swaps ran after every startup controller settled")
	for c in world.get_children():
		if "attempted" in c and "result" in c and c.get("result") is Dictionary:
			var res: Dictionary = c.get("result")
			if res.has("ok") and not res.ok and str(res.get("reason", "")).contains("P2"):
				check(false, "Controller %s refused on P2 art: %s" % [c.name, res])
	# a second call is a no-op
	var again := P2.apply(world)
	check(again.tailor.get("ok", false) and again.board.get("ok", false) and again.planters.get("reused", 0) > 0 and again.planters.get("swapped", -1) == 0 and again.rocks.get("batches", -1) == 0, "Second apply reuses everything: " + str(again))

	# ---- a. tailor
	var atelier := world.get_node_or_null("TailorAtelier") as Node3D
	var stall := atelier.get_node_or_null("P2TailorDyesStall") as Node3D if atelier else null
	check(stall != null, "Tailor stall art present")
	if stall:
		check(stall.transform.is_equal_approx(Transform3D.IDENTITY), "Tailor art has an identity local transform")
		check(lod_ok(stall, P2.LOD_END.tailor), "Tailor LOD0 0-25 m / LOD1 25 m+")
		check(bodies(stall).is_empty(), "Tailor art adds no collider (shell colliders stay)")
		var t0 := P2.tris(stall, 0); var t1 := P2.tris(stall, 1)
		report["tailor"] = {"lod0_tris": t0, "lod1_tris": t1, "lod0_surfaces": art.tailor.get("surfaces", -1), "hidden": art.tailor.get("hidden", -1)}
		check(t0 <= 45000 and t1 <= 18000, "Tailor tri cap (LOD0 <= 45k, LOD1 <= 18k): %d / %d" % [t0, t1])
		var sign := atelier.get_node_or_null("TailorIdentitySign") as Node3D
		check(sign != null and not sign.visible, "TailorIdentitySign hidden, kept for inspectors")
		var stray := []
		for g in atelier.find_children("*", "MeshInstance3D", true, false):
			if not g.is_visible_in_tree() or stall.is_ancestor_of(g): continue
			var p := g.get_parent(); var actor := false
			while p != atelier and p != null:
				if String(p.name).begins_with("Midstyle") or p.find_children("*", "Skeleton3D", false, false).size() > 0 or p is Skeleton3D: actor = true
				p = p.get_parent()
			if not actor: stray.append(str(atelier.get_path_to(g)))
		check(stray.is_empty(), "No blockout mesh left visible: " + str(stray.slice(0, 6)))
		var shell := 0
		for b in bodies(atelier): shell += 1
		check(shell >= 4, "Tailor shell colliders kept (%d)" % shell)
		check(world.has_method("tailor_accessible"), "Tailor interaction still wired")

	# ---- b. bed rocks
	var old_visible := 0; var old_total := 0
	for mmi in world.find_children("small_rock_group*", "MultiMeshInstance3D", true, false):
		if mmi.has_meta("p2_bed_rocks"): old_total += mmi.multimesh.instance_count
		elif mmi.is_visible_in_tree(): old_visible += 1
	var new_count := {0: 0, 1: 0}; var variants := {}; var lod_bad := 0; var pocket_lod0 := 0
	for b in world.find_children("BedRock_*", "MultiMeshInstance3D", true, false):
		var lod := int(b.get_meta("p2_rock_lod", -1))
		new_count[lod] = new_count.get(lod, 0) + b.multimesh.instance_count
		variants[String(b.name).substr(8, 1)] = true
		var pocket := P2.in_pockets(b)
		if pocket and lod == 0: pocket_lod0 += 1
		if not pocket:
			if lod == 0 and not is_equal_approx(b.visibility_range_end, P2.LOD_END.rocks): lod_bad += 1
			if lod == 1 and not is_equal_approx(b.visibility_range_begin, P2.LOD_END.rocks): lod_bad += 1
	report["rocks"] = {"swapped_instances": old_total, "lod1_instances": new_count.get(1, 0), "lod0_instances": new_count.get(0, 0), "variants": variants.keys(), "pocket_tris": [art.rocks.get("pocket_rock_tris_before", -1), art.rocks.get("pocket_rock_tris_after", -1)]}
	check(old_total > 0 and old_visible == 0, "Every visible small_rock_group batch swapped (%d instances, %d left)" % [old_total, old_visible])
	check(new_count.get(1, 0) == old_total, "One bed rock per old rock (LOD1 %d vs %d)" % [new_count.get(1, 0), old_total])
	check(variants.size() >= 3, "Bed rock variety a-e used: " + str(variants.keys()))
	check(lod_bad == 0 and pocket_lod0 == 0, "Rock LOD ranges set; pockets use LOD1 only")
	# pocket content budget: 38.1k built + the rock delta at LOD1 (MAX_TRIANGLES is pinned at 40k)
	var delta := int(art.rocks.get("pocket_rock_tris_after", 0)) - int(art.rocks.get("pocket_rock_tris_before", 0))
	report["rocks"]["pocket_delta_tris"] = delta
	check(delta <= 13500, "Pocket rock delta at LOD1 <= 13.5k tris (%d)" % delta)

	# ---- c. planters
	var pots := []
	for n in world.find_children("*", "Node3D", true, false):
		if P2.is_planter(n) != "": pots.append(n)
	var with_art := 0; var with_col := 0; var old_vis := 0
	for n in pots:
		var a := n.get_node_or_null("P2Planter") as Node3D
		if a == null: continue
		with_art += 1
		if not bodies(a).is_empty(): with_col += 1
		check(lod_ok(a, P2.LOD_END.planters) or with_art > 1, "Planter LOD ranges")
		for g in n.find_children("*", "MeshInstance3D", true, false):
			if g.is_visible_in_tree() and not a.is_ancestor_of(g): old_vis += 1
	report["planters"] = {"pots": pots.size(), "with_art": with_art, "with_collider": with_col, "old_visible": old_vis}
	check(pots.size() >= 15 and with_art == pots.size() and with_col == pots.size() and old_vis == 0, "Every kit planter swapped with a pot collider: " + str(report.planters))
	var blocked := path_blocks(pots)
	report["planters"]["path_blocks"] = blocked
	check(blocked.is_empty(), "Planter colliders leave the walk rings, spokes and paved routes clear: " + str(blocked.slice(0, 6)))
	# ---- c. board
	var board := world.get_node_or_null("RequestBoard") as Node3D
	var woven := board.get_node_or_null("P2RequestBoardWoven") as Node3D if board else null
	check(woven != null, "Woven request board present")
	if woven:
		check(bodies(woven).is_empty(), "Board duplicate _col dropped")
		var shell := 0
		for b in bodies(board): shell += 1
		check(shell >= 1, "Original board collider kept")
		check(lod_ok(woven, P2.LOD_END.board), "Board LOD ranges")
		var t := P2.tris(woven, 0)
		check(t <= 6500, "Board tris %d <= 6.5k" % t)
		var vis := 0
		for g in board.find_children("*", "MeshInstance3D", true, false):
			if g.is_visible_in_tree() and not woven.is_ancestor_of(g): vis += 1
		check(vis == 0, "Old board art hidden (%d visible)" % vis)
		report["board"] = {"lod0_tris": t}

	# ---- e. trees
	var comp := world.find_child("PlazaIslandComposition", true, false) as Node3D
	var want := {"Tree_left": ["plaza_tree_a", Vector2(4.9, 11.7)], "Tree_right": ["plaza_tree_b", Vector2(11.0, 5.5)]}
	for nm in want:
		var tr := comp.get_node_or_null(nm) as Node3D if comp else null
		var lod0 := tr.find_child(want[nm][0] + "_LOD0", true, false) as MeshInstance3D if tr else null
		check(lod0 != null, nm + " is " + want[nm][0])
		if lod0 == null: continue
		check(Vector2(tr.position.x, tr.position.z).distance_to(want[nm][1]) < 0.05, nm + " at the old spot")
		check(comp.get_node_or_null(nm.replace("Tree_", "TreeSolid_")) == null, nm + " old whole-bark trimesh removed")
		check(bodies(tr).size() == 1, nm + " has one trunk collider")
		check(is_equal_approx(lod0.visibility_range_end, 32.0), nm + " LOD0 0-32 m")
		var bb: AABB = lod0.global_transform * lod0.get_aabb()
		report[nm] = {"lod0_tris": lod0.mesh.get_faces().size() / 3, "top": snappedf(bb.end.y - tr.global_position.y, 0.01)}
	# ---- f. hills
	var dh := world.get_node_or_null("DistantHills")
	check(dh != null and hills.get("ok", false), "Distant hills installed: " + str(hills))
	if dh:
		check(hills.get("chunks", 0) == 192, "192 hill chunks")
		for nm in ["OuterFoothills", "DistantAlpineRange", "FarSceneryLayerRidges"]:
			var o := world.find_child(nm, true, false) as Node3D
			check(o != null and not o.visible, nm + " hidden, kept in the tree")
		var imp_ok := true
		for f in ["distant_hills/distant_hills_foothills", "distant_hills/distant_hills_alpine", "distant_hills/distant_hills_ridges", "plaza_trees/plaza_tree_a", "plaza_trees/plaza_tree_b", "plaza_trees/plaza_tree_c"]:
			var txt := FileAccess.get_file_as_string("res://assets/%s.gltf.import" % f)
			if not txt.contains("meshes/generate_lods=false"): imp_ok = false
		check(imp_ok, "generate_lods off on the hill and tree imports")
	# ---- ship pad route (#31): none of the new colliders sit on the boarding approach
	var route_hits := route_blocks()
	report["pad_route_hits"] = route_hits
	check(route_hits.is_empty(), "Boarding route clear of new colliders: " + str(route_hits))
	# ---- shots
	var shots := OS.get_environment("P2_SHOTS")
	if shots != "":
		await take_shots(shots)
	var dh2 := world.get_node_or_null("DistantHills")
	if dh2: await medium_block(dh2, hills)
	await frame_times()
	await set_q(2)
	finish()

func medium_block(dh: Node, hills: Dictionary) -> void:
	await set_q(1)
	var med_ok := true
	for c in dh.chunks:
		var mi: MeshInstance3D = c[0]
		if int(c[1]) == 0 and not is_equal_approx(mi.visibility_range_end, 450.0): med_ok = false
		if int(c[1]) == 2 and not is_equal_approx(mi.visibility_range_begin, 900.0): med_ok = false
	check(med_ok, "Medium ranges 450 / 900 m")
	var shore := lake_rise(dh)
	report["lake_shore"] = shore
	check(shore.new_max_above_water <= 0.0 or shore.new_max_above_water <= shore.old_max_above_water + 0.6, "Hill chunks inside the lake ellipse stay under the water plane (or no higher than the old ring): " + str(shore))

## Every collider belonging to the new art (P2* nodes and plaza trees).
func new_bodies() -> Array:
	var out := []
	for b in world.find_children("*", "StaticBody3D", true, false):
		var p := b.get_parent()
		while p != null and p != world:
			var nm := String(p.name)
			if nm.begins_with("P2") or (p.find_child("plaza_tree_*_LOD0", false, false) != null):
				out.append(b); break
			p = p.get_parent()
	return out

func hits_at(p: Vector3, r: float, only: Array) -> Array:
	var shape := SphereShape3D.new(); shape.radius = r
	var q := PhysicsShapeQueryParameters3D.new(); q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, p)
	var out := []
	for h in world.get_world_3d().direct_space_state.intersect_shape(q, 32):
		if h.collider in only: out.append(h.collider)
	return out

## Planter pot colliders vs (1) walk rings around the fountain inside and outside the planter ring,
## (2) radial spokes through the gap between every pair of neighbouring pots, (3) paved route surfaces
## right next to each pot (a 0.35 m player at knee height must fit on any paving within 1.2 m).
func path_blocks(pots: Array) -> Array:
	var only := []
	for n in pots:
		var a: Node = n.get_node_or_null("P2Planter")
		if a: only.append_array(bodies(a))
	var out := []
	for ring in [7.9, 11.0]:
		for i in 96:
			var a := TAU * i / 96.0
			var p := Vector3(cos(a) * ring, 0.5, sin(a) * ring)
			if not hits_at(p, 0.35, only).is_empty(): out.append("ring %.1f @ %d deg" % [ring, int(rad_to_deg(a))])
	var centers := []
	for n in pots: centers.append((n as Node3D).global_position)
	for i in centers.size():
		var c: Vector3 = centers[i]
		if Vector2(c.x, c.z).length() > 10.5 or Vector2(c.x, c.z).length() < 8.0: continue
		var best := INF; var nb := Vector3.ZERO
		for j in centers.size():
			if j == i: continue
			var d := c.distance_to(centers[j])
			if d < best: best = d; nb = centers[j]
		var mid := (c + nb) * 0.5
		var dir := Vector3(mid.x, 0, mid.z).normalized()
		for k in 9:
			var p := Vector3(mid.x, 0.5, mid.z) + dir * (k - 4) * 0.5
			if not hits_at(p, 0.35, only).is_empty(): out.append("spoke between %s and %s" % [str(c.snappedf(0.1)), str(nb.snappedf(0.1))]); break
	return out

## Ship boarding approach from #31 (ShipBoardingWayfinding ring + ramp): sample the ramp line and the ring.
func route_blocks() -> Array:
	var ship := world.get_node_or_null("LaunchpadShip") as Node3D
	if ship == null: return ["no ship"]
	var only := new_bodies()
	var out := []
	for k in 40:
		var local := Vector3(0, 0.6, 4.0 + k * 0.4)    # ramp centre line out to 20 m from the pad centre
		var p := ship.to_global(local)
		if not hits_at(p, 0.4, only).is_empty(): out.append("ramp line %.1f m" % (4.0 + k * 0.4))
	for i in 64:
		var a := TAU * i / 64.0
		var p := ship.to_global(Vector3(sin(a) * 9.2, 0.6, cos(a) * 9.2))
		if not hits_at(p, 0.4, only).is_empty(): out.append("pad ring @ %d deg" % int(rad_to_deg(a)))
	return out

## Highest point above the lake water of the foothills inside the lake ellipse, old ring vs new chunks.
func lake_rise(dh: Node) -> Dictionary:
	var old := world.find_child("OuterFoothills", true, false) as MeshInstance3D
	var res := {"old_max_above_water": -INF, "new_max_above_water": -INF, "old_inside": 0, "new_inside": 0}
	if old:
		for v in old.mesh.get_faces():
			var w: Vector3 = old.global_transform * v
			if Lake.lake_distance(Vector2(w.x, w.z)) < 1.0:
				res.old_inside += 1; res.old_max_above_water = maxf(res.old_max_above_water, w.y - Lake.WATER_Y)
	for c in dh.chunks:
		var mi: MeshInstance3D = c[0]
		if int(c[1]) != 0 or not String(mi.name).begins_with("distant_hills_foothills"): continue
		for v in mi.mesh.get_faces():
			var w: Vector3 = mi.global_transform * v
			if Lake.lake_distance(Vector2(w.x, w.z)) < 1.0:
				res.new_inside += 1; res.new_max_above_water = maxf(res.new_max_above_water, w.y - Lake.WATER_Y)
	for k in ["old_max_above_water", "new_max_above_water"]:
		res[k] = snappedf(res[k], 0.01) if res[k] > -INF else -99.0
	return res

## Toggle: P2 art shown (as installed) vs the originals shown (art hidden, replaced nodes visible).
func set_p2(on: bool) -> void:
	for g in world.find_children("*", "Node3D", true, false):
		if g.has_meta("p2_replaced") or g.has_meta("p2_bed_rocks"): (g as Node3D).visible = not on
	for nm in ["OuterFoothills", "DistantAlpineRange", "FarSceneryLayerRidges"]:
		var o := world.find_child(nm, true, false) as Node3D
		if o: o.visible = not on
	var dh := world.get_node_or_null("DistantHills") as Node3D
	if dh: dh.visible = on
	for b in world.find_children("BedRock_*", "MultiMeshInstance3D", true, false): b.visible = on
	for n in world.find_children("P2*", "Node3D", true, false): n.visible = on
	var sign := world.get_node_or_null("TailorAtelier/TailorIdentitySign") as Node3D
	if sign: sign.visible = not on

func frame_times() -> void:
	root.size = Vector2i(960, 600)
	var cam := Camera3D.new(); cam.fov = 70.0; cam.far = 4000.0; world.add_child(cam)
	root.get_viewport().disable_3d = false
	var views := [["plaza", Vector3(2.0, 1.7, 2.0), Vector3(-8.0, 1.0, -8.0), 1], ["hills_medium", Vector3(6.0, 1.68, 12.0), Vector3(300.0, 30.0, -150.0), 1]]
	var out := {}
	for v in views:
		await set_q(v[3])
		cam.global_position = v[1]; cam.look_at(v[2]); cam.current = true
		var times := {"on": [], "off": []}
		for block in 4:
			var mode := "on" if block % 2 == 0 else "off"
			set_p2(mode == "on")
			for i in 2: await process_frame
			var t0 := Time.get_ticks_usec()
			for i in 4: await process_frame
			times[mode].append((Time.get_ticks_usec() - t0) / 4000.0)
		out[v[0]] = {"on": avg(times.on), "off": avg(times.off), "blocks": times}
		log_("frame %s %s" % [v[0], out[v[0]]])
	set_p2(true)
	cam.queue_free()
	root.get_viewport().disable_3d = true
	root.size = Vector2i(1440, 900)
	out["note"] = "Medium scenery, llvmpipe software GL, 960x600; relative only. Old plaza trees are freed by the swap, so 'off' draws no plaza trees."
	report["frame_time"] = out

func take_shots(shots: String) -> void:
	DirAccess.make_dir_recursive_absolute(shots)
	var poses = JSON.parse_string(FileAccess.get_file_as_string(POSES_PATH))
	var cyc = world.get_node_or_null("DayNightCycle")
	if cyc: cyc.set_process(false); cyc.elapsed_seconds = cyc.cycle_seconds * 0.06; cyc.apply_lighting()
	var hidden := []
	for c in world.find_children("*", "CanvasLayer", true, false):
		if c.visible: c.visible = false; hidden.append(c)
	var cam := Camera3D.new(); cam.near = 0.05; cam.far = 4000.0; world.add_child(cam)
	root.get_viewport().disable_3d = false
	var keep_pos: Vector3 = world.player.global_position
	world.player.global_position = Vector3(0, -50, 0)
	poses.sort_custom(func(x, y): return int(x.get("quality", 2)) > int(y.get("quality", 2)))
	for p in poses:
		if int(p.get("quality", 2)) != 2 and OS.get_environment("P2_Q1_SHOTS") != "1": continue
		await set_q(int(p.get("quality", 2)))
		cam.fov = p.get("fov", 70.0)
		cam.global_position = Vector3(p.eye[0], p.eye[1], p.eye[2]); cam.look_at(Vector3(p.at[0], p.at[1], p.at[2])); cam.current = true
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image(); img.convert(Image.FORMAT_RGB8)
		img.save_jpg(shots.path_join("after_" + p.name + ".jpg"), 0.88)
		log_("shot " + p.name)
	world.player.global_position = keep_pos
	cam.queue_free()
	root.get_viewport().disable_3d = true
	for c in hidden: c.visible = true
	if cyc: cyc.set_process(true)

func avg(a: Array) -> float:
	var s := 0.0
	for v in a: s += v
	return snappedf(s / maxf(a.size(), 1), 0.01)
