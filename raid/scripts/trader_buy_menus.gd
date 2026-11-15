extends RefCounted
## Item 16 installer. Swaps the four specialist buy-menu panels into the live
## settlement without editing pinned scripts. Safe to call twice.
const Icons = preload("res://raid/scripts/trader_buy_icons.gd")
const RookPanel = preload("res://raid/scripts/rook_buy_menu_panel.gd")
const TailorPanel = preload("res://raid/scripts/tailor_buy_menu_panel.gd")
const PsyPanel = preload("res://raid/scripts/psy_buy_menu_panel.gd")
const FishingPanel = preload("res://raid/scripts/fishing_buy_menu_panel.gd")
const FishingTransaction = preload("res://raid/scripts/fishing_supply_transaction_ext.gd")

const ROOK_PATH := "res://raid/scripts/rook_buy_menu_panel.gd"
const TAILOR_PATH := "res://raid/scripts/tailor_buy_menu_panel.gd"
const PSY_PATH := "res://raid/scripts/psy_buy_menu_panel.gd"
const FISHING_PATH := "res://raid/scripts/fishing_buy_menu_panel.gd"

static func _script_path(node) -> String:
	if not is_instance_valid(node) or node.get_script() == null:
		return ""
	return str(node.get_script().resource_path)

static func install(host: Node) -> Dictionary:
	var result := {"rook": false, "tailor": false, "psy": false, "fishing": false}
	if host == null or not is_instance_valid(host):
		return result
	if _script_path(host.get("supplies_panel")) != ROOK_PATH and is_instance_valid(host.get("supplies_panel")):
		result.rook = _install_rook(host)
	elif _script_path(host.get("supplies_panel")) == ROOK_PATH:
		result.rook = true
	if _script_path(host.get("clothing_panel")) != TAILOR_PATH and is_instance_valid(host.get("clothing_panel")):
		result.tailor = _install_tailor(host)
	elif _script_path(host.get("clothing_panel")) == TAILOR_PATH:
		result.tailor = true
	if is_instance_valid(host.get("trader_previews")):
		var panel = host.trader_previews.panel
		if _script_path(panel) != PSY_PATH and is_instance_valid(panel):
			result.psy = _install_psy(host)
		elif _script_path(panel) == PSY_PATH:
			result.psy = true
	if is_instance_valid(host.get("fishing_trader")):
		var panel = host.fishing_trader.panel
		if _script_path(panel) != FISHING_PATH and is_instance_valid(panel):
			result.fishing = _install_fishing(host)
		elif _script_path(panel) == FISHING_PATH:
			result.fishing = true
	host.set_meta("trader_buy_menus", result)
	return result

static func _swap(old_panel: Control, new_panel: Control) -> Control:
	var parent: Node = old_panel.get_parent()
	var idx: int = old_panel.get_index()
	parent.add_child(new_panel)
	parent.move_child(new_panel, idx)
	old_panel.queue_free()
	return new_panel

static func _install_rook(host: Node) -> bool:
	var old: Control = host.supplies_panel
	var panel: Control = RookPanel.new()
	_swap(old, panel)
	panel.review_requested.connect(host.select_supply)
	panel.tab_changed.connect(host.change_supply_tab)
	panel.confirmed.connect(host.confirm_supply)
	panel.cancelled.connect(host.cancel_supply)
	panel.closed.connect(host.close_supplies)
	host.supplies_panel = panel
	return true

static func _install_tailor(host: Node) -> bool:
	var old: Control = host.clothing_panel
	var panel: Control = TailorPanel.new()
	_swap(old, panel)
	panel.action_requested.connect(host.clothing_action)
	panel.closed.connect(host.close_clothing)
	panel.review_requested.connect(host.tailor_shop_review)
	panel.confirmed.connect(host.tailor_shop_confirm)
	panel.cancelled.connect(host.tailor_shop_cancel)
	host.clothing_panel = panel
	return true

static func _install_psy(host: Node) -> bool:
	var controller = host.trader_previews
	var old: Control = controller.panel
	var panel: Control = PsyPanel.new()
	_swap(old, panel)
	panel.closed.connect(controller.close)
	panel.review_requested.connect(controller.review_gear)
	panel.confirmed.connect(controller.confirm_gear)
	panel.cancelled.connect(controller.cancel_gear)
	controller.panel = panel
	return true

static func _install_fishing(host: Node) -> bool:
	var controller = host.fishing_trader
	var old: Control = controller.panel
	var panel: Control = FishingPanel.new()
	var transaction = FishingTransaction.new()
	_swap(old, panel)
	controller.transaction = transaction
	controller.token = 0
	panel.selected.connect(func(item: String):
		if not controller.eligible():
			controller.close()
			return
		var qty := 1
		if is_instance_valid(panel.quantity):
			qty = int(panel.quantity.value)
		controller.token = controller.transaction.select(item, controller.host.state, controller.host.inventory, qty)
		controller.refresh(controller.transaction.last_error)
		if controller.token != 0:
			panel.cancel_button.grab_focus()
	)
	panel.confirmed.connect(controller.confirm_purchase)
	panel.cancelled.connect(controller.cancel)
	panel.closed.connect(controller.close)
	controller.panel = panel
	return true
