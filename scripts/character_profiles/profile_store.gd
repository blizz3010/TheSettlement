extends RefCounted
# Unintegrated source candidate. Call only after an explicit creation/adoption confirmation.
# Crash leftovers are retained and block reuse; no repair, overwrite-slot or delete API.
const Model = preload("res://scripts/character_profiles/profile_model.gd")
const ROOT = "user://characters"
const INDEX = ROOT + "/catalogue.json"
const LOCK = ROOT + "/transaction.lock"
const LEGACY = "user://settlement_v1.json"

static func bytes_current(expected: PackedByteArray) -> bool:
 if DirAccess.dir_exists_absolute(INDEX):return false
 if expected.is_empty():return not FileAccess.file_exists(INDEX)
 return FileAccess.file_exists(INDEX) and FileAccess.get_file_as_bytes(INDEX) == expected

static func write_new(path: String, content: PackedByteArray) -> bool:
 if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):return false
 var file = FileAccess.open(path,FileAccess.WRITE)
 if file == null:return false
 file.store_buffer(content);file.flush()
 var ok = file.get_error() == OK
 file.close()
 return ok and FileAccess.get_file_as_bytes(path) == content

static func create(profile: Dictionary, rules: Dictionary, expected_index: PackedByteArray, gameplay: PackedByteArray, validate_gameplay: Callable, adopt_legacy: bool = false) -> Dictionary:
 # The gameplay validator must be the exact delivered SaveCodec decode wrapper.
 # This API has no default/reset fallback for malformed data.
 if not validate_gameplay.is_valid() or gameplay.is_empty() or not Model.profile_valid(profile,rules):return {"ok":false,"reason":"Invalid creation input"}
 var proposed = profile.duplicate(true)
 if proposed.intro_seen:return {"ok":false,"reason":"New profile cannot skip intro"}
 var current = {"version":1,"revision":0,"profiles":[]}
 if not expected_index.is_empty():
  current = JSON.parse_string(expected_index.get_string_from_utf8())
  if not current is Dictionary:return {"ok":false,"reason":"Malformed existing catalogue"}
 if not Model.catalogue_valid(current,rules):return {"ok":false,"reason":"Invalid catalogue"}
 var next = Model.add_candidate(current,proposed,int(current.revision),rules)
 if next.is_empty():return {"ok":false,"reason":"Slot occupied or catalogue full"}
 if validate_gameplay.call(gameplay) != true:return {"ok":false,"reason":"Gameplay validation failed"}
 var legacy_exists = FileAccess.file_exists(LEGACY)
 if DirAccess.dir_exists_absolute(LEGACY):return {"ok":false,"reason":"Legacy save path is a directory"}
 if legacy_exists and current.profiles.is_empty() and not adopt_legacy:return {"ok":false,"reason":"Explicit legacy adoption required"}
 if adopt_legacy and (not legacy_exists or not current.profiles.is_empty() or proposed.slot != "slot_1" or FileAccess.get_file_as_bytes(LEGACY) != gameplay):return {"ok":false,"reason":"Legacy adoption bytes or target mismatch"}
 if DirAccess.make_dir_recursive_absolute(ROOT) != OK:return {"ok":false,"reason":"Cannot prepare profile directory"}
 if DirAccess.make_dir_absolute(LOCK) != OK:return {"ok":false,"reason":"Another transaction or interrupted transaction needs recovery"}
 var outcome = _locked_create(next,proposed.slot,expected_index,gameplay,adopt_legacy)
 # Only our empty lock directory is removed. Slot data and failure evidence are never removed.
 if DirAccess.remove_absolute(LOCK) != OK:outcome["recovery_required"] = true
 return outcome

static func _locked_create(next: Dictionary, slot: String, expected: PackedByteArray, gameplay: PackedByteArray, adopting: bool) -> Dictionary:
 if not bytes_current(expected):return {"ok":false,"reason":"Catalogue changed; no slot written"}
 if not adopting and next.profiles.size() == 1 and (FileAccess.file_exists(LEGACY) or DirAccess.dir_exists_absolute(LEGACY)):return {"ok":false,"reason":"Legacy data appeared; explicit adoption required"}
 if adopting and FileAccess.get_file_as_bytes(LEGACY) != gameplay:return {"ok":false,"reason":"Legacy save changed"}
 var directory = ROOT + "/" + slot
 if DirAccess.make_dir_absolute(directory) != OK:return {"ok":false,"reason":"Slot already exists or cannot be created; recovery required"}
 var target = Model.save_path(slot)
 if not write_new(target,gameplay):return {"ok":false,"reason":"Gameplay write/readback failed; unpublished slot retained"}
 if not expected.is_empty():
  var backup = ROOT + "/catalogue.r%d.backup" % int(next.revision-1)
  if not write_new(backup,expected):return {"ok":false,"reason":"Catalogue backup failed or conflicts; unpublished slot retained"}
 var temporary = ROOT + "/catalogue.r%d.pending" % int(next.revision)
 var encoded = JSON.stringify(next).to_utf8_buffer()
 if not write_new(temporary,encoded):return {"ok":false,"reason":"Catalogue staging failed; unpublished slot retained"}
 if not bytes_current(expected) or (adopting and FileAccess.get_file_as_bytes(LEGACY) != gameplay):return {"ok":false,"reason":"Source changed before publication; staged files retained"}
 if not adopting and next.profiles.size() == 1 and (FileAccess.file_exists(LEGACY) or DirAccess.dir_exists_absolute(LEGACY)):return {"ok":false,"reason":"Legacy data appeared before publication; staged files retained"}
 if DirAccess.rename_absolute(temporary,INDEX) != OK:return {"ok":false,"reason":"Catalogue publication failed; staged files retained"}
 if FileAccess.get_file_as_bytes(INDEX) != encoded:return {"ok":false,"reason":"Publication readback uncertain; recovery required","uncertain":true}
 return {"ok":true,"slot":slot,"revision":next.revision,"legacy_preserved":adopting}

static func mark_intro(expected:PackedByteArray, slot:String, rules:Dictionary)->Dictionary:
 var parser=JSON.new()
 if parser.parse(expected.get_string_from_utf8())!=OK:return {"ok":false,"reason":"Invalid catalogue"}
 if not Model.catalogue_valid(parser.data,rules):return {"ok":false,"reason":"Invalid catalogue"}
 var next=Model.intro_candidate(parser.data,slot,int(parser.data.revision),rules)
 if next.is_empty():return {"ok":false,"reason":"Intro state changed"}
 if DirAccess.make_dir_absolute(LOCK)!=OK:return {"ok":false,"reason":"Profile transaction locked"}
 var result=_locked_intro(expected,next)
 if DirAccess.remove_absolute(LOCK)!=OK:result["recovery_required"]=true
 return result

static func _locked_intro(expected:PackedByteArray,next:Dictionary)->Dictionary:
 if not bytes_current(expected):return {"ok":false,"reason":"Catalogue changed"}
 var backup=ROOT+"/catalogue.r%d.backup"%int(next.revision-1)
 if not write_new(backup,expected):return {"ok":false,"reason":"Intro backup conflicts; preserve files"}
 var pending_path=ROOT+"/catalogue.r%d.pending"%int(next.revision)
 var bytes=JSON.stringify(next).to_utf8_buffer()
 if not write_new(pending_path,bytes):return {"ok":false,"reason":"Intro write failed"}
 if not bytes_current(expected):return {"ok":false,"reason":"Catalogue changed before intro commit"}
 if DirAccess.rename_absolute(pending_path,INDEX)!=OK:return {"ok":false,"reason":"Intro commit failed"}
 if FileAccess.get_file_as_bytes(INDEX)!=bytes:return {"ok":false,"reason":"Intro readback uncertain","uncertain":true}
 return {"ok":true,"bytes":bytes}
