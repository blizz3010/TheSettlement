extends SceneTree
## Item 13: Atlas recovery — downed intake, pay to recover, insufficient funds,
## wait timer, expiry after N raids, and sidecar persistence.
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Request = preload("res://scripts/request_state.gd")
const ShopTransaction = preload("res://scripts/shop_transaction.gd")
const PreviewCatalog = preload("res://scripts/trader_preview_catalog.gd")
const Store = preload("res://raid/scripts/atlas_recovery_store.gd")
const Service = preload("res://raid/scripts/atlas_recovery_service.gd")
const AtlasPanel = preload("res://raid/scripts/atlas_recovery_panel.gd")
const Install = preload("res://raid/scripts/atlas_recovery_install.gd")
const Icons = preload("res://raid/scripts/trader_buy_icons.gd")
const Outcome = preload("res://raid/scripts/raid_outcome.gd")

var checks := 0
var failures: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func fresh() -> Dictionary:
	return {"plot": Plot.new(), "inventory": Inventory.new(), "request": Request.new()}

func ctx(store: Store, now: int = 1000, wait: int = 0, expire: int = 3) -> Dictionary:
	return {"recovery": store.snapshot(), "now_unix": now, "wait_sec": wait, "expire_after_raids": expire, "map": "Relay Ridge", "source": "sentry turret"}

func sidecar() -> String:
	return "user://atlas_recovery_test/atlas_recovery.json"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var atlas: Array = PreviewCatalog.rows("atlas", "overview")
	check(not atlas.is_empty() and str(atlas[0].get("reason", "")).to_lower().contains("unavailable"), "Pinned Atlas catalog is still the demo fallback")
	check(Outcome.peek().is_empty(), "Outcome.peek is empty by default")
	Outcome.record({"outcome": "downed", "map": "Relay Ridge"})
	check(Outcome.peek().get("outcome") == "downed", "Outcome.peek does not consume")
	check(Outcome.take().get("map") == "Relay Ridge" and Outcome.peek().is_empty(), "Outcome.take still consumes")

	var s: Dictionary = fresh()
	s.inventory.carried["timber"] = 3
	s.inventory.carried["stone"] = 2
	s.inventory.stash["metal"] = 2
	var start_credits: int = s.plot.credits
	var store := Store.new()
	store.wait_sec = 0
	store.expire_after_raids = 3
	var svc := Service.new()
	var taken: Dictionary = svc.intake(s.plot, s.inventory, s.request, store, ctx(store, 1000, 0, 3))
	check(not taken.is_empty(), "Downed intake succeeds: " + svc.last_error)
	if not taken.is_empty():
		check(taken.inventory.amount("carried", "timber") == 0 and taken.inventory.amount("carried", "stone") == 0, "Carried stacks leave the bag")
		check(taken.inventory.amount("stash", "metal") == 2, "Stash is untouched")
		check(taken.plot.credits == start_credits, "Intake does not charge credits")
		store.restore(taken.recovery)
		s.plot = taken.plot
		s.inventory = taken.inventory
		check(store.open_rows().size() == 2, "Two recovery entries are held")
		check(store.raid_count == 1, "Intake counts as one raid")
		check(str(taken.receipt.message).to_lower().contains("atlas is holding"), "Intake message names Atlas")

	# Immediate recover (wait_sec 0)
	var timber_id := ""
	var stone_id := ""
	for row in store.open_rows():
		if row.item_id == "timber":
			timber_id = str(row.id)
		elif row.item_id == "stone":
			stone_id = str(row.id)
	check(not timber_id.is_empty() and Store.unit_fee("timber") == 6, "Timber recovery fee is 60% of Rook's 10")
	var recovered: Dictionary = svc.quote_candidate("atlas", "recover", timber_id, 1, s.plot, s.inventory, s.request, ctx(store, 1000, 0, 3))
	check(not recovered.is_empty(), "Recovering timber succeeds: " + svc.last_error)
	if not recovered.is_empty():
		check(recovered.plot.credits == start_credits - 18, "Timber × 3 costs 6 x 3 = 18 credits")
		check(recovered.inventory.amount("carried", "timber") == 3, "Recovered timber returns to carried")
		var after := Store.new()
		after.restore(recovered.recovery)
		check(after.find(timber_id).status == "recovered", "Recovered entry is marked recovered")
		s.plot = recovered.plot
		s.inventory = recovered.inventory
		store.restore(recovered.recovery)

	# Insufficient funds
	var broke := fresh()
	broke.plot.credits = 5
	var denied: Dictionary = svc.quote_candidate("atlas", "recover", stone_id, 1, broke.plot, broke.inventory, broke.request, ctx(store, 1000, 0, 3))
	check(denied.is_empty() and svc.last_error.to_lower().contains("credit"), "Insufficient funds blocks recovery: " + svc.last_error)
	check(broke.plot.credits == 5 and broke.inventory.amount("carried", "stone") == 0, "Failed recover leaves state unchanged")

	# Wait timer: holding is not recoverable
	var wait_state := fresh()
	wait_state.inventory.carried["metal"] = 1
	var wait_store := Store.new()
	wait_store.wait_sec = 10
	wait_store.expire_after_raids = 3
	var held: Dictionary = svc.intake(wait_state.plot, wait_state.inventory, wait_state.request, wait_store, ctx(wait_store, 2000, 10, 3))
	check(not held.is_empty(), "Intake with a wait succeeds")
	wait_store.restore(held.recovery)
	wait_state.plot = held.plot
	wait_state.inventory = held.inventory
	var hold_id := str(wait_store.open_rows()[0].id)
	check(wait_store.find(hold_id).status == "holding", "Entry starts in holding")
	var early: Dictionary = svc.quote_candidate("atlas", "recover", hold_id, 1, wait_state.plot, wait_state.inventory, wait_state.request, ctx(wait_store, 2005, 10, 3))
	check(early.is_empty() and svc.last_error.to_lower().contains("preparing"), "Holding entry cannot be recovered yet: " + svc.last_error)
	var later: Dictionary = svc.quote_candidate("atlas", "recover", hold_id, 1, wait_state.plot, wait_state.inventory, wait_state.request, ctx(wait_store, 2010, 10, 3))
	check(not later.is_empty(), "Entry is recoverable once the wait has passed: " + svc.last_error)

	# Expiry after N extracted raids
	var exp_state := fresh()
	exp_state.inventory.carried["bait_portion"] = 2
	exp_state.inventory.format_version = 9
	var exp_store := Store.new()
	exp_store.wait_sec = 0
	exp_store.expire_after_raids = 2
	var exp_in: Dictionary = svc.intake(exp_state.plot, exp_state.inventory, exp_state.request, exp_store, ctx(exp_store, 3000, 0, 2))
	exp_store.restore(exp_in.recovery)
	exp_state.plot = exp_in.plot
	exp_state.inventory = exp_in.inventory
	var exp_id := ""
	for row in exp_store.open_rows():
		exp_id = str(row.id)
	var tick1: Dictionary = svc.tick_raids(exp_state.plot, exp_state.inventory, exp_state.request, exp_store, ctx(exp_store, 3100, 0, 2))
	exp_store.restore(tick1.recovery)
	check(exp_store.find(exp_id).status == "ready", "Still ready after one later raid")
	var tick2: Dictionary = svc.tick_raids(exp_state.plot, exp_state.inventory, exp_state.request, exp_store, ctx(exp_store, 3200, 0, 2))
	exp_store.restore(tick2.recovery)
	check(exp_store.find(exp_id).status == "expired", "Expires after two later raids")
	check(str(tick2.receipt.message).to_lower().contains("expired"), "Expiry is mentioned")
	var too_late: Dictionary = svc.quote_candidate("atlas", "recover", exp_id, 1, exp_state.plot, exp_state.inventory, exp_state.request, ctx(exp_store, 3300, 0, 2))
	check(too_late.is_empty(), "Expired entries cannot be recovered")

	# Empty bag: no entries, stash intact
	var empty := fresh()
	empty.inventory.stash["timber"] = 4
	var empty_store := Store.new()
	var empty_in: Dictionary = svc.intake(empty.plot, empty.inventory, empty.request, empty_store, ctx(empty_store, 4000, 0, 3))
	check(not empty_in.is_empty() and empty_in.inventory.amount("stash", "timber") == 4, "Empty carried intake leaves the stash")
	var empty_store2 := Store.new()
	empty_store2.restore(empty_in.recovery)
	check(empty_store2.open_rows().is_empty(), "No recovery rows when nothing was carried")

	# Persistence
	var path := sidecar()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	store.attach(path)
	check(store.save() and FileAccess.file_exists(path), "Sidecar save writes atlas_recovery.json")
	var reloaded := Store.new()
	check(reloaded.load_or_create(path), "Sidecar reloads")
	check(reloaded.find(timber_id).status == "recovered", "Recovered entry survives a reload")
	check(reloaded.find(stone_id).status == "ready", "Unclaimed ready entry survives a reload")

	# ShopTransaction wrapper
	var tx := ShopTransaction.new(svc.quote_candidate)
	var quote: Dictionary = tx.select("atlas", "recover", stone_id, 1, s.plot, s.inventory, s.request, ctx(store, 1000, 0, 3))
	check(not quote.is_empty(), "ShopTransaction can review a recovery: " + svc.last_error + " / " + tx.last_error)
	if quote.is_empty():
		print("ATLAS_RECOVERY_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "scope": "aborted before confirm"}))
		quit(1)
		return
	var writer_ok := [false]
	var committed: Dictionary = tx.confirm(quote.token, s.plot, s.inventory, s.request, func(): return true, func(candidate):
		s.plot = candidate.plot
		s.inventory = candidate.inventory
		store.restore(candidate.recovery)
		writer_ok[0] = true
		return true
	, ctx(store, 1000, 0, 3))
	check(not committed.is_empty() and writer_ok[0], "ShopTransaction confirm persists a recovery")
	check(s.inventory.amount("carried", "stone") == 2, "Confirmed recovery returns stone")

	# Panel rows / help deferrals
	var ui := AtlasPanel.new()
	var rows: Array = ui.recover_rows(store, s.inventory)
	# timber and stone already recovered in this store copy after confirm
	check(ui.help_rows()[0].description.to_lower().contains("salvage tab"), "Help points extracted raid loot to the Salvage tab (item 13)")
	check(ui.help_rows()[0].description.to_lower().contains("healing") and ui._review_label("recover") == "Review recovery", "Help defers healing; review label is recovery")
	ui.free()

	# Seeded/held items reuse mid-to-high poly icons
	for item_id in ["timber", "stone", "metal", "bait_portion"]:
		var icon_path := ProjectSettings.globalize_path(Icons.path_for(item_id))
		check(FileAccess.file_exists(icon_path), "Existing mid-style icon is used for %s" % item_id)

	check(Install.install(null) == false, "Installer refuses a missing host")

	print("ATLAS_RECOVERY_TESTS ", JSON.stringify({
		"checks": checks,
		"failures": failures,
		"scope": "Atlas intake, recover, insufficient funds, wait, expiry, persistence; field loot still deferred",
		"timber_fee": Store.unit_fee("timber"),
	}))
	quit(0 if failures.is_empty() else 1)
