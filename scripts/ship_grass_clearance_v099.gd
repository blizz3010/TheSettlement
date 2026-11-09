extends RefCounted
# S01 footprint slice. Copy raw rows exactly; dummy/headless renderers do not
# implement get_instance_transform reliably for loaded MultiMeshes.
static func transform_at(raw:PackedFloat32Array,i:int,stride:int)->Transform3D:
 var k=i*stride
 return Transform3D(Basis(Vector3(raw[k],raw[k+4],raw[k+8]),Vector3(raw[k+1],raw[k+5],raw[k+9]),Vector3(raw[k+2],raw[k+6],raw[k+10])),Vector3(raw[k+3],raw[k+7],raw[k+11]))
static func polygons(world:Node3D)->Array:
 var ship=world.get_node_or_null('LaunchpadShip');var approach=world.get_node_or_null('LaunchpadApproach')
 if ship==null or approach==null:return []
 var bodies=approach.get_children();bodies.append(ship.get_node('Collision/ApproachStub'))
 var ramp=ship.get_node_or_null('Collision/Accessible solid ramp')
 if ramp==null:return []
 bodies.append(ramp)
 var result=[]
 for body in bodies:
  if not body is StaticBody3D or body.get_child_count()==0:continue
  var col=body.get_child(0) as CollisionShape3D
  if col==null:return []
  var points=PackedVector2Array()
  if col.shape is BoxShape3D:
   var half=col.shape.size*.5
   for x in [-half.x,half.x]:
    for z in [-half.z,half.z]:
     var p=world.global_transform.affine_inverse()*col.global_transform*Vector3(x,0,z);points.append(Vector2(p.x,p.z))
  elif col.shape is ConvexPolygonShape3D:
   for local in col.shape.points:
    var p=world.global_transform.affine_inverse()*col.global_transform*local;points.append(Vector2(p.x,p.z))
  else:return []
  result.append(Geometry2D.convex_hull(points))
 return result
static func intersects(bounds:AABB,polys:Array,wind:float)->bool:
 var r=Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).grow(wind+.015)
 var rect=PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
 for poly in polys:
  if not Geometry2D.intersect_polygons(rect,poly).is_empty():return true
 return false
static func key(p:Vector3)->String:return '%d:%d:%d'%[roundi(p.x*10000),roundi(p.y*10000),roundi(p.z*10000)]
static func prepare(world:Node3D)->Dictionary:
 var polys=polygons(world)
 if polys.size()!=5:return {'ok':false,'reason':'Expected three connectors, stub and ramp footprints'}
 var candidates=[];var rejected_positions={};var region=Rect2(polys[0][0],Vector2.ZERO)
 for poly in polys:
  for p in poly:region=region.expand(p)
 for batch in world.find_children('*','MultiMeshInstance3D',true,false):
  var label=str(batch.name).to_lower()
  if not ('grass' in label or label.begins_with('lawnchunk_') or label.begins_with('groundnear_') or label.begins_with('groundfar_')):continue
  var old=batch.multimesh
  if old==null or old.mesh==null or old.instance_count==0:continue
  var raw=old.buffer;var stride=12+(4 if old.use_colors else 0)+(4 if old.use_custom_data else 0)
  if old.transform_format!=MultiMesh.TRANSFORM_3D or raw.size()!=old.instance_count*stride:return {'ok':false,'reason':'Unsupported grass buffer '+str(batch.name)}
  var xform=world.global_transform.affine_inverse()*batch.global_transform;var keys=[];var touched=false
  var wind=0.0;var material=batch.material_override as ShaderMaterial
  if material!=null and material.shader!=null and 'wind_strength' in material.shader.code:
   var strength=material.get_shader_parameter('wind_strength')
   if strength==null or not strength is float:return {'ok':false,'reason':'Unresolved wind bound'}
   wind=absf(strength)
  for i in old.instance_count:
   var t=xform*transform_at(raw,i,stride);var identity=key(t.origin);keys.append(identity)
   var bounds=t*old.mesh.get_aabb()
   if not region.intersects(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).grow(wind+.015)):continue
   touched=true
   if intersects(bounds,polys,wind):rejected_positions[identity]=true
  if touched:candidates.append({'node':batch,'old':old,'raw':raw,'stride':stride,'keys':keys,'transform':batch.global_transform,'wind':wind})
 var records=[];var total=0
 for row in candidates:
  var kept=PackedFloat32Array();var indices=[];var rejected=[];var shown=0
  for i in row.old.instance_count:
   if rejected_positions.has(row.keys[i]):rejected.append(i);continue
   kept.append_array(row.raw.slice(i*row.stride,(i+1)*row.stride));indices.append(i)
   if row.old.visible_instance_count<0 or i<row.old.visible_instance_count:shown+=1
  if rejected.is_empty():continue
  var next=MultiMesh.new();next.transform_format=row.old.transform_format;next.use_colors=row.old.use_colors;next.use_custom_data=row.old.use_custom_data;next.mesh=row.old.mesh;next.custom_aabb=row.old.custom_aabb;next.instance_count=indices.size()
  if not kept.is_empty():next.buffer=kept
  next.visible_instance_count=-1 if row.old.visible_instance_count<0 else shown
  if next.buffer.to_byte_array()!=kept.to_byte_array():return {'ok':false,'reason':'Grass row-copy readback failed '+str(row.node.name)+' expected '+str(kept.size())+' actual '+str(next.buffer.size())}
  row.next=next;row.output_buffer=kept;row.retained=indices;row.rejected=rejected;row.metadata=row.node.get_meta('source_transforms') if row.node.has_meta('source_transforms') else null
  if row.metadata!=null and row.metadata.size()!=row.old.instance_count:return {'ok':false,'reason':'Source transform authority length mismatch'}
  records.append(row);total+=rejected.size()
 return {'ok':true,'records':records,'polygons':polys,'removed':total}
static func commit(world:Node3D,plan:Dictionary)->Dictionary:
 if not plan.get('ok',false):return plan
 for row in plan.records:
  if not is_instance_valid(row.node) or row.node.multimesh!=row.old or row.old.buffer!=row.raw or row.node.global_transform!=row.transform:return {'ok':false,'reason':'Grass source changed before commit'}
 for row in plan.records:
  row.node.multimesh=row.next
  if row.metadata!=null:
   var retained=[]
   for i in row.retained:retained.append(row.metadata[i])
   row.node.set_meta('source_transforms',retained)
 world.set_meta('ship_grass_source_receipt_v099',plan)
 var result={'ok':true,'changed_batches':plan.records.size(),'removed_instances':plan.removed,'footprints':plan.polygons,'original_resources_retained':true,'near_far_shared_rejection':true,'terrain_changed':false}
 world.set_meta('ship_grass_clearance_v099',result);return result
static func restore(world:Node3D)->Dictionary:
 if not world.has_meta('ship_grass_source_receipt_v099'):return {'ok':false,'reason':'No receipt'}
 var plan=world.get_meta('ship_grass_source_receipt_v099')
 for row in plan.records:
  if not is_instance_valid(row.node) or row.node.multimesh!=row.next or row.next.buffer!=row.output_buffer or row.old.buffer!=row.raw:return {'ok':false,'reason':'Current grass ownership or retained source changed'}
 for row in plan.records:
  row.node.multimesh=row.old
  if row.metadata!=null:row.node.set_meta('source_transforms',row.metadata)
 world.remove_meta('ship_grass_source_receipt_v099');world.remove_meta('ship_grass_clearance_v099')
 return {'ok':true}
static func apply(world:Node3D)->Dictionary:
 if world.has_meta('ship_grass_clearance_v099'):return world.get_meta('ship_grass_clearance_v099')
 return commit(world,prepare(world))
