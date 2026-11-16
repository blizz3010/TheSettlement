extends Node
## Item 12 rollout 2 capture: load the ship settlement with the new swap off, shoot
## before views of the launchpad ship and request board, apply midstyle_rollout2.gd,
## then shoot the same after views. Not part of the suite.
## xvfb-run -s '-screen 0 1440x900x24' godot --rendering-driver opengl3 --path . res://raid/tests/midstyle_rollout2_capture.tscn
## Env: ROLLOUT2_OUT=<abs dir>
const MidstyleSwap = preload("res://raid/scripts/midstyle_swap.gd")
const Rollout2 = preload("res://raid/scripts/midstyle_rollout2.gd")
var out_dir := ""

func _ready() -> void:
	get_tree().create_timer(1500).timeout.connect(func(): get_tree().quit(3))
	call_deferred("run")

func shoot(world: Node3D, tag: String) -> void:
	var ship: Node3D = world.get_node_or_null("LaunchpadShip")
	var board: Node3D = world.get_node_or_null("RequestBoard")
	var views: Array = []
	if ship != null:
		var st := ship.global_transform
		views.append(["ship_player", st * Vector3(0, 1.7, 13.5), st * Vector3(0, 2.6, 0), 70.0])
		views.append(["ship_close", st * Vector3(-7.5, 2.6, 7.0), st * Vector3(0.5, 3.1, 0), 50.0])
		views.append(["ship_rear", st * Vector3(9.5, 2.5, 3.2), st * Vector3(2.0, 3.1, 0), 50.0])
		views.append(["ship_wide", st * Vector3(-14.0, 11.0, 16.0), st * Vector3(0, 1.5, 0), 60.0])
	if board != null:
		var bt := board.global_transform
		views.append(["board_player", bt * Vector3(0, 1.55, 2.5), bt * Vector3(0, 1.40, 0), 70.0])
		views.append(["board_close", bt * Vector3(0.55, 1.50, 1.35), bt * Vector3(0, 1.45, 0), 48.0])
	for v in views:
		var cam := Camera3D.new(); cam.fov = v[3]; cam.near = 0.05; cam.far = 800
		world.add_child(cam); cam.global_position = v[1]; cam.look_at(v[2]); cam.current = true
		for i in 6: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [v[0], tag]))
		cam.queue_free()
		print("ROLLOUT2 shot ", v[0], " ", tag)

func run() -> void:
	out_dir = OS.get_environment("ROLLOUT2_OUT").strip_edges()
	if out_dir.is_empty(): out_dir = ProjectSettings.globalize_path("res://raid/screenshots/rollout2")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	# Force the new swap off for the "before" pass; item 11 / rollout 1 stay on.
	OS.set_environment("MIDSTYLE_ROLLOUT2", "0")
	MidstyleSwap.enabled = true
	Rollout2.enabled = false
	var world: Node = load("res://raid/ship_settlement_preview.tscn").instantiate()
	if not world.bind_legacy_continue() or not world.request_town_hall_login():
		print("ROLLOUT2 BREAK login binding failed"); get_tree().quit(1); return
	world.staged_startup = true
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.loading_stage.connect(func(label, ms): print("ROLLOUT2 STAGE ", label, " ", snapped(ms, 0.1)))
	get_tree().root.add_child(world)
	var deadline := Time.get_ticks_msec() + 600000
	var frames := 0
	while is_instance_valid(world) and not world.world_initialized:
		if Time.get_ticks_msec() > deadline:
			print("ROLLOUT2 BREAK world did not initialize phase=", world.startup_phase, " last=", world.startup_last_label)
			get_tree().quit(1); return
		frames += 1
		if frames % 120 == 0:
			print("ROLLOUT2 wait phase=", world.startup_phase, " last=", world.startup_last_label, " cancel=", world.startup_cancel_requested)
		await get_tree().process_frame
	if not is_instance_valid(world) or not world.world_initialized:
		print("ROLLOUT2 BREAK world previously freed or uninitialized")
		get_tree().quit(1); return
	var assets: Dictionary = await world.startup_asset_gate.prepare(world)
	if not assets.get("ok", false):
		print("ROLLOUT2 BREAK assets ", assets); get_tree().quit(1); return
	world.activate_loaded_world()
	get_tree().current_scene = world
	for i in 30: await get_tree().process_frame
	if is_instance_valid(world.get("player")):
		world.player.visible = false; world.player.enabled = false
	for child in world.get_children():
		if child is CanvasLayer or child is Control: child.visible = false
	var before := {
		"ship": _tris(world.get_node_or_null("LaunchpadShip")),
		"board": _tris(world.get_node_or_null("RequestBoard")),
	}
	await shoot(world, "before")
	Rollout2.enabled = true
	var result := Rollout2.apply(world)
	var after := {
		"ship": _tris(world.get_node_or_null("LaunchpadShip")),
		"board": _tris(world.get_node_or_null("RequestBoard")),
	}
	print("ROLLOUT2 RESULT ", JSON.stringify({"swap": result, "visible_tris_before": before, "visible_tris_after": after}))
	await shoot(world, "after")
	get_tree().quit(0 if result.get("ok", false) else 2)

func _tris(root: Node) -> int:
	if root == null: return -1
	var total := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree(): continue
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var idx = a[Mesh.ARRAY_INDEX]
			total += (idx.size() if idx != null and idx.size() > 0 else a[Mesh.ARRAY_VERTEX].size()) / 3
	return total
