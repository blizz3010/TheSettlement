extends SceneTree
## Item 13: Dan's local player listings — post, buy, cancel, payout,
## insufficient funds, and sidecar persistence. Bidding is deferred.
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Request = preload("res://scripts/request_state.gd")
const ShopTransaction = preload("res://scripts/shop_transaction.gd")
const PreviewCatalog = preload("res://scripts/trader_preview_catalog.gd")
const Store = preload("res://raid/scripts/dan_listings_store.gd")
const Service = preload("res://raid/scripts/dan_listings_service.gd")
const Panel = preload("res://raid/scripts/dan_listings_panel.gd")
const Install = preload("res://raid/scripts/dan_listings_install.gd")
const Icons = preload("res://raid/scripts/trader_buy_icons.gd")

var checks := 0
var failures: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func fresh() -> Dictionary:
	return {"plot": Plot.new(), "inventory": Inventory.new(), "request": Request.new()}

func ctx(store: Store, asking: int = 5, now: int = 1000, delay: int = 15) -> Dictionary:
	return {"listings": store.snapshot(), "asking_price": asking, "now_unix": now, "sale_delay_sec": delay}

func sidecar() -> String:
	return "user://dan_listings_test/dan_listings.json"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Atlas stays preview-only; the pinned Dan catalog remains the demo fallback.
	var atlas: Array = PreviewCatalog.rows("atlas", "overview")
	check(not atlas.is_empty() and atlas[0].get("price") == null and not atlas[0].get("enabled", true), "Atlas recovery stays unavailable")
	var demo: Array = PreviewCatalog.rows("dan", "browse")
	check(not demo.is_empty() and str(demo[0].get("reason", "")).to_lower().contains("coming soon"), "Pinned Dan catalog is still the demo fallback")

	var store := Store.new()
	store.sale_delay_sec = 15
	store.seed_if_empty(1000)
	check(store.active_rows().size() == Store.SEEDS.size(), "Seeded NPC listings fill a new board")
	var names: Array = []
	for row in store.active_rows():
		names.append(str(row.seller_name))
		check(row.seller_id != Store.PLAYER_SELLER, "Seeds are not attributed to the player")
		check(Inventory.ITEMS.has(str(row.item_id)), "Seed item is in the pinned inventory: " + str(row.item_id))
		check(str(row.seller_name) != "" and not str(row.seller_name).to_lower().contains("sample seller"), "Seed sellers have original names")
	check(names.has("Harlan Reed") and names.has("Sora Venn"), "Seed names include Harlan Reed and Sora Venn")

	# --- post ---------------------------------------------------------------
	var s: Dictionary = fresh()
	s.inventory.carried["timber"] = 3
	var svc := Service.new()
	var posted: Dictionary = svc.quote_candidate("dan", "post", "timber", 2, s.plot, s.inventory, s.request, ctx(store, 9, 2000))
	check(not posted.is_empty(), "Posting two timber at 9 credits succeeds: " + svc.last_error)
	if not posted.is_empty():
		check(posted.inventory.amount("carried", "timber") == 1, "Posting reserves 2 timber and leaves 1 carried")
		check(posted.plot.credits == s.plot.credits, "Posting does not take credits")
		var mine: Dictionary = Store.new()
		check(mine.restore(posted.listings), "Posted listings restore")
		var found := false
		for row in mine.player_rows():
			if row.item_id == "timber" and int(row.quantity) == 2 and int(row.unit_price) == 9 and row.status == "active":
				found = true
		check(found, "Posted timber listing is active on the board")
		s.plot = posted.plot
		s.inventory = posted.inventory
		store.restore(posted.listings)

	var too_many: Dictionary = svc.quote_candidate("dan", "post", "timber", 4, s.plot, s.inventory, s.request, ctx(store, 9, 2000))
	check(too_many.is_empty() and svc.last_error.to_lower().contains("carried"), "Cannot post more than carried: " + svc.last_error)

	# --- buy NPC listing ----------------------------------------------------
	var harlan_id := ""
	for row in store.active_rows():
		if row.seller_id == "harlan_reed":
			harlan_id = str(row.id)
			break
	check(not harlan_id.is_empty(), "Harlan's timber listing is on the board")
	var before_credits: int = s.plot.credits
	var before_timber: int = s.inventory.amount("carried", "timber")
	var bought: Dictionary = svc.quote_candidate("dan", "buy", harlan_id, 3, s.plot, s.inventory, s.request, ctx(store, 9, 2100))
	check(not bought.is_empty(), "Buying Harlan's timber listing succeeds: " + svc.last_error)
	if not bought.is_empty():
		check(bought.plot.credits == before_credits - 24, "Harlan's lot costs 8 x 3 = 24 credits")
		check(bought.inventory.amount("carried", "timber") == before_timber + 3, "Bought timber is added to carried inventory")
		var after := Store.new()
		after.restore(bought.listings)
		check(after.find(harlan_id).status == "sold", "Bought NPC listing is marked sold")
		s.plot = bought.plot
		s.inventory = bought.inventory
		store.restore(bought.listings)

	# --- insufficient funds -------------------------------------------------
	var broke := fresh()
	broke.plot.credits = 5
	var nila_id := ""
	for row in store.active_rows():
		if row.seller_id == "nila_korr":
			nila_id = str(row.id)
			break
	var denied: Dictionary = svc.quote_candidate("dan", "buy", nila_id, 1, broke.plot, broke.inventory, broke.request, ctx(store, 5, 2200))
	check(denied.is_empty() and svc.last_error.to_lower().contains("credit"), "Insufficient funds blocks the buy: " + svc.last_error)
	check(broke.plot.credits == 5 and broke.inventory.amount("carried", "metal") == 0, "Failed buy leaves credits and inventory unchanged")

	# --- cannot buy your own listing ----------------------------------------
	var own_id := ""
	for row in store.player_rows():
		if row.status == "active" and row.item_id == "timber":
			own_id = str(row.id)
			break
	check(not own_id.is_empty(), "The player's timber listing is still active")
	var self_buy: Dictionary = svc.quote_candidate("dan", "buy", own_id, 2, s.plot, s.inventory, s.request, ctx(store, 9, 2300))
	check(self_buy.is_empty() and svc.last_error.to_lower().contains("your listing"), "Cannot buy your own listing: " + svc.last_error)

	# --- cancel returns the item --------------------------------------------
	# Post a separate stone listing so cancel can be tested without touching the timber one we will sell.
	s.inventory.carried["stone"] = 2
	var stone_post: Dictionary = svc.quote_candidate("dan", "post", "stone", 2, s.plot, s.inventory, s.request, ctx(store, 6, 2400))
	check(not stone_post.is_empty(), "Posting stone succeeds")
	var stone_id := str(stone_post.receipt.listing_id) if not stone_post.is_empty() else ""
	if not stone_post.is_empty():
		s.plot = stone_post.plot
		s.inventory = stone_post.inventory
		store.restore(stone_post.listings)
	var carried_before_cancel: int = s.inventory.amount("carried", "stone")
	var cancelled: Dictionary = svc.quote_candidate("dan", "cancel", stone_id, 2, s.plot, s.inventory, s.request, ctx(store, 6, 2500))
	check(not cancelled.is_empty(), "Cancelling the stone listing succeeds: " + svc.last_error)
	if not cancelled.is_empty():
		check(cancelled.inventory.amount("carried", "stone") == carried_before_cancel + 2, "Cancel returns the listed stone")
		check(cancelled.plot.credits == s.plot.credits, "Cancel does not change credits")
		var after_cancel := Store.new()
		after_cancel.restore(cancelled.listings)
		check(after_cancel.find(stone_id).status == "cancelled", "Cancelled listing is marked cancelled")
		s.plot = cancelled.plot
		s.inventory = cancelled.inventory
		store.restore(cancelled.listings)

	# Cancel into a full bag fails.
	var full := fresh()
	full.inventory.carried["timber"] = 8
	var full_store := Store.new()
	full_store.restore(store.snapshot())
	# Re-post stone onto a copy where the bag is already full of timber.
	full_store.add_listing(Store.PLAYER_SELLER, Store.PLAYER_NAME, "stone", 2, 6, 2500)
	var full_id := ""
	for row in full_store.player_rows():
		if row.item_id == "stone" and row.status == "active":
			full_id = str(row.id)
	var full_cancel: Dictionary = svc.quote_candidate("dan", "cancel", full_id, 2, full.plot, full.inventory, full.request, ctx(full_store, 6, 2600))
	check(full_cancel.is_empty() and svc.last_error.to_lower().contains("bag full"), "Cancel fails when the bag is full: " + svc.last_error)

	# --- payout after a timed sale ------------------------------------------
	check(not own_id.is_empty(), "Timber listing id is known for the sale")
	# 15 second delay; posted at 2000, so it sells at 2015. Use a later clock.
	var sold_rows: Array = store.resolve_sales(2000 + 15)
	var sold_ok := false
	for row in sold_rows:
		if str(row.id) == own_id:
			sold_ok = true
	check(sold_ok, "Player timber listing sells after the delay")
	check(store.find(own_id).status == "sold", "Sold listing waits for payout")
	check(store.pending_payout_total() == 18, "Waiting payout is 9 x 2 = 18 credits")
	var credits_before_pay: int = s.plot.credits
	var paid: Dictionary = svc.quote_candidate("dan", "collect", own_id, 1, s.plot, s.inventory, s.request, ctx(store, 9, 3000))
	check(not paid.is_empty(), "Collecting the payout succeeds: " + svc.last_error)
	if not paid.is_empty():
		check(paid.plot.credits == credits_before_pay + 18, "Payout adds 18 credits")
		check(paid.inventory.amount("carried", "timber") == s.inventory.amount("carried", "timber"), "Payout does not change inventory")
		var after_pay := Store.new()
		after_pay.restore(paid.listings)
		check(after_pay.find(own_id).status == "collected", "Collected listing is marked collected")
		s.plot = paid.plot
		s.inventory = paid.inventory
		store.restore(paid.listings)

	# force_sell + collect_all path
	s.inventory.carried["cloth_linen"] = 2
	var cloth_post: Dictionary = svc.quote_candidate("dan", "post", "cloth_linen", 2, s.plot, s.inventory, s.request, ctx(store, 5, 4000))
	check(not cloth_post.is_empty(), "Posting linen succeeds")
	if not cloth_post.is_empty():
		s.plot = cloth_post.plot
		s.inventory = cloth_post.inventory
		store.restore(cloth_post.listings)
		var cloth_id: String = str(cloth_post.receipt.listing_id)
		store.force_sell(cloth_id, 4001)
		var all_pay: Dictionary = svc.quote_candidate("dan", "collect", "payout_all", 1, s.plot, s.inventory, s.request, ctx(store, 5, 4002))
		check(not all_pay.is_empty(), "Collect-all payout succeeds: " + svc.last_error)
		if not all_pay.is_empty():
			check(all_pay.plot.credits == s.plot.credits + 10, "Collect-all adds 5 x 2 credits")
			s.plot = all_pay.plot
			s.inventory = all_pay.inventory
			store.restore(all_pay.listings)

	# --- persistence --------------------------------------------------------
	var path := sidecar()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	store.attach(path)
	check(store.save() and FileAccess.file_exists(path), "Sidecar save writes dan_listings.json")
	var reloaded := Store.new()
	check(reloaded.load_or_seed(path, 5000), "Sidecar reloads")
	check(reloaded.find(own_id).status == "collected", "Collected payout survives a reload")
	check(reloaded.find(harlan_id).status == "sold", "Bought NPC listing survives a reload")
	check(reloaded.pending_payout_total() == 0, "No extra payouts appear after reload")
	# A second load_or_seed on an existing file must not re-seed.
	var again := Store.new()
	again.load_or_seed(path, 6000)
	check(again.active_rows().size() == reloaded.active_rows().size(), "Reloading an existing sidecar does not reseed")

	# Transaction wrapper still works with the service builder.
	var tx_state := fresh()
	tx_state.inventory.carried["bait_portion"] = 4
	var tx_store := Store.new()
	tx_store.seed_if_empty(1000)
	var tx := ShopTransaction.new(svc.quote_candidate)
	var quote: Dictionary = tx.select("dan", "post", "bait_portion", 2, tx_state.plot, tx_state.inventory, tx_state.request, ctx(tx_store, 3, 7000))
	check(not quote.is_empty(), "ShopTransaction can review a listing post")
	var writer_ok := [false]
	var committed: Dictionary = tx.confirm(quote.token, tx_state.plot, tx_state.inventory, tx_state.request, func(): return true, func(candidate):
		tx_state.plot = candidate.plot
		tx_state.inventory = candidate.inventory
		tx_store.restore(candidate.listings)
		writer_ok[0] = true
		return true
	, ctx(tx_store, 3, 7000))
	check(not committed.is_empty() and writer_ok[0], "ShopTransaction confirm persists a post")
	check(tx_state.inventory.amount("carried", "bait_portion") == 2, "Confirmed post removes bait from carried")

	# Panel rows and review labels, including the bidding deferral.
	var ui := Panel.new()
	# ShopPanel hides in _ready and needs a tree for some layout; row helpers do not.
	var browse: Array = ui.browse_rows(store, s.inventory)
	var buyable := 0
	for row in browse:
		if row.get("enabled", false) and row.get("row_action") == "buy":
			buyable += 1
			check(row.get("price") != null, "Buyable row has a price")
	check(buyable >= 1, "Browse has at least one buyable NPC listing")
	ui.action = "how it works"
	var help: Array = ui.help_rows()
	check(not help.is_empty() and str(help[0].get("description", "")).to_lower().contains("bidding is not in this build"), "How-it-works defers bidding")
	check(ui._review_label("post") == "Review listing" and ui._verb("collect") == "Collect", "Panel verbs match post and payout")

	# Seeded items reuse mid-to-high poly item 16 icons. No new low-poly art.
	for spec in Store.SEEDS:
		var icon_path := ProjectSettings.globalize_path(Icons.path_for(str(spec.item_id)))
		check(FileAccess.file_exists(icon_path), "Existing mid-style icon is used for seed %s" % spec.item_id)

	# Installer is a no-op without a trader controller (does not throw).
	check(Install.install(null) == false, "Installer refuses a missing host")

	print("DAN_PLAYER_LISTINGS_TESTS ", JSON.stringify({
		"checks": checks,
		"failures": failures,
		"scope": "Dan post, buy, cancel, payout, insufficient funds, persistence; bidding deferred; Atlas unchanged",
		"seed_count": Store.SEEDS.size(),
	}))
	quit(0 if failures.is_empty() else 1)
