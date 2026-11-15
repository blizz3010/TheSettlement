extends Node
## Test-only camera-matched captures of the inn lake and the hills around it
## (TASKS item 10). Does not change gameplay. Writes PNGs plus a JSON dump of
## the scenery meshes that overlap the lake ellipse.

const Lake := preload("res://scripts/inn_lake_v088.gd")

# World meters. The inn rear deck is at y=3.38, so a standing eye is ~5.0 m.
const SHOTS := [
	{"name": "inn_deck_lake", "origin": Vector3(0.0, 5.05, 61.6), "look": Vector3(20.0, 3.0, 130.0), "note": "Player on the inn's rear deck, looking out over the lake"},
	{"name": "inn_deck_west", "origin": Vector3(-6.0, 5.05, 61.6), "look": Vector3(-70.0, 6.0, 115.0), "note": "Inn deck, looking north-west along the west shore"},
	{"name": "inn_deck_east", "origin": Vector3(8.0, 5.05, 61.6), "look": Vector3(100.0, 6.0, 105.0), "note": "Inn deck, looking north-east along the east shore"},
	{"name": "old_lake_view", "origin": Vector3(0.0, 5.85, 62.0), "look": Vector3(20.0, 2.0, 110.0), "note": "Same view as the earlier screens_fixed/05_lake_by_inn shot"},
	{"name": "high_over_lake", "origin": Vector3(10.0, 42.0, 18.0), "look": Vector3(20.0, 0.0, 120.0), "note": "High oblique from above the settlement toward the lake"},
	{"name": "elevated_plaza_market", "origin": Vector3(2.0, 16.0, -10.0), "look": Vector3(8.0, 1.2, 14.0), "note": "The existing elevated overview, lake and mountain wall behind the inn"}
]

var journal: Dictionary = {"notes": [], "screenshots": [], "scenery": [], "ok": false}
var out_dir := ""
var tag := ""

func log_line(msg: String) -> void:
	print("LAKE: ", msg)
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

func screenshot(world: Node3D, shot: Dictionary) -> void:
	var old = world.get_node_or_null("InnLakeCaptureCamera")
	if old:
		old.free()
	var cam := Camera3D.new()
	cam.name = "InnLakeCaptureCamera"
	cam.fov = 76.0
	cam.near = 0.05
	cam.far = 4000.0
	world.add_child(cam)
	cam.global_position = shot.origin
	cam.look_at(shot.look, Vector3.UP)
	cam.current = true
	for i in 10:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var path := "%s/%s_%s.png" % [out_dir, tag, shot.name]
	img.save_png(path)
	journal["screenshots"].append({"path": path, "note": shot.note})
	log_line("shot " + path)

func material_info(m) -> String:
	if m == null:
		return "none"
	if m is ShaderMaterial:
		return "Shader:" + (m.shader.resource_path if m.shader else "?")
	if m is StandardMaterial3D:
		return "Standard cull=%d transp=%d" % [m.cull_mode, m.transparency]
	return m.get_class()

func dump_scenery(world: Node3D) -> void:
	for node in world.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = null
		if node is MeshInstance3D:
			mesh = node.mesh
		if mesh == null:
			continue
		var faces := mesh.get_faces()
		if faces.size() > 600000:
			continue
		var inside := 0
		var inside_above := 0
		var max_y_inside := -INF
		var aabb: AABB = node.global_transform * mesh.get_aabb()
		if aabb.end.z < 50.0 or aabb.position.y > 400.0:
			continue
		for v in faces:
			var p: Vector3 = node.global_transform * v
			if Lake.lake_distance(Vector2(p.x, p.z)) < 1.0:
				inside += 1
				if p.y > Lake.WATER_Y:
					inside_above += 1
				max_y_inside = maxf(max_y_inside, p.y)
		if inside == 0:
			continue
		journal["scenery"].append({"path": str(world.get_path_to(node)), "visible": node.is_visible_in_tree(), "material": material_info(node.material_override), "surface_mat": material_info(mesh.surface_get_material(0)), "vis_range": [node.visibility_range_begin, node.visibility_range_end], "verts": faces.size(), "inside_lake": inside, "inside_above_water": inside_above, "max_y_inside": max_y_inside, "aabb": str(aabb)})

func run() -> void:
	tag = OS.get_environment("INN_LAKE_TAG").strip_edges()
	out_dir = OS.get_environment("INN_LAKE_OUT").strip_edges()
	if tag == "" or out_dir == "":
		push_error("INN_LAKE_TAG and INN_LAKE_OUT required")
		get_tree().quit(2)
		return
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
	world.activate_loaded_world()
	get_tree().current_scene = world
	for i in 30:
		await get_tree().process_frame
	hide_overlays(world)
	journal["lake_meta"] = str(world.get_meta("inn_lake_v088", {}))
	journal["fix_meta"] = str(world.get_meta("inn_lake_mountain_fix", {}))
	dump_scenery(world)
	log_line("scenery overlapping lake: %d meshes" % journal["scenery"].size())
	var only := OS.get_environment("INN_LAKE_SHOTS").strip_edges()
	for shot in SHOTS:
		if only != "" and not str(shot.name) in only.split(","):
			continue
		await screenshot(world, shot)
	journal["ok"] = true
	write_journal()
	log_line("done")
	get_tree().quit(0)
