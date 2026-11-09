extends RefCounted
# v052: semantic pedestrian routes only; never retint building floors/plaza tiles.
# Runs after legacy reconciliation, BEFORE terrain grounding and short grass.
const FOOTPRINT=preload('res://scripts/market_expansion.gd')
const BASE_Y=-.05
const CLEARANCE=.12 # Includes the existing .05m leaf-wind envelope.
static func rect(x:float,z:float,w:float,d:float)->PackedVector2Array:
 return PackedVector2Array([Vector2(x,z),Vector2(x+w,z),Vector2(x+w,z+d),Vector2(x,z+d)])
static func routes(scene:Node3D)->Array:
 var result=[rect(-3.5,-21,7,18),rect(-24,-6.5,24,5)]
 # Keep plaza material/geometry intact, but never relocate bushes onto its walk area.
 var circle=PackedVector2Array()
 for i in range(64):circle.append(Vector2(cos(i*TAU/64),sin(i*TAU/64))*10)
 result.append(circle)
 for mesh in scene.get_node('HallSurroundPaths').find_children('*','MeshInstance3D',true,false):
  result.append(FOOTPRINT.paving_footprint(mesh.mesh,mesh.global_transform))
 result.append_array(scene.get_node('MarketExpansion').get_meta('paving_polygons'))
 result.append_array(scene.get_node('ApproachPathFinish').get_meta('footprints'))
 for c in scene.get_node('RaisedHideoutTerrace').find_children('*','CollisionShape3D',true,false):
  var b:AABB=c.global_transform*c.shape.get_debug_mesh().get_aabb()
  if b.end.y<.1 and b.size.y<.1:result.append(FOOTPRINT.paving_footprint(c.shape.get_debug_mesh(),c.global_transform))
 return result
static func overlaps(poly:PackedVector2Array,polygons:Array)->bool:
 for p in polygons:
  if not Geometry2D.intersect_polygons(poly,p).is_empty():return true
 return false
static func expanded(poly:PackedVector2Array)->PackedVector2Array:
 var grown=Geometry2D.offset_polygon(poly,CLEARANCE,Geometry2D.JOIN_ROUND)
 assert(grown.size()==1);return grown[0]
static func solids(scene:Node3D)->Array:
 var result=[]
 for c in scene.find_children('*','CollisionShape3D',true,false):
  if not c.get_parent() is StaticBody3D or c.disabled:continue
  var b:AABB=c.global_transform*c.shape.get_debug_mesh().get_aabb()
  if b.end.y>.18 and b.position.y<1.5 and b.size.x<60 and b.size.z<60:
   result.append(rect(b.position.x,b.position.z,b.size.x,b.size.z))
 return result
static func move_clear(poly:PackedVector2Array,origin:Vector3,paths:Array,obstacles:Array)->Vector3:
 # Nearest deterministic lawn shoulder, not a distant reserve dumping ground.
 for ring in range(1,49):
  for i in range(32):
   var delta=Vector2(cos(i*TAU/32),sin(i*TAU/32))*ring*.20
   var moved=PackedVector2Array()
   for p in poly:moved.append(p+delta)
   var target=origin+Vector3(delta.x,0,delta.y)
   if Vector2(target.x,target.z).length()>44:continue
   if not overlaps(moved,paths) and not overlaps(moved,obstacles):return target
 assert(false,'No local safe shrub shoulder for '+str(origin))
 return origin
static func corrected(mesh:Mesh,t:Transform3D,paths:Array,obstacles:Array,ground_root:=true)->Transform3D:
 var result=t
 var hull=expanded(FOOTPRINT.paving_footprint(mesh,t))
 if overlaps(hull,paths):result.origin=move_clear(hull,t.origin,paths,obstacles)
 var minimum=INF
 for p in mesh.get_faces():minimum=minf(minimum,(result*p).y)
 # Genuine root gap >2cm only. Keep already grounded stems and planter flora intact.
 if ground_root and minimum>BASE_Y+.02:result.origin.y+=BASE_Y-.005-minimum
 return result
static func apply(scene:Node3D)->Node3D:
 assert(not scene.has_node('PathFoliageFinish'))
 var root=Node3D.new();root.name='PathFoliageFinish';scene.add_child(root)
 var material=scene.courtyard_material('paving',Color(.46,.44,.38,1))
 var materials=[];var changes=[]
 for mesh in scene.get_node('HallSurroundPaths').find_children('*','MeshInstance3D',true,false):
  materials.append(str(mesh.get_path()));mesh.material_override=material
 # Other routes already share exact same shader parameters. Terrace construction
 # uses this material before batching; preserve separate capstones and stair faces.
 var paths=routes(scene);var obstacles=solids(scene)
 for holder in ['NaturalBorder','SouthernGroundcover','WalkwayPlanting','RouteGardens','RaisedHideoutTerrace']:
  for batch in scene.get_node(holder).find_children('*','MultiMeshInstance3D',true,false):
   var is_shrub='shrub' in str(batch.name)
   var is_low_flora='ground_' in str(batch.name) and not 'grass' in str(batch.name) and batch.has_meta('source_transforms')
   if not is_shrub and not is_low_flora:continue
   var mm=batch.multimesh;var authority:Array=batch.get_meta('source_transforms').duplicate()
   for i in range(mm.instance_count):
    var old=batch.global_transform*authority[i]
    # Non-shrub flora is touched ONLY where the newly aligned last slab
    # extends into its former lawn. Never lower flower/fern authored stems.
    if not is_shrub and not overlaps(expanded(FOOTPRINT.paving_footprint(mm.mesh,old)),[rect(-8.28,10,2.6,6.6)]):continue
    var next=corrected(mm.mesh,old,paths,obstacles,is_shrub)
    if old.is_equal_approx(next):continue
    changes.append({'node':str(batch.get_path()),'instance':i,'from':old.origin,'to':next.origin,'path_relocation':not Vector2(old.origin.x,old.origin.z).is_equal_approx(Vector2(next.origin.x,next.origin.z))})
    var local=batch.global_transform.affine_inverse()*next
    mm.set_instance_transform(i,local);authority[i]=local
   batch.set_meta('source_transforms',authority)
 for shrub in scene.get_node('ReferenceFoliage').get_children():
  if not str(shrub.name).begins_with('Shrub'):continue
  var mesh=shrub.find_children('*','MeshInstance3D',true,false)[0]
  var old:Transform3D=mesh.global_transform;var next=corrected(mesh.mesh,old,paths,obstacles)
  if old.is_equal_approx(next):continue
  changes.append({'node':str(shrub.get_path()),'instance':-1,'from':old.origin,'to':next.origin,'path_relocation':not Vector2(old.origin.x,old.origin.z).is_equal_approx(Vector2(next.origin.x,next.origin.z))})
  shrub.global_position+=next.origin-old.origin
 root.set_meta('journal',changes);root.set_meta('material_journal',materials);root.set_meta('route_polygons',paths)
 return root

# Opt-in loading path. Original synchronous entrypoints above remain unchanged.
# Searches visit the same rings/angles and face vertices in exactly the same order.
static func solids_staged(scene:Node3D)->Variant:
 var result=[];var visited=0
 for c in scene.find_children('*','CollisionShape3D',true,false):
  visited+=1
  if visited%8==0:
   if await scene._startup_checkpoint('path foliage: collision footprint batch'):return null
  if not c.get_parent() is StaticBody3D or c.disabled:continue
  var b:AABB=c.global_transform*c.shape.get_debug_mesh().get_aabb()
  if b.end.y>.18 and b.position.y<1.5 and b.size.x<60 and b.size.z<60:
   result.append(rect(b.position.x,b.position.z,b.size.x,b.size.z))
 return result
static func move_clear_staged(scene:Node3D,poly:PackedVector2Array,origin:Vector3,paths:Array,obstacles:Array)->Variant:
 for ring in range(1,49):
  for i in range(32):
   if i%4==0:
    if await scene._startup_checkpoint('path foliage: shoulder search batch'):return null
   var delta=Vector2(cos(i*TAU/32),sin(i*TAU/32))*ring*.20
   var moved=PackedVector2Array()
   for p in poly:moved.append(p+delta)
   var target=origin+Vector3(delta.x,0,delta.y)
   if Vector2(target.x,target.z).length()>44:continue
   if not overlaps(moved,paths) and not overlaps(moved,obstacles):return target
 assert(false,'No local safe shrub shoulder for '+str(origin))
 return origin
static func corrected_staged(scene:Node3D,mesh:Mesh,t:Transform3D,paths:Array,obstacles:Array,ground_root:=true)->Variant:
 var result=t
 var hull=expanded(FOOTPRINT.paving_footprint(mesh,t))
 if overlaps(hull,paths):
  var shifted=await move_clear_staged(scene,hull,t.origin,paths,obstacles)
  if shifted==null:return null
  result.origin=shifted
 var minimum=INF;var visited=0
 for p in mesh.get_faces():
  minimum=minf(minimum,(result*p).y);visited+=1
  if visited%128==0:
   if await scene._startup_checkpoint('path foliage: root vertex batch'):return null
 if ground_root and minimum>BASE_Y+.02:result.origin.y+=BASE_Y-.005-minimum
 return result
static func apply_staged(scene:Node3D)->Node3D:
 assert(not scene.has_node('PathFoliageFinish'))
 var root=Node3D.new();root.name='PathFoliageFinish';scene.add_child(root)
 var material=scene.courtyard_material('paving',Color(.46,.44,.38,1))
 var materials=[];var changes=[]
 for mesh in scene.get_node('HallSurroundPaths').find_children('*','MeshInstance3D',true,false):
  materials.append(str(mesh.get_path()));mesh.material_override=material
  if await scene._startup_checkpoint('path foliage: hall material'):return null
 var paths=routes(scene)
 if await scene._startup_checkpoint('path foliage: routes collected'):return null
 var obstacles=await solids_staged(scene)
 if obstacles==null:return null
 for holder in ['NaturalBorder','SouthernGroundcover','WalkwayPlanting','RouteGardens','RaisedHideoutTerrace']:
  for batch in scene.get_node(holder).find_children('*','MultiMeshInstance3D',true,false):
   var is_shrub='shrub' in str(batch.name)
   var is_low_flora='ground_' in str(batch.name) and not 'grass' in str(batch.name) and batch.has_meta('source_transforms')
   if not is_shrub and not is_low_flora:continue
   var mm=batch.multimesh;var authority:Array=batch.get_meta('source_transforms').duplicate()
   for i in range(mm.instance_count):
    if await scene._startup_checkpoint('path foliage: instance boundary'):return null
    var old=batch.global_transform*authority[i]
    if not is_shrub and not overlaps(expanded(FOOTPRINT.paving_footprint(mm.mesh,old)),[rect(-8.28,10,2.6,6.6)]):continue
    var next=await corrected_staged(scene,mm.mesh,old,paths,obstacles,is_shrub)
    if next==null:return null
    if old.is_equal_approx(next):continue
    changes.append({'node':str(batch.get_path()),'instance':i,'from':old.origin,'to':next.origin,'path_relocation':not Vector2(old.origin.x,old.origin.z).is_equal_approx(Vector2(next.origin.x,next.origin.z))})
    var local=batch.global_transform.affine_inverse()*next
    mm.set_instance_transform(i,local);authority[i]=local
   batch.set_meta('source_transforms',authority)
 for shrub in scene.get_node('ReferenceFoliage').get_children():
  if not str(shrub.name).begins_with('Shrub'):continue
  if await scene._startup_checkpoint('path foliage: reference shrub'):return null
  var mesh=shrub.find_children('*','MeshInstance3D',true,false)[0]
  var old:Transform3D=mesh.global_transform
  var next=await corrected_staged(scene,mesh.mesh,old,paths,obstacles)
  if next==null:return null
  if old.is_equal_approx(next):continue
  changes.append({'node':str(shrub.get_path()),'instance':-1,'from':old.origin,'to':next.origin,'path_relocation':not Vector2(old.origin.x,old.origin.z).is_equal_approx(Vector2(next.origin.x,next.origin.z))})
  shrub.global_position+=next.origin-old.origin
 root.set_meta('journal',changes);root.set_meta('material_journal',materials);root.set_meta('route_polygons',paths)
 return root
