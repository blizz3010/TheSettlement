extends SceneTree
## TASKS item 22, PR A: 4-tier gear data, locker state, sidecar save, and the
## health_component damage-reduction hook. Headless; disposable XDG profile.
## Prints exactly one machine-readable marker line: GEAR_TIERS_TESTS {json}.
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const State = preload("res://raid/scripts/gear_tiers/gear_locker_state.gd")
const Store = preload("res://raid/scripts/gear_tiers/gear_locker_store.gd")
const Art = preload("res://raid/scripts/gear_tiers/gear_placeholder_art.gd")
const Health = preload("res://raid/scripts/health_component.gd")
const Vitals = preload("res://scripts/player_vitals.gd")
const Catalog = preload("res://scripts/equipment_catalog.gd")
var checks := 0
var failures: Array = []
var facts := {}

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func near(a: float, b: float, eps: float = 0.0005) -> bool:
	return absf(a - b) <= eps

func _initialize():
	call_deferred("run")

# ---------------------------------------------------------------- data file
func data_tests():
	var ids := Defs.all_ids()
	check(ids.size() == 44 and Defs.SLOTS.size() == 11, "44 items over 11 slots")
	for weapon in ["primary_firearm", "sidearm", "secondary_tool"]:
		check(not weapon in Defs.SLOTS, "weapon slot excluded: " + weapon)
	var names := {}
	for slot in Defs.SLOTS:
		check(Catalog.SLOT_TYPES.has(slot) and Catalog.SLOT_TYPES[slot] == slot, "slot matches equipment catalog: " + slot)
		var src: Dictionary = Defs.SLOT_DATA[slot]
		for key in ["names", "durability", "weight", "price"]:
			check(src[key].size() == 4, "%s.%s has 4 tiers" % [slot, key])
		for cls in src.dr:
			check(cls in Defs.DAMAGE_CLASSES and src.dr[cls].size() == 4, "%s dr.%s valid" % [slot, cls])
		var prev_price := 0
		for t in Defs.TIERS:
			var d := Defs.item(Defs.item_id(slot, t))
			check(d.slot == slot and d.tier == t and d.name is String and d.name != "", "%s T%d defined" % [slot, t])
			check(not names.has(d.name), "unique name " + str(d.name))
			names[d.name] = true
			check(int(d.price) > prev_price, "%s T%d price rises" % [slot, t])
			prev_price = int(d.price)
			check(d.sell_price == int(floor(d.price * 0.5)), "%s T%d sells at 50%%" % [slot, t])
			check(d.durability > 0 and d.weight > 0.0, "%s T%d durability and weight positive" % [slot, t])
		# Trade-off rule: T3 is the most durable; T4 is lighter than T3 (backpack: T4 lighter too).
		var t3 := Defs.item(Defs.item_id(slot, 3)); var t4 := Defs.item(Defs.item_id(slot, 4)); var t2 := Defs.item(Defs.item_id(slot, 2))
		check(t3.durability > t4.durability and t3.durability > t2.durability, "%s T3 most durable" % slot)
		check(t4.weight <= t3.weight, "%s T4 no heavier than T3" % slot)
	check(Defs.item("helmet_basic").is_empty() and Defs.item("gear_helmet_t5").is_empty() and Defs.item("gear_sidearm_t1").is_empty(), "unknown ids rejected")
	check(Defs.item(Defs.item_id("helmet", 1)).price > 24, "T1 helmet above the 24-credit cosmetic helmet")
	check(Defs.DOWNED_DURABILITY_LOSS == 0.25, "Q2 downed rule: keep gear, -25% durability")
	check(Defs.CAPS == {"ballistic": 0.65, "hazard": 0.60, "fall": 0.50}, "caps")
	check(Defs.TIER_SOURCES[4].psy_stock == "rotating" and Defs.TIER_SOURCES[1].psy_stock == "always", "T4 rare, T1 always stocked")
	check(Defs.class_for_source("sentry turret") == "ballistic" and Defs.class_for_source("live cable") == "hazard" and Defs.class_for_source("fall") == "fall" and Defs.class_for_source("test") == "", "source classes")
	var totals := {}
	for t in Defs.TIERS:
		var price := 0; var weight := 0.0; var ballistic := 0.0
		for slot in Defs.SLOTS:
			var d := Defs.item(Defs.item_id(slot, t))
			price += int(d.price); weight += float(d.weight); ballistic += float(d.dr.ballistic)
		totals[t] = {"price": price, "weight": snappedf(weight, 0.01), "ballistic": snappedf(ballistic, 0.001)}
	facts["kit_totals"] = totals
	check(totals[1].price == 293 and totals[2].price == 881 and totals[3].price == 2330 and totals[4].price == 7070, "kit price totals match the plan")
	check(near(totals[1].weight, 8.5) and near(totals[2].weight, 13.4) and near(totals[3].weight, 20.3) and near(totals[4].weight, 16.3), "kit weights match the plan")
	check(near(totals[1].ballistic, 0.16) and near(totals[2].ballistic, 0.30) and near(totals[3].ballistic, 0.45) and near(totals[4].ballistic, 0.60), "kit ballistic sums match the plan")
	check(Defs.repair_cost(Defs.item_id("body_armor", 4), 55.0) == 225 and Defs.repair_cost(Defs.item_id("body_armor", 4), 110.0) == 0, "repair cost = 30% x missing")
	check(Defs.upgrade_cost(Defs.item_id("body_armor", 1)) == 132 and Defs.upgrade_cost(Defs.item_id("body_armor", 4)) == -1, "upgrade cost = diff + 10%")
	check(Defs.weight_band(10.0).sprint == 1.0 and Defs.weight_band(16.3).sprint == 0.92 and Defs.weight_band(20.3).walk == 0.95, "weight bands")

# ------------------------------------------------------------- locker state
func full_kit(s, tier: int) -> void:
	for slot in Defs.SLOTS:
		s.equip(s.grant(Defs.item_id(slot, tier)))

func state_tests():
	var s = State.new()
	check(s.summary().equipped == 0 and s.reduction_for("ballistic") == 0.0 and s.total_weight() == 0.0, "empty locker: no stats")
	check(s.reduce_damage(12.0, "sentry turret") == 12.0, "empty locker: damage unchanged")
	check(s.grant("helmet_basic") == "" and s.grant("nope") == "", "grant rejects non-tier ids")
	var a = s.grant(Defs.item_id("body_armor", 1))
	var b = s.grant(Defs.item_id("body_armor", 2))
	check(a == "gear_1" and b == "gear_2" and s.owned[a].location == "locker", "grant into locker")
	check(s.equip(a) and s.slots.body_armor == a and s.owned[a].location == "equipped", "equip")
	check(s.equip(b) and s.slots.body_armor == b and s.owned[a].location == "locker", "equip swaps slot occupant back to locker")
	check(near(s.reduction_for("ballistic"), 0.18), "T2 armor 18% ballistic")
	check(s.unequip("body_armor") and s.slots.body_armor == "" and not s.unequip("body_armor"), "unequip")
	var k = State.new(); full_kit(k, 4)
	check(near(k.reduction_for("ballistic"), 0.60) and near(k.reduction_for("hazard"), 0.49) and near(k.reduction_for("fall"), 0.44), "full T4 reductions")
	check(near(k.total_weight(), 16.3) and k.summary().band.sprint == 0.92, "full T4 weight band")
	var k1 = State.new(); full_kit(k1, 1)
	check(near(k1.reduce_damage(12.0, "sentry turret"), 10.08), "full T1: turret 12 -> 10.08")
	var raw_turret = k.reduce_damage(12.0, "sentry turret")
	check(near(raw_turret, 4.8, 0.01), "full T4: turret 12 -> 4.8 (%.3f)" % raw_turret)
	check(k.reduce_damage(12.0, "test") == 12.0 and k.reduce_damage(12.0, "unknown") == 12.0, "unknown source passes through")
	# Wear: absorbed 7.2 split by contribution; armor's share = 7.2*0.34/0.60 = 4.08.
	var armor_id: String = k.slots.body_armor
	check(near(k.owned[armor_id].durability, 110.0 - 4.08, 0.01), "armor wore by its absorbed share")
	check(k.owned[k.slots.backpack].durability == 90.0 and k.owned[k.slots.headset].durability == 50.0, "non-contributing pieces don't wear")
	# Cap: stack fake pieces above cap via a T4 kit plus forcing reduction; verify cap with hazard extremes.
	var cap = State.new(); full_kit(cap, 4)
	for cls in Defs.DAMAGE_CLASSES: check(cap.reduction_for(cls) <= Defs.CAPS[cls] + 0.0001, "cap holds for " + cls)
	# Worn scaling.
	var w = State.new(); var v = w.grant(Defs.item_id("body_armor", 3)); w.equip(v)
	w.owned[v].durability = 70.0
	check(near(w.effectiveness(v), 0.75) and near(w.reduction_for("ballistic"), 0.195), "half durability = 75% effectiveness")
	w.owned[v].durability = 0.0
	check(w.effectiveness(v) == 0.0 and w.reduction_for("ballistic") == 0.0 and w.reduce_damage(12.0, "sentry turret") == 12.0, "broken piece gives nothing")
	w.repair(v)
	check(w.owned[v].durability == 140.0, "repair restores max durability")
	# Clothing wears at half rate.
	var c = State.new(); var j = c.grant(Defs.item_id("gloves", 4)); c.equip(j)
	c.reduce_damage(10.0, "live cable")
	check(near(c.owned[j].durability, 40.0 - 10.0 * 0.06 * 0.5), "clothing wears at 0.5x")
	# Downed (Q2).
	var d = State.new(); full_kit(d, 2)
	check(d.apply_downed() == 11, "downed touches all equipped")
	check(near(d.owned[d.slots.body_armor].durability, 67.5) and d.owned.size() == 11, "downed keeps gear, -25% max durability")
	d.apply_downed(); d.apply_downed(); d.apply_downed(); d.apply_downed()
	check(d.owned[d.slots.helmet].durability == 0.0, "durability floors at 0")
	var r = State.new(); var x = r.grant(Defs.item_id("visor", 1)); r.equip(x)
	check(r.remove(x) and r.slots.visor == "" and r.owned.is_empty(), "remove clears equipped slot")

# -------------------------------------------------------------- persistence
func persistence_tests():
	check(Store.DEFAULT_PATH == "user://gear_locker.json", "sidecar path is user://gear_locker.json")
	var s = State.new(); full_kit(s, 3); s.grant(Defs.item_id("boots", 1)); s.extractions = 4
	s.reduce_damage(12.0, "sentry turret")
	var copy = State.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(s.data()))) and copy.owned.size() == 12 and copy.extractions == 4, "round trip restores")
	check(JSON.stringify(copy.data()) == JSON.stringify(s.data()), "round trip is exact")
	check(near(copy.reduction_for("ballistic"), s.reduction_for("ballistic")), "restored stats match")
	var bad_cases := {}
	var base: Dictionary = s.data()
	var t1 = base.duplicate(true); t1.items[0].durability = 9999; bad_cases["durability over max"] = t1
	var t2 = base.duplicate(true); t2.slots.helmet = t2.slots.body_armor; bad_cases["wrong slot"] = t2
	var t3 = base.duplicate(true); t3.items[0].location = "locker"; bad_cases["equipped mismatch"] = t3
	var t4 = base.duplicate(true); t4.items[0].def = "helmet_basic"; bad_cases["non-tier def"] = t4
	var t5 = base.duplicate(true); t5.version = 2; bad_cases["unknown version"] = t5
	var t6 = base.duplicate(true); t6.next_serial = 1; bad_cases["serial collision"] = t6
	var t7 = base.duplicate(true); t7["extra"] = 1; bad_cases["extra key"] = t7
	for label in bad_cases:
		var probe = State.new(); probe.grant(Defs.item_id("pants", 1))
		var before := JSON.stringify(probe.data())
		check(not probe.restore(bad_cases[label]) and JSON.stringify(probe.data()) == before, "restore rejects (%s) and keeps state" % label)
	# Files: missing -> empty and written; save/load; corrupt -> backup + empty.
	var dir := "user://gear_tiers_test"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := dir + "/gear_locker.json"
	for f in [path, path + ".invalid-backup", path + ".tmp"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var store = Store.new()
	check(store.load_locker(path) and store.state.owned.is_empty() and FileAccess.file_exists(path), "missing file: empty locker, file created")
	full_kit(store.state, 2); store.state.extractions = 1
	check(store.save() and not FileAccess.file_exists(path + ".tmp"), "save commits atomically")
	var again = Store.new()
	check(again.load_locker(path) and again.state.owned.size() == 11 and again.state.extractions == 1 and not again.recovered_from_corrupt, "reload restores the locker")
	var fh := FileAccess.open(path, FileAccess.WRITE); fh.store_string("{not json"); fh.close()
	var broken = Store.new()
	check(broken.load_locker(path) and broken.recovered_from_corrupt and broken.state.owned.is_empty(), "corrupt file: starts empty, game not blocked")
	check(FileAccess.file_exists(path + ".invalid-backup") and FileAccess.get_file_as_string(path + ".invalid-backup") == "{not json", "corrupt bytes kept as .invalid-backup")
	var after = Store.new()
	check(after.load_locker(path) and not after.recovered_from_corrupt, "rewritten file loads clean")
	fh = FileAccess.open(path, FileAccess.WRITE); fh.store_string(JSON.stringify(bad_cases["wrong slot"])); fh.close()
	var tampered = Store.new()
	check(tampered.load_locker(path) and tampered.recovered_from_corrupt and tampered.state.owned.is_empty(), "tampered file: recovered empty")

# ------------------------------------------------------------- health hook
func health_tests():
	# Without a hook: identical to the pre-PR sequence in test_health_damage.
	var vitals = Vitals.new(); var h = Health.new(); root.add_child(h); h.set_physics_process(false)
	var dealt := []
	h.damaged.connect(func(a, s, c): dealt.append(a))
	check(not h.reduction.is_valid(), "no hook by default")
	check(h.bind(vitals, 100.0) and h.damage(30.0, "sentry turret") and vitals.current == 70.0, "no hook: full damage")
	check(not h.damage(30.0, "sentry turret") and vitals.current == 70.0, "no hook: i-frames unchanged")
	h.tick(0.61)
	check(h.damage(12.0, "live cable") and vitals.current == 58.0 and dealt == [30.0, 12.0] and h.last_raw_damage == 12.0, "no hook: signal amounts unchanged")
	h.invulnerable_left = 0.0
	check(h.damage(500.0, "fall") and vitals.current == 0.0 and h.dead, "no hook: lethal unchanged")
	h.queue_free()
	# With the gear locker bound.
	var gv = Vitals.new(); var g = Health.new(); root.add_child(g); g.set_physics_process(false)
	var locker = State.new(); full_kit(locker, 4)
	var calls := [0]
	g.reduction = func(a, s): calls[0] += 1; return locker.reduce_damage(a, s)
	var got := []
	g.damaged.connect(func(a, s, c): got.append(a))
	g.bind(gv, 100.0)
	check(g.damage(12.0, "sentry turret") and near(gv.current, 95.2, 0.01) and near(got[-1], 4.8, 0.01) and g.last_raw_damage == 12.0, "hook: T4 kit turret 12 -> 4.8")
	check(not g.damage(12.0, "sentry turret") and calls[0] == 1, "hook not called during i-frames (no wear)")
	g.invulnerable_left = 0.0
	var expect_hazard := 12.0 * (1.0 - locker.reduction_for("hazard"))
	check(g.damage(12.0, "live cable") and near(got[-1], expect_hazard, 0.001), "hook: hazard class")
	g.invulnerable_left = 0.0
	var before: float = gv.current
	check(g.damage(10.0, "test") and near(before - gv.current, 10.0), "hook: unknown source unreduced")
	g.invulnerable_left = 0.0
	g.reduction = func(a, s): return -5.0
	before = gv.current
	check(g.damage(10.0, "fall") and near(gv.current, before), "hook result clamped at 0")
	g.invulnerable_left = 0.0
	g.reduction = func(a, s): return 999.0
	before = gv.current
	check(g.damage(10.0, "fall") and near(before - gv.current, 10.0), "hook result clamped at raw amount")
	g.invulnerable_left = 0.0
	g.reduction = func(a, s): return "bad"
	before = gv.current
	check(g.damage(10.0, "fall") and near(before - gv.current, 10.0), "invalid hook result ignored")
	g.reduction = Callable()
	g.invulnerable_left = 0.0
	before = gv.current
	check(g.damage(10.0, "sentry turret") and near(before - gv.current, 10.0), "clearing the hook restores old behaviour")
	g.queue_free()

# --------------------------------------------------------- placeholder art
func art_tests():
	var built := 0
	for id in Defs.all_ids():
		var node: Node3D = Art.build(id)
		if node != null and node.get_meta("placeholder", false) and node.get_child_count() == 1 + Defs.item(id).tier and node.get_child(0).mesh != null:
			built += 1
		if node != null: node.free()
	check(built == 44, "44 placeholder models build (%d)" % built)
	check(Art.build("helmet_basic") == null, "no placeholder for unknown ids")
	facts["placeholder_models"] = built

func run():
	data_tests()
	state_tests()
	persistence_tests()
	health_tests()
	art_tests()
	await process_frame
	print("GEAR_TIERS_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "facts": facts}))
	quit(0 if failures.is_empty() else 1)
