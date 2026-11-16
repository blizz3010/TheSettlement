extends "res://scripts/trader_preview_controller.gd"
## Item 13 adapter: Dan gets a dedicated listings panel and a sidecar store.
## Psy and Atlas keep using the existing panel. Safe to install twice.
const DanPanel = preload("res://raid/scripts/dan_listings_panel.gd")
const DanStore = preload("res://raid/scripts/dan_listings_store.gd")
const DanService = preload("res://raid/scripts/dan_listings_service.gd")
const ShopTransaction = preload("res://scripts/shop_transaction.gd")
const SaveCodec = preload("res://scripts/save_codec.gd")

var marketplace_panel: Control
var listings_store: DanStore
var listings_service: DanService
var listings_transactions: ShopTransaction
var listings_message: String = ""

func is_open() -> bool:
	return _marketplace_visible() or super.is_open()

func _marketplace_visible() -> bool:
	return is_instance_valid(marketplace_panel) and marketplace_panel.visible

func prompt_text() -> String:
	var id := nearest()
	if id == "dan":
		return host.key_label("interact") + "  Dan · Player marketplace"
	return super.prompt_text()

func refresh_service_metadata():
	super.refresh_service_metadata()
	if not is_instance_valid(host):
		return
	var stand = host.get_node_or_null(ACCESS["dan"].path)
	if not is_instance_valid(stand) or not marketplace_enabled:
		return
	stand.set_meta("service_status", "player_listings")
	for label in stand.find_children("*", "Label3D", true, false):
		if label.text in ["PLAYER MARKETPLACE · PREVIEW", "PLANNED SERVICE · NOT AVAILABLE", "STARTER CLOTHING · MARKETPLACE PLANNED"]:
			label.text = "PLAYER MARKETPLACE · LISTINGS"

func open(id: String):
	if id == "dan":
		_open_marketplace()
		return
	if _marketplace_visible():
		marketplace_panel.hide()
	super.open(id)

func _open_marketplace() -> void:
	if not accessible("dan") or host.modal_open():
		return
	current_id = "dan"
	restore_pending = false
	listings_transactions.cancel()
	_ensure_store()
	var now := _now()
	var sold: Array = listings_store.resolve_sales(now)
	if not sold.is_empty():
		listings_store.save()
		var bits: PackedStringArray = []
		for row in sold:
			bits.append("%s × %d for %d credits" % [DanStore.display_name(str(row.item_id)), int(row.quantity), int(row.payout)])
		listings_message = "Sold: " + ", ".join(bits) + ". Collect the payout in My listings."
	elif listings_store.pending_payout_total() > 0:
		listings_message = "You have %d credits waiting in My listings." % listings_store.pending_payout_total()
	else:
		listings_message = ""
	if is_instance_valid(panel):
		panel.hide()
	marketplace_panel.action = "browse"
	marketplace_panel.selected_item = ""
	marketplace_panel.render_board(host.state, host.inventory, listings_store, {}, listings_message)
	marketplace_panel.show()
	marketplace_panel.close_button.grab_focus()
	host.player.enabled = false
	host.player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func eligible() -> bool:
	if current_id == "dan":
		return _marketplace_visible() and accessible("dan") and not host.modal_open(true, true, false)
	return super.eligible()

func close():
	listings_transactions.cancel()
	if _marketplace_visible():
		restore_pending = restore_pending or true
		marketplace_panel.hide()
	super.close()

func _ensure_store() -> void:
	if listings_store == null:
		listings_store = DanStore.new()
	var save_path := ""
	if is_instance_valid(host):
		save_path = str(host.get("character_save_path"))
	if listings_store.path.is_empty() or (not save_path.is_empty() and listings_store.path != DanStore.sidecar_path(save_path)):
		listings_store.load_or_seed(save_path, _now())

func _now() -> int:
	return int(Time.get_unix_time_from_system())

func listings_context() -> Dictionary:
	_ensure_store()
	var asking := 5
	if is_instance_valid(marketplace_panel):
		asking = marketplace_panel.asking_price()
	return {
		"listings": listings_store.snapshot(),
		"asking_price": asking,
		"now_unix": _now(),
	}

func listings_access() -> bool:
	return current_id == "dan" and eligible()

func review_listing(item: String, quantity: int, action: String) -> void:
	if not listings_access():
		return
	if action != marketplace_panel.row_action() or item != marketplace_panel.selected_item:
		return
	if action == "buy":
		var row: Dictionary = marketplace_panel._selected_row()
		quantity = int(row.get("listing_quantity", quantity))
	elif action == "cancel":
		var row: Dictionary = marketplace_panel._selected_row()
		quantity = int(row.get("listing_quantity", quantity))
	elif action == "collect":
		quantity = 1
	var quote: Dictionary = listings_transactions.select("dan", action, item, quantity, host.state, host.inventory, host.request, listings_context())
	var message := listings_service.last_error if not listings_service.last_error.is_empty() else listings_transactions.last_error
	marketplace_panel.render_board(host.state, host.inventory, listings_store, quote, message)
	if not quote.is_empty():
		marketplace_panel.cancel_button.grab_focus()

func confirm_listing(writer_override = null) -> bool:
	var pending: Dictionary = listings_transactions.pending_quote()
	if pending.is_empty():
		return false
	var writer = writer_override if writer_override != null else _default_writer
	var candidate: Dictionary = listings_transactions.confirm(pending.token, host.state, host.inventory, host.request, listings_access, writer, listings_context())
	if not candidate.is_empty():
		host.state = candidate.plot
		host.inventory = candidate.inventory
		host.request = candidate.request
		listings_store.restore(candidate.listings)
		if host.has_meta("approved_audio_service"):
			var audio = host.get_meta("approved_audio_service")
			if is_instance_valid(audio) and audio.has_method("queue_cue"):
				audio.queue_cue("confirm_buy")
		listings_message = _success_message(pending, candidate)
	var message := listings_message if not candidate.is_empty() else listings_transactions.last_error
	marketplace_panel.render_board(host.state, host.inventory, listings_store, {}, message)
	if marketplace_panel.visible:
		marketplace_panel.close_button.grab_focus()
	return not candidate.is_empty()

func cancel_listing() -> void:
	listings_transactions.cancel()
	if current_id == "dan" and _marketplace_visible():
		marketplace_panel.render_board(host.state, host.inventory, listings_store, {}, "Review cancelled. Nothing changed.")

func _success_message(pending: Dictionary, candidate: Dictionary) -> String:
	if pending.action == "buy":
		return "Saved. Bought %s for %d credits." % [pending.get("name", "listing"), int(pending.total)]
	if pending.action == "post":
		return "Saved. Listed %s for %d credits. Cancel from My listings to get the item back." % [pending.get("name", "item"), int(pending.total)]
	if pending.action == "cancel":
		return "Saved. Listing cancelled. The item is back in your carried inventory."
	return "Saved. Collected %d credits from %s." % [int(candidate.receipt.total), pending.get("name", "your sale")]

func _default_writer(candidate) -> bool:
	if not candidate is Dictionary or not candidate.has("listings"):
		return false
	var previous: Dictionary = listings_store.snapshot()
	if not listings_store.restore(candidate.listings):
		return false
	var payload: Dictionary = SaveCodec.encode(candidate.plot, candidate.inventory, candidate.request, host.craft, host.onboarding, host.fishing)
	if not host.save_payload(payload, false):
		listings_store.restore(previous)
		return false
	if not listings_store.save():
		# The hideout save already holds the new inventory and credits. Keep the
		# in-memory listings so the next successful save can persist them.
		return false
	return true

func on_tab_changed(_tab: String) -> void:
	if current_id != "dan" or not _marketplace_visible():
		return
	listings_transactions.cancel()
	if _tab == "post" and is_instance_valid(marketplace_panel) and not marketplace_panel.selected_item.is_empty():
		var row: Dictionary = marketplace_panel._selected_row()
		if not row.is_empty():
			marketplace_panel.set_asking_price(DanStore.suggested_price(str(row.get("item_id", row.get("id", "")))))
	marketplace_panel.render_board(host.state, host.inventory, listings_store, {}, listings_message)

func on_asking_changed(_value: int) -> void:
	if current_id != "dan" or not _marketplace_visible() or marketplace_panel.action != "post":
		return
	# Price display updates from the panel's own summary handler.
	pass
