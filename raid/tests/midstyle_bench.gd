extends Node
## Item 11 frame-time bench (manual, not part of the suite).
## Loads the preview settlement exactly like midstyle_capture.gd, optionally applies the
## item 11 swap, then flies a fixed, frame-indexed camera path past each prop
## (player-height view -> close view) and records per-frame times.
## Run under Xvfb:  godot --rendering-driver opengl3 --path . res://raid/tests/midstyle_bench.tscn
## Env: MIDSTYLE_BENCH_SWAP=1|0, MIDSTYLE_BENCH_OUT=<abs json>, MIDSTYLE_BENCH_FRAMES=<per segment>
const MidstyleSwap = preload("res://raid/scripts/midstyle_swap.gd")
## segment: [player eye, player look, close eye, close look] (global), same cameras as the capture.
const SEGMENTS := {
	"tailor": [Vector3(-25.55, 1.62, -4.35), Vector3(-28.6, 1.30, -4.0), Vector3(-27.05, 1.58, -3.25), Vector3(-28.6, 1.42, -4.0)],
	"rook": [Vector3(30.0, 1.62, 32.4), Vector3(30.0, 1.15, 34.5), Vector3(30.75, 1.56, 33.5), Vector3(31.2, 1.17, 34.45)],
	"reception": [Vector3(0.6, 1.86, -17.6), Vector3(0.0, 0.95, -22.0), Vector3(1.9, 1.80, -19.9), Vector3(0.0, 0.85, -22.0)],
}
const WARMUP := 20

func _ready() -> void:
	get_tree().create_timer(3000).timeout.connect(func(): get_tree().quit(3))
	call_deferred("run")

func run() -> void:
	var swap := OS.get_environment("MIDSTYLE_BENCH_SWAP") != "0"
	var out := OS.get_environment("MIDSTYLE_BENCH_OUT")
	var frames := int(OS.get_environment("MIDSTYLE_BENCH_FRAMES")) if OS.get_environment("MIDSTYLE_BENCH_FRAMES") != "" else 120
	get_tree().root.size = Vector2i(1280, 800)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	MidstyleSwap.enabled = false
	var world: Node = load("res://raid/ship_settlement_preview.tscn").instantiate()
	if not world.bind_legacy_continue() or not world.request_town_hall_login():
		print("BENCH BREAK login"); get_tree().quit(1); return
	world.staged_startup = true
	world.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(world)
	while not world.world_initialized: await get_tree().process_frame
	var assets: Dictionary = await world.startup_asset_gate.prepare(world)
	if not assets.get("ok", false):
		print("BENCH BREAK assets"); get_tree().quit(1); return
	world.activate_loaded_world()
	get_tree().current_scene = world
	for i in 30: await get_tree().process_frame
	if is_instance_valid(world.get("player")):
		world.player.visible = false; world.player.enabled = false
	for child in world.get_children():
		if child is CanvasLayer or child is Control: child.visible = false
	var swap_result := {}
	if swap: swap_result = MidstyleSwap.apply(world)
	var cam := Camera3D.new(); cam.fov = 60.0; cam.near = 0.05; cam.far = 600
	world.add_child(cam); cam.current = true
	var report := {"swap": swap, "frames_per_segment": frames, "resolution": [1280, 800], "segments": {}, "swap_result": swap_result}
	var all_ms: Array[float] = []
	for seg in SEGMENTS:
		var s: Array = SEGMENTS[seg]
		var ms: Array[float] = []
		var last := 0
		for i in WARMUP + frames:
			var t := clampf(float(i - WARMUP) / float(frames - 1), 0.0, 1.0)
			cam.global_position = (s[0] as Vector3).lerp(s[2], t)
			cam.look_at((s[1] as Vector3).lerp(s[3], t))
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			if i >= WARMUP and last > 0: ms.append((now - last) / 1000.0)
			last = now
		# draw calls / primitives at the close view (last frame of the segment)
		var info := {
			"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)}
		report.segments[seg] = _stats(ms).merged(info)
		all_ms.append_array(ms)
	report["all"] = _stats(all_ms)
	print("BENCH RESULT ", JSON.stringify(report))
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE); f.store_string(JSON.stringify(report, "  ")); f.close()
	get_tree().quit(0)

func _stats(ms: Array[float]) -> Dictionary:
	var sorted := ms.duplicate(); sorted.sort()
	var n := sorted.size(); var total := 0.0
	for v in sorted: total += v
	var k := maxi(1, int(ceil(n * 0.01)))
	var worst := 0.0
	for i in k: worst += sorted[n - 1 - i]
	return {"frames": n, "avg_ms": total / n, "one_pct_low_ms": worst / k, "median_ms": sorted[n / 2]}
