extends RefCounted
## user://gear_locker.json sidecar for tiered gear (TASKS item 22, PR A).
## Same pattern as Dan listings / Atlas recovery: the pinned save envelope can't
## grow a key, so this lives next to it. Atomic tmp-verify-rename writes. A missing
## file starts an empty locker; a corrupt file is kept as .invalid-backup and the
## locker starts empty instead of blocking the game.
const State = preload("res://raid/scripts/gear_tiers/gear_locker_state.gd")
const DEFAULT_PATH := "user://gear_locker.json"

var path := DEFAULT_PATH
var state = State.new()
var last_error := ""
var recovered_from_corrupt := false

## Loads the sidecar. Returns true when the locker is usable (always, unless
## a fresh file could not be written).
func load_locker(target: String = DEFAULT_PATH) -> bool:
	path = target
	last_error = ""
	recovered_from_corrupt = false
	state = State.new()
	if not FileAccess.file_exists(path):
		return save()
	# JSON instance parse reports errors by code (no engine ERROR line for a bad file).
	var json := JSON.new()
	var parsed: Variant = null
	if json.parse(FileAccess.get_file_as_string(path)) == OK: parsed = json.data
	var candidate = State.new()
	if candidate.restore(parsed):
		state = candidate
		return true
	var backup := path + ".invalid-backup"
	if not FileAccess.file_exists(backup):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup))
	recovered_from_corrupt = true
	last_error = "Gear locker file was invalid; kept as " + backup.get_file() + " and started empty."
	push_warning(last_error)
	return save()

func save() -> bool:
	var encoded := JSON.stringify(state.data())
	var bytes := encoded.to_utf8_buffer()
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir)) != OK:
			last_error = "Could not create gear locker folder."; return false
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		last_error = "Could not open gear locker temp file."; return false
	file.store_string(encoded)
	file.flush()
	var err := file.get_error()
	file.close()
	if err != OK or FileAccess.get_file_as_bytes(tmp) != bytes:
		last_error = "Gear locker temp file could not be verified."
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) != OK:
		last_error = "Could not commit gear locker file."; return false
	return true
