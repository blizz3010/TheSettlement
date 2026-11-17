extends SceneTree
## Salvage art redo (fix/salvage-art-midpoly; not in the suite). Re-renders the redone salvage
## icons with the item 16 trader icon renderer into res://raid/assets/trader_icons/<id>.png,
## then takes lit close-ups of the sealed survey drive into raid/screenshots/salvage_art/.
## Needs a display (Xvfb): xvfb-run -a godot --rendering-driver opengl3 --path . --script res://raid/tests/salvage_art_capture.gd
## Env SALVAGE_IDS=comma list (default: the three redone pieces). Timings: llvmpipe, relative only.
const Renderer = preload("res://raid/scripts/trader_icon_renderer.gd")
const REDONE := ["salvage_survey_drive", "salvage_research_core", "salvage_sensor"]

func _initialize():
	_run.call_deferred()

func _run():
	var ids: Array = REDONE
	var env := OS.get_environment("SALVAGE_IDS").strip_edges()
	if not env.is_empty(): ids = env.split(",")
	var r = Renderer.new(); root.add_child(r)
	await process_frame
	var dir := ProjectSettings.globalize_path("res://raid/assets/trader_icons")
	if OS.get_environment("SALVAGE_SKIP_ICONS") == "1": ids = []
	for id in ids:
		var t := Time.get_ticks_usec()
		var img: Image = await r.render(str(id))
		var err := img.save_png(dir.path_join(str(id) + ".png"))
		print("SALVAGE_ICON ", id, " err=", err, " size=", img.get_size(), " ms=", (Time.get_ticks_usec() - t) / 1000)
	r.queue_free()
	await process_frame
	await closeups()
	quit(0)

func closeups():
	var out := ProjectSettings.globalize_path("res://raid/screenshots/salvage_art")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	# Own-world SubViewport (same approach as the icon renderer) so the project clear colour
	# and root world never leak into the lighting.
	var vp := SubViewport.new(); vp.size = Vector2i(1440, 900); vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X; vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var stage := Node3D.new(); vp.add_child(stage)
	var we := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color("1c2422")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color("b8c2c0"); e.ambient_light_energy = 0.22
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC; e.glow_enabled = true; e.glow_intensity = 0.25; e.glow_hdr_threshold = 1.5
	we.environment = e; stage.add_child(we)
	var key := DirectionalLight3D.new(); key.light_energy = 0.85; key.light_color = Color("fff1dc"); key.shadow_enabled = true
	key.rotation_degrees = Vector3(-48, -35, 0); stage.add_child(key)
	var rim := OmniLight3D.new(); rim.light_color = Color("7fd6d0"); rim.light_energy = 0.35; rim.omni_range = 1.2; rim.position = Vector3(-0.25, 0.18, -0.25); stage.add_child(rim)
	var fill := OmniLight3D.new(); fill.light_color = Color("c9d4ff"); fill.light_energy = 0.2; fill.omni_range = 1.5; fill.position = Vector3(0.3, 0.12, 0.35); stage.add_child(fill)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(2, 2); floor.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color("1a1f1d"); fm.roughness = 0.9; floor.material_override = fm; stage.add_child(floor)
	var model: Node3D = load("res://raid/assets/salvage/salvage_survey_drive.glb").instantiate()
	stage.add_child(model)
	var tris := 0
	for m in model.find_children("*", "MeshInstance3D", true, false):
		for s in m.mesh.get_surface_count(): tris += m.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
	var cam := Camera3D.new(); cam.fov = 32; cam.near = 0.01; cam.environment = e; stage.add_child(cam); cam.current = true
	for shot in [["survey_drive_closeup_label_led", Vector3(0.17, 0.16, 0.20), Vector3(0.0, 0.02, 0.0)],
			["survey_drive_closeup_port_screws", Vector3(0.24, 0.07, -0.06), Vector3(0.06, 0.018, 0.0)]]:
		cam.position = shot[1]; cam.look_at(shot[2])
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out.path_join(shot[0] + ".png"))
		print("SALVAGE_SHOT ", shot[0])
	var t := Time.get_ticks_usec()
	for i in 60: await process_frame
	print("SALVAGE_CLOSEUP ", JSON.stringify({"tris_imported": tris, "frame_ms": snappedf((Time.get_ticks_usec() - t) / 1000.0 / 60.0, 0.01)}))
	vp.queue_free()
	await process_frame
