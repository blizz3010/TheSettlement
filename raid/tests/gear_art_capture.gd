extends SceneTree
## Manual rendered capture for gear art E0 (TASKS item 22; not in the suite): the T3 Warden
## Helm + T3 Bulwark Carrier on the select screen, Psy's equip-tab mannequin, raid loot rows
## and HUD, studio before/after against the PR A placeholder, close-ups, and frame times.
## Writes user://gear_locker.json, so use a disposable XDG profile:
## XDG_DATA_HOME=/tmp/x xvfb-run -a godot --rendering-driver opengl3 --path . --script res://raid/tests/gear_art_capture.gd
## Env GEAR_OUT=<abs dir> (default raid/screenshots/gear_art_e0), GEAR_PART=ui|studio (default both),
## GEAR_TIER=1|3 (which art set is worn, default 3 = E0), GEAR_FMT=jpg (review JPEGs at q88, else PNG).
## Third person in the settlement: gear_art_settlement_capture.gd. Timings: llvmpipe, relative only.
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const Store = preload("res://raid/scripts/gear_tiers/gear_locker_store.gd")
const Install = preload("res://raid/scripts/gear_tiers/gear_shop_install.gd")
const GearArt = preload("res://raid/scripts/gear_tiers/gear_art.gd")
const Placeholder = preload("res://raid/scripts/gear_tiers/gear_placeholder_art.gd")
const ShopTransaction = preload("res://scripts/shop_transaction.gd")
const DefaultOutfit = preload("res://raid/scripts/outfit/default_outfit.gd")
const GearAvatar = preload("res://raid/scripts/gear_tiers/gear_avatar.gd")
var TIER := 3
var HELM := "gear_helmet_t3"
var VEST := "gear_body_armor_t3"
var WAVE := "E0"
var out := ""
var scene
var timing := {}

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
	var character_save_path := "user://gear_art_shots/character_save.json"
	func save_payload(_p: Dictionary, _n := true, _w = null) -> bool: return true

class ShotController:
	extends "res://raid/scripts/gear_tiers/psy_gear_controller_ext.gd"
	func accessible(_id: String) -> bool: return true
	func active() -> bool: return true

func _initialize():
	call_deferred("run")

func shot(name: String, tex: Texture2D = null):
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	save_img((tex if tex != null else root.get_texture()).get_image(), name)

## Committed review shots: JPEG q88 when GEAR_FMT=jpg (from E1-A on), PNG otherwise.
func save_img(img: Image, name: String):
	if OS.get_environment("GEAR_FMT") == "jpg":
		img.convert(Image.FORMAT_RGB8); img.save_jpg(out.path_join(name + ".jpg"), 0.88)
	else:
		img.save_png(out.path_join(name + ".png"))
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

func frame_ms(frames: int) -> float:
	var t := Time.get_ticks_usec()
	for i in frames: await process_frame
	return snappedf((Time.get_ticks_usec() - t) / 1000.0 / frames, 0.01)

func wipe_locker():
	for f in [Store.DEFAULT_PATH, Store.DEFAULT_PATH + ".tmp"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

## Tier-N kit worn; only the helmet and vest have art (E0 = T3, E1-A = T1).
func seed_t3():
	wipe_locker()
	var store = Store.new(); store.path = Store.DEFAULT_PATH
	var st = store.state
	st.extractions = 8
	st.shop.stock_iii = true
	for slot in ["helmet", "body_armor", "tactical_rig", "backpack", "gloves", "boots"]:
		st.equip(st.grant(Defs.item_id(slot, TIER)))
	st.grant(Defs.item_id("body_armor", 2))
	st.grant(Defs.item_id("helmet", 2))
	store.save()

func run():
	var tier_env := OS.get_environment("GEAR_TIER").strip_edges()
	if tier_env != "": TIER = int(tier_env)
	HELM = "gear_helmet_t%d" % TIER; VEST = "gear_body_armor_t%d" % TIER
	WAVE = "E0" if TIER == 3 else "E1-A"
	out = OS.get_environment("GEAR_OUT").strip_edges()
	if out.is_empty(): out = ProjectSettings.globalize_path("res://raid/screenshots/gear_art_e0")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	var part := OS.get_environment("GEAR_PART").strip_edges()
	if part in ["", "ui"]:
		await select_shots()
		await psy_shots()
		await raid_shots()
	if part in ["", "studio"]:
		await studio_shots()
	print("GEAR_ART_FRAME_MS ", JSON.stringify(timing))
	wipe_locker()
	quit()

# ------------------------------------------------------------------ select screen
func open_select() -> Node:
	var title = (load("res://raid/play_title.tscn") as PackedScene).instantiate()
	root.add_child(title); current_scene = title
	for i in 10: await process_frame
	title.play_button.pressed.emit()
	for i in 10: await process_frame
	var panel = title.character_panel
	if is_instance_valid(panel) and panel.cards.has("slot_1"):
		panel.cards["slot_1"].pressed.emit()
	await create_timer(1.5).timeout
	return title

func close_select(title):
	title.queue_free(); current_scene = null
	for i in 4: await process_frame

func seed_settler():
	var Session = load("res://scripts/character_profiles/title_session.gd")
	var Rules = load("res://scripts/character_profiles/experimental_rules.gd")
	var session = Session.new(); session.rules = Rules.data()
	var state = session.inspect()
	if state.screen == "create":
		var r = session.create_character("slot_1", {"name":"Settler","cheek":0.0,"hair":"hair_short02_v1","brows":"brow_009_v1","eyes":"eye_brown_v1","hair_tint":"natural"}, {"str":7,"int":7,"dex":7}, [], state.bytes, false)
		session.cancel()
		print("GEAR_SEED settler ", r.get("ok", false))

func select_shots():
	seed_settler()
	wipe_locker()
	var title = await open_select()
	await shot("02_before_select_screen_no_art")
	await close_select(title)
	seed_t3()
	title = await open_select()
	var stage = title.character_panel.preview
	print("GEAR_SELECT worn ", stage.worn_gear)
	timing["select_screen_ms"] = await frame_ms(30)
	await shot("01_select_screen_t%d_helm_vest" % TIER)
	await close_select(title)

# ------------------------------------------------------------------ Psy equip tab ("inventory")
func psy_shots():
	seed_t3()
	var layer := CanvasLayer.new(); root.add_child(layer)
	var bg := ColorRect.new(); bg.color = Color("26332c"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.add_child(bg)
	var host := FakeHost.new(); layer.add_child(host)
	host.state.credits = 2400
	host.player = FakePlayer.new(); host.add_child(host.player)
	var holder := Control.new(); holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.add_child(holder)
	host.supplies_panel = Control.new(); holder.add_child(host.supplies_panel)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://gear_art_shots"))
	var ctl = ShotController.new()
	ctl.host = host
	ctl.listings_transactions = ShopTransaction.new()
	ctl.recovery_transactions = ShopTransaction.new()
	host.trader_previews = ctl
	Install._attach_panel(host, ctl)
	var cap := caption(layer, "")
	ctl.open("psy")
	ctl.tier_panel._change_tab("equip")
	var ids := {}
	for id in ctl.gear_store.state.owned: ids[ctl.gear_store.state.owned[id].def] = id
	ctl.tier_panel._select_item(ids[VEST])
	cap.text = "Equip tab · worn %s + %s on the locker mannequin (LOD1); rendered icons in the rows" % [str(Defs.item(HELM).get("name", HELM)), str(Defs.item(VEST).get("name", VEST))]
	for i in 6: await process_frame
	await shot("03_inventory_psy_equip_mannequin")
	ctl.tier_panel._select_item(ids[Defs.item_id("body_armor", 2)])
	cap.text = "Equip tab · trying on the T2 vest: no art yet, so the mannequin drops the vest and its row keeps the tier chip"
	for i in 6: await process_frame
	await shot("04_inventory_psy_tryon_t2_fallback")
	ctl.close()
	ctl.free()
	layer.queue_free()
	for i in 3: await process_frame

# ------------------------------------------------------------------ raid loot rows + HUD
func target(id: String) -> Dictionary:
	for t in scene.targets:
		if t.kind == "cache" and t.poi.id == id: return t
	return {}

func button(text_or_name: String) -> Button:
	for b in scene.modal_content.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and (b.name == text_or_name or b.text == text_or_name): return b
	return null

func raid_shots():
	wipe_locker()
	scene = load("res://raid/relay_ridge.tscn").instantiate()
	root.add_child(scene)
	while not scene.is_raid_ready(): await process_frame
	scene.return_requested.connect(func(): pass)
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	scene.health_controller.set_physics_process(false)
	var t := target("relay")
	scene.raid_state.unlocked["relay"] = true
	scene._open_door("relay")
	var cp: Vector3 = t.node.global_position
	var view := cp + Vector3(2.2, 0, 2.6)
	scene.player.position = view
	var cam := Camera3D.new(); cam.fov = 70; cam.far = 500; scene.add_child(cam); cam.current = true
	cam.global_position = view + Vector3(0, 1.62, 0); cam.look_at(cp + Vector3(0, 0.3, 0))
	for i in 20: await process_frame
	var rs = scene.raid_state
	rs.search_cache(t.poi)
	rs.cache_contents["relay"] = {"metal": 2, "salvage_power_cell": 1}
	rs.cache_supplies["relay"] = {}
	rs.cache_gear["relay"] = {HELM + "@85": 1, VEST + "@60": 1, "gear_helmet_t4@80": 1}
	scene._cache_panel(t)
	await shot("06_raid_cache_rows_icons")
	for id in [HELM + "_c85", "salvage_power_cell"]:
		var b := button("Loot_" + id)
		if b != null and not b.disabled: b.pressed.emit()
		await process_frame
	scene._close_modal()
	scene._process(0.016)
	timing["raid_hud_ms"] = await frame_ms(60)
	await shot("07_raid_hud_haul_found_t%d" % TIER)
	scene._haul_panel()
	await shot("05_inventory_raid_manage_haul_icons")
	scene.queue_free()
	for i in 3: await process_frame

# ------------------------------------------------------------------ studio
var stage: Node3D
var cam3: Camera3D

func studio() -> void:
	# Root viewport (a SubViewport readback double-applies sRGB on the opengl3 driver here).
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new(); root.add_child(stage)
	var we := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color("1c2422")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color("b8c2c0"); e.ambient_light_energy = 0.3
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = e; stage.add_child(we)
	var key := DirectionalLight3D.new(); key.light_energy = 0.8; key.light_color = Color("fff4e8"); key.shadow_enabled = true
	key.rotation_degrees = Vector3(-35, -30, 0); stage.add_child(key)
	var rim := DirectionalLight3D.new(); rim.light_color = Color("ffd9bd"); rim.light_energy = 0.5; rim.rotation_degrees = Vector3(-15, 150, 0); stage.add_child(rim)
	var fill := DirectionalLight3D.new(); fill.light_color = Color("c9d4ff"); fill.light_energy = 0.3; fill.rotation_degrees = Vector3(-5, 60, 0); stage.add_child(fill)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(8, 8); floor.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color("232a27"); fm.roughness = 0.9; floor.material_override = fm; stage.add_child(floor)
	cam3 = Camera3D.new(); cam3.fov = 30; cam3.near = 0.01; stage.add_child(cam3); cam3.current = true

func rig_at(x: float) -> Skeleton3D:
	var rig: Node3D = (load("res://models/Appearance-Proof.glb") as PackedScene).instantiate()
	stage.add_child(rig); rig.position.x = x
	for n in ["hair_bob01_v1", "brow_001_v1", "eye_blue_v1"]:
		var m := rig.find_child(n, true, false)
		if m is Node3D: m.visible = false
	var body := rig.find_child("ProofBody", true, false) as MeshInstance3D
	if body != null:
		for si in body.mesh.get_surface_count():
			var m := body.get_active_material(si) as BaseMaterial3D
			if m == null: continue
			var t := m.duplicate() as BaseMaterial3D
			t.albedo_color = t.albedo_color * Color(0.66, 0.54, 0.46)
			body.set_surface_override_material(si, t)
	var sk := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	# Gear is worn over the default outfit (raid/scripts/outfit/default_outfit.gd).
	DefaultOutfit.dress(sk, DefaultOutfit.ORDER, 0, body)
	return sk

var labels: CanvasLayer

## Big top-left / top-right panel labels (shot 14: which side is the old placeholder).
func label_pair(left: String, right: String):
	if labels != null: labels.queue_free(); labels = null
	if left == "" and right == "": return
	labels = CanvasLayer.new(); root.add_child(labels)
	for pr in [[left, 0.0], [right, 0.5]]:
		if pr[0] == "": continue
		var bar := ColorRect.new(); bar.color = Color(0.07, 0.1, 0.09, 0.82)
		bar.position = Vector2(1440 * pr[1] + 24, 20); bar.size = Vector2(560, 44); labels.add_child(bar)
		var l := Label.new(); l.text = pr[0]
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", Color("ffb36b") if str(pr[0]).begins_with("OLD") else Color("bff0c8"))
		l.position = Vector2(12, 6); bar.add_child(l)

func view(name: String, pos: Vector3, look: Vector3, fov: float = 30.0):
	cam3.fov = fov; cam3.position = pos; cam3.look_at(look)
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	save_img(root.get_texture().get_image(), name)

func studio_shots():
	await studio()
	# Before / after: PR A primitive placeholders vs the wave's art, same rig, same light.
	var left := rig_at(-0.45)
	var right := rig_at(0.45)
	for pair in [[HELM, Vector3(0, 1.49, -0.01)], [VEST, Vector3(0, 1.18, 0.0)]]:
		var ph := Placeholder.build(pair[0]); stage.add_child(ph); ph.position = Vector3(-0.45, 0, 0) + pair[1]
	GearArt.show_worn(right, [HELM, VEST], 0)
	label_pair("OLD · PR A primitive placeholder (retired)", "NEW · %s art: %s + %s" % [WAVE, str(Defs.item(HELM).get("name", "")), str(Defs.item(VEST).get("name", ""))])
	await view("14_before_after_placeholder_vs_art", Vector3(0.9, 1.35, 3.1), Vector3(0, 1.05, 0), 32)
	# Rear view: the sides swap on screen.
	label_pair("NEW · %s art (rear)" % WAVE, "OLD · PR A placeholder (rear)")
	await view("14b_before_after_placeholder_vs_art_rear", Vector3(-0.9, 1.35, -3.1), Vector3(0, 1.05, 0), 32)
	label_pair("", "")
	for c in stage.get_children():
		if c is Node3D and not (c is Camera3D or c is DirectionalLight3D or c is WorldEnvironment or c is MeshInstance3D): c.queue_free()
		elif c is Node3D and c.has_meta("placeholder"): c.queue_free()
	await process_frame
	var sk := rig_at(0.0)
	GearArt.show_worn(sk, [HELM, VEST], 0)
	await view("15_closeup_helmet_front", Vector3(0.32, 1.56, 0.62), Vector3(0, 1.46, 0), 28)
	await view("16_closeup_helmet_rear_side", Vector3(-0.5, 1.58, -0.42), Vector3(0, 1.46, 0), 28)
	await view("17_closeup_vest_front", Vector3(0.55, 1.35, 1.15), Vector3(0, 1.16, 0), 30)
	await view("18_closeup_vest_back", Vector3(-0.6, 1.4, -1.1), Vector3(0, 1.16, 0), 30)
	# Fit: the avatar's own walk / sprint cycles with the vest worn (arms over the carrier).
	var av = GearAvatar.new(); av.skeleton = sk; av.worn = [HELM, VEST]
	for pr in [["idle", 0.0, "19a"], ["walk", PI * 0.5, "19b"], ["sprint", PI * 0.5, "19c"], ["sprint", PI * 1.5, "19d"]]:
		av.apply_pose(pr[0], pr[1])
		await view("%s_fit_%s_front" % [pr[2], pr[0]], Vector3(0.7, 1.25, 1.9), Vector3(0, 1.1, 0), 32)
		await view("%s_fit_%s_side" % [pr[2], pr[0]], Vector3(2.0, 1.25, 0.3), Vector3(0, 1.1, 0), 32)
	sk.reset_bone_poses()
	av.free()
	await view("19e_fit_helmet_straps_side", Vector3(0.62, 1.46, 0.12), Vector3(0, 1.43, 0.01), 28)
	cam3.position = Vector3(0.55, 1.35, 1.15); cam3.look_at(Vector3(0, 1.16, 0))
	timing["studio_closeup_with_art_ms"] = await frame_ms(60)
	GearArt.detach_all(sk)
	timing["studio_closeup_rig_outfit_no_gear_ms"] = await frame_ms(60)
	stage.queue_free()
	await process_frame
