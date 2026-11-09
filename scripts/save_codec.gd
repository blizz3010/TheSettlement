extends RefCounted
const Fishing = preload("res://scripts/fishing_state.gd")
const Onboarding = preload("res://scripts/onboarding_state.gd")
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Craft = preload("res://scripts/craft_state.gd")
const Request = preload("res://scripts/request_state.gd")
static func encode(plot, inventory, request, craft, onboarding, fishing) -> Dictionary:
	if onboarding == null:
		onboarding = Onboarding.new()
		onboarding.refresh(plot)
	var inventory_data=inventory.data()
	return {"version":23 if inventory_data.version==10 else (22 if inventory_data.version==9 else 21),"fishing":fishing.data(),"onboarding":onboarding.data(),"craft":craft.data(),"plot":plot.data(),"inventory":inventory_data,"request":Request.new().data() if request == null else request.data()}
static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var version = value.get("version")
	if not (version is int or version is float) or not is_finite(float(version)) or version != floor(version): return {}
	version = int(version)
	var plot = Plot.new()
	var inventory = Inventory.new()
	var request = Request.new()
	var craft = Craft.new()
	var onboarding = Onboarding.new()
	var fishing = Fishing.new()
	# Legacy saves have no inventory. Seed replaces, never appends to, current contents.
	if int(version) in [1,2]:
		if not plot.restore(value): return {}
	elif int(version) in [3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23]:
		if not value.get("plot") is Dictionary: return {}
		if (version in [18,19,20,21,22,23] and value.plot.get("version") != 12) or (version in [15,16,17] and value.plot.get("version") != 11) or (version == 14 and value.plot.get("version") != 10) or (version in [12,13] and value.plot.get("version") != 9) or (version == 11 and value.plot.get("version") != 8) or (version == 10 and value.plot.get("version") != 7) or (version == 9 and value.plot.get("version") != 6) or (version == 8 and value.plot.get("version") != 5) or (version == 3 and value.plot.get("version") != 2) or (version == 4 and value.plot.get("version") != 3) or (version in [5,6,7] and value.plot.get("version") != 4): return {}
		if not value.get("inventory") is Dictionary: return {}
		var inventory_version = value.inventory.get("version")
		if not inventory.integer(inventory_version) or inventory_version != (10 if version == 23 else (9 if version == 22 else (8 if version == 21 else (7 if version == 20 else (6 if version == 19 else (5 if version in [17,18,19,20,21,22,23] else (4 if version == 16 else (3 if version >= 11 else (2 if version in [6,7,8,9,10] else 1))))))))): return {}
		if not plot.restore(value.get("plot")) or not inventory.restore(value.get("inventory")): return {}
	else: return {}
	if version >= 7 and not request.restore(value.get("request")): return {}
	if version >= 11:
		if value.size() != (7 if version >= 19 else (6 if version >= 13 else 5)) or not craft.restore(value.get("craft")): return {}
		if craft.status != "idle" and plot.workbench.is_empty(): return {}
	elif value.has("craft"): return {}
	if version >= 13:
		if not value.get("onboarding") is Dictionary or value.onboarding.get("version") != (3 if version in [17,18,19,20,21,22,23] else (2 if version in [15,16] else 1)): return {}
		if not onboarding.restore(value.get("onboarding")): return {}
		# MOVE completion and relocation are one transaction; contradictory records
		# indicate corruption and must not silently unlock or strand the player.
		if (onboarding.status == "completed") != (plot.home_stash.location == "plot"): return {}
	else:
		if value.has("onboarding"): return {}
		# Save12 was an internal, unshipped move-capable format without onboarding.
		# Preserve that existing relocation and unlock instead of requiring an
		# impossible second external-to-home move. Public Save11 stays external.
		if version == 12 and plot.home_stash.location == "plot": onboarding.status = "completed"
		else: onboarding.refresh(plot)
	if version < 15: onboarding.refresh(plot)
	if version in [17,18,19,20,21,22,23]:
		var spent = inventory.dye_free_used.values().has(true)
		if (onboarding.clothing_step == "complete") != spent: return {}
		if onboarding.clothing_step in ["available","talk_dan","claim_pending"]:
			for slot in ["jacket","gloves","pants","boots"]:
				if inventory.equipment_owned.has("starter_clothing_"+slot): return {}
	if version >= 19:
		if not fishing.restore(value.get("fishing")) or not fishing.valid_inventory(inventory): return {}
	elif value.has("fishing"): return {}
	return {"fishing":fishing,"onboarding":onboarding,"plot":plot,"inventory":inventory,"request":request,"craft":craft}
