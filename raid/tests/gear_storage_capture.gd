extends SceneTree
## Manual rendered capture for rig/backpack raid storage (TASKS item 22, PR D; not in the suite).
## Relay Ridge with a seeded T3 kit (haul 21, 2 quick slots), then Psy's shop text.
## Writes user://gear_locker.json, so run with a disposable XDG profile:
## XDG_DATA_HOME=/tmp/x xvfb-run -a godot --rendering-driver opengl3 --path . --script res://raid/tests/gear_storage_capture.gd
## Env GEAR_OUT=<abs dir> (default raid/screenshots/gear_storage). Timings: llvmpipe, relative only.
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const Store = preload("res://raid/scripts/gear_tiers/gear_locker_store.gd")
const Install = preload("res://raid/scripts/gear_tiers/gear_shop_install.gd")
const ShopTransaction = preload("res://scripts/shop_transaction.gd")
const Storage = preload("res://raid/scripts/gear_tiers/gear_storage.gd")
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


func seed_kit(tier: int, downs: int = 0) -> void:
	var store = Store.new(); store.path = Store.DEFAULT_PATH
	for slot in Defs.SLOTS: store.state.equip(store.state.grant(Defs.item_id(slot, tier)))
	for i in downs: store.state.apply_downed()
	store.save()

func target(id: String) -> Dictionary:
	for t in scene.targets:
		if t.kind == "cache" and t.poi.id == id: return t
	return {}

func frame_ms(frames: int) -> float:
	var t := Time.get_ticks_usec()
	for i in frames: await process_frame
	return (Time.get_ticks_usec() - t) / 1000.0 / frames

func open_relay():
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
	cam = Camera3D.new(); cam.fov = 70; cam.far = 500; scene.add_child(cam); cam.current = true
	cam.global_position = view + Vector3(0, 1.62, 0); cam.look_at(cp + Vector3(0, 0.3, 0))
	for i in 20: await process_frame

func close_relay():
	scene.queue_free()
	for i in 3: await process_frame

func run():
	out = OS.get_environment("GEAR_OUT").strip_edges()
	if out.is_empty(): out = ProjectSettings.globalize_path("res://raid/screenshots/gear_storage")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	var timing := {}
	# Pouch only (empty locker) for the frame-time baseline and the no-rig cache row.
	if FileAccess.file_exists(Store.DEFAULT_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.DEFAULT_PATH))
	await open_relay()
	timing["pouch_only_ms"] = snappedf(await frame_ms(60), 0.01)
	var t := target("relay")
	scene.raid_state.search_cache(t.poi)
	scene.raid_state.cache_supplies["relay"] = {"field_dressing": 1}
	var h = scene.health_controller.health
	h.invulnerable_left = 0.0; h.damage(35.0, "unknown")
	scene._cache_panel(t)
	await shot("07_no_rig_use_now")
	await close_relay()
	# T3 kit: pouch 8 + rig 4 + pack 9, 2 quick slots.
	seed_kit(3)
	await open_relay()
	scene._process(0.016)
	timing["t3_kit_empty_ms"] = snappedf(await frame_ms(60), 0.01)
	await shot("01_t3_kit_hud_storage")
	t = target("relay")
	scene.raid_state.search_cache(t.poi)
	scene.raid_state.cache_contents["relay"] = {"stone": 6, "metal": 9, "salvage_capacitor": 2, "salvage_survey_drive": 1, "salvage_power_cell": 1, "timber": 4}
	scene.raid_state.cache_supplies["relay"] = {"field_dressing": 2}
	scene._cache_panel(t)
	await shot("02_cache_with_dressings")
	for b in scene.modal_content.find_children("*", "Button", true, false):
		if b.text == "Take all that fits": b.pressed.emit(); break
	for i in 2:
		for b in scene.modal_content.find_children("*", "Button", true, false):
			if b.name == "Stow_field_dressing" and not b.disabled: b.pressed.emit(); break
	await shot("03_cache_after_take_all_and_stow")
	scene._close_modal()
	scene._process(0.016)
	scene.toast.text = ""
	timing["t3_kit_full_haul_ms"] = snappedf(await frame_ms(60), 0.01)
	await shot("04_full_haul_load_hud")
	h = scene.health_controller.health
	h.invulnerable_left = 0.0; h.damage(45.0, "unknown")
	var ev := InputEventKey.new(); ev.pressed = true; ev.physical_keycode = KEY_1
	scene._unhandled_input(ev)
	scene._process(0.016)
	await shot("05_quick_use_key_1")
	scene._field_notes()
	await shot("06_field_notes_storage")
	print("GEAR_STORAGE_HUD ", scene.gear.hud_label.text.replace("\n", " | "))
	print("GEAR_STORAGE_STATUS ", scene.status.text.get_slice("\n", 2))
	await close_relay()
	# Worn kit after three downed raids: rig and pack torn.
	seed_kit(3, 3)
	await open_relay()
	scene._process(0.016)
	await shot("08_torn_rig_pack_after_3_downs")
	await close_relay()
	print("GEAR_STORAGE_FRAME_MS ", JSON.stringify(timing))
	await psy_shots()
	if FileAccess.file_exists(Store.DEFAULT_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.DEFAULT_PATH))
	quit()

func psy_shots():
	var store = Store.new(); store.path = Store.DEFAULT_PATH
	var st = store.state
	st.extractions = 6
	st.shop.stock_iii = true
	for pair in [["helmet", 2], ["body_armor", 2], ["tactical_rig", 2], ["backpack", 3], ["boots", 1]]:
		st.equip(st.grant(Defs.item_id(pair[0], pair[1])))
	store.save()
	var layer := CanvasLayer.new(); root.add_child(layer)
	var bg := ColorRect.new(); bg.color = Color("26332c"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.add_child(bg)
	var host := FakeHost.new(); layer.add_child(host)
	host.state.credits = 1840
	host.player = FakePlayer.new(); host.add_child(host.player)
	var holder := Control.new(); holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.add_child(holder)
	host.supplies_panel = Control.new(); holder.add_child(host.supplies_panel)
	var ctl = ShotController.new()
	ctl.host = host
	ctl.listings_transactions = ShopTransaction.new()
	ctl.recovery_transactions = ShopTransaction.new()
	host.trader_previews = ctl
	Install._attach_panel(host, ctl)
	var cap := caption(layer, "")
	ctl.open("psy")
	select_first(ctl, Defs.item_id("tactical_rig", 3))
	cap.text = "Psy buy row · Assault Rig: +4 raid haul slots and 2 quick-use slots"
	await shot("09_psy_rig_row")
	select_first(ctl, Defs.item_id("backpack", 4))
	cap.text = "Psy buy row · Expedition Frame: +12 raid haul slots"
	await shot("10_psy_pack_row")
	ctl.tier_panel._change_tab("equip")
	select_first(ctl)
	cap.text = "Equip tab · loadout shows raid haul capacity (pouch 8 + rig 3 + pack 9) and quick-use slots"
	await shot("11_psy_loadout_capacity")
	ctl.close()
	ctl.free()
	layer.queue_free()
	await process_frame
