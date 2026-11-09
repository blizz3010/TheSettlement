extends RefCounted
const EquipmentSchema = preload("res://scripts/equipment_schema.gd")
const RecipeKnowledge = preload("res://scripts/recipe_knowledge.gd")
const HotbarContract = preload("res://scripts/hotbar_contract.gd")
# Basic cosmetic outfit and Psy helmet. No protection or storage bonuses.
const DEFAULT_FABRIC = [0.29,0.31,0.23,1.0]
const DEFAULT_FABRICS = {"jacket":DEFAULT_FABRIC,"gloves":[0.25,0.28,0.20,1.0],"pants":[0.20,0.21,0.18,1.0]}
const EQUIPMENT_DEFINITIONS: Dictionary = {
 "helmet_basic":{"id":"helmet_basic","category":"helmet","display_name":"Basic helmet (cosmetic)","dye_channels":[],"variant_ids":["basic"]},
 "basic_jacket":{"id":"basic_jacket","category":"jacket","display_name":"Basic jacket","dye_channels":["fabric"],"variant_ids":["basic"]},
 "basic_gloves":{"id":"basic_gloves","category":"gloves","display_name":"Basic gloves","dye_channels":["fabric"],"variant_ids":["basic"]},
 "basic_pants":{"id":"basic_pants","category":"pants","display_name":"Basic pants","dye_channels":["fabric"],"variant_ids":["basic"]},
 "basic_boots":{"id":"basic_boots","category":"boots","display_name":"Basic boots","dye_channels":[],"variant_ids":["basic"]}
}
var dye_free_used: Dictionary = {"jacket":false,"gloves":false,"pants":false}
var equipment_owned: Dictionary = {}
var equipment_slots: Dictionary = EquipmentSchema.empty_slots()
var hotbar_assignments: Array = HotbarContract.empty_assignments()
func equipment_definitions() -> Dictionary:
	return EQUIPMENT_DEFINITIONS
func context_for(owned:Dictionary,slots:Dictionary,materials:Dictionary) -> Dictionary:
	var targets:Dictionary={}
	for instance_id in owned:
		var record=owned[instance_id]
		if not record is Dictionary or not record.get("location") is String:continue
		targets["equipment:"+instance_id]={"kind":"instance","item_id":instance_id,"location":record.location,"container_instance_id":"","quick_access_eligible":record.location in ["carried","equipped"],"count":1}
	# Fungible material TYPE references, not unique stacks or a quantity ledger.
	for item in ITEMS:
		if materials.get(item,0)>0:
			targets["material:"+item]={"kind":"stack","item_id":item,"location":"carried","container_instance_id":"","quick_access_eligible":item!="bait_portion","count":materials[item]}
	return {"definitions":equipment_definitions(),"owned":owned,"slots":slots,"targets":targets,"material_ids":ITEMS.keys()}
func hotbar_context() -> Dictionary:
	return context_for(equipment_owned,equipment_slots,carried)
func reconcile_hotbar() -> void:
	# Invoke on the candidate before strict whole-save validation, never on live
	# state before a commit. Reacquisition never resurrects cleared assignments.
	var context: Dictionary = hotbar_context()
	for index in range(hotbar_assignments.size()):
		if not HotbarContract.valid_reference(hotbar_assignments[index], context): hotbar_assignments[index] = ""

# Carried/stash use provisional unit capacities. Lockbox has four 1x1, one-unit cells.
# Raid/death protection, stacking, gear footprints and expansion are not implemented.
const FISHING_SUPPLIES = ["fishing_pole", "bait_portion", "river_fish"]
const PRODUCTION_SUPPLIES = ["cooked_griddle_fish", "cloth_linen", "thread_spool"]
var recipe_unlocks:Array = RecipeKnowledge.defaults()
func knows_recipe(id:String)->bool:return recipe_unlocks.has(id)
func learn_recipe_candidate(id:String):
	last_error=""
	if not RecipeKnowledge.IDS.has(id):last_error="Unknown recipe.";return null
	if knows_recipe(id):last_error="Already learned.";return null
	var next=get_script().new()
	if not next.restore(data()):last_error="Invalid inventory.";return null
	next.format_version=10;next.recipe_unlocks.append(id)
	if not get_script().new().restore(next.data()):last_error="Recipe validation failed.";return null
	return next
const ITEMS = {"cooked_griddle_fish":"Griddle fish (display sample)", "cloth_linen":"Linen cloth", "thread_spool":"Thread spool", "river_fish":"River fish", "fishing_pole":"Basic fishing pole", "bait_portion":"Bait portion", "timber":"Timber", "stone":"Stone", "metal":"Metal", "lantern_kit":"Lantern kit", "stream_fish":"Stream fish"}
const CAPACITIES = {"carried":8, "stash":24, "lockbox":4}
var format_version:int = 8 # Promote only on a confirmed fishing-supply candidate.
var carried: Dictionary = {}
var stash: Dictionary = {"timber":4, "stone":4, "metal":2}
var lockbox: Array = ["","","",""]
var last_error := ""
func container(name: String) -> Dictionary:
	if name == "carried": return carried
	if name == "stash": return stash
	if name == "lockbox":
		var counts := {}
		for item in lockbox:
			if item is String and item != "": counts[item] = int(counts.get(item,0)) + 1
		return counts
	return {}
func used(name: String) -> int:
	if name=="lockbox":
		var occupied=0
		for cell in lockbox:
			if not empty_lockbox_cell(cell):occupied+=1
		return occupied
	var total := 0
	for quantity in container(name).values(): total += int(quantity)
	# Interim allocation only: garments use existing carried units, not final footprints.
	if name in ["carried","stash"]:
		for entry in equipment_owned.values():
			if entry.location == ("carried" if name=="carried" else "home_stash"): total += 1
	return total
func capacity(name: String) -> int:
	return CAPACITIES.get(name,0)
func amount(name: String, item: String) -> int:
	return int(container(name).get(item,0))
func data() -> Dictionary:
	var result={"version":format_version,"dye_free_used":dye_free_used.duplicate(),"carried":carried.duplicate(true),"stash":stash.duplicate(true),"lockbox":lockbox.duplicate(true),"equipment":{"owned":equipment_owned.duplicate(true),"slots":equipment_slots.duplicate(true)},"hotbar":hotbar_assignments.duplicate(true)}
	if format_version>=10:result["recipes"]=RecipeKnowledge.encode(recipe_unlocks)
	return result
func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value)
func validated_container(value: Variant, limit: int) -> Variant:
	if not value is Dictionary: return null
	var clean: Dictionary = {}
	var total := 0
	for item in value:
		if not item is String or not ITEMS.has(item): return null
		var count = value[item]
		if not integer(count) or count < 0 or count > limit: return null
		total += int(count)
		if total > limit: return null
		if count > 0: clean[item] = int(count)
	return clean
func restore(value: Variant) -> bool:
	last_error = "Invalid inventory save."
	if not value is Dictionary: return false
	if not integer(value.get("version")) or not int(value.version) in [1,2,3,4,5,6,7,8,9,10]: return false
	if value.size() != (3 if value.version == 1 else (8 if value.version == 10 else (7 if value.version >= 5 else (6 if value.version == 4 else 4)))): return false
	var next_recipes=RecipeKnowledge.defaults()
	if value.version>=10:
		next_recipes=RecipeKnowledge.decode(value.get("recipes"))
		if next_recipes==null:return false
	else:
		for name in ["carried","stash"]:
			if value.get(name) is Dictionary:
				for item in PRODUCTION_SUPPLIES:
					if value[name].has(item):return false
		if value.get("lockbox") is Array:
			for item in PRODUCTION_SUPPLIES:
				if value.lockbox.has(item):return false
	# Explicit format boundary: older inventory versions never contain new supplies.
	if value.version<9:
		for name in ["carried","stash"]:
			if value.get(name) is Dictionary:
				for item in FISHING_SUPPLIES:
					if value[name].has(item):return false
		if value.get("lockbox") is Array:
			for item in FISHING_SUPPLIES:
				if value.lockbox.has(item):return false
	# New identities never leak into historical schemas.
	if value.version < 6:
		for name in ["carried","stash"]:
			if value.get(name) is Dictionary and value[name].has("stream_fish"): return false
		if value.get("lockbox") is Array and value.lockbox.has("stream_fish"): return false
	var next_dye:Dictionary = {"jacket":false,"gloves":false,"pants":false}
	if value.version >= 5:
		if not value.get("dye_free_used") is Dictionary or value.dye_free_used.size()!=3: return false
		for slot in next_dye:
			if not value.dye_free_used.get(slot) is bool: return false
			next_dye[slot]=value.dye_free_used[slot]
	var next_owned: Dictionary = {}
	var next_slots: Dictionary = EquipmentSchema.empty_slots()
	var next_hotbar: Array = HotbarContract.empty_assignments()
	if value.version >= 4:
		if not value.get("equipment") is Dictionary or value.equipment.size() != 2: return false
		if not value.equipment.has("owned") or not value.equipment.has("slots"): return false
		if value.version == 4 and (not value.equipment.owned is Dictionary or not value.equipment.owned.is_empty()): return false
		if not EquipmentSchema.validate(value.equipment.owned,value.equipment.slots,equipment_definitions()): return false
		if value.version<8:
			for entry in value.equipment.owned.values():
				if entry.location=="lockbox":return false
		next_owned = value.equipment.owned.duplicate(true)
		next_slots = value.equipment.slots.duplicate(true)
		var checked_carried=validated_container(value.get("carried"),CAPACITIES.carried)
		if checked_carried==null:return false
		if not HotbarContract.validate(value.get("hotbar"),context_for(next_owned,next_slots,checked_carried)):return false
		next_hotbar = value.hotbar.duplicate(true)
	var next_lockbox: Array = ["","","",""]
	if value.version >= 2:
		if not value.get("lockbox") is Array or value.lockbox.size() != 4: return false
		for item in value.lockbox:
			if item is String:
				if item!="" and not ITEMS.has(item):return false
			elif value.version>=8 and item is Dictionary:
				if item.size()!=2 or item.get("kind")!="equipment" or not item.get("instance_id") is String:return false
			else:return false
		next_lockbox = value.lockbox.duplicate(true)
	var cell_ids:Dictionary={}
	for cell in next_lockbox:
		if cell is Dictionary:
			var id:String=cell.instance_id
			if cell_ids.has(id) or not next_owned.has(id) or next_owned[id].location!="lockbox":return false
			cell_ids[id]=true
	for id in next_owned:
		if (next_owned[id].location=="lockbox")!=cell_ids.has(id):return false
	if value.version < 3:
		for name in ["carried","stash"]:
			if value.get(name) is Dictionary and value[name].has("lantern_kit"): return false
		if next_lockbox.has("lantern_kit"): return false
	var next_carried = validated_container(value.get("carried"),CAPACITIES.carried)
	var next_stash = validated_container(value.get("stash"),CAPACITIES.stash)
	if next_carried == null or next_stash == null: return false
	var occupied:int=0
	for count in next_carried.values():occupied+=int(count)
	for entry in next_owned.values():
		if entry.location == "carried":occupied+=1
	if occupied>CAPACITIES.carried:return false
	# Publish only once both containers validate; never append starter supplies on load.
	dye_free_used = next_dye
	carried = next_carried
	stash = next_stash
	lockbox = next_lockbox
	equipment_owned = next_owned
	equipment_slots = next_slots
	hotbar_assignments = next_hotbar
	last_error = ""
	format_version = maxi(8,int(value.version))
	recipe_unlocks=next_recipes
	return true
func transfer_candidate(from: String, to: String, item: String, count: Variant, slot_index: Variant = -1) -> RefCounted:
	last_error = ""
	if not CAPACITIES.has(from) or not CAPACITIES.has(to) or from == to:
		last_error = "Choose two different containers."
		return null
	if "lockbox" in [from,to] and not "carried" in [from,to]:
		last_error = "Move Lockbox items through carried inventory, not Home Stash."
		return null
	if not integer(slot_index) or slot_index < -1 or slot_index > 3:
		last_error = "Invalid Lockbox slot."
		return null
	if slot_index != -1 and (not "lockbox" in [from,to] or count != 1):
		last_error = "Choose one Lockbox cell and one unit."
		return null
	if not ITEMS.has(item):
		last_error = "Unknown material."
		return null
	if not integer(count) or count <= 0:
		last_error = "Choose a positive quantity."
		return null
	if amount(from,item) < count:
		last_error = "Not enough material in the source."
		return null
	if count > capacity(to)-used(to):
		last_error = "Destination is full for that quantity."
		return null
	var candidate = get_script().new()
	if not candidate.restore(data()):
		last_error = "Current inventory is invalid."
		return null
	if from == "lockbox" and slot_index != -1 and (not candidate.lockbox[int(slot_index)] is String or candidate.lockbox[int(slot_index)] != item):
		last_error = "That Lockbox slot no longer contains this item."
		return null
	if to == "lockbox" and slot_index != -1 and not empty_lockbox_cell(candidate.lockbox[int(slot_index)]):
		last_error = "That Lockbox cell is occupied."
		return null
	if from == "lockbox":
		for n in range(int(count)):
			var index = int(slot_index) if slot_index != -1 else candidate.lockbox.find(item)
			candidate.lockbox[index] = ""
	else:
		var source: Dictionary = candidate.container(from)
		source[item] -= int(count)
		if source[item] == 0: source.erase(item)
	if to == "lockbox":
		for n in range(int(count)): candidate.lockbox[int(slot_index) if slot_index != -1 else candidate.lockbox.find("")] = item
	else:
		var destination: Dictionary = candidate.container(to)
		destination[item] = int(destination.get(item,0)) + int(count)
	candidate.reconcile_hotbar()
	# Caller persists the complete game save before publishing this candidate.
	return candidate

func equipment_candidate(action:String, instance_id:String, slot:String, movement_validator:Callable=Callable(), stash_access:bool=false, destination:String="carried") -> RefCounted:
	last_error=""
	var candidate=get_script().new()
	if not candidate.restore(data()):last_error="Current equipment state is invalid.";return null
	if not equipment_owned.has(instance_id) or not equipment_slots.has(slot):last_error="Choose owned equipment and a valid slot.";return null
	var changes:Array=[]
	if action=="equip":
		var entry:Dictionary=candidate.equipment_owned[instance_id]
		if entry.location in ["home_stash","lockbox"]:last_error="Withdraw this clothing to carried inventory before equipping.";return null
		if not preload("res://scripts/equipment_catalog.gd").accepts(slot,equipment_definitions()[entry.definition_id]):last_error="This equipment does not fit that slot.";return null
		if candidate.equipment_slots[slot]==instance_id:return candidate
		if entry.location=="equipped":last_error="Unequip this item before moving it.";return null
		var previous:String=candidate.equipment_slots[slot]
		if not previous.is_empty():
			changes.append({"id":previous,"from":"equipped","to":entry.location})
			candidate.equipment_owned[previous].location=entry.location
		changes.append({"id":instance_id,"from":entry.location,"to":"equipped"})
		entry.location="equipped";candidate.equipment_slots[slot]=instance_id
	elif action=="unequip":
		if candidate.equipment_slots[slot]!=instance_id or not destination in ["carried","home_stash"]:last_error="That equipped item changed.";return null
		if destination=="home_stash" and not stash_access:last_error="Move near Home Stash first.";return null
		changes.append({"id":instance_id,"from":"equipped","to":destination})
		candidate.equipment_slots[slot]="";candidate.equipment_owned[instance_id].location=destination
	else:last_error="Unknown equipment action.";return null
	# Only application-owned capacity/movement policy may authorize the complete
	# relocation set; no callable or capacity flag is accepted from UI drag data.
	if not movement_validator.is_valid():last_error="Equipment storage rules are not available yet.";return null
	var allowed=movement_validator.call(data(),candidate.data(),changes.duplicate(true))
	if not allowed is bool or not allowed:last_error="There is no safe room for this equipment change.";return null
	candidate.reconcile_hotbar()
	var validator=get_script().new()
	if not validator.restore(candidate.data()):last_error="Equipment validation failed.";return null
	return candidate

func hotbar_candidate(index:Variant,target_id:Variant,source_slot:Variant=-1) -> RefCounted:
	last_error=""
	if not index is int or index<0 or index>=6 or not target_id is String or not source_slot is int or source_slot < -1 or source_slot>=6:last_error="Invalid quick-access request.";return null
	var candidate=get_script().new()
	if not candidate.restore(data()):last_error="Current inventory is invalid.";return null
	if source_slot>=0:
		if candidate.hotbar_assignments[source_slot]!=target_id or target_id.is_empty():last_error="That quick-access slot changed.";return null
		var displaced=candidate.hotbar_assignments[index]
		candidate.hotbar_assignments[index]=target_id;candidate.hotbar_assignments[source_slot]=displaced
	else:
		if not HotbarContract.valid_reference(target_id,hotbar_context()):last_error="That item is no longer available.";return null
		if not target_id.is_empty() and target_id in hotbar_assignments and hotbar_assignments[index]!=target_id:last_error="Drag the existing quick-access slot to move it.";return null
		candidate.hotbar_assignments[index]=target_id
	if not HotbarContract.validate(candidate.hotbar_assignments,candidate.hotbar_context()):last_error="Quick-access validation failed.";return null
	return candidate

# A pure relocation of an existing validated instance, never a reward or a new
# definition. Legacy records/overflow stay visible and withdrawable. Capacity is
# a deposit rule, not a reason to reject historically valid saved ownership.
func clothing_storage_candidate(instance_id:String,source:String,destination:String) -> RefCounted:
	last_error=""
	if not source in ["carried","equipped","home_stash"] or not destination in ["carried","home_stash"] or source==destination or (source=="equipped" and destination!="home_stash"):
		last_error="Choose clothing and a different storage container.";return null
	var candidate=get_script().new()
	if not candidate.restore(data()):last_error="Current inventory is invalid.";return null
	if not candidate.equipment_owned.has(instance_id) or candidate.equipment_owned[instance_id].location!=source:
		last_error="That clothing has moved. Try again.";return null
	var target="stash" if destination=="home_stash" else "carried"
	if candidate.used(target)>=candidate.capacity(target):last_error="Destination is full. Withdraw items to make room.";return null
	if source=="equipped":
		var worn_slot=""
		for slot in candidate.equipment_slots:
			if candidate.equipment_slots[slot]==instance_id:worn_slot=slot;break
		if worn_slot.is_empty():last_error="That equipped clothing changed.";return null
		candidate.equipment_slots[worn_slot]=""
	candidate.equipment_owned[instance_id].location=destination
	candidate.reconcile_hotbar()
	var check=get_script().new()
	if not check.restore(candidate.data()):last_error="Clothing storage validation failed.";return null
	return candidate

# One existing provisional unit per garment, not a final footprint or protection system.
func clothing_lockbox_candidate(instance_id:String,source:String,destination:String,slot_index:int=-1) -> RefCounted:
	last_error=""
	if not source in ["carried","lockbox"] or not destination in ["carried","lockbox"] or source==destination or slot_index < -1 or slot_index>=4:
		last_error="Move clothing between carried inventory and a Lockbox cell.";return null
	var candidate=get_script().new()
	if not candidate.restore(data()):last_error="Current inventory is invalid.";return null
	if not candidate.equipment_owned.has(instance_id) or candidate.equipment_owned[instance_id].location!=source:
		last_error="That clothing has moved. Try again.";return null
	if destination=="lockbox":
		if slot_index==-1:slot_index=candidate.lockbox.find("")
		if slot_index<0 or not empty_lockbox_cell(candidate.lockbox[slot_index]):last_error="That Lockbox cell is occupied or full.";return null
		candidate.lockbox[slot_index]={"kind":"equipment","instance_id":instance_id}
	else:
		if slot_index<0 or not candidate.lockbox[slot_index] is Dictionary or candidate.lockbox[slot_index]!={"kind":"equipment","instance_id":instance_id}:
			last_error="That Lockbox cell changed. Try again.";return null
		if candidate.used("carried")>=candidate.capacity("carried"):last_error="Carried inventory is full. Make room first.";return null
		candidate.lockbox[slot_index]=""
	candidate.equipment_owned[instance_id].location=destination
	candidate.reconcile_hotbar()
	var check=get_script().new()
	if not check.restore(candidate.data()):last_error="Lockbox clothing validation failed.";return null
	return candidate

func empty_lockbox_cell(cell:Variant)->bool:
	return cell is String and cell==""
