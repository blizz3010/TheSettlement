extends Node
## Item 9 far-scenery iso bench (manual, not part of the suite).
## Loads the settlement, places a fixed outward-looking edge orbit, and
## records frame times on whatever GPU/software renderer is in use.
## Env: FAR_SCENERY_OPTION=off|A|B|C, FAR_BENCH_OUT=<abs json>, FAR_BENCH_FRAMES=<n>
const WARMUP := 8

var journal := {}

static var _started := false

func _ready() -> void:
	get_tree().create_timer(1200).timeout.connect(func(): get_tree().quit(3))
	call_deferred("_boot")

func _boot() -> void:
	if get_parent() == get_tree().root and get_tree().current_scene != self:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene != self and scene.get_script() == get_script():
			return
		for i in 4:
			await get_tree().process_frame
	if _started:
		return
	_started = true
	run()

func run() -> void:
	var opt := OS.get_environment("FAR_SCENERY_OPTION").strip_edges()
	var out := OS.get_environment("FAR_BENCH_OUT")
	var frames := int(OS.get_environment("FAR_BENCH_FRAMES")) if OS.get_environment("FAR_BENCH_FRAMES") != "" else 40
	get_tree().root.size = Vector2i(1280, 800)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var world: Node = load("res://raid/ship_settlement_preview.tscn").instantiate()
	if not world.bind_legacy_continue() or not world.request_town_hall_login():
		push_error("FAR BENCH login failed")
		get_tree().quit(1)
		return
	world.staged_startup = true
	world.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(world)
	var deadline := Time.get_ticks_msec() + 300000
	while is_instance_valid(world) and not world.world_initialized:
		if Time.get_ticks_msec() > deadline:
			push_error("FAR BENCH world did not initialize")
			get_tree().quit(1)
			return
		await get_tree().process_frame
	if not is_instance_valid(world) or not world.world_initialized:
		push_error("FAR BENCH world was freed or failed to initialize")
		get_tree().quit(1)
		return
	var assets: Dictionary = await world.startup_asset_gate.prepare(world)
	if not assets.get("ok", false):
		push_error("FAR BENCH assets: " + str(assets))
		get_tree().quit(1)
		return
	world.activate_loaded_world()
	get_tree().current_scene = world
	for i in 12:
		await get_tree().process_frame
	if is_instance_valid(world.get("player")):
		world.player.visible = false
		world.player.enabled = false
	for child in world.get_children():
		if child is CanvasLayer or child is Control:
			child.visible = false
	var cam := Camera3D.new()
	cam.name = "FarBenchCamera"
	cam.fov = 72.0
	cam.near = 0.05
	cam.far = 4000.0
	world.add_child(cam)
	cam.current = true
	var ms: Array[float] = []
	var last := 0
	var info := {}
	for f in WARMUP + frames:
		var a := TAU * float(max(f - WARMUP, 0)) / float(maxi(frames, 1))
		var pos := Vector3(cos(a) * 38.0, 8.0, sin(a) * 38.0)
		var look := Vector3(cos(a) * 240.0, 22.0, sin(a) * 240.0)
		cam.global_position = pos
		cam.look_at(look, Vector3.UP)
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if f >= WARMUP and last > 0:
			ms.append((now - last) / 1000.0)
		last = now
		if f == WARMUP:
			var vp := get_viewport().get_viewport_rid()
			info = {
				"draw_calls": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
				"primitives": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
				"objects": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
			}
	var sorted := ms.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted:
		total += v
	var k := maxi(1, int(ceil(sorted.size() * 0.01)))
	var worst := 0.0
	for j in k:
		worst += sorted[sorted.size() - 1 - j]
	var report := {
		"option": opt if opt != "" else "off",
		"frames": sorted.size(),
		"avg_ms": total / sorted.size() if not sorted.is_empty() else 0.0,
		"median_ms": sorted[sorted.size() / 2] if not sorted.is_empty() else 0.0,
		"one_pct_low_ms": worst / k if k > 0 else 0.0,
		"first_frame": info,
		"far_option_meta": world.get_meta("far_scenery_option", {}),
		"lake_fix_present": world.has_meta("inn_lake_mountain_fix"),
	}
	print("FAR ISO RESULT ", JSON.stringify(report))
	if out != "":
		var fh := FileAccess.open(out, FileAccess.WRITE)
		fh.store_string(JSON.stringify(report, "  "))
		fh.close()
	get_tree().quit(0)
