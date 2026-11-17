extends SceneTree
## Manual rendered capture for gear as raid loot (TASKS item 22, gear PR F; not in the suite).
## Relay Ridge cache with found tiered gear + a composite insert, the haul, extraction and
## downed screens, the settlement return into the gear locker, Psy's tabs, and lit close-ups
## of the new composite insert model. Writes user:// files, so use a disposable XDG profile:
## XDG_DATA_HOME=/tmp/x xvfb-run -a godot --rendering-driver opengl3 --path . --script res://raid/tests/gear_loot_capture.gd
## Env GEAR_OUT=<abs dir> (default raid/screenshots/gear_loot). Timings: llvmpipe, relative only.
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const Store = preload("res://raid/scripts/gear_tiers/gear_locker_store.gd")
const Install = preload("res://raid/scripts/gear_tiers/gear_shop_install.gd")
const LootInstall = preload("res://raid/scripts/raid_loot/raid_loot_install.gd")
const Outcome = preload("res://raid/scripts/raid_outcome.gd")
const ShopTransaction = preload("res://scripts/shop_transaction.gd")
var scene
var cam: Camera3D
var out := ""

class FakePlayer:
	extends Node3D
	var enabled := true
	var velocity := Vector3.ZERO

class FakeHost:
	extends Node
	var state = preload("res://scripts/plot_state.gd").new()
	var inventory = preload("res://scripts/inventory_state.gd").new()
	var request = preload("res://scripts/request_state.gd").new()
	var craft = preload("res://scripts/craft_state.gd").new()
	var onboarding = preload("res://scripts/onboarding_state.gd").new()
	var fishing = preload("res://scripts/fishing_state.gd").new()
	var player
	var supplies_panel: Control
	var trader_previews
	var cooking_window_focused := true
	func key_label(_a): return "E"
	func modal_open(_a = true, _b = true, _c = true) -> bool: return false
	var character_save_path := "user://gear_loot_shots/character_save.json"
	func save_payload(_p: Dictionary, _n := true, _w = null) -> bool: return true

class ShotController:
	extends "res://raid/scripts/gear_tiers/psy_gear_controller_ext.gd"
	func accessible(_id: String) -> bool: return true
	func active() -> bool: return true

func _initialize():
	call_deferred("run")

func shot(name: String):
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("GEAR_SHOT ", name)

func caption(layer: CanvasLayer, text: String) -> Label:
	var bar := ColorRect.new()
	bar.color = Color(0.07, 0.1, 0.09, 0.86)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -40
	layer.add_child(bar)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color("f2ead8"))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 18
	bar.add_child(label)
	return label

func select_first(ctl, wanted: String = "") -> void:
	var id := wanted
	if id.is_empty():
		for r in ctl.tier_panel.rows:
			if r.get("enabled", false): id = str(r.id); break
	if not id.is_empty(): ctl.tier_panel._select_item(id)


func seed_kit(tier: int) -> void:
	var store = Store.new(); store.path = Store.DEFAULT_PATH
	for slot in Defs.SLOTS: store.state.equip(store.state.grant(Defs.item_id(slot, tier)))
	store.save()

func wipe_locker():
	for f in [Store.DEFAULT_PATH, Store.DEFAULT_PATH + ".tmp"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

func target(id: String) -> Dictionary:
	for t in scene.targets:
		if t.kind == "cache" and t.poi.id == id: return t
	return {}

func frame_ms(frames: int) -> float:
	var t := Time.get_ticks_usec()
	for i in frames: await process_frame
	return (Time.get_ticks_usec() - t) / 1000.0 / frames

func open_map(path: String, poi: String):
	scene = load(path).instantiate()
	root.add_child(scene)
	while not scene.is_raid_ready(): await process_frame
	scene.return_requested.connect(func(): pass)
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	scene.health_controller.set_physics_process(false)
	var t := target(poi)
	scene.raid_state.unlocked[poi] = true
	scene._open_door(poi)
	var cp: Vector3 = t.node.global_position
	var view := cp + Vector3(2.2, 0, 2.6)
	scene.player.position = view
	cam = Camera3D.new(); cam.fov = 70; cam.far = 500; scene.add_child(cam); cam.current = true
	cam.global_position = view + Vector3(0, 1.62, 0); cam.look_at(cp + Vector3(0, 0.3, 0))
	for i in 20: await process_frame

func close_map():
	scene.queue_free()
	for i in 3: await process_frame

func button(text_or_name: String) -> Button:
	for b in scene.modal_content.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and (b.name == text_or_name or b.text == text_or_name): return b
	return null

const FOUND := {"gear_helmet_t4@80": 1, "gear_body_armor_t3@60": 1, "composite_insert": 1}

func run():
	out = OS.get_environment("GEAR_OUT").strip_edges()
	if out.is_empty(): out = ProjectSettings.globalize_path("res://raid/screenshots/gear_loot")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	var timing := {}
	wipe_locker()
	await open_map("res://raid/relay_ridge.tscn", "relay")
	timing["pouch_only_empty_ms"] = snappedf(await frame_ms(60), 0.01)
	var t := target("relay")
	var rs = scene.raid_state
	rs.search_cache(t.poi)
	rs.cache_contents["relay"] = {"metal": 3, "salvage_survey_drive": 1, "salvage_power_cell": 1}
	rs.cache_supplies["relay"] = {}
	rs.cache_gear["relay"] = FOUND.duplicate()
	scene._cache_panel(t)
	await shot("01_relay_tower_cache_t4_and_insert")
	for id in ["gear_helmet_t4_c80", "composite_insert", "salvage_power_cell", "salvage_survey_drive"]:
		var b := button("Loot_" + id)
		if b != null and not b.disabled: b.pressed.emit()
		await process_frame
	rs.take_from_cache("relay", "metal", 1)
	scene._cache_panel(t)
	await shot("02_vest_needs_3_units_2_free")
	rs.take_from_cache("relay", "metal", 2)
	scene._close_modal()
	scene._process(0.016)
	timing["pouch_found_gear_haul_ms"] = snappedf(await frame_ms(60), 0.01)
	await shot("03_hud_haul_with_found_gear")
	scene._haul_panel()
	await shot("04_manage_haul_found_gear")
	rs.extracted_at = "extract1"
	Outcome.last = {}
	scene._extraction_complete()
	await shot("05_extraction_summary_found_gear")
	var outcome: Dictionary = Outcome.peek().duplicate(true)
	await close_map()
	# T3 kit at Cinder Basin's Obsidian Archive: bigger haul, downed with found gear.
	seed_kit(3)
	await open_map("res://raid/cinder_basin.tscn", "obsidian")
	t = target("obsidian")
	rs = scene.raid_state
	rs.search_cache(t.poi)
	rs.cache_contents["obsidian"] = {"metal": 4, "salvage_research_core": 1}
	rs.cache_supplies["obsidian"] = {}
	rs.cache_gear["obsidian"] = {"gear_backpack_t4@75": 1, "gear_visor_t3@55": 1}
	rs.take_all("obsidian")
	scene._haul_changed()
	scene._process(0.016)
	timing["t3_kit_found_gear_haul_ms"] = snappedf(await frame_ms(60), 0.01)
	Outcome.last = {}
	var h = scene.health_controller.health
	h.invulnerable_left = 0.0
	h.damage(500.0, "sentry turret")
	for i in 4: await process_frame
	await shot("06_downed_found_gear_lost")
	await close_map()
	Outcome.last = {}
	print("GEAR_LOOT_FRAME_MS ", JSON.stringify(timing))
	await psy_shots(outcome)
	await closeups()
	wipe_locker()
	quit()

func psy_shots(outcome: Dictionary):
	wipe_locker()
	var store = Store.new(); store.path = Store.DEFAULT_PATH
	var st = store.state
	st.extractions = 11
	st.shop.stock_iii = true
	for pair in [["helmet", 3], ["body_armor", 2], ["tactical_rig", 2], ["backpack", 3]]:
		st.equip(st.grant(Defs.item_id(pair[0], pair[1])))
	store.save()
	var layer := CanvasLayer.new(); root.add_child(layer)
	var bg := ColorRect.new(); bg.color = Color("26332c"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.add_child(bg)
	var host := FakeHost.new(); layer.add_child(host)
	host.state.credits = 2400
	host.player = FakePlayer.new(); host.add_child(host.player)
	var holder := Control.new(); holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.add_child(holder)
	host.supplies_panel = Control.new(); holder.add_child(host.supplies_panel)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://gear_loot_shots"))
	# Settlement return: the extracted haul from shot 05 goes home.
	outcome["raid_uid"] = "shots-1"
	var note := LootInstall.apply_return(host, outcome)
	print("GEAR_LOOT_RETURN ", note)
	var ctl = ShotController.new()
	ctl.host = host
	ctl.listings_transactions = ShopTransaction.new()
	ctl.recovery_transactions = ShopTransaction.new()
	host.trader_previews = ctl
	Install._attach_panel(host, ctl)
	var cap := caption(layer, "")
	ctl.open("psy")
	ctl.tier_panel._change_tab("equip")
	var found_helm := ""
	var worn_helm := ""
	for id in ctl.gear_store.state.owned:
		var r: Dictionary = ctl.gear_store.state.owned[id]
		if r.def == "gear_helmet_t4": found_helm = id
		if r.def == "gear_helmet_t3": worn_helm = id
	select_first(ctl, found_helm)
	cap.text = "Back home · the found T4 Crestline Helm (80%) and the composite insert are in the gear locker"
	await shot("07_psy_equip_found_t4_helmet")
	ctl.tier_panel._change_tab("repair")
	select_first(ctl, found_helm)
	cap.text = "Repair tab · the found T4 Crestline Helm came home at 80% durability"
	await shot("08_psy_repair_found_gear")
	ctl.tier_panel._change_tab("upgrade")
	select_first(ctl, worn_helm)
	cap.text = "Upgrade tab · T3 -> T4 is open: the composite insert from the Relay Tower cache is in the locker"
	await shot("09_psy_upgrade_t3_to_t4_with_found_insert")
	ctl.tier_panel._change_tab("buy")
	select_first(ctl, Defs.item_id("visor", 4))
	cap.text = "Buy tab · T4 rows point at quality 4-5 raid caches or Psy's rotating listing"
	await shot("10_psy_t4_row_raid_loot_reason")
	ctl.close()
	ctl.free()
	layer.queue_free()
	await process_frame

func closeups():
	root.size = Vector2i(1440, 900)
	var vp := SubViewport.new(); vp.size = Vector2i(1440, 900); vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X; vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var stage := Node3D.new(); vp.add_child(stage)
	var we := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color("1c2422")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color("b8c2c0"); e.ambient_light_energy = 0.25
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC; e.glow_enabled = true; e.glow_intensity = 0.2; e.glow_hdr_threshold = 1.5
	we.environment = e; stage.add_child(we)
	var key := DirectionalLight3D.new(); key.light_energy = 0.9; key.light_color = Color("fff1dc"); key.shadow_enabled = true
	key.rotation_degrees = Vector3(-40, -30, 0); stage.add_child(key)
	var rim := OmniLight3D.new(); rim.light_color = Color("ffb27a"); rim.light_energy = 0.45; rim.omni_range = 1.6; rim.position = Vector3(-0.3, 0.35, 0.3); stage.add_child(rim)
	var fill := OmniLight3D.new(); fill.light_color = Color("c9d4ff"); fill.light_energy = 0.25; fill.omni_range = 1.8; fill.position = Vector3(0.35, 0.2, -0.4); stage.add_child(fill)
	var dome := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 6.0; sm.height = 12.0; sm.flip_faces = true; dome.mesh = sm
	var dm := StandardMaterial3D.new(); dm.albedo_color = Color("1c2422"); dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; dome.material_override = dm; stage.add_child(dome)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(2, 2); floor.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color("1a1f1d"); fm.roughness = 0.9; floor.material_override = fm; stage.add_child(floor)
	var model: Node3D = load("res://raid/assets/gear_parts/composite_insert.glb").instantiate()
	stage.add_child(model)
	var tris := 0
	for m in model.find_children("*", "MeshInstance3D", true, false):
		for s in m.mesh.get_surface_count(): tris += m.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
	var cam3 := Camera3D.new(); cam3.fov = 34; cam3.near = 0.01; cam3.environment = e; stage.add_child(cam3); cam3.current = true
	# glTF: the strike face (Blender -Y) faces +Z in Godot.
	for s in [["11_composite_insert_closeup_front_label", Vector3(0.20, 0.30, 0.50), Vector3(0.0, 0.17, 0.0)],
			["12_composite_insert_closeup_back_label_pad", Vector3(-0.28, 0.22, -0.42), Vector3(0.0, 0.14, 0.0)],
			["13_composite_insert_closeup_grommet_edge", Vector3(0.20, 0.10, 0.20), Vector3(0.09, 0.04, 0.0)]]:
		cam3.position = s[1]; cam3.look_at(s[2])
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out.path_join(s[0] + ".png"))
		print("GEAR_SHOT ", s[0])
	var t0 := Time.get_ticks_usec()
	for i in 60: await process_frame
	print("GEAR_PART_CLOSEUP ", JSON.stringify({"tris_imported": tris, "frame_ms": snappedf((Time.get_ticks_usec() - t0) / 1000.0 / 60.0, 0.01)}))
	vp.queue_free()
	await process_frame
