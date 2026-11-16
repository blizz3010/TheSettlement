extends Node
## Item 13 capture driver: before (pinned demo) and after (browse, post,
## confirm, sold/payout) for Dan's player marketplace.
## Env: DL_OUT (shot dir). Loaded as a scene or through a temporary override.cfg.
const PreviewPanel = preload("res://scripts/trader_preview_panel.gd")
const DanPanel = preload("res://raid/scripts/dan_listings_panel.gd")
const Store = preload("res://raid/scripts/dan_listings_store.gd")
const Service = preload("res://raid/scripts/dan_listings_service.gd")
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")

var out: String

func _ready() -> void:
	out = OS.get_environment("DL_OUT")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://raid/screenshots/dan_listings")
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()

func run() -> void:
	await before_shot()
	await browse_shot()
	await post_shot()
	await confirm_shot()
	await sold_shot()
	await compare_sheet()
	print("DL: done")
	get_tree().quit()

func _state(credits: int = 150, carried: Dictionary = {}) -> Dictionary:
	var plot := Plot.new()
	var inv := Inventory.new()
	plot.credits = credits
	for item in carried:
		inv.carried[item] = int(carried[item])
	return {"plot": plot, "inventory": inv}

func _store(now: int = 1000) -> Store:
	var store := Store.new()
	store.sale_delay_sec = 15
	store.seed_if_empty(now)
	return store

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
	print("DL: %s err=%d %dx%d" % [name_, err, img.get_width(), img.get_height()])

func before_shot() -> void:
	var pack: Dictionary = _layer()
	var state: Dictionary = _state()
	var panel: Control = PreviewPanel.new()
	pack.host.add_child(panel)
	panel.open_service("dan", state.plot, state.inventory)
	panel.show()
	_caption(pack.layer, "BEFORE  ·  Dan's demo board  ·  Buy, Bid and Post are coming soon")
	await _snap("dan_listings_before.png")
	pack.layer.queue_free()

func browse_shot() -> void:
	var pack: Dictionary = _layer()
	var state: Dictionary = _state()
	var store: Store = _store()
	var panel: Control = DanPanel.new()
	pack.host.add_child(panel)
	panel.configure({
		"shop_id": "dan",
		"title": "DAN · PLAYER MARKETPLACE",
		"emblem": "▤",
		"role": "Player listings · local board",
		"tabs": ["browse", "my listings", "post", "how it works"],
		"help": "Buy listed goods, post a carried item, or cancel your own listing.",
	})
	panel.action = "browse"
	panel.render_board(state.plot, state.inventory, store, {}, "")
	var first := ""
	for row in panel.rows:
		if row.get("enabled", false):
			first = str(row.id)
			break
	if not first.is_empty():
		panel._select_item(first)
	panel.show()
	_caption(pack.layer, "AFTER  ·  Browse  ·  seeded settler listings, mid-style icons, 150 credits")
	await _snap("dan_listings_browse.png")
	pack.layer.queue_free()

func post_shot() -> void:
	var pack: Dictionary = _layer()
	var state: Dictionary = _state(150, {"timber": 3, "stone": 2})
	var store: Store = _store()
	var panel: Control = DanPanel.new()
	pack.host.add_child(panel)
	panel.configure({
		"shop_id": "dan",
		"title": "DAN · PLAYER MARKETPLACE",
		"emblem": "▤",
		"role": "Player listings · local board",
		"tabs": ["browse", "my listings", "post", "how it works"],
		"help": "Post a carried item at your asking price.",
	})
	panel.action = "post"
	panel.render_board(state.plot, state.inventory, store, {}, "")
	panel._select_item("timber")
	panel.set_asking_price(9)
	panel.quantity.value = 2
	panel._update_summary()
	panel.show()
	_caption(pack.layer, "AFTER  ·  Post  ·  2 timber at 9 credits each, reserved from carried inventory")
	await _snap("dan_listings_post.png")
	pack.layer.queue_free()

func confirm_shot() -> void:
	var pack: Dictionary = _layer()
	var state: Dictionary = _state()
	var store: Store = _store()
	var svc := Service.new()
	var harlan_id := ""
	for row in store.active_rows():
		if row.seller_id == "harlan_reed":
			harlan_id = str(row.id)
			break
	var candidate: Dictionary = svc.quote_candidate("dan", "buy", harlan_id, 3, state.plot, state.inventory, preload("res://scripts/request_state.gd").new(), {
		"listings": store.snapshot(),
		"asking_price": 8,
		"now_unix": 1500,
	})
	if candidate.is_empty() or not candidate.get("receipt") is Dictionary:
		print("DL: confirm quote failed: " + svc.last_error)
		pack.layer.queue_free()
		return
	var quote: Dictionary = candidate.receipt.duplicate(true)
	quote["token"] = 1
	var panel: Control = DanPanel.new()
	pack.host.add_child(panel)
	panel.configure({
		"shop_id": "dan",
		"title": "DAN · PLAYER MARKETPLACE",
		"emblem": "▤",
		"role": "Player listings · local board",
		"tabs": ["browse", "my listings", "post", "how it works"],
		"help": "Review the purchase, then confirm.",
	})
	panel.action = "browse"
	panel.render_board(state.plot, state.inventory, store, quote, "Review this purchase, then confirm. Nothing is taken until you confirm.")
	panel.show()
	_caption(pack.layer, "AFTER  ·  Confirm  ·  Harlan Reed's timber × 3 for 24 credits")
	await _snap("dan_listings_confirm.png")
	pack.layer.queue_free()

func sold_shot() -> void:
	var pack: Dictionary = _layer()
	var state: Dictionary = _state(150, {"timber": 3})
	var store: Store = _store(1000)
	var svc := Service.new()
	var request = preload("res://scripts/request_state.gd").new()
	var posted: Dictionary = svc.quote_candidate("dan", "post", "timber", 2, state.plot, state.inventory, request, {
		"listings": store.snapshot(),
		"asking_price": 9,
		"now_unix": 2000,
	})
	store.restore(posted.listings)
	state.plot = posted.plot
	state.inventory = posted.inventory
	var listing_id: String = str(posted.receipt.listing_id)
	store.force_sell(listing_id, 2015)
	var panel: Control = DanPanel.new()
	pack.host.add_child(panel)
	panel.configure({
		"shop_id": "dan",
		"title": "DAN · PLAYER MARKETPLACE",
		"emblem": "▤",
		"role": "Player listings · local board",
		"tabs": ["browse", "my listings", "post", "how it works"],
		"help": "Collect a payout from a sold listing.",
	})
	panel.action = "my listings"
	panel.render_board(state.plot, state.inventory, store, {}, "Sold: Timber × 2 for 18 credits. Collect the payout in My listings.")
	panel._select_item(listing_id)
	panel.show()
	_caption(pack.layer, "AFTER  ·  Sold / payout  ·  visiting settler bought your timber for 18 credits")
	await _snap("dan_listings_sold.png")
	pack.layer.queue_free()

func compare_sheet() -> void:
	var names := ["dan_listings_before.png", "dan_listings_browse.png", "dan_listings_post.png", "dan_listings_confirm.png", "dan_listings_sold.png"]
	var images: Array = []
	for name_ in names:
		var path := out.path_join(name_)
		if FileAccess.file_exists(path):
			images.append(Image.load_from_file(path))
	if images.size() < 2:
		print("DL: compare skipped, missing shots")
		return
	var w: int = images[0].get_width()
	var h: int = images[0].get_height()
	var cols := images.size()
	var sheet := Image.create(w * cols, h, false, Image.FORMAT_RGBA8)
	for i in range(images.size()):
		sheet.blit_rect(images[i], Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	var dest := out.path_join("compare_dan_listings.png")
	var err := sheet.save_png(dest)
	print("DL: compare_dan_listings.png err=%d %dx%d" % [err, sheet.get_width(), sheet.get_height()])
