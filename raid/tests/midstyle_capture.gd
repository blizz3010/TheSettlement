extends Node
## Item 11 style-test capture driver (manual, not part of the suite).
## Loads the preview settlement with the swap disabled, shoots player-height "before"
## views, applies raid/scripts/midstyle_swap.gd, then shoots the same "after" views.
## Run under Xvfb:  godot --rendering-driver opengl3 --path . res://raid/tests/midstyle_capture.tscn
## Env: MIDSTYLE_OUT=<abs dir> (default res://raid/screenshots/item11)
const MidstyleSwap = preload("res://raid/scripts/midstyle_swap.gd")
## name: [eye (global), look-at (global), fov]
const VIEWS := {
	"tailor_player": [Vector3(-25.55, 1.62, -4.35), Vector3(-28.6, 1.30, -4.0), 70.0],
	"tailor_close": [Vector3(-27.05, 1.58, -3.25), Vector3(-28.6, 1.42, -4.0), 50.0],
	"rook_player": [Vector3(30.0, 1.62, 32.4), Vector3(30.0, 1.15, 34.5), 70.0],
	"rook_close": [Vector3(29.6, 1.56, 33.4), Vector3(29.4, 1.17, 34.42), 50.0],
	"rook_ledger": [Vector3(30.75, 1.56, 33.5), Vector3(31.2, 1.17, 34.45), 50.0],
}
var out_dir := ""

func _ready() -> void:
	get_tree().create_timer(1500).timeout.connect(func(): get_tree().quit(3))
	call_deferred("run")

func shoot(world: Node3D, tag: String) -> void:
	for view in VIEWS:
		var spec: Array = VIEWS[view]
		var cam := Camera3D.new(); cam.fov = spec[2]; cam.near = 0.05; cam.far = 600
		world.add_child(cam); cam.global_position = spec[0]; cam.look_at(spec[1]); cam.current = true
		for i in 10: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [view, tag]))
		cam.queue_free()
		print("MIDSTYLE shot ", view, " ", tag)

func run() -> void:
	out_dir = OS.get_environment("MIDSTYLE_OUT").strip_edges()
	if out_dir.is_empty(): out_dir = ProjectSettings.globalize_path("res://raid/screenshots/item11")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	MidstyleSwap.enabled = false
	var world: Node = load("res://raid/ship_settlement_preview.tscn").instantiate()
	if not world.bind_legacy_continue() or not world.request_town_hall_login():
		print("MIDSTYLE BREAK login binding failed"); get_tree().quit(1); return
	world.staged_startup = true
	world.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(world)
	var deadline := Time.get_ticks_msec() + 600000
	while is_instance_valid(world) and not world.world_initialized:
		if Time.get_ticks_msec() > deadline:
			print("MIDSTYLE BREAK world did not initialize"); get_tree().quit(1); return
		await get_tree().process_frame
	var assets: Dictionary = await world.startup_asset_gate.prepare(world)
	if not assets.get("ok", false):
		print("MIDSTYLE BREAK assets ", assets); get_tree().quit(1); return
	world.activate_loaded_world()
	get_tree().current_scene = world
	for i in 30: await get_tree().process_frame
	if is_instance_valid(world.get("player")):
		world.player.visible = false; world.player.enabled = false
	for child in world.get_children():
		if child is CanvasLayer or child is Control: child.visible = false
	var before := {"tailor": _tris(world.get_node("TailorAtelier")), "rook": _tris(world.get_node("RookReferenceArt"))}
	await shoot(world, "before")
	var result := MidstyleSwap.apply(world)
	var after := {"tailor": _tris(world.get_node("TailorAtelier")), "rook": _tris(world.get_node("RookReferenceArt"))}
	print("MIDSTYLE RESULT ", JSON.stringify({"swap": result, "visible_tris_before": before, "visible_tris_after": after}))
	await shoot(world, "after")
	get_tree().quit(0 if result.ok else 2)

func _tris(root: Node) -> int:
	var total := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree(): continue
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var idx = a[Mesh.ARRAY_INDEX]
			total += (idx.size() if idx != null and idx.size() > 0 else a[Mesh.ARRAY_VERTEX].size()) / 3
	return total
