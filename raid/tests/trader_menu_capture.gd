extends Node
## Item 16 capture driver: icon contact sheet, before/after menus for all four
## traders, a confirm dialog and an insufficient-funds state.
## Env: TM_OUT (shot dir). Icons are read from res://raid/assets/trader_icons.
## Optional TM_SKIP_ICONS=1 reuses existing PNGs; TM_ONLY=comma ids limits icon renders.
const Renderer = preload("res://raid/scripts/trader_icon_renderer.gd")
const Icons = preload("res://raid/scripts/trader_buy_icons.gd")
const ShopPanel = preload("res://scripts/shop_panel.gd")
const ShopCatalog = preload("res://scripts/shop_catalog.gd")
const SuppliesPanel = preload("res://scripts/supplies_panel.gd")
const ClothingPanel = preload("res://scripts/clothing_panel.gd")
const PreviewPanel = preload("res://scripts/trader_preview_panel.gd")
const FishingPanel = preload("res://scripts/fishing_supply_panel.gd")
const RookPanel = preload("res://raid/scripts/rook_buy_menu_panel.gd")
const TailorPanel = preload("res://raid/scripts/tailor_buy_menu_panel.gd")
const PsyPanel = preload("res://raid/scripts/psy_buy_menu_panel.gd")
const FishBuyPanel = preload("res://raid/scripts/fishing_buy_menu_panel.gd")
const PsyCatalog = preload("res://scripts/psy_gear_catalog.gd")
const TailorCatalog = preload("res://scripts/tailor_catalog.gd")
const FishingCatalog = preload("res://raid/scripts/fishing_supply_catalog_ext.gd")
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Onboarding = preload("res://scripts/onboarding_state.gd")

var out: String
var icon_dir: String

func _ready() -> void:
	out = OS.get_environment("TM_OUT")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://raid/screenshots/trader_menus")
	DirAccess.make_dir_recursive_absolute(out)
	icon_dir = ProjectSettings.globalize_path(Icons.ICON_DIR)
	DirAccess.make_dir_recursive_absolute(icon_dir)
	run.call_deferred()

func run() -> void:
	var ids: Array = Renderer.ITEMS.keys()
	var only := OS.get_environment("TM_ONLY")
	if not only.is_empty():
		ids = Array(only.split(",", false))
	if OS.get_environment("TM_SKIP_ICONS") != "1":
		var r := Renderer.new()
		add_child(r)
		await get_tree().process_frame
		for id in ids:
			var t := Time.get_ticks_msec()
			var img: Image = await r.render(str(id))
			if img == null or img.is_empty():
				print("TM: icon %s FAILED (no image)" % id)
			else:
				var dest := icon_dir.path_join(str(id) + ".png")
				var err := img.save_png(dest)
				print("TM: icon %s err=%d alpha_px=%d %dms" % [id, err, _opaque(img), Time.get_ticks_msec() - t])
		r.queue_free()
		Icons._cache.clear()
	if only.is_empty() or OS.get_environment("TM_SHEET") == "1":
		await contact_sheet()
		await menu_shot("rook", "before", false, "timber")
		await menu_shot("rook", "after", true, "timber")
		await menu_shot("psy", "before", false, "helmet_basic")
		await menu_shot("psy", "after", true, "helmet_basic")
		await menu_shot("tailor", "before", false, "basic_jacket")
		await menu_shot("tailor", "after", true, "basic_jacket")
		await menu_shot("fishing", "before", false, "fishing_pole")
		await menu_shot("fishing", "after", true, "fishing_pole")
		await confirm_shot()
		await funds_shot()
	print("TM: done")
	get_tree().quit()

func _opaque(img: Image) -> int:
	var n := 0
	var d := img.get_data()
	for i in range(3, d.size(), 4):
		if d[i] > 16:
			n += 1
	return n

func _snap(name_: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var e := img.save_png(out.path_join(name_))
	print("TM: shot %s err=%d %s" % [name_, e, str(img.get_size())])

func _tex(id: String) -> Texture2D:
	return Icons.texture(id)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _caption(layer: CanvasLayer, text: String) -> void:
	var tag := Label.new()
	tag.text = text
	tag.add_theme_color_override("font_color", Color("ffd98a"))
	tag.add_theme_font_size_override("font_size", 15)
	tag.position = Vector2(12, 6)
	layer.add_child(tag)

func contact_sheet() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("0f1a17")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var col := VBoxContainer.new()
	col.position = Vector2(24, 14)
	col.add_theme_constant_override("separation", 8)
	layer.add_child(col)
	var theme_ = preload("res://scripts/shop_theme.gd")
	var title := _label("ITEM 16  ·  TRADER MENU ICONS  ·  rendered from in-game models (256 px, thin outline)", 22, Color("d3b47a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_override("font", theme_.heading_font())
	col.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for id in Renderer.ITEMS:
		var spec: Dictionary = Renderer.ITEMS[id]
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override("panel", theme_.frame("182622", "465a4a", 8))
		grid.add_child(cell)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		cell.add_child(v)
		var t := TextureRect.new()
		t.texture = _tex(id)
		t.custom_minimum_size = Vector2(150, 150)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(t)
		v.add_child(_label(spec.name, 14, Color("e6e0cf")))
		v.add_child(_label(str(spec.trader), 12, Color("9fb3a6")))
	var strip_title := _label("Same PNGs at in-menu sizes (64 / 48 / 34 px):", 15, Color("b8c7b6"))
	strip_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(strip_title)
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", theme_.frame("c9c5b8", "8a826d", 8))
	col.add_child(strip)
	var rows_ := VBoxContainer.new()
	rows_.add_theme_constant_override("separation", 6)
	strip.add_child(rows_)
	for size in [64, 48, 34]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		rows_.add_child(row)
		var sl := _label("%d px" % size, 13, Color("2a2f2b"))
		sl.custom_minimum_size.x = 48
		row.add_child(sl)
		for id in Renderer.ITEMS:
			var t := TextureRect.new()
			t.texture = _tex(id)
			t.custom_minimum_size = Vector2(size, size)
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(t)
	await _snap("icon_contact_sheet.png")
	layer.queue_free()

func _make_state(credits: int = -1) -> Dictionary:
	var plot := Plot.new()
	var inv := Inventory.new()
	var onboarding := Onboarding.new()
	if credits >= 0:
		plot.credits = credits
	return {"plot": plot, "inventory": inv, "onboarding": onboarding}

func menu_shot(shop: String, tag: String, preview: bool, select_id: String) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("26332c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(host)
	var state: Dictionary = _make_state()
	var panel: Control
	match shop:
		"rook":
			panel = RookPanel.new() if preview else SuppliesPanel.new()
			host.add_child(panel)
			if preview:
				panel.render(state.plot, state.inventory, "", "", {})
			else:
				panel.render(state.plot, state.inventory, "", "", {})
		"psy":
			panel = PsyPanel.new() if preview else PreviewPanel.new()
			host.add_child(panel)
			panel.open_service("psy", state.plot, state.inventory)
		"tailor":
			panel = TailorPanel.new() if preview else ClothingPanel.new()
			host.add_child(panel)
			panel.render(state.inventory, state.onboarding, "", state.plot, {})
		"fishing":
			panel = FishBuyPanel.new() if preview else FishingPanel.new()
			host.add_child(panel)
			panel.render(state.plot, state.inventory, "", "")
		_:
			panel = ShopPanel.new()
			host.add_child(panel)
	if panel.has_method("_select_item"):
		panel._select_item(select_id)
	panel.show()
	var kind := "AFTER · working buy menu" if preview else "BEFORE · shipped panel"
	_caption(layer, "%s  ·  %s  ·  fresh save, %d credits  ·  selected %s" % [kind, shop.capitalize(), state.plot.credits, select_id])
	await _snap("%s_buy_menu_%s.png" % [shop, tag])
	layer.queue_free()

func confirm_shot() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("26332c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(host)
	var state: Dictionary = _make_state()
	var panel: Control = RookPanel.new()
	host.add_child(panel)
	var pending := {
		"token": 1,
		"shop_id": "rook",
		"action": "buy",
		"item": "timber",
		"name": "Timber",
		"quantity": 2,
		"unit_price": 10,
		"total": 20,
		"balance_after": state.plot.credits - 20,
		"carried_after": 2,
		"capacity": state.inventory.capacity("carried"),
	}
	panel.render(state.plot, state.inventory, "", "Review this purchase, then confirm. Nothing is taken until you confirm.", pending)
	panel.show()
	_caption(layer, "CONFIRM  ·  Rook  ·  2 timber for 20 credits  ·  Confirm purchase is armed")
	await _snap("rook_confirm.png")
	layer.queue_free()

func funds_shot() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("26332c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(host)
	var state: Dictionary = _make_state(5)
	var panel: Control = RookPanel.new()
	host.add_child(panel)
	panel.render(state.plot, state.inventory, "", "", {})
	panel._select_item("timber")
	panel.show()
	_caption(layer, "INSUFFICIENT FUNDS  ·  Rook  ·  5 credits, timber costs 10  ·  Review is disabled")
	await _snap("rook_insufficient_funds.png")
	layer.queue_free()
