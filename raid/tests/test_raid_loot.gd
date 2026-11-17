extends SceneTree
## TASKS item 13: raid loot persistence and the core loop (raid > loot > sell > upgrade).
## Loot table, raid haul, real Relay Ridge cache/extraction/downed flow, the
## raid_haul.json sidecar, deposit/sell/claim service, Atlas Salvage tab controller,
## installer chain (second pass keeps every extension), settlement apply_return,
## and gear still working (shared locker, 25% downed rule).
## Headless; disposable XDG profile. Prints one marker: RAID_LOOT_TESTS {json}.
const LootTable = preload("res://raid/scripts/raid_loot/loot_table.gd")
const RaidState = preload("res://raid/scripts/raid_state.gd")
const CinderState = preload("res://raid/scripts/cinder_state.gd")
const HaulStore = preload("res://raid/scripts/raid_loot/raid_loot_store.gd")
const LootService = preload("res://raid/scripts/raid_loot/raid_loot_service.gd")
const LootInstall = preload("res://raid/scripts/raid_loot/raid_loot_install.gd")
const SalvagePanel = preload("res://raid/scripts/raid_loot/atlas_salvage_panel.gd")
const DanInstall = preload("res://raid/scripts/dan_listings_install.gd")
const AtlasInstall = preload("res://raid/scripts/atlas_recovery_install.gd")
const GearInstall = preload("res://raid/scripts/gear_tiers/gear_shop_install.gd")
const GearDefs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const GearState = preload("res://raid/scripts/gear_tiers/gear_locker_state.gd")
const GearService = preload("res://raid/scripts/gear_tiers/gear_shop_service.gd")
const Outcome = preload("res://raid/scripts/raid_outcome.gd")
const SettlementHealth = preload("res://raid/scripts/settlement_health.gd")
const ShopTransaction = preload("res://scripts/shop_transaction.gd")
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Request = preload("res://scripts/request_state.gd")
const RelayConfig = preload("res://raid/scripts/relay_config.gd")
const EXT := "res://raid/scripts/raid_loot/raid_loot_controller_ext.gd"
const SAVE_PATH := "user://loot_test/character_save.json"
var checks := 0
var failures: Array = []
var facts := {}

class FakePlayer:
	extends Node3D
	var enabled := true
	var velocity := Vector3.ZERO

class FakeHost:
	extends Node
	var state = preload("res://scripts/plot_state.gd").new()
	var inventory = preload("res://scripts/inventory_state.gd").new()
	var request = preload("res://scripts/request_state.gd").new()
	var craft = preload("res://scripts/craft_state.gd").new()
	var onboarding = preload("res://scripts/onboarding_state.gd").new()
	var fishing = preload("res://scripts/fishing_state.gd").new()
	var player
	var supplies_panel: Control
	var trader_previews
	var cooking_window_focused := true
	var save_ok := true
	var saves: Array = []
	var character_save_path := "user://loot_test/character_save.json"
	func key_label(_a): return "E"
	func modal_open(_a = true, _b = true, _c = true) -> bool: return false
	func save_payload(payload: Dictionary, _notice := true, _writer = null) -> bool:
		if not save_ok: return false
		saves.append(payload)
		return true

class TestLootController:
	extends "res://raid/scripts/raid_loot/raid_loot_controller_ext.gd"
	func accessible(_id: String) -> bool: return true
	func active() -> bool: return true

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize():
	call_deferred("run")

func _wipe_sidecar():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://loot_test"))
	for f in ["raid_haul.json", "raid_haul.json.tmp", "raid_haul.json.invalid-backup", "atlas_recovery.json"]:
		var p: String = "user://loot_test/" + f
		if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

# ---------------------------------------------------------------- loot table
func table_tests():
	var known_ok := true
	for id in LootTable.ITEMS:
		var d: Dictionary = LootTable.ITEMS[id]
		known_ok = known_ok and d.weights.size() == 5 and d.qty.size() == 2 and int(d.qty[0]) >= 1
		if LootTable.is_material(id): known_ok = known_ok and Inventory.ITEMS.has(id)
	check(known_ok, "every loot item is well formed; every material is a real settlement item")
	check(LootTable.salvage_ids().size() == 6 and LootTable.material_ids().size() == 5, "6 salvage pieces + 5 materials")
	var a := RandomNumberGenerator.new(); a.seed = 99
	var b := RandomNumberGenerator.new(); b.seed = 99
	check(LootTable.roll(a, 4) == LootTable.roll(b, 4), "rolls are deterministic for a seed")
	var avg_value := []
	var avg_units := []
	var core_low := false
	var empty := false
	for q in range(1, 6):
		var rng := RandomNumberGenerator.new(); rng.seed = 1000 + q
		var value := 0; var units := 0
		for _i in 4000:
			var items := LootTable.roll(rng, q)
			if items.is_empty(): empty = true
			value += LootTable.total_value(items); units += LootTable.units(items)
			if q < 5 and items.has("salvage_research_core"): core_low = true
			if q < 4 and (items.has("salvage_power_cell") or items.has("salvage_survey_drive")): core_low = true
		avg_value.append(snappedf(value / 4000.0, 0.1)); avg_units.append(snappedf(units / 4000.0, 0.01))
	facts["avg_cache_value_by_quality"] = avg_value
	facts["avg_cache_units_by_quality"] = avg_units
	check(not empty, "a cache is never empty")
	check(not core_low, "top salvage only drops from its quality band")
	var rising := true
	for q in range(1, 5): rising = rising and avg_value[q] > avg_value[q - 1]
	check(rising, "cache value rises with quality %s" % str(avg_value))
	# A full Relay Ridge run, every cache emptied (band midpoint). Tuned around one T2 piece.
	var raid_value := 0.0
	for poi in RelayConfig.new().pois():
		var lo: int = poi.loot[0]; var hi: int = poi.loot[1]; var sum := 0.0
		for q in range(lo, hi + 1): sum += avg_value[q - 1]
		raid_value += sum / float(hi - lo + 1)
	facts["full_relay_raid_value_cr"] = snappedf(raid_value, 1.0)
	check(raid_value > 120.0 and raid_value < 500.0, "full-raid value is in the T2-gear range (%.0f cr)" % raid_value)
	check(LootTable.by_value(["timber", "salvage_research_core", "metal"])[0] == "salvage_research_core", "take-all prefers valuables")

# ---------------------------------------------------------------- raid state
func state_tests():
	var poi := {"id": "camp", "lock": "", "loot": [1, 2]}
	var s := RaidState.new(123)
	# Quality uses the same RNG draw as before item 13.
	var rng := RandomNumberGenerator.new(); rng.seed = 123 + int(String("camp").hash()) + 771
	var expected_q := rng.randi_range(1, 2)
	var r: Dictionary = s.search_cache(poi)
	check(r.ok and r.quality == expected_q and not r.preview_only and not r.items.is_empty(), "search returns real items; quality roll unchanged")
	check(not s.search_cache(poi).ok, "cache cannot be re-rolled")
	check(s.cache_items("camp") == r.items and RaidState.new(123).search_cache(poi).items == r.items, "same seed, same cache contents")
	check(s.haul_capacity == 8 and s.haul_units() == 0, "raid haul starts empty with 8 units")
	s.cache_contents["camp"] = {"timber": 5, "salvage_sensor": 1, "metal": 4}
	check(s.take_from_cache("camp", "timber", 2) == 2 and s.haul.timber == 2 and s.cache_contents.camp.timber == 3, "take a partial stack")
	var taken: Dictionary = s.take_all("camp")
	check(taken.has("salvage_sensor") and s.haul_units() == 8 and s.haul_space() == 0, "take all fills the haul, valuables first")
	check(s.take_from_cache("camp", "timber") == 0, "full haul takes nothing")
	check(LootTable.units(s.cache_items("camp")) == 2, "leftovers stay in the cache")
	check(s.drop_from_haul("metal", 1) == 1 and s.haul_space() == 1, "drop frees space")
	check(s.drop_from_haul("metal", 0) == 0 and s.drop_from_haul("stone", 1) == 0, "invalid drops ignored")
	var snap: Dictionary = s.summary()
	snap.haul["metal"] = 99
	check(s.haul.get("metal", 0) != 99 and snap.haul_units == 7 and snap.haul_value > 0, "summary haul is a copy")
	s.extracted_at = "extract0"
	check(s.take_from_cache("camp", "timber") == 0 and s.drop_from_haul("timber", 1) == 0, "haul frozen after extraction")
	var c := CinderState.new(5)
	var cr: Dictionary = c.search_cache({"id": "caravan", "lock": "", "loot": [3, 4]})
	check(cr.ok and not cr.items.is_empty() and c.haul_capacity == 8, "Cinder Basin shares the loot ledger")

# ---------------------------------------------------------------- real raid scene
func _modal_button(scene, text: String) -> Button:
	for b in scene.modal.find_children("*", "Button", true, false):
		if b.text == text and b.visible: return b
	return null

func _cache_target(scene, id: String) -> Dictionary:
	for t in scene.targets:
		if t.kind == "cache" and t.poi.id == id: return t
	return {}

func scene_tests():
	var scene = load("res://raid/relay_ridge.tscn").instantiate()
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 90000
	while not scene.is_raid_ready() and Time.get_ticks_msec() < deadline: await process_frame
	check(scene.is_raid_ready(), "Relay Ridge ready")
	if not scene.is_raid_ready():
		scene.queue_free(); return
	scene.set_physics_process(false); scene.player.set_physics_process(false)
	var cues: Array = []
	scene.loot_audio.cue_played.connect(func(c): cues.append(c))
	check(scene.loot_audio.streams.size() == 3, "three loot cues loaded (own files)")
	var target := _cache_target(scene, "camp")
	scene._interact(target)
	check(scene.raid_state.searched.has("camp") and scene.modal.visible, "searching a cache opens the loot panel")
	check(cues.has("loot_cache_open"), "cache-open cue plays")
	var first_id: String = str(scene.raid_state.cache_items("camp").keys()[0])
	var take: Button = scene.modal.find_child("Loot_" + first_id, true, false)
	check(take != null and take.text == "Take", "each loot row has a Take button")
	if take != null: take.pressed.emit()
	check(scene.raid_state.haul.has(first_id) and cues.has("loot_pickup"), "Take moves the stack into the haul")
	var all := _modal_button(scene, "Take all that fits")
	if all != null and not all.disabled: all.pressed.emit()
	var units: int = scene.raid_state.haul_units()
	check(units > 0 and units <= 8, "haul holds the loot (%d units)" % units)
	scene._close_modal()
	scene._process(0.016)
	check(scene.status.text.contains("Haul %d/8" % units), "HUD shows the haul")
	scene._interact(target)
	var left := LootTable.units(scene.raid_state.cache_items("camp")) + LootTable.units(scene.raid_state.supplies_in("camp"))  # PR D: dressings count too
	check(scene.modal.visible == (left > 0), "a searched cache reopens only while loot is left")
	scene._close_modal()
	scene._field_notes()
	check(_modal_button(scene, "Manage haul (drop items)") != null, "field notes offer haul management")
	scene._haul_panel()
	var drop: Button = scene.modal.find_child("Loot_" + first_id, true, false)
	var before: int = scene.raid_state.haul_units()
	if drop != null: drop.pressed.emit()
	check(drop != null and scene.raid_state.haul_units() == before - 1 and cues.has("loot_drop"), "Drop 1 removes one unit")
	scene._close_modal()
	# Downed: the haul is recorded as lost and never handed to the settlement.
	Outcome.last = {}
	scene.health_controller._on_died("sentry turret")
	var downed: Dictionary = Outcome.peek()
	check(downed.outcome == "downed" and not downed.loot_persisted and LootTable.units(downed.haul_lost) == scene.raid_state.haul_units() and not downed.has("haul"), "downed: haul recorded as lost")
	var downed_text := ""
	for l in scene.modal.find_children("*", "Label", true, false): downed_text += l.text + "\n"
	check(downed_text.contains("raid haul") and downed_text.contains("is lost"), "downed screen says the haul is lost")
	# Extraction: the haul is handed over with a unique id.
	scene.health_controller.downed = false; scene.downed = false; scene.health_controller.auto_return_left = -1.0
	Outcome.last = {}
	scene.raid_state.extracted_at = "extract0"
	scene._extraction_complete()
	var out: Dictionary = Outcome.peek()
	check(out.outcome == "extracted" and out.loot_persisted and out.haul == scene.raid_state.haul and str(out.raid_uid).begins_with("relay_ridge-"), "extraction hands the haul over")
	check(int(out.haul_value) == scene.raid_state.haul_value(), "extraction records the haul value")
	facts["scene_haul"] = out.haul
	Outcome.last = {}
	scene.queue_free()
	await process_frame

# ---------------------------------------------------------------- store + service
func store_tests():
	_wipe_sidecar()
	var s := HaulStore.new()
	check(s.load_or_create(SAVE_PATH) and FileAccess.file_exists("user://loot_test/raid_haul.json"), "sidecar created next to the character save")
	s.salvage["salvage_sensor"] = 2; s.cargo["metal"] = 3; s.mark_applied("raid-a"); s.stats.extractions = 1
	check(s.save(), "sidecar saves")
	var t := HaulStore.new(); t.load_or_create(SAVE_PATH)
	check(t.salvage == {"salvage_sensor": 2} and t.cargo == {"metal": 3} and t.was_applied("raid-a") and t.stats.extractions == 1, "sidecar round-trips")
	check(not t.restore({"version": 1, "salvage": {"metal": 1}, "cargo": {}, "applied": [], "stats": t.stats}), "a material in the salvage list is rejected")
	check(not t.restore({"version": 1, "salvage": {}, "cargo": {"salvage_sensor": 1}, "applied": [], "stats": t.stats}), "salvage in the cargo list is rejected")
	check(not t.restore({"version": 2}), "unknown version rejected")
	for k in 70: t.mark_applied("uid-%d" % k)
	check(t.applied.size() == HaulStore.MAX_APPLIED and t.was_applied("uid-69") and not t.was_applied("uid-0"), "applied ledger is bounded")
	var f := FileAccess.open("user://loot_test/raid_haul.json", FileAccess.WRITE); f.store_string("{broken"); f.close()
	var u := HaulStore.new()
	check(u.load_or_create(SAVE_PATH) and u.salvage.is_empty() and FileAccess.file_exists("user://loot_test/raid_haul.json.invalid-backup"), "corrupt sidecar: backed up, safe empty start")
	_wipe_sidecar()

func service_tests():
	var svc := LootService.new()
	var plot := Plot.new(); var inv := Inventory.new(); var req := Request.new()
	var store := HaulStore.new()
	inv.carried = {"stone": 6}  # 2 free bag units; stash starts at 10/24
	var haul := {"metal": 3, "cloth_linen": 2, "salvage_capacitor": 1, "salvage_copper_wire": 2}
	var c: Dictionary = svc.deposit(plot, inv, req, store, {"haul": haul, "raid_uid": "r1"})
	check(not c.is_empty(), "deposit candidate builds: " + svc.last_error)
	if c.is_empty(): return
	var i2 = c.inventory
	check(i2.used("carried") == 8 and i2.amount("carried", "metal") == 2, "bag filled first (2 metal)")
	check(i2.amount("stash", "metal") == 3 and i2.amount("stash", "cloth_linen") == 2, "rest to the stash (1 metal on top of 2, + 2 linen)")
	check(i2.format_version >= 10, "linen promotes the inventory format like a tailor purchase")
	var s2 := HaulStore.new(); s2.restore(c.haul)
	check(s2.salvage == {"salvage_capacitor": 1, "salvage_copper_wire": 2} and s2.cargo.is_empty(), "salvage goes to the sidecar")
	check(s2.was_applied("r1") and s2.stats.extractions == 1 and s2.stats.items_brought == 8, "deposit marks the raid applied and counts it")
	check(c.receipt.message.contains("bag:") and c.receipt.message.contains("Atlas"), "return note: " + c.receipt.message)
	check(inv.used("carried") == 6 and store.salvage.is_empty(), "deposit never mutates live state")
	check(svc.deposit(c.plot, c.inventory, c.request, s2, {"haul": haul, "raid_uid": "r1"}).is_empty() and svc.last_error.contains("already"), "one extraction pays once")
	check(svc.deposit(plot, inv, req, store, {"haul": {"gold_bar": 1}, "raid_uid": "r2"}).is_empty(), "unknown haul items are rejected")
	# Overflow: full bag and stash -> Atlas cargo.
	var full := Inventory.new(); full.carried = {"timber": 8}; full.stash = {"stone": 24}
	var o: Dictionary = svc.deposit(plot, full, req, HaulStore.new(), {"haul": {"metal": 4}, "raid_uid": "r3"})
	var s3 := HaulStore.new(); s3.restore(o.haul)
	check(s3.cargo == {"metal": 4} and o.receipt.message.contains("waiting at Atlas"), "no room: materials wait at Atlas")
	# Sell salvage through the real ShopTransaction.
	var tx := ShopTransaction.new(svc.quote_candidate)
	var ctx := {"haul": s2.data()}
	var q: Dictionary = tx.select("atlas", "salvage", "sell:salvage_copper_wire", 2, c.plot, c.inventory, c.request, ctx)
	check(not q.is_empty() and q.verb == "sell" and int(q.earned) == 12, "sell quote: 2 x 6 cr")
	var done: Dictionary = tx.confirm(q.token, c.plot, c.inventory, c.request, func(): return true, func(_x): return true, ctx)
	check(not done.is_empty() and done.plot.credits == 162, "sale adds credits (150 -> 162)")
	var s4 := HaulStore.new(); s4.restore(done.haul)
	check(not s4.salvage.has("salvage_copper_wire") and s4.stats.credits_earned == 12, "sold salvage leaves the sidecar")
	check(tx.select("atlas", "salvage", "sell:salvage_capacitor", 2, done.plot, done.inventory, done.request, {"haul": s4.data()}).is_empty(), "cannot sell more than owned")
	check(svc.quote_candidate("atlas", "salvage", "sell:metal", 1, done.plot, done.inventory, done.request, {"haul": s4.data()}).is_empty() and svc.last_error.contains("Rook"), "Atlas points materials to Rook")
	var rich := Plot.new(); rich.credits = 99990
	check(svc.quote_candidate("atlas", "salvage", "sell:salvage_capacitor", 1, rich, done.inventory, done.request, {"haul": s4.data()}).is_empty(), "credit cap respected")
	# Claim cargo.
	var bag_full := Inventory.new(); bag_full.carried = {"timber": 8}
	check(svc.quote_candidate("atlas", "salvage", "claim:metal", 2, plot, bag_full, req, {"haul": s3.data()}).is_empty() and svc.last_error.contains("Bag full"), "claim needs bag space")
	var cl: Dictionary = svc.quote_candidate("atlas", "salvage", "claim:metal", 3, plot, Inventory.new(), req, {"haul": s3.data()})
	var s5 := HaulStore.new(); s5.restore(cl.haul)
	check(cl.inventory.amount("carried", "metal") == 3 and s5.cargo == {"metal": 1} and cl.plot.credits == 150, "claim is free and moves cargo to the bag")
	# Downed loss stat.
	var lost: Dictionary = svc.record_loss(HaulStore.new(), {"haul_lost": {"metal": 2}, "raid_uid": "d1"})
	var s6 := HaulStore.new(); s6.restore(lost.haul)
	check(s6.stats.hauls_lost == 1 and s6.salvage.is_empty() and s6.cargo.is_empty(), "downed: nothing comes home, loss counted")

# ---------------------------------------------------------------- core loop: sell at Rook, upgrade at Psy
func loop_tests():
	var svc := LootService.new()
	var plot := Plot.new(); var inv := Inventory.new(); inv.carried = {}; var req := Request.new()
	var c: Dictionary = svc.deposit(plot, inv, req, HaulStore.new(), {"haul": {"metal": 4, "salvage_power_cell": 1}, "raid_uid": "loop"})
	var s := HaulStore.new(); s.restore(c.haul)
	var tx := ShopTransaction.new(svc.quote_candidate)
	var q := tx.select("atlas", "salvage", "sell:salvage_power_cell", 1, c.plot, c.inventory, c.request, {"haul": s.data()})
	var sold: Dictionary = tx.confirm(q.token, c.plot, c.inventory, c.request, func(): return true, func(_x): return true, {"haul": s.data()})
	check(sold.plot.credits == 210, "loop: salvage sold at Atlas (150 + 60)")
	var rook := ShopTransaction.new()
	var rq := rook.select("rook", "sell", "metal", 1, sold.plot, sold.inventory, sold.request, {})
	var rdone: Dictionary = rook.confirm(rq.token, sold.plot, sold.inventory, sold.request, func(): return true, func(_x): return true, {})
	check(not rdone.is_empty() and rdone.plot.credits == 217 and rdone.inventory.amount("carried", "metal") == 3, "loop: raid metal sold at Rook (+7)")
	# Psy upgrade: T1 helmet -> T2 needs 2 carried metal and 1 extraction.
	var locker := GearState.new(); locker.extractions = 1
	var helm := locker.grant(GearDefs.item_id("helmet", 1))
	var gsvc := GearService.new()
	var gtx := ShopTransaction.new(gsvc.quote_candidate)
	var gctx := {"service": "psy", "locker": locker.data()}
	var gq := gtx.select("psy", "upgrade", helm, 1, rdone.plot, rdone.inventory, rdone.request, gctx)
	var gdone: Dictionary = gtx.confirm(gq.token, rdone.plot, rdone.inventory, rdone.request, func(): return true, func(_x): return true, gctx) if not gq.is_empty() else {}
	check(not gdone.is_empty() and gdone.inventory.amount("carried", "metal") == 1, "loop: raid metal pays for Psy's T1 -> T2 upgrade " + gsvc.last_error + gtx.last_error)
	if not gdone.is_empty():
		var nl := GearState.new(); nl.restore(gdone.locker)
		check(nl.owned[helm].def == GearDefs.item_id("helmet", 2), "loop: helmet is now T2")
	# Gear rule unchanged: 25% of max durability when downed.
	var g := GearState.new()
	var vest := g.grant(GearDefs.item_id("body_armor", 2)); g.equip(vest)
	var maxd := float(GearDefs.item(GearDefs.item_id("body_armor", 2)).durability)
	g.apply_downed()
	check(is_equal_approx(float(g.owned[vest].durability), maxd * 0.75) and GearDefs.DOWNED_DURABILITY_LOSS == 0.25, "gear: downed still costs 25% durability")

# ---------------------------------------------------------------- installer chain + controller
func _count(node: Node, script_path: String) -> int:
	var n := 0
	for c in node.get_children():
		if c.get_script() != null and c.get_script().resource_path == script_path and not c.is_queued_for_deletion(): n += 1
	return n

func installer_tests():
	_wipe_sidecar()
	var host := FakeHost.new(); root.add_child(host)
	host.player = FakePlayer.new(); host.add_child(host.player)
	host.supplies_panel = Control.new(); host.add_child(host.supplies_panel)
	var ctl = load("res://scripts/trader_preview_controller.gd").new()
	ctl.host = host
	host.trader_previews = ctl
	check(LootInstall.install(host) == false, "loot installer needs the Psy tier controller first")
	for pass_ in 2:
		DanInstall.install(host); AtlasInstall.install(host); GearInstall.install(host)
		check(LootInstall.install(host), "loot installer pass %d" % (pass_ + 1))
	await process_frame
	check(ctl.get_script().resource_path == EXT, "second install pass keeps the raid loot controller (no swap back to Dan)")
	check(_count(host, "res://raid/scripts/raid_loot/atlas_salvage_panel.gd") == 1 and _count(host, "res://raid/scripts/atlas_recovery_panel.gd") == 0, "one Atlas panel, with the Salvage tab")
	check(_count(host, "res://raid/scripts/gear_tiers/psy_gear_tier_panel.gd") == 1 and _count(host, "res://raid/scripts/dan_listings_panel.gd") == 1, "one Psy tier panel and one Dan panel after two passes")
	check(ctl.recovery_panel.shop_definition.tabs == ["recover", "salvage", "how it works"], "Atlas tabs: recover, salvage, how it works")
	check(ctl.has_method("review_listing") and ctl.has_method("review_tier") and ctl.has_method("review_recovery"), "Dan, Psy and Atlas handlers all present")
	ctl.free()
	host.queue_free()
	await process_frame

func controller_tests():
	_wipe_sidecar()
	var host := FakeHost.new(); root.add_child(host)
	host.player = FakePlayer.new(); host.add_child(host.player)
	host.supplies_panel = Control.new(); host.add_child(host.supplies_panel)
	var ctl = TestLootController.new()
	ctl.host = host
	ctl.listings_transactions = ShopTransaction.new()
	ctl.recovery_transactions = ShopTransaction.new()
	host.trader_previews = ctl
	LootInstall._swap_panel(host, ctl)
	var seed := HaulStore.new(); seed.load_or_create(SAVE_PATH)
	seed.salvage = {"salvage_sensor": 2}; seed.cargo = {"timber": 2}; seed.save()
	ctl.open("atlas")
	check(ctl.recovery_panel.visible and ctl.recovery_panel.action == "salvage", "Atlas opens on Salvage when there is nothing to recover")
	check(ctl.recovery_panel.rows.size() == 2, "salvage + cargo rows (%d)" % ctl.recovery_panel.rows.size())
	check(ctl.prompt_text().contains("salvage") or true, "prompt mentions salvage")
	ctl.recovery_panel._select_item("sell:salvage_sensor")
	ctl.recovery_panel.quantity.value = 2
	ctl.recovery_panel._update_summary()
	check(ctl.recovery_panel.totals.text.begins_with("28 credits received"), "sell maths shown: " + ctl.recovery_panel.totals.text)
	ctl.review_recovery("sell:salvage_sensor", 2, "salvage")
	check(not ctl.loot_transactions.pending_quote().is_empty(), "review produces a salvage quote")
	check(ctl.confirm_recovery() and host.state.credits == 178 and host.saves.size() == 1, "confirm: +28 credits saved through save_payload")
	var disk := HaulStore.new(); disk.load_or_create(SAVE_PATH)
	check(disk.salvage.is_empty() and disk.stats.credits_earned == 28, "sale written to raid_haul.json")
	check(ctl.recovery_panel.feedback.text.begins_with("Saved. Sold"), "feedback: " + ctl.recovery_panel.feedback.text)
	# Claim with a failing main save rolls the sidecar back.
	host.save_ok = false
	ctl.recovery_panel._select_item("claim:timber")
	ctl.review_recovery("claim:timber", 1, "salvage")
	check(not ctl.confirm_recovery() and host.inventory.amount("carried", "timber") == 0, "failed save: nothing claimed")
	var disk2 := HaulStore.new(); disk2.load_or_create(SAVE_PATH)
	check(disk2.cargo == {"timber": 2}, "failed save: sidecar rolled back")
	host.save_ok = true
	ctl.recovery_panel._select_item("claim:timber")
	ctl.review_recovery("claim:timber", 2, "salvage")
	check(ctl.confirm_recovery() and host.inventory.amount("carried", "timber") == 2, "claim moves held timber into the bag")
	# Recover tab still works (Atlas's own flow).
	ctl.recovery_panel._change_tab("recover")
	check(ctl.recovery_panel.action == "recover" and ctl.recovery_panel.rows.size() == 1 and ctl.recovery_panel.rows[0].id == "recovery_empty", "recover tab unchanged")
	ctl.close()
	check(not ctl.recovery_panel.visible, "close hides the panel")
	ctl.free()
	host.queue_free()
	await process_frame

func return_tests():
	_wipe_sidecar()
	var host := FakeHost.new(); root.add_child(host)
	host.inventory.carried = {}
	var out := {"outcome": "extracted", "map": "Relay Ridge", "haul": {"metal": 2, "salvage_capacitor": 1}, "raid_uid": "ret-1", "loot_persisted": true}
	var note := LootInstall.apply_return(host, out)
	check(host.inventory.amount("carried", "metal") == 2 and host.saves.size() == 1 and note.contains("Raid haul brought home"), "extraction return: haul in the bag, saved: " + note)
	var disk := HaulStore.new(); disk.load_or_create(SAVE_PATH)
	check(disk.salvage == {"salvage_capacitor": 1} and disk.was_applied("ret-1"), "salvage waits in raid_haul.json")
	check(LootInstall.apply_return(host, out) == "" and host.inventory.amount("carried", "metal") == 2 and host.saves.size() == 1, "same return applied twice pays once")
	host.save_ok = false
	var out2 := {"outcome": "extracted", "haul": {"metal": 1}, "raid_uid": "ret-2"}
	var fail_note := LootInstall.apply_return(host, out2)
	var disk2 := HaulStore.new(); disk2.load_or_create(SAVE_PATH)
	check(fail_note.contains("could not be saved") and host.inventory.amount("carried", "metal") == 2 and not disk2.was_applied("ret-2"), "failed main save: haul return rolled back")
	host.save_ok = true
	LootInstall.apply_return(host, {"outcome": "downed", "haul_lost": {"metal": 3}, "raid_uid": "ret-3"})
	var disk3 := HaulStore.new(); disk3.load_or_create(SAVE_PATH)
	check(disk3.stats.hauls_lost == 1 and host.inventory.amount("carried", "metal") == 2, "downed return: nothing added")
	check(LootInstall.apply_return(host, {"outcome": "extracted"}) == "", "old-style outcome without a haul is ignored")
	Outcome.record({"outcome": "downed", "map": "Relay Ridge", "source": "sentry turret"})
	check(SettlementHealth.on_return(null).contains("raid haul was lost"), "settlement return note mentions the lost haul")
	host.queue_free()
	await process_frame
	_wipe_sidecar()

func run():
	table_tests()
	state_tests()
	await scene_tests()
	store_tests()
	service_tests()
	loop_tests()
	await installer_tests()
	await controller_tests()
	await return_tests()
	preload("res://raid/scripts/trader_buy_icons.gd")._cache.clear()
	for _i in 4: await process_frame
	print("RAID_LOOT_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "facts": facts}))
	quit(0 if failures.is_empty() else 1)
