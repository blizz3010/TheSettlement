extends "res://raid/scripts/atlas_recovery_controller_ext.gd"
## TASKS item 22, PR C: Psy opens the tier gear shop (buy, sell, repair, upgrade,
## equip). Extends the Atlas controller (which extends Dan's), so all three stands
## keep working. Pinned trader scripts are untouched. Tiered gear is written to the
## user://gear_locker.json sidecar; credits and materials to the normal save.
const GearPanel = preload("res://raid/scripts/gear_tiers/psy_gear_tier_panel.gd")
const GearStore = preload("res://raid/scripts/gear_tiers/gear_locker_store.gd")
const GearService = preload("res://raid/scripts/gear_tiers/gear_shop_service.gd")
const GearAvatar = preload("res://raid/scripts/gear_tiers/gear_avatar.gd")

var tier_panel: Control
var gear_store: GearStore
var tier_service: GearService
var tier_transactions: ShopTransaction
var tier_message: String = ""

func _tiers_visible() -> bool:
	return is_instance_valid(tier_panel) and tier_panel.visible

func is_open() -> bool:
	return _tiers_visible() or super.is_open()

func prompt_text() -> String:
	if nearest() == "psy":
		return host.key_label("interact") + "  Psy · Gear & armor"
	return super.prompt_text()

func refresh_service_metadata():
	super.refresh_service_metadata()
	if not is_instance_valid(host): return
	var stand = host.get_node_or_null(ACCESS["psy"].path)
	if not is_instance_valid(stand): return
	stand.set_meta("service_status", "tier_gear_trading")
	for label in stand.find_children("*", "Label3D", true, false):
		if label.text == "COSMETIC HELMET · BUY / SELL": label.text = "GEAR & ARMOR · TIERS 1-4"

func ensure_gear_store() -> void:
	if gear_store == null:
		gear_store = GearStore.new()
		gear_store.load_locker()
	if tier_service == null: tier_service = GearService.new()
	if tier_transactions == null: tier_transactions = ShopTransaction.new(tier_service.quote_candidate)

func open(id: String):
	if id == "psy":
		if _marketplace_visible(): marketplace_panel.hide()
		if _recovery_visible(): recovery_panel.hide()
		_open_tiers()
		return
	if _tiers_visible(): tier_panel.hide()
	super.open(id)

func _open_tiers() -> void:
	if not accessible("psy") or host.modal_open(): return
	current_id = "psy"
	restore_pending = false
	# Re-read the sidecar on every visit: raids wear gear and count extractions.
	gear_store = null
	ensure_gear_store()
	tier_transactions.cancel()
	if is_instance_valid(panel): panel.hide()
	tier_panel.action = "buy"
	tier_panel.selected_item = ""
	render_tiers({}, tier_message)
	tier_panel.show()
	tier_panel.close_button.grab_focus()
	host.player.enabled = false
	host.player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func render_tiers(pending: Dictionary = {}, message: String = "") -> void:
	ensure_gear_store()
	var rows: Array = tier_service.rows(tier_panel.action, host.state, host.inventory, gear_store.state)
	tier_panel.set_loadout_help(tier_service.loadout_text(gear_store.state))
	# Gear art E0: equip-tab mannequin + third-person avatar follow the worn loadout.
	var worn: Array = GearAvatar.worn_defs(gear_store.state)
	tier_panel.set_worn(worn)
	if is_instance_valid(host) and is_instance_valid(host.get("player")): GearAvatar.install(host.player, worn)
	tier_panel.render_state(host.state, host.inventory, rows, pending, message)

func eligible() -> bool:
	if current_id == "psy" and _tiers_visible():
		return accessible("psy") and not host.modal_open(true, true, false)
	return super.eligible()

func close():
	if tier_transactions != null: tier_transactions.cancel()
	if _tiers_visible():
		restore_pending = true
		tier_panel.hide()
	super.close()

func tier_context() -> Dictionary:
	ensure_gear_store()
	return {"service": "psy", "locker": gear_store.state.data()}

func tier_access() -> bool:
	return current_id == "psy" and _tiers_visible() and eligible()

func review_tier(item: String, quantity: int, action: String) -> void:
	if not tier_access() or action != tier_panel.action or item != tier_panel.selected_item: return
	var quote: Dictionary = tier_transactions.select("psy", action, item, quantity, host.state, host.inventory, host.request, tier_context())
	var message: String = tier_service.last_error if not tier_service.last_error.is_empty() else tier_transactions.last_error
	render_tiers(quote, message)
	if not quote.is_empty(): tier_panel.cancel_button.grab_focus()

func confirm_tier(writer_override = null) -> bool:
	var pending: Dictionary = tier_transactions.pending_quote()
	if pending.is_empty(): return false
	var writer = func(candidate): return _tier_writer(candidate, writer_override)
	var candidate: Dictionary = tier_transactions.confirm(pending.token, host.state, host.inventory, host.request, tier_access, writer, tier_context())
	if not candidate.is_empty():
		host.state = candidate.plot
		host.inventory = candidate.inventory
		host.request = candidate.request
		if host.has_meta("approved_audio_service"):
			var audio = host.get_meta("approved_audio_service")
			if is_instance_valid(audio) and audio.has_method("queue_cue"): audio.queue_cue("confirm_buy")
		tier_message = "Saved. %s · %d credits." % [str(pending.get("name", "Done")), int(pending.total)]
	var message := tier_message if not candidate.is_empty() else tier_transactions.last_error
	render_tiers({}, message)
	if tier_panel.visible: tier_panel.close_button.grab_focus()
	return not candidate.is_empty()

## Locker first, then the main save; a failed main save rolls the locker back.
func _tier_writer(candidate, writer_override = null) -> bool:
	if not candidate is Dictionary or not candidate.has("locker"): return false
	var previous: Dictionary = gear_store.state.data()
	if not gear_store.state.restore(candidate.locker): return false
	if not gear_store.save():
		gear_store.state.restore(previous)
		return false
	var payload: Dictionary = SaveCodec.encode(candidate.plot, candidate.inventory, candidate.request, host.craft, host.onboarding, host.fishing)
	if not host.save_payload(payload, false, writer_override):
		gear_store.state.restore(previous)
		gear_store.save()
		return false
	return true

func cancel_tier() -> void:
	if tier_transactions != null: tier_transactions.cancel()
	if current_id == "psy" and _tiers_visible(): render_tiers({}, "Review cancelled. Nothing changed.")

func on_tier_tab_changed(_tab: String) -> void:
	if current_id != "psy" or not _tiers_visible(): return
	tier_transactions.cancel()
	tier_message = ""
	render_tiers({}, "")
