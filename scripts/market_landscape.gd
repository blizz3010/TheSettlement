extends RefCounted
# Candidate-only spatial reconciliation. Never changes source RNG streams, save data,
# species, mesh/material identity, counts, animation timing or per-instance wind phase.
const PATHS = [
 [Vector2(0,10),Vector2(0,15),Vector2(6,17),Vector2(17,12),Vector2(14,0),Vector2(11,-9)],
 [Vector2(17,12),Vector2(31,10),Vector2(31,7)],
 [Vector2(17,12),Vector2(18,19),Vector2(17,29),Vector2(9,30),Vector2(-6,30)],
 [Vector2(17,29),Vector2(27,26),Vector2(31,27)]
]
static func envelopes()->Array[AABB]:
 return [
  AABB(Vector3(27,-2,-1.5),Vector3(8,20,10)), # Psy + SOUTH customer apron.
  AABB(Vector3(18,-2,14.5),Vector3(11,20,7)), # Atlas + west customer apron.
  AABB(Vector3(1,-2,17.5),Vector3(10,20,10)) # Dan + north customer apron.
 ]
static func _segment_rect(a:Vector2,b:Vector2,r:Rect2)->bool:
 var lo=0.0;var hi=1.0;var delta=b-a
 for axis in range(2):
  if absf(delta[axis])<.00001:
   if a[axis]<r.position[axis] or a[axis]>r.end[axis]:return false
  else:
   var t1=(r.position[axis]-a[axis])/delta[axis];var t2=(r.end[axis]-a[axis])/delta[axis]
   lo=maxf(lo,minf(t1,t2));hi=minf(hi,maxf(t1,t2))
   if lo>hi:return false
 return true
static func conflicts(bounds:AABB)->bool:
 for b in envelopes():
  if bounds.intersects(b):return true
 # 4m path plus 0.15m visual/foot clearance. Expanded AABB is conservative at corners.
 var r=Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).grow(2.15)
 for path in PATHS:
  for i in range(path.size()-1):
   if _segment_rect(path[i],path[i+1],r):return true
 return false
static func _source_conflicts(bounds:AABB)->bool:
 # Keep the already-reviewed decoration at its existing destinations after the
 # short Dan reroute. Vacating the old path must not reseed every later relocation.
 # This historical source exclusion affects placement only, not current route/audio tests.
 if conflicts(bounds):return true
 var r=Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).grow(2.15)
 return _segment_rect(Vector2(9,30),Vector2(-6,26),r)
static func _destination_safe(b:AABB)->bool:
 if conflicts(b):return false
 # Future sites remain unassigned and unbuilt; do not use them as relocation dumps.
 for reserve in [AABB(Vector3(-10,-2,32.5),Vector3(8,20,7)),AABB(Vector3(6,-2,34.5),Vector3(8,20,7)),AABB(Vector3(26,-2,29.5),Vector3(8,20,7))]:
  if b.intersects(reserve):return false
 if b.position.x< -44.5 or b.end.x>44.5 or b.position.z< -44.5 or b.end.z>44.5:return false
 if b.intersects(AABB(Vector3(-13,-2,-35),Vector3(26,20,24))):return false
 if preload('res://scripts/hideout_terrace.gd').conflicts(b):return false
 if b.intersects(AABB(Vector3(19.9,-2,-9),Vector3(4.2,20,20.7))):return false
 # Keep existing pad rim and 3m public perimeter apron clear.
 var p=Vector2(clampf(22,b.position.x,b.end.x),clampf(-16,b.position.z,b.end.z))
 if p.distance_to(Vector2(22,-16))<11:return false
 return true
static func _destination(bounds:AABB,origin:Vector3,serial:int)->Vector3:
 for attempt in range(720):
  var angle=(serial*2.399963229728653+attempt*.271)
  var radius=38.0+float((serial+attempt)%11)*.4
  var next=Vector3(cos(angle)*radius,origin.y,sin(angle)*radius)
  var moved=AABB(bounds.position+next-origin,bounds.size)
  if _destination_safe(moved):return next
 assert(false,'No safe deterministic market foliage destination')
 return origin
static func _vec(v:Vector3)->Array:return [v.x,v.y,v.z]
static func _record(journal:Array,node:Node,index:int,old:Vector3,next:Vector3,bounds:AABB):
 journal.append({'node':str(node.get_path()),'instance':index,'from':_vec(old),'to':_vec(next),'original_bounds':{'position':_vec(bounds.position),'size':_vec(bounds.size)}})
static func _multimesh(node:MultiMeshInstance3D,journal:Array):
 var mm=node.multimesh
 var original:Array=node.get_meta('source_transforms',[])
 var current=[]
 for i in range(mm.instance_count):
  var t:Transform3D=original[i] if original.size()==mm.instance_count else mm.get_instance_transform(i)
  var world=node.global_transform*t
  var b=(world*mm.mesh.get_aabb()).grow(.08)
  if _source_conflicts(b):
   var next=_destination(b,world.origin,journal.size())
   _record(journal,node,i,world.origin,next,b)
   world.origin=next;t=node.global_transform.affine_inverse()*world
   mm.set_instance_transform(i,t)
  current.append(t)
 # Update transform authority; color/custom data wind phases remain exactly unchanged.
 if not original.is_empty():node.set_meta('source_transforms',current)
static func _visual_bounds(root:Node3D)->AABB:
 var found=false;var result=AABB()
 for mesh in root.find_children('*','MeshInstance3D',true,false):
  var b=mesh.global_transform*mesh.mesh.get_aabb()
  result=result.merge(b) if found else b;found=true
 assert(found,'Expected foliage mesh under '+str(root.get_path()))
 return result.grow(.08)
static func _root(root:Node3D,journal:Array,companion:Node3D=null):
 var b=_visual_bounds(root)
 if not _source_conflicts(b):return
 var old=root.global_position;var next=_destination(b,old,journal.size())
 _record(journal,root,-1,old,next,b);root.global_position=next
 if companion!=null:companion.global_position+=next-old
static func _transform_record(t:Transform3D)->Dictionary:
 return {'basis_x':_vec(t.basis.x),'basis_y':_vec(t.basis.y),'basis_z':_vec(t.basis.z),'origin':_vec(t.origin)}
static func _reserve_a_clearance(scene:Node3D)->void:
 # Parent-approved exact pair: preserve all original 32 relocation records and RNG.
 var batch=scene.get_node('NaturalBorder/border_shrub_b') as MultiMeshInstance3D
 var transforms:Array=batch.get_meta('source_transforms');var journal=[]
 for spec in [[23,2.5,Vector3(-3.474331,0,38.84494)],[28,3.0,Vector3(-8.099559,0,38.14967)]]:
  var index:int=spec[0];var old:Transform3D=transforms[index]
  assert(old.origin.distance_to(spec[2])<.001,'Reviewed reserve shrub source moved unexpectedly')
  var next=old;next.origin.z+=spec[1]
  var old_bounds=(batch.global_transform*old*batch.multimesh.mesh.get_aabb()).grow(.08)
  var bounds=(batch.global_transform*next*batch.multimesh.mesh.get_aabb()).grow(.08)
  assert(_destination_safe(bounds),'Reserve shrub destination must clear all routes/sites/world bounds')
  batch.multimesh.set_instance_transform(index,next);transforms[index]=next
  journal.append({'reason':'Reserve A south shift clearance','node':str(batch.get_path()),'instance':index,'before':_transform_record(old),'after':_transform_record(next),'before_canopy_wind_bounds':{'position':_vec(old_bounds.position),'size':_vec(old_bounds.size)},'after_canopy_wind_bounds':{'position':_vec(bounds.position),'size':_vec(bounds.size)}})
 batch.set_meta('source_transforms',transforms)
 scene.set_meta('market_reservation_clearance_journal',journal)
static func apply_to(scene:Node3D)->Array:
 assert(not scene.has_meta('market_landscape_applied'),'Market reconciliation must run once')
 var journal=[]
 for name in ['NaturalBorder','SouthernGroundcover','WalkwayPlanting']:
  var holder=scene.get_node_or_null(name)
  if holder!=null:
   for child in holder.get_children():
    if child is MultiMeshInstance3D:_multimesh(child,journal)
 # Terrace decorative batches only, never retaining stone or architectural batching.
 for node in scene.find_children('Base planting *','MultiMeshInstance3D',true,false):_multimesh(node,journal)
 var near=scene.get_node_or_null('ReferenceFoliage')
 if near!=null:
  for i in range(4):
   _root(near.get_node('Tree%d'%i),journal,near.get_node('Trunk%d'%i))
   _root(near.get_node('Shrub%d'%i),journal)
 # Near plaza imported planters are independent root scenes, not a MultiMesh.
 for child in scene.get_children():
  if child is Node3D and ('/planter.glb' in child.scene_file_path or '/planter_fern_variant.glb' in child.scene_file_path):_root(child,journal)
 var animals=scene.get_node_or_null('AmbientWildlife')
 var wildlife_checked=0
 if animals!=null:
  for item in animals.animals:
   var b=AABB(item.points[0]-Vector3(.45,.2,.45),Vector3(.9,1.5,.9))
   for point in item.points:b=b.expand(point-Vector3(.45,.2,.45)).expand(point+Vector3(.45,1.3,.45))
   if _source_conflicts(b):
    var origin:Vector3=item.points[0];var next=_destination(b,origin,journal.size());var delta=next-origin
    _record(journal,item.root,-2,origin,next,b)
    for i in range(item.points.size()):item.points[i]+=delta
    item['market_route_offset']=delta
   wildlife_checked+=1
  animals.advance(0.0)
 _reserve_a_clearance(scene)
 scene.set_meta('market_landscape_journal',journal)
 scene.set_meta('market_landscape_applied',true)
 scene.set_meta('market_wildlife_checked',wildlife_checked)
 return journal
