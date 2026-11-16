extends RefCounted
## Local, persistent Atlas recovery hold. Sidecar next to the character save;
## the pinned save envelope cannot grow a new key.
const Inventory = preload("res://scripts/inventory_state.gd")

const VERSION := 1
const FILE_NAME := "atlas_recovery.json"
const WAIT_SEC := 10
const EXPIRE_AFTER_RAIDS := 3
## Recovery fees are 60% of the known vendor buy price, minimum 1 credit.
const VENDOR_VALUE := {
	"timber": 10,
	"stone": 8,
	"metal": 15,
	"cloth_linen": 4,
	"thread_spool": 2,
	"fishing_pole": 25,
	"bait_portion": 4,
	"lantern_kit": 12,
	"river_fish": 5,
	"stream_fish": 5,
	"cooked_griddle_fish": 6,
}
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

var path: String = ""
var next_id: int = 1
var raid_count: int = 0
var entries: Array = []
var wait_sec: int = WAIT_SEC
var expire_after_raids: int = EXPIRE_AFTER_RAIDS
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

static func unit_fee(item_id: String) -> int:
	return maxi(1, int(round(float(VENDOR_VALUE.get(item_id, 5)) * 0.6)))

func data() -> Dictionary:
	var rows: Array = []
	for row in entries:
		rows.append((row as Dictionary).duplicate(true))
	return {"version": VERSION, "next_id": next_id, "raid_count": raid_count, "entries": rows}

func snapshot() -> Dictionary:
	return data().duplicate(true)

func clear() -> void:
	next_id = 1
	raid_count = 0
	entries = []
	last_error = ""
	_tmp_bytes = PackedByteArray()

func restore(value: Variant) -> bool:
	last_error = ""
	if not value is Dictionary:
		last_error = "Invalid recovery file."
		return false
	if not _integer(value.get("version")) or int(value.version) != VERSION:
		last_error = "Unsupported recovery version."
		return false
	if not _integer(value.get("next_id")) or int(value.next_id) < 1:
		last_error = "Invalid recovery serial."
		return false
	if not _integer(value.get("raid_count")) or int(value.raid_count) < 0:
		last_error = "Invalid raid count."
		return false
	if not value.get("entries") is Array:
		last_error = "Invalid recovery array."
		return false
	var clean: Array = []
	var seen: Dictionary = {}
	var max_serial := 0
	for row in value.entries:
		var parsed := _parse_entry(row)
		if parsed.is_empty():
			last_error = "Invalid recovery record."
			return false
		if seen.has(parsed.id):
			last_error = "Duplicate recovery id."
			return false
		seen[parsed.id] = true
		max_serial = maxi(max_serial, int(parsed.serial))
		clean.append(parsed)
	next_id = maxi(int(value.next_id), max_serial + 1)
	raid_count = int(value.raid_count)
	entries = clean
	return true

func _parse_entry(row: Variant) -> Dictionary:
	if not row is Dictionary:
		return {}
	var id := str(row.get("id", ""))
	if not id.begins_with("recovery_"):
		return {}
	var serial := int(id.trim_prefix("recovery_"))
	if serial < 1:
		return {}
	var item_id := str(row.get("item_id", ""))
	if not Inventory.ITEMS.has(item_id):
		return {}
	if not _integer(row.get("quantity")) or int(row.quantity) < 1 or int(row.quantity) > Inventory.CAPACITIES.carried:
		return {}
	if not _integer(row.get("unit_fee")) or int(row.unit_fee) < 1:
		return {}
	var status := str(row.get("status", ""))
	if not status in ["holding", "ready", "recovered", "expired"]:
		return {}
	return {
		"id": id,
		"serial": serial,
		"item_id": item_id,
		"quantity": int(row.quantity),
		"unit_fee": int(row.unit_fee),
		"status": status,
		"map": str(row.get("map", "")),
		"source": str(row.get("source", "")),
		"intake_raid": int(row.get("intake_raid", 0)),
		"expire_after_raid": int(row.get("expire_after_raid", 0)),
		"lost_unix": int(row.get("lost_unix", 0)),
		"ready_unix": int(row.get("ready_unix", 0)),
	}

func find(id: String) -> Dictionary:
	for row in entries:
		if str(row.get("id")) == id:
			return row
	return {}

func open_rows() -> Array:
	var out: Array = []
	for row in entries:
		if row.status in ["holding", "ready"]:
			out.append(row)
	return out

func add_entry(item_id: String, quantity: int, map_name: String, source: String, now_unix: int) -> Dictionary:
	var id := "recovery_%d" % next_id
	var serial := next_id
	next_id += 1
	var fee: int = unit_fee(item_id)
	var ready := now_unix + wait_sec
	var status := "ready" if wait_sec <= 0 or now_unix >= ready else "holding"
	var row := {
		"id": id,
		"serial": serial,
		"item_id": item_id,
		"quantity": quantity,
		"unit_fee": fee,
		"status": status,
		"map": map_name,
		"source": source,
		"intake_raid": raid_count,
		"expire_after_raid": raid_count + expire_after_raids,
		"lost_unix": now_unix,
		"ready_unix": ready,
	}
	entries.append(row)
	return row

func tick_raid() -> void:
	raid_count += 1

func resolve(now_unix: int) -> Dictionary:
	var became_ready: Array = []
	var expired: Array = []
	for row in entries:
		if row.status == "holding" and now_unix >= int(row.ready_unix):
			row.status = "ready"
			became_ready.append((row as Dictionary).duplicate(true))
		if row.status in ["holding", "ready"] and raid_count >= int(row.expire_after_raid) and int(row.expire_after_raid) > 0:
			row.status = "expired"
			expired.append((row as Dictionary).duplicate(true))
	return {"ready": became_ready, "expired": expired}

func force_ready(id: String, now_unix: int) -> Dictionary:
	var row := find(id)
	if row.is_empty() or row.status != "holding":
		return {}
	row.status = "ready"
	row.ready_unix = now_unix
	return (row as Dictionary).duplicate(true)

func attach(character_save_path: String) -> void:
	path = sidecar_path(character_save_path)

func load_or_create(character_save_path: String) -> bool:
	attach(character_save_path)
	if path.is_empty():
		clear()
		return true
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if restore(parsed):
			return true
		var backup := path + ".invalid-backup"
		if not FileAccess.file_exists(backup):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup))
		var reason := last_error
		clear()
		last_error = reason
		return save()
	clear()
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
			last_error = "Could not create recovery folder."
			return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Could not open recovery temp file."
		return false
	file.store_string(encoded)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or not FileAccess.file_exists(path + ".tmp") or FileAccess.get_file_as_bytes(path + ".tmp") != _tmp_bytes:
		last_error = "Recovery temp file could not be verified."
		return false
	return true

func _commit_tmp() -> bool:
	if path.is_empty() or _tmp_bytes.is_empty():
		return false
	if not FileAccess.file_exists(path + ".tmp") or FileAccess.get_file_as_bytes(path + ".tmp") != _tmp_bytes:
		last_error = "Recovery temp file changed before commit."
		return false
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if err != OK:
		last_error = "Could not commit recovery file."
		return false
	_tmp_bytes = PackedByteArray()
	return true

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value)
