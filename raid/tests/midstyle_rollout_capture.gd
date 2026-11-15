extends Node
## Item 12 rollout capture + in-raid frame-time bench (manual, not part of the suite).
## Loads a raid map with raid/scripts/midstyle_rollout.gd off ("before") or on ("after") and
## either shoots fixed views of the swapped props or flies the same views and records frame times.
## Views are placed relative to the prop art, so before and after use identical cameras.
## Run under Xvfb:  godot --rendering-driver opengl3 --path . res://raid/tests/midstyle_rollout_capture.tscn
## Env: ROLLOUT=0|1, ROLLOUT_MAP=relay_ridge|cinder_basin, ROLLOUT_MODE=capture|bench,
##      ROLLOUT_OUT=<abs dir or json>, ROLLOUT_FRAMES=<frames per view, bench>
const Rollout = preload("res://raid/scripts/midstyle_rollout.gd")
## view: [art node name, selector, eye offset (art-local), look offset (art-local), fov]
const VIEWS := {
	"relay_ridge": {
		"relay_player": ["PuzzleControlArt", 1, Vector3(0.35, 1.62, 2.4), Vector3(0, 1.05, 0), 70.0],
		"relay_close": ["PuzzleControlArt", 1, Vector3(0.75, 1.5, 1.05), Vector3(0, 1.2, 0), 50.0],
		"cache_player": ["CacheArt", 0, Vector3(0.6, 1.62, 2.3), Vector3(0, 0.45, 0), 70.0],
		"cache_close": ["CacheArt", 0, Vector3(1.0, 1.25, 1.25), Vector3(0, 0.55, 0), 50.0],
		"container_intact": ["CargoArt", "container_intact", Vector3(4.6, 1.75, 4.2), Vector3(0, 1.1, 0.8), 70.0],
		"container_dented": ["CargoArt", "container_dented", Vector3(-4.6, 1.75, 4.2), Vector3(0, 1.1, 0.8), 70.0],
	},
	"cinder_basin": {
		"cache_player": ["CacheArt", 0, Vector3(0.6, 1.62, 2.3), Vector3(0, 0.45, 0), 70.0],
		"cache_close": ["CacheArt", 0, Vector3(1.0, 1.25, 1.25), Vector3(0, 0.55, 0), 50.0],
		"stack_large": ["CargoArt", "stack_large", Vector3(-2.7, 1.62, 2.2), Vector3(0, 1.0, 0), 70.0],
		"stack_pallet": ["CargoArt", "stack_pallet", Vector3(2.7, 1.62, 2.2), Vector3(0, 0.75, 0), 70.0],
	},
}
const WARMUP := 20

func _ready() -> void:
	get_tree().create_timer(2400).timeout.connect(func(): get_tree().quit(3))
	call_deferred("run")

func find_art(scene: Node, spec: Array) -> Node3D:
	var arts := scene.find_children(spec[0], "Node3D", true, false)
	if spec[1] is String: arts = arts.filter(func(a): return a.get_meta("cargo_kind", "") == spec[1])
	else: arts = arts.slice(spec[1], spec[1] + 1)
	return arts[0] if not arts.is_empty() else null

func place(cam: Camera3D, art: Node3D, eye: Vector3, look: Vector3) -> void:
	var t := art.global_transform.orthonormalized()
	cam.global_position = t * eye; cam.look_at(t * look)

func run() -> void:
	var on := OS.get_environment("ROLLOUT") == "1"
	var map := OS.get_environment("ROLLOUT_MAP") if OS.get_environment("ROLLOUT_MAP") != "" else "relay_ridge"
	var mode := OS.get_environment("ROLLOUT_MODE") if OS.get_environment("ROLLOUT_MODE") != "" else "capture"
	var out := OS.get_environment("ROLLOUT_OUT")
	var frames := int(OS.get_environment("ROLLOUT_FRAMES")) if OS.get_environment("ROLLOUT_FRAMES") != "" else 60
	var size := Vector2i(1440, 900) if mode == "capture" else Vector2i(1280, 800)
	get_tree().root.size = size; DisplayServer.window_set_size(size)
	if mode == "bench":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps = 0
	Rollout.enabled = on
	var scene: Node = load("res://raid/%s.tscn" % map).instantiate()
	get_tree().root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 120000
	while not scene.is_raid_ready() and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	if not scene.is_raid_ready(): print("ROLLOUT BREAK not ready"); get_tree().quit(1); return
	scene.set_physics_process(false)
	if is_instance_valid(scene.get("player")):
		scene.player.set_physics_process(false); scene.player.visible = false
	for node in scene.find_children("*", "CanvasLayer", true, false): node.visible = false
	for node in scene.find_children("*", "Control", true, false):
		if node.get_parent() == scene: node.visible = false
	var cam := Camera3D.new(); cam.near = 0.05; cam.far = 600; scene.add_child(cam); cam.current = true
	for i in 30: await get_tree().process_frame
	var views: Dictionary = VIEWS[map]
	var report := {"rollout": on, "map": map, "mode": mode, "views": {}}
	var all_ms: Array[float] = []
	for view in views:
		var spec: Array = views[view]
		var art := find_art(scene, spec)
		if art == null: print("ROLLOUT missing art for ", view); report.views[view] = "missing"; continue
		report.views[view] = {"art_scene": art.scene_file_path, "triangles": _tris(art)}
		cam.fov = spec[4]
		if mode == "capture":
			place(cam, art, spec[2], spec[3])
			for i in 6: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s_%s.png" % [map, view, "after" if on else "before"]))
			print("ROLLOUT shot ", map, " ", view)
		else:
			# fly from 1.6x the view distance into the view, frame-indexed (identical in both runs)
			var ms: Array[float] = []; var last := 0
			for i in WARMUP + frames:
				var t := clampf(float(i - WARMUP) / float(frames - 1), 0.0, 1.0)
				place(cam, art, (spec[2] - spec[3]) * lerpf(1.6, 1.0, t) + spec[3], spec[3])
				await RenderingServer.frame_post_draw
				var now := Time.get_ticks_usec()
				if i >= WARMUP and last > 0: ms.append((now - last) / 1000.0)
				last = now
			report.views[view].merge(_stats(ms).merged({
				"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}))
			all_ms.append_array(ms)
	if mode == "bench":
		report["all"] = _stats(all_ms)
		if out != "":
			var f := FileAccess.open(out, FileAccess.WRITE); f.store_string(JSON.stringify(report, "  ")); f.close()
	print("ROLLOUT RESULT ", JSON.stringify(report))
	Rollout.enabled = false
	get_tree().quit(0)

func _stats(ms: Array[float]) -> Dictionary:
	var sorted := ms.duplicate(); sorted.sort()
	var n := sorted.size(); var total := 0.0
	for v in sorted: total += v
	var k := maxi(1, int(ceil(n * 0.01))); var worst := 0.0
	for i in k: worst += sorted[n - 1 - i]
	return {"frames": n, "avg_ms": total / n, "one_pct_low_ms": worst / k, "median_ms": sorted[n / 2]}

func _tris(root: Node) -> int:
	var total := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (node as MeshInstance3D).mesh
		if m == null: continue
		for s in m.get_surface_count():
			var a := m.surface_get_arrays(s); var idx = a[Mesh.ARRAY_INDEX]
			total += (idx.size() if idx != null and idx.size() > 0 else a[Mesh.ARRAY_VERTEX].size()) / 3
	return total
