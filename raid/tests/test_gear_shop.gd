extends SceneTree
## TASKS item 22, PR C: Psy's tier gear shop (buy, sell, repair, upgrade, equip),
## unlock rules, T0 helmet kept working, controller + installer, extraction counter.
## Headless; disposable XDG profile. Prints one marker: GEAR_SHOP_TESTS {json}.
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const State = preload("res://raid/scripts/gear_tiers/gear_locker_state.gd")
const Store = preload("res://raid/scripts/gear_tiers/gear_locker_store.gd")
const Service = preload("res://raid/scripts/gear_tiers/gear_shop_service.gd")
const Install = preload("res://raid/scripts/gear_tiers/gear_shop_install.gd")
const TierPanel = preload("res://raid/scripts/gear_tiers/psy_gear_tier_panel.gd")
const ShopTransaction = preload("res://scripts/shop_transaction.gd")
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Request = preload("res://scripts/request_state.gd")
const Craft = preload("res://scripts/craft_state.gd")
const Onboarding = preload("res://scripts/onboarding_state.gd")
const Fishing = preload("res://scripts/fishing_state.gd")
const SaveCodec = preload("res://scripts/save_codec.gd")
const ATLAS_EXT := "res://raid/scripts/atlas_recovery_controller_ext.gd"
const EXT := "res://raid/scripts/gear_tiers/psy_gear_controller_ext.gd"
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
	var character_save_path := ""
	func key_label(_a): return "E"
	func modal_open(_a = true, _b = true, _c = true) -> bool: return false
	func save_payload(payload: Dictionary, _notice := true, _writer = null) -> bool:
		if not save_ok: return false
		saves.append(payload)
		return true
	func get_node_or_null_stand(): return null

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize():
	call_deferred("run")

func fresh() -> Dictionary:
	return {"plot": Plot.new(), "inventory": Inventory.new(), "request": Request.new(), "locker": State.new()}

func row(rows: Array, id: String) -> Dictionary:
	for r in rows:
		if r.id == id: return r
	return {}

## Review + confirm through the real ShopTransaction; applies the candidate on success.
func trade(s: Dictionary, action: String, item: String) -> Dictionary:
	var svc := Service.new()
	var tx := ShopTransaction.new(svc.quote_candidate)
	var ctx := {"service": "psy", "locker": s.locker.data()}
	var quote := tx.select("psy", action, item, 1, s.plot, s.inventory, s.request, ctx)
	if quote.is_empty(): return {"ok": false, "error": svc.last_error if not svc.last_error.is_empty() else tx.last_error}
	var done := tx.confirm(quote.token, s.plot, s.inventory, s.request, func(): return true, func(_c): return true, ctx)
	if done.is_empty(): return {"ok": false, "error": tx.last_error}
	s.plot = done.plot; s.inventory = done.inventory; s.request = done.request
	s.locker = State.new(); s.locker.restore(done.locker)
	return {"ok": true, "receipt": done.receipt}

# ---------------------------------------------------------------- service
func service_tests():
	var svc := Service.new()
	var s := fresh()
	var rows := svc.rows("buy", s.plot, s.inventory, s.locker)
	check(row(rows, "helmet_basic").get("enabled", false) and row(rows, "helmet_basic").price == 24, "T0 basic helmet still listed at 24")
	var t1_ok := true; var t2_locked := true; var t4_locked := true
	for slot in Defs.SLOTS:
		t1_ok = t1_ok and row(rows, Defs.item_id(slot, 1)).get("enabled", false)
		t2_locked = t2_locked and not row(rows, Defs.item_id(slot, 2)).get("enabled", true)
		t4_locked = t4_locked and not row(rows, Defs.item_id(slot, 4)).get("enabled", true)
	check(t1_ok, "T1 stocked for all 11 slots from the start")
	check(t2_locked and row(rows, Defs.item_id("helmet", 2)).reason.find("1 successful extraction") >= 0, "T2 locked until the first extraction")
	check(t4_locked and not row(rows, Service.STOCK_III).get("enabled", true), "T4 and Stock III locked at 0 extractions")
	check(rows.size() == 1 + 1 + 44, "buy rows: T0 helmet + Stock III + 44 tier items (%d)" % rows.size())
	# Buy T1.
	var r := trade(s, "buy", Defs.item_id("body_armor", 1))
	check(r.ok and s.plot.credits == 90 and s.locker.owned.size() == 1, "buy T1 Padded Vest: 150 -> 90, in locker")
	check(s.inventory.used("carried") == 0, "tier gear does not use carried space")
	var t2 := trade(s, "buy", Defs.item_id("body_armor", 2))
	check(not t2.ok and str(t2.error).find("extraction") >= 0, "T2 buy rejected at 0 extractions: " + str(t2.get("error")))
	var poor := fresh(); poor.plot.credits = 10
	var p1 := trade(poor, "buy", Defs.item_id("helmet", 1))
	check(not p1.ok and str(p1.error).to_lower().find("credit") >= 0 and poor.locker.owned.is_empty(), "insufficient funds: nothing granted")
	# T2 after an extraction.
	s.locker.extractions = 1; s.plot.credits = 2000
	check(trade(s, "buy", Defs.item_id("helmet", 2)).ok and s.plot.credits == 1880, "T2 buyable after 1 extraction (120)")
	check(not trade(s, "buy", Defs.item_id("helmet", 3)).ok, "T3 still locked")
	check(not trade(s, "buy", Service.STOCK_III).ok, "Stock III needs 5 extractions")
	s.locker.extractions = 5
	check(not trade(s, "buy", Defs.item_id("helmet", 3)).ok, "T3 needs the licence even at 5 extractions")
	check(trade(s, "buy", Service.STOCK_III).ok and s.locker.shop.stock_iii and s.plot.credits == 1580, "Stock III licence: 300 credits")
	check(trade(s, "buy", Defs.item_id("helmet", 3)).ok and s.plot.credits == 1260, "T3 buyable after licence (320)")
	check(not row(svc.rows("buy", s.plot, s.inventory, s.locker), Service.STOCK_III).size() > 0, "licence row gone once paid")
	# T4 rotation.
	s.locker.extractions = 10; s.plot.credits = 20000
	var offer := Service.t4_offer(s.locker)
	check(offer == Defs.item_id("face_cover", 4), "10 extractions: window 3 lists T4 face cover (%s)" % offer)
	check(not trade(s, "buy", Defs.item_id("helmet", 4)).ok, "non-listed T4 not for sale")
	check(trade(s, "buy", offer).ok and s.locker.shop.t4_window_bought == 3, "listed T4 bought")
	check(not trade(s, "buy", offer).ok, "one T4 per rotation window")
	s.locker.extractions = 12
	check(Service.t4_offer(s.locker) == Defs.item_id("body_armor", 4) and trade(s, "buy", Defs.item_id("body_armor", 4)).ok, "12 extractions: next window lists T4 body armor")
	# Equip / sell / repair.
	var vest := ""
	for id in s.locker.owned:
		if s.locker.owned[id].def == Defs.item_id("body_armor", 1): vest = id
	check(trade(s, "equip", vest).ok and s.locker.slots.body_armor == vest, "equip via Psy")
	var sold := trade(s, "sell", vest)
	check(not sold.ok and str(sold.error).find("Unequip") >= 0, "equipped gear can't be sold")
	check(trade(s, "equip", vest).ok and s.locker.slots.body_armor == "", "equip again = unequip")
	s.locker.owned[vest].durability = 0.0
	check(not trade(s, "sell", vest).ok, "broken gear can't be sold")
	var before := int(s.plot.credits)
	var rep := trade(s, "repair", vest)
	check(rep.ok and int(rep.receipt.total) == 18 and s.plot.credits == before - 18 and s.locker.owned[vest].durability == 60.0, "repair 0% -> 100%: 30% of 60 = 18")
	check(not trade(s, "repair", vest).ok, "repair rejected at full durability")
	before = int(s.plot.credits)
	check(trade(s, "sell", vest).ok and s.plot.credits == before + 30 and not s.locker.owned.has(vest), "sell T1 vest back for 30 (50%)")
	# Upgrade T1 -> T2 with materials.
	var u := fresh(); u.plot.credits = 5000; u.locker.extractions = 1
	trade(u, "buy", Defs.item_id("body_armor", 1))
	var piece: String = u.locker.owned.keys()[0]
	trade(u, "equip", piece)
	var no_mats := trade(u, "upgrade", piece)
	check(not no_mats.ok and str(no_mats.error).find("metal") >= 0, "upgrade needs 2 carried metal scrap: " + str(no_mats.get("error")))
	u.inventory.carried["metal"] = 3
	u.locker.owned[piece].durability = 20.0
	before = int(u.plot.credits)
	var up := trade(u, "upgrade", piece)
	check(up.ok and int(up.receipt.total) == 132 and u.plot.credits == before - 132, "T1 -> T2 armor: (180-60) + 10% = 132")
	check(u.locker.owned[piece].def == Defs.item_id("body_armor", 2) and u.locker.owned[piece].durability == 90.0 and u.locker.slots.body_armor == piece, "upgraded in place, full durability, still equipped")
	check(u.inventory.amount("carried", "metal") == 1, "2 metal consumed")
	trade(u, "buy", Defs.item_id("gloves", 1))
	var glove := ""
	for id in u.locker.owned:
		if u.locker.owned[id].def == Defs.item_id("gloves", 1): glove = id
	u.inventory.format_version = 10 # linen and thread exist only in crafting-era (v10) inventories
	u.inventory.carried["cloth_linen"] = 2; u.inventory.carried["thread_spool"] = 1
	var gu := trade(u, "upgrade", glove)
	check(gu.ok and u.inventory.amount("carried", "cloth_linen") == 0 and u.inventory.amount("carried", "thread_spool") == 0, "clothing upgrade uses 2 linen + 1 thread: " + str(gu.get("error", "")))
	# T3 -> T4 needs the raid-only composite insert (stub until item 13).
	var c := fresh(); c.plot.credits = 20000; c.locker.extractions = 5; c.locker.shop.stock_iii = true
	trade(c, "buy", Defs.item_id("helmet", 3))
	var helm: String = c.locker.owned.keys()[0]
	var no_insert := trade(c, "upgrade", helm)
	check(not no_insert.ok and str(no_insert.error).find("composite insert") >= 0, "T3 -> T4 blocked without a composite insert")
	c.locker.shop.composite_insert = 1
	check(trade(c, "upgrade", helm).ok and c.locker.owned[helm].def == Defs.item_id("helmet", 4) and c.locker.shop.composite_insert == 0, "with an insert (stubbed), T3 -> T4 works and consumes it")
	check(not trade(c, "upgrade", helm).ok, "T4 can't upgrade further")
	# T0 helmet unchanged through the new shop.
	var h := fresh()
	var hb := trade(h, "buy", "helmet_basic")
	check(hb.ok and h.plot.credits == 126 and h.inventory.equipment_owned.has("psy_helmet_1") and h.locker.owned.is_empty(), "T0 helmet buy via pinned flow: 24 credits, carried equipment")
	var hrows := svc.rows("sell", h.plot, h.inventory, h.locker)
	check(row(hrows, "psy_helmet_1").get("price", 0) == 12, "T0 helmet listed in sell at 12")
	check(trade(h, "sell", "psy_helmet_1").ok and h.plot.credits == 138 and h.inventory.equipment_owned.is_empty(), "T0 helmet sells back for 12")
	# Equip tab rows + loadout text.
	var erows := svc.rows("equip", u.plot, u.inventory, u.locker)
	check(erows.size() == u.locker.owned.size() and str(erows[0].name).begins_with("● "), "equip rows mark worn gear")
	var text := svc.loadout_text(u.locker)
	check(text.split("\n").size() == 1 + 11 + 2 and text.find("Body armor: T2 Scrapplate Vest") >= 0, "loadout lists all 11 slots")
	# v1 locker still loads.
	var v1 := {"version": 1, "next_serial": 1, "extractions": 2, "items": [], "slots": State.new().slots.duplicate()}
	var mig = State.new()
	check(mig.restore(v1) and mig.extractions == 2 and mig.shop == State.DEFAULT_SHOP and mig.data().version == 2, "v1 locker (PR A/B) migrates to v2")

# ------------------------------------------------------------ controller
class TestController:
	extends "res://raid/scripts/gear_tiers/psy_gear_controller_ext.gd"
	func accessible(_id: String) -> bool: return true
	func active() -> bool: return true

func controller_tests():
	for f in [Store.DEFAULT_PATH, Store.DEFAULT_PATH + ".tmp"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var host := FakeHost.new()
	root.add_child(host)
	host.player = FakePlayer.new(); host.add_child(host.player)
	host.supplies_panel = Control.new(); host.add_child(host.supplies_panel)
	var ctl = TestController.new()
	ctl.host = host
	ctl.listings_transactions = ShopTransaction.new()
	ctl.recovery_transactions = ShopTransaction.new()
	host.trader_previews = ctl
	Install._attach_panel(host, ctl)
	check(is_instance_valid(ctl.tier_panel) and ctl.tier_panel.shop_definition.tabs == ["buy", "sell", "repair", "upgrade", "equip"], "tier panel attached with 5 tabs")
	ctl.open("psy")
	check(ctl.tier_panel.visible and ctl.is_open() and not host.player.enabled and ctl.current_id == "psy", "Psy opens the tier shop")
	check(ctl.tier_panel.rows.size() == 46, "buy tab rendered (%d rows)" % ctl.tier_panel.rows.size())
	var id := Defs.item_id("backpack", 1)
	ctl.tier_panel._select_item(id)
	ctl.review_tier(id, 1, "buy")
	check(not ctl.tier_transactions.pending_quote().is_empty(), "review produces a quote")
	check(ctl.confirm_tier() and host.state.credits == 120 and host.saves.size() == 1, "confirm: credits saved through save_payload")
	var disk = Store.new(); disk.load_locker()
	check(disk.state.owned.size() == 1 and disk.state.owned.values()[0].def == id, "bought gear written to user://gear_locker.json")
	check(ctl.tier_panel.feedback.text.begins_with("Saved."), "feedback: " + ctl.tier_panel.feedback.text)
	# Failed main save rolls the locker back.
	host.save_ok = false
	ctl.tier_panel._select_item(id)
	ctl.review_tier(id, 1, "buy")
	check(not ctl.confirm_tier() and host.state.credits == 120 and ctl.gear_store.state.owned.size() == 1, "failed save: nothing bought")
	var disk2 = Store.new(); disk2.load_locker()
	check(disk2.state.owned.size() == 1, "failed save: sidecar rolled back")
	host.save_ok = true
	# Equip tab.
	ctl.tier_panel._change_tab("equip")
	check(ctl.tier_panel.action == "equip" and ctl.tier_panel.rows.size() == 1, "equip tab lists owned gear")
	var inst: String = ctl.tier_panel.rows[0].id
	ctl.tier_panel._select_item(inst)
	ctl.review_tier(inst, 1, "equip")
	check(ctl.confirm_tier() and ctl.gear_store.state.slots.backpack == inst, "equip from the tab")
	check(ctl.tier_panel.shop_definition.help.find("Backpack: T1 Satchel") >= 0, "loadout summary shows the equipped satchel")
	ctl.close()
	check(not ctl.tier_panel.visible and not ctl.is_open(), "close hides the tier shop")
	facts["controller_saves"] = host.saves.size()
	ctl.free()
	host.queue_free()
	await process_frame

# -------------------------------------------------------------- installer
func installer_tests():
	check(Install.install(null) == false, "installer refuses a missing host")
	var host := FakeHost.new(); root.add_child(host)
	host.supplies_panel = Control.new(); host.add_child(host.supplies_panel)
	var plain = load("res://scripts/trader_preview_controller.gd").new()
	host.trader_previews = plain
	check(Install.install(host) == false, "installer needs Atlas's controller first")
	var atlas = load(ATLAS_EXT).new()
	atlas.host = host
	atlas.current_id = "atlas"; atlas.marketplace_enabled = true
	host.trader_previews = atlas
	check(Install.install(host), "installs over Atlas's controller")
	check(atlas.get_script().resource_path == EXT and atlas.current_id == "atlas" and atlas.marketplace_enabled, "script extended, fields carried over")
	check(is_instance_valid(atlas.tier_panel) and atlas.has_method("review_recovery") and atlas.has_method("review_listing"), "Atlas and Dan handlers still present")
	var panel_before = atlas.tier_panel
	check(Install.install(host) and atlas.tier_panel == panel_before, "second install is a no-op")
	plain.free()
	atlas.free()
	host.queue_free()
	await process_frame
	# Extraction counter.
	var path := "user://gear_shop_test/gear_locker.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://gear_shop_test"))
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(Install.apply_return(null, {"outcome": "extracted"}, path), "extracted return counted")
	Install.apply_return(null, {"outcome": "extracted"}, path)
	check(not Install.apply_return(null, {"outcome": "downed"}, path), "downed return not counted")
	var s = Store.new(); s.load_locker(path)
	check(s.state.extractions == 2, "extractions saved in the gear sidecar (%d)" % s.state.extractions)

func panel_tests():
	var p = TierPanel.new(); root.add_child(p)
	var ok := true
	for t in [1, 2, 3, 4]:
		var tex: Texture2D = p._item_texture({"tier": t})
		ok = ok and tex != null and tex.get_width() == 34
	check(ok, "tier chips render for T1-T4")
	check(p._verb("upgrade") == "Upgrade" and p._review_label("repair") == "Review repair", "action labels")
	p.queue_free()

func run():
	service_tests()
	await controller_tests()
	await installer_tests()
	panel_tests()
	await process_frame
	print("GEAR_SHOP_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "facts": facts}))
	quit(0 if failures.is_empty() else 1)
