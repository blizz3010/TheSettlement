extends Node
## Item 21 capture/repro driver for Ori's Town Hall stall. Loaded ONLY through a temporary
## override.cfg autoload (never committed), so the game is a plain launch of main_scene with a
## fresh XDG profile. Drives real input events through Input.parse_input_event: creates a new
## settler, opens/closes inventory, map and journal like a new player, then walks around the
## reception counter and the plot office toward the Town Hall exit.
## Every frame it records delta, player position, mouse mode and input state; a watchdog thread
## reports if the main loop stops advancing. env: STALL_OUT=<dir>, STALL_MODE=repro|after.
var out := ""
var mode := "repro"
var frame_count := 0
var last_frame_usec := 0
var watchdog: Thread
var watchdog_run := true
var trace: FileAccess
var world: Node
var state_line := ""
var max_delta := 0.0
var t0 := 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	out = OS.get_environment("STALL_OUT")
	mode = OS.get_environment("STALL_MODE") if OS.get_environment("STALL_MODE") != "" else "repro"
	DirAccess.make_dir_recursive_absolute(out)
	trace = FileAccess.open(out + "/trace.tsv", FileAccess.WRITE)
	trace.store_line("t_ms\tframe\tdelta_ms\tprocess_ms\tphysics_ms\tdraw_calls\tprims\tobjects\tx\ty\tz\tyaw\tpitch\tmouse\tenabled\tmodal\tfocused\tpaused\tseated\ton_floor\tphase")
	last_frame_usec = Time.get_ticks_usec(); t0 = Time.get_ticks_msec()
	watchdog = Thread.new(); watchdog.start(_watch)
	get_tree().create_timer(3600).timeout.connect(func(): log_("watchdog timeout"); _finish(3))
	call_deferred("_run")

var phase := "boot"
func log_(s): print("STALL: ", s, "  t=", (Time.get_ticks_msec() - t0) / 1000.0)

func _watch():
	var reported := 0
	while watchdog_run:
		OS.delay_msec(1000)
		var gap := (Time.get_ticks_usec() - last_frame_usec) / 1000000.0
		if gap > 15.0 and int(gap) / 15 != reported:
			reported = int(gap) / 15
			printerr("STALL: MAIN_LOOP_NOT_ADVANCING gap_s=%.1f frame=%d last=%s" % [gap, frame_count, state_line])

func _process(delta):
	frame_count += 1
	last_frame_usec = Time.get_ticks_usec()
	world = get_tree().current_scene
	if world == null or world.get("player") == null or not is_instance_valid(world.player): return
	if world.get("world_activated") != true: return
	var p = world.player
	max_delta = maxf(max_delta, delta)
	state_line = "%d\t%d\t%.1f\t%.1f\t%.1f\t%d\t%d\t%d\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % [Time.get_ticks_msec() - t0, frame_count, delta * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), p.global_position.x, p.global_position.y, p.global_position.z, p.rotation.y, p.pitch, Input.mouse_mode, p.enabled, world.modal_open(), world.get("cooking_window_focused"), get_tree().paused, p.seated, p.is_on_floor(), phase]
	trace.store_line(state_line)
	trace.flush()

func shot(name: String):
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	log_("shot " + name)

func frames(n: int):
	for i in n: await get_tree().process_frame

func secs(s: float):
	await get_tree().create_timer(s, true, false, true).timeout

func click(control: Control):
	var p = control.get_global_rect().get_center()
	var label = str(control.name)
	for pressed in [true, false]:
		var e = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.position = p; e.global_position = p
		Input.parse_input_event(e)
		await frames(2)
	log_("click " + label + " " + str(p))

func key(code: int, pressed: bool):
	var e = InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = pressed
	Input.parse_input_event(e)

func tap(code: int):
	key(code, true); await frames(2); key(code, false); await frames(2)

func look(dx: float, dy: float, steps := 6):
	for i in steps:
		var e = InputEventMouseMotion.new()
		e.relative = Vector2(dx / steps, dy / steps); e.position = Vector2(720, 450)
		Input.parse_input_event(e)
		await frames(1)

func wait_for(cond: Callable, seconds: float) -> bool:
	var deadline = Time.get_ticks_msec() + seconds * 1000
	while Time.get_ticks_msec() < deadline:
		if cond.call(): return true
		await get_tree().process_frame
	return false

func status(tag: String):
	var p = world.player
	var opts = world.options_panel.visible if is_instance_valid(world.options_panel) else null
	var mapv = world.settlement_hud.full.visible if is_instance_valid(world.settlement_hud) else null
	log_("%s pos=%s yaw=%.2f pitch=%.2f mouse=%d enabled=%s modal=%s options=%s map=%s inv=%s journal=%s focused=%s" % [tag, str(p.global_position), p.rotation.y, p.pitch, Input.mouse_mode, p.enabled, world.modal_open(), opts, mapv, world.inventory_panel.visible, (world.quest_journal.visible if is_instance_valid(world.quest_journal) else null), world.cooking_window_focused])

## Hold keys for a wall-clock duration (software rendering: a few FPS). Logs position.
func walk(keys: Array, seconds: float, tag: String):
	phase = tag
	for k in keys: key(k, true)
	var start = world.player.global_position
	await secs(seconds)
	for k in keys: key(k, false)
	await frames(3)
	log_("walk %s from %s to %s moved=%.2f" % [tag, str(start), str(world.player.global_position), start.distance_to(world.player.global_position)])

## Turn to face a world XZ point by injecting mouse motion (yaw only).
func face(target: Vector3, pitch_target := -0.04):
	var p = world.player
	var to = target - p.global_position
	var yaw_target = atan2(-to.x, -to.z)
	var dyaw = wrapf(yaw_target - p.rotation.y, -PI, PI)
	var dpitch = pitch_target - p.pitch
	await look(-dyaw / p.mouse_sensitivity, -dpitch / p.mouse_sensitivity, 8)

## Walk toward a point with W, steering each frame by injected mouse motion.
func goto(target: Vector3, timeout: float, tag: String) -> bool:
	phase = tag
	await face(target)
	key(KEY_W, true)
	var deadline = Time.get_ticks_msec() + timeout * 1000
	var start = world.player.global_position
	var last_progress = Time.get_ticks_msec(); var best = INF
	while Time.get_ticks_msec() < deadline:
		var p = world.player
		var to = Vector3(target.x - p.global_position.x, 0, target.z - p.global_position.z)
		if to.length() < 0.5: break
		if to.length() < best - 0.05: best = to.length(); last_progress = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_progress > 6000: log_("goto %s NO PROGRESS at %s dist=%.2f" % [tag, str(p.global_position), to.length()]); break
		var yaw_target = atan2(-to.x, -to.z)
		var dyaw = wrapf(yaw_target - p.rotation.y, -PI, PI)
		if absf(dyaw) > 0.02:
			var e = InputEventMouseMotion.new(); e.relative = Vector2(-dyaw / p.mouse_sensitivity * 0.5, 0); e.position = Vector2(720, 450)
			Input.parse_input_event(e)
		await get_tree().process_frame
	key(KEY_W, false)
	await frames(3)
	var d = Vector2(target.x - world.player.global_position.x, target.z - world.player.global_position.z).length()
	log_("goto %s from %s to %s remaining=%.2f" % [tag, str(start), str(world.player.global_position), d])
	return d < 0.6

func dump_hall():
	var f = FileAccess.open(out + "/hall_bodies.txt", FileAccess.WRITE)
	var stack: Array = [world]
	while not stack.is_empty():
		var n = stack.pop_back()
		for c in n.get_children(): stack.append(c)
		if n is CollisionObject3D and n is Node3D:
			var gp = n.global_position
			if gp.x > -16 and gp.x < 16 and gp.z > -40 and gp.z < -5:
				for s in n.get_children():
					if s is CollisionShape3D and s.shape != null:
						var desc = s.shape.get_class()
						if s.shape is BoxShape3D: desc += " size=" + str(s.shape.size)
						f.store_line("%s\t%s\tshape_at=%s\t%s\tlayer=%d disabled=%s" % [n.get_path(), n.get_class(), str(s.global_position), desc, n.collision_layer, s.disabled])
	f.close()

func _run():
	await wait_for(func(): return get_tree().current_scene != null and get_tree().current_scene.get("play_button") != null, 120)
	var title = get_tree().current_scene
	log_("main scene " + title.scene_file_path)
	await secs(3.0)
	await click(title.play_button)
	await wait_for(func(): return is_instance_valid(title.character_panel), 20)
	var panel = title.character_panel
	await secs(3.0)
	await shot("00_select")
	var state = panel.session.inspect()
	log_("select screen " + str(state.screen))
	if state.screen == "create" or not panel.cards.has("slot_1") or true:
		pass
	# Fresh profile: open the real creator for slot 1, then click its confirm button.
	if not is_instance_valid(panel.creator):
		panel.open_creator("slot_1", false, state.bytes)
	await secs(3.0)
	if is_instance_valid(panel.creator):
		await shot("00b_creator")
		await click(panel.creator.confirm)
	await secs(2.0)
	log_("creator confirmed")
	var ok = await wait_for(func():
		var s = get_tree().current_scene
		# Skip the new-settler intro the way a player would (Escape / click).
		if s != null and s.get("world_activated") != true and Engine.get_process_frames() % 120 == 0:
			key(KEY_ESCAPE, true); key(KEY_ESCAPE, false)
		return s != null and s.get("world_activated") == true and s.get("world_initialized") == true, 1500)
	world = get_tree().current_scene
	log_("world ready " + str(ok) + " " + str(world.get_script().resource_path if world else "none"))
	if not ok: await shot("01_FAILED"); _finish(4); return
	await secs(8.0)
	if not world.cooking_window_focused:
		log_("window reports unfocused under Xvfb; forcing focus flag")
		world.cooking_window_focused = true
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		log_("mouse not captured after spawn; clicking the view")
		var e = InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = true; e.position = Vector2(720, 450)
		Input.parse_input_event(e); await frames(2); e = e.duplicate(); e.pressed = false; Input.parse_input_event(e); await frames(2)
	dump_hall()
	status("spawn")
	await shot("01_spawn")
	if OS.get_environment("STALL_PROBE") == "1": await _probe(); _finish(0); return
	if OS.get_environment("STALL_CENSUS") == "1": await _census(); _finish(0); return
	if OS.get_environment("STALL_PROBE") == "2": await _probe2(); _finish(0); return
	if OS.get_environment("STALL_GRASS") == "1": _grass_dump(); _finish(0); return
	if OS.get_environment("STALL_MEASURE") == "1": await _measure(); _finish(0); return
	if OS.get_environment("STALL_SYMPTOMS") == "1": await _symptoms(); _finish(0); return
	phase = "idle_spawn"
	await secs(float(OS.get_environment("STALL_IDLE")) if OS.get_environment("STALL_IDLE") != "" else 20.0)
	status("after idle")
	if OS.get_environment("STALL_SKIP_OVERLAYS") == "1": await _walk_route(); return
	# --- overlays like a new player ---
	phase = "overlays"
	await tap(KEY_I); await secs(2.0); status("inventory open"); await shot("02_inventory")
	await tap(KEY_I); await secs(1.5); status("inventory closed")
	await tap(KEY_M); await secs(3.0); status("map open"); await shot("03_map")
	await tap(KEY_ESCAPE); await secs(2.0); status("map after Escape"); await shot("03b_map_after_escape")
	if world.options_panel.visible:
		await tap(KEY_ESCAPE); await secs(1.5); status("options after second Escape")
	if world.settlement_hud.full.visible:
		await tap(KEY_M); await secs(1.5); status("map after M")
	await tap(KEY_L); await secs(2.0); status("journal open"); await shot("04_journal")
	await tap(KEY_ESCAPE); await secs(1.5); status("journal after Escape")
	await tap(KEY_I); await secs(1.5); await tap(KEY_I); await secs(1.5); status("inventory reopen/close")
	await _walk_route()

func _walk_route():
	# --- walk the hall ---
	await look(0, 0)
	var route: Array = JSON.parse_string(OS.get_environment("STALL_ROUTE")) if OS.get_environment("STALL_ROUTE") != "" else []
	if route.is_empty():
		route = [[0, -19.5, "toward counter"], [-3.5, -19.5, "counter west side"], [-3.5, -24.5, "behind counter west"], [3.5, -24.5, "behind counter east"], [5.0, -21.0, "plot office approach"], [3.5, -19.0, "counter east side"], [0, -14.0, "toward exit"], [0, -9.0, "exit"], [0, -5.0, "outside"]]
	var i := 0
	for r in route:
		i += 1
		await goto(Vector3(r[0], 0, r[1]), 45.0, str(r[2]))
		status("at " + str(r[2]))
		if i % 2 == 0: await shot("05_walk_%02d" % i)
		# A new player pokes at things: try interact and an overlay on the way.
		if i == 5:
			await tap(KEY_E); await secs(2.0); status("after E near plot office"); await shot("05_after_E")
			await tap(KEY_ESCAPE); await secs(1.5); status("after Escape near plot office")
			if world.options_panel.visible: await tap(KEY_ESCAPE); await secs(1.0)
	await shot("06_end")
	status("end")
	log_("max_delta_ms=%.1f frames=%d" % [max_delta * 1000.0, frame_count])
	_finish(0)

func _frames_report(tag: String, n: int):
	var vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for i in n:
		var t = Time.get_ticks_msec()
		await get_tree().process_frame
		log_("PROBE %s wall_ms=%d process_ms=%.0f physics_ms=%.0f prims=%d draws=%d rs_cpu=%.1f rs_gpu=%.1f" % [tag, Time.get_ticks_msec() - t, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp)])

func _probe():
	var vps: Array = []
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n = stack.pop_back()
		for c in n.get_children(true): stack.append(c)
		if n is SubViewport:
			vps.append(n)
			log_("SUBVIEWPORT %s size=%s update=%d own_world=%s disable3d=%s visible_parent=%s" % [n.get_path(), str(n.size), n.render_target_update_mode, n.own_world_3d, n.disable_3d, str(n.get_parent().get("visible"))])
	await _frames_report("baseline", 4)
	for v in vps: v.set_meta("old_mode", v.render_target_update_mode); v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	await _frames_report("subviewports_disabled", 4)
	for v in vps: v.render_target_update_mode = v.get_meta("old_mode")
	get_viewport().disable_3d = true
	await _frames_report("root_3d_disabled", 4)
	get_viewport().disable_3d = false
	var rs = get_viewport().msaa_3d
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	await _frames_report("msaa_off", 4)
	get_viewport().msaa_3d = rs
	var sun: Array = []
	for l in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		if l.shadow_enabled: sun.append(l); l.shadow_enabled = false
	await _frames_report("shadows_off(%d)" % sun.size(), 4)
	for l in sun: l.shadow_enabled = true
	await _frames_report("restored", 3)

func _tri_count(mesh: Mesh) -> int:
	if mesh == null: return 0
	var t := 0
	for si in mesh.get_surface_count():
		var arr = mesh.surface_get_arrays(si)
		var idx = arr[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null and idx.size() > 0 else arr[Mesh.ARRAY_VERTEX].size()) / 3
	return t

func _census():
	var f = FileAccess.open(out + "/census.tsv", FileAccess.WRITE)
	f.store_line("top\tpath\tkind\ttris_each\tinstances\ttotal\tshadow\tvis_end\tdist_to_player")
	var p = world.player.global_position
	var cache := {}
	for n in world.find_children("*", "GeometryInstance3D", true, false):
		if not n.is_visible_in_tree(): continue
		var top = str(world.get_path_to(n)).split("/")[0]
		var tris := 0; var inst := 1; var kind := n.get_class()
		if n is MultiMeshInstance3D and n.multimesh != null:
			var mm = n.multimesh
			if not cache.has(mm.mesh): cache[mm.mesh] = _tri_count(mm.mesh)
			tris = cache[mm.mesh]; inst = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		elif n is MeshInstance3D:
			if not cache.has(n.mesh): cache[n.mesh] = _tri_count(n.mesh)
			tris = cache[n.mesh]
		else: continue
		f.store_line("%s\t%s\t%s\t%d\t%d\t%d\t%d\t%.1f\t%.1f" % [top, world.get_path_to(n), kind, tris, inst, tris * inst, n.cast_shadow, n.visibility_range_end, n.global_position.distance_to(p)])
	f.close()
	log_("census written")
	# Dynamic: hide each top-level child alone, measure primitives drawn (MSAA off for speed).
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	await _frames_report("census_base", 2)
	var base = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var g = FileAccess.open(out + "/census_dynamic.tsv", FileAccess.WRITE)
	var kids: Array = []
	for c in world.get_children():
		if c is Node3D and c.visible and c != world.player: kids.append(c)
	# batches of 8, then drill into batches that matter
	var i := 0
	while i < kids.size():
		var batch = kids.slice(i, i + 8)
		for c in batch: c.visible = false
		await get_tree().process_frame; await get_tree().process_frame
		var prims = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		for c in batch: c.visible = true
		var names = []
		for c in batch: names.append(str(c.name))
		g.store_line("%d\t%s" % [base - prims, ",".join(names)]); g.flush()
		log_("batch drop=%d %s" % [base - prims, ",".join(names)])
		if base - prims > 300000:
			for c in batch:
				c.visible = false
				await get_tree().process_frame; await get_tree().process_frame
				var pc = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
				c.visible = true
				g.store_line("  %d\t%s" % [base - pc, c.name]); g.flush()
				log_("  child drop=%d %s" % [base - pc, c.name])
		i += 8
	g.close()

func _probe2():
	var S = load("res://scripts/game_settings.gd").new()
	var vp = get_viewport()
	await _frames_report("p2_baseline", 3)
	S.apply_grass_quality(vp, 1); await _frames_report("p2_grass_medium", 3)
	S.apply_grass_quality(vp, 0); await _frames_report("p2_grass_low", 3)
	vp.msaa_3d = Viewport.MSAA_DISABLED; await _frames_report("p2_low_msaa_off", 3)
	S.apply_scene_shadows(vp, false); await _frames_report("p2_low_msaa_off_shadows_off", 3)
	vp.scaling_3d_scale = 0.5; await _frames_report("p2_plus_scale_half", 3)
	vp.scaling_3d_scale = 1.0; S.apply_scene_shadows(vp, true); vp.msaa_3d = Viewport.MSAA_4X; S.apply_grass_quality(vp, 2)
	await _frames_report("p2_restored", 3)

func _grass_dump():
	var f = FileAccess.open(out + "/grass.tsv", FileAccess.WRITE)
	f.store_line("path\tparent_script\tnear\tseam\taabb_pos\taabb_size\tinst\tvisible\ttris\tvb\tve\tfade\tshader\tgroups")
	var cache := {}
	for n in world.find_children("*", "MultiMeshInstance3D", true, false):
		if n.multimesh == null: continue
		var mm = n.multimesh
		if not cache.has(mm.mesh): cache[mm.mesh] = _tri_count(mm.mesh)
		var total = cache[mm.mesh] * (mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count)
		if total < 20000: continue
		var ab: AABB = n.global_transform * n.get_aabb()
		var mat = n.material_override
		var sh = mat.shader.resource_path if mat is ShaderMaterial and mat.shader else str(mat)
		var ps = n.get_parent().get_script().resource_path if n.get_parent().get_script() else ""
		f.store_line("%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%.1f\t%.1f\t%d\t%s\t%s" % [world.get_path_to(n), ps, n.get_meta("near_lod", "-"), n.get_meta("edge_seam", "-"), str(ab.position), str(ab.size), mm.instance_count, mm.visible_instance_count, cache[mm.mesh], n.visibility_range_begin, n.visibility_range_end, n.visibility_range_fade_mode, sh, str(n.get_groups())])
	f.close()
	log_("grass dump written")

func _measure_modes(tag: String):
	var gc = world.get_node_or_null("GrassViewCulling")
	for m in ["original", "split", "cull"]:
		gc.set_mode(m)
		await frames(1)
		await _frames_report("%s_%s" % [tag, m], 3)
		await shot("measure_%s_%s" % [tag, m])
	log_("MEASURE %s stats=%s" % [tag, str(gc.stats)])
	_dump_subs(tag, gc)
	if OS.get_environment("STALL_OCC") == "1":
		var occ = world.get_node_or_null("SettlementOccluders")
		if occ == null:
			occ = load("res://raid/scripts/settlement_occluders.gd").install(world)
			log_("MEASURE occluders=%d tris=%d" % [occ.occluder_count, occ.occluder_tris])
		get_viewport().use_occlusion_culling = true
		for m in ["original", "cull"]:
			gc.set_mode(m)
			await frames(3)
			await _frames_report("%s_%s_occ" % [tag, m], 3)
			await shot("measure_%s_%s_occ" % [tag, m])
		get_viewport().use_occlusion_culling = false

func _aabb_in_frustum(planes: Array, b: AABB) -> bool:
	for pl in planes:
		var inside := false
		for i in 8:
			if not pl.is_point_over(b.get_endpoint(i)): inside = true; break
		if not inside: return false
	return true

func _dump_subs(tag: String, gc):
	var cam = get_viewport().get_camera_3d()
	var planes = cam.get_frustum()
	var f = FileAccess.open(out + "/subs_%s.tsv" % tag, FileAccess.WRITE)
	f.store_line("name\tcx\tcy\tcz\tsx\tsy\tsz\tvis_inst\ttris\txz\tfrustum\tnear")
	var tot := 0; var tot_f := 0
	for batch in gc.batches:
		var tris = gc._tri_count(batch.original.multimesh.mesh)
		for s in batch.subs:
			if not s.mmi.visible: continue
			var mm = s.mmi.multimesh
			var n = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
			var b: AABB = s.aabb
			var c = b.get_center()
			var d = gc.xz_distance(cam.global_position, b)
			var inf = _aabb_in_frustum(planes, b) and (batch.original.visibility_range_end <= 0.0 or cam.global_position.distance_to(c) < batch.original.visibility_range_end)
			tot += n * tris
			if inf: tot_f += n * tris
			f.store_line("%s\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%d\t%d\t%.1f\t%s\t%s" % [s.mmi.name, c.x, c.y, c.z, b.size.x, b.size.y, b.size.z, n, tris, d, inf, s.near])
	f.close()
	log_("MEASURE %s subs visible_tris=%d in_frustum_tris=%d" % [tag, tot, tot_f])

func _place(pos: Vector3, yaw: float):
	var p = world.player
	p.global_position = pos; p.rotation = Vector3(0, yaw, 0); p.velocity = Vector3.ZERO
	p.pitch = -0.04; p.camera.rotation.x = p.pitch; p.reset_physics_interpolation()
	await frames(3)

func _measure():
	var gc = world.get_node_or_null("GrassViewCulling")
	if gc == null: log_("MEASURE no culling node"); return
	var ok = await wait_for(func(): return gc.split_done, 900)
	log_("MEASURE split_done=%s stats=%s split_ms=%d" % [ok, str(gc.stats), gc.split_usec / 1000])
	get_viewport().msaa_3d = Viewport.MSAA_4X
	await _measure_modes("spawn")
	await _place(Vector3(0, 0.27, -24.5), 0.0)
	await _measure_modes("hall_rear")
	await _place(Vector3(0, 0.2, -8.0), PI)
	await _measure_modes("plaza")

## Reproduces Ori's observations at the measured frame rate, without touching game state
## directly: real InputEvents only, timings are wall clock.
func _symptoms():
	var p = world.player
	var label = OS.get_environment("STALL_LABEL")
	await _frames_report(label + "_frame", 2)
	# 1. hold W for 5 s wall clock
	var start = p.global_position
	key(KEY_W, true); await secs(5.0); key(KEY_W, false); await frames(2)
	log_("SYMPTOM %s hold_W_5s moved=%.2f m frames_during=%s" % [label, start.distance_to(p.global_position), "see trace"])
	# 2. a quick tap (press+release before the next frame), like a key click
	start = p.global_position
	key(KEY_W, true); key(KEY_W, false); await frames(3)
	log_("SYMPTOM %s tap_W moved=%.3f m" % [label, start.distance_to(p.global_position)])
	# 3. a player nudging the mouse down while waiting for the view to react:
	#    12 small moves of 60 px over ~3 s wall clock
	var pitch0 = p.pitch
	var t0m = Time.get_ticks_msec()
	for i in 12:
		var e = InputEventMouseMotion.new(); e.relative = Vector2(0, 60); e.position = Vector2(720, 450)
		Input.parse_input_event(e)
		OS.delay_msec(250)
	await frames(1)
	log_("SYMPTOM %s mouse_down_12x60px pitch %.2f -> %.2f (clamp -1.25) frames_elapsed_wall_ms=%d" % [label, pitch0, p.pitch, Time.get_ticks_msec() - t0m])
	await shot("symptom_%s_after_mouse" % label)
	await look(0, (p.pitch + 0.04) / p.mouse_sensitivity, 1)
	# 4. Escape -> options: wall clock until visible on a drawn frame
	var t_esc = Time.get_ticks_msec()
	key(KEY_ESCAPE, true); key(KEY_ESCAPE, false)
	await wait_for(func(): return world.options_panel.visible, 120)
	await RenderingServer.frame_post_draw
	log_("SYMPTOM %s escape_to_options_drawn_ms=%d" % [label, Time.get_ticks_msec() - t_esc])
	key(KEY_ESCAPE, true); key(KEY_ESCAPE, false)
	await wait_for(func(): return not world.options_panel.visible, 120)
	await RenderingServer.frame_post_draw
	# 5. window close button -> quit prompt (needs a second click on Save and Quit)
	var t_close = Time.get_ticks_msec()
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	await wait_for(func(): return world.options_panel.visible and world.options_panel.quit_pending, 120)
	await RenderingServer.frame_post_draw
	log_("SYMPTOM %s close_to_quit_prompt_drawn_ms=%d quit_pending=%s (game keeps running until Save and Quit)" % [label, Time.get_ticks_msec() - t_close, world.options_panel.quit_pending])
	await shot("symptom_%s_quit_prompt" % label)

func _finish(code: int):
	watchdog_run = false
	if trace: trace.flush()
	get_tree().quit(code)

func _exit_tree():
	watchdog_run = false
	if watchdog and watchdog.is_started(): watchdog.wait_to_finish()
