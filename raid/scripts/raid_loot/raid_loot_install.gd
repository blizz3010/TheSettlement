extends RefCounted
## TASKS item 13 installer. Runs after the Psy tier installer and extends its
## controller, swapping Atlas's panel for one with a Salvage tab. Safe to call twice.
## apply_return() brings an extracted raid's haul home (or records a lost haul).
const GEAR_EXT := "res://raid/scripts/gear_tiers/psy_gear_controller_ext.gd"
const EXT_PATH := "res://raid/scripts/raid_loot/raid_loot_controller_ext.gd"
const PANEL_PATH := "res://raid/scripts/raid_loot/atlas_salvage_panel.gd"
const SalvagePanel = preload("res://raid/scripts/raid_loot/atlas_salvage_panel.gd")
const HaulStore = preload("res://raid/scripts/raid_loot/raid_loot_store.gd")
const LootService = preload("res://raid/scripts/raid_loot/raid_loot_service.gd")
const LootTable = preload("res://raid/scripts/raid_loot/loot_table.gd")
const ShopTransaction = preload("res://scripts/shop_transaction.gd")
const SaveCodec = preload("res://scripts/save_codec.gd")
const Chain = preload("res://raid/scripts/controller_chain.gd")
const GearStore = preload("res://raid/scripts/gear_tiers/gear_locker_store.gd")
const CARRY := ["host", "gear_service", "gear_transactions", "panel", "current_id", "restore_pending",
	"marketplace_enabled", "window_focused", "marketplace_panel", "listings_store", "listings_service",
	"listings_transactions", "listings_message", "recovery_panel", "recovery_store", "recovery_service",
	"recovery_transactions", "recovery_message", "tier_panel", "gear_store", "tier_service",
	"tier_transactions", "tier_message"]
const ATLAS_DEFINITION := {
	"shop_id": "atlas",
	"title": "ATLAS · RECOVERY & SALVAGE",
	"emblem": "▣",
	"role": "Item recovery · raid salvage buyer · overflow cargo",
	"tabs": ["recover", "salvage", "how it works"],
	"help": "Recover carried supplies lost when you were downed, sell raid salvage for credits, and claim raid materials that did not fit your bag or stash.",
}

static func _script_path(node) -> String:
	if not is_instance_valid(node) or node.get_script() == null: return ""
	return str(node.get_script().resource_path)

static func install(host: Node) -> bool:
	if host == null or not is_instance_valid(host): return false
	var controller = host.get("trader_previews")
	if not is_instance_valid(controller): return false
	if _script_path(controller) != EXT_PATH:
		if _script_path(controller) != GEAR_EXT: return false
		var saved := {}
		for key in CARRY: saved[key] = controller.get(key)
		controller.set_script(load(EXT_PATH))
		for key in saved: controller.set(key, saved[key])
		controller.loot_message = ""
	_swap_panel(host, controller)
	controller.ensure_haul_store()
	controller.refresh_service_metadata()
	host.set_meta("raid_loot_installed", true)
	return _script_path(controller.recovery_panel) == PANEL_PATH

static func _swap_panel(host: Node, controller) -> void:
	var old = controller.get("recovery_panel")
	if _script_path(old) == PANEL_PATH: return
	var parent: Node = null
	var index := -1
	if is_instance_valid(old):
		parent = old.get_parent()
		index = old.get_index()
	elif is_instance_valid(controller.get("marketplace_panel")):
		parent = controller.marketplace_panel.get_parent()
	if parent == null: parent = host
	var panel: Control = SalvagePanel.new()
	parent.add_child(panel)
	if index >= 0: parent.move_child(panel, index)
	panel.hide()
	panel.configure(ATLAS_DEFINITION)
	panel.closed.connect(controller.close)
	panel.review_requested.connect(controller.review_recovery)
	panel.confirmed.connect(controller.confirm_recovery)
	panel.cancelled.connect(controller.cancel_recovery)
	panel.tab_changed.connect(controller.on_recovery_tab_changed)
	if controller.get("recovery_store") != null: panel.bind_store(controller.recovery_store)
	controller.recovery_panel = panel
	if is_instance_valid(old):
		old.hide()
		old.queue_free()

## Reload the sidecar (after a load_game).
static func load_store(host: Node) -> void:
	var controller = host.get("trader_previews") if is_instance_valid(host) else null
	if is_instance_valid(controller) and Chain.inherits(controller, EXT_PATH):
		controller.ensure_haul_store(true)

## Applies a raid return. Extracted: haul goes home (bag, stash, Atlas cargo,
## salvage). Downed: nothing comes home; only the lifetime stat changes.
## Returns a player-facing note ("" if nothing to say).
## Gear PR F: found gear and composite inserts go into the gear locker sidecar (gear_path).
static func apply_return(host: Node, outcome: Dictionary, gear_path: String = GearStore.DEFAULT_PATH) -> String:
	if host == null or not is_instance_valid(host): return ""
	var kind := str(outcome.get("outcome", ""))
	if not kind in ["extracted", "downed"]: return ""
	var store := HaulStore.new()
	store.load_or_create(str(host.get("character_save_path")))
	var service := LootService.new()
	if kind == "downed":
		var lost: Dictionary = service.record_loss(store, outcome)
		if not lost.is_empty() and store.restore(lost.haul): store.save()
		_sync(host, store)
		return ""
	if not outcome.has("haul"): return ""
	# Gear PR F: the locker is only read (and written) when the haul holds gear or parts.
	var gear_store: GearStore = null
	var locker_before: Dictionary = {}
	var with_gear: Dictionary = outcome.duplicate()
	if _has_gear(outcome.get("haul")):
		gear_store = GearStore.new()
		if FileAccess.file_exists(gear_path): gear_store.load_locker(gear_path)
		else: gear_store.path = gear_path
		locker_before = gear_store.state.data()
		with_gear["locker_free"] = gear_store.state.free_space()
	var candidate: Dictionary = service.deposit(host.state, host.inventory, host.request, store, with_gear)
	if candidate.is_empty():
		return "" if service.last_error.contains("already") else "Your raid haul could not be brought home: " + service.last_error
	if gear_store != null:
		var receipt: Dictionary = candidate.receipt
		for key in receipt.get("to_gear", {}):
			var g := LootTable.parse_gear(str(key))
			for _n in int(receipt.to_gear[key]): gear_store.state.grant_found(str(g.def), int(g.condition))
		for key in receipt.get("to_parts", {}): gear_store.state.add_parts(int(receipt.to_parts[key]))
		if not gear_store.save():
			gear_store.state.restore(locker_before)
			return "Your raid haul could not be saved (gear locker). Nothing changed."
	var previous: Dictionary = store.snapshot()
	if not store.restore(candidate.haul) or not store.save():
		store.restore(previous)
		_undo_locker(gear_store, locker_before)
		return "Your raid haul could not be saved. Nothing changed."
	if host.has_method("save_payload"):
		var payload: Dictionary = SaveCodec.encode(candidate.plot, candidate.inventory, candidate.request, host.craft, host.onboarding, host.fishing)
		if not host.save_payload(payload, false):
			store.restore(previous)
			store.save()
			_undo_locker(gear_store, locker_before)
			return "Your raid haul could not be saved. Nothing changed."
	host.state = candidate.plot
	host.inventory = candidate.inventory
	host.request = candidate.request
	_sync(host, store)
	if gear_store != null: _sync_gear(host, gear_store)
	return str(candidate.receipt.get("message", ""))

static func _has_gear(haul: Variant) -> bool:
	if not haul is Dictionary: return false
	for id in haul:
		if LootTable.is_gear(str(id)) or LootTable.is_part(str(id)): return true
	return false

static func _undo_locker(gear_store: GearStore, before: Dictionary) -> void:
	if gear_store == null: return
	gear_store.state.restore(before)
	gear_store.save()

## Psy re-reads the sidecar on every visit; keep a live copy in step anyway.
static func _sync_gear(host: Node, gear_store: GearStore) -> void:
	var controller = host.get("trader_previews")
	if is_instance_valid(controller) and controller.get("gear_store") != null:
		controller.gear_store.state.restore(gear_store.state.data())

static func _sync(host: Node, store: HaulStore) -> void:
	var controller = host.get("trader_previews")
	if is_instance_valid(controller) and Chain.inherits(controller, EXT_PATH) and controller.haul_store != null:
		controller.haul_store.restore(store.snapshot())
