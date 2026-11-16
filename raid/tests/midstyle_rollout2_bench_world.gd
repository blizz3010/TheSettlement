extends Node
## In-settlement frame-time bench for item 12 rollout 2 (manual). Loads the ship
## settlement, looks at the launchpad, then the request board. MIDSTYLE_ROLLOUT2=0|1.
## Env: ROLLOUT2_OUT=<abs json>, ROLLOUT2_FRAMES=<n>
const MidstyleSwap = preload("res://raid/scripts/midstyle_swap.gd")
const Rollout2 = preload("res://raid/scripts/midstyle_rollout2.gd")
const WARMUP := 20

func _ready() -> void:
	get_tree().create_timer(1500).timeout.connect(func(): get_tree().quit(3))
	call_deferred("run")

func run() -> void:
	var on := OS.get_environment("MIDSTYLE_ROLLOUT2") != "0"
	var out := OS.get_environment("ROLLOUT2_OUT")
	var frames := int(OS.get_environment("ROLLOUT2_FRAMES")) if OS.get_environment("ROLLOUT2_FRAMES") != "" else 40
	get_tree().root.size = Vector2i(1280, 800)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if not on:
		OS.set_environment("MIDSTYLE_ROLLOUT2", "0")
	MidstyleSwap.enabled = true
	var world: Node = load("res://raid/ship_settlement_preview.tscn").instantiate()
	if not world.bind_legacy_continue() or not world.request_town_hall_login():
		print("ROLLOUT2 BENCH BREAK login"); get_tree().quit(1); return
	world.staged_startup = true
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.loading_stage.connect(func(label, ms): print("ROLLOUT2 BENCH STAGE ", label, " ", snapped(ms, 0.1)))
	get_tree().root.add_child(world)
	var deadline := Time.get_ticks_msec() + 600000
	while is_instance_valid(world) and not world.world_initialized:
		if Time.get_ticks_msec() > deadline:
			print("ROLLOUT2 BENCH BREAK init phase=", world.startup_phase, " last=", world.startup_last_label)
			get_tree().quit(1); return
		await get_tree().process_frame
	if not is_instance_valid(world) or not world.world_initialized:
		print("ROLLOUT2 BENCH BREAK world previously freed or uninitialized")
		get_tree().quit(1); return
	var assets: Dictionary = await world.startup_asset_gate.prepare(world)
	if not assets.get("ok", false):
		print("ROLLOUT2 BENCH BREAK assets ", assets); get_tree().quit(1); return
	world.activate_loaded_world()
	get_tree().current_scene = world
	for i in 20: await get_tree().process_frame
	if is_instance_valid(world.get("player")):
		world.player.visible = false; world.player.enabled = false
	for child in world.get_children():
		if child is CanvasLayer or child is Control: child.visible = false
	var ship: Node3D = world.get_node("LaunchpadShip")
	var board: Node3D = world.get_node("RequestBoard")
	var cam := Camera3D.new(); cam.fov = 60; cam.near = 0.05; cam.far = 800
	world.add_child(cam); cam.current = true
	var report := {"rollout2": on, "ship_visible_tris": _tris(ship), "board_visible_tris": _tris(board), "views": {}}
	for view in [
		["ship", ship.global_transform * Vector3(-10, 8, 14), ship.global_transform * Vector3(0, 2, 0)],
		["board", board.global_transform * Vector3(0, 1.6, 3.2), board.global_transform * Vector3(0, 1.3, 0)],
	]:
		cam.global_position = view[1]; cam.look_at(view[2])
		var ms: Array[float] = []; var last := 0
		for f in WARMUP + frames:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			if f >= WARMUP and last > 0: ms.append((now - last) / 1000.0)
			last = now
		var sorted := ms.duplicate(); sorted.sort(); var total := 0.0
		for v in sorted: total += v
		report.views[view[0]] = {"frames": sorted.size(), "avg_ms": total / sorted.size(), "median_ms": sorted[sorted.size() / 2],
			"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
	print("ROLLOUT2 WORLD BENCH ", JSON.stringify(report))
	if out != "":
		var fh := FileAccess.open(out, FileAccess.WRITE); fh.store_string(JSON.stringify(report, "  ")); fh.close()
	get_tree().quit(0)

func _tris(root: Node) -> int:
	var total := 0
	if root == null: return -1
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree(): continue
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var idx = a[Mesh.ARRAY_INDEX]
			total += (idx.size() if idx != null and idx.size() > 0 else a[Mesh.ARRAY_VERTEX].size()) / 3
	return total
