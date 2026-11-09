extends RefCounted
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Request = preload("res://scripts/request_state.gd")
const Craft = preload("res://scripts/craft_state.gd")
const BENCH_COST = {"timber":2,"metal":1}
const LANTERN_COST = {"timber":1,"metal":1}
const CRAFT_SECONDS = 10
var last_error := ""
func fail(message: String) -> Dictionary:
	last_error = message
	return {}
func remove_materials(inventory, cost: Dictionary) -> bool:
	for item in cost:
		if inventory.amount("carried",item) < cost[item]: return false
	for item in cost:
		inventory.carried[item] -= cost[item]
		if inventory.carried[item] == 0: inventory.carried.erase(item)
	return true
func candidate(action: String, plot, inventory, request, craft, cell := Vector2i.ZERO, rotation := 0, level := 0) -> Dictionary:
	last_error = ""
	var p = Plot.new(); var i = Inventory.new(); var r = Request.new(); var c = Craft.new()
	if not p.restore(plot.data()) or not i.restore(inventory.data()) or not r.restore(request.data()) or not c.restore(craft.data()): return fail("Current save state is invalid.")
	if c.status != "idle" and p.workbench.is_empty(): return fail("Crafting job has no workbench.")
	match action:
		"build_bench":
			if not p.place_piece("workbench",cell,rotation,level): return fail(p.last_error)
			if not remove_materials(i,BENCH_COST): return fail("Carry 2 Timber and 1 Metal scrap to build a workbench.")
		"remove_bench":
			if c.status != "idle": return fail("Claim the finished job before removing the workbench.")
			if i.capacity("carried")-i.used("carried") < 3: return fail("Make room for the 3 returned material units.")
			if not p.remove_workbench(): return fail(p.last_error)
			for item in BENCH_COST: i.carried[item] = i.amount("carried",item)+BENCH_COST[item]
		"start":
			if p.workbench.is_empty(): return fail("Place a workbench first.")
			if c.status != "idle": return fail("The workbench already has a job or finished kit.")
			if not remove_materials(i,LANTERN_COST): return fail("Carry 1 Timber and 1 Metal scrap for a lantern kit.")
			c.status = "working"; c.recipe = "lantern"; c.remaining = CRAFT_SECONDS
		"tick":
			if c.status != "working": return fail("No active crafting job.")
			c.remaining -= 1
			if c.remaining == 0: c.status = "ready"
		"claim":
			if c.status != "ready": return fail("No finished kit to claim.")
			if i.used("carried") >= i.capacity("carried"): return fail("Carried inventory is full. The finished kit stays here.")
			i.carried["lantern_kit"] = i.amount("carried","lantern_kit")+1
			c.status = "idle"; c.recipe = ""; c.remaining = 0
		"place_lantern":
			if i.amount("carried","lantern_kit") < 1: return fail("Carry a crafted lantern kit first.")
			if not p.place_piece("lantern",cell,rotation,level): return fail(p.last_error)
			i.carried["lantern_kit"] -= 1
			if i.carried["lantern_kit"] == 0: i.carried.erase("lantern_kit")
		"pickup_lantern":
			if i.used("carried") >= i.capacity("carried"): return fail("Make room for the lantern kit first.")
			if not p.remove_lantern(cell,level): return fail(p.last_error)
			i.carried["lantern_kit"] = i.amount("carried","lantern_kit")+1
		"toggle_lantern":
			var index = p.lantern_index(cell,level)
			if index < 0: return fail("No lantern here.")
			p.set_lantern_on(cell,level,not p.lanterns[index].on)
		_: return fail("Unknown crafting action.")
	i.reconcile_hotbar()
	if not Plot.new().restore(p.data()) or not Inventory.new().restore(i.data()) or not Request.new().restore(r.data()) or not Craft.new().restore(c.data()): return fail("Crafting validation failed.")
	return {"plot":p,"inventory":i,"request":r,"craft":c}
