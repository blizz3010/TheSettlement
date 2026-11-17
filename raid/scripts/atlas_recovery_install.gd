extends RefCounted
## Installs Atlas's recovery panel beside Dan's listings and the item 16 menus.
## Safe to call twice. Extends the Dan controller script rather than replacing it.
const DAN_EXT := "res://raid/scripts/dan_listings_controller_ext.gd"
const EXT_PATH := "res://raid/scripts/atlas_recovery_controller_ext.gd"
const AtlasPanel = preload("res://raid/scripts/atlas_recovery_panel.gd")
const AtlasStore = preload("res://raid/scripts/atlas_recovery_store.gd")
const AtlasService = preload("res://raid/scripts/atlas_recovery_service.gd")
const ShopTransaction = preload("res://scripts/shop_transaction.gd")
const SaveCodec = preload("res://scripts/save_codec.gd")

static func _script_path(node) -> String:
	if not is_instance_valid(node) or node.get_script() == null:
		return ""
	return str(node.get_script().resource_path)

static func install(host: Node) -> bool:
	if host == null or not is_instance_valid(host):
		return false
	var controller = host.get("trader_previews")
	if not is_instance_valid(controller):
		return false
	if preload("res://raid/scripts/controller_chain.gd").inherits(controller, EXT_PATH):
		_bind_store(host, controller)
		if is_instance_valid(controller.get("recovery_panel")):
			return true
		_attach_panel(host, controller)
		return is_instance_valid(controller.recovery_panel)
	# Dan's installer must have run first so marketplace fields exist.
	if _script_path(controller) != DAN_EXT:
		return false
	var saved := {
		"host": controller.get("host"),
		"gear_service": controller.get("gear_service"),
		"gear_transactions": controller.get("gear_transactions"),
		"panel": controller.get("panel"),
		"current_id": controller.get("current_id"),
		"restore_pending": controller.get("restore_pending"),
		"marketplace_enabled": controller.get("marketplace_enabled"),
		"window_focused": controller.get("window_focused"),
		"marketplace_panel": controller.get("marketplace_panel"),
		"listings_store": controller.get("listings_store"),
		"listings_service": controller.get("listings_service"),
		"listings_transactions": controller.get("listings_transactions"),
		"listings_message": controller.get("listings_message"),
	}
	controller.set_script(load(EXT_PATH))
	for key in saved:
		controller.set(key, saved[key])
	controller.recovery_store = AtlasStore.new()
	controller.recovery_service = AtlasService.new()
	controller.recovery_transactions = ShopTransaction.new(controller.recovery_service.quote_candidate)
	controller.recovery_message = ""
	_attach_panel(host, controller)
	_bind_store(host, controller)
	if controller.has_method("refresh_service_metadata"):
		controller.refresh_service_metadata()
	host.set_meta("atlas_recovery", controller.recovery_store)
	host.set_meta("atlas_recovery_installed", true)
	return is_instance_valid(controller.recovery_panel)

static func _attach_panel(host: Node, controller) -> void:
	if is_instance_valid(controller.get("recovery_panel")):
		return
	var panel: Control = AtlasPanel.new()
	var parent: Node = null
	if is_instance_valid(controller.get("marketplace_panel")):
		parent = controller.marketplace_panel.get_parent()
	elif is_instance_valid(controller.panel):
		parent = controller.panel.get_parent()
	elif is_instance_valid(host.get("supplies_panel")):
		parent = host.supplies_panel.get_parent()
	if parent == null:
		parent = host
	parent.add_child(panel)
	panel.hide()
	panel.configure({
		"shop_id": "atlas",
		"title": "ATLAS · RECOVERY",
		"emblem": "▣",
		"role": "Item recovery · carried losses from a failed raid",
		"tabs": ["recover", "how it works"],
		"help": "Pay to recover carried supplies lost when you were downed. Stash, Lockbox and equipped clothing stay at home. A raid haul lost when downed is not recoverable.",
	})
	panel.closed.connect(controller.close)
	panel.review_requested.connect(controller.review_recovery)
	panel.confirmed.connect(controller.confirm_recovery)
	panel.cancelled.connect(controller.cancel_recovery)
	panel.tab_changed.connect(controller.on_recovery_tab_changed)
	controller.recovery_panel = panel

static func _bind_store(host: Node, controller) -> void:
	if controller.recovery_store == null:
		controller.recovery_store = AtlasStore.new()
	if controller.recovery_service == null:
		controller.recovery_service = AtlasService.new()
	if controller.recovery_transactions == null:
		controller.recovery_transactions = ShopTransaction.new(controller.recovery_service.quote_candidate)
	var save_path := str(host.get("character_save_path"))
	if controller.recovery_store.path.is_empty() or (not save_path.is_empty() and controller.recovery_store.path != AtlasStore.sidecar_path(save_path)):
		controller.recovery_store.load_or_create(save_path)
	if is_instance_valid(controller.recovery_panel):
		controller.recovery_panel.bind_store(controller.recovery_store)
	host.set_meta("atlas_recovery", controller.recovery_store)
	host.set_meta("atlas_recovery_installed", true)

static func load_store(host: Node) -> void:
	if not is_instance_valid(host):
		return
	var controller = host.get("trader_previews")
	if is_instance_valid(controller) and controller.has_method("_ensure_recovery_store"):
		controller._ensure_recovery_store()
		var save_path := str(host.get("character_save_path"))
		controller.recovery_store.load_or_create(save_path)
		host.set_meta("atlas_recovery", controller.recovery_store)
		if controller.has_method("refresh_service_metadata"):
			controller.refresh_service_metadata()

## Apply a raid return to the live settlement. Downed returns move carried
## stacks into the sidecar; extracted returns only tick expiry. Returns a note.
static func apply_return(host: Node, outcome: Dictionary) -> String:
	if host == null or not is_instance_valid(host):
		return ""
	var kind := str(outcome.get("outcome", ""))
	if not kind in ["downed", "extracted"]:
		return ""
	if not bool(host.get_meta("atlas_recovery_installed", false)):
		install(host)
	var store: AtlasStore = host.get_meta("atlas_recovery") if host.has_meta("atlas_recovery") else null
	if store == null:
		store = AtlasStore.new()
		host.set_meta("atlas_recovery", store)
	var save_path := str(host.get("character_save_path"))
	if store.path.is_empty():
		store.load_or_create(save_path)
	var service := AtlasService.new()
	var context := {
		"now_unix": int(Time.get_unix_time_from_system()),
		"wait_sec": store.wait_sec,
		"expire_after_raids": store.expire_after_raids,
		"map": str(outcome.get("map", "")),
		"source": str(outcome.get("source", "")),
	}
	var candidate: Dictionary
	if kind == "downed":
		candidate = service.intake(host.state, host.inventory, host.request, store, context)
	else:
		candidate = service.tick_raids(host.state, host.inventory, host.request, store, context)
	if candidate.is_empty():
		return ""
	var previous: Dictionary = store.snapshot()
	var previous_plot = host.state
	var previous_inventory = host.inventory
	var previous_request = host.request
	if not store.restore(candidate.recovery):
		return ""
	host.state = candidate.plot
	host.inventory = candidate.inventory
	host.request = candidate.request
	var changed := kind == "downed" or not str(candidate.receipt.get("message", "")).is_empty()
	if changed and host.has_method("save_payload"):
		var payload: Dictionary = SaveCodec.encode(host.state, host.inventory, host.request, host.craft, host.onboarding, host.fishing)
		if not host.save_payload(payload, false):
			store.restore(previous)
			host.state = previous_plot
			host.inventory = previous_inventory
			host.request = previous_request
			return "Atlas could not save the recovery hold. Your hideout was left unchanged."
	if not store.save() and kind == "downed":
		return "Atlas could not save the recovery hold."
	return str(candidate.receipt.get("message", ""))
