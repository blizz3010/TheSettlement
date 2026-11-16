extends RefCounted
## Pure candidate builder for Dan's player listings. Never writes files or
## publishes live state. Bidding is not offered in this build.
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Request = preload("res://scripts/request_state.gd")
const Store = preload("res://raid/scripts/dan_listings_store.gd")

var last_error := ""

func fail(reason: String) -> Dictionary:
	last_error = reason
	return {}

func quote_candidate(shop_id: String, action: String, item: String, quantity: Variant, plot, inventory, request, context: Dictionary = {}) -> Dictionary:
	last_error = ""
	if shop_id != "dan" or not action in ["buy", "post", "cancel", "collect"]:
		return fail("Choose Dan's marketplace service.")
	if action == "buy":
		return _buy(item, quantity, plot, inventory, request, context)
	if action == "post":
		return _post(item, quantity, plot, inventory, request, context)
	if action == "cancel":
		return _cancel(item, quantity, plot, inventory, request, context)
	return _collect(item, quantity, plot, inventory, request, context)

func _clone(plot, inventory, request, context: Dictionary):
	var p = Plot.new()
	var i = Inventory.new()
	var r = Request.new()
	var store = Store.new()
	if not p.restore(plot.data()) or not i.restore(inventory.data()) or not r.restore(request.data()):
		return [fail("Current save state is invalid. Nothing changed."), null, null, null, null]
	if not store.restore(context.get("listings", {})):
		return [fail("Marketplace listings are invalid. Nothing changed."), null, null, null, null]
	if "sale_delay_sec" in context:
		store.sale_delay_sec = int(context.sale_delay_sec)
	return [{}, p, i, r, store]

func _validated(p, i, r, store, receipt: Dictionary) -> Dictionary:
	if not Plot.new().restore(p.data()) or not Inventory.new().restore(i.data()) or not Request.new().restore(r.data()):
		return fail("Trade validation failed. Nothing changed.")
	if not Store.new().restore(store.data()):
		return fail("Listing validation failed. Nothing changed.")
	return {"plot": p, "inventory": i, "request": r, "listings": store.data(), "receipt": receipt}

func _receipt(action: String, item: String, name: String, quantity: int, unit_price: int, total: int, p, i, extra: Dictionary = {}) -> Dictionary:
	var receipt := {
		"shop_id": "dan",
		"action": action,
		"item": item,
		"name": name,
		"quantity": quantity,
		"unit_price": unit_price,
		"total": total,
		"balance_after": p.credits,
		"carried_after": i.used("carried"),
		"capacity": i.capacity("carried"),
	}
	for key in extra:
		receipt[key] = extra[key]
	return receipt

func _take_carried(inventory, item_id: String, quantity: int) -> bool:
	if inventory.amount("carried", item_id) < quantity:
		return false
	inventory.carried[item_id] = inventory.amount("carried", item_id) - quantity
	if inventory.carried[item_id] == 0:
		inventory.carried.erase(item_id)
	return true

func _give_carried(inventory, item_id: String, quantity: int) -> bool:
	if quantity > inventory.capacity("carried") - inventory.used("carried"):
		return false
	inventory.carried[item_id] = inventory.amount("carried", item_id) + quantity
	return true

func _now(context: Dictionary) -> int:
	return int(context.get("now_unix", 0))

func _buy(item: String, quantity: Variant, plot, inventory, request, context: Dictionary) -> Dictionary:
	var packed = _clone(plot, inventory, request, context)
	if packed[1] == null:
		return packed[0]
	var p = packed[1]
	var i = packed[2]
	var r = packed[3]
	var store: Store = packed[4]
	var row: Dictionary = store.find(item)
	if row.is_empty() or row.status != "active":
		return fail("That listing is no longer available.")
	if not quantity is int or quantity != int(row.quantity):
		return fail("Buy the full listing quantity.")
	if row.seller_id == Store.PLAYER_SELLER:
		return fail("That's your listing. Cancel it from My listings if you want it back.")
	var total: int = int(row.unit_price) * int(row.quantity)
	if p.credits < total:
		return fail("Not enough settlement credits. Nothing purchased.")
	if not _give_carried(i, str(row.item_id), int(row.quantity)):
		return fail("Bag full · make %d carried space." % (int(row.quantity) - (i.capacity("carried") - i.used("carried"))))
	p.credits -= total
	row.status = "sold"
	row.sold_unix = _now(context)
	row.buyer_name = Store.PLAYER_NAME
	row.payout = 0
	i.reconcile_hotbar()
	var name := "%s × %d" % [Store.display_name(str(row.item_id)), int(row.quantity)]
	return _validated(p, i, r, store, _receipt("buy", item, name, int(row.quantity), int(row.unit_price), total, p, i, {
		"listing_id": row.id,
		"item_id": row.item_id,
		"seller_name": row.seller_name,
	}))

func _post(item: String, quantity: Variant, plot, inventory, request, context: Dictionary) -> Dictionary:
	var packed = _clone(plot, inventory, request, context)
	if packed[1] == null:
		return packed[0]
	var p = packed[1]
	var i = packed[2]
	var r = packed[3]
	var store: Store = packed[4]
	if not Inventory.ITEMS.has(item):
		return fail("That item cannot be listed.")
	if not quantity is int or quantity < 1 or quantity > Inventory.CAPACITIES.carried:
		return fail("Choose a whole quantity from 1 to 8.")
	var asking = context.get("asking_price", Store.suggested_price(item))
	if not asking is int or asking < 1 or asking > 9999:
		return fail("Choose an asking price from 1 to 9,999 credits.")
	if not _take_carried(i, item, quantity):
		return fail("Not enough carried units. Stash and Lockbox stay at home.")
	i.reconcile_hotbar()
	var row: Dictionary = store.add_listing(Store.PLAYER_SELLER, Store.PLAYER_NAME, item, quantity, int(asking), _now(context))
	var total: int = int(asking) * quantity
	var name := "%s × %d" % [Store.display_name(item), quantity]
	return _validated(p, i, r, store, _receipt("post", item, name, quantity, int(asking), total, p, i, {
		"listing_id": row.id,
		"item_id": item,
	}))

func _cancel(item: String, quantity: Variant, plot, inventory, request, context: Dictionary) -> Dictionary:
	var packed = _clone(plot, inventory, request, context)
	if packed[1] == null:
		return packed[0]
	var p = packed[1]
	var i = packed[2]
	var r = packed[3]
	var store: Store = packed[4]
	var row: Dictionary = store.find(item)
	if row.is_empty() or row.seller_id != Store.PLAYER_SELLER or row.status != "active":
		return fail("You have no active listing with that id.")
	if not quantity is int or quantity != int(row.quantity):
		return fail("Cancel returns the full listed quantity.")
	if not _give_carried(i, str(row.item_id), int(row.quantity)):
		return fail("Bag full · make %d carried space to recover this listing." % (int(row.quantity) - (i.capacity("carried") - i.used("carried"))))
	row.status = "cancelled"
	i.reconcile_hotbar()
	var name := "%s × %d" % [Store.display_name(str(row.item_id)), int(row.quantity)]
	return _validated(p, i, r, store, _receipt("cancel", item, name, int(row.quantity), 0, 0, p, i, {
		"listing_id": row.id,
		"item_id": row.item_id,
	}))

func _collect(item: String, quantity: Variant, plot, inventory, request, context: Dictionary) -> Dictionary:
	var packed = _clone(plot, inventory, request, context)
	if packed[1] == null:
		return packed[0]
	var p = packed[1]
	var i = packed[2]
	var r = packed[3]
	var store: Store = packed[4]
	if item == "payout_all":
		if not quantity is int or quantity != 1:
			return fail("Collect the waiting payout as one total.")
		var pending: Array = store.pending_payouts()
		if pending.is_empty():
			return fail("You have no sold listings waiting to pay out.")
		var total := 0
		var names: PackedStringArray = []
		for row in pending:
			total += int(row.payout)
			row.status = "collected"
			names.append("%s × %d" % [Store.display_name(str(row.item_id)), int(row.quantity)])
		if p.credits > 100000 - total:
			return fail("Credit limit reached. Nothing collected.")
		p.credits += total
		return _validated(p, i, r, store, _receipt("collect", item, "Marketplace payout", 1, total, total, p, i, {
			"listing_id": "payout_all",
			"sold_names": ", ".join(names),
		}))
	var row: Dictionary = store.find(item)
	if row.is_empty() or row.seller_id != Store.PLAYER_SELLER or row.status != "sold":
		return fail("That sale has no waiting payout.")
	if not quantity is int or quantity != 1:
		return fail("Collect the payout as one total.")
	var total: int = int(row.payout)
	if p.credits > 100000 - total:
		return fail("Credit limit reached. Nothing collected.")
	p.credits += total
	row.status = "collected"
	var name := "%s × %d" % [Store.display_name(str(row.item_id)), int(row.quantity)]
	return _validated(p, i, r, store, _receipt("collect", item, name, 1, total, total, p, i, {
		"listing_id": row.id,
		"item_id": row.item_id,
		"buyer_name": row.buyer_name,
	}))
