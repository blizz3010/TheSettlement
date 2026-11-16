extends Node
## Item 13 capture driver: before (coming soon) and after (recover, confirm,
## insufficient funds) for Atlas's recovery stand.
## Env: AR_OUT (shot dir). Loaded as a scene; override.cfg is temporary only.
const PreviewPanel = preload("res://scripts/trader_preview_panel.gd")
const AtlasPanel = preload("res://raid/scripts/atlas_recovery_panel.gd")
const Store = preload("res://raid/scripts/atlas_recovery_store.gd")
const Service = preload("res://raid/scripts/atlas_recovery_service.gd")
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Request = preload("res://scripts/request_state.gd")

var out: String

func _ready() -> void:
	out = OS.get_environment("AR_OUT")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://raid/screenshots/atlas_recovery")
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()

func run() -> void:
	await before_shot()
	await recover_shot()
	await confirm_shot()
	await funds_shot()
	await compare_sheet()
	print("AR: done")
	get_tree().quit()

func _state(credits: int = 150, carried: Dictionary = {}) -> Dictionary:
	var plot := Plot.new()
	var inv := Inventory.new()
	plot.credits = credits
	for item in carried:
		inv.carried[item] = int(carried[item])
	return {"plot": plot, "inventory": inv, "request": Request.new()}

func _held_store() -> Dictionary:
	var state: Dictionary = _state(150, {"timber": 3, "stone": 2})
	var store := Store.new()
	store.wait_sec = 0
	store.expire_after_raids = 3
	var svc := Service.new()
	var taken: Dictionary = svc.intake(state.plot, state.inventory, state.request, store, {
		"recovery": store.snapshot(), "now_unix": 1000, "wait_sec": 0, "expire_after_raids": 3,
		"map": "Relay Ridge", "source": "sentry turret",
	})
	store.restore(taken.recovery)
	state.plot = taken.plot
	state.inventory = taken.inventory
	return {"state": state, "store": store, "svc": svc}

func _layer() -> Dictionary:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("26332c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(host)
	return {"layer": layer, "host": host}

func _caption(layer: CanvasLayer, text: String) -> void:
	var bar := ColorRect.new()
	bar.color = Color(0.07, 0.1, 0.09, 0.86)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 46
	layer.add_child(bar)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("f2ead8"))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 18
	label.offset_right = -18
	bar.add_child(label)

func _snap(name_: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var dest := out.path_join(name_)
	var err := img.save_png(dest)
	print("AR: %s err=%d %dx%d" % [name_, err, img.get_width(), img.get_height()])

func _configure(panel: Control) -> void:
	panel.configure({
		"shop_id": "atlas",
		"title": "ATLAS · RECOVERY",
		"emblem": "▣",
		"role": "Item recovery · carried losses from a failed raid",
		"tabs": ["recover", "how it works"],
		"help": "Pay to recover carried supplies lost when you were downed.",
	})

func before_shot() -> void:
	var pack: Dictionary = _layer()
	var state: Dictionary = _state()
	var panel: Control = PreviewPanel.new()
	pack.host.add_child(panel)
	panel.open_service("atlas", state.plot, state.inventory)
	panel.show()
	_caption(pack.layer, "BEFORE  ·  Atlas recovery  ·  service coming soon, no stock")
	await _snap("atlas_recovery_before.png")
	pack.layer.queue_free()

func recover_shot() -> void:
	var pack: Dictionary = _layer()
	var held: Dictionary = _held_store()
	var panel: Control = AtlasPanel.new()
	pack.host.add_child(panel)
	_configure(panel)
	panel.action = "recover"
	panel.render_board(held.state.plot, held.state.inventory, held.store, {}, "Atlas is holding Timber × 3 and Stone × 2. Pay to recover them at his stand before they expire.")
	var first := ""
	for row in panel.rows:
		if row.get("enabled", false):
			first = str(row.id)
			break
	if not first.is_empty():
		panel._select_item(first)
	panel.show()
	_caption(pack.layer, "AFTER  ·  Recover  ·  carried losses from a downed raid at Relay Ridge")
	await _snap("atlas_recovery_after.png")
	pack.layer.queue_free()

func confirm_shot() -> void:
	var pack: Dictionary = _layer()
	var held: Dictionary = _held_store()
	var timber_id := ""
	for row in held.store.open_rows():
		if row.item_id == "timber":
			timber_id = str(row.id)
	var candidate: Dictionary = held.svc.quote_candidate("atlas", "recover", timber_id, 1, held.state.plot, held.state.inventory, held.state.request, {
		"recovery": held.store.snapshot(), "now_unix": 1000, "wait_sec": 0, "expire_after_raids": 3,
	})
	if candidate.is_empty() or not candidate.get("receipt") is Dictionary:
		print("AR: confirm quote failed: " + held.svc.last_error)
		pack.layer.queue_free()
		return
	var quote: Dictionary = candidate.receipt.duplicate(true)
	quote["token"] = 1
	var panel: Control = AtlasPanel.new()
	pack.host.add_child(panel)
	_configure(panel)
	panel.action = "recover"
	panel.render_board(held.state.plot, held.state.inventory, held.store, quote, "Review this recovery, then confirm. Nothing is taken until you confirm.")
	panel.show()
	_caption(pack.layer, "AFTER  ·  Confirm  ·  recover Timber × 3 for 18 credits")
	await _snap("atlas_recovery_confirm.png")
	pack.layer.queue_free()

func funds_shot() -> void:
	var pack: Dictionary = _layer()
	var held: Dictionary = _held_store()
	held.state.plot.credits = 5
	var timber_id := ""
	for row in held.store.open_rows():
		if row.item_id == "timber":
			timber_id = str(row.id)
	var panel: Control = AtlasPanel.new()
	pack.host.add_child(panel)
	_configure(panel)
	panel.action = "recover"
	panel.render_board(held.state.plot, held.state.inventory, held.store, {}, "Not enough settlement credits. Nothing recovered.")
	if not timber_id.is_empty():
		panel._select_item(timber_id)
	panel.show()
	_caption(pack.layer, "AFTER  ·  Insufficient funds  ·  5 credits, timber recovery costs 18")
	await _snap("atlas_recovery_funds.png")
	pack.layer.queue_free()

func compare_sheet() -> void:
	var names := ["atlas_recovery_before.png", "atlas_recovery_after.png", "atlas_recovery_confirm.png", "atlas_recovery_funds.png"]
	var images: Array = []
	for name_ in names:
		var path := out.path_join(name_)
		if FileAccess.file_exists(path):
			images.append(Image.load_from_file(path))
	if images.size() < 2:
		print("AR: compare skipped")
		return
	var w: int = images[0].get_width()
	var h: int = images[0].get_height()
	var sheet := Image.create(w * images.size(), h, false, Image.FORMAT_RGBA8)
	for i in range(images.size()):
		sheet.blit_rect(images[i], Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	var dest := out.path_join("compare_atlas_recovery.png")
	var err := sheet.save_png(dest)
	print("AR: compare_atlas_recovery.png err=%d %dx%d" % [err, sheet.get_width(), sheet.get_height()])
