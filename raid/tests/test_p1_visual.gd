extends SceneTree
## TASKS queue item 4 (P1 visual fixes), rendered acceptance through the real Play flow.
##  1. Install: stairwell finish, threshold finish and grass edge lips are present and add no colliders.
##  2. Stairwell: the four shaft faces are lined from the basement ceiling to the Hall floor, every
##     tread of both descending flights has a riser, and the stair still walks (physics treads).
##  3. Threshold: the sill covers the beige sliver; the walkable step at the door is unchanged.
##  4. Lips: edge points at Psy, Rook, the inn stair foot, the pad strip, the Hall front and the lake;
##     no lip vertex lies more than the tuck under the hard side (roads untouched); the lawn blades
##     stop at an irregular distance from the edge.
##  5. Frame time: render frames with the fixes shown vs hidden.
## env: P1_SHOTS=<dir> writes after_<pose>.jpg (JPEG q88) from the same poses as the before shots.
const MARKER := "P1_VISUAL_TESTS "
const Layout = preload("res://scripts/hall_shared_stair_layout.gd")
const Lips = preload("res://raid/scripts/grass_edge_lips.gd")
const SPOTS := {"psy": Vector2(29.0, 3.0), "rook": Vector2(26.0, 31.0), "inn_stair_foot": Vector2(4.2, 32.0), "pad_strip": Vector2(20.0, -7.0), "hall_front": Vector2(6.0, -13.0), "lake": Vector2(-20.0, 61.0)}
const POSES := [
	["hall_stairwell_down", Vector3(-3.6, 2.0, -17.5), Vector3(-6.4, -1.0, -19.5)],
	["hall_stairwell_wide", Vector3(2.5, 1.7, -15.2), Vector3(-6.4, -0.2, -19.5)],
	["hall_threshold", Vector3(-1.0, 1.7, -11.5), Vector3(-3.0, 0.0, -14.0)],
	["hall_threshold_close", Vector3(1.6, 1.15, -12.2), Vector3(0.0, 0.08, -14.1)],
	["hall_front_beds", Vector3(6.0, 1.6, -8.0), Vector3(6.0, 0.0, -13.0)],
	["psy_edges", Vector3(24.0, 1.7, 6.0), Vector3(30.0, 0.0, 2.0)],
	["rook_edges", Vector3(22.0, 1.7, 24.0), Vector3(25.0, 0.0, 31.0)],
	["inn_stair_foot", Vector3(7.5, 1.7, 27.0), Vector3(4.0, 0.2, 32.5)],
	["pad_strip", Vector3(14.0, 1.7, -2.0), Vector3(20.0, 0.0, -7.0)],
	["lake_edge_day", Vector3(-14.0, 2.5, 52.0), Vector3(-20.0, 0.4, 61.0)],
	["lake_shore_close", Vector3(-17.0, 1.6, 57.0), Vector3(-21.0, 0.3, 62.0)],
]
var checks := 0
var failures: Array = []
var report := {}
var world: Node3D

func _initialize(): call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func log_(s: String) -> void: print("P1TEST: ", s, "  t=", Time.get_ticks_msec() / 1000.0)

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
	var deadline := Time.get_ticks_msec() + 900000
	while true:
		var sc = current_scene
		if sc != null and sc.get("world_activated") == true and sc.get("world_initialized") == true: break
		if Time.get_ticks_msec() > deadline: return false
		await process_frame
	world = current_scene
	return true

func ray_y(x: float, z: float, from_y: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, from_y - 6.0, z))
	q.exclude = [world.player.get_rid()]
	var h := world.get_world_3d().direct_space_state.intersect_ray(q)
	return h.position.y if not h.is_empty() else NAN

func run() -> void:
	if DisplayServer.get_name() == "headless":
		check(false, "Needs a display (xvfb-run --rendering-driver opengl3)"); finish(); return
	if not await boot():
		check(false, "Play flow reached the settlement"); finish(); return
	log_("world up")
	root.get_viewport().disable_3d = true
	var fixes = world.get_meta("p1_visual_fixes", {})
	report["install"] = fixes
	check(not fixes.is_empty(), "P1 visual fixes installed from the settlement startup")
	var sw := world.get_node_or_null("HallStairwellFinish")
	var th := world.get_node_or_null("HallThresholdFinish")
	var lips := world.get_node_or_null("GrassEdgeLips")
	check(sw != null and th != null and lips != null, "Stairwell, threshold and lip nodes exist")
	if sw == null or th == null or lips == null: finish(); return
	for n in [sw, th, lips]:
		check(n.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s adds no colliders" % n.name)
	# ---- 2. stairwell
	var H: Rect2 = Layout.HOLE
	var lining: MeshInstance3D = sw.get_node("Shaft limestone lining")
	var faces := lining.mesh.get_faces()
	var sides := {"west": false, "east": false, "north": false, "south": false}
	for i in range(0, faces.size(), 3):
		var a := faces[i]; var b := faces[i + 1]; var c := faces[i + 2]
		var n := (b - a).cross(c - a).normalized()
		var lo: float = minf(a.y, minf(b.y, c.y)); var hi: float = maxf(a.y, maxf(b.y, c.y))
		if absf(a.x - H.position.x) < 0.012 and absf(b.x - H.position.x) < 0.012 and n.x > 0.9: sides.west = sides.west or (lo <= -0.79 or hi >= 0.239)
		if absf(a.x - H.end.x) < 0.012 and absf(b.x - H.end.x) < 0.012 and n.x < -0.9: sides.east = sides.east or (lo <= -0.79 or hi >= 0.239)
		if absf(a.z - H.position.y) < 0.012 and absf(b.z - H.position.y) < 0.012 and n.z > 0.9: sides.north = sides.north or (lo <= -0.79 or hi >= 0.239)
		if absf(a.z - H.end.y) < 0.012 and absf(b.z - H.end.y) < 0.012 and n.z < -0.9: sides.south = sides.south or (lo <= -0.79 or hi >= 0.239)
	var lb: AABB = lining.get_aabb()
	report["stairwell"] = {"meta": sw.get_meta("hall_stairwell_finish", {}), "inward_faces": sides, "lining_y": [snappedf(lb.position.y, 0.01), snappedf(lb.end.y, 0.01)]}
	for k in sides: check(sides[k], "Shaft %s face is lined, facing into the stairwell" % k)
	check(lb.position.y <= -0.79 and lb.end.y >= 0.239, "Lining spans basement ceiling (-0.80) to Hall floor (0.24)")
	var swm: Dictionary = sw.get_meta("hall_stairwell_finish", {})
	check(int(swm.get("risers", 0)) == Layout.STEPS * 2, "Every tread of both flights has a riser (%d)" % int(swm.get("risers", 0)))
	# the stair still walks: physics tread tops where the layout puts them
	var t3 := ray_y(Layout.DOWN_EAST_X, Layout.START_Z - Layout.GOING * 3.5, 1.0)
	check(absf(t3 - (Layout.GROUND_Y - Layout.RISE * 4)) < 0.02, "East flight tread 3 still at %.2f (physics %.2f)" % [Layout.GROUND_Y - Layout.RISE * 4, t3])
	# ---- 3. threshold
	var door := ray_y(0.0, -13.85, 1.0)
	var inside := ray_y(0.0, -14.5, 1.0)
	report["threshold"] = {"meta": th.get_meta("hall_threshold_finish", {}), "outside_floor_y": door, "inside_floor_y": inside}
	check(absf(door - 0.08) < 0.03 and absf(inside - 0.24) < 0.03, "Walkable door step unchanged (outside %.3f, inside %.3f)" % [door, inside])
	var sill: MeshInstance3D = th.get_node("Entrance stone sill")
	var sb: AABB = sill.get_aabb()
	check(sb.position.z <= -13.99 and sb.end.z >= -13.81 and sb.position.x <= -2.0 and sb.end.x >= 2.0 and sb.end.y > 0.08, "Sill covers the old outer threshold strip (z -13.99..-13.81) above the pavers")
	# ---- 4. lips
	var pts := Lips.load_points()
	var lm: Dictionary = lips.get_meta("grass_edge_lips", {})
	report["lips"] = lm
	var kinds := [0, 0]
	for p in pts: kinds[int(p[5])] += 1
	check(kinds[0] > 1000 and kinds[1] > 100, "Baked edges cover paths (%d) and the lake shore (%d)" % kinds)
	var spot_counts := {}
	for k in SPOTS:
		var c: Vector2 = SPOTS[k]; var cnt := 0
		for p in pts:
			if Vector2(p[0], p[2]).distance_to(c) < 5.0: cnt += 1
		spot_counts[k] = cnt
		check(cnt >= 10, "Lip edge points near %s (%d)" % [k, cnt])
	report["spot_edge_points"] = spot_counts
	check(int(lm.get("blades_hidden", 0)) > 1000, "Lawn blades removed from the lip band (%d)" % int(lm.get("blades_hidden", 0)))
	# no lip vertex more than the tuck (path 0.05, shore 0.12) onto the hard side
	var hash := {}
	for i in pts.size():
		var key := Vector2i(floori(pts[i][0]), floori(pts[i][2]))
		if not hash.has(key): hash[key] = []
		hash[key].append(i)
	var worst := 0.0; var nverts := 0
	for mi in lips.get_children():
		if not (mi is MeshInstance3D): continue
		var shore: bool = str(mi.name).ends_with("shore")
		var vs: PackedVector3Array = mi.mesh.get_faces()
		for vi in range(0, vs.size(), 7):
			var v: Vector3 = vs[vi]
			var best := INF; var dn := 0.0
			var key := Vector2i(floori(v.x), floori(v.z))
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					for j in hash.get(key + Vector2i(dx, dz), []):
						var p: Array = pts[j]
						if (int(p[5]) == 1) != shore: continue
						var d := Vector2(v.x - p[0], v.z - p[2])
						if d.length_squared() < best: best = d.length_squared(); dn = d.dot(Vector2(p[3], p[4]))
			if best < INF:
				worst = minf(worst, dn); nverts += 1
	report["lip_hard_side_worst_m"] = snappedf(worst, 0.001)
	check(nverts > 1000 and worst > -0.16, "No lip vertex lies more than the tuck onto the paving (worst %.3f m, %d sampled)" % [worst, nverts])
	# irregular lawn edge: distance from edge to the first full-height blade varies along the edge
	var gaps := []
	for n in Lips.grass_batches(world, true):
		var mm: MultiMesh = n.multimesh
		var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
		var buf: PackedFloat32Array = mm.buffer
		if buf.size() != mm.instance_count * stride: continue
		for i in range(0, mm.instance_count, 3):
			var o := i * stride
			if Vector3(buf[o + 1], buf[o + 5], buf[o + 9]).length() < 0.001: continue
			var w: Vector3 = n.global_transform * Vector3(buf[o + 3], buf[o + 7], buf[o + 11])
			var key := Vector2i(floori(w.x), floori(w.z))
			for j in hash.get(key, []):
				var p: Array = pts[j]
				if int(p[5]) != 0: continue
				var d := Vector2(w.x - p[0], w.z - p[2])
				if absf(d.dot(Vector2(-p[4], p[3]))) < 0.1 and d.dot(Vector2(p[3], p[4])) > -0.05 and d.dot(Vector2(p[3], p[4])) < 0.8:
					gaps.append(d.dot(Vector2(p[3], p[4])))
		if gaps.size() > 20000: break
	var mean := 0.0
	for g in gaps: mean += g
	mean /= maxf(gaps.size(), 1)
	var var_ := 0.0
	for g in gaps: var_ += (g - mean) * (g - mean)
	var sd := sqrt(var_ / maxf(gaps.size(), 1))
	var under := 0
	for g in gaps: if g < 0.08: under += 1
	report["lawn_edge"] = {"samples": gaps.size(), "mean_m": snappedf(mean, 0.001), "sd_m": snappedf(sd, 0.001), "blades_within_0_08": under}
	check(gaps.size() > 500 and sd > 0.08, "Lawn edge distance varies along the paths (sd %.3f m over %d blades)" % [sd, gaps.size()])
	check(under * 50 < gaps.size(), "Almost no full blades within 0.08 m of a paving edge (%d of %d)" % [under, gaps.size()])
	# ---- shots
	var shots := OS.get_environment("P1_SHOTS").strip_edges()
	if not shots.is_empty():
		DirAccess.make_dir_recursive_absolute(shots)
		var cyc = world.get_node_or_null("DayNightCycle")
		if cyc: cyc.set_process(false); cyc.elapsed_seconds = cyc.cycle_seconds * 0.06; cyc.apply_lighting()
		var hidden := []
		for c in world.find_children("*", "CanvasLayer", true, false):
			if c.visible: c.visible = false; hidden.append(c)
		var cam := Camera3D.new(); cam.near = 0.05; cam.fov = 70.0; world.add_child(cam)
		root.get_viewport().disable_3d = false
		var keep_pos: Vector3 = world.player.global_position
		world.player.global_position = Vector3(0, -50, 0)
		for p in POSES:
			cam.global_position = p[1]; cam.look_at(p[2]); cam.current = true
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_viewport().get_texture().get_image(); img.convert(Image.FORMAT_RGB8)
			img.save_jpg(shots.path_join("after_" + p[0] + ".jpg"), 0.88)
			log_("shot " + p[0])
		world.player.global_position = keep_pos
		cam.queue_free()
		for c in hidden: c.visible = true
		if cyc: cyc.set_process(true)
	# ---- 5. frame time at the plaza edge by the Hall front, fixes shown vs hidden
	root.size = Vector2i(960, 600)
	var cam2 := Camera3D.new(); cam2.fov = 70.0; world.add_child(cam2)
	cam2.global_position = Vector3(6.0, 1.7, -6.0); cam2.look_at(Vector3(4.0, 0.0, -13.0)); cam2.current = true
	root.get_viewport().disable_3d = false
	var times := {"on": [], "off": []}
	for block in 4:
		var mode := "on" if block % 2 == 0 else "off"
		for n in [sw, th, lips]: n.visible = mode == "on"
		await process_frame
		var t0 := Time.get_ticks_usec()
		for i in 4: await process_frame
		times[mode].append((Time.get_ticks_usec() - t0) / 4000.0)
		log_("frame block %d %s %.1f ms" % [block, mode, times[mode][-1]])
	for n in [sw, th, lips]: n.visible = true
	root.get_viewport().disable_3d = true
	root.size = Vector2i(1440, 900)
	report["frame_time"] = {"frame_ms_fixes_on": avg(times.on), "frame_ms_fixes_off": avg(times.off), "blocks": times, "install_ms": fixes.get("install_ms", -1), "note": "llvmpipe software GL, 960x600; relative only. Blade trim is not toggled (it removes blades)."}
	log_("frame %s" % report.frame_time)
	finish()

func avg(a: Array) -> float:
	var s := 0.0
	for v in a: s += v
	return snappedf(s / maxf(a.size(), 1), 0.01)
