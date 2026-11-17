extends RefCounted
## TASKS item 22, PR D: raid storage from the worn rig and backpack.
## Pure functions over gear_locker_state.gd; nothing here reads or writes files.
##   haul capacity = pouch 8 + rig cells + pack cells (read once at raid start)
##   quick-use slots = rig quick_slots (field dressings, keys 1-3)
## Durability matters: a torn piece (below TORN_FRACTION of max) keeps half its
## cells, a broken piece (0 durability) gives none. Quick-use slots only need the
## rig not to be broken.
## Weight: worn gear weight plus the load carried beyond the 8-unit pouch, so a
## pouch-only raid keeps the PR B movement exactly.
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const LootTable = preload("res://raid/scripts/raid_loot/loot_table.gd")
const TORN_FRACTION := 0.35
const TORN_CELL_FRACTION := 0.5

static func durability_fraction(state, slot: String) -> float:
	if state == null or not state.slots.has(slot) or state.slots[slot] == "": return -1.0
	var r: Dictionary = state.owned[state.slots[slot]]
	var maximum := float(Defs.item(r.def).durability)
	return clampf(float(r.durability) / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0

## "none", "ok", "torn" or "broken".
static func condition(state, slot: String) -> String:
	var f := durability_fraction(state, slot)
	if f < 0.0: return "none"
	if f <= 0.0: return "broken"
	if f < TORN_FRACTION: return "torn"
	return "ok"

static func cells(state, slot: String) -> int:
	var key := "rig_cells" if slot == "tactical_rig" else "pack_cells"
	var def: Dictionary = state.equipped_def(slot) if state != null else {}
	if def.is_empty() or not def.has(key): return 0
	match condition(state, slot):
		"broken": return 0
		"torn": return int(floor(int(def[key]) * TORN_CELL_FRACTION))
	return int(def[key])

static func quick_slots(state) -> int:
	if state == null: return 0
	var def: Dictionary = state.equipped_def("tactical_rig")
	if def.is_empty() or condition(state, "tactical_rig") == "broken": return 0
	return int(def.get("quick_slots", 0))

static func capacity(state) -> Dictionary:
	var rig := cells(state, "tactical_rig")
	var pack := cells(state, "backpack")
	return {"pouch": LootTable.HAUL_BASE_CAPACITY, "rig": rig, "pack": pack,
		"total": LootTable.HAUL_BASE_CAPACITY + rig + pack, "quick_slots": quick_slots(state),
		"rig_condition": condition(state, "tactical_rig"), "pack_condition": condition(state, "backpack")}

## Has storage gear that can carry load beyond the pouch (so movement can change mid-raid).
static func carries_load(state) -> bool:
	var c := capacity(state)
	return int(c.rig) + int(c.pack) > 0

## kg of haul that counts toward weight: the share of the haul beyond the pouch.
static func load_weight(haul: Dictionary) -> float:
	var units := LootTable.units(haul)
	if units <= LootTable.HAUL_BASE_CAPACITY: return 0.0
	var kg := LootTable.total_weight(haul)
	return snappedf(kg * float(units - LootTable.HAUL_BASE_CAPACITY) / float(units), 0.01)

static func total_weight(state, haul: Dictionary) -> float:
	var worn: float = state.total_weight() if state != null else 0.0
	return snappedf(worn + load_weight(haul), 0.01)

static func band(state, haul: Dictionary) -> Dictionary:
	return Defs.weight_band(total_weight(state, haul))

## "pouch 8 + rig 4 + pack 9" (pieces left out when not worn; torn/broken noted).
static func breakdown(c: Dictionary) -> String:
	var parts := ["pouch %d" % int(c.pouch)]
	for key in ["rig", "pack"]:
		var cond := str(c.get(key + "_condition", "none"))
		if cond == "none": continue
		var note := "" if cond == "ok" else " (%s)" % cond
		parts.append("%s %d%s" % [key, int(c[key]), note])
	return " + ".join(parts)
