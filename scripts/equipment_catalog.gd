extends RefCounted
# Category rules only. No production item grants, armor numbers, prices or capacities.
const SLOT_TYPES: Dictionary = {
	"helmet":"helmet", "visor":"visor", "headset":"headset", "face_cover":"face_cover",
	"body_armor":"body_armor", "tactical_rig":"tactical_rig", "gloves":"gloves",
	"jacket":"jacket", "pants":"pants", "boots":"boots", "backpack":"backpack",
	"primary_firearm":"primary_firearm", "sidearm":"sidearm", "secondary_tool":"melee_tool"
}
const PROTECTION_TYPES: Array[String] = ["helmet", "visor", "body_armor"]
const COSMETIC_TYPES: Array[String] = ["gloves", "jacket", "pants", "boots"]
const EXPLICIT_DYE_TYPES: Array[String] = ["gloves", "jacket", "pants"]
const STORAGE_CATEGORIES: Array[String] = ["pockets", "tactical_rig", "backpack", "lockbox"]

static func provides_protection(category: String) -> bool:
	return category in PROTECTION_TYPES

static func is_cosmetic(category: String) -> bool:
	return category in COSMETIC_TYPES

static func valid_definition(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 5: return false
	for key in ["id", "category", "display_name", "dye_channels", "variant_ids"]:
		if not value.has(key): return false
	for key in ["id", "category", "display_name"]:
		if not value[key] is String or value[key].strip_edges().is_empty(): return false
	if not value.category in SLOT_TYPES.values(): return false
	if not value.variant_ids is Array or value.variant_ids.is_empty(): return false
	var variants: Dictionary = {}
	for variant in value.variant_ids:
		if not variant is String or variant.strip_edges().is_empty() or variants.has(variant): return false
		variants[variant] = true
	if not value.dye_channels is Array: return false
	if not value.dye_channels.is_empty() and not value.category in EXPLICIT_DYE_TYPES: return false
	var seen: Dictionary = {}
	for channel in value.dye_channels:
		if not channel is String or channel.strip_edges().is_empty() or seen.has(channel): return false
		seen[channel] = true
	return true

static func valid_catalog(definitions: Variant) -> bool:
	if not definitions is Dictionary: return false
	for key in definitions:
		if not key is String or not valid_definition(definitions[key]) or key != definitions[key].id: return false
	return true

static func accepts(slot: String, definition: Dictionary) -> bool:
	return SLOT_TYPES.has(slot) and valid_definition(definition) and SLOT_TYPES[slot] == definition.category
