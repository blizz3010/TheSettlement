extends Node
## Item 12 proof: the mid-stylized props are live in the NORMAL game start. Same approach as
## play_flow_capture.gd: loaded ONLY through a temporary override.cfg autoload during capture
## (project.godot unchanged), so the game is a plain `godot --path .` launch of main_scene
## (raid/play_title.tscn). Drives real input: Play -> settler card -> Enter -> settlement, then
## W up the ship ramp, E, Deploy -> Relay Ridge. At each stop it adds a framing camera next to
## the styled props (the game itself is untouched) and logs which art scene is instanced.
## env RL_OUT=<dir>; RL_SETTLEMENT_ONLY=1 stops after the settlement shots.
## Run: write override.cfg with [autoload] RolloutLiveCapture="*res://raid/tests/rollout_live_capture.gd",
## seed settlers with play_flow_seed.gd in a scratch XDG profile, then
## RL_OUT=<dir> xvfb-run -s '-screen 0 1440x900x24' godot --rendering-driver opengl3 --path . ; delete override.cfg after.
const MidstyleSwap = preload("res://raid/scripts/midstyle_swap.gd")
const Rollout = preload("res://raid/scripts/midstyle_rollout.gd")
var out := ""
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	out = OS.get_environment("RL_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(5400).timeout.connect(func(): print("RL: watchdog"); get_tree().quit(3))
	call_deferred("_run")

func log_(s): print("RL: ", s, "  t=", Time.get_ticks_msec() / 1000)

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


func framed(parent: Node, views: Array, prefix: String):
	# views: [name, eye, look, fov] in world space
	var player_cam := get_viewport().get_camera_3d()
	var cam := Camera3D.new(); cam.near = 0.05; cam.far = 600; parent.add_child(cam); cam.current = true
	for v in views:
		cam.fov = v[3]; cam.global_position = v[1]; cam.look_at(v[2])
		await get_tree().create_timer(1.5).timeout
		await shot(prefix + v[0])
	cam.queue_free()
	if is_instance_valid(player_cam): player_cam.current = true

func art_view(art: Node3D, eye: Vector3, look: Vector3) -> Array:
	var t := art.global_transform.orthonormalized()
	return [t * eye, t * look]

func _run():
	await wait_for(func(): return get_tree().current_scene != null and get_tree().current_scene.get("play_button") != null, 60)
	var title = get_tree().current_scene
	log_("main scene " + title.scene_file_path + " script " + title.get_script().resource_path + " main_scene setting " + str(ProjectSettings.get_setting("application/run/main_scene")))
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
	if not ok: await shot("FAILED_settlement"); get_tree().quit(4); return
	await get_tree().create_timer(6.0).timeout
	log_("swap enabled " + str(MidstyleSwap.enabled) + " rollout enabled " + str(Rollout.enabled))
	for n in ["TailorAtelier", "RookReferenceArt", "HallReceptionAssemblyV098"]:
		var node = world.get_node_or_null(n)
		var styled := 0
		if node:
			for m in node.find_children("*", "Node3D", true, false):
				if str(m.scene_file_path).contains("midstyle"): styled += 1
		log_(n + " present " + str(node != null) + " midstyle instances " + str(styled))
	log_("swap result " + str(world.get_meta("midstyle_style_test", {}).get("ok")) + " dress form " + str(world.has_node("TailorAtelier/MidstyleDressForm")) + " counter stock " + str(world.has_node("RookReferenceArt/MidstyleCounterStock")) + " reception " + str(world.has_node("HallReceptionAssemblyV098/MidstyleReceptionDesk")))
	# World-space framings from the item 11 capture (midstyle_capture.gd), same props.
	await framed(world, [
		["tailor", Vector3(-25.55, 1.62, -4.35), Vector3(-28.6, 1.30, -4.0), 70.0],
		["rook", Vector3(30.0, 1.62, 32.4), Vector3(30.0, 1.15, 34.5), 70.0],
		["reception", Vector3(0.6, 1.86, -17.6), Vector3(0.0, 0.95, -22.0), 70.0]], "live_settlement_")
	if OS.get_environment("RL_SETTLEMENT_ONLY") == "1": log_("done (settlement only)"); get_tree().quit(0); return
	var ship = world.get_node("LaunchpadShip")
	var player = world.player
	player.global_position = ship.to_global(Vector3(0, 0.1, 15))
	player.global_rotation = Vector3(0, ship.global_rotation.y, 0)
	player.velocity = Vector3.ZERO
	player.pitch = 0.05; player.camera.rotation.x = 0.05
	await get_tree().create_timer(1.0).timeout
	if not world.cooking_window_focused: world.cooking_window_focused = true
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	key(KEY_W, true)
	var reached = await wait_for(func(): return world.ship_can_embark(), 1200)
	key(KEY_W, false)
	await get_tree().create_timer(1.0).timeout
	log_("on pad " + str(reached))
	key(KEY_E, true); await frames(2); key(KEY_E, false)
	var sel_ok = await wait_for(func(): return is_instance_valid(world.ship_selection), 5)
	if not sel_ok: log_("selection failed"); get_tree().quit(5); return
	await get_tree().create_timer(1.5).timeout
	await click(world.ship_selection.deploy_button)
	var raid_ok = await wait_for(func():
		var s = get_tree().current_scene
		return s != null and s.get("raid") != null and is_instance_valid(s.raid) and s.raid.is_raid_ready() and not s.cover.visible, 2400)
	log_("raid ready " + str(raid_ok))
	if not raid_ok: await shot("FAILED_raid"); get_tree().quit(6); return
	await get_tree().create_timer(5.0).timeout
	var raid = get_tree().current_scene.raid
	log_("raid " + str(raid.scene_file_path) + " rollout enabled " + str(Rollout.enabled))
	var views := []
	var relays = raid.find_children("PuzzleControlArt", "Node3D", true, false)
	var caches = raid.find_children("CacheArt", "Node3D", true, false)
	var cargo = raid.find_children("CargoArt", "Node3D", true, false)
	for a in relays + caches + cargo: log_("art " + a.name + " " + a.scene_file_path)
	if relays.size() > 1: views.append(["relay"] + art_view(relays[1], Vector3(0.35, 1.62, 2.4), Vector3(0, 1.05, 0)) + [70.0])
	if caches.size() > 0: views.append(["cache"] + art_view(caches[0], Vector3(0.6, 1.62, 2.3), Vector3(0, 0.45, 0)) + [70.0])
	var intact = cargo.filter(func(a): return a.get_meta("cargo_kind", "") == "container_intact")
	if intact.size() > 0: views.append(["container"] + art_view(intact[0], Vector3(4.6, 1.75, 4.2), Vector3(0, 1.1, 0.8)) + [70.0])
	await framed(raid, views, "live_raid_")
	log_("done")
	get_tree().quit(0)
