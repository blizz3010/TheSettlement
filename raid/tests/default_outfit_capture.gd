extends SceneTree
## Manual rendered capture for the default outfit (not in the suite): select screen, Psy's
## equip-tab mannequin, studio before/after (bare body vs outfit) front / side / back,
## close-ups, walk / sprint poses, the outfit under the T3 gear, and frame times.
## Writes user://gear_locker.json, so use a disposable XDG profile:
## XDG_DATA_HOME=/tmp/x xvfb-run -a godot --rendering-driver opengl3 --path . --script res://raid/tests/default_outfit_capture.gd
## Env OUTFIT_OUT=<abs dir> (default raid/screenshots/default_outfit), OUTFIT_PART=ui|studio (default both).
## Third person in the settlement: default_outfit_settlement_capture.tscn. Timings: llvmpipe, relative only.
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const Store = preload("res://raid/scripts/gear_tiers/gear_locker_store.gd")
const Install = preload("res://raid/scripts/gear_tiers/gear_shop_install.gd")
const GearArt = preload("res://raid/scripts/gear_tiers/gear_art.gd")
const GearAvatar = preload("res://raid/scripts/gear_tiers/gear_avatar.gd")
const DefaultOutfit = preload("res://raid/scripts/outfit/default_outfit.gd")
const ShopTransaction = preload("res://scripts/shop_transaction.gd")
const HELM := "gear_helmet_t3"
const VEST := "gear_body_armor_t3"
var out := ""
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
	(tex if tex != null else root.get_texture()).get_image().save_png(out.path_join(name + ".png"))
	print("OUTFIT_SHOT ", name)

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

## T3 kit worn; only the helmet and vest have art in E0.
func seed_t3():
	wipe_locker()
	var store = Store.new(); store.path = Store.DEFAULT_PATH
	var st = store.state
	st.extractions = 8
	st.shop.stock_iii = true
	for slot in ["helmet", "body_armor", "tactical_rig", "backpack", "gloves", "boots"]:
		st.equip(st.grant(Defs.item_id(slot, 3)))
	st.grant(Defs.item_id("body_armor", 2))
	st.grant(Defs.item_id("helmet", 2))
	store.save()

func run():
	out = OS.get_environment("OUTFIT_OUT").strip_edges()
	if out.is_empty(): out = ProjectSettings.globalize_path("res://raid/screenshots/default_outfit")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	var part := OS.get_environment("OUTFIT_PART").strip_edges()
	if part in ["", "ui"]:
		await select_shots()
		await psy_shots()
	if part in ["", "studio"]:
		await studio_shots()
	print("OUTFIT_FRAME_MS ", JSON.stringify(timing))
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
	var stage = title.character_panel.preview
	print("OUTFIT_SELECT pieces ", DefaultOutfit.pieces_on(stage.skeleton))
	timing["select_screen_outfit_ms"] = await frame_ms(30)
	await shot("01_select_screen_default_outfit")
	await close_select(title)
	seed_t3()
	title = await open_select()
	timing["select_screen_outfit_t3_gear_ms"] = await frame_ms(30)
	await shot("02_select_screen_outfit_under_t3_gear")
	await close_select(title)
	wipe_locker()

func psy_shots():
	for worn in [false, true]:
		if worn: seed_t3()
		else: wipe_locker()
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
		cap.text = "Psy equip tab · locker mannequin in the default outfit (LOD1)" + (" under the worn T3 Warden Helm + Bulwark Carrier" if worn else ", nothing worn")
		for i in 6: await process_frame
		await shot("03_psy_mannequin_default_outfit" if not worn else "04_psy_mannequin_outfit_under_t3")
		ctl.close()
		ctl.free()
		layer.queue_free()
		for i in 3: await process_frame
	wipe_locker()

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
	return rig.find_child("Skeleton3D", true, false) as Skeleton3D

func view(name: String, pos: Vector3, look: Vector3, fov: float = 30.0):
	cam3.fov = fov; cam3.position = pos; cam3.look_at(look)
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("OUTFIT_SHOT ", name)

var labels: CanvasLayer

func label_pair(left: String, right: String):
	if labels != null: labels.queue_free()
	labels = CanvasLayer.new(); root.add_child(labels)
	for pr in [[left, 0.0], [right, 0.5]]:
		if pr[0] == "": continue
		var l := Label.new(); l.text = pr[0]
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color("f2ead8"))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8)); l.add_theme_constant_override("outline_size", 6)
		l.position = Vector2(1440 * pr[1] + 30, 24)
		labels.add_child(l)

func clear_rigs():
	for c in stage.get_children():
		if c is Node3D and c.find_child("Skeleton3D", true, false) != null: c.queue_free()
	await process_frame

func dressed_rig(x: float, lod: int = 0) -> Skeleton3D:
	var sk := rig_at(x)
	DefaultOutfit.dress(sk, DefaultOutfit.ORDER, lod, sk.get_parent().find_child("ProofBody", true, false) as MeshInstance3D)
	return sk

func studio_shots():
	await studio()
	# Before / after: same rig, same light; left bare, right in the default outfit.
	rig_at(-0.45)
	dressed_rig(0.45)
	label_pair("BEFORE · bare Appearance-Proof body", "AFTER · default outfit (shirt, pants, boots)")
	await view("20_before_after_bare_vs_outfit_front", Vector3(0, 1.0, 4.4), Vector3(0, 0.86, 0), 30)
	await view("21_before_after_bare_vs_outfit_side", Vector3(4.4, 1.0, 0.9), Vector3(0, 0.86, 0), 30)
	label_pair("AFTER · default outfit", "BEFORE · bare body")
	await view("22_before_after_bare_vs_outfit_back", Vector3(0, 1.0, -4.4), Vector3(0, 0.86, 0), 30)
	label_pair("", "")
	await clear_rigs()
	var sk := dressed_rig(0.0)
	await view("23_outfit_front", Vector3(0, 0.95, 3.4), Vector3(0, 0.82, 0), 30)
	await view("24_outfit_side", Vector3(3.4, 0.95, 0), Vector3(0, 0.82, 0), 30)
	await view("25_outfit_back", Vector3(0, 0.95, -3.4), Vector3(0, 0.82, 0), 30)
	await view("26_closeup_shirt_henley_pocket", Vector3(0.25, 1.28, 0.95), Vector3(0, 1.12, 0), 30)
	await view("27_closeup_belt_buckle_fly", Vector3(0.2, 0.98, 0.75), Vector3(0, 0.86, 0), 30)
	await view("28_closeup_cargo_pocket_knee", Vector3(0.95, 0.7, 0.55), Vector3(0.12, 0.55, 0), 30)
	await view("29_closeup_boots_front", Vector3(0.35, 0.42, 0.85), Vector3(0, 0.1, 0.03), 30)
	await view("30_closeup_boots_side_back", Vector3(0.75, 0.38, -0.6), Vector3(0.12, 0.1, 0), 30)
	cam3.position = Vector3(0, 0.95, 3.4); cam3.look_at(Vector3(0, 0.82, 0))
	timing["studio_full_body_outfit_lod0_ms"] = await frame_ms(60)
	cam3.position = Vector3(0.25, 1.28, 0.95); cam3.look_at(Vector3(0, 1.12, 0))
	timing["studio_closeup_outfit_lod0_ms"] = await frame_ms(60)
	# Poses (the third-person avatar's own cycles), side and 3/4 views.
	var av = GearAvatar.new(); av.skeleton = sk
	for pr in [["walk", PI * 0.5, "31"], ["sprint", PI * 0.5, "32"], ["sprint", PI * 1.5, "33"]]:
		av.apply_pose(pr[0], pr[1])
		await view("%s_pose_%s_side" % [pr[2], pr[0]], Vector3(3.2, 1.0, 0.6), Vector3(0, 0.8, 0), 30)
		await view("%s_pose_%s_threequarter" % [pr[2], pr[0]], Vector3(-2.0, 1.1, 2.6), Vector3(0, 0.8, 0), 30)
	sk.reset_bone_poses()
	av.free()
	# Outfit under the T3 gear (E0 helmet + vest).
	GearArt.show_worn(sk, [HELM, VEST], 0)
	await view("34_outfit_under_t3_gear_front", Vector3(0.9, 1.1, 3.2), Vector3(0, 0.95, 0), 30)
	await view("35_outfit_under_t3_gear_back", Vector3(-0.9, 1.1, -3.2), Vector3(0, 0.95, 0), 30)
	GearArt.detach_all(sk)
	# Frame-time comparison at the same full-body framing: bare, LOD0, LOD1.
	cam3.position = Vector3(0, 0.95, 3.4); cam3.look_at(Vector3(0, 0.82, 0))
	DefaultOutfit.undress(sk, sk.get_parent().find_child("ProofBody", true, false) as MeshInstance3D)
	await process_frame
	timing["studio_full_body_bare_ms"] = await frame_ms(60)
	cam3.position = Vector3(0.25, 1.28, 0.95); cam3.look_at(Vector3(0, 1.12, 0))
	timing["studio_closeup_bare_ms"] = await frame_ms(60)
	DefaultOutfit.dress(sk, DefaultOutfit.ORDER, 1, sk.get_parent().find_child("ProofBody", true, false) as MeshInstance3D)
	cam3.position = Vector3(0, 0.95, 3.4); cam3.look_at(Vector3(0, 0.82, 0))
	timing["studio_full_body_outfit_lod1_ms"] = await frame_ms(60)
	stage.queue_free()
	await process_frame
