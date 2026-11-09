extends RefCounted
const Schema = preload("res://scripts/equipment_schema.gd")
# Six stable target IDs resolved against validated current ownership/location.
# References contain no quantity, category, container or duplicate equipment state.
const SLOT_COUNT: int = 6
const LOCAL_LOCATIONS: Array[String] = ["carried", "pockets", "tactical_rig", "backpack", "lockbox", "equipped"]
static func empty_assignments() -> Array:
	return ["", "", "", "", "", ""]

static func valid_context(context: Variant) -> bool:
	if not context is Dictionary or context.size() != 5: return false
	for key in ["definitions", "owned", "slots", "targets", "material_ids"]:
		if not context.has(key): return false
	if not Schema.validate(context.owned, context.slots, context.definitions): return false
	if not context.targets is Dictionary or not context.material_ids is Array: return false
	var materials: Dictionary = {}
	for item in context.material_ids:
		if not item is String or item.is_empty() or materials.has(item): return false
		materials[item] = true
	var resolved_instances: Dictionary = {}
	for target_id in context.targets:
		if not target_id is String or target_id.is_empty(): return false
		var entry = context.targets[target_id]
		if not entry is Dictionary or entry.size() != 6: return false
		for key in ["kind", "item_id", "location", "container_instance_id", "quick_access_eligible", "count"]:
			if not entry.has(key): return false
		for key in ["kind", "item_id", "location", "container_instance_id"]:
			if not entry[key] is String: return false
		if not entry.quick_access_eligible is bool: return false
		if not entry.location in LOCAL_LOCATIONS + ["home_stash"]: return false
		var count = entry.count
		if not (count is int or count is float) or not is_finite(float(count)) or count != floor(count) or count <= 0: return false
		if entry.kind == "instance":
			if count != 1 or not context.owned.has(entry.item_id) or resolved_instances.has(entry.item_id): return false
			resolved_instances[entry.item_id] = true
			if entry.location != context.owned[entry.item_id].location: return false
			var is_equipped: bool = entry.item_id in context.slots.values()
			if (entry.location == "equipped") != is_equipped: return false
		elif entry.kind == "stack":
			if not materials.has(entry.item_id) or entry.location == "equipped": return false
		else: return false
		if entry.location in ["tactical_rig", "backpack"]:
			if not Schema.storage_available(entry.location, context.owned, context.slots, context.definitions): return false
			if entry.container_instance_id != context.slots[entry.location]: return false
			if entry.kind == "instance" and entry.item_id == entry.container_instance_id: return false
		elif not entry.container_instance_id.is_empty(): return false
	return true

static func valid_reference(target_id: Variant, context: Dictionary) -> bool:
	if not valid_context(context) or not target_id is String: return false
	if target_id.is_empty(): return true
	if not context.targets.has(target_id): return false
	var entry: Dictionary = context.targets[target_id]
	return entry.quick_access_eligible and entry.location != "home_stash"

static func validate(assignments: Variant, context: Dictionary) -> bool:
	if not assignments is Array or assignments.size() != SLOT_COUNT or not valid_context(context): return false
	for target_id in assignments:
		if not target_id is String: return false
		if target_id.is_empty(): continue
		if not context.targets.has(target_id): return false
		var entry: Dictionary = context.targets[target_id]
		if not entry.quick_access_eligible or entry.location == "home_stash": return false
	return true
