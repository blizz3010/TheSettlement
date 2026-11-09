extends RefCounted
# ROOTS-ONLY PRODUCTION CANDIDATE. F02/F03 geometry remains deferred, not visually accepted.
# Six original sources and physical collision remain untouched.
const Lake=preload('res://scripts/inn_lake_v088.gd')
const GRID=4.0
const ROOT_BURY=.12
const GROUNDED_SOURCE_IDS=[8,9,11,31]
static func hash_bytes(bytes:PackedByteArray)->String:return bytes.hex_encode().sha256_text()
static func xz(v:Vector3)->Vector2:return Vector2(v.x,v.z)
static func make_index(node:MeshInstance3D,role:String)->Dictionary:
 var rows=[];var bins={};var by_triangle={};var vertices=node.mesh.get_faces();var arrays=node.mesh.surface_get_arrays(0);var ids=arrays[Mesh.ARRAY_INDEX];var colors=arrays[Mesh.ARRAY_COLOR];var indexed=ids!=null and ids.size()>0
 for i in range(0,vertices.size(),3):
  var points=PackedVector3Array();var shades=PackedColorArray()
  for j in 3:
   points.append(node.global_transform*vertices[i+j]);var at=ids[i+j] if indexed else i+j
   shades.append(colors[at] if colors!=null and at<colors.size() else Color.WHITE)
  var a=xz(points[0]);var b=xz(points[1]);var c=xz(points[2]);var determinant=(b-a).cross(c-a)
  if absf(determinant)<.0000001:continue
  var bounds=Rect2(a,Vector2.ZERO).expand(b).expand(c);var id=rows.size()
  by_triangle[i/3]=id
  rows.append({'p':points,'c':shades,'det':determinant,'triangle':i/3,'bounds':bounds})
  for z in range(floori(bounds.position.y/GRID),floori(bounds.end.y/GRID)+1):
   for x in range(floori(bounds.position.x/GRID),floori(bounds.end.x/GRID)+1):
    var key=Vector2i(x,z)
    if not bins.has(key):bins[key]=[]
    bins[key].append(id)
 return {'node':node,'role':role,'rows':rows,'bins':bins,'by_triangle':by_triangle,'mesh':node.mesh,'transform':node.global_transform,'faces_sha256':hash_bytes(vertices.to_byte_array())}
static func weights(p:Vector2,row:Dictionary)->Vector3:
 var a=xz(row.p[0]);var b=xz(row.p[1]);var c=xz(row.p[2]);var v=(p-a).cross(c-a)/row.det;var w=(b-a).cross(p-a)/row.det
 return Vector3(1-v-w,v,w)
static func sample(index:Dictionary,p:Vector2)->Dictionary:
 var result={'found':false,'height':-INF}
 for id in index.bins.get(Vector2i(floori(p.x/GRID),floori(p.y/GRID)),[]):
  var row=index.rows[id];var bary=weights(p,row)
  if bary.x<-.00001 or bary.y<-.00001 or bary.z<-.00001:continue
  var height=row.p[0].y*bary.x+row.p[1].y*bary.y+row.p[2].y*bary.z
  if height>result.height:result={'found':true,'height':height,'color':row.c[0]*bary.x+row.c[1]*bary.y+row.c[2]*bary.z,'row':id,'triangle':row.triangle,'role':index.role}
 return result
static func surface_sample(indices:Array,p:Vector2)->Dictionary:
 var result={'found':false,'height':-INF}
 for index in indices:
  var hit=sample(index,p)
  if hit.found and hit.height>result.height:result=hit
 return result
static func grounded_target(point:Vector3,collar:Dictionary,scenic:Array,shore:Dictionary={})->Dictionary:
 var footprint=xz(point);var hit=sample(collar,footprint)
 if not shore.is_empty():
  var apron=sample(shore,footprint)
  if apron.found and (not hit.found or apron.height>hit.height):hit=apron
 if not hit.found:return {'affected':false}
 var existing=surface_sample(scenic,footprint)
 if existing.found and existing.height>hit.height+.001:return {'affected':false}
 if Lake.lake_distance(footprint)<1:return {'affected':false}
 var next=Vector3(point.x,hit.height-ROOT_BURY,point.z)
 return {'affected':absf(next.y-point.y)>.015,'next':next,'height':hit.height,'triangle':hit.triangle,'owner':hit.role}
static func geometry_plan(world:Node3D)->Dictionary:
 if world.global_transform!=Transform3D.IDENTITY:return {'ok':false,'reason':'Unexpected world transform for lake geometry'}
 var specifications=[['SettlementTerrain/GroundRelief','SettlementTerrain'],['InnLakesideV088/LocalLakeBank','LocalLakeBank'],['InnLakesideV088/ContinuousShoreApron','ContinuousShoreApron'],['ValleyBackdrop/ScenicGroundApron','ScenicGroundApron'],['ValleyBackdrop/MiddleRidge','MiddleRidge'],['ValleyBackdrop/OuterFoothills','OuterFoothills']]
 var indices={};var sources=[]
 for spec in specifications:
  var node=world.get_node_or_null(spec[0])
  if not node is MeshInstance3D or node.mesh==null or node.mesh.get_surface_count()!=1:return {'ok':false,'reason':'Lake join source unavailable: '+spec[0]}
  var index=make_index(node,spec[1]);indices[spec[1]]=index
  sources.append({'path':spec[0],'mesh':node.mesh,'material':node.material_override,'transform':node.global_transform,'visible':node.visible,'faces_sha256':index.faces_sha256})
 var collisions=collision_snapshot(world)
 if not collision_owners_present(collisions):return {'ok':false,'reason':'Both original physical collision owners and shapes required'}
 var scenic=[indices.ScenicGroundApron,indices.MiddleRidge,indices.OuterFoothills]
 var marker=Node3D.new();marker.name='LakeJoinsV096'
 return {'ok':true,'root':marker,'sources':sources,'collar_index':{'bins':{},'rows':[]},'scenic':scenic,'shore_index':indices.ContinuousShoreApron,'collision_snapshot':collisions}
static func collision_snapshot(world:Node3D)->Array:
 var result=[]
 for path in ['SettlementTerrain/WalkableRelief','InnLakesideV088/LocalLakeBankCollision']:
  var owner=world.get_node_or_null(path)
  if not owner is CollisionObject3D:continue
  for node in owner.find_children('*','CollisionShape3D',true,false):
   var properties=[]
   if node.shape!=null:
    for property in node.shape.get_property_list():
     if property.usage&PROPERTY_USAGE_STORAGE:properties.append([property.name,node.shape.get(property.name)])
   result.append({'owner_path':path,'path':str(world.get_path_to(node)),'shape':node.shape,'transform':node.global_transform,'disabled':node.disabled,'body':node.get_parent(),'body_layer':node.get_parent().collision_layer if node.get_parent() is CollisionObject3D else 0,'body_mask':node.get_parent().collision_mask if node.get_parent() is CollisionObject3D else 0,'properties_sha256':hash_bytes(var_to_bytes(properties))})
 return result
static func collision_owners_present(snapshot:Array)->bool:
 for path in ['SettlementTerrain/WalkableRelief','InnLakesideV088/LocalLakeBankCollision']:
  var found=false
  for row in snapshot:
   if row.owner_path==path and row.shape!=null:found=true
  if not found:return false
 return true
static func tree_plan(world:Node3D,geometry:Dictionary)->Dictionary:
 var proposals=[];var journal=[];var source_ids=[]
 var original_journal=world.get_node("ValleyBackdrop").get_meta("approved_forest_journal",[])
 # Inspect only the two final unmarked legacy owners. All approved targets
 # are on the unchanged apron; prior NorthTrees history stays intact.
 for name in ['DistantTree0','DistantTree1']:
  var path='ValleyBackdrop/'+name;var batch=world.get_node_or_null(path)
  if not batch is MultiMeshInstance3D or batch.multimesh==null:return {'ok':false,'reason':'Final scenic tree owner missing: '+path}
  var old:MultiMesh=batch.multimesh
  if old.transform_format!=MultiMesh.TRANSFORM_3D or not old.use_colors or not old.use_custom_data:return {'ok':false,'reason':'Final scenic tree channels changed: '+path}
  var before:PackedFloat32Array=old.buffer;var stride=20
  if before.size()!=old.instance_count*stride or before.is_empty():return {'ok':false,'reason':'Native scenic tree buffers required: '+path}
  var after=before.duplicate();var changes=[];var transforms=[]
  for i in old.instance_count:
   var local:Transform3D=old.get_instance_transform(i);var point=batch.global_transform*local.origin;var target=grounded_target(point,geometry.collar_index,geometry.scenic,geometry.shore_index);transforms.append(local)
   if not target.affected:continue
   var authority=-1
   for record in original_journal:
    if record.source==('border_tree_a' if name=='DistantTree0' else 'border_tree_b') and record.transform.is_equal_approx(local):authority=record.index;break
   if not authority in GROUNDED_SOURCE_IDS:return {'ok':false,'reason':'Unexpected shore-tree source would move: '+str(authority)}
   source_ids.append(authority)
   var next=local;next.origin=batch.to_local(target.next);transforms[i]=next
   after[i*stride+3]=next.origin.x;after[i*stride+7]=next.origin.y;after[i*stride+11]=next.origin.z
   changes.append({'index':i,'original_source_index':authority,'surface_owner':target.owner,'before':local,'after':next,'world_before':point,'world_after':target.next,'surface_height':target.height,'triangle':target.triangle})
  if changes.is_empty():continue
  if not batch.has_meta('instance_transforms'):return {'ok':false,'reason':'Final tree provenance metadata missing: '+path}
  var metadata=batch.get_meta('instance_transforms')
  if not metadata is Array or metadata.size()!=old.instance_count:return {'ok':false,'reason':'Final tree provenance count changed: '+path}
  for i in metadata.size():
   if not metadata[i] is Transform3D or not metadata[i].is_equal_approx(old.get_instance_transform(i)):return {'ok':false,'reason':'Final tree provenance transform changed: '+path}
  var next:MultiMesh=old.duplicate();next.buffer=after
  if next.buffer.to_byte_array()!=after.to_byte_array():return {'ok':false,'reason':'Scenic tree native buffer roundtrip changed'}
  var bounds=old.custom_aabb
  for change in changes:bounds=bounds.merge(change.after*old.mesh.get_aabb())
  next.custom_aabb=bounds
  proposals.append({'batch':batch,'before':old,'after':next,'transforms':transforms,'source_transforms':metadata.duplicate(),'changes':changes})
  journal.append({'path':path,'count':old.instance_count,'visible_prefix':old.visible_instance_count,'source_buffer_sha256':hash_bytes(before.to_byte_array()),'result_buffer_sha256':hash_bytes(after.to_byte_array()),'source_custom_aabb':old.custom_aabb,'result_custom_aabb':next.custom_aabb,'changes':changes})
 source_ids.sort()
 if source_ids!=GROUNDED_SOURCE_IDS:return {'ok':false,'reason':'Expected four shoreline roots differ: '+str(source_ids)}
 return {'ok':true,'proposals':proposals,'journal':journal}
static func apply(world:Node3D)->Dictionary:
 if world.has_meta('lake_joins_v096'):
  if not world.get_meta('lake_joins_v096').get('roots_only',false):return {'ok':false,'reason':'Existing geometry variant cannot be accepted as roots-only'}
  return world.get_meta('lake_joins_v096') if world.has_node('LakeJoinsV096') else {'ok':false,'reason':'Lake join owner disappeared'}
 if world.has_node('LakeJoinsV096'):return {'ok':false,'reason':'Foreign lake join owner'}
 if not world.has_node('NorthTreesStage3') or not world.has_meta('inn_lake_v088'):return {'ok':false,'reason':'Final lake/scenery owners must finish before joins'}
 var geometry=geometry_plan(world)
 if not geometry.ok:return geometry
 var trees=tree_plan(world,geometry)
 if not trees.ok:geometry.root.free();return trees
 if 'startup_cancel_requested' in world and world.startup_cancel_requested:geometry.root.free();return {'ok':false,'reason':'Loading cancelled before lake join commit'}
 for source in geometry.sources:
  var node=world.get_node(source.path)
  if node.mesh!=source.mesh or node.global_transform!=source.transform:geometry.root.free();return {'ok':false,'reason':'Lake source changed during preparation'}
 for proposal in trees.proposals:
  if proposal.batch.multimesh!=proposal.before:geometry.root.free();return {'ok':false,'reason':'Tree source changed during preparation'}
 # No yield or fallible preparation after this complete proposal validation.
 var preimages=[]
 for proposal in trees.proposals:
  preimages.append({'path':str(world.get_path_to(proposal.batch)),'source':proposal.before,'source_transforms':proposal.source_transforms})
  proposal.batch.multimesh=proposal.after;proposal.batch.set_meta('instance_transforms',proposal.transforms)
 world.add_child(geometry.root)
 var result={'ok':true,'roots_only':true,'geometry_added':false,'F02_deferred':true,'F03_deferred':true,'shoreline_visual_accepted':false,'collar_edges':0,'collar_triangles':0,'cap_triangles':0,'collar_journal':[],'collar_end_seals':[],'cap_journal':[],'tree_journal':trees.journal,'cut_contact_normalized_allowance':0.0,'max_cap_contact_error':0.0,'new_colliders':0,'new_lights':0,'new_shadow_casters':0,'essential_all_quality_tiers':true,'source_meshes_unchanged':true,'save_changes':0}
 world.set_meta('lake_joins_v096_evidence',{'sources':geometry.sources,'trees':preimages,'collision_snapshot':geometry.collision_snapshot,'north_tree_history_sha256':hash_bytes(var_to_bytes(world.get_node('NorthTreesStage3').original_records))})
 world.set_meta('lake_joins_v096',result);return result
static func demand(condition:bool,message:String,errors:Array):
 if not condition:errors.append(message)
static func audit(world:Node3D)->Dictionary:
 var errors=[];var observed={}
 if DisplayServer.get_name()=='headless':return {'ok':false,'errors':['Native renderer required for final tree-byte acceptance.']}
 if not world.has_meta('lake_joins_v096') or not world.has_meta('lake_joins_v096_evidence') or not world.has_node('LakeJoinsV096'):return {'ok':false,'errors':['Complete lake join install required.']}
 var result=world.get_meta('lake_joins_v096');var evidence=world.get_meta('lake_joins_v096_evidence');var indices={};var tree_sources={}
 for source in evidence.sources:
  var node=world.get_node_or_null(source.path);demand(node is MeshInstance3D,'Original geometry owner '+source.path,errors)
  if not node is MeshInstance3D:continue
  demand(node.mesh==source.mesh and node.material_override==source.material and node.global_transform==source.transform and node.visible==source.visible,'Original mesh/material/transform/visibility unchanged '+source.path,errors)
  demand(hash_bytes(node.mesh.get_faces().to_byte_array())==source.faces_sha256,'Original geometry bytes unchanged '+source.path,errors)
  var role='SettlementTerrain' if source.path.begins_with('SettlementTerrain/') else str(node.name);indices[role]=make_index(node,role)
 for row in evidence.trees:tree_sources[row.path]=row
 var scenic=[indices.ScenicGroundApron,indices.MiddleRidge,indices.OuterFoothills];var collar_index={'bins':{},'rows':[]};var moved=[]
 demand(evidence.sources.size()==6,'Exactly six original source preimages',errors)
 demand(world.get_node('LakeJoinsV096').get_child_count()==0,'Roots-only marker adds zero geometry or other children',errors)
 demand(result.roots_only and not result.geometry_added and result.collar_triangles==0 and result.cap_triangles==0 and result.collar_journal.is_empty() and result.cap_journal.is_empty(),'Zero added geometry explicitly recorded',errors)
 demand(result.F02_deferred and result.F03_deferred and not result.shoreline_visual_accepted,'F02/F03 explicitly deferred',errors)
 demand(collision_owners_present(evidence.collision_snapshot) and collision_owners_present(collision_snapshot(world)),'Both expected physical collision owner paths present',errors)
 demand(collision_snapshot(world)==evidence.collision_snapshot,'Original physical collision references/properties/transforms unchanged',errors)
 for row in result.tree_journal:
  demand(tree_sources.has(row.path),'Tree preimage exists '+row.path,errors)
  if not tree_sources.has(row.path):continue
  var batch=world.get_node(row.path);var source:MultiMesh=tree_sources[row.path].source;var current:MultiMesh=batch.multimesh;var expected:PackedFloat32Array=source.buffer.duplicate()
  demand(current.instance_count==source.instance_count and current.mesh==source.mesh and current.use_colors==source.use_colors and current.use_custom_data==source.use_custom_data and current.transform_format==source.transform_format,'Tree counts/geometry/channels preserved '+row.path,errors)
  demand(current.visible_instance_count==source.visible_instance_count and current.visible_instance_count==row.visible_prefix,'Tree visible prefix preserved '+row.path,errors)
  demand(hash_bytes(expected.to_byte_array())==row.source_buffer_sha256,'Tree source native hash '+row.path,errors)
  var touched={}
  for change in row.changes:
   demand(not touched.has(change.index),'Unique grounded native index',errors);touched[change.index]=true;moved.append(change.original_source_index)
   demand(source.get_instance_transform(change.index).is_equal_approx(change.before),'Native preimage transform exact',errors)
   var target=grounded_target(change.world_before,collar_index,scenic,indices.ContinuousShoreApron)
   demand(change.surface_owner=='ContinuousShoreApron','Only unchanged original apron supplies root height',errors)
   demand(target.affected and target.next.is_equal_approx(change.world_after) and target.owner==change.surface_owner,'Exact final visible shore owner/root target',errors)
   demand(change.before.basis==change.after.basis and is_equal_approx(change.world_before.x,change.world_after.x) and is_equal_approx(change.world_before.z,change.world_after.z),'Only world-Y root translation',errors)
   expected[change.index*20+3]=change.after.origin.x;expected[change.index*20+7]=change.after.origin.y;expected[change.index*20+11]=change.after.origin.z
  demand(expected.to_byte_array()==current.buffer.to_byte_array() and hash_bytes(current.buffer.to_byte_array())==row.result_buffer_sha256,'All unmodified rows/basis/color/custom bytes preserved '+row.path,errors)
  var metadata=batch.get_meta('instance_transforms')
  demand(metadata.size()==current.instance_count,'Tree provenance count preserved',errors)
  for i in metadata.size():
   demand(metadata[i].is_equal_approx(current.get_instance_transform(i)),'Final native transform metadata '+row.path+':'+str(i),errors)
   if not touched.has(i):demand(metadata[i]==tree_sources[row.path].source_transforms[i],'Unrelated authored tree metadata preserved',errors)
 moved.sort();demand(moved==GROUNDED_SOURCE_IDS,'Exactly four approved root identities moved',errors)
 demand(hash_bytes(var_to_bytes(world.get_node('NorthTreesStage3').original_records))==evidence.north_tree_history_sha256,'Original north-stage tree history unchanged',errors)
 demand(world.get_node('LakeJoinsV096').find_children('*','CollisionObject3D',true,false).is_empty() and world.get_node('LakeJoinsV096').find_children('*','Light3D',true,false).is_empty(),'No new collision or lights',errors)
 observed={'roots_only':true,'added_geometry':0,'F02_deferred':true,'F03_deferred':true,'shoreline_visual_accepted':false,'collar_triangles':result.collar_triangles,'cap_triangles':result.cap_triangles,'grounded_original_source_indices':moved,'original_geometry_and_tree_bytes_verified':errors.is_empty(),'playable_collision_changes':0}
 return {'ok':errors.is_empty(),'errors':errors,'observed':observed}
