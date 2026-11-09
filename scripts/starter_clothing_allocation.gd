extends RefCounted
# Reversible interim prototype accounting, NOT an approved final footprint table.
const Inventory=preload("res://scripts/inventory_state.gd")
const SLOTS=["jacket","gloves","pants","boots"]
static func allowed(before:Dictionary,after:Dictionary,changes:Array) -> bool:
	var old=Inventory.new();var next=Inventory.new()
	if not old.restore(before) or not next.restore(after) or changes.is_empty():return false
	if old.carried!=next.carried or old.stash!=next.stash or old.lockbox!=next.lockbox:return false
	if old.dye_free_used!=next.dye_free_used or old.hotbar_assignments!=next.hotbar_assignments:return false
	if old.recipe_unlocks!=next.recipe_unlocks or old.format_version!=next.format_version:return false
	var reward_count=0
	var seen:Dictionary={}
	for change in changes:
		if not change is Dictionary or change.size()!=3:return false
		var id=change.get("id")
		if not id is String or seen.has(id) or not next.equipment_owned.has(id):return false
		seen[id]=true
		var entry=next.equipment_owned[id]
		var slot:String=next.equipment_definitions()[entry.definition_id].category
		if not slot in SLOTS and entry.definition_id!="helmet_basic":return false
		if entry.variant_id!="basic" or not change.get("to") in ["carried","equipped"] or entry.location!=change.to:return false
		if change.get("from")=="reward":
			if not slot in SLOTS:return false
			if id!="starter_clothing_"+slot or old.equipment_owned.has(id) or change.to!="carried" or not entry.dyes.is_empty():return false
			reward_count+=1
		else:
			if not old.equipment_owned.has(id) or old.equipment_owned[id].location!=change.get("from"):return false
			if not change.get("from") in ["carried","equipped"]:return false
			var expected=old.equipment_owned[id].duplicate(true);expected.location=entry.location
			if entry!=expected:return false
	# Only the entire starter set can be minted, not a partial reward or extra ID.
	if reward_count>0 and (reward_count!=4 or changes.size()!=4):return false
	for id in old.equipment_owned:
		if not next.equipment_owned.has(id):return false
		if not seen.has(id) and old.equipment_owned[id]!=next.equipment_owned[id]:return false
	for id in next.equipment_owned:
		if not old.equipment_owned.has(id) and not seen.has(id):return false
	return next.used("carried")<=next.capacity("carried")
