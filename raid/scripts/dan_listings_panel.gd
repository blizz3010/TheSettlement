extends "res://scripts/shop_panel.gd"
## Item 13: Dan's player marketplace. Reuses the item 16 icon, hero, confirm
## and insufficient-funds layout. Bidding is described as not in this build.
const Icons = preload("res://raid/scripts/trader_buy_icons.gd")
const Store = preload("res://raid/scripts/dan_listings_store.gd")
const Inventory = preload("res://scripts/inventory_state.gd")

signal asking_changed(value: int)

var hero: TextureRect
var asking: SpinBox
var asking_wrap: HBoxContainer
var _store: Store = Store.new()

func _ready():
	super._ready()
	name = "DanListingsPanel"
	hero = Icons.install_hero(self)
	_install_asking()

func _install_asking() -> void:
	if is_instance_valid(asking):
		return
	asking_wrap = HBoxContainer.new()
	asking_wrap.name = "AskingPriceRow"
	asking_wrap.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = "Asking price (each)"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asking_wrap.add_child(label)
	asking = SpinBox.new()
	asking.min_value = 1
	asking.max_value = 9999
	asking.step = 1
	asking.value = 5
	asking.custom_minimum_size = Vector2(120, 34)
	asking.value_changed.connect(func(value: float):
		if _rendering:
			return
		asking_changed.emit(int(value))
		_update_summary()
	)
	asking_wrap.add_child(asking)
	# Sit just above the pinned shop summary so child 0 of summary stays the
	# quantity row that ShopPanel looks up as MaximumQuantity.
	if is_instance_valid(summary) and is_instance_valid(summary.get_parent()):
		var column: Node = summary.get_parent()
		column.add_child(asking_wrap)
		column.move_child(asking_wrap, summary.get_index())
	asking_wrap.visible = false

func bind_store(store: Store) -> void:
	_store = store if store != null else Store.new()

func asking_price() -> int:
	return int(asking.value) if is_instance_valid(asking) else 5

func set_asking_price(value: int) -> void:
	if not is_instance_valid(asking):
		return
	_rendering = true
	asking.value = clampi(value, 1, 9999)
	_rendering = false

func row_action(row: Dictionary = {}) -> String:
	if row.is_empty():
		row = _selected_row()
	if action == "browse":
		return "buy"
	if action == "post":
		return "post"
	if action == "my listings":
		return str(row.get("row_action", ""))
	return ""

func _item_texture(row: Dictionary) -> Texture2D:
	return Icons.texture(str(row.get("icon_item", row.get("item_id", row.get("id", "")))))

func _rebuild_list():
	super._rebuild_list()
	Icons.apply_row_style(self)

func _verb(value: String) -> String:
	if value == "post":
		return "Post"
	if value == "cancel":
		return "Cancel"
	if value == "collect":
		return "Collect"
	return "Buy"

func _review_label(value: String) -> String:
	if value == "post":
		return "Review listing"
	if value == "cancel":
		return "Review cancellation"
	if value == "collect":
		return "Review payout"
	return "Review purchase"

func _review():
	if review_button.disabled or not quote.is_empty():
		return
	quantity.apply()
	if is_instance_valid(asking):
		asking.apply()
	_update_summary()
	if review_button.disabled:
		return
	var row := _selected_row()
	var verb := row_action(row)
	if verb.is_empty():
		return
	review_requested.emit(selected_item, int(quantity.value), verb)

func render_board(plot, inventory, store: Store, pending: Dictionary = {}, message: String = "") -> void:
	bind_store(store)
	if action == "browse":
		render_state(plot, inventory, browse_rows(store, inventory), pending, message)
	elif action == "my listings":
		render_state(plot, inventory, my_rows(store, inventory), pending, message)
	elif action == "post":
		render_state(plot, inventory, post_rows(inventory), pending, message)
	else:
		render_state(plot, inventory, help_rows(), pending, message)

func browse_rows(store: Store, inventory) -> Array:
	var rows: Array = []
	for row in store.active_rows():
		if row.seller_id == Store.PLAYER_SELLER:
			rows.append(_listing_row(row, inventory, "Your listing. Buyers are other settlers on this board. Cancel it from My listings if you want the item back.", false, "That's your listing. Open My listings to cancel it."))
		else:
			rows.append(_listing_row(row, inventory, "Listed by %s, a fellow settler on this local board (not a live network sale)." % row.seller_name, true, ""))
	if rows.is_empty():
		rows.append({
			"id": "board_empty",
			"icon_item": "timber",
			"name": "No listings right now",
			"category": "Board",
			"description": "The board is empty. Post something from the Post tab, or check back after other settlers list goods.",
			"price": null,
			"owned": 0,
			"enabled": false,
			"reason": "Nothing to buy.",
			"max_quantity": 1,
			"space_per_unit": 0,
		})
	return rows

func my_rows(store: Store, inventory) -> Array:
	var rows: Array = []
	for row in store.player_rows():
		if row.status == "active":
			var reason := ""
			var enabled := true
			var room: int = inventory.capacity("carried") - inventory.used("carried")
			if room < int(row.quantity):
				enabled = false
				reason = "Bag full · make %d carried space to cancel and recover this item." % (int(row.quantity) - room)
			rows.append(_listing_row(row, inventory, "Your listing. It stays up until you cancel it or a visiting settler buys it. Cancel returns the item to your carried inventory. Bidding is not in this build.", enabled, reason, "cancel"))
		elif row.status == "sold":
			rows.append({
				"id": row.id,
				"icon_item": row.item_id,
				"item_id": row.item_id,
				"name": "Sold · %s × %d" % [Store.display_name(str(row.item_id)), int(row.quantity)],
				"category": "Payout",
				"description": "%s bought your listing for %d credits. Collect the payout to add it to your balance." % [row.buyer_name, int(row.payout)],
				"price": int(row.payout),
				"owned": 0,
				"enabled": true,
				"reason": "",
				"max_quantity": 1,
				"space_per_unit": 0,
				"row_action": "collect",
				"seller_name": row.seller_name,
			})
	if rows.is_empty():
		rows.append({
			"id": "my_empty",
			"icon_item": "timber",
			"name": "No listings of yours",
			"category": "My listings",
			"description": "You have nothing up on the board and no waiting payouts. Post a carried item from the Post tab.",
			"price": null,
			"owned": 0,
			"enabled": false,
			"reason": "Nothing to cancel or collect.",
			"max_quantity": 1,
			"space_per_unit": 0,
		})
	return rows

func post_rows(inventory) -> Array:
	var rows: Array = []
	var ids: Array = Inventory.ITEMS.keys()
	ids.sort()
	for item_id in ids:
		var owned: int = inventory.amount("carried", item_id)
		var suggested: int = Store.suggested_price(item_id)
		rows.append({
			"id": item_id,
			"icon_item": item_id,
			"item_id": item_id,
			"name": Store.display_name(item_id),
			"category": Store.category_of(item_id),
			"description": "Post from carried inventory at your asking price. The item is reserved on the board until it sells or you cancel. Stash, Lockbox, clothing and equipment stay out of this board.",
			"price": suggested if selected_item != item_id else asking_price(),
			"owned": owned,
			"enabled": owned > 0,
			"reason": "" if owned > 0 else "No carried units. Move some out of the stash first.",
			"max_quantity": maxi(1, owned),
			"space_per_unit": 1,
			"row_action": "post",
		})
	rows.sort_custom(func(a, b):
		if bool(a.get("enabled", false)) != bool(b.get("enabled", false)):
			return bool(a.get("enabled", false))
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return rows

func help_rows() -> Array:
	return [
		{
			"id": "help_board",
			"icon_item": "timber",
			"name": "How the board works",
			"category": "Help",
			"description": "This is Dan's player marketplace. Listings are saved with your hideout on this device. There is no live multiplayer server.\n\nOther names on the board are generic fellow settlers, seeded so the stand is not empty. They are not real people.\n\nPost a carried item at an asking price. Cancel your own listing to get the item back. When a visiting settler buys one of your listings, collect the credits from My listings.\n\nBuying is available now. Bidding is not in this build.",
			"price": null,
			"owned": 0,
			"enabled": false,
			"reason": "Information only.",
			"max_quantity": 1,
			"space_per_unit": 0,
		}
	]

func _listing_row(row: Dictionary, inventory, description: String, enabled: bool, reason: String, row_action_name: String = "buy") -> Dictionary:
	var qty: int = int(row.quantity)
	var total: int = int(row.unit_price) * qty
	var label := Store.display_name(str(row.item_id))
	var name := "%s × %d · %s" % [label, qty, row.seller_name]
	return {
		"id": row.id,
		"icon_item": row.item_id,
		"item_id": row.item_id,
		"name": name,
		"category": Store.category_of(str(row.item_id)),
		"description": description + "\n\n%d credits each · %d credits for the lot." % [int(row.unit_price), total],
		"price": total,
		"owned": inventory.amount("carried", str(row.item_id)),
		"enabled": enabled,
		"reason": reason,
		"max_quantity": 1 if row_action_name != "cancel" else qty,
		"space_per_unit": qty if row_action_name == "buy" else (0 if row_action_name == "cancel" else 1),
		"row_action": row_action_name,
		"seller_name": row.seller_name,
		"unit_price": int(row.unit_price),
		"listing_quantity": qty,
	}

func _update_summary():
	if _rendering or not is_instance_valid(quantity):
		return
	if is_instance_valid(asking_wrap):
		asking_wrap.visible = action == "post" and quote.is_empty()
		if is_instance_valid(asking):
			asking.editable = action == "post" and quote.is_empty()
	var row := _selected_row()
	var verb := row_action(row)
	if action == "post" and not row.is_empty() and quote.is_empty() and is_instance_valid(asking):
		row.price = asking_price()
	var previous := details.text if is_instance_valid(details) else ""
	if verb in ["post", "cancel", "collect"]:
		_update_listing_summary(row, verb)
	else:
		super._update_summary()
	Icons.update_hero(self, row)
	if not row.is_empty() and verb in ["buy", "post"]:
		Icons.apply_details(self, row, previous)
	if is_instance_valid(confirm_button) and not quote.is_empty():
		if quote.action == "post":
			confirm_button.text = "Confirm listing"
		elif quote.action == "cancel":
			confirm_button.text = "Confirm cancellation"
		elif quote.action == "collect":
			confirm_button.text = "Confirm payout"
		else:
			confirm_button.text = "Confirm purchase"

func _update_listing_summary(row: Dictionary, verb: String) -> void:
	var reviewing := not quote.is_empty()
	quantity.editable = not reviewing and not row.is_empty() and verb == "post"
	search.editable = not reviewing
	categories.disabled = reviewing
	clear_filters.disabled = reviewing or (search.text.is_empty() and _category == "All")
	for button in tab_buttons.values():
		button.disabled = reviewing
	for button in category_buttons.get_children():
		button.disabled = reviewing
	if is_instance_valid(summary) and summary.get_child_count() > 0:
		var maximum = summary.get_child(0).get_node_or_null("MaximumQuantity")
		if maximum:
			maximum.disabled = reviewing or row.is_empty() or not row.get("enabled", false) or verb != "post"
	confirmation.visible = reviewing
	review_button.visible = not reviewing
	confirm_button.disabled = not reviewing
	cancel_button.disabled = not reviewing
	if row.is_empty():
		details.text = str(shop_definition.get("help", "Choose a listing or an item to post."))
		totals.text = "Choose an item"
		review_button.text = _review_label(verb if not verb.is_empty() else action)
		review_button.disabled = true
		return
	details.text = str(row.name) + "\n\n" + str(row.get("description", ""))
	var reason := str(row.get("reason", ""))
	_rendering = true
	quantity.max_value = int(row.get("max_quantity", 8))
	if verb != "post":
		quantity.value = 1 if verb == "collect" else int(row.get("listing_quantity", row.get("max_quantity", 1)))
	_rendering = false
	var valid := bool(row.get("enabled", false)) and row.get("price") != null
	var count: int = int(quantity.value)
	if verb == "post":
		var unit: int = asking_price()
		var after_carried: int = _inventory.used("carried") - count
		if int(row.get("owned", 0)) < count:
			valid = false
			reason = "Not enough carried units. Stash and Lockbox stay at home."
		elif after_carried < 0:
			valid = false
			reason = "Not enough carried units."
		totals.text = "%d credits asking · %d total\nAfter: %d credits · Carried %d / %d" % [unit, unit * count, _plot.credits, after_carried, _inventory.capacity("carried")]
		review_button.text = _review_label("post")
		review_button.tooltip_text = "%d %s · %d credits asking" % [count, row.name, unit * count]
	elif verb == "cancel":
		var after_carried: int = _inventory.used("carried") + int(row.get("listing_quantity", count))
		if after_carried > _inventory.capacity("carried"):
			valid = false
			reason = "Bag full · make %d carried space to recover this listing." % (after_carried - _inventory.capacity("carried"))
		totals.text = "Item returns to you. No credits change.\nAfter: %d credits · Carried %d / %d" % [_plot.credits, after_carried, _inventory.capacity("carried")]
		review_button.text = _review_label("cancel")
	elif verb == "collect":
		var total: int = int(row.price)
		var after: int = _plot.credits + total
		if after > 100000:
			valid = false
			reason = "Credit limit is 100,000."
		totals.text = "%d credits payout\nAfter: %d credits · Carried %d / %d" % [total, after, _inventory.used("carried"), _inventory.capacity("carried")]
		review_button.text = _review_label("collect")
	else:
		totals.text = reason
		review_button.text = "Unavailable"
	if not reason.is_empty():
		details.text += "\n\n" + reason
	review_button.disabled = not valid
	if reviewing:
		if quote.action == "post":
			totals.text = "Post %d %s · %d credits asking\nAfter: %d credits · Carried %d / %d" % [quote.quantity, quote.get("name", row.name), quote.total, quote.balance_after, quote.carried_after, quote.capacity]
			confirm_button.text = "Confirm listing"
		elif quote.action == "cancel":
			totals.text = "Cancel %s\nAfter: %d credits · Carried %d / %d" % [quote.get("name", row.name), quote.balance_after, quote.carried_after, quote.capacity]
			confirm_button.text = "Confirm cancellation"
		else:
			totals.text = "Collect %d credits from %s\nAfter: %d credits · Carried %d / %d" % [quote.total, quote.get("name", row.name), quote.balance_after, quote.carried_after, quote.capacity]
			confirm_button.text = "Confirm payout"
