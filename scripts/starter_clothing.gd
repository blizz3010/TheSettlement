extends RefCounted
# Provisional mechanics; concept artwork and production wardrobe policy remain gated.
const SLOTS = ["jacket", "gloves", "pants", "boots"]
const DYE_SLOTS = ["jacket", "gloves", "pants"]
const Inventory = preload("res://scripts/inventory_state.gd")
const Onboarding = preload("res://scripts/onboarding_state.gd")
var last_error := ""
func clone_pair(inventory, onboarding) -> Dictionary:
	var inv = Inventory.new()
	var progress = Onboarding.new()
	if not inv.restore(inventory.data()) or not progress.restore(onboarding.data()):
		last_error = "Current clothing state is invalid."
		return {}
	return {"inventory":inv,"onboarding":progress,"source":{"inventory":inventory.data(),"onboarding":onboarding.data()}}
func accept(inventory, onboarding) -> Dictionary:
	last_error = ""
	if onboarding.clothing_step != "available": return {}
	var result = clone_pair(inventory,onboarding)
	if not result.is_empty(): result.onboarding.clothing_step = "talk_dan"
	return result
func talk_dan(inventory, onboarding, movement_validator:Callable=Callable()) -> Dictionary:
	# Legacy API alias and persisted step remain valid for every old save.
	return talk_tailor(inventory,onboarding,movement_validator)
func talk_tailor(inventory, onboarding, movement_validator:Callable=Callable()) -> Dictionary:
	last_error = ""
	if not onboarding.clothing_step in ["talk_dan","claim_pending"]: return {}
	var result = clone_pair(inventory,onboarding)
	if result.is_empty(): return {}
	# Persist pending entitlement even when the complete set cannot be placed.
	result.onboarding.clothing_step = "claim_pending"
	var proposed = Inventory.new()
	if not proposed.restore(inventory.data()): return {}
	var changes:Array = []
	for slot in SLOTS:
		var id:String = "starter_clothing_" + slot
		if proposed.equipment_owned.has(id):
			last_error = "Starter reward identity conflict. Nothing granted."
			return {}
		proposed.equipment_owned[id] = {"id":id,"definition_id":"basic_"+slot,"variant_id":"basic","dyes":{},"location":"carried"}
		changes.append({"id":id,"from":"reward","to":"carried"})
	var allowed:Variant=false
	if movement_validator.is_valid(): allowed=movement_validator.call(inventory.data(),proposed.data(),changes)
	if not allowed is bool or not allowed:
		last_error = "Full outfit reserved with the tailor. Claim waits for safe inventory space."
		return result
	var check = Inventory.new()
	if not check.restore(proposed.data()): return {}
	result.inventory = proposed
	result.onboarding.clothing_step = "dye_active"
	return result
func dye(inventory, onboarding, instance_id:String, channel:String, rgba:Array) -> Dictionary:
	last_error = ""
	if not onboarding.clothing_step in ["dye_active","complete"]: return {}
	var result = clone_pair(inventory,onboarding)
	if result.is_empty(): return {}
	if not inventory.equipment_owned.has(instance_id): return {}
	var entry:Dictionary = inventory.equipment_owned[instance_id]
	var definition:Dictionary = inventory.equipment_definitions()[entry.definition_id]
	var slot:String = definition.category
	if not slot in DYE_SLOTS or not channel in definition.dye_channels or not entry.location in ["carried","equipped"]: return {}
	if inventory.dye_free_used[slot]:
		last_error = "This slot's free dye was used. Paid dye is unavailable until its credit price is selected."
		return {}
	# Unchanged drafts must not spend the slot entitlement or finish the quest.
	if rgba.size()!=4:return {}
	var previous:Array=entry.dyes.get(channel,Inventory.DEFAULT_FABRICS[slot])
	var unchanged=true
	for n in range(4):
		if not (rgba[n] is int or rgba[n] is float) or not is_finite(float(rgba[n])) or rgba[n]<0 or rgba[n]>1:return {}
		if not is_equal_approx(float(previous[n]),float(rgba[n])):unchanged=false
	if unchanged:return {}
	result.inventory.equipment_owned[instance_id].dyes[channel] = rgba.duplicate()
	result.inventory.dye_free_used[slot] = true
	if result.onboarding.clothing_step == "dye_active": result.onboarding.clothing_step = "complete"
	var check = Inventory.new()
	if not check.restore(result.inventory.data()): return {}
	# Caller must save BOTH candidate objects before publishing either. Preview
	# and cancel never call this commit candidate method.
	return result
