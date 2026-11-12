extends RefCounted
static func resolve_resource(path:String,guards:Dictionary)->Array:
 if guards.has(path):return [path]
 var remap=path+'.import'
 assert(guards.has(remap),'Dependency lacks guarded remap: '+path)
 var raw=FileAccess.get_file_as_bytes(remap)
 while not raw.is_empty() and raw[-1]==0:raw.resize(raw.size()-1)
 assert(not raw.has(0),'Interior NUL in import metadata')
 var text=raw.get_string_from_utf8()
 var config=ConfigFile.new();assert(config.parse(text)==OK and config.has_section('remap'))
 var result=[]
 for key in config.get_section_keys('remap'):
  if key=='path' or key.begins_with('path.'):
   var target=config.get_value('remap',key)
   assert(target is String and target.begins_with('res://') and guards.has(target),'Unbound dependency target: '+str(target))
   assert(FileAccess.get_sha256(target)==guards[target])
   result.append(target)
 assert(not result.is_empty(),'No loader target in guarded remap: '+path)
 return result
static func verify()->Dictionary:
 var authority=JSON.parse_string(FileAccess.get_file_as_string('res://assets/planting_review/verified-native-foliage.json'))
 var guards:Dictionary=authority.source_sha256;var queue=[];var visited={};var edges=[]
 for path in guards:
  assert(FileAccess.get_sha256(path)==guards[path],'Actual PCK guarded bytes differ: '+path)
  if path.ends_with('.scn') or path.ends_with('.ctex') or path.ends_with('.gdshader'):queue.append(path)
 while not queue.is_empty():
  var path=queue.pop_back()
  if visited.has(path):continue
  visited[path]=true
  assert(ResourceLoader.exists(path),'Guarded resource is not loadable: '+path)
  for declaration in ResourceLoader.get_dependencies(path):
   var parts=str(declaration).split('::');var dependency=parts[parts.size()-1]
   assert(dependency.begins_with('res://'),'Unresolved dependency UID: '+str(declaration))
   var targets=resolve_resource(dependency,guards)
   var uid_check={'registered':false,'fallback_used':true}
   if parts.size()>1 and parts[0].begins_with('uid://'):
    var uid=ResourceUID.text_to_id(parts[0])
    if ResourceUID.has_id(uid):
     var uid_path=ResourceUID.get_id_path(uid)
     assert(uid_path.begins_with('res://'),'Registered UID lacks resource path')
     var uid_targets=resolve_resource(uid_path,guards)
     var a=targets.duplicate();var b=uid_targets.duplicate();a.sort();b.sort()
     assert(a==b,'UID target differs from guarded fallback: '+str(declaration))
     uid_check={'registered':true,'uid':parts[0],'path':uid_path,'targets':uid_targets,'fallback_used':false}
    else:uid_check={'registered':false,'uid':parts[0],'fallback_used':true}
   edges.append({'owner':path,'declaration':str(declaration),'dependency':dependency,'resolved_targets':targets,'uid_check':uid_check})
   for target in targets:
    assert(ResourceLoader.exists(target),'Dependency loader target missing: '+target)
    queue.append(target)
 var report={'status':'ACTUAL_PCK_RECURSIVE_DEPENDENCY_CLOSURE_PASS','guard_count':guards.size(),'visited':visited.keys(),'edges':edges}
 return report
