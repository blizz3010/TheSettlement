extends Node
## Item 11 props-only frame-time bench (manual, not part of the suite).
## Instances only the three midstyle props (no settlement) under one shadowed sun and flies a
## fixed, frame-indexed orbit, so prop cost is not drowned by the 16M-primitive world.
## Env: MIDSTYLE_ISO_EXT=.gltf|.glb, MIDSTYLE_ISO_OUT=<abs json>, MIDSTYLE_ISO_FRAMES=<n>
const PROPS := ["tailor_dress_form", "rook_counter_stock", "hall_reception_desk"]
const OFFSETS := [Vector3(-2.2, 0, 1.35), Vector3(0.6, -0.6, 1.5), Vector3(0.6, 0, -1.2)]
const WARMUP := 30

func _ready() -> void:
	get_tree().create_timer(900).timeout.connect(func(): get_tree().quit(3))
	call_deferred("run")

func run() -> void:
	var ext := OS.get_environment("MIDSTYLE_ISO_EXT") if OS.get_environment("MIDSTYLE_ISO_EXT") != "" else ".gltf"
	var out := OS.get_environment("MIDSTYLE_ISO_OUT")
	var frames := int(OS.get_environment("MIDSTYLE_ISO_FRAMES")) if OS.get_environment("MIDSTYLE_ISO_FRAMES") != "" else 300
	get_tree().root.size = Vector2i(1280, 800)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var root := Node3D.new(); add_child(root)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.5, 0.55, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.shadow_enabled = true; sun.rotation_degrees = Vector3(-50, 35, 0); root.add_child(sun)
	var floor_mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(12, 12); floor_mi.mesh = pm; root.add_child(floor_mi)
	var tris := {}
	for i in PROPS.size():
		var ps: PackedScene = load("res://assets/midstyle_test/%s%s" % [PROPS[i], ext])
		var n: Node3D = ps.instantiate(); n.position = OFFSETS[i]; root.add_child(n)
		tris[PROPS[i]] = _tris(n)
	var cam := Camera3D.new(); cam.fov = 60.0; root.add_child(cam); cam.current = true
	var ms: Array[float] = []; var last := 0; var info := {}
	for i in WARMUP + frames:
		var a := TAU * float(max(i - WARMUP, 0)) / float(frames)
		cam.position = Vector3(sin(a) * 4.2, 1.6, cos(a) * 4.2); cam.look_at(Vector3(0, 0.9, 0))
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if i >= WARMUP and last > 0: ms.append((now - last) / 1000.0)
		last = now
		if i == WARMUP:
			info = {"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)}
	var sorted := ms.duplicate(); sorted.sort(); var total := 0.0
	for v in sorted: total += v
	var k := maxi(1, int(ceil(sorted.size() * 0.01))); var worst := 0.0
	for j in k: worst += sorted[sorted.size() - 1 - j]
	var report := {"ext": ext, "frames": sorted.size(), "avg_ms": total / sorted.size(), "median_ms": sorted[sorted.size() / 2],
		"one_pct_low_ms": worst / k, "tris": tris, "first_frame": info}
	print("ISO RESULT ", JSON.stringify(report))
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE); f.store_string(JSON.stringify(report, "  ")); f.close()
	get_tree().quit(0)

func _tris(n: Node) -> Dictionary:
	var t := 0; var surf := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null: continue
		for s in m.get_surface_count():
			surf += 1
			var arr := m.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			t += (idx.size() / 3) if idx != null and idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX].size() / 3)
	return {"triangles": t, "surfaces": surf}
