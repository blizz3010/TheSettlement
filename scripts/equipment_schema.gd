extends RefCounted
const Catalog = preload("res://scripts/equipment_catalog.gd")
# Standalone proposed contract. NOT a live save schema or migration.
static func empty_slots() -> Dictionary:
	var result: Dictionary = {}
	for slot in Catalog.SLOT_TYPES: result[slot] = ""
	return result

static func valid_instance(value: Variant, definitions: Dictionary) -> bool:
	if not value is Dictionary or value.size() != 5: return false
	for key in ["id", "definition_id", "variant_id", "dyes", "location"]:
		if not value.has(key): return false
	for key in ["id", "definition_id", "variant_id"]:
		if not value[key] is String or value[key].strip_edges().is_empty(): return false
	if not definitions.has(value.definition_id) or not Catalog.valid_definition(definitions[value.definition_id]): return false
	if not value.variant_id in definitions[value.definition_id].variant_ids: return false
	if not value.location is String or not value.location in ["carried", "equipped", "home_stash", "lockbox"]: return false
	if not value.dyes is Dictionary: return false
	var channels: Array = definitions[value.definition_id].dye_channels
	for channel in value.dyes:
		if not channel is String or not channel in channels: return false
		var rgba = value.dyes[channel]
		if not rgba is Array or rgba.size() != 4: return false
		for component in rgba:
			if not (component is int or component is float) or not is_finite(float(component)) or component < 0 or component > 1: return false
	return true

static func validate(owned: Variant, slots: Variant, definitions: Variant) -> bool:
	if not owned is Dictionary or not slots is Dictionary or not Catalog.valid_catalog(definitions): return false
	if slots.size() != Catalog.SLOT_TYPES.size(): return false
	for instance_id in owned:
		if not instance_id is String or not valid_instance(owned[instance_id], definitions) or owned[instance_id].id != instance_id: return false
	var used: Dictionary = {}
	for slot in Catalog.SLOT_TYPES:
		if not slots.has(slot) or not slots[slot] is String: return false
		var instance_id: String = slots[slot]
		if instance_id.is_empty(): continue
		if not owned.has(instance_id) or used.has(instance_id): return false
		if not Catalog.accepts(slot, definitions[owned[instance_id].definition_id]): return false
		used[instance_id] = true
	for instance_id in owned:
		if (owned[instance_id].location == "equipped") != used.has(instance_id): return false
	return true

static func storage_available(category: String, owned: Variant, slots: Variant, definitions: Variant) -> bool:
	if not validate(owned, slots, definitions): return false
	if category in ["pockets", "lockbox"]: return true
	if category in ["tactical_rig", "backpack"]:
		# validate() resolved ownership and the exact category of every occupied slot.
		return not slots[category].is_empty()
	return false
