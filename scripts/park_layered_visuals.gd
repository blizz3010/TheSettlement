extends Node3D
## Fixed render-only composition. No terrain sampling, physics, services or save state.
const ASSET="res://assets/park_layered/park_layered_fixed.glb"
const ASSET_SHA256="0a77d1ee22ed9a5b03aed240011e0a3a753d295dc2d3afde919ebfa941f3e264"
const BINDING="res://assets/park_layered/binding.json"
var host
var visual:Node3D
var requested=false
var attempted=false
var disposing=false
var result:Dictionary={"ok":false,"reason":"Not activated"}
func setup(world):
 name="ParkLayeredVisuals";host=world
 set_process(false);set_physics_process(false)
func active_world()->bool:
 return not disposing and not is_queued_for_deletion() and is_inside_tree() and is_instance_valid(host) and host.is_inside_tree() and not host.is_queued_for_deletion() and host.world_initialized and not host.startup_cancel_requested and (not host.staged_startup or host.world_activated or host.startup_preparing_assets)
func begin_after_activation(world):
 if disposing or is_queued_for_deletion() or not is_inside_tree():return
 if is_instance_valid(host) and host!=world:return
 setup(world)
 if requested or attempted or not active_world():return
 requested=true
 var tree=get_tree()
 # Cooking already owns its two-frame support barrier. Wait for its terminal
 # placement decision without changing activation or enabling any world process.
 while active_world():
  if not is_instance_valid(host.cooking_test):
   fail("Cooking lifecycle missing");return
  if host.cooking_test.placement_attempted:break
  await tree.physics_frame
  if not active_world():return
 if not active_world():return
 await tree.physics_frame
 if not active_world():return
 install()
func fail(reason:String)->Dictionary:
 attempted=true;result={"ok":false,"reason":reason};return result
func install()->Dictionary:
 if not active_world():return {"ok":false,"reason":"World inactive"}
 if is_instance_valid(visual):return result
 if attempted:return result
 attempted=true
 if not transform.is_equal_approx(Transform3D.IDENTITY) or not host.global_transform.is_equal_approx(Transform3D.IDENTITY):return fail("World origin changed")
 if not is_instance_valid(host.cooking_test) or not host.cooking_test.placement_attempted or not is_instance_valid(host.cooking_test.station) or not host.cooking_test.clearance.get("ok",false):return fail("Cooking placement context unavailable")
 var plants=host.get_node_or_null("IntentionalPlantingPockets")
 if plants==null or plants.get_meta("budget",{}).get("accepted",0)!=47 or not host.has_node("HallRoutePark"):return fail("Completed park/planting context unavailable")
 if get_node_or_null("ParkLayeredBaked")!=null or host.get_node_or_null("ParkLayeredBaked")!=null:return fail("Foreign park visual exists")
 var contract=JSON.parse_string(FileAccess.get_file_as_string(BINDING))
 if not contract is Dictionary or contract.get("version")!=1 or not contract.get("groups") is Dictionary or contract.groups.size()!=20 or contract.get("triangles")!=18392 or not contract.get("source_scripts") is Dictionary:return fail("Invalid bake binding")
 for path in contract.source_scripts:
  if not path is String or not path.begins_with("scripts/") or not path.ends_with(".gd") or FileAccess.get_sha256("res://"+path)!=contract.source_scripts[path]:return fail("Bake terrain/source binding changed")
 if contract.get("asset_sha256")!=ASSET_SHA256 or not asset_bytes_bound():return fail("Baked asset bytes are not bound")
 var packed=load(ASSET) as PackedScene
 if packed==null:return fail("Baked asset unavailable")
 var instance=packed.instantiate()
 if not instance is Node3D:
  if is_instance_valid(instance):instance.free()
  return fail("Baked root invalid")
 var candidate:Node3D=instance
 var checked=inspect_candidate(candidate,contract)
 if not checked.get("ok",false):candidate.free();return fail(checked.reason)
 if not active_world():candidate.free();return fail("World cancelled before installation")
 candidate.name="ParkLayeredBaked"
 add_child(candidate);visual=candidate
 result={"ok":true,"groups":20,"triangles":18392,"bounds":checked.bounds,"source_bound":true,"visual_only":true}
 return result
static func asset_bytes_bound()->bool:
 if FileAccess.file_exists(ASSET):return FileAccess.get_sha256(ASSET)==ASSET_SHA256
 # Exported scenes have no raw GLB. Require BOTH actual metadata and resolved
 # imported SCN in the independently translated package authority.
 var authority=JSON.parse_string(FileAccess.get_file_as_string("res://assets/planting_review/verified-native-foliage.json"))
 if not authority is Dictionary or not authority.get("source_sha256") is Dictionary:return false
 var guards:Dictionary=authority.source_sha256;var metadata=ASSET+".import"
 if not guards.has(metadata) or FileAccess.get_sha256(metadata)!=guards[metadata]:return false
 var raw=FileAccess.get_file_as_bytes(metadata)
 while not raw.is_empty() and raw[-1]==0:raw.resize(raw.size()-1)
 if raw.is_empty() or raw.has(0):return false
 var config=ConfigFile.new()
 if config.parse(raw.get_string_from_utf8())!=OK or not config.has_section("remap") or config.get_value("remap","type","")!="PackedScene":return false
 var paths=[]
 for key in config.get_section_keys("remap"):
  if key.begins_with("path"):
   if key!="path":return false
   paths.append(config.get_value("remap",key))
 if paths.size()!=1 or not paths[0] is String:return false
 var target:String=paths[0]
 return target.begins_with("res://.godot/imported/") and target.ends_with(".scn") and guards.has(target) and FileAccess.get_sha256(target)==guards[target]
static func inspect_candidate(candidate:Node3D,contract:Dictionary)->Dictionary:
 if candidate==null or not contract.get("groups") is Dictionary or contract.groups.size()!=20:return {"ok":false,"reason":"Invalid group contract"}
 if not candidate.transform.is_equal_approx(Transform3D.IDENTITY):return {"ok":false,"reason":"Baked root transform changed"}
 if not candidate.find_children("*","CollisionObject3D",true,false).is_empty():return {"ok":false,"reason":"Unexpected baked collider"}
 for node in [candidate]+candidate.find_children("*","",true,false):
  if not node is Node3D or node.get_script()!=null or node is Light3D or node is Camera3D or node is AnimationPlayer:return {"ok":false,"reason":"Unexpected scripted/active baked node"}
 if candidate.get_child_count()!=20:return {"ok":false,"reason":"Baked group count changed"}
 var seen={};var bounds={};var triangles=0
 for group in candidate.get_children():
  var key=String(group.name)
  if not group is Node3D or not contract.groups.has(key) or seen.has(key):return {"ok":false,"reason":"Unexpected baked group"}
  seen[key]=true
  var meshes=group.find_children("*","MeshInstance3D",true,false)
  if meshes.size()!=1 or not meshes[0].mesh is ArrayMesh:return {"ok":false,"reason":"Baked mesh count changed"}
  var mesh:MeshInstance3D=meshes[0]
  if mesh.get_parent()!=group:return {"ok":false,"reason":"Baked hierarchy changed"}
  var box:AABB=(group.transform*mesh.transform)*mesh.mesh.get_aabb()
  if not contract.groups[key] is Dictionary:return {"ok":false,"reason":"Malformed group binding"}
  var expected:Dictionary=contract.groups[key]
  if not expected.get("min") is Array or not expected.get("max") is Array or expected.min.size()!=3 or expected.max.size()!=3:return {"ok":false,"reason":"Invalid bound record"}
  for value in expected.min+expected.max:
   if not (value is int or value is float) or not is_finite(float(value)):return {"ok":false,"reason":"Invalid finite bound coordinate"}
  var low=Vector3(expected.min[0],expected.min[1],expected.min[2]);var high=Vector3(expected.max[0],expected.max[1],expected.max[2])
  # Float serialization/import representation only; NOT a clearance tolerance.
  if box.position.distance_to(low)>0.00002 or box.end.distance_to(high)>0.00002:return {"ok":false,"reason":"Baked bounds changed"}
  var count=0
  for surface in range(mesh.mesh.get_surface_count()):
   if mesh.mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:return {"ok":false,"reason":"Unexpected primitive"}
   var indices=mesh.mesh.surface_get_array_index_len(surface)
   var vertices=indices if indices>0 else mesh.mesh.surface_get_array_len(surface)
   if vertices%3!=0:return {"ok":false,"reason":"Malformed triangle array"}
   count+=int(vertices/3)
  if count!=expected.get("triangle_count",-1):return {"ok":false,"reason":"Baked triangle count changed"}
  triangles+=count;bounds[key]={"min":[box.position.x,box.position.y,box.position.z],"max":[box.end.x,box.end.y,box.end.z]}
 if triangles!=18392:return {"ok":false,"reason":"Baked total changed"}
 return {"ok":true,"bounds":bounds}
func _exit_tree():
 disposing=true;host=null
 # The owned visual is a child, never a sibling/orphan. Tree disposal owns it.
