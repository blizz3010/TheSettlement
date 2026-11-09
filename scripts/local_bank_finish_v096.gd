extends RefCounted
# F05/V01/V02: material-only lawn/tree finish; subtractive shoreline gaps.
# Invoke after terrain and NorthTreesStage3 have completed. Never rebuild RNG.
const GROUND=preload('res://shaders/rook_ground_finish_v096.gdshader')
const LEAVES=preload('res://shaders/north_transition_v096.gdshader')
const GAPS=[Vector2(-33,-30),Vector2(-24,-20),Vector2(-13,-9),Vector2(-2,2),Vector2(8,12),Vector2(20,24),Vector2(29,32)]
static func in_gap(bank:Node,p:Vector3)->bool:
 # Only the original tiny shoreline stones, never the five field anchors.
 if bank.shoreline(p.x)-p.z>1.5:return false
 for gap in GAPS:
  if p.x>gap.x and p.x<gap.y:return true
 return false
static func digest(mm:MultiMesh)->String:
 if mm.instance_count==0:return 'empty:0'
 var ctx=HashingContext.new();ctx.start(HashingContext.HASH_SHA256);ctx.update(mm.buffer.to_byte_array());return ctx.finish().hex_encode()
static func material_copy(source:ShaderMaterial,shader:Shader)->ShaderMaterial:
 var next=source.duplicate() as ShaderMaterial
 next.shader=shader
 # Explicit copy is important: do not silently drop wind/study/stream controls.
 for entry in source.shader.get_shader_uniform_list():
  next.set_shader_parameter(entry.name,source.get_shader_parameter(entry.name))
 return next
static func source_preflight(bank:Node,north:Node)->Dictionary:
 if bank==null or north==null:return {'ok':false,'reason':'Final bank and marked trees required'}
 if bank.get_script()!=load('res://scripts/riverbank_stage1_v094.gd') or north.get_script()!=load('res://scripts/north_trees_stage3_v094.gd'):return {'ok':false,'reason':'Unexpected source scripts'}
 if bank.audit.has('local_finish_v096'):return {'ok':false,'reason':'Source already carries an unowned finish'}
 var counts={'rock':0,'grass':0};var seen={};var originals=0;var selected=0
 for batch in bank.batches:
  if not is_instance_valid(batch) or batch.get_parent()!=bank or batch.multimesh==null:return {'ok':false,'reason':'Invalid bank owner'}
  var kind=str(batch.get_meta('bank_kind',''));var key=str(batch.name).trim_prefix('Bank_');var mm:MultiMesh=batch.multimesh
  if seen.has(key) or not bank.groups.has(key) or not batch.has_meta('source_transforms'):return {'ok':false,'reason':'Missing or duplicate bank authority'}
  seen[key]=true
  var source=batch.get_meta('source_transforms')
  if not source is Array or source!=bank.groups[key] or source.size()!=mm.instance_count or mm.mesh!=bank.meshes.get(kind):return {'ok':false,'reason':'Bank source metadata mismatch'}
  if kind in counts:counts[kind]+=mm.instance_count
  if kind=='rock':
   if mm.instance_count==0 or mm.transform_format!=MultiMesh.TRANSFORM_3D or mm.use_colors or mm.use_custom_data or mm.visible_instance_count not in [-1,mm.instance_count] or batch.material_override!=null:return {'ok':false,'reason':'Unsupported rock channels, prefix, or material'}
 for kind in counts:
  if counts[kind]!=(131 if kind=='rock' else 5600) or bank.audit.get('counts',{}).get(kind,-1)!=counts[kind]:return {'ok':false,'reason':'Unexpected source '+kind+' count'}
 if seen.size()!=bank.groups.size():return {'ok':false,'reason':'Unowned source group'}
 for batch in north.batches:
  if not str(batch.name).begins_with('NorthOriginal'):continue
  if batch.get_parent()!=north or batch.multimesh==null or not batch.material_override is ShaderMaterial:return {'ok':false,'reason':'Invalid marked-tree owner'}
  if batch.material_override.shader!=load('res://shaders/north_leaves_v094.gdshader'):return {'ok':false,'reason':'Unexpected marked-tree shader'}
  var records=batch.get_meta('source_records',[])
  if not records is Array or records.size()!=batch.multimesh.instance_count or not batch.multimesh.use_colors or not batch.multimesh.use_custom_data:return {'ok':false,'reason':'Marked-tree instance authority mismatch'}
  selected+=batch.multimesh.instance_count;originals+=1
 if originals!=2 or selected!=19:return {'ok':false,'reason':'Expected two marked-tree material owners'}
 if north.audit.get('original_trees_retained',-1)!=56 or north.audit.get('refined_original_trees',-1)!=19 or north.audit.get('untouched_outside_trees',-1)!=37:return {'ok':false,'reason':'Tree provenance mismatch'}
 return {'ok':true}
static func retained_bytes(before:MultiMesh,after:MultiMesh,indices:Array)->bool:
 if before.instance_count<=0 or after.instance_count!=indices.size():return false
 for mm in [before,after]:
  if mm.transform_format!=MultiMesh.TRANSFORM_3D or mm.use_colors or mm.use_custom_data or mm.visible_instance_count not in [-1,mm.instance_count]:return false
 # GLES reports errors for reads of empty instance buffers. Empty witnesses are
 # structural only; do not access after.buffer, even for its size.
 if indices.is_empty():return after.instance_count==0
 for index in indices:
  if index<0 or index>=before.instance_count:return false
 var old_bytes=before.buffer.to_byte_array();var next_bytes=after.buffer.to_byte_array()
 if old_bytes.size()!=before.instance_count*48 or next_bytes.size()!=indices.size()*48:return false
 for i in indices.size():
  if indices[i]<0 or indices[i]>=before.instance_count:return false
  if next_bytes.slice(i*48,(i+1)*48)!=old_bytes.slice(indices[i]*48,(indices[i]+1)*48):return false
 return true
static func apply(world:Node3D)->Dictionary:
 if world.has_meta('local_bank_finish_v096'):return world.get_meta('local_bank_finish_v096')
 var bank=world.get_node_or_null('NorthRiverbankStage1')
 var north=world.get_node_or_null('NorthTreesStage3')
 var preflight=source_preflight(bank,north)
 if not preflight.ok:return preflight
 var guards=[];var materials=[];var rocks=[];var removed=0;var original_rocks=0
 for batch in bank.batches:
  if batch.get_meta('bank_kind','')!='rock':
   guards.append({'node':batch,'digest':digest(batch.multimesh),'mesh':batch.multimesh.mesh});continue
  var old:MultiMesh=batch.multimesh;var kept=[];var indices=[]
  for i in old.instance_count:
   original_rocks+=1
   var t=old.get_instance_transform(i)
   if not t.is_equal_approx(batch.get_meta('source_transforms')[i]):return {'ok':false,'reason':'Native source transform differs from authority'}
   if in_gap(bank,t.origin):removed+=1
   else:kept.append(t);indices.append(i)
  var next=old.duplicate() as MultiMesh;next.instance_count=kept.size();next.visible_instance_count=-1 if old.visible_instance_count==-1 else kept.size();var bounds=AABB()
  for i in kept.size():
   next.set_instance_transform(i,kept[i]);var box=kept[i]*next.mesh.get_aabb();bounds=box if i==0 else bounds.merge(box)
  next.custom_aabb=bounds.grow(.06) if not kept.is_empty() else AABB()
  if not retained_bytes(old,next,indices):return {'ok':false,'reason':'Native retained rock bytes differ before commit'}
  rocks.append({'node':batch,'before':old,'after':next,'kept':kept,'indices':indices,'source_metadata':batch.get_meta('source_transforms'),'range_before':batch.visibility_range_end})
 for batch in north.batches:
  guards.append({'node':batch,'digest':digest(batch.multimesh),'mesh':batch.multimesh.mesh})
  if not str(batch.name).begins_with('NorthOriginal'):continue
  if not batch.material_override is ShaderMaterial:return {'ok':false,'reason':'Unexpected marked-tree material'}
  var source:ShaderMaterial=batch.material_override
  if source.shader.resource_path!='res://shaders/north_leaves_v094.gdshader':return {'ok':false,'reason':'Unreviewed marked-tree shader'}
  materials.append({'node':batch,'before':source,'after':material_copy(source,LEAVES)})
 # Retain exact signatures of the original unmarked forest and distant batches.
 for path in ['ValleyBackdrop','DistantValleyV093','NorthWoodlandStage2']:
  var holder=world.get_node_or_null(path)
  if holder!=null:
   for batch in holder.find_children('*','MultiMeshInstance3D',true,false):
    guards.append({'node':batch,'digest':digest(batch.multimesh),'mesh':batch.multimesh.mesh})
 var ground_count=0
 for node in world.find_children('*','MeshInstance3D',true,false):
  var source=node.material_override as ShaderMaterial
  if source==null or source.shader==null or source.shader.resource_path!='res://assets/materials/continuous_lawn.gdshader':continue
  var bounds=node.global_transform*node.get_aabb()
  if not Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).intersects(Rect2(20,29,24,24)):continue
  materials.append({'node':node,'before':source,'after':material_copy(source,GROUND),'mesh':node.mesh});ground_count+=1
 if ground_count==0 or removed!=44 or original_rocks!=131:return {'ok':false,'reason':'Local material/rock owners missing'}
 for row in materials:
  for entry in row.before.shader.get_shader_uniform_list():
   if row.before.get_shader_parameter(entry.name)!=row.after.get_shader_parameter(entry.name):return {'ok':false,'reason':'Source uniform copy failed'}
 # All validation precedes the atomic commit; source assets remain available.
 for row in rocks:
  row.node.multimesh=row.after;row.node.set_meta('source_transforms',row.kept)
  row.node.visibility_range_end=bank.RANGE[bank.quality]+row.after.custom_aabb.size.length()*.5+3.0
 for row in materials:row.node.material_override=row.after
 # Preserve original generation records as provenance. Runtime rendered rock
 # records live in this explicit finish journal, not a falsely re-seeded builder.
 var result={'ok':true,'ground_material_owners':ground_count,'rocks_before':original_rocks,'rocks_removed':removed,'rocks_after':original_rocks-removed,'grass_transforms_unchanged':true,'tree_instance_channels_unchanged':true,'new_geometry':0,'collision_changes':0,'grass_added':0,'native_visual_pass':false}
 world.set_meta('local_bank_finish_v096_guards',{'guards':guards,'materials':materials,'rocks':rocks})
 world.set_meta('local_bank_finish_v096',result)
 bank.audit['local_finish_v096']={'rendered_rocks':original_rocks-removed,'source_rocks':original_rocks,'removed_for_gaps':removed}
 var verified=check(world)
 if not verified.ok:
  for row in rocks:
   row.node.multimesh=row.before;row.node.set_meta('source_transforms',row.source_metadata);row.node.visibility_range_end=row.range_before
  for row in materials:row.node.material_override=row.before
  world.remove_meta('local_bank_finish_v096_guards');world.remove_meta('local_bank_finish_v096');bank.audit.erase('local_finish_v096')
  return {'ok':false,'reason':'Postcommit verification failed; original state restored','errors':verified.errors}
 return result
static func check(world:Node3D)->Dictionary:
 var errors=[];var data=world.get_meta('local_bank_finish_v096_guards',{})
 if data.is_empty():return {'ok':false,'errors':['Finish not applied']}
 for row in data.guards:
  if digest(row.node.multimesh)!=row.digest or row.node.multimesh.mesh!=row.mesh:errors.append('Unrelated instance data changed: '+str(row.node.name))
 for row in data.materials:
  if row.node.material_override!=row.after:errors.append('Material ownership changed')
  if row.has('mesh') and row.node.mesh!=row.mesh:errors.append('Ground geometry changed')
  for entry in row.before.shader.get_shader_uniform_list():
   if row.before.get_shader_parameter(entry.name)!=row.after.get_shader_parameter(entry.name):errors.append('Source uniform lost: '+str(entry.name))
 for row in data.rocks:
  if row.node.multimesh!=row.after:errors.append('Rock resource ownership changed')
  if row.node.get_meta('source_transforms',[])!=row.kept:errors.append('Rock metadata changed')
  if row.node.multimesh.instance_count!=row.indices.size():errors.append('Rock count changed')
  if not retained_bytes(row.before,row.node.multimesh,row.indices):errors.append('Retained rock bytes changed')
 return {'ok':errors.is_empty(),'errors':errors,'scope':'material-only Rook lawn / nearest marked tree palette; subtractive bank gaps','native_visual_pass':false}
