extends SceneTree
## Item 16: working trader buy menus (Rook, Psy, Tailor, Fishing).
## Covers specialist stock categories, purchases, insufficient funds, and inventory updates.
## Atlas stays preview-only. The pinned Dan catalog remains the demo fallback;
## live listings are covered by test_dan_player_listings.
const ShopCatalog = preload("res://scripts/shop_catalog.gd")
const Supplies = preload("res://scripts/supplies_purchase.gd")
const ShopTransaction = preload("res://scripts/shop_transaction.gd")
const PsyCatalog = preload("res://scripts/psy_gear_catalog.gd")
const PsyPurchase = preload("res://scripts/psy_gear_purchase.gd")
const TailorCatalog = preload("res://scripts/tailor_catalog.gd")
const TailorPurchase = preload("res://scripts/tailor_purchase.gd")
const PreviewCatalog = preload("res://scripts/trader_preview_catalog.gd")
const FishingCatalog = preload("res://raid/scripts/fishing_supply_catalog_ext.gd")
const FishingPurchase = preload("res://raid/scripts/fishing_supply_purchase_ext.gd")
const FishingTransaction = preload("res://raid/scripts/fishing_supply_transaction_ext.gd")
const Icons = preload("res://raid/scripts/trader_buy_icons.gd")
const Renderer = preload("res://raid/scripts/trader_icon_renderer.gd")
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Request = preload("res://scripts/request_state.gd")

var checks := 0
var failures: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func fresh() -> Dictionary:
	return {"plot": Plot.new(), "inventory": Inventory.new(), "request": Request.new()}

func _initialize() -> void:
	call_deferred("run")

func categories_of(rows: Array) -> Array:
	var found: Array = []
	for row in rows:
		var c := str(row.get("category", ""))
		if not found.has(c):
			found.append(c)
	return found

func ids_of(rows: Array) -> Array:
	var found: Array = []
	for row in rows:
		found.append(str(row.get("id", "")))
	return found

func buyable_ids(rows: Array) -> Array:
	var found: Array = []
	for row in rows:
		if row.get("enabled", false) and row.get("price") != null:
			found.append(str(row.id))
	return found

func run() -> void:
	var s: Dictionary = fresh()
	# --- stock categories -------------------------------------------------
	var rook_rows: Array = ShopCatalog.rows("buy", s.inventory)
	var rook_ids: Array = ids_of(rook_rows)
	check(rook_ids.has("timber") and rook_ids.has("stone") and rook_ids.has("metal"), "Rook stocks timber, stone and metal scrap")
	check(buyable_ids(rook_rows) == ["timber", "stone", "metal"], "Rook buyable stock is only the three materials")
	for id in rook_ids:
		check(not id.begins_with("basic_") and id != "helmet_basic" and id != "fishing_pole", "Rook does not stock other traders' items (%s)" % id)
	var rook_cats: Array = categories_of(rook_rows)
	for cat in rook_cats:
		check(cat in ["Materials", "Knowledge", "Tools", "Plans"], "Rook category is a supplies role: " + cat)

	var psy_rows: Array = PsyCatalog.rows(s.inventory, "buy")
	var psy_ids: Array = ids_of(psy_rows)
	check(psy_ids.has("helmet_basic") and psy_ids.has("armor_basic_vest") and psy_ids.has("backpack_basic") and psy_ids.has("rig_basic"), "Psy stocks helmet, vest, pack and rig")
	check(buyable_ids(psy_rows) == ["helmet_basic"], "Psy buyable stock is the basic helmet; vest/pack/rig stay preview (pinned inventory has no definitions for them)")
	for id in psy_ids:
		check(id in ["helmet_basic", "armor_basic_vest", "backpack_basic", "rig_basic"], "Psy only stocks gear: " + id)

	var tailor_rows: Array = TailorCatalog.rows(s.inventory, "buy")
	var tailor_ids: Array = ids_of(tailor_rows)
	check(tailor_ids.has("basic_jacket") and tailor_ids.has("cloth_linen") and tailor_ids.has("pattern_basic_gloves"), "Tailor stocks clothing, materials and patterns")
	check(buyable_ids(tailor_rows).has("basic_jacket") and buyable_ids(tailor_rows).has("cloth_linen") and buyable_ids(tailor_rows).has("thread_spool"), "Tailor garments and materials are buyable")
	check(not buyable_ids(tailor_rows).has("shirt_basic") and not buyable_ids(tailor_rows).has("dye_palette_future"), "Tailor shirt and pigments stay preview (no shirt slot or pigment item in the pinned inventory)")
	for id in tailor_ids:
		check(not id in ["timber", "stone", "metal", "helmet_basic", "fishing_pole", "bait_portion"], "Tailor does not stock other traders' items (%s)" % id)

	var fish_rows: Array = FishingCatalog.rows(s.inventory, "buy")
	var fish_ids: Array = ids_of(fish_rows)
	check(fish_ids == ["fishing_pole", "bait_portion"], "Fishing stocks the pole and bait only")
	check(buyable_ids(fish_rows) == ["fishing_pole", "bait_portion"], "Both fishing items are buyable")
	for row in fish_rows:
		check(str(row.category) == "Fishing", "Fishing category is Fishing")

	# Atlas unchanged; pinned Dan catalog stays the demo fallback
	var dan: Array = PreviewCatalog.rows("dan", "browse")
	var atlas: Array = PreviewCatalog.rows("atlas", "overview")
	check(not dan.is_empty() and str(dan[0].get("reason", "")).to_lower().contains("coming soon"), "Pinned Dan catalog is still the demo fallback")
	check(not atlas.is_empty() and atlas[0].get("price") == null and not atlas[0].get("enabled", true), "Atlas recovery stays unavailable")

	# --- icons for every stock row ----------------------------------------
	var all_ids: Array = rook_ids + psy_ids + tailor_ids + fish_ids
	for id in all_ids:
		var key: String = "pattern_sheet" if str(id).begins_with("pattern_basic_") else str(id)
		check(Renderer.ITEMS.has(str(id)) or Renderer.ITEMS.has(key), "Renderer knows %s" % id)
		# Icon files are required in the committed icon folder.
		var icon_path := ProjectSettings.globalize_path(Icons.path_for(str(id)))
		check(FileAccess.file_exists(icon_path), "Rendered icon exists for %s" % id)

	# --- Rook purchase + inventory update ---------------------------------
	var supplies := Supplies.new()
	var before_credits: int = s.plot.credits
	var bought: Dictionary = supplies.quote_candidate("rook", "buy", "timber", 2, s.plot, s.inventory, s.request, {})
	check(not bought.is_empty(), "Rook timber quote succeeds on a fresh save")
	if not bought.is_empty():
		check(bought.plot.credits == before_credits - 20, "Rook timber debit is 10 x 2")
		check(bought.inventory.amount("carried", "timber") == 2, "Rook timber is added to carried inventory")
		check(bought.receipt.balance_after == bought.plot.credits, "Rook receipt balance matches the candidate")

	var tx := ShopTransaction.new(supplies.quote_candidate)
	var writer_ok := [false]
	var quote: Dictionary = tx.select("rook", "buy", "stone", 1, s.plot, s.inventory, s.request, {})
	check(not quote.is_empty() and quote.has("token"), "Rook review step returns a token")
	var committed: Dictionary = tx.confirm(quote.token, s.plot, s.inventory, s.request, func(): return true, func(candidate):
		s.plot = candidate.plot
		s.inventory = candidate.inventory
		s.request = candidate.request
		writer_ok[0] = true
		return true
	, {})
	check(writer_ok[0] and not committed.is_empty(), "Rook confirm persists the candidate")
	check(s.inventory.amount("carried", "stone") == 1, "Live inventory has the purchased stone")
	check(s.plot.credits == before_credits - 8, "Live credits reflect the confirmed stone purchase (8 cr)")

	# Insufficient funds
	var broke := fresh()
	broke.plot.credits = 5
	var denied: Dictionary = supplies.quote_candidate("rook", "buy", "timber", 1, broke.plot, broke.inventory, broke.request, {})
	check(denied.is_empty(), "Rook rejects a timber purchase when credits are short")
	check(supplies.last_error.to_lower().contains("credit"), "Rook insufficient-funds error mentions credits: " + supplies.last_error)
	check(broke.inventory.amount("carried", "timber") == 0 and broke.plot.credits == 5, "Insufficient funds leaves inventory and credits unchanged")

	# Preview tools cannot be bought
	var tool: Dictionary = supplies.quote_candidate("rook", "buy", "pickaxe_preview", 1, s.plot, s.inventory, s.request, {})
	check(tool.is_empty(), "Rook tools stay unsellable (no inventory id in the pinned schema)")

	# --- Psy helmet purchase ----------------------------------------------
	var psy_state := fresh()
	var psy_svc := PsyPurchase.new()
	var psy_tx := ShopTransaction.new(psy_svc.quote_candidate)
	var psy_before: int = psy_state.plot.credits
	var psy_quote: Dictionary = psy_tx.select("psy", "buy", "helmet_basic", 1, psy_state.plot, psy_state.inventory, psy_state.request, {"service": "psy"})
	check(not psy_quote.is_empty(), "Psy helmet review succeeds")
	var psy_done: Dictionary = psy_tx.confirm(psy_quote.token, psy_state.plot, psy_state.inventory, psy_state.request, func(): return true, func(candidate):
		psy_state.plot = candidate.plot
		psy_state.inventory = candidate.inventory
		psy_state.request = candidate.request
		return true
	, {"service": "psy"})
	check(not psy_done.is_empty(), "Psy helmet confirm succeeds")
	check(psy_state.plot.credits == psy_before - 24, "Psy helmet costs 24 credits")
	var helmets := 0
	for entry in psy_state.inventory.equipment_owned.values():
		if entry.definition_id == "helmet_basic" and entry.location == "carried":
			helmets += 1
	check(helmets == 1, "Psy helmet is in carried equipment after purchase")

	var psy_broke := fresh()
	psy_broke.plot.credits = 10
	var psy_denied: Dictionary = psy_svc.quote_candidate("psy", "buy", "helmet_basic", 1, psy_broke.plot, psy_broke.inventory, psy_broke.request, {})
	check(psy_denied.is_empty() and psy_svc.last_error.to_lower().contains("credit"), "Psy insufficient funds: " + psy_svc.last_error)
	check(psy_broke.inventory.equipment_owned.is_empty(), "Failed Psy buy grants no helmet")

	var vest_denied: Dictionary = psy_svc.quote_candidate("psy", "buy", "armor_basic_vest", 1, psy_state.plot, psy_state.inventory, psy_state.request, {})
	check(vest_denied.is_empty(), "Psy vest stays preview-only")

	# --- Tailor purchase ---------------------------------------------------
	var tailor_state := fresh()
	var tailor_svc := TailorPurchase.new()
	var tailor_tx := ShopTransaction.new(tailor_svc.quote_candidate)
	var t_before: int = tailor_state.plot.credits
	var t_quote: Dictionary = tailor_tx.select("tailor", "buy", "cloth_linen", 3, tailor_state.plot, tailor_state.inventory, tailor_state.request, {})
	check(not t_quote.is_empty(), "Tailor linen review succeeds")
	var t_done: Dictionary = tailor_tx.confirm(t_quote.token, tailor_state.plot, tailor_state.inventory, tailor_state.request, func(): return true, func(candidate):
		tailor_state.plot = candidate.plot
		tailor_state.inventory = candidate.inventory
		tailor_state.request = candidate.request
		return true
	, {})
	check(not t_done.is_empty(), "Tailor linen confirm succeeds")
	check(tailor_state.inventory.amount("carried", "cloth_linen") == 3, "Tailor linen is in carried inventory")
	check(tailor_state.plot.credits == t_before - 12, "Tailor linen costs 4 x 3 credits")

	var jacket_quote: Dictionary = tailor_svc.quote_candidate("tailor", "buy", "basic_jacket", 1, tailor_state.plot, tailor_state.inventory, tailor_state.request, {})
	check(not jacket_quote.is_empty() and jacket_quote.plot.credits == tailor_state.plot.credits - 18, "Tailor jacket quote debit is 18")
	var jacket_owned := 0
	for entry in jacket_quote.inventory.equipment_owned.values():
		if entry.definition_id == "basic_jacket":
			jacket_owned += 1
	check(jacket_owned == 1, "Tailor jacket is added as carried clothing")

	var tailor_broke := fresh()
	tailor_broke.plot.credits = 3
	var t_denied: Dictionary = tailor_svc.quote_candidate("tailor", "buy", "basic_boots", 1, tailor_broke.plot, tailor_broke.inventory, tailor_broke.request, {})
	check(t_denied.is_empty() and tailor_svc.last_error.to_lower().contains("credit"), "Tailor insufficient funds: " + tailor_svc.last_error)

	# --- Fishing pole and bait --------------------------------------------
	var fish_state := fresh()
	var fish_svc := FishingPurchase.new()
	var fish_tx := FishingTransaction.new()
	var f_before: int = fish_state.plot.credits
	var pole_tok: int = fish_tx.select("fishing_pole", fish_state.plot, fish_state.inventory, 1)
	check(pole_tok != 0, "Fishing pole review returns a token")
	var pole_done: Dictionary = fish_tx.confirm(pole_tok, fish_state.plot, fish_state.inventory, func(): return true, func(plot, inventory):
		fish_state.plot = plot
		fish_state.inventory = inventory
		return true
	)
	check(not pole_done.is_empty(), "Fishing pole confirm succeeds")
	check(fish_state.inventory.amount("carried", "fishing_pole") == 1, "Pole is in carried inventory")
	check(fish_state.plot.credits == f_before - 25, "Pole costs 25 credits")

	var bait_tok: int = fish_tx.select("bait_portion", fish_state.plot, fish_state.inventory, 3)
	check(bait_tok != 0, "Bait review for quantity 3 succeeds")
	var bait_done: Dictionary = fish_tx.confirm(bait_tok, fish_state.plot, fish_state.inventory, func(): return true, func(plot, inventory):
		fish_state.plot = plot
		fish_state.inventory = inventory
		return true
	)
	check(not bait_done.is_empty(), "Bait confirm succeeds")
	check(fish_state.inventory.amount("carried", "bait_portion") == 3, "Three bait portions are in carried inventory")
	check(fish_state.plot.credits == f_before - 25 - 12, "Bait costs 4 x 3 credits on top of the pole")

	var fish_broke := fresh()
	fish_broke.plot.credits = 10
	var fish_denied: Dictionary = fish_svc.candidate("fishing_pole", fish_broke.plot, fish_broke.inventory, 1)
	check(fish_denied.is_empty() and fish_svc.last_error.to_lower().contains("credit"), "Fishing insufficient funds: " + fish_svc.last_error)
	check(fish_broke.inventory.amount("carried", "fishing_pole") == 0 and fish_broke.plot.credits == 10, "Failed fishing buy leaves state unchanged")

	# Replay / confirm without a selection
	var replay: Dictionary = fish_tx.confirm(bait_tok, fish_state.plot, fish_state.inventory, func(): return true, func(_p, _i): return true)
	check(replay.is_empty(), "A spent fishing token cannot be confirmed again")

	print("TRADER_BUY_MENUS_TESTS ", JSON.stringify({
		"checks": checks,
		"failures": failures,
		"scope": "Rook/Psy/Tailor/Fishing stock categories, purchases, insufficient funds, inventory update; pinned Dan catalog is the demo fallback; Atlas unchanged; icons present",
		"rook_stock": rook_ids,
		"psy_stock": psy_ids,
		"tailor_stock": tailor_ids,
		"fishing_stock": fish_ids,
	}))
	quit(0 if failures.is_empty() else 1)
