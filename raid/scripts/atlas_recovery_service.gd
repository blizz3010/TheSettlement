extends RefCounted
## Pure candidate builder for Atlas recovery. Never writes files or publishes live state.
## Raid field loot still does not persist; this only holds carried stacks lost on a downed return.
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Request = preload("res://scripts/request_state.gd")
const Store = preload("res://raid/scripts/atlas_recovery_store.gd")

var last_error := ""

func fail(reason: String) -> Dictionary:
	last_error = reason
	return {}

func _clone(plot, inventory, request, context: Dictionary):
	var p = Plot.new()
	var i = Inventory.new()
	var r = Request.new()
	var store = Store.new()
	if not p.restore(plot.data()) or not i.restore(inventory.data()) or not r.restore(request.data()):
		return [fail("Current save state is invalid. Nothing changed."), null, null, null, null]
	if not store.restore(context.get("recovery", {})):
		return [fail("Atlas recovery records are invalid. Nothing changed."), null, null, null, null]
	if "wait_sec" in context:
		store.wait_sec = int(context.wait_sec)
	if "expire_after_raids" in context:
		store.expire_after_raids = int(context.expire_after_raids)
	return [{}, p, i, r, store]

func _validated(p, i, r, store, receipt: Dictionary) -> Dictionary:
	if not Plot.new().restore(p.data()) or not Inventory.new().restore(i.data()) or not Request.new().restore(r.data()):
		return fail("Trade validation failed. Nothing changed.")
	if not Store.new().restore(store.data()):
		return fail("Recovery validation failed. Nothing changed.")
	return {"plot": p, "inventory": i, "request": r, "recovery": store.data(), "receipt": receipt}

func _promote(inventory, item_id: String) -> void:
	if item_id in Inventory.PRODUCTION_SUPPLIES:
		inventory.format_version = maxi(inventory.format_version, 10)
	elif item_id in Inventory.FISHING_SUPPLIES:
		inventory.format_version = maxi(inventory.format_version, 9)

func _give_carried(inventory, item_id: String, quantity: int) -> bool:
	if quantity > inventory.capacity("carried") - inventory.used("carried"):
		return false
	_promote(inventory, item_id)
	inventory.carried[item_id] = inventory.amount("carried", item_id) + quantity
	return true

func quote_candidate(shop_id: String, action: String, item: String, quantity: Variant, plot, inventory, request, context: Dictionary = {}) -> Dictionary:
	last_error = ""
	if shop_id != "atlas" or action != "recover":
		return fail("Choose Atlas's recovery service.")
	return _recover(item, quantity, plot, inventory, request, context)

func intake(plot, inventory, request, store: Store, context: Dictionary = {}) -> Dictionary:
	last_error = ""
	var packed = _clone(plot, inventory, request, {"recovery": store.snapshot(), "wait_sec": int(context.get("wait_sec", store.wait_sec)), "expire_after_raids": int(context.get("expire_after_raids", store.expire_after_raids))})
	if packed[1] == null:
		return packed[0]
	var p = packed[1]
	var i = packed[2]
	var r = packed[3]
	var next: Store = packed[4]
	var now := int(context.get("now_unix", 0))
	next.tick_raid()
	next.resolve(now)
	var taken: Array = []
	var ids: Array = i.carried.keys()
	ids.sort()
	for item_id in ids:
		var qty: int = i.amount("carried", str(item_id))
		if qty < 1 or not Inventory.ITEMS.has(str(item_id)):
			continue
		i.carried.erase(str(item_id))
		var row: Dictionary = next.add_entry(str(item_id), qty, str(context.get("map", "")), str(context.get("source", "")), now)
		taken.append(row.duplicate(true))
	i.reconcile_hotbar()
	var names: PackedStringArray = []
	for row in taken:
		names.append("%s × %d" % [Store.display_name(str(row.item_id)), int(row.quantity)])
	var message := ""
	if names.is_empty():
		message = "You carried nothing into the raid, so Atlas has nothing to hold."
	else:
		message = "Atlas is holding " + ", ".join(names) + ". Pay to recover them at his stand before they expire."
	return _validated(p, i, r, next, {
		"shop_id": "atlas",
		"action": "intake",
		"item": "intake",
		"name": "Raid recovery intake",
		"quantity": taken.size(),
		"unit_price": 0,
		"total": 0,
		"balance_after": p.credits,
		"carried_after": i.used("carried"),
		"capacity": i.capacity("carried"),
		"taken": taken,
		"message": message,
	})

func tick_raids(plot, inventory, request, store: Store, context: Dictionary = {}) -> Dictionary:
	last_error = ""
	var packed = _clone(plot, inventory, request, {"recovery": store.snapshot(), "wait_sec": int(context.get("wait_sec", store.wait_sec)), "expire_after_raids": int(context.get("expire_after_raids", store.expire_after_raids))})
	if packed[1] == null:
		return packed[0]
	var p = packed[1]
	var i = packed[2]
	var r = packed[3]
	var next: Store = packed[4]
	var now := int(context.get("now_unix", 0))
	next.tick_raid()
	var resolved: Dictionary = next.resolve(now)
	var expired: Array = resolved.get("expired", [])
	var message := ""
	if not expired.is_empty():
		var names: PackedStringArray = []
		for row in expired:
			names.append("%s × %d" % [Store.display_name(str(row.item_id)), int(row.quantity)])
		message = "Unclaimed recovery expired: " + ", ".join(names) + "."
	return _validated(p, i, r, next, {
		"shop_id": "atlas",
		"action": "tick",
		"item": "tick",
		"name": "Raid recovery tick",
		"quantity": 1,
		"unit_price": 0,
		"total": 0,
		"balance_after": p.credits,
		"carried_after": i.used("carried"),
		"capacity": i.capacity("carried"),
		"expired": expired,
		"message": message,
	})

func _recover(item: String, quantity: Variant, plot, inventory, request, context: Dictionary) -> Dictionary:
	var packed = _clone(plot, inventory, request, context)
	if packed[1] == null:
		return packed[0]
	var p = packed[1]
	var i = packed[2]
	var r = packed[3]
	var store: Store = packed[4]
	store.resolve(int(context.get("now_unix", 0)))
	var row: Dictionary = store.find(item)
	if row.is_empty() or row.status == "expired":
		return fail("That recovery entry is no longer available.")
	if row.status == "holding":
		return fail("Atlas is still preparing this recovery. Check back in a moment.")
	if row.status != "ready":
		return fail("That item has already been recovered.")
	if not quantity is int or quantity != 1:
		return fail("Recover the held lot as one payment.")
	var total: int = int(row.unit_fee) * int(row.quantity)
	if p.credits < total:
		return fail("Not enough settlement credits. Nothing recovered.")
	if not _give_carried(i, str(row.item_id), int(row.quantity)):
		return fail("Bag full · make %d carried space." % (int(row.quantity) - (i.capacity("carried") - i.used("carried"))))
	p.credits -= total
	row.status = "recovered"
	i.reconcile_hotbar()
	var name := "%s × %d" % [Store.display_name(str(row.item_id)), int(row.quantity)]
	return _validated(p, i, r, store, {
		"shop_id": "atlas",
		"action": "recover",
		"item": item,
		"name": name,
		"quantity": 1,
		"unit_price": total,
		"total": total,
		"balance_after": p.credits,
		"carried_after": i.used("carried"),
		"capacity": i.capacity("carried"),
		"item_id": row.item_id,
		"listing_quantity": int(row.quantity),
	})
