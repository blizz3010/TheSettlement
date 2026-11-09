extends RefCounted
# Title-facing source adapter; no UI/world is instantiated here.
const Model=preload("res://scripts/character_profiles/profile_model.gd")
const Policy=preload("res://scripts/character_profiles/flow_policy.gd")
const Store=preload("res://scripts/character_profiles/profile_store.gd")
const Fresh=preload("res://scripts/character_profiles/new_gameplay.gd")
var rules:Dictionary={}
var generation:int=0
var pending:Dictionary={}
func inspect() -> Dictionary:
 if DirAccess.dir_exists_absolute(Store.INDEX):return {"screen":"blocked","reason":"Catalogue path is a directory; preserve files"}
 var present=FileAccess.file_exists(Store.INDEX)
 var bytes=FileAccess.get_file_as_bytes(Store.INDEX) if present else PackedByteArray()
 var catalogue={"version":1,"revision":0,"profiles":[]}
 if present:
  var parser=JSON.new()
  if parser.parse(bytes.get_string_from_utf8())!=OK:return {"screen":"blocked","reason":"Unreadable character catalogue; preserve files"}
  catalogue=parser.data
 var legacy=FileAccess.file_exists(Store.LEGACY) or DirAccess.dir_exists_absolute(Store.LEGACY)
 var route=Policy.entry(present,catalogue,legacy,rules)
 if route.screen=="blocked":return route
 route["catalogue"]=catalogue;route["bytes"]=bytes
 return route
func cancel():
 generation+=1;pending.clear()
func create_character(slot:String, appearance:Dictionary, stats:Dictionary, perks:Array, expected_index:PackedByteArray, explicitly_adopt:bool=false) -> Dictionary:
 pending.clear()
 var profile={"version":1,"slot":slot,"rules_id":rules.get("id",""),"appearance":appearance.duplicate(true),"stats":stats.duplicate(true),"perks":perks.duplicate(true),"intro_seen":false}
 var gameplay=FileAccess.get_file_as_bytes(Store.LEGACY) if explicitly_adopt else Fresh.create()
 var result=Store.create(profile,rules,expected_index,gameplay,Fresh.valid,explicitly_adopt)
 if not result.ok:return result
 return select_character(slot)
func select_character(slot:String) -> Dictionary:
 pending.clear()
 var state=inspect()
 if state.screen!="select":return {"ok":false,"reason":"Select a valid saved character first"}
 var path=Model.save_path(slot)
 if path.is_empty() or not FileAccess.file_exists(path) or not Fresh.valid(FileAccess.get_file_as_bytes(path)):return {"ok":false,"reason":"Character save missing or invalid; preserve it"}
 var route=Policy.selected(state.catalogue,slot,int(state.catalogue.revision),rules,true)
 if route.is_empty():return {"ok":false,"reason":"Character selection changed"}
 generation+=1
 var selected_appearance={}
 for profile in state.catalogue.profiles:
  if profile.slot==slot:selected_appearance=profile.appearance.duplicate(true)
 if selected_appearance.is_empty():return {"ok":false,"reason":"Selected appearance unavailable"}
 pending={"generation":generation,"slot":slot,"index":state.bytes,"route":route,"appearance":selected_appearance}
 return {"ok":true,"generation":generation,"route":route.duplicate(true)}
func bind_world(world:Node, token:int) -> bool:
 if pending.is_empty() or token!=generation or token!=pending.generation or not Store.bytes_current(pending.index):return false
 if not is_instance_valid(world) or world.is_queued_for_deletion() or world.is_inside_tree() or not world.has_method("bind_character_slot"):return false
 var path=Model.save_path(pending.slot)
 if not FileAccess.file_exists(path) or not Fresh.valid(FileAccess.get_file_as_bytes(path)):return false
 return world.bind_character_slot(pending.slot,pending.appearance.duplicate(true))
func complete_intro(token:int)->Dictionary:
 if pending.is_empty() or token!=generation or token!=pending.generation:return {"ok":false,"reason":"Launch changed"}
 if pending.route.screen!="intro_then_loading":return {"ok":true}
 var result=Store.mark_intro(pending.index,pending.slot,rules)
 if not result.ok:return result
 pending.index=result.bytes;pending.route.screen="loading"
 return {"ok":true}
