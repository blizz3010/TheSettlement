extends SceneTree
## TASKS queue item 2 (Ori playtest2 bundle), rendered acceptance through the real Play flow
## (title -> Play -> settler -> Enter -> threaded load + staged startup), with a fresh profile:
##  (a) jump tuning is attached to the settlement player; an in-world standing jump on the plaza
##      reports the peak height (numbers for the obstacle classes are in test_jump_tuning.gd).
##  (b) the HUD title "S E T T L E M E N T / FIRST PLAYABLE" fades on leaving the Town Hall and
##      stays while still inside before the timer.
##  (c) first-run guide: welcome, NEXT 1/3 trader -> 2/3 ship -> 3/3 raid select -> done, saved to
##      the per-character sidecar; the Town Hall recovery toast names the ship.
##  (d) a single real Interact key event opens Psy and Dan from where the counter stops the
##      player (and from a step farther back), where the pinned strip had no service in range.
## Needs a display (xvfb-run, --rendering-driver opengl3): the Play-flow world does not load
## headless and boarding needs a captured mouse. The runner launches it that way.
## env: BUNDLE_SHOTS=<dir> writes JPEG q88 review shots; BUNDLE_BASELINE=1 records the same flow
## without the item 2 expectations (the "before" run on main 97efe00).
const MARKER := "PLAYTEST_BUNDLE_TESTS "
const SHIP_ZONE := Vector3(22.0, 1.28, -11.2)
const PLAZA := Vector2(0.0, -6.0)
var checks := 0
var failures: Array = []
var report := {}
var world: Node
var shots := ""
var expect_fix := true

func _initialize(): call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func log_(s: String) -> void: print("BUNDLE: ", s, "  t=", Time.get_ticks_msec() / 1000.0)

func finish() -> void:
	report["checks"] = checks
	report["failures"] = failures
	report["baseline"] = not expect_fix
	print(MARKER, JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func shot(name: String) -> void:
	if shots.is_empty(): return
	root.get_viewport().disable_3d = false
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(shots.path_join(name + ".jpg"), 0.88)
	root.get_viewport().disable_3d = true

func capture_mouse() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func face(target: Vector3) -> void:
	var p = world.player
	var d := Vector2(target.x - p.global_position.x, target.z - p.global_position.z)
	if d.length() > 0.01: p.rotation.y = atan2(-d.x, -d.y)

func ground_y(x: float, z: float, from_y := 6.0) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, -3.0, z))
	q.exclude = [world.player.get_rid()]
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else 0.0

func place(pos: Vector3, look := Vector3.INF, from_y := 6.0) -> void:
	var p = world.player
	p.enabled = true
	p.global_position = Vector3(pos.x, ground_y(pos.x, pos.z, from_y) + 0.05, pos.z)
	p.velocity = Vector3.ZERO
	if look != Vector3.INF: face(look)
	for i in 20: await physics_frame

func key_event(code: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	return ev

func interact_code() -> Key:
	for e in InputMap.action_get_events("interact"):
		if e is InputEventKey: return e.physical_keycode if e.physical_keycode != 0 else e.keycode
	return KEY_E

## One real key press + release, then a few frames for dispatch and the controller's _process.
func press_interact_once() -> void:
	Input.parse_input_event(key_event(interact_code(), true))
	await process_frame
	Input.parse_input_event(key_event(interact_code(), false))
	for i in 4: await process_frame

func prompt_for(id: String) -> bool:
	return world.prompt_panel.visible and str(world.prompt.text).contains(id.capitalize())

## The pinned controller's own strip test (scripts/trader_preview_controller.gd ACCESS + 2.8 m).
func pinned_reach(id: String) -> bool:
	var tp = world.trader_previews
	var spec: Dictionary = tp.ACCESS[id]
	var stand: Node3D = world.get_node(spec.path)
	var pos: Vector3 = world.player.global_position
	var p: Vector3 = stand.to_local(pos)
	if p.x < spec.x.x or p.x > spec.x.y or p.z < spec.z.x or p.z > spec.z.y or absf(p.y) > .6: return false
	var eye := pos + Vector3(0, 1.5, 0)
	var target: Vector3 = stand.to_global(spec.target)
	if eye.distance_to(target) > 2.8: return false
	var q := PhysicsRayQueryParameters3D.create(eye, target); q.exclude = [world.player.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## Real controller walks straight at the counter (stand-local x) until the collision stops it.
func walk_to_counter(id: String, x: float) -> Vector3:
	var stand: Node3D = world.get_node(world.trader_previews.ACCESS[id].path)
	await place(stand.to_global(Vector3(x, 0, 7.0)), stand.to_global(Vector3(x, 0, 0.5)))
	var p = world.player
	var goal: Vector3 = stand.to_global(Vector3(x, 0, 0.5))
	var last := Vector3.INF
	var still := 0
	Input.action_press("forward")
	for f in 600:
		capture_mouse()
		face(goal)
		await physics_frame
		if last.is_finite() and last.distance_to(p.global_position) < 0.002: still += 1
		else: still = 0
		last = p.global_position
		if still > 20: break
	Input.action_release("forward")
	for i in 10: await physics_frame
	return stand.to_local(p.global_position)

func trader_case(id: String, x: float, back := 0.0, shot_name := "") -> Dictionary:
	var tp = world.trader_previews
	var local: Vector3 = await walk_to_counter(id, x)
	if back > 0.0:
		var stand: Node3D = world.get_node(tp.ACCESS[id].path)
		await place(stand.to_global(Vector3(x, 0, local.z + back)), stand.to_global(Vector3(x, 0, 0.5)))
		local = stand.to_local(world.player.global_position)
	for i in 6:
		capture_mouse()
		await process_frame
	var row := {"id": id, "x": x, "local_z": snappedf(local.z, 0.01), "pinned_in_range": pinned_reach(id), "prompt": prompt_for(id)}
	if not shot_name.is_empty(): await shot(shot_name)
	await press_interact_once()
	row["opened_first_press"] = tp.is_open() and tp.current_id == id
	for i in 30: await process_frame
	row["still_open_30f"] = tp.is_open() and tp.current_id == id
	if not shot_name.is_empty() and row.opened_first_press: await shot(shot_name + "_open")
	if tp.is_open():
		Input.parse_input_event(key_event(KEY_ESCAPE, true))
		await process_frame
		Input.parse_input_event(key_event(KEY_ESCAPE, false))
		for i in 6: await process_frame
		if tp.is_open(): tp.close()
		for i in 6: await process_frame
	log_("trader %s" % row)
	return row

func jump_peak() -> float:
	var p = world.player
	await place(Vector3(PLAZA.x, 0, PLAZA.y))
	for i in 30: await physics_frame
	var base_y: float = p.global_position.y
	var peak := base_y
	capture_mouse()
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	for f in 90:
		await physics_frame
		peak = maxf(peak, p.global_position.y)
	return snappedf(peak - base_y, 0.001)

func run() -> void:
	shots = OS.get_environment("BUNDLE_SHOTS").strip_edges()
	expect_fix = OS.get_environment("BUNDLE_BASELINE") != "1"
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
		session.create_character("slot_1", {"name": "Newcomer", "cheek": 0.0, "hair": "hair_short02_v1", "brows": "brow_009_v1", "eyes": "eye_brown_v1", "hair_tint": "natural"}, {"str": 7, "int": 7, "dex": 7}, [], state.bytes, false)
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
	check(world.get_script().resource_path == "res://raid/scripts/ship_settlement_preview.gd", "Play flow loads the ship settlement")
	var p = world.player
	var spawn: Vector3 = p.global_position
	report["spawn"] = [snappedf(spawn.x, 0.01), snappedf(spawn.y, 0.01), snappedf(spawn.z, 0.01)]
	report["notice_at_start"] = str(world.notice.text)
	var hud_title: Label = null
	for c in world.hud_root.get_children():
		if c is Label and str(c.text).begins_with("S E T T L E M E N T"): hud_title = c
	check(hud_title != null, "HUD title label exists")
	report["title_visible_at_start"] = hud_title != null and hud_title.visible
	log_("world up at %s" % spawn)
	capture_mouse()
	await shot("01_spawn_town_hall")
	root.get_viewport().disable_3d = true
	var fade = world.get_node_or_null("HudTitleFade")
	var guide = world.get_node_or_null("FirstRunGuide")
	if expect_fix:
		check(str(report.notice_at_start).contains("ship"), "First-run welcome names the ship")
		check(fade != null, "HudTitleFade installed")
		check(guide != null, "FirstRunGuide installed")
		check(guide != null and guide.step == "trader", "Fresh settler starts at guide step 1 (trader)")
		check(p.get_node_or_null("JumpTuning") != null, "Jump tuning attached to the settlement player")
	# ---- (b) title fade: re-arm, hold inside the hall, then step out.
	if expect_fix and fade != null and hud_title != null:
		fade.fade_started_ms = -1; fade.done = false; fade.reason = ""; fade.started_ms = -1
		hud_title.visible = true; hud_title.modulate.a = 1.0
		await place(Vector3(0, 0, -20.0), Vector3(0, 0, -10.0), 2.5)
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 1500: await process_frame
		check(hud_title.visible and hud_title.modulate.a > 0.99 and fade.fade_started_ms < 0, "Title holds while still inside the Town Hall before the timer")
	await place(Vector3(PLAZA.x, 0, PLAZA.y), Vector3(0, 0, 10))
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 2000: await process_frame
	report["title_visible_on_plaza"] = hud_title != null and hud_title.visible
	if expect_fix:
		report["title_fade_reason"] = fade.reason if fade != null else ""
		check(fade != null and fade.reason == "left_town_hall", "Title fade starts on leaving the Town Hall")
		check(hud_title != null and not hud_title.visible, "Title is hidden after the fade")
		var obj: Label = guide.label if guide != null else null
		report["objective_text"] = str(obj.text) if obj != null else ""
		check(obj != null and obj.visible and str(obj.text).begins_with("NEXT 1/3"), "Objective NEXT 1/3 shown once the title is gone")
	await shot("02_plaza_after_leaving_hall")
	# ---- (a) in-world standing jump peak (sweep numbers per obstacle are in test_jump_tuning).
	report["plaza_jump_peak_m"] = await jump_peak()
	log_("plaza jump peak %s" % report.plaza_jump_peak_m)
	if expect_fix: check(report.plaza_jump_peak_m > 0.99 and report.plaza_jump_peak_m < 1.06, "Plaza jump peak is the tuned ~1.03 m")
	# ---- (d) first Interact press at Psy and Dan.
	var rows := []
	rows.append(await trader_case("psy", 0.0, 0.0, "03_psy_counter_face"))
	if expect_fix and guide != null:
		report["guide_after_trader"] = guide.step
		check(guide.step == "ship", "Opening a trader advances the guide to step 2 (ship)")
		for i in 10: await process_frame
		check(guide.label.visible and str(guide.label.text).begins_with("NEXT 2/3"), "Objective NEXT 2/3 points to the ship")
		await shot("04_guide_ship_step")
	rows.append(await trader_case("psy", -2.4))
	rows.append(await trader_case("psy", 0.0, 2.9))
	rows.append(await trader_case("dan", 0.0, 0.0, "05_dan_counter_face"))
	rows.append(await trader_case("dan", 2.4))
	rows.append(await trader_case("dan", 0.0, 2.9, "06_dan_step_back"))
	report["trader_rows"] = rows
	var psy_face: Dictionary = rows[0]
	report["psy_counter_face_pinned_in_range"] = psy_face.pinned_in_range
	check(not psy_face.pinned_in_range, "Root cause holds: the pinned Psy strip has no service at the counter face")
	if expect_fix:
		for r in rows:
			check(r.prompt, "%s prompt at x=%.1f z=%.2f" % [r.id, r.x, r.local_z])
			check(r.opened_first_press, "%s opens on the FIRST Interact press at x=%.1f z=%.2f" % [r.id, r.x, r.local_z])
			check(r.still_open_30f, "%s panel stays open after the first press at x=%.1f z=%.2f" % [r.id, r.x, r.local_z])
	# ---- (c) ship pad -> step 3, raid select -> done.
	await place(SHIP_ZONE, Vector3(22, 0, -20), 2.5)
	for i in 10:
		capture_mouse()
		await process_frame
	if expect_fix and guide != null:
		report["guide_on_pad"] = guide.step
		check(guide.step == "board", "Standing on the ship pad advances the guide to step 3")
		check(str(guide.label.text).begins_with("NEXT 3/3"), "Objective NEXT 3/3 asks to pick a raid")
		await shot("07_guide_board_step")
	report["can_embark"] = world.ship_can_embark()
	if world.ship_can_embark():
		await press_interact_once()
		for i in 6: await process_frame
		report["raid_select_open"] = is_instance_valid(world.ship_selection)
		if expect_fix and guide != null:
			check(guide.step == "done", "Opening raid selection completes the guide")
			var path: String = guide.path
			var saved = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
			report["guide_sidecar"] = saved
			check(saved is Dictionary and saved.get("step") == "done", "Guide progress saved to the character sidecar")
			report["guide_history"] = guide.history
		if is_instance_valid(world.ship_selection):
			Input.parse_input_event(key_event(KEY_ESCAPE, true))
			await process_frame
			Input.parse_input_event(key_event(KEY_ESCAPE, false))
			for i in 10: await process_frame
	elif expect_fix:
		check(false, "ship_can_embark() at the pad zone")
	# ---- (c) recovery toast.
	var rec = world.get_node_or_null("TownHallRecovery")
	check(rec != null, "TownHallRecovery installed")
	if rec != null:
		var r: Dictionary = rec.return_to_entrance("bundle_test")
		for i in 6: await process_frame
		report["recovery_toast"] = str(world.notice.text)
		if expect_fix: check(str(world.notice.text).contains("ship"), "Recovery toast points toward the ship")
		await shot("08_recovery_toast")
	finish()
