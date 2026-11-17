extends "res://raid/scripts/dan_listings_controller_ext.gd"
## Item 13 adapter: Atlas gets a dedicated recovery panel and a sidecar store.
## Extends Dan's controller so both stands stay available after PR #14.
const AtlasPanel = preload("res://raid/scripts/atlas_recovery_panel.gd")
const AtlasStore = preload("res://raid/scripts/atlas_recovery_store.gd")
const AtlasService = preload("res://raid/scripts/atlas_recovery_service.gd")

var recovery_panel: Control
var recovery_store: AtlasStore
var recovery_service: AtlasService
var recovery_transactions: ShopTransaction
var recovery_message: String = ""

func is_open() -> bool:
	return _recovery_visible() or super.is_open()

func _recovery_visible() -> bool:
	return is_instance_valid(recovery_panel) and recovery_panel.visible

func prompt_text() -> String:
	var id := nearest()
	if id == "atlas":
		return host.key_label("interact") + "  Atlas · Item recovery"
	return super.prompt_text()

func refresh_service_metadata():
	super.refresh_service_metadata()
	if not is_instance_valid(host):
		return
	var stand = host.get_node_or_null(ACCESS["atlas"].path)
	if not is_instance_valid(stand):
		return
	stand.set_meta("service_status", "item_recovery")
	for label in stand.find_children("*", "Label3D", true, false):
		if label.text in ["RECOVERY OVERVIEW · SERVICE COMING SOON", "PLANNED SERVICE · NOT AVAILABLE", "ATLAS · RECOVERY OVERVIEW", "RECOVERY · COMING SOON"]:
			label.text = "ITEM RECOVERY · CARRIED LOSSES"

func open(id: String):
	if id == "atlas":
		if _marketplace_visible():
			marketplace_panel.hide()
		_open_recovery()
		return
	if _recovery_visible():
		recovery_panel.hide()
	super.open(id)

func _open_recovery() -> void:
	if not accessible("atlas") or host.modal_open():
		return
	current_id = "atlas"
	restore_pending = false
	recovery_transactions.cancel()
	_ensure_recovery_store()
	recovery_store.resolve(_now())
	recovery_store.save()
	if recovery_store.open_rows().is_empty():
		recovery_message = ""
	recovery_panel.action = "recover"
	recovery_panel.selected_item = ""
	if is_instance_valid(panel):
		panel.hide()
	recovery_panel.render_board(host.state, host.inventory, recovery_store, {}, recovery_message)
	recovery_panel.show()
	recovery_panel.close_button.grab_focus()
	host.player.enabled = false
	host.player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func eligible() -> bool:
	if current_id == "atlas":
		return _recovery_visible() and accessible("atlas") and not host.modal_open(true, true, false)
	return super.eligible()

func close():
	if recovery_transactions != null:
		recovery_transactions.cancel()
	if _recovery_visible():
		restore_pending = restore_pending or true
		recovery_panel.hide()
	super.close()

func _ensure_recovery_store() -> void:
	if recovery_store == null:
		recovery_store = AtlasStore.new()
	var save_path := ""
	if is_instance_valid(host):
		save_path = str(host.get("character_save_path"))
	if recovery_store.path.is_empty() or (not save_path.is_empty() and recovery_store.path != AtlasStore.sidecar_path(save_path)):
		recovery_store.load_or_create(save_path)

func recovery_context() -> Dictionary:
	_ensure_recovery_store()
	return {
		"recovery": recovery_store.snapshot(),
		"now_unix": _now(),
		"wait_sec": recovery_store.wait_sec,
		"expire_after_raids": recovery_store.expire_after_raids,
	}

func recovery_access() -> bool:
	return current_id == "atlas" and eligible()

func review_recovery(item: String, quantity: int, action: String) -> void:
	if not recovery_access():
		return
	if action != "recover" or item != recovery_panel.selected_item:
		return
	var quote: Dictionary = recovery_transactions.select("atlas", "recover", item, 1, host.state, host.inventory, host.request, recovery_context())
	var message := recovery_service.last_error if not recovery_service.last_error.is_empty() else recovery_transactions.last_error
	recovery_panel.render_board(host.state, host.inventory, recovery_store, quote, message)
	if not quote.is_empty():
		recovery_panel.cancel_button.grab_focus()

func confirm_recovery(writer_override = null) -> bool:
	var pending: Dictionary = recovery_transactions.pending_quote()
	if pending.is_empty():
		return false
	var writer = writer_override if writer_override != null else _recovery_writer
	var candidate: Dictionary = recovery_transactions.confirm(pending.token, host.state, host.inventory, host.request, recovery_access, writer, recovery_context())
	if not candidate.is_empty():
		host.state = candidate.plot
		host.inventory = candidate.inventory
		host.request = candidate.request
		recovery_store.restore(candidate.recovery)
		if host.has_meta("approved_audio_service"):
			var audio = host.get_meta("approved_audio_service")
			if is_instance_valid(audio) and audio.has_method("queue_cue"):
				audio.queue_cue("confirm_buy")
		recovery_message = "Saved. Recovered %s for %d credits." % [pending.get("name", "item"), int(pending.total)]
	var message := recovery_message if not candidate.is_empty() else recovery_transactions.last_error
	recovery_panel.render_board(host.state, host.inventory, recovery_store, {}, message)
	if recovery_panel.visible:
		recovery_panel.close_button.grab_focus()
	return not candidate.is_empty()

func cancel_recovery() -> void:
	recovery_transactions.cancel()
	if current_id == "atlas" and _recovery_visible():
		recovery_panel.render_board(host.state, host.inventory, recovery_store, {}, "Review cancelled. Nothing changed.")

func on_recovery_tab_changed(_tab: String) -> void:
	if current_id != "atlas" or not _recovery_visible():
		return
	recovery_transactions.cancel()
	recovery_panel.render_board(host.state, host.inventory, recovery_store, {}, recovery_message)

func _recovery_writer(candidate) -> bool:
	if not candidate is Dictionary or not candidate.has("recovery"):
		return false
	var previous: Dictionary = recovery_store.snapshot()
	if not recovery_store.restore(candidate.recovery):
		return false
	var payload: Dictionary = SaveCodec.encode(candidate.plot, candidate.inventory, candidate.request, host.craft, host.onboarding, host.fishing)
	if not host.save_payload(payload, false):
		recovery_store.restore(previous)
		return false
	if not recovery_store.save():
		return false
	return true
