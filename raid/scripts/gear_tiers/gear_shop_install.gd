extends RefCounted
## TASKS item 22, PR C installer. Runs after Atlas's installer and extends its
## controller script, so Dan, Atlas and Psy all keep working. Safe to call twice.
## Also counts successful extractions into the gear sidecar (Psy's unlock rules).
const ATLAS_EXT := "res://raid/scripts/atlas_recovery_controller_ext.gd"
const EXT_PATH := "res://raid/scripts/gear_tiers/psy_gear_controller_ext.gd"
const GearPanel = preload("res://raid/scripts/gear_tiers/psy_gear_tier_panel.gd")
const GearStore = preload("res://raid/scripts/gear_tiers/gear_locker_store.gd")
const GearService = preload("res://raid/scripts/gear_tiers/gear_shop_service.gd")
const ShopTransaction = preload("res://scripts/shop_transaction.gd")
const CARRY := ["host", "gear_service", "gear_transactions", "panel", "current_id", "restore_pending",
	"marketplace_enabled", "window_focused", "marketplace_panel", "listings_store", "listings_service",
	"listings_transactions", "listings_message", "recovery_panel", "recovery_store", "recovery_service",
	"recovery_transactions", "recovery_message"]

static func _script_path(node) -> String:
	if not is_instance_valid(node) or node.get_script() == null: return ""
	return str(node.get_script().resource_path)

static func install(host: Node) -> bool:
	if host == null or not is_instance_valid(host): return false
	var controller = host.get("trader_previews")
	if not is_instance_valid(controller): return false
	if not preload("res://raid/scripts/controller_chain.gd").inherits(controller, EXT_PATH):
		if _script_path(controller) != ATLAS_EXT: return false
		var saved := {}
		for key in CARRY: saved[key] = controller.get(key)
		controller.set_script(load(EXT_PATH))
		for key in saved: controller.set(key, saved[key])
		controller.refresh_service_metadata()
	if not is_instance_valid(controller.tier_panel): _attach_panel(host, controller)
	host.set_meta("gear_shop_installed", true)
	return is_instance_valid(controller.tier_panel)

static func _attach_panel(host: Node, controller) -> void:
	var panel: Control = GearPanel.new()
	var parent: Node = null
	if is_instance_valid(controller.panel): parent = controller.panel.get_parent()
	elif is_instance_valid(host.get("supplies_panel")): parent = host.supplies_panel.get_parent()
	if parent == null: parent = host
	parent.add_child(panel)
	panel.hide()
	panel.configure({
		"shop_id": "psy",
		"title": "PSY · GEAR & ARMOR",
		"emblem": "◇",
		"role": "Tiered gear 1-4 · buy, sell, repair, upgrade, equip",
		"tabs": ["buy", "sell", "repair", "upgrade", "equip"],
		"help": "Tiered gear goes to your gear locker and is used in raids when equipped. Tier 2 unlocks after your first extraction, tier 3 after 5 extractions and the Stock III licence, and tier 4 is rare. Gear found in raid caches lands in your locker worn; repair it here. The basic T0 helmet is still sold here.",
		"sale_help": "Only unequipped, unbroken tier gear and carried T0 helmets can be sold. Sells at 50%.",
	})
	panel.closed.connect(controller.close)
	panel.review_requested.connect(controller.review_tier)
	panel.confirmed.connect(controller.confirm_tier)
	panel.cancelled.connect(controller.cancel_tier)
	panel.tab_changed.connect(controller.on_tier_tab_changed)
	controller.tier_panel = panel

## Reload the sidecar (after a load_game).
static func load_store(host: Node) -> void:
	var controller = host.get("trader_previews") if is_instance_valid(host) else null
	if is_instance_valid(controller) and preload("res://raid/scripts/controller_chain.gd").inherits(controller, EXT_PATH):
		controller.gear_store = null
		controller.ensure_gear_store()

## Counts a successful extraction in the gear sidecar. Downed raids don't count.
## Found gear and composite inserts are granted by raid_loot_install.apply_return (PR F).
static func apply_return(host: Node, outcome: Dictionary, path: String = GearStore.DEFAULT_PATH) -> bool:
	if str(outcome.get("outcome", "")) != "extracted": return false
	var store := GearStore.new()
	store.load_locker(path)
	store.state.extractions += 1
	var ok := store.save()
	var controller = host.get("trader_previews") if is_instance_valid(host) else null
	if ok and is_instance_valid(controller) and preload("res://raid/scripts/controller_chain.gd").inherits(controller, EXT_PATH) and controller.gear_store != null:
		controller.gear_store.state.extractions = store.state.extractions
	return ok
