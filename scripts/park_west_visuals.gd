extends Node3D
## Fixed render-only composition. No terrain sampling, physics, services or save state.
const ASSET="res://assets/park_west/west_garden_fixed.glb"
const ASSET_SHA256="81ab9e9f9d7f66378fb4e0e4726fd4ee3eed1242f064dac7b8cf85c3bf967aa7"
const BINDING="res://assets/park_west/binding.json"
var host
var visual:Node3D
var requested=false
var attempted=false
var disposing=false
var result:Dictionary={"ok":false,"reason":"Not activated"}
func setup(world):
 name="ParkWestVisuals";host=world
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
  if not is_instance_valid(host.park_layered_visuals):
   fail("Original20 park lifecycle missing");return
  if host.park_layered_visuals.is_queued_for_deletion() or (not host.park_layered_visuals.requested and not host.park_layered_visuals.attempted):
   fail("Original20 park activation unavailable");return
  if host.cooking_test.placement_attempted and host.park_layered_visuals.attempted:break
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
 if not is_instance_valid(host.park_layered_visuals) or not host.park_layered_visuals.result.get("ok",false):return fail("Original20 park context unavailable")
 var plants=host.get_node_or_null("IntentionalPlantingPockets")
 if plants==null or plants.get_meta("budget",{}).get("accepted",0)!=47 or not host.has_node("HallRoutePark"):return fail("Completed park/planting context unavailable")
 if get_node_or_null("WestGardenBackBaked")!=null or host.get_node_or_null("WestGardenBackBaked")!=null:return fail("Foreign park visual exists")
 var contract=JSON.parse_string(FileAccess.get_file_as_string(BINDING))
 if not contract is Dictionary or contract.get("version")!=1 or not contract.get("groups") is Dictionary or contract.groups.size()!=11 or contract.get("triangles")!=18742 or not contract.get("source_scripts") is Dictionary:return fail("Invalid bake binding")
 for path in contract.source_scripts:
  if not path is String or not path.begins_with("scripts/") or not path.ends_with(".gd") or FileAccess.get_sha256("res://"+path)!=contract.source_scripts[path]:return fail("Bake terrain/source binding changed")
 if contract.get("asset_sha256")!=ASSET_SHA256 or not asset_bytes_bound():return fail("Baked asset bytes are not bound")
 if not contract.get("retained_shrub") is Dictionary:return fail("Malformed retained shrub binding")
 if contract.get("shader_sha256")!="54c5451f612d1d1e2d7a7495b5dc4e3a864404e39e68f214fb1fccd463c36437":return fail("Unreviewed edge shader")
 var identity=retained_shrub_bound(host,contract.retained_shrub)
 if not identity.get("ok",false):return fail(identity.reason)
 var packed=load(ASSET) as PackedScene
 if packed==null:return fail("Baked asset unavailable")
 var instance=packed.instantiate()
 if not instance is Node3D:
  if is_instance_valid(instance):instance.free()
  return fail("Baked root invalid")
 var candidate:Node3D=instance
 var checked=inspect_candidate(candidate,contract)
 if not checked.get("ok",false):candidate.free();return fail(checked.reason)
 var material=preload("res://scripts/park_west_edge_material.gd").prepare(candidate,load("res://assets/route_limestone_candidate.gdshader"),contract.get("shader_sha256",""))
 if not material.get("ok",false):candidate.free();return fail(material.reason)
 if not active_world():candidate.free();return fail("World cancelled before installation")
 candidate.name="WestGardenBackBaked"
 add_child(candidate);visual=candidate
 result={"ok":true,"groups":11,"plant_groups":10,"edge_triangles":62,"triangles":18742,"bounds":checked.bounds,"source_bound":true,"visual_only":true}
 return result
static func asset_bytes_bound()->bool:return asset_path_bound(ASSET,ASSET_SHA256)
static func asset_path_bound(asset_path:String,expected_raw_sha:String)->bool:
 if FileAccess.file_exists(asset_path):return FileAccess.get_sha256(asset_path)==expected_raw_sha
 # Exported scenes have no raw GLB. Require BOTH actual metadata and resolved
 # imported SCN in the independently translated package authority.
 var authority=JSON.parse_string(FileAccess.get_file_as_string("res://assets/planting_review/verified-native-foliage.json"))
 if not authority is Dictionary or not authority.get("source_sha256") is Dictionary:return false
 var guards:Dictionary=authority.source_sha256;var metadata=asset_path+".import"
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
 if candidate==null or not contract.get("groups") is Dictionary or contract.groups.size()!=11:return {"ok":false,"reason":"Invalid group contract"}
 if not candidate.transform.is_equal_approx(Transform3D.IDENTITY):return {"ok":false,"reason":"Baked root transform changed"}
 if not candidate.find_children("*","CollisionObject3D",true,false).is_empty():return {"ok":false,"reason":"Unexpected baked collider"}
 for node in [candidate]+candidate.find_children("*","",true,false):
  if not node is Node3D or node.get_script()!=null or node is Light3D or node is Camera3D or node is AnimationPlayer:return {"ok":false,"reason":"Unexpected scripted/active baked node"}
 if candidate.get_child_count()!=11:return {"ok":false,"reason":"Baked group count changed"}
 var seen={};var bounds={};var triangles=0
 for group in candidate.get_children():
  var key=String(group.name)
  if not group is Node3D or not contract.groups.has(key) or seen.has(key):return {"ok":false,"reason":"Unexpected baked group"}
  seen[key]=true
  var meshes=group.find_children("*","MeshInstance3D",true,false)
  if meshes.size()!=(31 if key=="FlushStoneEdge" else 1):return {"ok":false,"reason":"Baked mesh count changed"}
  var box:AABB;var first=true
  for node in meshes:
   if not node.mesh is ArrayMesh or node.get_parent()!=group:return {"ok":false,"reason":"Baked hierarchy changed"}
   var part:AABB=(group.transform*node.transform)*node.mesh.get_aabb()
   box=part if first else box.merge(part);first=false
  if not contract.groups[key] is Dictionary:return {"ok":false,"reason":"Malformed group binding"}
  var expected:Dictionary=contract.groups[key]
  if not expected.get("min") is Array or not expected.get("max") is Array or expected.min.size()!=3 or expected.max.size()!=3:return {"ok":false,"reason":"Invalid bound record"}
  for value in expected.min+expected.max:
   if not (value is int or value is float) or not is_finite(float(value)):return {"ok":false,"reason":"Invalid finite bound coordinate"}
  var low=Vector3(expected.min[0],expected.min[1],expected.min[2]);var high=Vector3(expected.max[0],expected.max[1],expected.max[2])
  # Float serialization/import representation only; NOT a clearance tolerance.
  if box.position.distance_to(low)>0.00002 or box.end.distance_to(high)>0.00002:return {"ok":false,"reason":"Baked bounds changed"}
  var count=0
  for mesh in meshes:
   for surface in range(mesh.mesh.get_surface_count()):
    if mesh.mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:return {"ok":false,"reason":"Unexpected primitive"}
    var indices=mesh.mesh.surface_get_array_index_len(surface)
    var vertices=indices if indices>0 else mesh.mesh.surface_get_array_len(surface)
    if vertices%3!=0:return {"ok":false,"reason":"Malformed triangle array"}
    count+=int(vertices/3)
  if count!=expected.get("triangle_count",-1):return {"ok":false,"reason":"Baked triangle count changed"}
  triangles+=count;bounds[key]={"min":[box.position.x,box.position.y,box.position.z],"max":[box.end.x,box.end.y,box.end.z]}
 if triangles!=18742:return {"ok":false,"reason":"Baked total changed"}
 return {"ok":true,"bounds":bounds}
func _exit_tree():
 disposing=true;host=null
 # The owned visual is a child, never a sibling/orphan. Tree disposal owns it.

static func digest(value)->String:return var_to_bytes(value).hex_encode().sha256_text()
static func retained_shrub_bound(world:Node3D,expected:Dictionary)->Dictionary:
 if expected.get("path")!="NaturalBorder/border_shrub_b" or expected.get("instance")!=7:return {"ok":false,"reason":"Retained shrub contract changed"}
 var holder=world.get_node_or_null("NaturalBorder")
 if holder==null:return {"ok":false,"reason":"NaturalBorder missing"}
 var wanted=expected.get("bounds",[])
 if not wanted is Array or wanted.size()!=4:return {"ok":false,"reason":"Malformed retained footprint"}
 for n in wanted:
  if not (n is int or n is float) or not is_finite(float(n)):return {"ok":false,"reason":"Malformed retained coordinate"}
 var matches=[]
 for batch in holder.find_children("*","MultiMeshInstance3D",true,false):
  if not String(batch.name).begins_with("border_shrub_") or batch.multimesh==null or batch.multimesh.mesh==null:continue
  for i in range(batch.multimesh.instance_count):
   var box=(batch.global_transform*batch.multimesh.get_instance_transform(i))*batch.multimesh.mesh.get_aabb()
   var actual=[box.position.x,box.position.z,box.end.x,box.end.z];var same=true
   for k in range(4):
    if absf(actual[k]-float(wanted[k]))>.00002:same=false
   if same:matches.append([batch,i])
 if matches.size()!=1:return {"ok":false,"reason":"Retained shrub identity ambiguous or missing"}
 var batch:MultiMeshInstance3D=matches[0][0];var index:int=matches[0][1]
 if str(world.get_path_to(batch))!=expected.path or index!=int(expected.instance):return {"ok":false,"reason":"Retained shrub identity changed"}
 if digest(batch.multimesh.get_instance_transform(index))!=expected.get("transform_sha") or not retained_buffer_bound(batch.multimesh.buffer,expected.get("batch_buffer_sha")) or digest(batch.multimesh.mesh.get_faces())!=expected.get("mesh_faces_sha"):return {"ok":false,"reason":"Retained shrub geometry changed"}
 if FileAccess.get_sha256("res://scripts/natural_border.gd")!=expected.get("source_script_sha"):return {"ok":false,"reason":"Retained shrub source changed"}
 if not expected.get("source_asset_sha") is String or not asset_path_bound("res://assets/kit/border_shrub_b.glb",expected.source_asset_sha):return {"ok":false,"reason":"Retained shrub asset unbound"}
 return {"ok":true,"path":expected.path,"instance":index}

# Godot 4.7 Windows produces one float32 ULP less in the cosine diagonal
# of unrelated shrub6. Both complete buffers were captured and compared.
# Normalize ONLY those two exact values; all other880-buffer content remains
# protected by the original canonical SHA. Never accepts an inn relocation.
static func retained_buffer_bound(buffer:PackedFloat32Array,expected:Variant)->bool:
 if digest(buffer)==expected:return true
 if expected!='8b91e33c0c8b4d80eb9f586bef895b0781990e9028cb5d7b80d9ba9fc6e862a9' or buffer.size()!=880:return false
 const WINDOWS_DIAGONAL=0.368681848049163818359375
 const CANONICAL_DIAGONAL=0.3686818778514862060546875
 if buffer[120]!=WINDOWS_DIAGONAL or buffer[130]!=WINDOWS_DIAGONAL:return false
 var canonical=buffer.duplicate()
 canonical[120]=CANONICAL_DIAGONAL;canonical[130]=CANONICAL_DIAGONAL
 return digest(canonical)==expected
