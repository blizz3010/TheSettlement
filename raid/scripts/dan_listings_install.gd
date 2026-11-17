extends RefCounted
## Installs Dan's player-listings panel beside the item 16 buy menus.
## Does not edit pinned trader scripts. Safe to call twice.
const EXT_PATH := "res://raid/scripts/dan_listings_controller_ext.gd"
const ATLAS_EXT := "res://raid/scripts/atlas_recovery_controller_ext.gd"
const DanPanel = preload("res://raid/scripts/dan_listings_panel.gd")
const DanStore = preload("res://raid/scripts/dan_listings_store.gd")
const DanService = preload("res://raid/scripts/dan_listings_service.gd")
const ShopTransaction = preload("res://scripts/shop_transaction.gd")

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
	# Any later extension (Atlas, Psy tiers, raid loot) already carries Dan's fields.
	if preload("res://raid/scripts/controller_chain.gd").inherits(controller, EXT_PATH):
		_bind_store(host, controller)
		if is_instance_valid(controller.get("marketplace_panel")):
			return true
		_attach_panel(host, controller)
		return is_instance_valid(controller.marketplace_panel)
	var saved := {
		"host": controller.get("host"),
		"gear_service": controller.get("gear_service"),
		"gear_transactions": controller.get("gear_transactions"),
		"panel": controller.get("panel"),
		"current_id": controller.get("current_id"),
		"restore_pending": controller.get("restore_pending"),
		"marketplace_enabled": controller.get("marketplace_enabled"),
		"window_focused": controller.get("window_focused"),
	}
	controller.set_script(load(EXT_PATH))
	for key in saved:
		controller.set(key, saved[key])
	controller.listings_store = DanStore.new()
	controller.listings_service = DanService.new()
	controller.listings_transactions = ShopTransaction.new(controller.listings_service.quote_candidate)
	controller.listings_message = ""
	_attach_panel(host, controller)
	_bind_store(host, controller)
	if controller.has_method("refresh_service_metadata"):
		controller.refresh_service_metadata()
	host.set_meta("dan_listings", controller.listings_store)
	host.set_meta("dan_listings_installed", true)
	return is_instance_valid(controller.marketplace_panel)

static func _attach_panel(host: Node, controller) -> void:
	if is_instance_valid(controller.get("marketplace_panel")):
		return
	var panel: Control = DanPanel.new()
	var parent: Node = null
	if is_instance_valid(controller.panel):
		parent = controller.panel.get_parent()
	elif is_instance_valid(host.get("supplies_panel")):
		parent = host.supplies_panel.get_parent()
	if parent == null:
		parent = host
	parent.add_child(panel)
	panel.hide()
	panel.configure({
		"shop_id": "dan",
		"title": "DAN · PLAYER MARKETPLACE",
		"emblem": "▤",
		"role": "Player listings · local board",
		"tabs": ["browse", "my listings", "post", "how it works"],
		"help": "Buy listed goods, post a carried item, or cancel your own listing. Sold listings pay out credits from My listings. Bidding is not in this build.",
	})
	panel.closed.connect(controller.close)
	panel.review_requested.connect(controller.review_listing)
	panel.confirmed.connect(controller.confirm_listing)
	panel.cancelled.connect(controller.cancel_listing)
	panel.tab_changed.connect(controller.on_tab_changed)
	panel.asking_changed.connect(controller.on_asking_changed)
	controller.marketplace_panel = panel

static func _bind_store(host: Node, controller) -> void:
	if controller.listings_store == null:
		controller.listings_store = DanStore.new()
	if controller.listings_service == null:
		controller.listings_service = DanService.new()
	if controller.listings_transactions == null:
		controller.listings_transactions = ShopTransaction.new(controller.listings_service.quote_candidate)
	var save_path := str(host.get("character_save_path"))
	var now := int(Time.get_unix_time_from_system())
	if controller.listings_store.path.is_empty() or (not save_path.is_empty() and controller.listings_store.path != DanStore.sidecar_path(save_path)):
		controller.listings_store.load_or_seed(save_path, now)
	if is_instance_valid(controller.marketplace_panel):
		controller.marketplace_panel.bind_store(controller.listings_store)
	host.set_meta("dan_listings", controller.listings_store)
	host.set_meta("dan_listings_installed", true)

static func load_store(host: Node) -> void:
	if not is_instance_valid(host):
		return
	var controller = host.get("trader_previews")
	if is_instance_valid(controller) and controller.has_method("_ensure_store"):
		controller._ensure_store()
		var save_path := str(host.get("character_save_path"))
		controller.listings_store.load_or_seed(save_path, int(Time.get_unix_time_from_system()))
		host.set_meta("dan_listings", controller.listings_store)
		if controller.has_method("refresh_service_metadata"):
			controller.refresh_service_metadata()
