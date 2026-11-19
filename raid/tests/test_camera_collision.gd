extends SceneTree
## TASKS queue item 3 (visualpass 109/110/209/231/232, playtest2 ship walkway): rendered acceptance
## through the real Play flow (title -> Play -> settler -> Enter, staged startup).
##  1. Install: CameraCollision on the player (camera-only mirror of visible meshes) and SolidProps.
##  2. Sweep: every reachable 0.75 m cell (flood fill from the hall, plaza, ship, inn, traders) x
##     8 headings; the shipped boom must never put the camera within 0.10 m of geometry (a sphere
##     that encloses the near plane) nor inside / under a mesh. The pinned single-ray placement is
##     audited on the same samples for comparison.
##  3. Reported spots with the real camera (player.third_person, its own frames): ship walkway
##     lamp and rail, inn lawn tree (the "green plane", 109/110), inn approach railing (231/232),
##     inn front, trees east of Rook (209), ship hull.
##  4. Solid trunks: the real controller cannot walk into a tree that had no collision.
##  5. Frame time: boom solve cost and render frames with the probe on/off.
## env: CAM_SHOTS=<dir> JPEG q88 review shots; CAM_BASELINE=1 audits the pinned camera only (main).
const MARKER := "CAMERA_COLLISION_TESTS "
const Audit = preload("res://raid/tests/camera_clip_audit.gd")
const CC = preload("res://raid/scripts/camera_collision.gd")
const SEEDS := [Vector3(0, 0.24, -17.2), Vector3(0, 0.2, -6), Vector3(22, 1.28, -11.2), Vector3(2.6, 0.3, 30), Vector3(2.6, 2.0, 38), Vector3(-8, 3.4, 44), Vector3(6, 0.1, 19), Vector3(-20, 0.2, 0), Vector3(20, 0.2, 5), Vector3(-30, 0.2, 10)]
## name, foot (x, z), heading index (yaw = i * TAU / 8), visual-pass reference
const SPOTS := [
	["ship_walkway_lamp", Vector2(22.5, 0.8), 1, "playtest2 149/156/157"],
	["ship_walkway_rail", Vector2(15.8, -9.7), 3, "playtest2 149/156/157"],
	["inn_lawn_tree_green_plane", Vector2(-17.2, 31.5), 2, "visualpass 109/110"],
	["inn_approach_railing", Vector2(2.3, 34.5), 1, "visualpass 231/232"],
	["inn_front_foundation", Vector2(-1.5, 45.0), 0, "visualpass 110 (foundation)"],
	["trees_east_of_rook", Vector2(18.8, 31.5), 1, "visualpass 209"],
	["ship_hull", Vector2(21.0, -11.2), 3, "ship pad"],
]
var checks := 0
var failures: Array = []
var report := {}
var world: Node
var shots := ""
var baseline := false
var cc: Node
var au

func _initialize(): call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func log_(s: String) -> void: print("CAMTEST: ", s, "  t=", Time.get_ticks_msec() / 1000.0)

func finish() -> void:
	report["checks"] = checks
	report["failures"] = failures
	report["baseline"] = baseline
	print(MARKER, JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func shot(name: String) -> void:
	if shots.is_empty(): return
	root.get_viewport().disable_3d = false
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(shots.path_join(name + ".jpg"), 0.88)
	root.get_viewport().disable_3d = true

func floor_y(x: float, z: float, near_y: float) -> float:
	var best := near_y
	var bestd := INF
	for y in au.floors_at(x, z):
		if absf(y - near_y) < bestd: bestd = absf(y - near_y); best = y
	return best

func verdict(c: Vector3) -> String:
	var k: String = au.touches(c)
	if k.is_empty(): k = au.inside(c)
	return k

func run() -> void:
	shots = OS.get_environment("CAM_SHOTS").strip_edges()
	baseline = OS.get_environment("CAM_BASELINE") == "1"
	if not shots.is_empty(): DirAccess.make_dir_recursive_absolute(shots)
	if DisplayServer.get_name() == "headless":
		check(false, "Needs a display (xvfb-run --rendering-driver opengl3)")
		finish(); return
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	var Session = load("res://scripts/character_profiles/title_session.gd")
	var Rules = load("res://scripts/character_profiles/experimental_rules.gd")
	var session = Session.new(); session.rules = Rules.data()
	var state = session.inspect()
	if state.screen == "create":
		session.create_character("slot_1", {"name": "Camera", "cheek": 0.0, "hair": "hair_short02_v1", "brows": "brow_009_v1", "eyes": "eye_brown_v1", "hair_tint": "natural"}, {"str": 7, "int": 7, "dex": 7}, [], state.bytes, false)
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
		if Time.get_ticks_msec() > deadline:
			check(false, "Play flow reached the settlement"); finish(); return
		await process_frame
	world = current_scene
	var p = world.player
	log_("world up")
	root.get_viewport().disable_3d = true
	# ---- 1. install
	cc = p.get_node_or_null("CameraCollision")
	var solids = world.get_node_or_null("SolidProps")
	if baseline:
		check(cc == null, "Baseline has no camera probe")
		cc = CC.attach(p, world)   # audit mirror only; the pinned camera stays in charge
		cc.enabled = false
	else:
		check(cc != null, "CameraCollision is attached to the settlement player")
		check(solids != null, "SolidProps installed")
		if solids != null:
			report["solid_props"] = solids.get_meta("solid_props", {})
			var sp: Dictionary = report.solid_props
			check(int(sp.get("trees", 0)) + int(sp.get("trunks", 0)) >= 10, "At least 10 tree trunks made solid")
	var t_build := Time.get_ticks_msec()
	if cc != null: cc.build_all()
	for i in 4: await physics_frame
	report["mirror"] = {"bodies": cc.entries.size(), "tris": cc.mirrored_tris, "build_ms": snappedf(cc.build_ms, 0.1), "finish_ms": Time.get_ticks_msec() - t_build}
	log_("mirror %s" % report.mirror)
	au = Audit.new(world, cc)
	# ---- 2. sweep
	var feet: Array = au.flood(SEEDS, -70, 70, -70, 80)
	report["reachable_cells"] = feet.size()
	check(feet.size() > 15000, "Flood fill reaches the settlement (%d cells)" % feet.size())
	var pinned := {}
	var probed := {}
	var n := 0
	var bad_samples := []
	var eye_blocked := 0
	for foot in feet:
		for yi in 8:
			var pivot: Vector3 = foot + Vector3(0, 1.70, 0)
			var desired: Vector3 = pivot + Basis(Vector3.UP, yi * TAU / 8.0) * CC.BOOM
			var ka := verdict(au.pinned_camera(pivot, desired))
			if not ka.is_empty(): pinned[ka] = pinned.get(ka, 0) + 1
			if not baseline:
				var kb := verdict(au.probe_camera(pivot, desired))
				if not kb.is_empty() and not au.touches(pivot).is_empty() and not au.touches(pivot - Vector3(0, 0.6, 0)).is_empty():
					eye_blocked += 1   # the eye and the body axis are in geometry; first person clips too
				elif not kb.is_empty():
					probed[kb] = probed.get(kb, 0) + 1
					if bad_samples.size() < 40:
						var sol: Array = cc.solve_point(pivot, desired)
						bad_samples.append([snappedf(foot.x, 0.01), snappedf(foot.y, 0.01), snappedf(foot.z, 0.01), yi, kb, snappedf(pivot.y - sol[0].y, 0.01), snappedf(sol[1], 0.01)])
			n += 1
		if n % 8000 == 0: await physics_frame
	var cp := 0
	for v in pinned.values(): cp += v
	var cb := 0
	for v in probed.values(): cb += v
	report["sweep"] = {"cameras": n, "pinned_clips": cp, "probe_clips": cb, "probe_eye_blocked": eye_blocked, "pinned_top": top(pinned, 12), "probe_top": top(probed, 12), "probe_samples": bad_samples}
	log_("sweep cams=%d pinned=%d probe=%d eye_blocked=%d top=%s samples=%s" % [n, cp, cb, eye_blocked, report.sweep.probe_top, bad_samples.slice(0, 20)])
	check(cp > 0, "Audit sees the pinned camera clipping (sanity)")
	if not baseline: check(eye_blocked * 1000 <= n, "Eye-in-geometry cameras stay under 0.1%% (%d)" % eye_blocked)
	if not baseline: check(cb == 0, "Shipped camera never within 0.10 m of, inside or under geometry at %d sampled cameras (pinned: %d)" % [n, cp])
	if OS.get_environment("CAM_SWEEP_ONLY") == "1": finish(); return
	# ---- 3. reported spots with the real camera
	if not p.third_person: p.toggle_view()
	var spots := {}
	for s in SPOTS:
		var foot := Vector3(s[1].x, 0, s[1].y)
		foot.y = floor_y(foot.x, foot.z, 1.0)
		p.global_position = foot + Vector3(0, 0.02, 0)
		p.velocity = Vector3.ZERO
		p.rotation.y = s[2] * TAU / 8.0
		p.pitch = -0.12
		p.camera.rotation.x = p.pitch
		for i in 20: await physics_frame
		for i in 3: await process_frame
		var cam: Vector3 = p.camera.global_position
		var pivot: Vector3 = p.global_position + Vector3(0, p.camera_eye_height + 0.02, 0)
		var pk := verdict(au.pinned_camera(pivot, pivot + p.basis * CC.BOOM))
		var k := verdict(cam)
		spots[s[0]] = {"ref": s[3], "foot": [snappedf(foot.x, 0.01), snappedf(foot.y, 0.01), snappedf(foot.z, 0.01)], "camera": [snappedf(cam.x, 0.01), snappedf(cam.y, 0.01), snappedf(cam.z, 0.01)], "boom_m": snappedf(cam.distance_to(pivot), 0.01), "pinned_clip": pk, "shown_clip": k}
		log_("spot %s %s" % [s[0], spots[s[0]]])
		if baseline: check(not pk.is_empty(), "Pinned camera clips at %s (spot reproduces)" % s[0])
		if not baseline: check(k.is_empty(), "Shown camera is clear at %s (%s)" % [s[0], k])
		await shot(("before_" if baseline else "after_") + s[0])
	report["spots"] = spots
	# ---- 4. solid trunks
	if not baseline and solids != null:
		var walked := []
		for col in solids.get_children():
			if walked.size() >= 3: break
			if not (col is CollisionShape3D) or not (col.shape is CylinderShape3D) or not str(col.name).to_lower().contains("tree"): continue
			var c: Vector3 = col.global_position
			var r: float = col.shape.radius
			var start := Vector3.INF
			for a in 8:
				var dir := Vector3(cos(a * TAU / 8.0), 0, sin(a * TAU / 8.0))
				var xz: Vector3 = c + dir * (r + 2.2)
				var fl: Array = au.floors_at(xz.x, xz.z)
				for fy in fl:
					if absf(fy - (c.y - col.shape.height * 0.5)) < 0.6: start = Vector3(xz.x, fy, xz.z); break
				if start != Vector3.INF: break
			if start == Vector3.INF: continue
			p.global_position = start + Vector3(0, 0.02, 0); p.velocity = Vector3.ZERO
			for i in 10: await physics_frame
			Input.action_press("forward")
			for f in 150:
				if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				var d := Vector2(c.x - p.global_position.x, c.z - p.global_position.z)
				p.rotation.y = atan2(-d.x, -d.y)
				await physics_frame
			Input.action_release("forward")
			for i in 5: await physics_frame
			var dist := Vector2(c.x - p.global_position.x, c.z - p.global_position.z).length()
			walked.append({"tree": str(col.name), "radius": snappedf(r, 0.01), "stopped_at_m": snappedf(dist, 0.01)})
			check(dist >= r + 0.25, "Player is stopped outside the trunk of %s (%.2f m, radius %.2f)" % [col.name, dist, r])
		report["trunk_walks"] = walked
		check(walked.size() >= 2, "Walked into at least two solid trunks")
	# ---- 5. frame time at the walkway lamp spot, 3D on
	var s0: Array = SPOTS[0]
	var f0 := Vector3(s0[1].x, 0, s0[1].y)
	p.global_position = Vector3(f0.x, floor_y(f0.x, f0.z, 1.0) + 0.02, f0.z)
	p.rotation.y = s0[2] * TAU / 8.0
	# llvmpipe renders this scene at seconds per frame, so the timed frames are few and smaller.
	root.size = Vector2i(960, 600)
	root.get_viewport().disable_3d = false
	var times := {"on": [], "off": []}
	for block in 4:
		var mode := "on" if block % 2 == 0 else "off"
		if not baseline: cc.enabled = mode == "on"
		await process_frame
		var t0 := Time.get_ticks_usec()
		for i in 4: await process_frame
		times[mode].append((Time.get_ticks_usec() - t0) / 4000.0)
		log_("frame block %d %s %.1f ms" % [block, mode, times[mode][-1]])
	root.size = Vector2i(1440, 900)
	root.get_viewport().disable_3d = true
	if not baseline: cc.enabled = true
	var solves_before: int = cc.solves
	var us_before: int = cc.total_solve_us
	for i in 120: await physics_frame
	var solves: int = cc.solves - solves_before
	report["frame_time"] = {"frame_ms_probe_on": avg(times.on), "frame_ms_probe_off": avg(times.off), "solve_us_avg": snappedf(float(cc.total_solve_us - us_before) / maxf(solves, 1), 0.1), "solve_us_max": cc.max_solve_us, "solves": solves, "mirror_build_ms": snappedf(cc.build_ms, 0.1), "note": "llvmpipe software GL on the review box; relative only"}
	log_("frame %s" % report.frame_time)
	finish()

func avg(a: Array) -> float:
	var s := 0.0
	for v in a: s += v
	return snappedf(s / maxf(a.size(), 1), 0.01)

func top(d: Dictionary, k: int) -> Array:
	var rows: Array = []
	for key in d: rows.append([d[key], key])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	return rows.slice(0, k)
