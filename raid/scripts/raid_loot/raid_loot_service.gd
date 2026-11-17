extends RefCounted
## TASKS item 13: pure candidate builder for raid loot. Never writes files or
## publishes live state. Three operations:
##  - deposit(): an extracted raid's haul goes home. Materials fill the bag, then the
##    stash; anything left waits in Atlas's cargo hold. Salvage goes to the sidecar.
##  - quote_candidate("atlas", "salvage", "sell:<id>", n): sell salvage for credits.
##  - quote_candidate("atlas", "salvage", "claim:<id>", n): move cargo into the bag.
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Request = preload("res://scripts/request_state.gd")
const Store = preload("res://raid/scripts/raid_loot/raid_loot_store.gd")
const LootTable = preload("res://raid/scripts/raid_loot/loot_table.gd")
const CREDIT_CAP := 100000

var last_error := ""

func fail(reason: String) -> Dictionary:
	last_error = reason
	return {}

func _clone(plot, inventory, request, haul: Variant) -> Array:
	var p = Plot.new()
	var i = Inventory.new()
	var r = Request.new()
	var s = Store.new()
	if plot == null or inventory == null or request == null or not p.restore(plot.data()) or not i.restore(inventory.data()) or not r.restore(request.data()):
		return [fail("Current save state is invalid. Nothing changed."), null, null, null, null]
	if not s.restore(haul):
		return [fail("Raid haul records are invalid. Nothing changed."), null, null, null, null]
	return [{}, p, i, r, s]

func _validated(p, i, r, s, receipt: Dictionary) -> Dictionary:
	if not Plot.new().restore(p.data()) or not Inventory.new().restore(i.data()) or not Request.new().restore(r.data()):
		return fail("Validation failed. Nothing changed.")
	if not Store.new().restore(s.data()):
		return fail("Raid haul validation failed. Nothing changed.")
	return {"plot": p, "inventory": i, "request": r, "haul": s.data(), "receipt": receipt}

static func _promote(inventory, item_id: String) -> void:
	if item_id in Inventory.PRODUCTION_SUPPLIES:
		inventory.format_version = maxi(inventory.format_version, 10)
	elif item_id in Inventory.FISHING_SUPPLIES:
		inventory.format_version = maxi(inventory.format_version, 9)

static func _free(inventory, container: String) -> int:
	return maxi(0, inventory.capacity(container) - inventory.used(container))

static func _put(inventory, container: String, item_id: String, quantity: int) -> int:
	var n := mini(quantity, _free(inventory, container))
	if n <= 0:
		return 0
	_promote(inventory, item_id)
	var box: Dictionary = inventory.carried if container == "carried" else inventory.stash
	box[item_id] = int(box.get(item_id, 0)) + n
	return n

static func _receipt(p, i, fields: Dictionary) -> Dictionary:
	var r := {"shop_id": "atlas", "unit_price": 0, "total": 0, "quantity": 1,
		"balance_after": p.credits, "carried_after": i.used("carried"), "capacity": i.capacity("carried")}
	r.merge(fields, true)
	return r

## Applies an extracted raid's haul. outcome: {"haul": {id: n}, "raid_uid": String, "map": String}.
func deposit(plot, inventory, request, store: Store, outcome: Dictionary) -> Dictionary:
	last_error = ""
	var packed := _clone(plot, inventory, request, store.snapshot())
	if packed[1] == null:
		return packed[0]
	var p = packed[1]
	var i = packed[2]
	var r = packed[3]
	var s: Store = packed[4]
	var uid := str(outcome.get("raid_uid", ""))
	if s.was_applied(uid):
		return fail("This raid's haul was already brought home.")
	var haul = outcome.get("haul", {})
	if not haul is Dictionary:
		return fail("Raid haul is invalid. Nothing changed.")
	var to_bag := {}
	var to_stash := {}
	var to_cargo := {}
	var to_salvage := {}
	var brought := 0
	for id in LootTable.ITEMS:
		var qty := int(haul.get(id, 0)) if Store._integer(haul.get(id, 0)) else 0
		if qty <= 0:
			continue
		qty = mini(qty, Store.MAX_STACK)
		brought += qty
		if LootTable.is_salvage(id):
			s.salvage[id] = mini(Store.MAX_STACK, int(s.salvage.get(id, 0)) + qty)
			to_salvage[id] = qty
			continue
		var left := qty
		var n := _put(i, "carried", id, left)
		if n > 0: to_bag[id] = n
		left -= n
		n = _put(i, "stash", id, left)
		if n > 0: to_stash[id] = n
		left -= n
		if left > 0:
			s.cargo[id] = mini(Store.MAX_STACK, int(s.cargo.get(id, 0)) + left)
			to_cargo[id] = left
	for id in haul:
		if not LootTable.has_item(str(id)):
			return fail("Raid haul holds an unknown item. Nothing changed.")
	s.mark_applied(uid)
	s.stats.extractions = int(s.stats.extractions) + 1
	s.stats.items_brought = int(s.stats.items_brought) + brought
	i.reconcile_hotbar()
	var parts: PackedStringArray = []
	if not to_bag.is_empty(): parts.append("bag: " + LootTable.describe(to_bag))
	if not to_stash.is_empty(): parts.append("stash: " + LootTable.describe(to_stash))
	if not to_cargo.is_empty(): parts.append("waiting at Atlas (no room): " + LootTable.describe(to_cargo))
	if not to_salvage.is_empty(): parts.append("salvage to sell at Atlas (%d cr): %s" % [LootTable.total_value(to_salvage), LootTable.describe(to_salvage)])
	var message := "Raid haul brought home. " + "; ".join(parts) + "." if not parts.is_empty() else "You extracted empty-handed."
	return _validated(p, i, r, s, _receipt(p, i, {"action": "deposit", "item": "deposit", "name": "Raid haul",
		"to_bag": to_bag, "to_stash": to_stash, "to_cargo": to_cargo, "to_salvage": to_salvage,
		"brought": brought, "message": message}))

## A downed raid: nothing comes home. Only the lifetime stat changes.
func record_loss(store: Store, outcome: Dictionary) -> Dictionary:
	var s := Store.new()
	if not s.restore(store.snapshot()):
		return fail("Raid haul records are invalid.")
	var uid := str(outcome.get("raid_uid", ""))
	var lost = outcome.get("haul_lost", {})
	if not lost is Dictionary or lost.is_empty() or s.was_applied(uid):
		return {}
	s.stats.hauls_lost = int(s.stats.hauls_lost) + 1
	s.mark_applied(uid)
	return {"haul": s.data()}

func quote_candidate(shop_id: String, action: String, item: String, quantity: Variant, plot, inventory, request, context: Dictionary = {}) -> Dictionary:
	last_error = ""
	if shop_id != "atlas" or action != "salvage":
		return fail("Choose Atlas's salvage service.")
	if not quantity is int or quantity < 1:
		return fail("Choose a positive whole quantity.")
	var packed := _clone(plot, inventory, request, context.get("haul", {}))
	if packed[1] == null:
		return packed[0]
	var p = packed[1]
	var i = packed[2]
	var r = packed[3]
	var s: Store = packed[4]
	var parts := item.split(":", false, 1)
	if parts.size() != 2 or not LootTable.has_item(parts[1]):
		return fail("That salvage row is no longer available.")
	var verb: String = parts[0]
	var id: String = parts[1]
	var name := "%s × %d" % [LootTable.display_name(id), quantity]
	if verb == "sell":
		if not LootTable.is_salvage(id):
			return fail("Atlas only buys salvage. Sell materials to Rook.")
		var have := int(s.salvage.get(id, 0))
		if quantity > have:
			return fail("You only have %d to sell." % have)
		var unit := LootTable.value(id)
		if p.credits + unit * quantity > CREDIT_CAP:
			return fail("Credit limit reached. Sell fewer.")
		p.credits += unit * quantity
		s.salvage[id] = have - quantity
		if int(s.salvage[id]) <= 0: s.salvage.erase(id)
		s.stats.salvage_sold = int(s.stats.salvage_sold) + quantity
		s.stats.credits_earned = int(s.stats.credits_earned) + unit * quantity
		# ShopTransaction requires total == unit_price * quantity; a sale costs nothing.
		return _validated(p, i, r, s, _receipt(p, i, {"action": "salvage", "item": item, "quantity": quantity,
			"name": name, "verb": "sell", "earned": unit * quantity, "item_id": id}))
	if verb == "claim":
		if not LootTable.is_material(id):
			return fail("Only material overflow can be claimed.")
		var have := int(s.cargo.get(id, 0))
		if quantity > have:
			return fail("Atlas is holding only %d." % have)
		var free := _free(i, "carried")
		if quantity > free:
			return fail("Bag full · make %d carried space." % (quantity - free))
		_put(i, "carried", id, quantity)
		s.cargo[id] = have - quantity
		if int(s.cargo[id]) <= 0: s.cargo.erase(id)
		i.reconcile_hotbar()
		return _validated(p, i, r, s, _receipt(p, i, {"action": "salvage", "item": item, "quantity": quantity,
			"name": name, "verb": "claim", "earned": 0, "item_id": id}))
	return fail("That salvage row is no longer available.")
