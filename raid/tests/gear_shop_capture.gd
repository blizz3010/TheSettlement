extends SceneTree
## Manual rendered capture for Psy's tier gear shop (TASKS item 22, PR C; not in the suite).
## Drives the real controller ext + panel with a stand-in host. Writes user://gear_locker.json,
## so run with a disposable XDG profile:
## XDG_DATA_HOME=/tmp/x DISPLAY=:N godot --rendering-driver opengl3 --path . --script res://raid/tests/gear_shop_capture.gd
## Env GEAR_OUT=<abs dir> (default raid/screenshots/gear_shop).
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const Store = preload("res://raid/scripts/gear_tiers/gear_locker_store.gd")
const Install = preload("res://raid/scripts/gear_tiers/gear_shop_install.gd")
const ShopTransaction = preload("res://scripts/shop_transaction.gd")
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

func run():
	out = OS.get_environment("GEAR_OUT").strip_edges()
	if out.is_empty(): out = ProjectSettings.globalize_path("res://raid/screenshots/gear_shop")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	# Seed: 6 extractions, Stock III paid, a mixed loadout, one worn piece, materials carried.
	var store = Store.new(); store.path = Store.DEFAULT_PATH
	var st = store.state
	st.extractions = 6
	st.shop.stock_iii = true
	for pair in [["helmet", 2], ["body_armor", 1], ["jacket", 2], ["boots", 1], ["backpack", 1], ["headset", 1]]:
		st.equip(st.grant(Defs.item_id(pair[0], pair[1])))
	var spare = st.grant(Defs.item_id("gloves", 1))
	st.owned[spare].durability = 6.0
	st.grant(Defs.item_id("pants", 3))
	store.save()
	var layer := CanvasLayer.new(); root.add_child(layer)
	var bg := ColorRect.new(); bg.color = Color("26332c"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.add_child(bg)
	var host := FakeHost.new(); layer.add_child(host)
	host.state.credits = 1840
	host.inventory.carried["metal"] = 3
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
	select_first(ctl, Defs.item_id("helmet", 3))
	cap.text = "Buy · 6 extractions, Stock III paid: T1-T3 stocked, T4 locked until 10 extractions · T0 basic helmet still listed"
	await shot("01_psy_tier_shop_buy")
	ctl.tier_panel._change_tab("upgrade")
	select_first(ctl)
	cap.text = "Upgrade · price difference + 10% + materials (carried metal scrap); T3 -> T4 needs a raid-only composite insert"
	await shot("02_psy_tier_shop_upgrade")
	ctl.tier_panel._change_tab("repair")
	select_first(ctl)
	cap.text = "Repair · 30% of the piece's price scaled by missing durability"
	await shot("03_psy_tier_shop_repair")
	ctl.tier_panel._change_tab("equip")
	select_first(ctl)
	cap.text = "Equip · 11-slot loadout summary; ● marks worn pieces, selecting one unequips it"
	await shot("04_psy_equip_tab")
	ctl.close()
	ctl.free()
	print("GEAR_SHOT done")
	quit()
