extends Node
## Test-only survey and camera-matched screenshots of the settlement.
## Does not change gameplay. Uses ship_settlement_preview so the later style
## test hook is visible on the same path as the raid adapter.

const BEFORE := "/workspace/settlement_visuals/before"
const AFTER := "/workspace/settlement_visuals/style_test"
const JOURNAL := "/workspace/settlement_visuals/survey_journal.json"
const MODE := "after"  # before | after

# Repeatable cameras. Origins are world meters. Player-height shots use ~1.65 m.
const SHOTS := [
	{"name": "plaza_from_spawn", "origin": Vector3(6.0, 1.65, 11.0), "look": Vector3(0.4, 1.15, -1.0), "elevated": false, "note": "Spawn view toward the fountain and plaza"},
	{"name": "west_trader_and_hideout", "origin": Vector3(-1.5, 1.65, 3.5), "look": Vector3(-16.0, 2.6, 13.0), "elevated": false, "note": "West trader grounds and the approach to the hideout terrace"},
	{"name": "hideout_terrace", "origin": Vector3(-10.4, 2.55, 15.0), "look": Vector3(-24.0, 3.6, 15.0), "elevated": false, "note": "From the hideout stairs onto the empty build turf"},
	{"name": "trader_row", "origin": Vector3(16.0, 1.65, 10.0), "look": Vector3(24.0, 2.2, 16.0), "elevated": false, "note": "Market row: Psy, Atlas and Dan"},
	{"name": "rook_and_north", "origin": Vector3(18.0, 1.65, 30.0), "look": Vector3(28.0, 2.0, 34.0), "elevated": false, "note": "Rook's Supplies and the north market edge"},
	{"name": "hall_and_ship", "origin": Vector3(8.0, 1.65, -8.0), "look": Vector3(20.0, 2.4, -16.0), "elevated": false, "note": "Town Hall side and the launch pad ship"},
	{"name": "elevated_plaza_market", "origin": Vector3(2.0, 16.0, -10.0), "look": Vector3(8.0, 1.2, 14.0), "elevated": true, "note": "Elevated overview of plaza, market and hideout"},
	{"name": "elevated_hideout", "origin": Vector3(-6.0, 14.0, 4.0), "look": Vector3(-20.0, 2.5, 16.0), "elevated": true, "note": "Elevated overview of the hideout terrace and west grounds"},
	{"name": "hideout_west_face", "origin": Vector3(-41.0, 2.9, 9.5), "look": Vector3(-32.0, 1.5, 16.0), "elevated": false, "note": "Player height west of the hideout, looking at the west retaining face"},
	{"name": "hideout_north_face", "origin": Vector3(-21.0, 2.05, 31.0), "look": Vector3(-25.0, 1.5, 23.0), "elevated": false, "note": "Player height north of the hideout, looking at the north retaining face"},
	{"name": "elevated_hideout_nw", "origin": Vector3(-44.0, 14.0, 34.0), "look": Vector3(-24.0, 1.5, 15.0), "elevated": true, "note": "Elevated view of the hideout west and north faces"},
	{"name": "c2_west_ground_elev", "origin": Vector3(-2.0, 16.0, -16.0), "look": Vector3(-18.0, 0.0, 0.0), "elevated": true, "note": "Chunk 2: west unused ground and paved route, elevated"},
	{"name": "c2_west_ground", "origin": Vector3(-4.0, 1.55, -10.0), "look": Vector3(-18.0, 1.0, 2.0), "elevated": false, "note": "Chunk 2: west unused ground, player height"},
	{"name": "c2_far_west_elev", "origin": Vector3(-22.0, 18.0, -26.0), "look": Vector3(-36.0, 1.0, -4.0), "elevated": true, "note": "Chunk 2: far-west mound, elevated"},
	{"name": "c2_far_west", "origin": Vector3(-24.0, 1.55, -2.0), "look": Vector3(-38.0, 3.0, -10.0), "elevated": false, "note": "Chunk 2: far-west mound, player height"},
	{"name": "c2_northwest_elev", "origin": Vector3(-6.0, 16.0, 16.0), "look": Vector3(-20.0, 0.0, 30.0), "elevated": true, "note": "Chunk 2: ground north of the hideout, elevated"},
	{"name": "c2_northwest", "origin": Vector3(-10.0, 1.55, 22.0), "look": Vector3(-22.0, 1.2, 30.0), "elevated": false, "note": "Chunk 2: ground north of the hideout, player height"},
	{"name": "c2_west_mound", "origin": Vector3(-37.0, 4.2, -12.0), "look": Vector3(-44.0, 3.2, -3.0), "elevated": false, "note": "Chunk 2: west mound, player height"}
]

var journal: Dictionary = {"notes": [], "screenshots": [], "coverage": {}, "meshes": [], "ok": false}

func log_line(msg: String) -> void:
	print("VISUALS: ", msg)
	journal["notes"].append({"t": Time.get_ticks_msec(), "msg": msg})
	write_journal()

func write_journal() -> void:
	var f := FileAccess.open(JOURNAL, FileAccess.WRITE)
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
	# Named HUD / prompt nodes that may not be CanvasLayers.
	for path in ["HUD", "SettlementHUD", "Prompt", "PromptPanel", "prompt_panel"]:
		var n = world.get_node_or_null(path)
		if n:
			n.visible = false
	var prompt = world.get("prompt_panel")
	if prompt is CanvasItem or prompt is CanvasLayer:
		prompt.visible = false
	var hud = world.get("settlement_hud")
	if hud is CanvasItem or hud is CanvasLayer or hud is Node:
		if hud.has_method("hide"):
			hud.hide()
		elif "visible" in hud:
			hud.visible = false

func place_camera(world: Node3D, origin: Vector3, look: Vector3) -> Camera3D:
	var existing = world.get_node_or_null("VisualsSurveyCamera")
	if existing:
		existing.queue_free()
	var cam := Camera3D.new()
	cam.name = "VisualsSurveyCamera"
	cam.fov = 70.0
	cam.near = 0.12
	cam.far = 400.0
	world.add_child(cam)
	cam.global_position = origin
	cam.look_at(look, Vector3.UP)
	cam.current = true
	return cam

func screenshot(world: Node3D, folder: String, shot: Dictionary, tag: String) -> String:
	place_camera(world, shot.origin, shot.look)
	for i in 8:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	await get_tree().process_frame
	var tex: ViewportTexture = get_viewport().get_texture()
	if tex == null:
		log_line("no viewport texture for " + str(shot.name))
		return ""
	var img: Image = tex.get_image()
	if img == null:
		log_line("no image for " + str(shot.name))
		return ""
	DirAccess.make_dir_recursive_absolute(folder)
	var path := "%s/%s_%s.png" % [folder, tag, shot.name]
	img.save_png(path)
	var rec := {"path": path, "name": shot.name, "tag": tag, "origin": [shot.origin.x, shot.origin.y, shot.origin.z], "look": [shot.look.x, shot.look.y, shot.look.z], "elevated": shot.elevated, "note": shot.note, "bytes": FileAccess.get_file_as_bytes(path).size()}
	journal["screenshots"].append(rec)
	log_line("shot " + path + " (" + str(rec.bytes) + " bytes) — " + shot.note)
	return path

func classify(node: Node) -> String:
	var hay := (str(node.name) + " " + str(node.get_path())).to_lower()
	if "lawn" in hay or "continuousgrass" in hay or "grass_" in hay or "ground_grass" in hay or hay.ends_with("grass") or "/grass" in hay or "coverage" in hay and "grass" in hay:
		return "grass"
	if "tree" in hay or "broadleaf" in hay or "canopy" in hay or "trunk" in hay:
		return "tree"
	if "shrub" in hay or "bush" in hay or "mound" in hay:
		return "shrub"
	if "flower" in hay or "blossom" in hay or "clover" in hay:
		return "flower"
	if "fern" in hay or "plant" in hay:
		return "plant"
	if "rock" in hay or "pebble" in hay or "stone" in hay and ("ground" in hay or "garden" in hay or "planting" in hay):
		return "rock"
	if "bench" in hay or "lantern" in hay or "lamp" in hay or "planter" in hay or "pot" in hay or "prop" in hay:
		return "dressing"
	return "other"

func count_instances(node: Node) -> int:
	if node is MultiMeshInstance3D and node.multimesh:
		var visible = node.multimesh.visible_instance_count
		if visible >= 0:
			return visible
		return node.multimesh.instance_count
	return 1

func mesh_triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var total := 0
	for i in mesh.get_surface_count():
		var arr = mesh.surface_get_arrays(i)
		var indices = arr[Mesh.ARRAY_INDEX] if arr.size() > Mesh.ARRAY_INDEX else null
		if indices:
			total += indices.size() / 3
		else:
			var verts = arr[Mesh.ARRAY_VERTEX]
			if verts:
				total += verts.size() / 3
	return total

func origin_of(node: Node3D) -> Vector3:
	if node is MultiMeshInstance3D and node.multimesh and node.multimesh.instance_count > 0:
		var acc := Vector3.ZERO
		var n: int = mini(node.multimesh.instance_count, 24)
		for i in n:
			acc += (node.global_transform * node.multimesh.get_instance_transform(i)).origin
		return acc / float(n)
	return node.global_position

func survey_coverage(world: Node3D) -> Dictionary:
	var roots := {}
	var kinds := {}
	var cells := {}
	var named := {}
	var mesh_use := {}
	for node in world.find_children("*", "GeometryInstance3D", true, false):
		if not (node is MeshInstance3D or node is MultiMeshInstance3D):
			continue
		if not node.visible:
			continue
		var kind := classify(node)
		var ninst := count_instances(node)
		kinds[kind] = int(kinds.get(kind, 0)) + ninst
		var p := origin_of(node)
		# Skip far/high sky/dome clutter for the ground coverage map.
		if p.y > 12.0 or Vector2(p.x, p.z).length() > 70.0:
			continue
		var cx := int(floor(p.x / 8.0))
		var cz := int(floor(p.z / 8.0))
		var key := "%d,%d" % [cx, cz]
		if not cells.has(key):
			cells[key] = {"x0": cx * 8, "z0": cz * 8, "grass": 0, "tree": 0, "shrub": 0, "flower": 0, "plant": 0, "rock": 0, "dressing": 0, "other": 0, "total": 0}
		cells[key][kind] = int(cells[key].get(kind, 0)) + ninst
		cells[key]["total"] = int(cells[key]["total"]) + ninst
		var parent_name := str(node.get_parent().name) if node.get_parent() else ""
		# Climb to a named system root when possible.
		var walk: Node = node
		var system := ""
		while walk and walk != world:
			var nm := str(walk.name)
			if nm in ["SouthernGroundcover", "WalkwayPlanting", "ContinuousGrass", "NaturalBorder", "ReferenceFoliage", "RaisedHideoutTerrace", "FourAreaGardens", "MarketExpansion", "ParkHall", "PathShoulderGardens", "MarketEdgeGardens", "HallEastSpurGardens", "PlazaIslandLandscape", "IntentionalPlantingPockets", "ApprovedGardensV086", "RouteGardens", "ParkWestVisuals", "ParkLayeredVisuals", "ValleyBackdrop", "RuinedValley", "SettlementInnExpansion", "LaunchpadShip"]:
				system = nm
				break
			walk = walk.get_parent()
		if system == "":
			system = parent_name
		if not roots.has(system):
			roots[system] = {"nodes": 0, "instances": 0, "kinds": {}}
		roots[system]["nodes"] = int(roots[system]["nodes"]) + 1
		roots[system]["instances"] = int(roots[system]["instances"]) + ninst
		roots[system]["kinds"][kind] = int(roots[system]["kinds"].get(kind, 0)) + ninst
		var mesh: Mesh = null
		if node is MeshInstance3D:
			mesh = node.mesh
		elif node is MultiMeshInstance3D and node.multimesh:
			mesh = node.multimesh.mesh
		if mesh:
			var mid := mesh.resource_path if mesh.resource_path != "" else str(mesh)
			if not mesh_use.has(mid):
				mesh_use[mid] = {"path": mid, "triangles": mesh_triangles(mesh), "instances": 0, "kind": kind, "name": str(node.name)}
			mesh_use[mid]["instances"] = int(mesh_use[mid]["instances"]) + ninst
	# Interesting named nodes for the coverage writeup.
	for child in world.get_children():
		named[str(child.name)] = true
	var coverage := {
		"kinds": kinds,
		"systems": roots,
		"cells": cells,
		"top_nodes": named.keys()
	}
	journal["coverage"] = coverage
	var meshes: Array = mesh_use.values()
	meshes.sort_custom(func(a, b): return int(a["triangles"]) < int(b["triangles"]))
	journal["meshes"] = meshes
	return coverage

func print_coverage(coverage: Dictionary) -> void:
	log_line("kind totals: " + str(coverage.get("kinds", {})))
	log_line("systems:")
	var systems: Dictionary = coverage.get("systems", {})
	var names: Array = systems.keys()
	names.sort()
	for nm in names:
		var s = systems[nm]
		if int(s.get("instances", 0)) < 3:
			continue
		log_line("  %s nodes=%s inst=%s kinds=%s" % [nm, s.nodes, s.instances, s.kinds])
	log_line("sparse 8m cells (trees+shrubs+plants+flowers+dressing < 8, not empty other-only):")
	var cells: Dictionary = coverage.get("cells", {})
	var keys: Array = cells.keys()
	keys.sort()
	for key in keys:
		var c = cells[key]
		var dressed: int = int(c.tree) + int(c.shrub) + int(c.flower) + int(c.plant) + int(c.dressing)
		var in_core: bool = bool(c.x0 >= -40 and c.x0 < 48 and c.z0 >= -40 and c.z0 < 56)
		if in_core and dressed < 8:
			log_line("  cell(%d..%d, %d..%d) dressed=%d grass=%d other=%d trees=%d shrubs=%d flowers=%d plants=%d dressing=%d" % [c.x0, c.x0 + 8, c.z0, c.z0 + 8, dressed, c.grass, c.other, c.tree, c.shrub, c.flower, c.plant, c.dressing])

func run() -> void:
	get_tree().root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	DirAccess.make_dir_recursive_absolute(BEFORE)
	DirAccess.make_dir_recursive_absolute(AFTER)
	log_line("boot ship_settlement_preview")
	var packed: PackedScene = load("res://raid/ship_settlement_preview.tscn")
	if packed == null:
		log_line("BREAK missing ship_settlement_preview.tscn")
		write_journal()
		get_tree().quit(1)
		return
	var world: Node = packed.instantiate()
	if not world.bind_legacy_continue():
		log_line("BREAK bind_legacy_continue failed")
		get_tree().quit(1)
		return
	if not world.request_town_hall_login():
		log_line("BREAK request_town_hall_login failed")
		get_tree().quit(1)
		return
	world.staged_startup = true
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.loading_stage.connect(func(stage, ms): print("VISUALS: stage %s (%.1f ms)" % [str(stage), float(ms)]))
	world.tree_exiting.connect(func(): log_line("world tree_exiting cancel=%s initialized=%s phase=%s" % [str(world.startup_cancel_requested), str(world.world_initialized), str(world.startup_phase)]))
	get_tree().root.add_child(world)
	# Host scene stays current until activation so title-like startup is stable.
	var deadline := Time.get_ticks_msec() + 300000
	var last_pulse := 0
	while is_instance_valid(world) and not world.world_initialized:
		if Time.get_ticks_msec() - last_pulse > 5000:
			last_pulse = Time.get_ticks_msec()
			log_line("still initializing, valid=%s cancel=%s" % [str(is_instance_valid(world)), str(world.startup_cancel_requested) if is_instance_valid(world) else "?"])
		if Time.get_ticks_msec() > deadline:
			log_line("BREAK world did not initialize")
			write_journal()
			get_tree().quit(1)
			return
		await get_tree().process_frame
	if not is_instance_valid(world):
		log_line("BREAK world lost during init")
		get_tree().quit(1)
		return
	log_line("world_initialized, preparing assets")
	var assets_result: Dictionary = await world.startup_asset_gate.prepare(world)
	if not assets_result.get("ok", false):
		log_line("BREAK assets: " + str(assets_result.get("reason", assets_result)))
		journal["assets_result"] = assets_result
		write_journal()
		get_tree().quit(1)
		return
	world.activate_loaded_world()
	get_tree().current_scene = world
	# Let after-activation gardens finish a few frames.
	for i in 30:
		await get_tree().process_frame
	if "cooking_window_focused" in world and not world.cooking_window_focused:
		world.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	hide_overlays(world)
	log_line("activated; surveying")
	var coverage := survey_coverage(world)
	print_coverage(coverage)
	var tag := MODE
	var folder := BEFORE if MODE == "before" else AFTER
	# After mode relies on ship_settlement_preview applying the style test during activation.
	if MODE == "after":
		var patch_root = world.get_node_or_null("SettlementVisualsStyleTest")
		log_line("style test present=" + str(patch_root != null) + (" budget=" + str(patch_root.get_meta("budget")) if patch_root else ""))
	var only := OS.get_environment("SETTLEMENT_VISUALS_SHOTS").strip_edges()
	var custom_folder := OS.get_environment("SETTLEMENT_VISUALS_AFTER" if tag == "after" else "SETTLEMENT_VISUALS_BEFORE").strip_edges()
	if custom_folder != "":
		folder = custom_folder
		DirAccess.make_dir_recursive_absolute(folder)
	log_line("taking " + tag + " shots into " + folder + (" filter=" + only if only != "" else " (all cameras)"))
	for shot in SHOTS:
		if only != "" and not str(shot.name) in only.split(","):
			continue
		await screenshot(world, folder, shot, tag)
	journal["ok"] = true
	write_journal()
	log_line("done")
	get_tree().quit(0)
