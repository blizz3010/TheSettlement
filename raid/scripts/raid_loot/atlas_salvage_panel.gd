extends "res://raid/scripts/atlas_recovery_panel.gd"
## TASKS item 13: Atlas's stand gains a Salvage tab. Sell raid salvage for credits
## and claim material overflow that did not fit your bag or stash on return.
## Recovery and help tabs are unchanged (inherited).
const LootTable = preload("res://raid/scripts/raid_loot/loot_table.gd")
const HaulStore = preload("res://raid/scripts/raid_loot/raid_loot_store.gd")

var haul_store: HaulStore = HaulStore.new()

func _ready():
	super._ready()
	name = "AtlasSalvagePanel"

func bind_haul(store: HaulStore) -> void:
	haul_store = store if store != null else HaulStore.new()

func _verb(value: String) -> String:
	if value == "salvage":
		var row := _selected_row()
		return "Claim" if str(row.get("row_verb", quote.get("verb", ""))) == "claim" else "Sell"
	return super._verb(value)

func _review_label(value: String) -> String:
	if value == "salvage":
		return "Review claim" if str(_selected_row().get("row_verb", "")) == "claim" else "Review sale"
	return super._review_label(value)

func render_board(plot, inventory, store, pending: Dictionary = {}, message: String = "") -> void:
	if action == "salvage":
		bind_store(store)
		render_state(plot, inventory, salvage_rows(haul_store, inventory), pending, message)
		return
	super.render_board(plot, inventory, store, pending, message)

func salvage_rows(store: HaulStore, inventory) -> Array:
	var rows: Array = []
	var free_bag: int = maxi(0, inventory.capacity("carried") - inventory.used("carried"))
	for id in LootTable.salvage_ids():
		var have: int = int(store.salvage.get(id, 0))
		if have <= 0: continue
		rows.append({
			"id": "sell:" + id, "icon_item": id, "item_id": id, "row_verb": "sell",
			"name": LootTable.display_name(id), "category": "Salvage",
			"description": "%s\n\nAtlas pays %d credits each. You have %d (%d credits in total)." % [LootTable.description(id), LootTable.value(id), have, have * LootTable.value(id)],
			"price": LootTable.value(id), "owned": have, "enabled": true, "reason": "",
			"max_quantity": have, "space_per_unit": 0,
		})
	for id in LootTable.material_ids():
		var held: int = int(store.cargo.get(id, 0))
		if held <= 0: continue
		var can := mini(held, free_bag)
		rows.append({
			"id": "claim:" + id, "icon_item": id, "item_id": id, "row_verb": "claim",
			"name": "%s · held for you" % LootTable.display_name(id), "category": "Cargo",
			"description": "Raid loot that did not fit your bag or stash when you came home. Atlas holds it for free. Claim it into your bag when you have room.\n\nHeld: %d." % held,
			"price": 0, "owned": held, "enabled": can > 0, "reason": "" if can > 0 else "Bag full · make carried space to claim.",
			"max_quantity": maxi(1, can), "space_per_unit": 1,
		})
	if rows.is_empty():
		rows.append({
			"id": "salvage_empty", "icon_item": "salvage_copper_wire", "name": "No salvage yet",
			"category": "Overview",
			"description": "Search supply caches in a raid and extract to bring loot home. Materials go straight to your bag and stash; salvage pieces wait here for Atlas to buy. Anything that did not fit is held here too.",
			"price": null, "owned": 0, "enabled": false, "reason": "Nothing to sell or claim.",
			"max_quantity": 1, "space_per_unit": 0,
		})
	return rows

func _maximum() -> int:
	if action != "salvage":
		return super._maximum()
	var row := _selected_row()
	if row.is_empty() or not row.get("enabled", false): return 1
	if str(row.get("row_verb", "")) == "sell" and _plot != null:
		return maxi(1, mini(int(row.max_quantity), int((100000 - _plot.credits) / maxi(1, int(row.price)))))
	return maxi(1, int(row.get("max_quantity", 1)))

func _update_summary():
	if action != "salvage":
		super._update_summary()
		return
	if _rendering or not is_instance_valid(quantity): return
	# Same layout rules as shop_panel.gd, with sell / claim maths instead of buy maths.
	var row: Dictionary = _selected_row()
	var reviewing := not quote.is_empty()
	quantity.editable = not reviewing and not row.is_empty()
	search.editable = not reviewing
	categories.disabled = reviewing
	clear_filters.disabled = reviewing or (search.text.is_empty() and _category == "All")
	for button in tab_buttons.values(): button.disabled = reviewing
	for button in category_buttons.get_children(): button.disabled = reviewing
	summary.get_child(0).get_node("MaximumQuantity").disabled = reviewing or row.is_empty() or not row.get("enabled", false)
	confirmation.visible = reviewing
	review_button.visible = not reviewing
	confirm_button.disabled = not reviewing
	cancel_button.disabled = not reviewing
	Icons.update_hero(self, row)
	if row.is_empty():
		details.text = "Salvage: sell raid salvage to Atlas for credits, or claim raid materials he is holding because your bag and stash were full."
		totals.text = "Choose an item"
		review_button.text = "Review sale"
		review_button.disabled = true
		return
	details.text = str(row.name) + "\n\n" + str(row.get("description", ""))
	_rendering = true
	quantity.max_value = maxi(1, int(row.get("max_quantity", 1)))
	_rendering = false
	var count: int = int(quantity.value)
	var verb := str(row.get("row_verb", "sell"))
	var valid: bool = bool(row.get("enabled", false)) and row.get("price") != null
	var reason := str(row.get("reason", ""))
	var after_credits: int = _plot.credits
	var used: int = _inventory.used("carried")
	if valid and verb == "sell":
		var total: int = int(row.price) * count
		after_credits += total
		if count > int(row.get("owned", 0)): valid = false; reason = "You only have %d." % int(row.get("owned", 0))
		elif after_credits > 100000: valid = false; reason = "Credit limit is 100,000."
		totals.text = "%d credits received\nAfter: %d credits · Carried %d / %d" % [total, after_credits, used, _inventory.capacity("carried")]
	elif valid:
		used += count
		if count > int(row.get("owned", 0)): valid = false; reason = "Atlas is holding only %d." % int(row.get("owned", 0))
		elif used > _inventory.capacity("carried"): valid = false; reason = "Bag full · make %d carried space." % (used - _inventory.capacity("carried"))
		totals.text = "Free claim\nAfter: %d credits · Carried %d / %d" % [after_credits, used, _inventory.capacity("carried")]
	if not valid:
		totals.text = reason if not reason.is_empty() else "Unavailable"
	if not reason.is_empty(): details.text += "\n\n" + reason
	review_button.text = _review_label(action) if valid else "Unavailable"
	review_button.disabled = not valid
	if reviewing:
		var qverb := str(quote.get("verb", verb))
		confirm_button.text = "Confirm claim" if qverb == "claim" else "Confirm sale"
		totals.text = "%s %s · %s\nAfter: %d credits · Carried %d / %d" % ["Claim" if qverb == "claim" else "Sell", quote.get("name", row.name),
			"free" if qverb == "claim" else "+%d credits" % int(quote.get("earned", 0)), int(quote.balance_after), int(quote.carried_after), int(quote.capacity)]
