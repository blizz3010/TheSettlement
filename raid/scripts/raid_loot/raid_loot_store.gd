extends RefCounted
## TASKS item 13: the raid haul sidecar (raid_haul.json next to the character save;
## the pinned save envelope cannot grow a new key). Holds salvage valuables waiting
## to be sold at Atlas, material overflow that did not fit the bag or stash, the
## ids of raid returns already applied (so one extraction never pays twice) and
## simple lifetime stats. Atomic tmp+rename writes; a corrupt file is backed up.
const LootTable = preload("res://raid/scripts/raid_loot/loot_table.gd")

const VERSION := 1
const FILE_NAME := "raid_haul.json"
const MAX_APPLIED := 64
const MAX_STACK := 9999

var path: String = ""
var salvage: Dictionary = {}
var cargo: Dictionary = {}
var applied: Array = []
var stats: Dictionary = {"extractions": 0, "items_brought": 0, "salvage_sold": 0, "credits_earned": 0, "hauls_lost": 0}
var last_error: String = ""
var _tmp_bytes: PackedByteArray = PackedByteArray()

static func sidecar_path(character_save_path: String) -> String:
	if character_save_path.is_empty():
		return ""
	return character_save_path.get_base_dir().path_join(FILE_NAME)

func clear() -> void:
	salvage = {}
	cargo = {}
	applied = []
	stats = {"extractions": 0, "items_brought": 0, "salvage_sold": 0, "credits_earned": 0, "hauls_lost": 0}
	last_error = ""
	_tmp_bytes = PackedByteArray()

func data() -> Dictionary:
	return {"version": VERSION, "salvage": salvage.duplicate(true), "cargo": cargo.duplicate(true),
		"applied": applied.duplicate(), "stats": stats.duplicate(true)}

func snapshot() -> Dictionary:
	return data().duplicate(true)

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value)

static func _stacks(value: Variant, kind: String) -> Variant:
	if not value is Dictionary:
		return null
	var clean := {}
	for id in value:
		if not id is String or LootTable.kind(id) != kind:
			return null
		if not _integer(value[id]) or int(value[id]) < 0 or int(value[id]) > MAX_STACK:
			return null
		if int(value[id]) > 0:
			clean[id] = int(value[id])
	return clean

func restore(value: Variant) -> bool:
	last_error = ""
	if not value is Dictionary:
		last_error = "Invalid raid haul file."
		return false
	if not _integer(value.get("version")) or int(value.version) != VERSION:
		last_error = "Unsupported raid haul version."
		return false
	var s = _stacks(value.get("salvage"), "salvage")
	var c = _stacks(value.get("cargo"), "material")
	if s == null or c == null:
		last_error = "Invalid raid haul stacks."
		return false
	if not value.get("applied") is Array or value.applied.size() > MAX_APPLIED:
		last_error = "Invalid raid haul ledger."
		return false
	for uid in value.applied:
		if not uid is String or uid.is_empty() or uid.length() > 96:
			last_error = "Invalid raid haul ledger."
			return false
	if not value.get("stats") is Dictionary:
		last_error = "Invalid raid haul stats."
		return false
	var next_stats := {}
	for key in ["extractions", "items_brought", "salvage_sold", "credits_earned", "hauls_lost"]:
		var v = value.stats.get(key)
		if not _integer(v) or int(v) < 0 or int(v) > 100000000:
			last_error = "Invalid raid haul stats."
			return false
		next_stats[key] = int(v)
	salvage = s
	cargo = c
	applied = (value.applied as Array).duplicate()
	stats = next_stats
	return true

func was_applied(uid: String) -> bool:
	return not uid.is_empty() and applied.has(uid)

func mark_applied(uid: String) -> void:
	if uid.is_empty() or applied.has(uid):
		return
	applied.append(uid)
	while applied.size() > MAX_APPLIED:
		applied.pop_front()

func salvage_value() -> int:
	return LootTable.total_value(salvage)

func load_or_create(character_save_path: String) -> bool:
	path = sidecar_path(character_save_path)
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
	var encoded := JSON.stringify(data())
	_tmp_bytes = encoded.to_utf8_buffer()
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir)) != OK:
			last_error = "Could not create the raid haul folder."
			return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Could not open the raid haul temp file."
		return false
	file.store_string(encoded)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_file_as_bytes(path + ".tmp") != _tmp_bytes:
		last_error = "Raid haul temp file could not be verified."
		return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK:
		last_error = "Could not commit the raid haul file."
		return false
	_tmp_bytes = PackedByteArray()
	return true
