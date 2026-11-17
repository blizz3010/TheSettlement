extends RefCounted
## TASKS item 13: what a raid cache holds. One data file for every loot number.
## Materials are real settlement items (inventory_state.ITEMS): they go home into
## the bag or stash and are sold at Rook (timber, stone, metal) or used for Psy's
## Reinforce upgrades (metal, linen, thread). Salvage pieces are raid-only valuables
## kept in the raid_haul.json sidecar and sold to Atlas for credits.
## [guess] numbers, tuned for about one T2 gear piece per full six-cache raid.

const GearDefs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const HAUL_BASE_CAPACITY := 8 ## raid pouch units; an equipped rig and backpack add cells (PR D, gear_storage.gd)
const STACKS_BY_QUALITY := [2, 2, 3, 3, 4] ## stacks rolled per cache, quality 1..5

## kind: "material" (real inventory item) or "salvage" (sidecar valuable).
## value: credits. Materials use Rook's sell price where Rook buys them, else 0.
## weights: draw weight per cache quality 1..5. qty: [min, max] per stack draw.
const ITEMS := {
	"timber": {"kind": "material", "name": "Timber", "value": 5, "weights": [30, 22, 14, 6, 0], "qty": [1, 3],
		"description": "Building and crafting material. Rook buys it."},
	"stone": {"kind": "material", "name": "Stone", "value": 4, "weights": [26, 20, 12, 6, 0], "qty": [1, 3],
		"description": "Settlement building material. Rook buys it."},
	"metal": {"kind": "material", "name": "Metal scrap", "value": 7, "weights": [20, 24, 24, 18, 12], "qty": [1, 3],
		"description": "Rook buys it; Psy uses it to reinforce armor, helmets, rigs, headsets and visors."},
	"cloth_linen": {"kind": "material", "name": "Linen cloth", "value": 0, "weights": [12, 12, 10, 8, 4], "qty": [1, 2],
		"description": "Tailoring ingredient; Psy uses it to reinforce clothing."},
	"thread_spool": {"kind": "material", "name": "Thread spool", "value": 0, "weights": [10, 10, 8, 4, 2], "qty": [1, 2],
		"description": "Tailoring ingredient; Psy uses it to reinforce clothing."},
	"salvage_copper_wire": {"kind": "salvage", "name": "Copper wire bundle", "value": 6, "weights": [14, 16, 12, 8, 4], "qty": [1, 2],
		"description": "Stripped field cable, coiled and tied. Atlas buys salvage."},
	"salvage_sensor": {"kind": "salvage", "name": "Sensor module", "value": 14, "weights": [0, 8, 12, 12, 10], "qty": [1, 1],
		"description": "A weatherproof sensor head pulled from a survey mast."},
	"salvage_capacitor": {"kind": "salvage", "name": "Relay capacitor", "value": 24, "weights": [0, 0, 8, 12, 12], "qty": [1, 1],
		"description": "Heavy can capacitor from a relay cabinet. Still holds a charge."},
	"salvage_survey_drive": {"kind": "salvage", "name": "Sealed survey drive", "value": 40, "weights": [0, 0, 0, 9, 10], "qty": [1, 1],
		"description": "Rugged data drive with intact survey records."},
	"salvage_power_cell": {"kind": "salvage", "name": "Field power cell", "value": 60, "weights": [0, 0, 0, 6, 9], "qty": [1, 1],
		"description": "Sealed long-life power cell from a secure site."},
	"salvage_research_core": {"kind": "salvage", "name": "Research core", "value": 110, "weights": [0, 0, 0, 0, 6], "qty": [1, 1],
		"description": "Shielded compute core from a top-tier site. Rare."},
	# Gear PR F: raid-only part for Psy's T3 -> T4 upgrade. Never drawn by roll() (weights 0);
	# roll_gear() places it in quality 4-5 caches (GEAR_PART_CHANCE). Goes to the gear locker.
	"composite_insert": {"kind": "part", "name": "Composite insert", "value": 0, "weights": [0, 0, 0, 0, 0], "qty": [1, 1],
		"description": "Graphite-copper composite plate insert. Psy fits one to turn a T3 piece into T4. Raid-only."},
}

## PR D: kg per unit. Only load beyond the 8-unit pouch counts toward weight bands
## (gear_storage.gd), so a pouch-only raid moves exactly as before.
const UNIT_WEIGHT := {"timber": 1.5, "stone": 2.0, "metal": 1.2, "cloth_linen": 0.3, "thread_spool": 0.1,
	"salvage_copper_wire": 0.6, "salvage_sensor": 0.5, "salvage_capacitor": 0.9, "salvage_survey_drive": 0.4,
	"salvage_power_cell": 1.4, "salvage_research_core": 2.2, "composite_insert": 0.8}

## PR D: raid-only consumables. Found in caches, kept in rig quick-use slots (keys 1-3)
## or used on the spot. They never join the haul and never go home.
## chance: per cache search by quality 1..5 (drawn after the item roll, so item rolls are unchanged).
const SUPPLIES := {
	"field_dressing": {"name": "Field dressing", "heal": 30.0, "chance": [0.30, 0.35, 0.45, 0.55, 0.65],
		"description": "Sealed pressure dressing. Restores 30 health. Raid-only."},
}

# ------------------------------------------------------------ gear PR F: gear as loot
## A found gear piece is one haul key: "gear_<slot>_t<tier>@<condition %>", e.g.
## "gear_helmet_t2@70". Tier chances per cache come from gear_defs TIER_SOURCES.
const GEAR_SEP := "@"
## Haul units a piece takes (bulky armor and packs take more of the pouch).
const GEAR_UNITS := {"body_armor": 3, "backpack": 3, "tactical_rig": 2, "helmet": 2, "jacket": 2,
	"pants": 2, "boots": 2, "visor": 1, "headset": 1, "face_cover": 1, "gloves": 1}
## Found condition, % of max durability, rolled in 5% steps [guess].
const FOUND_CONDITION := [45, 90]
## Composite insert: quality 4-5 caches, per search (plan: q4-5 only, 5%).
const GEAR_PART_CHANCE := {4: 0.05, 5: 0.05}
## Take-all ordering weight for the insert (Psy does not buy it, so its credit value stays 0).
const PART_SORT_VALUE := 400

static func gear_key(def_id: String, condition_pct: int) -> String:
	return "%s%s%d" % [def_id, GEAR_SEP, clampi(condition_pct, 1, 100)]

## {"def", "condition" (1-100), "slot", "tier"} or {} when id is not a gear key.
static func parse_gear(id: String) -> Dictionary:
	var parts := id.split(GEAR_SEP)
	if parts.size() != 2 or not parts[1].is_valid_int(): return {}
	var pct := int(parts[1])
	if pct < 1 or pct > 100: return {}
	var key := GearDefs.parse_id(parts[0])
	if key.is_empty(): return {}
	return {"def": parts[0], "condition": pct, "slot": key.slot, "tier": int(key.tier)}

static func is_gear(id: String) -> bool:
	return not parse_gear(id).is_empty()

static func is_part(id: String) -> bool:
	return kind(id) == "part"

## Haul units one unit of this id takes (1 for everything but gear).
static func unit_size(id: String) -> int:
	var g := parse_gear(id)
	return int(GEAR_UNITS.get(g.slot, 1)) if not g.is_empty() else 1

## Draws gear for one cache with the caller's RNG, after roll() and roll_supplies(),
## so the item and supply rolls for a seed are unchanged. Returns {key: 1}.
static func roll_gear(rng: RandomNumberGenerator, quality: int) -> Dictionary:
	var q := clampi(quality, 1, 5)
	var found := {}
	for tier in GearDefs.TIERS:
		var chance := tier_chance(tier, q)
		if chance <= 0.0: continue
		if rng.randf() < chance:
			var slot: String = GearDefs.SLOTS[rng.randi_range(0, GearDefs.SLOTS.size() - 1)]
			var pct := rng.randi_range(FOUND_CONDITION[0] / 5, FOUND_CONDITION[1] / 5) * 5
			var key := gear_key(GearDefs.item_id(slot, tier), pct)
			found[key] = int(found.get(key, 0)) + 1
	if rng.randf() < float(GEAR_PART_CHANCE.get(q, 0.0)): found["composite_insert"] = 1
	return found

## Per-search chance of a tier-N piece in a quality-q cache (0 outside its band).
static func tier_chance(tier: int, quality: int) -> float:
	var src: Dictionary = GearDefs.TIER_SOURCES[tier]
	var band: Array = src.loot_quality
	if quality < int(band[0]) or quality > int(band[1]): return 0.0
	if src.has("loot_chance_by_quality"): return float(src.loot_chance_by_quality.get(quality, 0.0))
	return float(src.get("loot_chance", 0.0))

static func unit_weight(id: String) -> float:
	var g := parse_gear(id)
	if not g.is_empty(): return float(GearDefs.item(g.def).weight)
	return float(UNIT_WEIGHT.get(id, 1.0))

static func total_weight(items: Dictionary) -> float:
	var kg := 0.0
	for id in items:
		kg += unit_weight(str(id)) * int(items[id])
	return snappedf(kg, 0.01)

static func is_supply(id: String) -> bool:
	return SUPPLIES.has(id)

static func supply_name(id: String) -> String:
	return str(SUPPLIES.get(id, {}).get("name", id.capitalize()))

## Draw supplies for one cache with the caller's RNG, after roll(). Returns {supply_id: n}.
static func roll_supplies(rng: RandomNumberGenerator, quality: int) -> Dictionary:
	var q := clampi(quality, 1, 5)
	var found := {}
	for id in SUPPLIES:
		if rng.randf() < float(SUPPLIES[id].chance[q - 1]): found[id] = 1
	return found

static func has_item(id: String) -> bool:
	return ITEMS.has(id) or is_gear(id)

static func kind(id: String) -> String:
	if is_gear(id): return "gear"
	return str(ITEMS.get(id, {}).get("kind", ""))

static func is_salvage(id: String) -> bool:
	return kind(id) == "salvage"

static func is_material(id: String) -> bool:
	return kind(id) == "material"

static func display_name(id: String) -> String:
	var g := parse_gear(id)
	if not g.is_empty(): return "T%d %s · %d%%" % [g.tier, GearDefs.item(g.def).name, g.condition]
	return str(ITEMS.get(id, {}).get("name", id.capitalize()))

## Credits: Rook/Atlas price for materials and salvage; Psy's sell price for found gear.
static func value(id: String) -> int:
	var g := parse_gear(id)
	if not g.is_empty(): return int(GearDefs.item(g.def).sell_price)
	return int(ITEMS.get(id, {}).get("value", 0))

static func description(id: String) -> String:
	var g := parse_gear(id)
	if not g.is_empty(): return "Tier %d %s found in a raid cache at %d%% durability. Goes to your gear locker at Psy if you extract." % [g.tier, GearDefs.item(g.def).name, g.condition]
	return str(ITEMS.get(id, {}).get("description", ""))

static func salvage_ids() -> Array:
	return ITEMS.keys().filter(func(id): return is_salvage(id))

static func material_ids() -> Array:
	return ITEMS.keys().filter(func(id): return is_material(id))

## Rolls one cache. Uses the caller's seeded RNG so a cache always holds the same
## loot for a given raid seed. Returns {item_id: quantity} in table order.
static func roll(rng: RandomNumberGenerator, quality: int) -> Dictionary:
	var q := clampi(quality, 1, 5)
	var stacks: int = STACKS_BY_QUALITY[q - 1]
	var drawn := {}
	for _i in stacks:
		var total := 0
		for id in ITEMS:
			total += int(ITEMS[id].weights[q - 1])
		if total <= 0:
			break
		var pick := rng.randi_range(1, total)
		for id in ITEMS:
			pick -= int(ITEMS[id].weights[q - 1])
			if pick <= 0:
				var range_q: Array = ITEMS[id].qty
				drawn[id] = int(drawn.get(id, 0)) + rng.randi_range(int(range_q[0]), int(range_q[1]))
				break
	var ordered := {}
	for id in ITEMS:
		if drawn.has(id):
			ordered[id] = drawn[id]
	return ordered

## Haul units (gear pieces take GEAR_UNITS each; everything else 1 per item).
static func units(items: Dictionary) -> int:
	var n := 0
	for id in items:
		n += int(items[id]) * unit_size(str(id))
	return n

## Item count (pieces), ignoring size.
static func count(items: Dictionary) -> int:
	var n := 0
	for id in items:
		n += int(items[id])
	return n

static func total_value(items: Dictionary) -> int:
	var n := 0
	for id in items:
		n += value(str(id)) * int(items[id])
	return n

static func sort_value(id: String) -> int:
	return PART_SORT_VALUE if is_part(id) else value(id)

## Highest unit value first, then table order. Used by "Take all that fits".
static func by_value(ids: Array) -> Array:
	var order := ITEMS.keys()
	var sorted := ids.duplicate()
	sorted.sort_custom(func(a, b):
		var va := sort_value(str(a))
		var vb := sort_value(str(b))
		if va != vb: return va > vb
		return order.find(a) < order.find(b))
	return sorted

static func describe(items: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id in items:
		if int(items[id]) > 0:
			parts.append("%s × %d" % [display_name(str(id)), int(items[id])])
	return ", ".join(parts)
