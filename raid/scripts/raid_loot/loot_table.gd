extends RefCounted
## TASKS item 13: what a raid cache holds. One data file for every loot number.
## Materials are real settlement items (inventory_state.ITEMS): they go home into
## the bag or stash and are sold at Rook (timber, stone, metal) or used for Psy's
## Reinforce upgrades (metal, linen, thread). Salvage pieces are raid-only valuables
## kept in the raid_haul.json sidecar and sold to Atlas for credits.
## [guess] numbers, tuned for about one T2 gear piece per full six-cache raid.

const HAUL_BASE_CAPACITY := 8 ## raid pouch units with no rig or backpack (PR D adds cells)
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
}

static func has_item(id: String) -> bool:
	return ITEMS.has(id)

static func kind(id: String) -> String:
	return str(ITEMS.get(id, {}).get("kind", ""))

static func is_salvage(id: String) -> bool:
	return kind(id) == "salvage"

static func is_material(id: String) -> bool:
	return kind(id) == "material"

static func display_name(id: String) -> String:
	return str(ITEMS.get(id, {}).get("name", id.capitalize()))

static func value(id: String) -> int:
	return int(ITEMS.get(id, {}).get("value", 0))

static func description(id: String) -> String:
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

static func units(items: Dictionary) -> int:
	var n := 0
	for id in items:
		n += int(items[id])
	return n

static func total_value(items: Dictionary) -> int:
	var n := 0
	for id in items:
		n += value(str(id)) * int(items[id])
	return n

## Highest unit value first, then table order. Used by "Take all that fits".
static func by_value(ids: Array) -> Array:
	var order := ITEMS.keys()
	var sorted := ids.duplicate()
	sorted.sort_custom(func(a, b):
		var va := value(str(a))
		var vb := value(str(b))
		if va != vb: return va > vb
		return order.find(a) < order.find(b))
	return sorted

static func describe(items: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id in items:
		if int(items[id]) > 0:
			parts.append("%s × %d" % [display_name(str(id)), int(items[id])])
	return ", ".join(parts)
