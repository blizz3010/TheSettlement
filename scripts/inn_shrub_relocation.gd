extends Node3D
# One explicitly authorized shrub relocation, not a scatter/reconcile pass.
const INDEX=18
const TARGET_XZ=Vector2(11.2,44.8) # Proposed eastern garden, not yet cleared.
const MESH_PATH='res://assets/foliage_wind/border_shrub_b.glb::ArrayMesh_ysb2s'
const EXPECTED_MIN=Vector3(3.73751473426819,1.44746279716492,36.7917900085449)
const EXPECTED_MAX=Vector3(7.36775398254395,3.12485504150391,40.2142143249512)
const RESERVED=[Rect2(-30,9,12,12),Rect2(-10,32.5,8,7),Rect2(6,34.5,8,7),Rect2(26,29.5,8,7),Rect2(2.6,32,3,11.2),Rect2(-9,43.2,18,17)]
var host:Node3D
var batch:MultiMeshInstance3D
var original:MultiMesh
var replacement:MultiMesh
var before_stamp=''
var after_stamp=''
var batch_transform=Transform3D.IDENTITY
var journal={}
static func stamp(mm:MultiMesh)->String:
 if mm==null or mm.mesh==null:return ''
 return var_to_bytes([mm.mesh.get_instance_id(),mm.transform_format,mm.use_colors,mm.use_custom_data,mm.instance_count,mm.visible_instance_count,mm.custom_aabb,mm.physics_interpolation_quality,mm.buffer]).hex_encode().sha256_text()
static func xz(b:AABB)->Rect2:return Rect2(b.position.x,b.position.z,b.size.x,b.size.z)
static func mesh_conflict(mesh:Mesh,t:Transform3D,bounds:AABB)->bool:
 var broad=t*mesh.get_aabb()
 if not broad.intersects(bounds):return false
 # Large meshes use their actual triangles instead of rejecting on whole-world bounds.
 if broad.size.x<=5 and broad.size.z<=5:return true
 var faces=mesh.get_faces()
 if faces.is_empty():return true
 for i in range(0,faces.size()-2,3):
  var face=AABB(t*faces[i],Vector3.ZERO);face=face.expand(t*faces[i+1]);face=face.expand(t*faces[i+2])
  if face.intersects(bounds):return true
 return false
static func fine_lawn(node:Node,world:Node3D,reference:Mesh)->bool:
 if not node is MultiMeshInstance3D or node.get_parent()!=world.get_node_or_null('ContinuousGrass'):return false
 if node.get_parent()==null or node.get_parent().get_parent()!=world or node.get_parent().global_transform!=Transform3D.IDENTITY:return false
 var parts=str(node.name).split('_')
 if parts.size()!=3 or parts[0]!='LawnChunk' or not parts[1].is_valid_int() or not parts[2].is_valid_int():return false
 if node.transform!=Transform3D(Basis.IDENTITY,Vector3(int(parts[1])*10,0,int(parts[2])*10)):return false
 var mm=node.multimesh
 if mm==null or mm.mesh==null or mm.transform_format!=MultiMesh.TRANSFORM_3D or not mm.use_colors or mm.use_custom_data:return false
 if mm.mesh.get_surface_count()!=1 or mm.mesh.surface_get_primitive_type(0)!=Mesh.PRIMITIVE_TRIANGLES:return false
 if var_to_bytes(mm.mesh.surface_get_arrays(0))!=var_to_bytes(reference.surface_get_arrays(0)):return false
 var material=node.material_override
 return material is ShaderMaterial and material.shader!=null and material.shader.resource_path=='res://assets/materials/continuous_blades.gdshader'
func relocate(world:Node3D)->Dictionary:
 if original!=null:return {'ok':false,'reason':'Already attempted'}
 if not is_inside_tree() or is_queued_for_deletion() or get_parent()!=world or global_transform!=Transform3D.IDENTITY:return {'ok':false,'reason':'Relocation controller not owned by this world'}
 if not is_instance_valid(world) or world.is_queued_for_deletion() or not world.is_inside_tree() or world.global_transform!=Transform3D.IDENTITY or not world.world_initialized or (world.staged_startup and not world.world_activated and not world.startup_preparing_assets) or world.startup_cancel_requested:return {'ok':false,'reason':'Inactive world'}
 if world.process_mode==Node.PROCESS_MODE_DISABLED and not world.startup_preparing_assets:return {'ok':false,'reason':'Physics disabled'}
 var found=world.get_node_or_null('NaturalBorder/border_shrub_b')
 if not found is MultiMeshInstance3D:return {'ok':false,'reason':'Wrong shrub batch type'}
 batch=found;host=world
 if not is_instance_valid(batch) or batch.is_queued_for_deletion() or not batch.is_visible_in_tree() or batch.multimesh==null:return {'ok':false,'reason':'Missing shrub batch'}
 var mm=batch.multimesh
 if mm.mesh==null or mm.mesh.resource_path!=MESH_PATH or mm.instance_count<=INDEX or (mm.visible_instance_count>=0 and mm.visible_instance_count<=INDEX):return {'ok':false,'reason':'Unexpected shrub resource/count'}
 var old_local=mm.get_instance_transform(INDEX);var old_world=batch.global_transform*old_local
 var old_bounds=old_world*mm.mesh.get_aabb()
 if old_bounds.position!=EXPECTED_MIN or old_bounds.end!=EXPECTED_MAX:return {'ok':false,'reason':'Surveyed shrub bounds changed','bounds':old_bounds}
 var q=PhysicsRayQueryParameters3D.create(Vector3(TARGET_XZ.x,20,TARGET_XZ.y),Vector3(TARGET_XZ.x,-10,TARGET_XZ.y));q.exclude=[world.player.get_rid()]
 var hit=world.get_world_3d().direct_space_state.intersect_ray(q)
 var ground=world.get_node_or_null('SettlementTerrain/WalkableRelief');var ground_visual=world.get_node_or_null('SettlementTerrain/GroundRelief')
 if hit.is_empty() or hit.collider!=ground or hit.normal.y<.8 or not ground_visual is MeshInstance3D:return {'ok':false,'reason':'Destination lacks expected dry relief support','hit':hit}
 var next=old_world
 next.origin+=Vector3(TARGET_XZ.x-old_bounds.get_center().x,hit.position.y-old_bounds.position.y-.003,TARGET_XZ.y-old_bounds.get_center().z)
 var next_bounds=next*mm.mesh.get_aabb();var padded=next_bounds.grow(.12)
 for r in RESERVED:
  if r.intersects(xz(padded),true):return {'ok':false,'reason':'Destination reservation conflict','reservation':r}
 # Short authored lawn may naturally layer under the shrub; no lawn buffer is changed.
 var lawn_reference=load('res://scripts/continuous_grass.gd').blade_mesh();var lawn_contacts=[]
 # All other foliage remains an obstacle, including original flowers/shrubs.
 for node in world.find_children('*','GeometryInstance3D',true,false):
  if node==ground_visual or not node.is_visible_in_tree() or node.is_queued_for_deletion():continue
  if node is MeshInstance3D and node.mesh!=null:
   if mesh_conflict(node.mesh,node.global_transform,padded):return {'ok':false,'reason':'Destination visual conflict','path':str(world.get_path_to(node))}
  elif node is MultiMeshInstance3D and node.multimesh!=null and node.multimesh.mesh!=null:
   if fine_lawn(node,world,lawn_reference):
    lawn_contacts.append(str(world.get_path_to(node)));continue
   var other=node.multimesh;var count=other.instance_count if other.visible_instance_count<0 else mini(other.instance_count,other.visible_instance_count)
   for i in range(count):
    if node==batch and i==INDEX:continue
    if mesh_conflict(other.mesh,node.global_transform*other.get_instance_transform(i),padded):return {'ok':false,'reason':'Destination foliage conflict','path':str(world.get_path_to(node)),'index':i}
 var shape=BoxShape3D.new();shape.size=padded.size
 var test=PhysicsShapeQueryParameters3D.new();test.shape=shape;test.transform=Transform3D(Basis.IDENTITY,padded.get_center());test.exclude=[world.player.get_rid(),ground.get_rid()]
 var collisions=world.get_world_3d().direct_space_state.intersect_shape(test,1)
 if not collisions.is_empty():return {'ok':false,'reason':'Destination physics conflict','path':str(world.get_path_to(collisions[0].collider))}
 original=mm;before_stamp=stamp(original);batch_transform=batch.global_transform
 replacement=original.duplicate();replacement.set_instance_transform(INDEX,batch.global_transform.affine_inverse()*next)
 after_stamp=stamp(replacement)
 journal={'index':INDEX,'old_world':old_world,'new_world':next,'old_bounds':old_bounds,'new_bounds':next_bounds,'support':hit.position,'support_scope':'Center-root ray only, not full foliage ground contact','mesh':MESH_PATH,'count_unchanged':replacement.instance_count==original.instance_count,'fine_lawn_layering_nodes':lawn_contacts}
 batch.multimesh=replacement
 return {'ok':true,'journal':journal.duplicate(true)}
func restore()->bool:
 if original==null:return true
 if not is_instance_valid(host) or host.is_queued_for_deletion() or not host.is_inside_tree():return false
 if not is_instance_valid(batch) or batch.is_queued_for_deletion() or host.get_node_or_null('NaturalBorder/border_shrub_b')!=batch:return false
 if batch.multimesh!=replacement or batch.global_transform!=batch_transform or stamp(replacement)!=after_stamp or stamp(original)!=before_stamp:return false
 batch.multimesh=original;original=null;replacement=null
 return true
func _exit_tree():
 restore()
