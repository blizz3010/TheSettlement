extends RefCounted
# One local starter request. These numbers are reversible prototype balance.
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const REQUIRED = {"timber":2,"metal":1}
const REWARD = 25
var status := "not_started"
var last_error := ""
func data() -> Dictionary:
	return {"version":1,"status":status}
func restore(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2: return false
	var version = value.get("version")
	if not (version is int or version is float) or version != 1: return false
	if not value.get("status") is String or not value.status in ["not_started","active","completed"]: return false
	status = value.status
	return true
func ready_to_deliver(inventory) -> bool:
	for item in REQUIRED:
		if inventory.amount("carried",item) < REQUIRED[item]: return false
	return true
func candidate(action: String, plot, inventory) -> Dictionary:
	last_error = ""
	var next_request = get_script().new()
	var next_plot = Plot.new()
	var next_inventory = Inventory.new()
	if not next_request.restore(data()) or not next_plot.restore(plot.data()) or not next_inventory.restore(inventory.data()):
		last_error = "Current save state is invalid."
		return {}
	if action == "accept" and status == "not_started": next_request.status = "active"
	elif action == "deliver" and status == "active":
		if not ready_to_deliver(next_inventory):
			last_error = "Carry 2 Timber and 1 Metal scrap. Home Stash and Lockbox are not used."
			return {}
		for item in REQUIRED:
			next_inventory.carried[item] -= REQUIRED[item]
			if next_inventory.carried[item] == 0: next_inventory.carried.erase(item)
		next_plot.credits += REWARD
		next_request.status = "completed"
	else:
		last_error = "This one-time request cannot be repeated." if status == "completed" else "That request action is no longer available."
		return {}
	next_inventory.reconcile_hotbar()
	# Revalidate credit bounds as well as container invariants before persistence.
	if not Plot.new().restore(next_plot.data()):
		last_error = "Credit limit reached. Nothing was delivered."
		return {}
	return {"request":next_request,"plot":next_plot,"inventory":next_inventory}
