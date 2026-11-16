extends Node
## Item 12 rollout 2 proof: the remodelled ship and request board are live in a
## NORMAL game start. Loaded ONLY through a temporary override.cfg autoload;
## project.godot is unchanged. Drives Play → settler card → Enter, then frames
## the launchpad and the request board (HUD stays visible). env: R2_LIVE_OUT=<dir>
const MidstyleSwap = preload("res://raid/scripts/midstyle_swap.gd")
const Rollout2 = preload("res://raid/scripts/midstyle_rollout2.gd")

func log_(s):
	print("R2 LIVE: ", s, "  t=", Time.get_ticks_msec() / 1000.0)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(1800).timeout.connect(func(): print("R2 LIVE: watchdog"); get_tree().quit(3))
	call_deferred("_run")

func frames(n: int):
	for i in n:
		await get_tree().process_frame

func click(control: Control):
	var p = control.get_global_rect().get_center()
	for pressed in [true, false]:
		var e = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.position = p; e.global_position = p
		Input.parse_input_event(e)
		await frames(2)
	log_("click " + str(control.name) + " " + str(p))

func wait_for(cond: Callable, seconds: float) -> bool:
	var deadline = Time.get_ticks_msec() + seconds * 1000
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await get_tree().process_frame
	return false

func shot(path: String) -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	log_("shot " + path)

func _run():
	var out := OS.get_environment("R2_LIVE_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	await wait_for(func(): return get_tree().current_scene != null and get_tree().current_scene.get("play_button") != null, 60)
	var title = get_tree().current_scene
	log_("main scene " + title.scene_file_path)
	await get_tree().create_timer(3.0).timeout
	await click(title.play_button)
	await wait_for(func(): return is_instance_valid(title.character_panel), 10)
	var panel = title.character_panel
	await get_tree().create_timer(2.0).timeout
	await click(panel.cards["slot_1"])
	await get_tree().create_timer(1.5).timeout
	await click(panel.enter_button)
	var ok = await wait_for(func():
		var s = get_tree().current_scene
		return s != null and s.get("world_activated") == true and s.get("world_initialized") == true, 1200)
	var world = get_tree().current_scene
	log_("world ready " + str(ok))
	if not ok:
		get_viewport().get_texture().get_image().save_png(out + "/FAILED_plain_launch.png")
		get_tree().quit(4)
		return
	await get_tree().create_timer(6.0).timeout
	log_("swap " + str(MidstyleSwap.enabled) + " rollout2 " + str(Rollout2.enabled))
	log_("meta " + str(world.get_meta("midstyle_rollout2", {})))
	log_("has hull " + str(world.has_node("LaunchpadShip/MidstyleLaunchpadHull")))
	log_("has board " + str(world.has_node("RequestBoard/MidstyleRequestBoard")))
	var player_cam := get_viewport().get_camera_3d()
	var ship: Node3D = world.get_node_or_null("LaunchpadShip")
	var board: Node3D = world.get_node_or_null("RequestBoard")
	var cam := Camera3D.new(); cam.near = 0.05; cam.far = 2000; world.add_child(cam)
	# Wide settlement with the ship in frame, HUD visible.
	cam.fov = 60; cam.global_position = Vector3(4, 18, 22); cam.look_at(Vector3(22, 2, -16)); cam.current = true
	await shot(out + "/live_plain_launch_settlement_ship.png")
	if ship != null:
		var st := ship.global_transform
		cam.fov = 60; cam.global_position = st * Vector3(0, 1.8, 13.0); cam.look_at(st * Vector3(0, 2.4, 0))
		await shot(out + "/live_plain_launch_ship_ramp.png")
		cam.fov = 50; cam.global_position = st * Vector3(-7.5, 2.6, 7.0); cam.look_at(st * Vector3(0.5, 3.1, 0))
		await shot(out + "/live_plain_launch_ship_close.png")
	if board != null:
		var bt := board.global_transform
		cam.fov = 60; cam.global_position = bt * Vector3(0, 1.6, 2.6); cam.look_at(bt * Vector3(0, 1.4, 0))
		await shot(out + "/live_plain_launch_request_board.png")
	cam.queue_free()
	if is_instance_valid(player_cam):
		player_cam.current = true
	get_tree().quit(0)
