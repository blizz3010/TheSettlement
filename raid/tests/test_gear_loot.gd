extends SceneTree
## TASKS item 22, gear PR F: tiered gear and composite inserts as raid cache loot.
## Loot table (keys, sizes, tier chances by quality band, found condition, rates),
## raid state (rolls unchanged, take/drop with size), deposit (gear -> locker, parts ->
## composite count, Atlas buys locker overflow), settlement apply_return (locker grant,
## pays once, rollback, downed loses found gear), Psy (T3 -> T4 with a found insert,
## texts), and the real Relay Ridge + Cinder Basin cache panel / extraction / downed flow.
## Headless; disposable XDG profile. Marker line: GEAR_LOOT_TESTS {json}.
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const State = preload("res://raid/scripts/gear_tiers/gear_locker_state.gd")
const Store = preload("res://raid/scripts/gear_tiers/gear_locker_store.gd")
const Storage = preload("res://raid/scripts/gear_tiers/gear_storage.gd")
const ShopService = preload("res://raid/scripts/gear_tiers/gear_shop_service.gd")
const LootTable = preload("res://raid/scripts/raid_loot/loot_table.gd")
const RaidState = preload("res://raid/scripts/raid_state.gd")
const HaulStore = preload("res://raid/scripts/raid_loot/raid_loot_store.gd")
const LootService = preload("res://raid/scripts/raid_loot/raid_loot_service.gd")
const LootInstall = preload("res://raid/scripts/raid_loot/raid_loot_install.gd")
const Outcome = preload("res://raid/scripts/raid_outcome.gd")
const RelayConfig = preload("res://raid/scripts/relay_config.gd")
const CinderConfig = preload("res://raid/scripts/cinder_config.gd")
const ShopTransaction = preload("res://scripts/shop_transaction.gd")
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Request = preload("res://scripts/request_state.gd")
const SAVE_PATH := "user://gear_loot_test/character_save.json"
const GEAR_PATH := "user://gear_loot_test/gear_locker.json"
var checks := 0
var failures: Array = []
var facts := {}

class FakeHost:
	extends Node
	var state = preload("res://scripts/plot_state.gd").new()
	var inventory = preload("res://scripts/inventory_state.gd").new()
	var request = preload("res://scripts/request_state.gd").new()
	var craft = preload("res://scripts/craft_state.gd").new()
	var onboarding = preload("res://scripts/onboarding_state.gd").new()
	var fishing = preload("res://scripts/fishing_state.gd").new()
	var trader_previews
	var save_ok := true
	var saves: Array = []
	var character_save_path := "user://gear_loot_test/character_save.json"
	func save_payload(payload: Dictionary, _notice := true, _writer = null) -> bool:
		if not save_ok: return false
		saves.append(payload)
		return true

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func near(a: float, b: float, eps: float = 0.01) -> bool:
	return absf(a - b) <= eps

func _initialize():
	call_deferred("run")

func _rm(path: String) -> void:
	for f in [path, path + ".tmp", path + ".invalid-backup"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

func wipe():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://gear_loot_test"))
	for f in ["raid_haul.json", "atlas_recovery.json"]: _rm("user://gear_loot_test/" + f)
	_rm(GEAR_PATH)
	_rm(Store.DEFAULT_PATH)

func text_of(node: Node) -> String:
	var t := ""
	for l in node.find_children("*", "Label", true, false): t += l.text + "\n"
	for r in node.find_children("*", "RichTextLabel", true, false): t += r.text + "\n"
	return t

# ---------------------------------------------------------------- loot table
func table_tests():
	var key := LootTable.gear_key(Defs.item_id("body_armor", 2), 70)
	check(key == "gear_body_armor_t2@70", "gear key format: " + key)
	var g := LootTable.parse_gear(key)
	check(g.def == "gear_body_armor_t2" and g.condition == 70 and g.slot == "body_armor" and g.tier == 2, "gear key parses back")
	for bad in ["gear_body_armor_t2", "gear_body_armor_t9@50", "gear_body_armor_t2@0", "gear_body_armor_t2@101", "gear_body_armor_t2@x", "metal@50", "gear_helmet_t1@50@1"]:
		check(LootTable.parse_gear(bad).is_empty() and not LootTable.has_item(bad), "rejects bad gear key " + bad)
	check(LootTable.has_item(key) and LootTable.kind(key) == "gear" and LootTable.is_gear(key) and not LootTable.is_salvage(key), "gear key is a known haul item of kind gear")
	check(LootTable.unit_size(key) == 3 and LootTable.unit_size("gear_visor_t1@50") == 1 and LootTable.unit_size("gear_helmet_t3@50") == 2 and LootTable.unit_size("metal") == 1, "haul units: armor 3, helmet 2, visor 1, metal 1")
	check(LootTable.value(key) == 90 and near(LootTable.unit_weight(key), 5.5), "found T2 vest: worth Psy's 90 sell price, 5.5 kg")
	check(LootTable.display_name(key) == "T2 Scrapplate Vest · 70%", "display name: " + LootTable.display_name(key))
	check(LootTable.units({key: 1, "metal": 2}) == 5 and LootTable.count({key: 1, "metal": 2}) == 3, "units count size, count counts pieces")
	# Composite insert: a part with zero roll weights, so roll() never draws it.
	check(LootTable.is_part("composite_insert") and LootTable.kind("composite_insert") == "part" and LootTable.value("composite_insert") == 0, "composite insert is a raid-only part")
	check(LootTable.ITEMS.composite_insert.weights == [0, 0, 0, 0, 0], "composite insert never drawn by the item roll")
	check(LootTable.by_value(["metal", "composite_insert", "salvage_research_core"])[0] == "composite_insert", "take-all grabs the insert first")
	# Tier chances by quality band (gear_defs TIER_SOURCES).
	var table := []
	for q in range(1, 6):
		var row := []
		for tier in Defs.TIERS: row.append(LootTable.tier_chance(tier, q))
		table.append(row)
	facts["tier_chance_by_quality"] = table
	check(table == [[0.08, 0.0, 0.0, 0.0], [0.08, 0.05, 0.0, 0.0], [0.0, 0.05, 0.04, 0.0], [0.0, 0.0, 0.04, 0.02], [0.0, 0.0, 0.0, 0.04]], "tier chances: q1-2 T1 8%, q2-3 T2 5%, q3-4 T3 4%, q4 T4 2%, q5 T4 4%")
	# Rates over many draws; condition 45-90% in 5% steps; T4 and inserts only at q4-5.
	var N := 20000
	var rates := []
	var insert_rate := []
	var cond_ok := true
	var t4_low := 0
	for q in range(1, 6):
		var counts := [0, 0, 0, 0]
		var inserts := 0
		var rng := RandomNumberGenerator.new()
		for i in N:
			rng.seed = 9000 + q * 100003 + i
			var found := LootTable.roll_gear(rng, q)
			for k in found:
				if k == "composite_insert": inserts += 1; continue
				var p := LootTable.parse_gear(str(k))
				counts[int(p.tier) - 1] += 1
				if int(p.condition) < 45 or int(p.condition) > 90 or int(p.condition) % 5 != 0: cond_ok = false
				if int(p.tier) == 4 and q < 4: t4_low += 1
		var r := []
		for c in counts: r.append(snappedf(float(c) / N, 0.001))
		rates.append(r)
		insert_rate.append(snappedf(float(inserts) / N, 0.001))
	facts["gear_rate_by_quality"] = rates
	facts["insert_rate_by_quality"] = insert_rate
	var rates_ok := true
	for q in 5:
		for t in 4:
			if absf(rates[q][t] - table[q][t]) > 0.006: rates_ok = false
	check(rates_ok, "measured tier rates match the table within 0.6 points: %s" % str(rates))
	check(cond_ok, "found condition always 45-90% in 5% steps")
	check(t4_low == 0 and insert_rate[0] == 0.0 and insert_rate[2] == 0.0 and absf(insert_rate[3] - 0.05) < 0.006 and absf(insert_rate[4] - 0.05) < 0.006, "T4 and inserts only at quality 4-5 (inserts ~5%%): %s" % str(insert_rate))
	var a := RandomNumberGenerator.new(); a.seed = 77
	var b := RandomNumberGenerator.new(); b.seed = 77
	check(LootTable.roll_gear(a, 5) == LootTable.roll_gear(b, 5), "gear roll deterministic for a seed")

# ---------------------------------------------------------------- raid state
func state_tests():
	# Item and supply rolls for a seed are unchanged by the gear draw (drawn last).
	var same := true
	var seen_gear := 0
	var t4_sites := {}
	for seed in range(1, 401):
		for poi in RelayConfig.new().pois() + CinderConfig.new().pois():
			var st := RaidState.new(seed)
			st.unlocked[poi.id] = true
			var r: Dictionary = st.search_cache(poi)
			var rng := RandomNumberGenerator.new(); rng.seed = seed + int(poi.id.hash()) + 771
			var q := rng.randi_range(poi.loot[0], poi.loot[1])
			var items := LootTable.roll(rng, q)
			var sup := LootTable.roll_supplies(rng, q)
			var gear := LootTable.roll_gear(rng, q)
			if q != r.quality or items != r.items or sup != r.supplies or gear != r.gear: same = false
			seen_gear += r.gear.size()
			for k in r.gear:
				if LootTable.is_gear(str(k)) and int(LootTable.parse_gear(str(k)).tier) == 4: t4_sites[poi.name] = int(t4_sites.get(poi.name, 0)) + 1
	check(same, "search_cache: quality, items and supplies unchanged; gear drawn last (400 seeds x 12 POIs)")
	facts["t4_drops_in_400_seeds"] = t4_sites
	check(t4_sites.has("Relay Tower") and t4_sites.has("Research Annex") and t4_sites.has("Helion Mirror Array") and t4_sites.has("Obsidian Archive"), "T4 drops at Relay Tower, Research Annex, Helion and Obsidian: %s" % str(t4_sites))
	check(not t4_sites.has("Survey Camp") and not t4_sites.has("Siltway Caravan") and not t4_sites.has("West Substation"), "no T4 from low-quality sites")
	# Expected gear pieces per full raid (all six caches), from the bands.
	for map in [["relay", RelayConfig.new().pois()], ["cinder", CinderConfig.new().pois()]]:
		var e := 0.0
		var e4 := 0.0
		for poi in map[1]:
			var lo: int = poi.loot[0]; var hi: int = poi.loot[1]
			for q in range(lo, hi + 1):
				for tier in Defs.TIERS:
					e += LootTable.tier_chance(tier, q) / float(hi - lo + 1)
				e4 += LootTable.tier_chance(4, q) / float(hi - lo + 1)
		facts["expected_gear_per_full_raid_" + map[0]] = snappedf(e, 0.001)
		facts["expected_t4_per_full_raid_" + map[0]] = snappedf(e4, 0.001)
	# Take with size.
	var s := RaidState.new(5)
	var camp := {"id": "camp", "lock": "", "loot": [1, 2]}
	s.search_cache(camp)
	s.cache_contents["camp"] = {"metal": 6}
	s.cache_gear["camp"] = {"gear_body_armor_t2@70": 1, "composite_insert": 1, "gear_visor_t1@50": 1}
	var loot := s.cache_loot("camp")
	check(loot.keys()[0] == "gear_body_armor_t2@70" and loot.has("metal") and loot.size() == 4, "cache_loot lists gear first, then items")
	check(s.take_from_cache("camp", "metal", 6) == 6 and s.haul_units() == 6 and s.haul_space() == 2, "6 metal: 2 units left")
	check(not s.fits("gear_body_armor_t2@70") and s.take_from_cache("camp", "gear_body_armor_t2@70") == 0, "a 3-unit vest does not fit in 2")
	check(s.drop_from_haul("metal", 2) == 2 and s.take_from_cache("camp", "gear_body_armor_t2@70") == 1 and s.haul_units() == 7, "drop 2 metal, the vest fits: 7 / 8 units")
	check(not s.cache_gear.camp.has("gear_body_armor_t2@70") and s.cache_has_anything("camp"), "vest left the cache; insert and visor still there")
	var taken := s.take_all("camp")
	check(taken.has("composite_insert") and s.haul_units() == 8 and not taken.has("gear_visor_t1@50"), "take all: the insert first, the visor no longer fits")
	check(s.summary().haul_gear == {"gear_body_armor_t2@70": 1, "composite_insert": 1}, "summary lists found gear in the haul")
	check(near(Storage.load_weight({"gear_body_armor_t2@70": 1, "metal": 8}), (5.5 + 9.6) * 3.0 / 11.0), "load weight counts the vest's kg and its 3 units")

# ---------------------------------------------------------------- deposit
func deposit_tests():
	var svc := LootService.new()
	var plot := Plot.new(); var inv := Inventory.new(); inv.carried = {}
	var out := {"haul": {"metal": 2, "gear_helmet_t3@60": 1, "gear_boots_t1@85": 1, "composite_insert": 2}, "raid_uid": "dep-1"}
	var c: Dictionary = svc.deposit(plot, inv, Request.new(), HaulStore.new(), out)
	check(not c.is_empty(), "gear haul deposits " + svc.last_error)
	if c.is_empty(): return
	var r: Dictionary = c.receipt
	check(r.to_gear == {"gear_helmet_t3@60": 1, "gear_boots_t1@85": 1} and r.to_parts == {"composite_insert": 2}, "receipt: to_gear and to_parts")
	check(c.inventory.amount("carried", "metal") == 2 and not c.inventory.carried.has("composite_insert") and r.brought == 6, "metal to the bag; gear and inserts never touch the pinned inventory")
	check(r.message.contains("gear to your locker (Psy · Equip): T3 Warden Helm · 60% × 1") and r.message.contains("Composite insert × 2"), "message: " + r.message)
	var hs := HaulStore.new(); check(hs.restore(c.haul) and hs.salvage.is_empty() and hs.cargo.is_empty(), "raid_haul.json holds no gear")
	# Locker room for only one piece: Atlas buys the rest at Psy's sell price.
	out.raid_uid = "dep-2"; out.locker_free = 1
	var c2: Dictionary = svc.deposit(Plot.new(), Inventory.new(), Request.new(), HaulStore.new(), out)
	var paid := int(c2.receipt.atlas_paid) if not c2.is_empty() else -1
	check(not c2.is_empty() and LootTable.count(c2.receipt.to_gear) == 1 and LootTable.count(c2.receipt.to_atlas_gear) == 1 and c2.plot.credits == 150 + paid and paid > 0, "locker full: Atlas buys the overflow (%d cr)" % paid)
	check(svc.deposit(Plot.new(), Inventory.new(), Request.new(), HaulStore.new(), {"haul": {"gear_helmet_t9@60": 1}, "raid_uid": "bad"}).is_empty(), "unknown gear key refused")

# ---------------------------------------------------------------- settlement return
func return_tests():
	wipe()
	var host := FakeHost.new(); root.add_child(host)
	host.inventory.carried = {}
	var out := {"outcome": "extracted", "map": "Relay Ridge", "haul": {"metal": 1, "gear_helmet_t3@60": 1, "gear_body_armor_t4@80": 1, "composite_insert": 1}, "raid_uid": "gl-1", "loot_persisted": true}
	var note := LootInstall.apply_return(host, out, GEAR_PATH)
	var disk := Store.new(); disk.load_locker(GEAR_PATH)
	var defs := []
	for r in disk.state.owned.values(): defs.append(r.def)
	defs.sort()
	check(defs == ["gear_body_armor_t4", "gear_helmet_t3"] and int(disk.state.shop.composite_insert) == 1, "extract: 2 pieces and 1 insert in gear_locker.json " + str(defs))
	var dur := {}
	for r in disk.state.owned.values(): dur[r.def] = float(r.durability)
	check(near(dur.get("gear_helmet_t3", -1.0), 54.0) and near(dur.get("gear_body_armor_t4", -1.0), 88.0), "found condition kept: helmet 60% of 90 = 54, T4 vest 80% of 110 = 88")
	check(note.contains("gear to your locker") and host.inventory.amount("carried", "metal") == 1 and host.saves.size() == 1, "note + metal in the bag: " + note)
	check(LootInstall.apply_return(host, out, GEAR_PATH) == "", "same return twice: refused")
	var disk2 := Store.new(); disk2.load_locker(GEAR_PATH)
	check(disk2.state.owned.size() == 2 and int(disk2.state.shop.composite_insert) == 1, "same return twice grants gear once")
	# Main save fails: the locker is rolled back too.
	host.save_ok = false
	var fail_note := LootInstall.apply_return(host, {"outcome": "extracted", "haul": {"gear_visor_t2@50": 1}, "raid_uid": "gl-2"}, GEAR_PATH)
	var disk3 := Store.new(); disk3.load_locker(GEAR_PATH)
	check(fail_note.contains("could not be saved") and disk3.state.owned.size() == 2, "failed main save: no gear granted")
	host.save_ok = true
	# Downed: found gear in the haul is lost; the locker is not touched.
	LootInstall.apply_return(host, {"outcome": "downed", "haul_lost": {"gear_visor_t2@50": 1}, "raid_uid": "gl-3"}, GEAR_PATH)
	var disk4 := Store.new(); disk4.load_locker(GEAR_PATH)
	check(disk4.state.owned.size() == 2, "downed: found gear lost, locker unchanged")
	# A haul without gear never creates the locker file.
	_rm(Store.DEFAULT_PATH)
	LootInstall.apply_return(host, {"outcome": "extracted", "haul": {"metal": 1}, "raid_uid": "gl-4"})
	check(not FileAccess.file_exists(Store.DEFAULT_PATH), "gear-free haul leaves the gear locker alone")
	host.queue_free()
	await process_frame

# ---------------------------------------------------------------- Psy
func trade(locker, action: String, item: String, plot, inv) -> Dictionary:
	var svc := ShopService.new()
	var tx := ShopTransaction.new(svc.quote_candidate)
	var ctx := {"service": "psy", "locker": locker.data()}
	var q := tx.select("psy", action, item, 1, plot, inv, Request.new(), ctx)
	if q.is_empty(): return {"ok": false, "error": svc.last_error + tx.last_error}
	var done: Dictionary = tx.confirm(q.token, plot, inv, Request.new(), func(): return true, func(_x): return true, ctx)
	if done.is_empty(): return {"ok": false, "error": svc.last_error + tx.last_error}
	var nl = State.new(); nl.restore(done.locker)
	return {"ok": true, "locker": nl, "plot": done.plot}

func psy_tests():
	var disk := Store.new(); disk.load_locker(GEAR_PATH)
	var locker = disk.state
	var helm := ""
	for id in locker.owned:
		if locker.owned[id].def == "gear_helmet_t3": helm = id
	var plot := Plot.new(); plot.credits = 3000
	var svc := ShopService.new()
	var rows: Array = svc.rows("upgrade", plot, Inventory.new(), locker)
	var row: Dictionary = {}
	for r in rows:
		if r.id == helm: row = r
	check(not row.is_empty() and row.enabled and str(row.description).contains("You have 1.") and not str(row.description).contains("PR F"), "Psy upgrade row: found insert makes T3 -> T4 available")
	var done := trade(locker, "upgrade", helm, plot, Inventory.new())
	check(done.ok and done.locker.owned[helm].def == "gear_helmet_t4" and int(done.locker.shop.composite_insert) == 0 and done.plot.credits == 3000 - Defs.upgrade_cost("gear_helmet_t3"), "found helmet + found insert: T3 -> T4 at Psy " + str(done.get("error", "")))
	var empty = State.new(); empty.extractions = 10
	var h3 := empty.grant("gear_helmet_t3")
	var why := trade(empty, "upgrade", h3, plot, Inventory.new())
	check(not why.ok and str(why.error).contains("quality 4-5 caches") and not str(why.error).contains("PR F"), "no insert: " + str(why.error))
	check(svc.loadout_text(locker).contains("Composite inserts 1") and svc.loadout_text(locker).split("\n").size() == 14, "loadout shows the insert count (still 14 lines)")
	# Found worn pieces: repair costs, sell at the normal 50%.
	var vest := ""
	for id in locker.owned:
		if locker.owned[id].def == "gear_body_armor_t4": vest = id
	check(Defs.repair_cost("gear_body_armor_t4", float(locker.owned[vest].durability)) == 90, "found T4 vest at 80%: repair 30% x 1500 x 0.2 = 90")
	var sold := trade(locker, "sell", vest, Plot.new(), Inventory.new())
	check(sold.ok and sold.plot.credits == 150 + 750, "found T4 vest sells for 750 at Psy")
	var buy_rows: Array = svc.rows("buy", plot, Inventory.new(), State.new())
	var t4_reason := ""
	for r in buy_rows:
		if r.id == "gear_helmet_t4": t4_reason = str(r.reason)
	check(t4_reason.contains("quality 4-5 raid caches"), "Psy T4 buy row points at raid loot: " + t4_reason)

# ---------------------------------------------------------------- real scenes
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

func scene_tests():
	_rm(Store.DEFAULT_PATH)
	var scene = await open_scene("res://raid/relay_ridge.tscn")
	if not scene.is_raid_ready(): return
	var rs = scene.raid_state
	var t := cache_target(scene, "camp")
	rs.search_cache(t.poi)
	rs.cache_contents["camp"] = {"metal": 6}
	rs.cache_supplies["camp"] = {}
	rs.cache_gear["camp"] = {"gear_body_armor_t2@70": 1, "composite_insert": 1}
	scene._cache_panel(t)
	var text := text_of(scene.modal_content)
	check(text.contains("T2 Scrapplate Vest · 70% × 1   (body armor · 3 haul units · 5.5 kg · Psy buys 90)"), "cache row shows the found vest")
	check(text.contains("Composite insert × 1   (gear part · Psy's T3 → T4 upgrade · raid-only)"), "cache row shows the insert")
	var badges: Array = scene.modal_content.find_children("TierBadge", "PanelContainer", true, false)
	check(badges.size() == 1 and text.contains("T2"), "tier badge on the gear row")
	var take := modal_button(scene, "Loot_metal")
	if take != null: take.pressed.emit()
	await process_frame
	check(rs.haul_units() == 6, "took 6 metal")
	var vest_btn := modal_button(scene, "Loot_gear_body_armor_t2_c70")
	check(vest_btn != null and vest_btn.disabled and vest_btn.text == "Needs 3", "vest row: Needs 3 when only 2 units are free")
	var ins := modal_button(scene, "Loot_composite_insert")
	check(ins != null and not ins.disabled, "insert row: Take (1 unit)")
	scene._haul_panel()
	await process_frame
	for i in 2:
		var drop := modal_button(scene, "Loot_metal")
		if drop != null: drop.pressed.emit()
		await process_frame
	scene._cache_panel(t)
	await process_frame
	vest_btn = modal_button(scene, "Loot_gear_body_armor_t2_c70")
	if vest_btn != null and not vest_btn.disabled: vest_btn.pressed.emit()
	await process_frame
	check(rs.haul.has("gear_body_armor_t2@70") and rs.haul_units() == 7, "vest taken through the panel: 7 / 8 units")
	scene._process(0.016)
	check(scene.status.text.contains("Haul 7/8"), "HUD counts the vest as 3 units")
	scene._close_modal()
	rs.extracted_at = "extract1"
	Outcome.last = {}
	scene._extraction_complete()
	await process_frame
	var out: Dictionary = Outcome.peek()
	check(out.get("haul", {}).has("gear_body_armor_t2@70") and text_of(scene.modal_content).contains("Found gear and composite inserts go to your gear locker"), "extraction outcome carries the vest; summary says where it goes")
	await close_scene(scene)
	# Downed with found gear: lost with the haul.
	scene = await open_scene("res://raid/cinder_basin.tscn")
	if not scene.is_raid_ready(): return
	rs = scene.raid_state
	rs.haul = {"gear_helmet_t4@85": 1, "metal": 1}
	Outcome.last = {}
	var h = scene.health_controller.health
	h.invulnerable_left = 0.0
	h.damage(500.0, "unknown")
	for i in 4: await process_frame
	var down: Dictionary = Outcome.peek()
	check(down.get("outcome", "") == "downed" and down.get("haul_lost", {}).has("gear_helmet_t4@85"), "cinder downed: found T4 helmet recorded as lost")
	check(text_of(scene.modal_content).contains("Found gear in your haul is lost with it."), "downed screen says found gear is lost")
	await close_scene(scene)
	Outcome.last = {}

func run():
	wipe()
	table_tests()
	state_tests()
	deposit_tests()
	await return_tests()
	psy_tests()
	await scene_tests()
	wipe()
	print("GEAR_LOOT_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "facts": facts}))
	quit(0 if failures.is_empty() else 1)
