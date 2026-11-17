extends RefCounted
## Tiered gear ownership + worn stats (TASKS item 22, PR A). Pure state, no I/O.
## Persisted by gear_locker_store.gd as the user://gear_locker.json sidecar.
## Never reads or writes the pinned settlement inventory/equipment save.
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
## v2 (PR C) adds the "shop" record. v1 files (PR A/B) still load and migrate.
const VERSION := 2
const DEFAULT_SHOP := {"stock_iii": false, "t4_window_bought": -1, "composite_insert": 0}
const LOCATIONS := ["locker", "equipped"]
const MAX_ITEMS := 512

## instance_id -> {"id", "def", "durability" (float), "location"}
var owned: Dictionary = {}
## slot -> instance_id ("" when empty)
var slots: Dictionary = {}
var next_serial := 1
var extractions := 0
## Psy progress: Stock III licence paid, last T4 rotation window bought, raid-only parts.
var shop: Dictionary = DEFAULT_SHOP.duplicate()
var last_error := ""

func _init() -> void:
	clear()

func clear() -> void:
	owned = {}
	slots = {}
	for slot in Defs.SLOTS: slots[slot] = ""
	next_serial = 1
	extractions = 0
	shop = DEFAULT_SHOP.duplicate()

# ------------------------------------------------------------------ ownership
## Adds a new full-durability instance to the locker. Returns its id or "".
func grant(def_id: String) -> String:
	last_error = ""
	if not Defs.has_item(def_id): last_error = "Unknown gear."; return ""
	if owned.size() >= MAX_ITEMS: last_error = "Gear locker is full."; return ""
	var id := "gear_%d" % next_serial
	next_serial += 1
	owned[id] = {"id": id, "def": def_id, "durability": float(Defs.item(def_id).durability), "location": "locker"}
	return id

## Gear PR F: a piece found in a raid, at condition_pct % of max durability.
func grant_found(def_id: String, condition_pct: int) -> String:
	var id := grant(def_id)
	if id.is_empty(): return ""
	var maximum := float(Defs.item(def_id).durability)
	owned[id].durability = snappedf(maximum * clampf(condition_pct / 100.0, 0.0, 1.0), 0.01)
	return id

func free_space() -> int:
	return maxi(0, MAX_ITEMS - owned.size())

## Gear PR F: composite inserts are counted in shop.composite_insert (max 999).
const MAX_PARTS := 999
func add_parts(n: int) -> int:
	var before := int(shop.composite_insert)
	shop.composite_insert = clampi(before + maxi(0, n), 0, MAX_PARTS)
	return int(shop.composite_insert) - before

func remove(instance_id: String) -> bool:
	if not owned.has(instance_id): return false
	if owned[instance_id].location == "equipped": slots[Defs.item(owned[instance_id].def).slot] = ""
	owned.erase(instance_id)
	return true

func equip(instance_id: String) -> bool:
	last_error = ""
	if not owned.has(instance_id): last_error = "That gear is not in the locker."; return false
	var slot: String = Defs.item(owned[instance_id].def).slot
	var current: String = slots[slot]
	if current == instance_id: return true
	if current != "": owned[current].location = "locker"
	slots[slot] = instance_id
	owned[instance_id].location = "equipped"
	return true

func unequip(slot: String) -> bool:
	if not slots.has(slot) or slots[slot] == "": return false
	owned[slots[slot]].location = "locker"
	slots[slot] = ""
	return true

func equipped_ids() -> Array:
	var result := []
	for slot in Defs.SLOTS:
		if slots[slot] != "": result.append(slots[slot])
	return result

func equipped_def(slot: String) -> Dictionary:
	if not slots.has(slot) or slots[slot] == "": return {}
	return Defs.item(owned[slots[slot]].def)

# ---------------------------------------------------------------------- stats
## Durability-scaled multiplier for one owned instance (0 when broken).
func effectiveness(instance_id: String) -> float:
	if not owned.has(instance_id): return 0.0
	var record: Dictionary = owned[instance_id]
	var maximum := float(Defs.item(record.def).durability)
	var dur := float(record.durability)
	if dur <= 0.0 or maximum <= 0.0: return 0.0
	return Defs.MIN_EFFECTIVENESS + (1.0 - Defs.MIN_EFFECTIVENESS) * clampf(dur / maximum, 0.0, 1.0)

## Per-piece effective reduction for a class, keyed by instance id.
func contributions(cls: String) -> Dictionary:
	var result := {}
	if not cls in Defs.DAMAGE_CLASSES: return result
	for id in equipped_ids():
		var value := float(Defs.item(owned[id].def).dr[cls]) * effectiveness(id)
		if value > 0.0: result[id] = value
	return result

## Total effective reduction for a class, capped.
func reduction_for(cls: String) -> float:
	if not cls in Defs.DAMAGE_CLASSES: return 0.0
	var total := 0.0
	for value in contributions(cls).values(): total += value
	return minf(total, float(Defs.CAPS[cls]))

func total_weight() -> float:
	var total := 0.0
	for id in equipped_ids(): total += float(Defs.item(owned[id].def).weight)
	return snappedf(total, 0.01)

func summary() -> Dictionary:
	var dr := {}
	for cls in Defs.DAMAGE_CLASSES: dr[cls] = reduction_for(cls)
	var weight := total_weight()
	return {"dr": dr, "weight": weight, "band": Defs.weight_band(weight), "equipped": equipped_ids().size()}

# --------------------------------------------------------------- damage hook
## Bound to health_component.reduction. Called only for hits that land.
## Returns the reduced damage and wears the pieces that absorbed it, split by
## each piece's share of the (uncapped) contribution. Unknown sources pass through.
func reduce_damage(amount: float, source: String) -> float:
	if not is_finite(amount) or amount <= 0.0: return amount
	var cls := Defs.class_for_source(source)
	if cls == "": return amount
	var parts := contributions(cls)
	if parts.is_empty(): return amount
	var reduction := reduction_for(cls)
	var absorbed := amount * reduction
	var raw_total := 0.0
	for value in parts.values(): raw_total += value
	for id in parts:
		var share: float = absorbed * float(parts[id]) / raw_total
		var kind: String = Defs.item(owned[id].def).wear_kind
		owned[id].durability = maxf(0.0, float(owned[id].durability) - share * float(Defs.WEAR_PER_ABSORBED[kind]))
	return amount - absorbed

## Q2: equipped gear is kept when downed but loses DOWNED_DURABILITY_LOSS of max.
func apply_downed() -> int:
	var touched := 0
	for id in equipped_ids():
		var maximum := float(Defs.item(owned[id].def).durability)
		owned[id].durability = maxf(0.0, float(owned[id].durability) - maximum * Defs.DOWNED_DURABILITY_LOSS)
		touched += 1
	return touched

func repair(instance_id: String) -> void:
	if owned.has(instance_id): owned[instance_id].durability = float(Defs.item(owned[instance_id].def).durability)

# ---------------------------------------------------------------- persistence
func data() -> Dictionary:
	var items := []
	for id in owned:
		var r: Dictionary = owned[id]
		items.append({"id": r.id, "def": r.def, "durability": snappedf(float(r.durability), 0.001), "location": r.location})
	return {"version": VERSION, "next_serial": next_serial, "extractions": extractions, "items": items, "slots": slots.duplicate(), "shop": shop.duplicate()}

static func _int(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

## Strict, all-or-nothing restore. On failure the current state is unchanged.
func restore(value: Variant) -> bool:
	last_error = "Invalid gear locker."
	if not value is Dictionary or not _int(value.get("version")): return false
	var version := int(value.version)
	if not version in [1, 2] or value.size() != (5 if version == 1 else 6): return false
	var next_shop: Dictionary = DEFAULT_SHOP.duplicate()
	if version == 2:
		var sh = value.get("shop")
		if not sh is Dictionary or sh.size() != DEFAULT_SHOP.size(): return false
		if not sh.get("stock_iii") is bool: return false
		if not _int(sh.get("t4_window_bought")) or int(sh.t4_window_bought) < -1: return false
		if not _int(sh.get("composite_insert")) or int(sh.composite_insert) < 0 or int(sh.composite_insert) > 999: return false
		next_shop = {"stock_iii": sh.stock_iii, "t4_window_bought": int(sh.t4_window_bought), "composite_insert": int(sh.composite_insert)}
	if not _int(value.get("next_serial")) or int(value.next_serial) < 1: return false
	if not _int(value.get("extractions")) or int(value.extractions) < 0 or int(value.extractions) > 1000000: return false
	if not value.get("items") is Array or value.items.size() > MAX_ITEMS: return false
	if not value.get("slots") is Dictionary or value.slots.size() != Defs.SLOTS.size(): return false
	var next_owned := {}
	for r in value.items:
		if not r is Dictionary or r.size() != 4: return false
		if not r.get("id") is String or not r.get("def") is String or not r.get("location") is String: return false
		if not r.id.begins_with("gear_") or not r.id.trim_prefix("gear_").is_valid_int(): return false
		if int(r.id.trim_prefix("gear_")) >= int(value.next_serial) or next_owned.has(r.id): return false
		if not Defs.has_item(r.def) or not r.location in LOCATIONS: return false
		var dur = r.get("durability")
		if not (dur is int or dur is float) or not is_finite(float(dur)) or dur < 0 or dur > Defs.item(r.def).durability: return false
		next_owned[r.id] = {"id": r.id, "def": r.def, "durability": float(dur), "location": r.location}
	var next_slots := {}
	var used := {}
	for slot in Defs.SLOTS:
		var id = value.slots.get(slot)
		if not id is String: return false
		if id != "":
			if not next_owned.has(id) or used.has(id) or Defs.item(next_owned[id].def).slot != slot: return false
			used[id] = true
		next_slots[slot] = id
	for id in next_owned:
		if (next_owned[id].location == "equipped") != used.has(id): return false
	owned = next_owned
	slots = next_slots
	next_serial = int(value.next_serial)
	extractions = int(value.extractions)
	shop = next_shop
	last_error = ""
	return true
