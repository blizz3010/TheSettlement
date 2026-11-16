extends RefCounted
## Psy "Gear & Armor" tier shop logic (TASKS item 22, PR C). Pure: builds candidates,
## never writes. Plugs into scripts/shop_transaction.gd as its candidate builder.
## Tiered gear lives in the gear locker sidecar (context.locker), never in the pinned
## inventory. The T0 cosmetic basic helmet is delegated unchanged to the pinned
## scripts/psy_gear_purchase.gd, so it keeps working exactly as before.
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const State = preload("res://raid/scripts/gear_tiers/gear_locker_state.gd")
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Request = preload("res://scripts/request_state.gd")
const PsyPurchase = preload("res://scripts/psy_gear_purchase.gd")
const PsyCatalog = preload("res://scripts/psy_gear_catalog.gd")
const ACTIONS := ["buy", "sell", "repair", "upgrade", "equip"]
const STOCK_III := "psy_stock_iii"
const BASIC_HELMET := "helmet_basic"
const CREDIT_LIMIT := 100000
const SLOT_LABELS := {"helmet": "Helmet", "visor": "Visor", "headset": "Headset", "face_cover": "Face cover",
	"body_armor": "Body armor", "tactical_rig": "Tactical rig", "gloves": "Gloves", "jacket": "Jacket",
	"pants": "Pants", "boots": "Boots", "backpack": "Backpack"}
const MATERIAL_NAMES := {"metal": "metal scrap", "cloth_linen": "linen cloth", "thread_spool": "thread spool", "composite_insert": "composite insert"}
var last_error := ""
var _helmet := PsyPurchase.new()

# ------------------------------------------------------------------- rules
static func t4_window(locker) -> int:
	return int(locker.extractions) / int(Defs.TIER_SOURCES[4].rotation_every_extractions)

## The one T4 piece Psy lists in the current window ("" before 10 extractions).
static func t4_offer(locker) -> String:
	if int(locker.extractions) < int(Defs.TIER_SOURCES[4].unlock_extractions): return ""
	return Defs.item_id(Defs.SLOTS[t4_window(locker) % Defs.SLOTS.size()], 4)

## "" when the tier is buyable at Psy, else the reason.
static func lock_reason(tier: int, locker) -> String:
	var src: Dictionary = Defs.TIER_SOURCES[tier]
	var need := int(src.unlock_extractions)
	if int(locker.extractions) < need:
		return "Unlocks after %d successful extraction%s (%d so far)." % [need, "" if need == 1 else "s", int(locker.extractions)]
	if tier == 3 and not bool(locker.shop.stock_iii):
		return "Needs Psy's Stock III licence (%d credits)." % int(src.stock_fee)
	return ""

static func upgrade_materials(def: Dictionary) -> Dictionary:
	if int(def.tier) >= 4: return {}
	var src: Dictionary = Defs.TIER_SOURCES[int(def.tier) + 1]
	return (src.upgrade_materials.get(def.upgrade_kind, {}) as Dictionary).duplicate()

static func stats_line(def: Dictionary) -> String:
	var parts := []
	for cls in Defs.DAMAGE_CLASSES:
		if float(def.dr[cls]) > 0.0: parts.append("%s %d%%" % [cls.capitalize(), roundi(float(def.dr[cls]) * 100)])
	if def.has("hearing_range"): parts.append("hearing +%d%% · %s compression" % [roundi(def.hearing_range * 100), def.compression])
	if def.has("rig_cells"): parts.append("+%d rig cells (raid storage, PR D)" % def.rig_cells)
	if def.has("pack_cells"): parts.append("+%d pack cells (raid storage, PR D)" % def.pack_cells)
	if def.has("safe_fall_bonus") and float(def.safe_fall_bonus) > 0.0: parts.append("safe fall +%.1f m/s" % def.safe_fall_bonus)
	if def.has("hazard_iframe_bonus") and float(def.hazard_iframe_bonus) > 0.0: parts.append("hazard i-frames +%.1f s" % def.hazard_iframe_bonus)
	return " · ".join(parts) + "\nDurability %d · %.1f kg · sells for %d" % [def.durability, def.weight, def.sell_price]

static func locker_from(context: Dictionary):
	var locker = State.new()
	if not locker.restore(context.get("locker")): return null
	return locker

# ---------------------------------------------------------------------- rows
func rows(action: String, plot, inventory, locker) -> Array:
	var result: Array = []
	match action:
		"buy":
			for row in PsyCatalog.rows(inventory, "buy"):
				if row.id == BASIC_HELMET:
					row = row.duplicate(true)
					row.name = "Basic helmet · T0 cosmetic"
					row.category = "T0 cosmetic"
					row.icon_item = BASIC_HELMET
					result.append(row)
			var fee := int(Defs.TIER_SOURCES[3].stock_fee)
			if not bool(locker.shop.stock_iii):
				var ok := int(locker.extractions) >= int(Defs.TIER_SOURCES[3].unlock_extractions)
				result.append({"id": STOCK_III, "name": "Stock III licence", "category": "Psy stock", "tier": 3,
					"description": "One-time fee. Lets Psy stock tier 3 gear for every slot.", "price": fee, "owned": 0,
					"enabled": ok, "reason": "" if ok else "Available after %d successful extractions (%d so far)." % [int(Defs.TIER_SOURCES[3].unlock_extractions), int(locker.extractions)],
					"max_quantity": 1, "space_per_unit": 0})
			var offer := t4_offer(locker)
			for slot in Defs.SLOTS:
				for tier in Defs.TIERS:
					var id := Defs.item_id(slot, tier)
					var def := Defs.item(id)
					var reason := ""
					if tier == 4:
						if id != offer: reason = "Rare: raid loot, or Psy's rotating T4 listing after %d extractions." % int(Defs.TIER_SOURCES[4].unlock_extractions)
						elif int(locker.shop.t4_window_bought) == t4_window(locker): reason = "This window's T4 piece is sold. Next listing after %d more extraction(s)." % (int(Defs.TIER_SOURCES[4].rotation_every_extractions) - int(locker.extractions) % int(Defs.TIER_SOURCES[4].rotation_every_extractions))
					else:
						reason = lock_reason(tier, locker)
					result.append({"id": id, "name": "T%d %s" % [tier, def.name], "category": SLOT_LABELS[slot], "tier": tier,
						"description": stats_line(def), "price": int(def.price), "owned": _count(locker, id),
						"enabled": reason.is_empty(), "reason": reason, "max_quantity": 1, "space_per_unit": 0})
		"sell":
			for row in PsyCatalog.rows(inventory, "sell"):
				row = row.duplicate(true); row.name = "T0 " + str(row.name); row.category = "T0 cosmetic"
				result.append(row)
			for id in _sorted_ids(locker):
				var r: Dictionary = locker.owned[id]
				var def := Defs.item(r.def)
				var reason := ""
				if r.location == "equipped": reason = "Unequip it in the Equip tab first."
				elif float(r.durability) <= 0.0: reason = "Broken. Repair it before selling."
				result.append(_instance_row(id, r, def, int(def.sell_price), reason, "Sell back at 50%% of %d credits." % int(def.price)))
		"repair":
			for id in _sorted_ids(locker):
				var r: Dictionary = locker.owned[id]
				var def := Defs.item(r.def)
				var cost := Defs.repair_cost(r.def, float(r.durability))
				result.append(_instance_row(id, r, def, cost, "" if cost > 0 else "Already at full durability.",
					"Repair to %d durability. Cost: 30%% of %d credits × the missing fraction." % [int(def.durability), int(def.price)]))
		"upgrade":
			for id in _sorted_ids(locker):
				var r: Dictionary = locker.owned[id]
				var def := Defs.item(r.def)
				if int(def.tier) >= 4:
					result.append(_instance_row(id, r, def, 0, "Already tier 4.", "Top tier."))
					continue
				var next := Defs.item(Defs.item_id(def.slot, int(def.tier) + 1))
				var mats := upgrade_materials(def)
				var reason := ""
				if int(next.tier) < 4: reason = lock_reason(int(next.tier), locker)
				if reason.is_empty(): reason = _materials_reason(mats, inventory, locker)
				var text := "Reinforce into T%d %s.\n%s\nCost: price difference + 10%%, plus %s. The piece comes back at full durability." % [int(next.tier), next.name, stats_line(next), _materials_text(mats)]
				if int(next.tier) == 4: text += "\nComposite inserts are raid-only parts (raid loot arrives with item 13); none can drop yet."
				result.append(_instance_row(id, r, def, Defs.upgrade_cost(r.def), reason, text))
		"equip":
			for id in _sorted_ids(locker):
				var r: Dictionary = locker.owned[id]
				var def := Defs.item(r.def)
				var worn: bool = r.location == "equipped"
				var current := locker.equipped_def(def.slot)
				var text := ("Unequip from %s. It returns to your gear locker." % SLOT_LABELS[def.slot]) if worn else ("Equip in the %s slot%s." % [SLOT_LABELS[def.slot], (", replacing " + str(current.name)) if not current.is_empty() else ""])
				var row := _instance_row(id, r, def, 0, "", text + "\n" + stats_line(def))
				row.name = ("● " if worn else "") + str(row.name)
				result.append(row)
	return result

func loadout_text(locker) -> String:
	var lines := ["Gear locker · 11 slots (worn tiered gear is used in raids):"]
	for slot in Defs.SLOTS:
		var def := locker.equipped_def(slot)
		var text := "—"
		if not def.is_empty():
			var r: Dictionary = locker.owned[locker.slots[slot]]
			text = "T%d %s (%d%%)" % [def.tier, def.name, roundi(100.0 * float(r.durability) / float(def.durability))]
		lines.append("%s: %s" % [SLOT_LABELS[slot], text])
	var s: Dictionary = locker.summary()
	lines.append("Protection: ballistic %d%% · hazard %d%% · fall %d%% · %.1f kg" % [roundi(s.dr.ballistic * 100), roundi(s.dr.hazard * 100), roundi(s.dr.fall * 100), s.weight])
	lines.append("Extractions: %d" % int(locker.extractions))
	return "\n".join(lines)

func _count(locker, def_id: String) -> int:
	var n := 0
	for r in locker.owned.values():
		if r.def == def_id: n += 1
	return n

func _sorted_ids(locker) -> Array:
	var ids: Array = locker.owned.keys()
	ids.sort_custom(func(a, b):
		var da := Defs.item(locker.owned[a].def); var db := Defs.item(locker.owned[b].def)
		var ka: int = Defs.SLOTS.find(da.slot) * 10 + int(da.tier); var kb: int = Defs.SLOTS.find(db.slot) * 10 + int(db.tier)
		return ka < kb or (ka == kb and int(a.trim_prefix("gear_")) < int(b.trim_prefix("gear_"))))
	return ids

func _instance_row(id: String, r: Dictionary, def: Dictionary, price: int, reason: String, text: String) -> Dictionary:
	var pct := roundi(100.0 * float(r.durability) / float(def.durability))
	return {"id": id, "name": "T%d %s · %d%%" % [def.tier, def.name, pct], "category": SLOT_LABELS[def.slot], "tier": int(def.tier),
		"description": "%s\n\n%s\nDurability %d / %d%s." % [text, stats_line(def), roundi(float(r.durability)), int(def.durability), " · equipped" if r.location == "equipped" else ""],
		"price": price, "owned": 1, "enabled": reason.is_empty(), "reason": reason, "max_quantity": 1, "space_per_unit": 0, "def": r.def}

func _materials_text(mats: Dictionary) -> String:
	var parts := []
	for k in mats: parts.append("%d %s" % [int(mats[k]), MATERIAL_NAMES.get(k, k)])
	return ", ".join(parts) if not parts.is_empty() else "no materials"

func _materials_reason(mats: Dictionary, inventory, locker) -> String:
	for k in mats:
		var have: int = int(locker.shop.composite_insert) if k == "composite_insert" else inventory.amount("carried", k)
		if have < int(mats[k]):
			return "Needs %d carried %s (you have %d)." % [int(mats[k]), MATERIAL_NAMES.get(k, k), have] if k != "composite_insert" else "Needs a composite insert (raid-only part; none can drop until raid loot persists, item 13)."
	return ""

# ----------------------------------------------------------------- candidate
func reject(message: String) -> Dictionary:
	last_error = message
	return {}

func quote_candidate(shop_id: String, action: String, item: String, quantity: int, plot, inventory, request, context: Dictionary = {}) -> Dictionary:
	last_error = ""
	if shop_id != "psy" or quantity != 1 or not action in ACTIONS: return reject("Choose one supported gear action.")
	var locker = locker_from(context)
	if locker == null: return reject("Gear locker is invalid. Nothing changed.")
	# T0 cosmetic helmet: unchanged pinned flow.
	if (action == "buy" and item == BASIC_HELMET) or (action == "sell" and item.begins_with("psy_helmet_")):
		var c: Dictionary = _helmet.quote_candidate(shop_id, action, item, quantity, plot, inventory, request, context)
		if c.is_empty(): return reject(_helmet.last_error)
		c["locker"] = locker.data()
		return c
	var p = Plot.new(); var i = Inventory.new(); var r = Request.new()
	if not p.restore(plot.data()) or not i.restore(inventory.data()) or not r.restore(request.data()): return reject("Current save state is invalid.")
	var price := 0
	var name := ""
	match action:
		"buy":
			if item == STOCK_III:
				if bool(locker.shop.stock_iii): return reject("Stock III is already licensed.")
				if int(locker.extractions) < int(Defs.TIER_SOURCES[3].unlock_extractions): return reject("Stock III needs %d extractions." % int(Defs.TIER_SOURCES[3].unlock_extractions))
				price = int(Defs.TIER_SOURCES[3].stock_fee); name = "Stock III licence"
				if p.credits < price: return reject("Not enough credits.")
				locker.shop.stock_iii = true
			else:
				var def := Defs.item(item)
				if def.is_empty(): return reject("Psy doesn't stock that.")
				if int(def.tier) == 4:
					if item != t4_offer(locker): return reject("Tier 4 is rare: raid loot or Psy's rotating listing.")
					if int(locker.shop.t4_window_bought) == t4_window(locker): return reject("This window's T4 piece is already sold.")
					locker.shop.t4_window_bought = t4_window(locker)
				else:
					var why := lock_reason(int(def.tier), locker)
					if not why.is_empty(): return reject(why)
				price = int(def.price); name = "T%d %s" % [def.tier, def.name]
				if p.credits < price: return reject("Not enough credits.")
				if locker.grant(item).is_empty(): return reject(locker.last_error)
			p.credits -= price
		"sell":
			if not locker.owned.has(item): return reject("That gear is no longer in your locker.")
			var rec: Dictionary = locker.owned[item]; var def := Defs.item(rec.def)
			if rec.location == "equipped": return reject("Unequip it first.")
			if float(rec.durability) <= 0.0: return reject("Broken gear must be repaired before selling.")
			price = int(def.sell_price); name = "T%d %s" % [def.tier, def.name]
			if p.credits + price > CREDIT_LIMIT: return reject("Credit limit reached. Nothing sold.")
			locker.remove(item); p.credits += price
		"repair":
			if not locker.owned.has(item): return reject("That gear is no longer in your locker.")
			var rec: Dictionary = locker.owned[item]; var def := Defs.item(rec.def)
			price = Defs.repair_cost(rec.def, float(rec.durability)); name = "Repair T%d %s" % [def.tier, def.name]
			if price <= 0: return reject("Already at full durability.")
			if p.credits < price: return reject("Not enough credits.")
			locker.repair(item); p.credits -= price
		"upgrade":
			if not locker.owned.has(item): return reject("That gear is no longer in your locker.")
			var rec: Dictionary = locker.owned[item]; var def := Defs.item(rec.def)
			if int(def.tier) >= 4: return reject("Already tier 4.")
			var next_id := Defs.item_id(def.slot, int(def.tier) + 1)
			if int(def.tier) + 1 < 4:
				var why := lock_reason(int(def.tier) + 1, locker)
				if not why.is_empty(): return reject(why)
			var mats := upgrade_materials(def)
			var missing := _materials_reason(mats, i, locker)
			if not missing.is_empty(): return reject(missing)
			price = Defs.upgrade_cost(rec.def); name = "Upgrade to T%d %s" % [int(def.tier) + 1, Defs.item(next_id).name]
			if p.credits < price: return reject("Not enough credits.")
			for k in mats:
				if k == "composite_insert": locker.shop.composite_insert = int(locker.shop.composite_insert) - int(mats[k])
				else:
					var left: int = i.amount("carried", k) - int(mats[k])
					if left > 0: i.carried[k] = left
					else: i.carried.erase(k)
			locker.owned[item].def = next_id
			locker.owned[item].durability = float(Defs.item(next_id).durability)
			p.credits -= price
		"equip":
			if not locker.owned.has(item): return reject("That gear is no longer in your locker.")
			var rec: Dictionary = locker.owned[item]; var def := Defs.item(rec.def)
			if rec.location == "equipped":
				locker.unequip(def.slot); name = "Unequip T%d %s" % [def.tier, def.name]
			else:
				locker.equip(item); name = "Equip T%d %s" % [def.tier, def.name]
	# Whole-state validation before anything can be written.
	var check = State.new()
	if not check.restore(JSON.parse_string(JSON.stringify(locker.data()))): return reject("Gear locker validation failed.")
	if not Inventory.new().restore(i.data()) or not Plot.new().restore(p.data()): return reject("Save validation failed.")
	return {"plot": p, "inventory": i, "request": r, "locker": locker.data(),
		"receipt": {"shop_id": "psy", "action": action, "item": item, "name": name, "quantity": 1, "unit_price": price, "total": price,
			"balance_after": p.credits, "carried_after": i.used("carried"), "capacity": i.capacity("carried")}}
