extends Node
## Test-only camera-matched captures of the far scenery (TASKS item 9).
## Shots come from FAR_SHOTS (JSON file path). Writes PNGs, per-shot render
## stats, and a dump of the backdrop nodes beyond the settlement.
## Convention used here: +z = north (inn/lake), +x = east (launch pad).

var journal: Dictionary = {"notes": [], "screenshots": [], "backdrop": [], "ok": false}
var out_dir := ""
var tag := ""

func log_line(msg: String) -> void:
	print("FAR: ", msg)
	journal["notes"].append(msg)
	write_journal()

func write_journal() -> void:
	if out_dir == "":
		return
	var f := FileAccess.open(out_dir + "/journal_" + tag + ".json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(journal, "\t"))
		f.close()

func _ready() -> void:
	call_deferred("run")

func hide_overlays(world: Node) -> void:
	if is_instance_valid(world.get("player")):
		world.player.visible = false
		world.player.enabled = false
	for child in world.get_children():
		if child is CanvasLayer or child is Control:
			child.visible = false
	var hud = world.get("settlement_hud")
	if hud is Node and hud.has_method("hide"):
		hud.hide()

func v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

func screenshot(world: Node3D, shot: Dictionary) -> void:
	var old = world.get_node_or_null("FarCaptureCamera")
	if old:
		old.free()
	var cam := Camera3D.new()
	cam.name = "FarCaptureCamera"
	cam.fov = 76.0
	cam.near = 0.05
	cam.far = 4000.0
	world.add_child(cam)
	cam.global_position = v3(shot.origin)
	cam.look_at(v3(shot.look), Vector3.UP)
	cam.current = true
	for i in 10:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var vp := get_viewport().get_viewport_rid()
	var stats := {
		"primitives": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		"draw_calls": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)}
	var img: Image = get_viewport().get_texture().get_image()
	var path := "%s/%s_%s.png" % [out_dir, tag, shot.name]
	img.save_png(path)
	journal["screenshots"].append({"path": path, "name": shot.name, "note": shot.get("note", ""), "stats": stats})
	log_line("shot %s %s" % [path, str(stats)])

func tri_count(node: Node) -> int:
	var mesh: Mesh = null
	var mult := 1
	if node is MeshInstance3D:
		mesh = node.mesh
	elif node is MultiMeshInstance3D and node.multimesh:
		mesh = node.multimesh.mesh
		mult = node.multimesh.visible_instance_count if node.multimesh.visible_instance_count >= 0 else node.multimesh.instance_count
	if mesh == null:
		return 0
	var t := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var idx = arr[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null and idx.size() > 0 else arr[Mesh.ARRAY_VERTEX].size()) / 3
	return t * mult

func dump_backdrop(world: Node3D) -> void:
	for node in world.find_children("*", "GeometryInstance3D", true, false):
		if not (node is MeshInstance3D or node is MultiMeshInstance3D):
			continue
		var aabb := (node as VisualInstance3D).get_aabb()
		aabb = node.global_transform * aabb
		var far := maxf(maxf(absf(aabb.position.x), absf(aabb.end.x)), maxf(absf(aabb.position.z), absf(aabb.end.z)))
		if far < 70.0:
			continue
		var mat = node.material_override
		var mname := "none"
		if mat is ShaderMaterial and mat.shader:
			mname = mat.shader.resource_path
		elif mat:
			mname = mat.get_class()
		var inst := 1
		if node is MultiMeshInstance3D and node.multimesh:
			inst = node.multimesh.instance_count
		journal["backdrop"].append({"path": str(world.get_path_to(node)), "class": node.get_class(), "visible": node.is_visible_in_tree(), "material": mname, "vis_range": [node.visibility_range_begin, node.visibility_range_end], "instances": inst, "triangles": tri_count(node), "aabb": str(aabb)})

func run() -> void:
	tag = OS.get_environment("FAR_TAG").strip_edges()
	out_dir = OS.get_environment("FAR_OUT").strip_edges()
	var shots_path := OS.get_environment("FAR_SHOTS").strip_edges()
	if tag == "" or out_dir == "" or shots_path == "":
		push_error("FAR_TAG, FAR_OUT and FAR_SHOTS required")
		get_tree().quit(2)
		return
	var shots = JSON.parse_string(FileAccess.get_file_as_string(shots_path))
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	var world: Node = load("res://raid/ship_settlement_preview.tscn").instantiate()
	if not world.bind_legacy_continue() or not world.request_town_hall_login():
		log_line("BREAK login binding failed")
		get_tree().quit(1)
		return
	world.staged_startup = true
	world.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(world)
	var deadline := Time.get_ticks_msec() + 300000
	while is_instance_valid(world) and not world.world_initialized:
		if Time.get_ticks_msec() > deadline:
			log_line("BREAK world did not initialize")
			get_tree().quit(1)
			return
		await get_tree().process_frame
	var assets: Dictionary = await world.startup_asset_gate.prepare(world)
	if not assets.get("ok", false):
		log_line("BREAK assets: " + str(assets))
		get_tree().quit(1)
		return
	var t0 := Time.get_ticks_usec()
	world.activate_loaded_world()
	journal["activate_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	get_tree().current_scene = world
	for i in 30:
		await get_tree().process_frame
	hide_overlays(world)
	journal["far_test_meta"] = str(world.get_meta("far_scenery_test", {}))
	if OS.get_environment("FAR_DUMP") == "1":
		dump_backdrop(world)
		log_line("backdrop nodes beyond 70 m: %d" % journal["backdrop"].size())
	for shot in shots:
		await screenshot(world, shot)
	journal["ok"] = true
	write_journal()
	log_line("done")
	get_tree().quit(0)
