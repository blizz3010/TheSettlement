extends SceneTree
## Ori's Nov 18 playtest (ship could not be boarded). Rendered acceptance through the real Play
## flow: title -> Play -> settler -> Enter -> threaded world load and staged startup. Then the
## real player controller walks (Input.action_press("forward"), its own _physics_process, real
## collision) from the plaza along the concrete path -- StoneConnector0..2, ApproachStub, the
## accessible ramp -- onto PadDeck, and the test asserts the boarding prompt is shown and that a
## real Interact key event opens raid selection. It also probes the grass pockets on both sides
## of the ramp, between the ramp side and the pad's retaining wall, for a wedge trap.
## Needs a display (xvfb-run, --rendering-driver opengl3): headless cannot capture the mouse,
## and production ship_can_embark() requires a captured mouse. The runner launches it that way.
## env: BOARD_SHOTS=<dir> also writes JPEG (q88) review shots; BOARD_EXPECT_FIX=1 also checks
## the wayfinding added by raid/scripts/ship_boarding_wayfinding.gd.
const MARKER := "SHIP_BOARDING_ROUTE_TESTS "
const SHIP_ZONE := Vector3(22.0, 1.28, -11.2)
## Plaza (east of the fountain) -> StoneConnector0 start -> 1 -> 2 -> stub -> ramp -> pad zone.
const ROUTE := [Vector2(5.6, -2.0), Vector2(5.2, 7.8), Vector2(11.0, 10.0), Vector2(22.0, 10.0), Vector2(22.0, 2.8), Vector2(22.0, -2.2), Vector2(22.0, -8.6), Vector2(22.0, -11.2)]
var checks := 0
var failures: Array = []
var report := {}
var world: Node
var shots := ""
var expect_fix := false
## Rendering is not needed for the physics walk: with BOARD_FAST (default on) the 3D view is
## switched off between shots so llvmpipe does not throttle physics frames to ~1 fps.
var fast := true

func _initialize(): call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func log_(s: String) -> void: print("BOARD_ROUTE: ", s, "  t=", Time.get_ticks_msec() / 1000.0)

func finish() -> void:
	report["checks"] = checks
	report["failures"] = failures
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
	root.get_viewport().disable_3d = fast

func capture_mouse() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func floor_name() -> String:
	var p = world.player
	var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP * 0.25, p.global_position - Vector3.UP * 0.8)
	q.exclude = [p.get_rid()]
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(q)
	return "" if hit.is_empty() else str(world.get_path_to(hit.collider))

func face(target: Vector2) -> void:
	var p = world.player
	var d := target - Vector2(p.global_position.x, p.global_position.z)
	if d.length() > 0.01: p.rotation.y = atan2(-d.x, -d.y)

## Walk with the real controller toward target until within reach. Returns the outcome.
func walk(target: Vector2, reach := 0.45, max_s := 0.0, sprint := false) -> Dictionary:
	var p = world.player
	var start := Vector2(p.global_position.x, p.global_position.z)
	if max_s <= 0.0: max_s = start.distance_to(target) / 4.2 * 1.8 + 3.0
	var frames := int(max_s * 60.0)
	var last := start
	var still := 0
	Input.action_press("forward")
	if sprint: Input.action_press("sprint")
	var result := {"reached": false, "stuck": false}
	for f in frames:
		capture_mouse()
		face(target)
		await physics_frame
		var at := Vector2(p.global_position.x, p.global_position.z)
		if at.distance_to(target) <= reach:
			result.reached = true
			break
		if f % 30 == 29:
			still = still + 1 if at.distance_to(last) < 0.15 else 0
			last = at
			if still >= 4:
				result.stuck = true
				break
		if f % 20 == 0:
			var n := floor_name()
			if not n.is_empty(): report["floors"][n] = true
	Input.action_release("forward")
	Input.action_release("sprint")
	for i in 10: await physics_frame
	result["at"] = [snappedf(p.global_position.x, 0.01), snappedf(p.global_position.y, 0.01), snappedf(p.global_position.z, 0.01)]
	return result

func place(xz: Vector2, yaw_target := Vector2.INF) -> void:
	var p = world.player
	var q := PhysicsRayQueryParameters3D.create(Vector3(xz.x, 6.0, xz.y), Vector3(xz.x, -3.0, xz.y))
	q.exclude = [p.get_rid()]
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(q)
	p.global_position = Vector3(xz.x, (hit.position.y if not hit.is_empty() else 0.0) + 0.05, xz.y)
	p.velocity = Vector3.ZERO
	if yaw_target != Vector2.INF: face(yaw_target)
	for i in 20: await physics_frame

func interact_event() -> InputEventKey:
	var ev := InputEventKey.new()
	for e in InputMap.action_get_events("interact"):
		if e is InputEventKey:
			ev.physical_keycode = e.physical_keycode
			ev.keycode = e.keycode
			break
	ev.pressed = true
	return ev

func run() -> void:
	shots = OS.get_environment("BOARD_SHOTS").strip_edges()
	expect_fix = OS.get_environment("BOARD_EXPECT_FIX") == "1"
	fast = OS.get_environment("BOARD_FAST") != "0"
	if not shots.is_empty(): DirAccess.make_dir_recursive_absolute(shots)
	report["floors"] = {}
	if DisplayServer.get_name() == "headless":
		check(false, "Needs a display (xvfb-run --rendering-driver opengl3): mouse capture gates boarding")
		finish(); return
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	var Session = load("res://scripts/character_profiles/title_session.gd")
	var Rules = load("res://scripts/character_profiles/experimental_rules.gd")
	var session = Session.new(); session.rules = Rules.data()
	var state = session.inspect()
	if state.screen == "create":
		session.create_character("slot_1", {"name": "Boarder", "cheek": 0.0, "hair": "hair_short02_v1", "brows": "brow_009_v1", "eyes": "eye_brown_v1", "hair_tint": "natural"}, {"str": 7, "int": 7, "dex": 7}, [], state.bytes, false)
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
	log_("world up at " + str(world.player.global_position))
	for i in 30: await physics_frame
	var p = world.player
	if not p.third_person: p.toggle_view()
	capture_mouse()
	for i in 10: await process_frame
	report["mouse_captured"] = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Mouse capture works under this display")
	report["jump_velocity"] = 6.0
	root.get_viewport().disable_3d = fast
	# ---- A. plaza -> concrete path -> ramp -> PadDeck, real controller and collision
	await place(Vector2(5.0, -6.0), ROUTE[0])
	report["start"] = [p.global_position.x, p.global_position.y, p.global_position.z]
	await shot("route_01_plaza_start")
	var legs := []
	var ok_route := true
	var hint_seen_at := -1.0
	for i in ROUTE.size():
		var reach := 0.6 if i < ROUTE.size() - 1 else 0.5
		var r := await walk(ROUTE[i], reach)
		r["to"] = [ROUTE[i].x, ROUTE[i].y]
		r["floor"] = floor_name()
		legs.append(r)
		log_("leg %d -> %s: %s" % [i, ROUTE[i], r])
		if expect_fix and hint_seen_at < 0.0 and world.prompt_panel.visible and str(world.prompt.text).contains("ship"):
			hint_seen_at = Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(SHIP_ZONE.x, SHIP_ZONE.z))
		if i == 3: await shot("route_02_path_turn_to_ramp")
		if i == 5: await shot("route_03_ramp_foot")
		if not r.reached:
			ok_route = false
			break
	report["legs"] = legs
	check(ok_route, "Real controller walks the concrete path from the plaza onto PadDeck without getting stuck")
	for i in 20:
		capture_mouse()
		await process_frame
	var local: Vector3 = world.get_node("LaunchpadShip").to_local(p.global_position)
	report["zone_local"] = [snappedf(local.x, 0.01), snappedf(local.y, 0.01), snappedf(local.z, 0.01)]
	report["on_floor_name"] = floor_name()
	report["has_boarding_support"] = world.ship_has_boarding_support()
	report["can_embark"] = world.ship_can_embark()
	report["prompt_visible"] = world.prompt_panel.visible
	report["prompt_text"] = str(world.prompt.text)
	check(report.on_floor_name.ends_with("LaunchpadShip/Collision/PadDeck"), "Player stands on PadDeck at the boarding zone")
	check(report.has_boarding_support, "Production boarding predicate accepts the walked position")
	check(report.can_embark, "ship_can_embark() is true at the end of the walk")
	check(world.prompt_panel.visible and report.prompt_text.contains("Select raid") and report.prompt_text.contains("Ship deployment"), "Boarding prompt 'Select raid • Ship deployment' is shown")
	await shot("route_04_pad_prompt")
	Input.parse_input_event(interact_event())
	for i in 10: await process_frame
	report["raid_select_open"] = is_instance_valid(world.ship_selection) and world.ship_selection.is_inside_tree()
	check(report.raid_select_open, "Real Interact key event opens raid selection")
	await shot("route_05_raid_select")
	if is_instance_valid(world.ship_selection):
		var esc := InputEventKey.new(); esc.physical_keycode = KEY_ESCAPE; esc.keycode = KEY_ESCAPE; esc.pressed = true
		Input.parse_input_event(esc)
		for i in 10: await process_frame
	check(not is_instance_valid(world.ship_selection), "Escape closes raid selection without departing")
	if expect_fix:
		report["hint_seen_at_m"] = hint_seen_at
		check(hint_seen_at > 3.0, "Route hint is shown on the approach before the boarding zone")
	# ---- B. grass pockets beside the ramp (between ramp side and the pad's retaining wall)
	p.enabled = true
	var pockets := {}
	for side in [-1.0, 1.0]:
		var key := "west" if side < 0 else "east"
		var outer: float = 22.0 + side * 2.0
		await place(Vector2(outer, -3.0), Vector2(outer, -9.0))
		var into: Dictionary = await walk(Vector2(22.0 + side * 1.75, -9.4), 0.3, 6.0)
		var deepest: Vector3 = p.global_position
		await shot("wedge_%s_in" % key)
		var out: Dictionary = await walk(Vector2(outer + side * 1.0, -2.0), 0.6, 8.0)
		var plaza := {"reached": true}
		if out.reached: plaza = await walk(Vector2(12.0, -2.0), 0.8, 8.0)
		pockets[key] = {"into": into, "deepest": [snappedf(deepest.x, 0.01), snappedf(deepest.y, 0.01), snappedf(deepest.z, 0.01)], "back_out": out, "to_plaza": plaza}
		log_("pocket %s: %s" % [key, pockets[key]])
		check(out.reached and plaza.reached, "Player can walk back out of the %s ramp pocket" % key)
		if expect_fix:
			check(deepest.z > -8.0 or deepest.y > 0.4, "The %s grass pocket is closed (player cannot walk into the ramp/wall wedge)" % key)
	report["pockets"] = pockets
	finish()
