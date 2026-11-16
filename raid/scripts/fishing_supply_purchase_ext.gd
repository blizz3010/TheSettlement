extends RefCounted
## Pure candidate builder for pole and bait. Never writes files or live state.
const Catalog = preload("res://raid/scripts/fishing_supply_catalog_ext.gd")
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
var last_error := ""

func candidate(item: String, plot, inventory, quantity: int = 1) -> Dictionary:
	last_error = ""
	var row := Catalog.row(item)
	if row.is_empty():
		last_error = "Choose a listed fishing supply."
		return {}
	if quantity < 1 or quantity > int(row.max_quantity):
		last_error = "Choose a whole quantity from 1 to %d." % int(row.max_quantity)
		return {}
	var next_plot = Plot.new()
	var next_inventory = Inventory.new()
	if not next_plot.restore(plot.data()) or not next_inventory.restore(inventory.data()):
		last_error = "Invalid current state. Nothing purchased."
		return {}
	var total: int = int(row.price) * quantity
	if next_plot.credits < total:
		last_error = "Not enough credits. Nothing purchased."
		return {}
	if next_inventory.used("carried") + quantity * int(row.space_per_unit) > next_inventory.capacity("carried"):
		last_error = "Carried inventory is full. Nothing purchased."
		return {}
	next_inventory.format_version = maxi(next_inventory.format_version, 9)
	next_plot.credits -= total
	next_inventory.carried[item] = next_inventory.amount("carried", item) + quantity
	next_inventory.reconcile_hotbar()
	if not Plot.new().restore(next_plot.data()) or not Inventory.new().restore(next_inventory.data()):
		last_error = "Purchase validation failed."
		return {}
	return {
		"plot": next_plot,
		"inventory": next_inventory,
		"item": item,
		"name": row.name,
		"quantity": quantity,
		"price": int(row.price),
		"total": total,
		"receipt": {
			"shop_id": "fishing",
			"action": "buy",
			"item": item,
			"name": row.name,
			"quantity": quantity,
			"unit_price": int(row.price),
			"total": total,
			"balance_after": next_plot.credits,
			"carried_after": next_inventory.used("carried"),
			"capacity": next_inventory.capacity("carried"),
		},
	}
