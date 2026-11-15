extends Node
## Capture driver for the normal play flow. Loaded ONLY through a temporary override.cfg
## autoload during capture (project.godot is not changed), so the game itself starts as a
## plain `godot --path .` launch of main_scene. Drives real input events:
## mouse clicks on Play / settler card / Enter, W to walk up the ship ramp, E to board,
## a click on Deploy. env PF_OUT=<dir>. Timeouts are wall-clock and generous: llvmpipe
## renders the settlement at a few seconds per frame.
var out := ""
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	out = OS.get_environment("PF_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(5400).timeout.connect(func(): print("PF: watchdog"); get_tree().quit(3))
	call_deferred("_run")

func log_(s): print("PF: ", s, "  t=", Time.get_ticks_msec() / 1000)

func shot(name: String):
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	log_("shot " + name)

func frames(n: int):
	for i in n: await get_tree().process_frame

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

func wait_for(cond: Callable, seconds: float) -> bool:
	var deadline = Time.get_ticks_msec() + seconds * 1000
	while Time.get_ticks_msec() < deadline:
		if cond.call(): return true
		await get_tree().process_frame
	return false

func _run():
	await wait_for(func(): return get_tree().current_scene != null and get_tree().current_scene.get("play_button") != null, 60)
	var title = get_tree().current_scene
	log_("main scene " + title.scene_file_path + " script " + title.get_script().resource_path)
	await get_tree().create_timer(3.0).timeout
	await shot("01_main_menu")
	await click(title.play_button)
	await wait_for(func(): return is_instance_valid(title.character_panel), 10)
	var panel = title.character_panel
	log_("select panel " + panel.get_script().resource_path + " stage " + panel.preview.get_script().resource_path + " model_ok " + str(panel.preview.model_ok))
	await get_tree().create_timer(2.0).timeout
	await click(panel.cards["slot_1"])
	await get_tree().create_timer(1.5).timeout
	await shot("02_character_select")
	# Close-up: same live screen, cropped to the plinth and info card.
	var img = get_viewport().get_texture().get_image()
	var w = img.get_width(); var h = img.get_height()
	img.get_region(Rect2i(int(w * 0.30), int(h * 0.09), int(w * 0.68), int(h * 0.80))).save_png(out + "/02b_character_select_closeup.png")
	log_("selected " + panel.selected_slot + " enter_disabled " + str(panel.enter_button.disabled))
	await click(panel.enter_button)
	# Intro video (new settler) then threaded world load + staged startup.
	var ok = await wait_for(func():
		var s = get_tree().current_scene
		return s != null and s.get("world_activated") == true and s.get("world_initialized") == true, 1200)
	var world = get_tree().current_scene
	log_("world ready " + str(ok) + " " + str(world.get_script().resource_path if world else "none"))
	if not ok: await shot("03_FAILED"); get_tree().quit(4); return
	await get_tree().create_timer(6.0).timeout
	log_("focused " + str(world.cooking_window_focused) + " mouse " + str(Input.mouse_mode) + " slot " + str(world.character_slot_bound))
	await shot("03_settlement")
	# Walk up the real ship ramp: start on open ground south of the pad, hold W.
	var ship = world.get_node("LaunchpadShip")
	var player = world.player
	player.global_position = ship.to_global(Vector3(0, 0.1, 15))
	player.global_rotation = Vector3(0, ship.global_rotation.y, 0)
	player.velocity = Vector3.ZERO
	player.pitch = 0.05; player.camera.rotation.x = 0.05
	await get_tree().create_timer(1.0).timeout
	if not world.cooking_window_focused:
		log_("window not focused under Xvfb; marking focused for input")
		world.cooking_window_focused = true
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		log_("mouse not captured; capturing"); Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	key(KEY_W, true)
	var took_approach = false
	var reached = await wait_for(func():
		var l = ship.to_local(player.global_position)
		if not took_approach and l.z < 10.5:
			took_approach = true
			call_deferred("shot", "04a_spaceship_approach")
		return world.ship_can_embark(), 1200)
	key(KEY_W, false)
	await get_tree().create_timer(1.0).timeout
	log_("on pad " + str(reached) + " local " + str(ship.to_local(player.global_position)) + " embark " + str(world.ship_can_embark()))
	await shot("04_spaceship_boarding")
	key(KEY_E, true); await frames(2); key(KEY_E, false)
	var sel_ok = await wait_for(func(): return is_instance_valid(world.ship_selection), 5)
	log_("selection open " + str(sel_ok))
	if not sel_ok: get_tree().quit(5); return
	await get_tree().create_timer(1.5).timeout
	await shot("04b_ship_raid_selection")
	await click(world.ship_selection.deploy_button)
	var raid_ok = await wait_for(func():
		var s = get_tree().current_scene
		return s != null and s.get("raid") != null and is_instance_valid(s.raid) and s.raid.is_raid_ready() and not s.cover.visible, 2400)
	log_("raid ready " + str(raid_ok))
	await get_tree().create_timer(5.0).timeout
	await shot("05_inside_raid" if raid_ok else "05_FAILED")
	log_("done")
	get_tree().quit(0 if raid_ok else 6)
