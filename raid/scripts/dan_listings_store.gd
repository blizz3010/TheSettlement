extends RefCounted
## Local, persistent player-marketplace listings for Dan.
## Stored as a sidecar next to the character save: the pinned save_codec
## envelope cannot grow a new key, and inventory_state is also pinned.
const Inventory = preload("res://scripts/inventory_state.gd")

const VERSION := 1
const PLAYER_SELLER := "player"
const PLAYER_NAME := "You"
const SALE_DELAY_SEC := 15
const FILE_NAME := "dan_listings.json"

const NAMES := {
	"cooked_griddle_fish": "Griddle fish",
	"cloth_linen": "Linen cloth",
	"thread_spool": "Thread spool",
	"river_fish": "River fish",
	"fishing_pole": "Basic fishing pole",
	"bait_portion": "Bait portion",
	"timber": "Timber",
	"stone": "Stone",
	"metal": "Metal scrap",
	"lantern_kit": "Lantern kit",
	"stream_fish": "Stream fish",
}
const CATEGORIES := {
	"cooked_griddle_fish": "Fishing",
	"cloth_linen": "Materials",
	"thread_spool": "Materials",
	"river_fish": "Fishing",
	"fishing_pole": "Fishing",
	"bait_portion": "Fishing",
	"timber": "Materials",
	"stone": "Materials",
	"metal": "Materials",
	"lantern_kit": "Materials",
	"stream_fish": "Fishing",
}
const SUGGESTED_PRICE := {
	"timber": 7,
	"stone": 6,
	"metal": 11,
	"cloth_linen": 5,
	"thread_spool": 3,
	"bait_portion": 3,
	"fishing_pole": 20,
	"lantern_kit": 10,
	"river_fish": 4,
	"stream_fish": 4,
	"cooked_griddle_fish": 5,
}

## Seeded NPC-settler listings so a new board is not empty. Names are generic
## and original. Only pinned inventory ids, and only items that already have
## mid-to-high poly model-rendered icons from the item 16 buy menus.
const SEEDS := [
	{"seller_id": "harlan_reed", "seller_name": "Harlan Reed", "item_id": "timber", "quantity": 3, "unit_price": 8},
	{"seller_id": "mira_holt", "seller_name": "Mira Holt", "item_id": "stone", "quantity": 2, "unit_price": 6},
	{"seller_id": "nila_korr", "seller_name": "Nila Korr", "item_id": "metal", "quantity": 1, "unit_price": 12},
	{"seller_id": "sora_venn", "seller_name": "Sora Venn", "item_id": "cloth_linen", "quantity": 2, "unit_price": 5},
	{"seller_id": "joss_calder", "seller_name": "Joss Calder", "item_id": "bait_portion", "quantity": 4, "unit_price": 3},
	{"seller_id": "pax_elian", "seller_name": "Pax Elian", "item_id": "thread_spool", "quantity": 1, "unit_price": 3},
]
const BUYER_POOL := ["Calder Voss", "Ryn Halden", "Ivo Senn", "Tamsin Low"]

var path: String = ""
var next_id: int = 1
var listings: Array = []
var sale_delay_sec: int = SALE_DELAY_SEC
var last_error: String = ""
var _tmp_bytes: PackedByteArray = PackedByteArray()

static func sidecar_path(character_save_path: String) -> String:
	if character_save_path.is_empty():
		return ""
	return character_save_path.get_base_dir().path_join(FILE_NAME)

static func display_name(item_id: String) -> String:
	return str(NAMES.get(item_id, item_id.capitalize()))

static func category_of(item_id: String) -> String:
	return str(CATEGORIES.get(item_id, "Other"))

static func suggested_price(item_id: String) -> int:
	return int(SUGGESTED_PRICE.get(item_id, 5))

func data() -> Dictionary:
	var rows: Array = []
	for row in listings:
		rows.append((row as Dictionary).duplicate(true))
	return {"version": VERSION, "next_id": next_id, "listings": rows}

func snapshot() -> Dictionary:
	return data().duplicate(true)

func clear() -> void:
	next_id = 1
	listings = []
	last_error = ""
	_tmp_bytes = PackedByteArray()

func restore(value: Variant) -> bool:
	last_error = ""
	if not value is Dictionary:
		last_error = "Invalid listings file."
		return false
	if not _integer(value.get("version")) or int(value.version) != VERSION:
		last_error = "Unsupported listings version."
		return false
	if not _integer(value.get("next_id")) or int(value.next_id) < 1:
		last_error = "Invalid listings serial."
		return false
	if not value.get("listings") is Array:
		last_error = "Invalid listings array."
		return false
	var clean: Array = []
	var seen: Dictionary = {}
	var max_serial := 0
	for row in value.listings:
		var parsed := _parse_listing(row)
		if parsed.is_empty():
			last_error = "Invalid listing record."
			return false
		if seen.has(parsed.id):
			last_error = "Duplicate listing id."
			return false
		seen[parsed.id] = true
		max_serial = maxi(max_serial, int(parsed.serial))
		clean.append(parsed)
	next_id = maxi(int(value.next_id), max_serial + 1)
	listings = clean
	return true

func _parse_listing(row: Variant) -> Dictionary:
	if not row is Dictionary:
		return {}
	var id := str(row.get("id", ""))
	if not id.begins_with("listing_"):
		return {}
	var serial := int(id.trim_prefix("listing_"))
	if serial < 1:
		return {}
	var item_id := str(row.get("item_id", ""))
	if not Inventory.ITEMS.has(item_id):
		return {}
	if not _integer(row.get("quantity")) or int(row.quantity) < 1 or int(row.quantity) > Inventory.CAPACITIES.carried:
		return {}
	if not _integer(row.get("unit_price")) or int(row.unit_price) < 1 or int(row.unit_price) > 9999:
		return {}
	var status := str(row.get("status", ""))
	if not status in ["active", "sold", "cancelled", "collected"]:
		return {}
	var seller_id := str(row.get("seller_id", ""))
	var seller_name := str(row.get("seller_name", ""))
	if seller_id.is_empty() or seller_name.is_empty():
		return {}
	if seller_id == PLAYER_SELLER and seller_name != PLAYER_NAME:
		seller_name = PLAYER_NAME
	var posted := int(row.get("posted_unix", 0))
	var sold_unix := int(row.get("sold_unix", 0))
	var payout := int(row.get("payout", 0))
	var buyer_name := str(row.get("buyer_name", ""))
	if status in ["sold", "collected"] and seller_id == PLAYER_SELLER:
		if payout != int(row.unit_price) * int(row.quantity) or buyer_name.is_empty():
			return {}
	return {
		"id": id,
		"serial": serial,
		"seller_id": seller_id,
		"seller_name": seller_name,
		"item_id": item_id,
		"quantity": int(row.quantity),
		"unit_price": int(row.unit_price),
		"status": status,
		"posted_unix": posted,
		"sold_unix": sold_unix,
		"buyer_name": buyer_name,
		"payout": payout,
	}

func find(id: String) -> Dictionary:
	for row in listings:
		if str(row.get("id")) == id:
			return row
	return {}

func active_rows() -> Array:
	var out: Array = []
	for row in listings:
		if row.status == "active":
			out.append(row)
	return out

func player_rows() -> Array:
	var out: Array = []
	for row in listings:
		if row.seller_id == PLAYER_SELLER and row.status in ["active", "sold"]:
			out.append(row)
	return out

func pending_payouts() -> Array:
	var out: Array = []
	for row in listings:
		if row.seller_id == PLAYER_SELLER and row.status == "sold":
			out.append(row)
	return out

func pending_payout_total() -> int:
	var total := 0
	for row in pending_payouts():
		total += int(row.payout)
	return total

func add_listing(seller_id: String, seller_name: String, item_id: String, quantity: int, unit_price: int, posted_unix: int) -> Dictionary:
	var id := "listing_%d" % next_id
	var serial := next_id
	next_id += 1
	var row := {
		"id": id,
		"serial": serial,
		"seller_id": seller_id,
		"seller_name": seller_name,
		"item_id": item_id,
		"quantity": quantity,
		"unit_price": unit_price,
		"status": "active",
		"posted_unix": posted_unix,
		"sold_unix": 0,
		"buyer_name": "",
		"payout": 0,
	}
	listings.append(row)
	return row

func seed_if_empty(posted_unix: int = 0) -> void:
	if not listings.is_empty():
		return
	for spec in SEEDS:
		add_listing(str(spec.seller_id), str(spec.seller_name), str(spec.item_id), int(spec.quantity), int(spec.unit_price), posted_unix)

func resolve_sales(now_unix: int) -> Array:
	var newly: Array = []
	for row in listings:
		if row.status != "active" or row.seller_id != PLAYER_SELLER:
			continue
		if now_unix < int(row.posted_unix) + sale_delay_sec:
			continue
		_mark_sold(row, now_unix)
		newly.append((row as Dictionary).duplicate(true))
	return newly

func force_sell(id: String, now_unix: int) -> Dictionary:
	var row := find(id)
	if row.is_empty() or row.status != "active" or row.seller_id != PLAYER_SELLER:
		return {}
	_mark_sold(row, now_unix)
	return (row as Dictionary).duplicate(true)

func _mark_sold(row: Dictionary, now_unix: int) -> void:
	row.status = "sold"
	row.sold_unix = now_unix
	row.buyer_name = BUYER_POOL[int(row.serial) % BUYER_POOL.size()]
	row.payout = int(row.unit_price) * int(row.quantity)

func attach(character_save_path: String) -> void:
	path = sidecar_path(character_save_path)

func load_or_seed(character_save_path: String, now_unix: int = 0) -> bool:
	attach(character_save_path)
	if path.is_empty():
		clear()
		seed_if_empty(now_unix)
		return true
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if restore(parsed):
			return true
		# Keep the bad file and start a clean seeded board so a corrupt sidecar
		# cannot brick the stand. The original bytes stay next to it.
		var backup := path + ".invalid-backup"
		if not FileAccess.file_exists(backup):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup))
		var reason := last_error
		clear()
		seed_if_empty(now_unix)
		last_error = reason
		return save()
	clear()
	seed_if_empty(now_unix)
	return save()

func save() -> bool:
	if path.is_empty():
		return true
	if not _write_tmp():
		return false
	return _commit_tmp()

func _write_tmp() -> bool:
	if path.is_empty():
		return false
	var encoded := JSON.stringify(data())
	_tmp_bytes = encoded.to_utf8_buffer()
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		if err != OK:
			last_error = "Could not create listings folder."
			return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Could not open listings temp file."
		return false
	file.store_string(encoded)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or not FileAccess.file_exists(path + ".tmp") or FileAccess.get_file_as_bytes(path + ".tmp") != _tmp_bytes:
		last_error = "Listings temp file could not be verified."
		return false
	return true

func _commit_tmp() -> bool:
	if path.is_empty() or _tmp_bytes.is_empty():
		return false
	if not FileAccess.file_exists(path + ".tmp") or FileAccess.get_file_as_bytes(path + ".tmp") != _tmp_bytes:
		last_error = "Listings temp file changed before commit."
		return false
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if err != OK:
		last_error = "Could not commit listings file."
		return false
	_tmp_bytes = PackedByteArray()
	return true

func discard_tmp() -> void:
	_tmp_bytes = PackedByteArray()
	if not path.is_empty() and FileAccess.file_exists(path + ".tmp"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value)
