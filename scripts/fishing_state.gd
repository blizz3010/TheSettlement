extends RefCounted
# One bounded starter-request prototype, not final fishing progression/economy.
const Inventory = preload("res://scripts/inventory_state.gd")
const ITEM = "stream_fish"
var status := "not_started"
var caught := false
var last_error := ""
func data() -> Dictionary:
	return {"version":1,"status":status,"caught":caught}
func restore(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=3: return false
	if not (value.get("version") is int or value.get("version") is float) or value.version!=1: return false
	if not value.get("status") is String or not value.status in ["not_started","active","completed"]: return false
	if not value.get("caught") is bool: return false
	if (value.status=="not_started" and value.caught) or (value.status=="completed" and not value.caught): return false
	status=value.status; caught=value.caught
	return true
func valid_inventory(inventory) -> bool:
	var total:int=0
	for container in ["carried","stash","lockbox"]: total+=inventory.amount(container,ITEM)
	return total == (1 if status=="active" and caught else 0)
func can_cast(inventory) -> bool:
	return status=="active" and not caught and valid_inventory(inventory) and inventory.used("carried")<inventory.capacity("carried")
func candidate(action:String,inventory) -> Dictionary:
	last_error=""
	var next=get_script().new()
	var bag=Inventory.new()
	if not next.restore(data()) or not bag.restore(inventory.data()) or not valid_inventory(bag):
		last_error="Fishing state is invalid. Nothing changed."; return {}
	if action=="accept" and status=="not_started": next.status="active"
	elif action=="catch" and can_cast(bag):
		bag.carried[ITEM]=1;next.caught=true
	elif action=="deliver" and status=="active" and caught and bag.amount("carried",ITEM)==1:
		bag.carried.erase(ITEM);bag.reconcile_hotbar();next.status="completed"
	else:
		last_error="Repeatable fishing is not enabled in this first test." if status=="completed" else "Carry the quest fish to deliver, or make one free carried space before casting."
		return {}
	if not Inventory.new().restore(bag.data()) or not next.valid_inventory(bag):return {}
	return {"fishing":next,"inventory":bag}
