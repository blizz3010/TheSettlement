extends Node
## Item 9 proof: far scenery is live in the NORMAL game start (play_title → settlement).
## Loaded ONLY through a temporary override.cfg autoload; project.godot is unchanged.
## Drives Play → settler card → Enter, then frames the same settlement-wide camera
## used by far_scenery_capture.gd. env: FS_LIVE_OUT=<dir>
const WIDE := {"name": "settlement_wide", "origin": Vector3(-42.0, 48.0, -48.0), "look": Vector3(8.0, 6.0, 22.0)}

func log_(s):
	print("FS LIVE: ", s, "  t=", Time.get_ticks_msec() / 1000.0)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(1800).timeout.connect(func(): print("FS LIVE: watchdog"); get_tree().quit(3))
	call_deferred("_run")

func frames(n: int):
	for i in n:
		await get_tree().process_frame

func click(control: Control):
	var p = control.get_global_rect().get_center()
	for pressed in [true, false]:
		var e = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		e.global_position = p
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

func _run():
	var out := OS.get_environment("FS_LIVE_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	await wait_for(func(): return get_tree().current_scene != null and get_tree().current_scene.get("play_button") != null, 60)
	var title = get_tree().current_scene
	log_("main scene " + title.scene_file_path + " script " + title.get_script().resource_path)
	log_("main_scene setting " + str(ProjectSettings.get_setting("application/run/main_scene")))
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
	log_("world ready " + str(ok) + " " + str(world.get_script().resource_path if world else "none"))
	if not ok:
		get_viewport().get_texture().get_image().save_png(out + "/FAILED_plain_launch.png")
		get_tree().quit(4)
		return
	await get_tree().create_timer(6.0).timeout
	var meta = world.get_meta("far_scenery_option", {})
	log_("far meta " + str(meta))
	log_("FarScenery present " + str(world.has_node("FarScenery")))
	log_("ribs hidden " + str(meta.get("hidden_original_ribs", 0)))
	var player_cam := get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.near = 0.05
	cam.far = 2000.0
	cam.fov = 60.0
	world.add_child(cam)
	cam.global_position = WIDE.origin
	cam.look_at(WIDE.look)
	cam.current = true
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var path := out + "/live_plain_launch_settlement_wide.png"
	get_viewport().get_texture().get_image().save_png(path)
	log_("shot " + path)
	cam.queue_free()
	if is_instance_valid(player_cam):
		player_cam.current = true
	get_tree().quit(0)
