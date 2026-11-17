extends "res://raid/scripts/gear_tiers/psy_gear_controller_ext.gd"
## TASKS item 13: Atlas's Salvage tab (sell raid salvage, claim material overflow).
## Extends the Psy tier controller (which extends Atlas's, which extends Dan's), so
## all four services keep working. Pinned trader scripts are untouched. Salvage
## and overflow live in the raid_haul.json sidecar; credits and items in the save.
const HaulStore = preload("res://raid/scripts/raid_loot/raid_loot_store.gd")
const LootService = preload("res://raid/scripts/raid_loot/raid_loot_service.gd")

var haul_store: HaulStore
var loot_service: LootService
var loot_transactions: ShopTransaction
var loot_message: String = ""

func prompt_text() -> String:
	if nearest() == "atlas":
		return host.key_label("interact") + "  Atlas · Recovery & salvage"
	return super.prompt_text()

func refresh_service_metadata():
	super.refresh_service_metadata()
	if not is_instance_valid(host): return
	var stand = host.get_node_or_null(ACCESS["atlas"].path)
	if not is_instance_valid(stand): return
	stand.set_meta("service_status", "item_recovery_and_salvage")
	for label in stand.find_children("*", "Label3D", true, false):
		if label.text == "ITEM RECOVERY · CARRIED LOSSES": label.text = "RECOVERY · SALVAGE BUYER"

func ensure_haul_store(reload: bool = false) -> void:
	var save_path := str(host.get("character_save_path")) if is_instance_valid(host) else ""
	if haul_store == null: haul_store = HaulStore.new()
	if reload or haul_store.path.is_empty() or (not save_path.is_empty() and haul_store.path != HaulStore.sidecar_path(save_path)):
		haul_store.load_or_create(save_path)
	if loot_service == null: loot_service = LootService.new()
	if loot_transactions == null: loot_transactions = ShopTransaction.new(loot_service.quote_candidate)
	if is_instance_valid(recovery_panel) and recovery_panel.has_method("bind_haul"):
		recovery_panel.bind_haul(haul_store)

func _open_recovery() -> void:
	# Re-read the sidecar on every visit: a raid return writes it.
	if loot_transactions != null: loot_transactions.cancel()
	ensure_haul_store(true)
	super._open_recovery()
	if not _recovery_visible(): return
	# Fresh from a raid with nothing to recover: show the salvage first.
	if recovery_store.open_rows().is_empty() and (not haul_store.salvage.is_empty() or not haul_store.cargo.is_empty()):
		if recovery_panel.tab_buttons.has("salvage"):
			recovery_panel._change_tab("salvage")

func loot_context() -> Dictionary:
	ensure_haul_store()
	return {"haul": haul_store.snapshot()}

func loot_access() -> bool:
	return current_id == "atlas" and _recovery_visible() and recovery_panel.action == "salvage" and eligible()

func _render_salvage(pending: Dictionary = {}, message: String = "") -> void:
	ensure_haul_store()
	recovery_panel.render_board(host.state, host.inventory, recovery_store, pending, message)

func review_recovery(item: String, quantity: int, action: String) -> void:
	if action != "salvage":
		super.review_recovery(item, quantity, action)
		return
	if not loot_access() or item != recovery_panel.selected_item: return
	var quote: Dictionary = loot_transactions.select("atlas", "salvage", item, quantity, host.state, host.inventory, host.request, loot_context())
	var message: String = loot_service.last_error if not loot_service.last_error.is_empty() else loot_transactions.last_error
	_render_salvage(quote, message)
	if not quote.is_empty(): recovery_panel.cancel_button.grab_focus()

func confirm_recovery(writer_override = null) -> bool:
	if loot_transactions == null or loot_transactions.pending_quote().is_empty():
		return super.confirm_recovery(writer_override)
	var pending: Dictionary = loot_transactions.pending_quote()
	var writer = func(candidate): return _loot_writer(candidate, writer_override)
	var candidate: Dictionary = loot_transactions.confirm(pending.token, host.state, host.inventory, host.request, loot_access, writer, loot_context())
	if not candidate.is_empty():
		host.state = candidate.plot
		host.inventory = candidate.inventory
		host.request = candidate.request
		if host.has_meta("approved_audio_service"):
			var audio = host.get_meta("approved_audio_service")
			if is_instance_valid(audio) and audio.has_method("queue_cue"): audio.queue_cue("confirm_buy")
		if str(pending.get("verb", "")) == "claim":
			loot_message = "Saved. Claimed %s into your bag." % str(pending.get("name", "items"))
		else:
			loot_message = "Saved. Sold %s for %d credits." % [str(pending.get("name", "salvage")), int(pending.get("earned", 0))]
	var message := loot_message if not candidate.is_empty() else loot_transactions.last_error
	_render_salvage({}, message)
	if recovery_panel.visible: recovery_panel.close_button.grab_focus()
	return not candidate.is_empty()

## Sidecar first, then the main save; a failed main save rolls the sidecar back.
func _loot_writer(candidate, writer_override = null) -> bool:
	if not candidate is Dictionary or not candidate.has("haul"): return false
	var previous: Dictionary = haul_store.snapshot()
	if not haul_store.restore(candidate.haul): return false
	if not haul_store.save():
		haul_store.restore(previous)
		return false
	var payload: Dictionary = SaveCodec.encode(candidate.plot, candidate.inventory, candidate.request, host.craft, host.onboarding, host.fishing)
	if not host.save_payload(payload, false, writer_override):
		haul_store.restore(previous)
		haul_store.save()
		return false
	return true

func cancel_recovery() -> void:
	if loot_transactions != null and not loot_transactions.pending_quote().is_empty():
		loot_transactions.cancel()
		if current_id == "atlas" and _recovery_visible(): _render_salvage({}, "Review cancelled. Nothing changed.")
		return
	super.cancel_recovery()

func on_recovery_tab_changed(tab: String) -> void:
	if loot_transactions != null: loot_transactions.cancel()
	if tab == "salvage":
		if current_id != "atlas" or not _recovery_visible(): return
		recovery_transactions.cancel()
		_render_salvage({}, loot_message)
		return
	super.on_recovery_tab_changed(tab)

func close():
	if loot_transactions != null: loot_transactions.cancel()
	super.close()
