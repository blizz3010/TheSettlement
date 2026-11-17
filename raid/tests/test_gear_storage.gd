extends SceneTree
## TASKS item 22, PR D: rig/backpack raid storage. Pure storage maths, raid state,
## the real Relay Ridge + Cinder Basin scenes (capacity, quick-use slots, load weight,
## HUD), extraction of a large haul into the settlement, and Psy shop text.
## Headless; disposable XDG profile. Marker line: GEAR_STORAGE_TESTS {json}.
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const State = preload("res://raid/scripts/gear_tiers/gear_locker_state.gd")
const Store = preload("res://raid/scripts/gear_tiers/gear_locker_store.gd")
const Storage = preload("res://raid/scripts/gear_tiers/gear_storage.gd")
const ShopService = preload("res://raid/scripts/gear_tiers/gear_shop_service.gd")
const GearPlayer = preload("res://raid/scripts/gear_tiers/raid_gear_player.gd")
const BasePlayer = preload("res://scripts/player.gd")
const LootTable = preload("res://raid/scripts/raid_loot/loot_table.gd")
const RaidState = preload("res://raid/scripts/raid_state.gd")
const HaulStore = preload("res://raid/scripts/raid_loot/raid_loot_store.gd")
const LootService = preload("res://raid/scripts/raid_loot/raid_loot_service.gd")
const Outcome = preload("res://raid/scripts/raid_outcome.gd")
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Request = preload("res://scripts/request_state.gd")
var checks := 0
var failures: Array = []
var facts := {}

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func near(a: float, b: float, eps: float = 0.01) -> bool:
	return absf(a - b) <= eps

func _initialize():
	call_deferred("run")

func remove_locker():
	for f in [Store.DEFAULT_PATH, Store.DEFAULT_PATH + ".tmp", Store.DEFAULT_PATH + ".invalid-backup"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

func kit(tier: int, slots: Array = Defs.SLOTS):
	var s = State.new()
	for slot in slots: s.equip(s.grant(Defs.item_id(slot, tier)))
	return s

func write_kit(tier: int, slots: Array = Defs.SLOTS) -> void:
	var store = Store.new()
	store.path = Store.DEFAULT_PATH
	store.state = kit(tier, slots)
	check(store.save(), "seeded T%d locker saved" % tier)

func open_scene(path: String):
	var scene = load(path).instantiate()
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 60000
	while not scene.is_raid_ready() and Time.get_ticks_msec() < deadline: await process_frame
	check(scene.is_raid_ready(), path + " ready")
	return scene

func close_scene(scene) -> void:
	scene.queue_free()
	await process_frame
	await process_frame

func cache_target(scene, id: String) -> Dictionary:
	for t in scene.targets:
		if t.kind == "cache" and t.poi.id == id: return t
	return {}

func modal_button(scene, name_or_text: String) -> Button:
	for b in scene.modal_content.find_children("*", "Button", true, false):
		if b.name == name_or_text or b.text == name_or_text: return b
	return null

# ------------------------------------------------------------ pure storage
func storage_tests():
	var none := Storage.capacity(State.new())
	check(none.total == 8 and none.quick_slots == 0 and Storage.breakdown(none) == "pouch 8", "no rig/pack: pouch 8, no quick slots")
	check(Storage.capacity(null).total == 8, "null locker: pouch 8")
	var totals := []
	var quick := []
	for tier in Defs.TIERS:
		var c := Storage.capacity(kit(tier))
		totals.append(int(c.total)); quick.append(int(c.quick_slots))
	facts["capacity_by_tier"] = totals
	facts["quick_by_tier"] = quick
	check(totals == [14, 17, 21, 26], "full kit capacity T1..T4 = 8 + rig + pack: %s" % str(totals))
	check(quick == [1, 2, 2, 3], "rig quick-use slots T1..T4: %s" % str(quick))
	var rig_only := Storage.capacity(kit(3, ["tactical_rig"]))
	check(rig_only.total == 12 and rig_only.pack == 0 and Storage.breakdown(rig_only) == "pouch 8 + rig 4", "rig only: 8 + 4")
	var pack_only := Storage.capacity(kit(4, ["backpack"]))
	check(pack_only.total == 20 and pack_only.quick_slots == 0, "pack only: 8 + 12, no quick slots")
	# Durability: torn halves the cells, broken gives none (rig quick slots survive torn).
	var s = kit(3, ["tactical_rig", "backpack"])
	var pack_id: String = s.slots.backpack
	var rig_id: String = s.slots.tactical_rig
	s.owned[pack_id].durability = 34.0  # 34 / 100 < 0.35
	var torn := Storage.capacity(s)
	check(torn.pack == 4 and torn.pack_condition == "torn" and Storage.breakdown(torn).contains("pack 4 (torn)"), "torn T3 pack: 9 -> 4 cells")
	s.owned[pack_id].durability = 35.0
	check(Storage.capacity(s).pack == 9, "35% durability is not torn")
	s.owned[pack_id].durability = 0.0
	s.owned[rig_id].durability = 20.0
	var broken := Storage.capacity(s)
	check(broken.pack == 0 and broken.pack_condition == "broken" and broken.rig == 2 and broken.quick_slots == 2, "broken pack 0 cells; torn rig 2 cells keeps 2 quick slots")
	s.owned[rig_id].durability = 0.0
	check(Storage.capacity(s).quick_slots == 0 and Storage.capacity(s).total == 8, "broken rig: no quick slots, back to the pouch")
	# Downed rule: 25% per downed raid wears storage too (T3 pack 100 -> 25 after 3 downs).
	var d = kit(3)
	for i in 3: d.apply_downed()
	var worn := Storage.capacity(d)
	check(worn.rig == 2 and worn.pack == 4 and worn.total == 14, "three downed raids: T3 rig+pack torn, 21 -> 14 units")
	d.apply_downed()
	check(Storage.capacity(d).total == 8 and Storage.capacity(d).quick_slots == 0, "four downed raids: storage broken, pouch only")
	# Weight: only load beyond the pouch counts.
	check(Storage.load_weight({"stone": 8}) == 0.0, "8 units in the pouch: no load weight")
	check(near(Storage.load_weight({"stone": 16}), 16.0), "16 stone: 8 beyond the pouch = 16 kg")
	check(near(Storage.load_weight({"timber": 4, "salvage_research_core": 6}), (6.0 + 13.2) * 2.0 / 10.0), "mixed haul: proportional share")
	check(Defs.weight_band(31.0).sprint == 0.78 and Defs.weight_band(31.0).walk == 0.9 and Defs.weight_band(30.0).sprint == 0.85, "new >30 kg band")
	var t4 = kit(4)
	var full_t4 := Storage.total_weight(t4, {"stone": 26})
	facts["t4_full_stone_kg"] = full_t4
	check(near(full_t4, 16.3 + 36.0) and Storage.band(t4, {"stone": 26}).sprint == 0.78, "T4 kit + 26 stone = 52.3 kg, heaviest band")
	check(LootTable.UNIT_WEIGHT.size() == LootTable.ITEMS.size(), "every loot item has a unit weight")

# ---------------------------------------------------------- supplies + state
func supply_tests():
	# Item rolls are unchanged by the supply draw (drawn after the items).
	var poi := {"id": "camp", "lock": "", "loot": [1, 5]}
	for seed in [7, 241107, 99]:
		var st = RaidState.new(seed)
		var r: Dictionary = st.search_cache(poi)
		var rng := RandomNumberGenerator.new(); rng.seed = seed + int(String("camp").hash()) + 771
		var q := rng.randi_range(1, 5)
		check(q == r.quality and LootTable.roll(rng, q) == r.items, "seed %d: item roll unchanged by supplies" % seed)
		check(r.has("supplies") and r.supplies == st.supplies_in("camp"), "seed %d: supplies reported" % seed)
	var found := [0, 0, 0, 0, 0]
	for seed in 400:
		for q in [1, 2, 3, 4, 5]:
			var rng := RandomNumberGenerator.new(); rng.seed = seed * 13 + q
			if not LootTable.roll_supplies(rng, q).is_empty(): found[q - 1] += 1
	var rates := []
	for n in found: rates.append(snappedf(n / 400.0, 0.01))
	facts["dressing_rate_by_quality"] = rates
	check(rates[0] > 0.2 and rates[0] < 0.4 and rates[4] > 0.55 and rates[4] < 0.75, "dressing rate tracks the table: %s" % str(rates))
	var s = RaidState.new(1)
	s.cache_supplies["camp"] = {"field_dressing": 3}
	check(not s.stow_supply("camp", "field_dressing"), "no rig: cannot stow")
	s.quick_capacity = 2
	check(s.stow_supply("camp", "field_dressing") and s.stow_supply("camp", "field_dressing") and not s.stow_supply("camp", "field_dressing"), "stow fills 2 quick slots, then refuses")
	check(s.quick_slots.size() == 2 and int(s.supplies_in("camp").field_dressing) == 1 and s.cache_has_anything("camp"), "one dressing left in the cache")
	check(s.use_supply_from_cache("camp", "field_dressing") and not s.cache_has_anything("camp"), "use one from the cache")
	check(s.use_quick(5) == "" and s.use_quick(0) == "field_dressing" and s.quick_slots.size() == 1 and s.supplies_used == 2, "quick slot use")
	check(s.haul_units() == 0, "supplies never join the haul")
	s.extracted_at = "x"
	check(s.use_quick(0) == "", "quick use frozen after extraction")
	check(s.summary().quick_slots == ["field_dressing"] and s.summary().supplies_used == 2, "summary carries quick slots")

# --------------------------------------------------------------- real scenes
func empty_scene_tests():
	remove_locker()
	var scene = await open_scene("res://raid/relay_ridge.tscn")
	if not scene.is_raid_ready(): return
	check(scene.raid_state.haul_capacity == 8 and scene.raid_state.quick_capacity == 0, "empty locker: haul 8, no quick slots")
	check(scene.player.get_script() == BasePlayer and scene.gear == null, "empty locker: plain player.gd, no gear node")
	scene._process(0.016)
	check(scene.status.text.contains("Haul 0/8") and not scene.status.text.contains("Quick"), "empty HUD: Haul 0/8, no quick bar")
	# Number keys do nothing without a rig.
	var ev := InputEventKey.new(); ev.pressed = true; ev.physical_keycode = KEY_1
	scene._unhandled_input(ev)
	check(not scene.toast.text.contains("Quick slot"), "key 1 ignored without a rig")
	# A dressing can still be used on the spot.
	var t := cache_target(scene, "camp")
	scene.raid_state.search_cache(t.poi)
	scene.raid_state.cache_supplies["camp"] = {"field_dressing": 1}
	var h = scene.health_controller.health
	h.invulnerable_left = 0.0; h.damage(40.0, "unknown")
	scene._cache_panel(t)
	var stow := modal_button(scene, "Stow_field_dressing")
	var use := modal_button(scene, "UseNow_field_dressing")
	check(stow != null and stow.disabled and stow.text == "No rig" and use != null and not use.disabled, "no rig: Stow disabled, Use now offered")
	if use != null: use.pressed.emit()
	check(near(h.current(), 90.0) and scene.raid_state.supplies_in("camp").is_empty(), "Use now heals 30 (60 -> 90)")
	scene._close_modal()
	await close_scene(scene)

func kit_scene_tests():
	remove_locker()
	write_kit(3)
	var scene = await open_scene("res://raid/relay_ridge.tscn")
	if not scene.is_raid_ready(): return
	var rs = scene.raid_state
	var gear = scene.gear
	check(rs.haul_capacity == 21 and rs.quick_capacity == 2, "T3 kit: haul 21 (8 + 4 + 9), 2 quick slots")
	check(scene.player.get_script() == GearPlayer, "T3 kit: gear player")
	check(near(scene.player.gear_sprint_mult, 0.85, 0.0001) and near(scene.player.gear_walk_mult, 0.95, 0.0001), "20.3 kg worn: sprint x0.85, walk x0.95")
	scene._process(0.016)
	check(scene.status.text.contains("Haul 0/21") and scene.status.text.contains("Quick [1] —  [2] —"), "HUD: Haul 0/21 and an empty quick bar: " + scene.status.text.get_slice("\n", 2))
	check(gear.hud_label.text.contains("Storage 21 units (pouch 8 + rig 4 + pack 9) · 2 quick slots"), "gear HUD storage line: " + gear.hud_label.text.replace("\n", " | "))
	# Fill the haul beyond the pouch with heavy stone through the real cache panel.
	var t := cache_target(scene, "camp")
	rs.search_cache(t.poi)
	rs.cache_contents["camp"] = {"stone": 25}
	rs.cache_supplies["camp"] = {"field_dressing": 3}
	scene._cache_panel(t)
	var all := modal_button(scene, "Take all that fits")
	if all != null: all.pressed.emit()
	check(rs.haul_units() == 21 and int(rs.cache_items("camp").stone) == 4, "Take all fills 21 units, 4 left behind")
	check(near(gear.load_kg, 26.0) and near(scene.player.gear_sprint_mult, 0.78, 0.0001) and near(scene.player.gear_walk_mult, 0.9, 0.0001), "13 stone beyond the pouch = 26 kg: 46.3 kg, sprint x0.78, walk x0.9")
	check(gear.hud_label.text.contains("46.3 kg (load 26.0)"), "gear HUD shows the load: " + gear.hud_label.text.replace("\n", " | "))
	check(scene._haul_line().contains("21 / 21 units (pouch 8 + rig 4 + pack 9) · load 26.0 kg"), "haul line shows the breakdown and load: " + scene._haul_line())
	facts["full_haul_line"] = scene._haul_line()
	# Stow dressings into the rig.
	scene._cache_panel(t)
	var stow := modal_button(scene, "Stow_field_dressing")
	check(stow != null and not stow.disabled and stow.text == "Stow in rig", "Stow in rig offered")
	if stow != null: stow.pressed.emit()
	stow = modal_button(scene, "Stow_field_dressing")
	if stow != null: stow.pressed.emit()
	stow = modal_button(scene, "Stow_field_dressing")
	check(rs.quick_slots.size() == 2 and stow != null and stow.disabled and stow.text == "Rig slots full", "two stowed, then Rig slots full")
	scene._close_modal()
	scene._process(0.016)
	check(scene.status.text.contains("Quick [1] Field dressing  [2] Field dressing"), "quick bar lists the dressings")
	# Keys 1 / 2 use the slots; full health refuses.
	var h = scene.health_controller.health
	var ev := InputEventKey.new(); ev.pressed = true; ev.physical_keycode = KEY_1
	scene._unhandled_input(ev)
	check(rs.quick_slots.size() == 2 and scene.toast.text == "Already at full health.", "full health: dressing kept")
	h.invulnerable_left = 0.0; h.damage(50.0, "unknown")
	var before: float = h.current()
	scene._unhandled_input(ev)
	check(near(h.current(), before + 30.0) and rs.quick_slots.size() == 1 and scene.toast.text.begins_with("Field dressing used"), "key 1 heals 30: %.1f -> %.1f" % [before, h.current()])
	var ev3 := InputEventKey.new(); ev3.pressed = true; ev3.physical_keycode = KEY_3
	scene._unhandled_input(ev3)
	check(rs.quick_slots.size() == 1 and scene.toast.text == "Quick slot 3 is empty.", "key 3 beyond the rig: nothing used")
	# Drop back into the pouch: movement returns to the worn-weight band.
	scene._haul_panel()
	for i in 13:
		var drop := modal_button(scene, "Loot_stone")
		if drop != null: drop.pressed.emit()
	check(rs.haul_units() == 8 and gear.load_kg == 0.0 and near(scene.player.gear_sprint_mult, 0.85, 0.0001), "drop to 8 units: load 0, back to x0.85")
	scene._close_modal()
	# Field notes show capacity and quick slots.
	scene._field_notes()
	var text := ""
	for l in scene.modal_content.find_children("*", "Label", true, false): text += l.text + "\n"
	for r in scene.modal_content.find_children("*", "RichTextLabel", true, false): text += r.text + "\n"
	check(text.contains("(pouch 8 + rig 4 + pack 9)") and text.contains("Rig quick-use: 1 / 2 filled"), "field notes show storage and quick slots")
	scene._close_modal()
	# Extraction carries a full 21-unit haul home.
	rs.cache_contents["camp"] = {"stone": 4, "metal": 9}
	rs.take_all("camp")
	scene._haul_changed()
	check(rs.haul_units() == 21, "refilled to 21 units")
	rs.extracted_at = "extract1"
	Outcome.last = {}
	scene._extraction_complete()
	var out: Dictionary = Outcome.peek()
	check(out.get("outcome", "") == "extracted" and LootTable.units(out.get("haul", {})) == 21, "extraction outcome carries 21 units")
	var plot := Plot.new(); var inv := Inventory.new()
	var dep: Dictionary = LootService.new().deposit(plot, inv, Request.new(), HaulStore.new(), out)
	check(not dep.is_empty(), "21-unit haul deposits")
	if not dep.is_empty():
		var r: Dictionary = dep.receipt
		var placed := LootTable.units(r.to_bag) + LootTable.units(r.to_stash) + LootTable.units(r.to_cargo)
		check(placed == 21 and LootTable.units(r.to_bag) == 8, "8 to the bag, the rest to stash/Atlas cargo (%s)" % r.message)
	await close_scene(scene)
	# Downed with a full rig/pack: haul lost, gear kept at -25%, next raid smaller only once torn.
	write_kit(3)
	scene = await open_scene("res://raid/relay_ridge.tscn")
	if not scene.is_raid_ready(): return
	rs = scene.raid_state
	rs.cache_contents["camp"] = {"metal": 20}
	rs.searched["camp"] = 3
	rs.take_all("camp")
	rs.quick_capacity = 2; rs.quick_slots = ["field_dressing"]
	scene._haul_changed()
	Outcome.last = {}
	var hh = scene.health_controller.health
	hh.invulnerable_left = 0.0
	hh.damage(500.0, "unknown")
	for i in 4: await process_frame
	var down: Dictionary = Outcome.peek()
	check(down.get("outcome", "") == "downed" and LootTable.units(down.get("haul_lost", {})) == 20, "downed: 20-unit haul lost")
	var texts := ""
	for l in scene.modal_content.find_children("*", "Label", true, false): texts += l.text
	check(texts.contains("Unused field dressings in your rig stay behind."), "downed screen mentions the dressings")
	await close_scene(scene)
	var after = Store.new(); after.load_locker(Store.DEFAULT_PATH)
	var cap := Storage.capacity(after.state)
	check(cap.total == 21 and near(float(after.state.owned[after.state.slots.backpack].durability), 75.0), "after one down: pack 75/100, still 21 units")
	# Cinder uses the same storage.
	scene = await open_scene("res://raid/cinder_basin.tscn")
	if scene.is_raid_ready():
		check(scene.raid_state.haul_capacity == 21 and scene.raid_state.quick_capacity == 2, "cinder: same 21 units, 2 quick slots")
	await close_scene(scene)
	remove_locker()

# --------------------------------------------------------------- Psy text
func shop_text_tests():
	var rig := ShopService.stats_line(Defs.item(Defs.item_id("tactical_rig", 4)))
	var pack := ShopService.stats_line(Defs.item(Defs.item_id("backpack", 3)))
	check(rig.contains("+6 raid haul slots") and rig.contains("3 quick-use slots") and not rig.contains("PR D"), "Psy rig row: " + rig.get_slice("\n", 0))
	check(pack.contains("+9 raid haul slots"), "Psy pack row: " + pack.get_slice("\n", 0))
	var text: String = ShopService.new().loadout_text(kit(2))
	check(text.split("\n").size() == 14 and text.contains("Raid haul 17 units (pouch 8 + rig 3 + pack 6) · 2 quick-use slots"), "Psy loadout shows raid storage: " + text.get_slice("\n", 13))

func run():
	storage_tests()
	supply_tests()
	shop_text_tests()
	await empty_scene_tests()
	await kit_scene_tests()
	print("GEAR_STORAGE_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "facts": facts}))
	quit(0 if failures.is_empty() else 1)
