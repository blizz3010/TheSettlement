extends RefCounted
## TASKS item 22, PR A: the single tunable data file for 4-tier gear.
## 11 wearable slots x 4 tiers = 44 items. Every number here is a first-pass
## design value from /workspace/settlement_audit/gear_tiers_plan.md (playtest-tunable).
## Weapon slots (primary_firearm, sidearm, secondary_tool) are intentionally excluded.
## Tiered gear lives in the user://gear_locker.json sidecar, never in the pinned
## inventory/equipment schema, so the existing cosmetic "T0" basics are untouched.

const VERSION := 1
const TIERS := [1, 2, 3, 4]
## Same slot ids as scripts/equipment_catalog.gd SLOT_TYPES (minus weapons).
const SLOTS := ["helmet", "visor", "headset", "face_cover", "body_armor", "tactical_rig",
	"gloves", "jacket", "pants", "boots", "backpack"]
const DAMAGE_CLASSES := ["ballistic", "hazard", "fall"]
## Total damage reduction per class after summing all worn pieces.
const CAPS := {"ballistic": 0.65, "hazard": 0.60, "fall": 0.50}
## Health-component source strings -> damage class. Unknown sources get no reduction.
const SOURCE_CLASSES := {"sentry turret": "ballistic", "live cable": "hazard", "fall": "fall"}

## Worn-gear scaling: effective = listed * (MIN_EFFECTIVENESS + (1 - MIN) * durability fraction).
## A piece at 0 durability is broken and gives nothing.
const MIN_EFFECTIVENESS := 0.5
## Durability lost per point of damage a piece absorbed.
const WEAR_PER_ABSORBED := {"protective": 1.0, "clothing": 0.5}
const CLOTHING_SLOTS := ["jacket", "pants", "gloves", "boots"]
## Q2 (Ori, Nov 16): equipped gear is KEPT when downed, losing this fraction of max durability.
const DOWNED_DURABILITY_LOSS := 0.25
const SELL_FRACTION := 0.5      # matches Psy helmet 24 -> 12
const REPAIR_FRACTION := 0.30   # of buy price, times the missing durability fraction
const UPGRADE_FEE_FRACTION := 0.10
## Weight bands (kg of worn tiered gear, plus haul load beyond the pouch from PR D).
## Raid-only effect, applied in PR B.
const WEIGHT_BANDS := [
	{"over": 0.0, "sprint": 1.0, "walk": 1.0},
	{"over": 14.0, "sprint": 0.92, "walk": 1.0},
	{"over": 20.0, "sprint": 0.85, "walk": 0.95},
	# PR D: a full rig + pack haul can push a heavy kit past 30 kg.
	{"over": 30.0, "sprint": 0.78, "walk": 0.90},
]
## Where each tier comes from (PR C shop, PR F loot). Drop chance is per cache search.
const TIER_SOURCES := {
	1: {"psy_stock": "always", "unlock_extractions": 0, "stock_fee": 0, "loot_quality": [1, 2], "loot_chance": 0.08},
	2: {"psy_stock": "unlocked", "unlock_extractions": 1, "stock_fee": 0, "loot_quality": [2, 3], "loot_chance": 0.05,
		"upgrade_materials": {"protective": {"metal": 2}, "clothing": {"cloth_linen": 2, "thread_spool": 1}, "electronic": {"metal": 1}}},
	3: {"psy_stock": "unlocked", "unlock_extractions": 5, "stock_fee": 300, "loot_quality": [3, 4], "loot_chance": 0.04,
		"upgrade_materials": {"protective": {"metal": 4}, "clothing": {"cloth_linen": 4}, "electronic": {"metal": 4}}},
	4: {"psy_stock": "rotating", "unlock_extractions": 10, "rotation_every_extractions": 3, "stock_fee": 0,
		"loot_quality": [4, 5], "loot_chance_by_quality": {4: 0.02, 5: 0.04},
		"upgrade_materials": {"protective": {"composite_insert": 1}, "clothing": {"composite_insert": 1}, "electronic": {"composite_insert": 1}}},
}
## Placeholder palette per tier (PR A art is primitive placeholders only).
const TIER_COLORS := {1: Color("8a7a5c"), 2: Color("5f6b45"), 3: Color("33393f"), 4: Color("4a4f57")}
const TIER_TRIM := {1: Color("5a4d38"), 2: Color("9aa0a3"), 3: Color("1f2326"), 4: Color("b87333")}

## Per-slot arrays are T1, T2, T3, T4. Stats are fractions (0.10 = 10%).
## "dr" = damage reduction per class. Extra keys are slot benefits used by later PRs.
const SLOT_DATA := {
	"body_armor": {"names": ["Padded Vest", "Scrapplate Vest", "Bulwark Carrier", "Ridgeline Composite"],
		"dr": {"ballistic": [0.10, 0.18, 0.26, 0.34], "hazard": [0.02, 0.03, 0.04, 0.06]},
		"durability": [60, 90, 140, 110], "weight": [3.0, 5.5, 8.5, 6.5], "price": [60, 180, 480, 1500]},
	"helmet": {"names": ["Shell Cap", "Riveted Helm", "Warden Helm", "Crestline Helm"],
		"dr": {"ballistic": [0.04, 0.07, 0.10, 0.13], "fall": [0.0, 0.02, 0.04, 0.05]},
		"durability": [40, 60, 90, 75], "weight": [0.9, 1.3, 1.8, 1.4], "price": [40, 120, 320, 950]},
	"visor": {"names": ["Clip Shade", "Polycarb Shield", "Smoked Faceguard", "Prism Faceguard"],
		"dr": {"ballistic": [0.02, 0.03, 0.05, 0.07], "hazard": [0.0, 0.02, 0.03, 0.04]},
		"durability": [20, 30, 45, 40], "weight": [0.2, 0.3, 0.5, 0.4], "price": [20, 60, 160, 480]},
	"headset": {"names": ["Earmuff Set", "Relay Cans", "Signal Hearing Set", "Echoline Set"],
		"dr": {}, "hearing_range": [0.10, 0.25, 0.40, 0.60], "compression": ["off", "light", "medium", "strong"],
		"threat_direction_hint": [false, false, false, true],
		"durability": [30, 40, 55, 50], "weight": [0.3, 0.4, 0.5, 0.4], "price": [30, 90, 240, 720]},
	"face_cover": {"names": ["Cloth Wrap", "Filter Mask", "Respirator Half-mask", "Sealed Respirator"],
		"dr": {"hazard": [0.04, 0.08, 0.12, 0.18]}, "hazard_iframe_bonus": [0.0, 0.0, 0.1, 0.1],
		"durability": [20, 35, 50, 45], "weight": [0.1, 0.2, 0.4, 0.4], "price": [12, 36, 100, 300]},
	"tactical_rig": {"names": ["Strap Rig", "Pouch Rig", "Assault Rig", "Modular Rig"],
		"dr": {"ballistic": [0.0, 0.01, 0.02, 0.03]}, "rig_cells": [2, 3, 4, 6],
		"quick_slots": [1, 2, 2, 3],
		"durability": [40, 60, 90, 80], "weight": [0.8, 1.2, 1.9, 1.5], "price": [35, 110, 290, 880]},
	"backpack": {"names": ["Satchel", "Field Pack", "Hauler Pack", "Expedition Frame"],
		"dr": {}, "pack_cells": [4, 6, 9, 12],
		"durability": [50, 70, 100, 90], "weight": [0.6, 1.2, 2.2, 2.0], "price": [30, 100, 260, 800]},
	"jacket": {"names": ["Work Jacket", "Lined Jacket", "Ripstop Shell", "Stormweave Shell"],
		"dr": {"hazard": [0.02, 0.04, 0.06, 0.08], "ballistic": [0.0, 0.01, 0.02, 0.03]},
		"durability": [30, 45, 65, 55], "weight": [0.8, 1.0, 1.4, 1.1], "price": [22, 60, 150, 450]},
	"pants": {"names": ["Work Trousers", "Reinforced Trousers", "Ripstop Trousers", "Stormweave Trousers"],
		"dr": {"hazard": [0.02, 0.03, 0.05, 0.07], "fall": [0.0, 0.02, 0.03, 0.04]},
		"durability": [30, 45, 65, 55], "weight": [0.7, 0.9, 1.2, 1.0], "price": [18, 50, 130, 390]},
	"gloves": {"names": ["Knit Gloves", "Leather Gloves", "Insulated Gloves", "Shockproof Gauntlets"],
		"dr": {"hazard": [0.01, 0.02, 0.04, 0.06]},
		"durability": [20, 30, 45, 40], "weight": [0.1, 0.2, 0.3, 0.3], "price": [10, 30, 80, 240]},
	"boots": {"names": ["Trail Boots", "Hobnail Boots", "Drop Boots", "Shockstep Boots"],
		"dr": {"fall": [0.08, 0.15, 0.25, 0.35]}, "safe_fall_bonus": [0.0, 0.5, 1.0, 1.5],
		"durability": [30, 45, 65, 55], "weight": [1.0, 1.2, 1.6, 1.3], "price": [16, 45, 120, 360]},
}
const UPGRADE_KIND := {"headset": "electronic", "visor": "electronic"}

static func item_id(slot: String, tier: int) -> String:
	return "gear_%s_t%d" % [slot, tier]

static func parse_id(id: String) -> Dictionary:
	for slot in SLOTS:
		for tier in TIERS:
			if item_id(slot, tier) == id: return {"slot": slot, "tier": tier}
	return {}

static func has_item(id: String) -> bool:
	return not parse_id(id).is_empty()

static func upgrade_kind(slot: String) -> String:
	if slot in CLOTHING_SLOTS: return "clothing"
	return UPGRADE_KIND.get(slot, "protective")

## Flattened definition for one item. Returns {} for unknown ids.
static func item(id: String) -> Dictionary:
	var key := parse_id(id)
	if key.is_empty(): return {}
	var slot: String = key.slot
	var i: int = int(key.tier) - 1
	var src: Dictionary = SLOT_DATA[slot]
	var dr := {}
	for cls in DAMAGE_CLASSES:
		dr[cls] = float(src.dr[cls][i]) if src.dr.has(cls) else 0.0
	var price: int = int(src.price[i])
	var result := {"id": id, "slot": slot, "tier": int(key.tier), "name": src.names[i], "dr": dr,
		"durability": int(src.durability[i]), "weight": float(src.weight[i]), "price": price,
		"sell_price": int(floor(price * SELL_FRACTION)), "source": TIER_SOURCES[int(key.tier)].duplicate(true),
		"wear_kind": "clothing" if slot in CLOTHING_SLOTS else "protective", "upgrade_kind": upgrade_kind(slot)}
	for extra in ["hearing_range", "compression", "threat_direction_hint", "hazard_iframe_bonus", "rig_cells", "pack_cells", "quick_slots", "safe_fall_bonus"]:
		if src.has(extra): result[extra] = src[extra][i]
	return result

static func all_ids() -> Array:
	var result := []
	for slot in SLOTS:
		for tier in TIERS: result.append(item_id(slot, tier))
	return result

static func class_for_source(source: String) -> String:
	return SOURCE_CLASSES.get(source, "")

static func repair_cost(id: String, durability: float) -> int:
	var def := item(id)
	if def.is_empty(): return -1
	var missing := clampf(1.0 - durability / float(def.durability), 0.0, 1.0)
	if missing <= 0.0: return 0
	return maxi(1, int(ceil(def.price * REPAIR_FRACTION * missing)))

static func upgrade_cost(id: String) -> int:
	var def := item(id)
	if def.is_empty() or def.tier >= 4: return -1
	var next := item(item_id(def.slot, def.tier + 1))
	var diff: int = int(next.price) - int(def.price)
	return diff + int(ceil(diff * UPGRADE_FEE_FRACTION))

static func weight_band(total_kg: float) -> Dictionary:
	var band: Dictionary = WEIGHT_BANDS[0]
	for b in WEIGHT_BANDS:
		if total_kg > float(b.over): band = b
	return band.duplicate()
