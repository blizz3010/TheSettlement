extends RefCounted
## Isolated clustered revision on v0.57; shipping entrypoint remains unwired. Install AFTER terrain, Park A, and ContinuousGrass.
## No relocation, state, collision, lights, terrain editing, or global RNG consumption.
const Terrain = preload('res://scripts/settlement_terrain.gd')
const Grass = preload('res://scripts/continuous_grass.gd')
const Paths = preload('res://scripts/path_foliage_finish.gd')
const BED_IDS = ['fountain_southeast','fountain_east','market_inner']
const ASSETS = ['compact_broadleaf_mound','flower_groundcover_mat','small_rock_group']
const MAX_TRIANGLES = 40000
const MAX_HEIGHT = .45
const PATH_CLEARANCE = .50
static func rectangle(b:AABB)->PackedVector2Array:
 return Grass.rect_poly(Rect2(Vector2(b.position.x,b.position.z),Vector2(b.size.x,b.size.z)))
static func bounds_xz(r:Rect2)->AABB:
 return AABB(Vector3(r.position.x,-1,r.position.y),Vector3(r.size.x,4,r.size.y))
static func overlap(b:AABB,polygons:Array,clearance:float)->bool:
 var footprint=Grass.rect_poly(Rect2(Vector2(b.position.x,b.position.z),Vector2(b.size.x,b.size.z)).grow(clearance))
 return Paths.overlaps(footprint,polygons)
static func semantic_masks(scene:Node3D,include_park:bool=true)->Array:
 var out=[]
 for r in preload("res://scripts/seat_interaction.gd").GARDEN_POCKETS:out.append(Grass.rect_poly(r))
 # Original plaza paths, full civic building and its surrounding walks, original traders.
 for r in [Rect2(-3.7,-21.2,7.4,18.4),Rect2(-24.2,-6.7,24.4,5.4),Rect2(-10.3,-33.5,20.6,20.3),Rect2(-10.6,-1.7,7.2,7.6),Rect2(5.0,-7.5,7.0,9.0),Rect2(20.1,-9.0,3.8,12.5)]:out.append(Grass.rect_poly(r))
 for bounds in preload('res://scripts/hideout_terrace.gd').reservations()+preload('res://scripts/market_landscape.gd').envelopes():
  out.append(Grass.rect_poly(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).grow(.08)))
 for root_name in ['MarketExpansion','ApproachPathFinish','HallRoutePark']:
  if root_name=='HallRoutePark' and not include_park:continue
  var holder=scene.get_node_or_null(root_name)
  if holder==null:continue
  var polygons=holder.get_meta('paving_polygons',holder.get_meta('footprints',[]))
  for polygon in polygons:
   var grown=Geometry2D.offset_polygon(polygon,.10)
   out.append_array(grown)
 var park=scene.get_node_or_null('HallRoutePark')
 if park!=null and include_park:out.append_array(park.get_meta('grass_exclusion_polygons',[]))
 return out
static func preservation_masks(scene:Node3D)->Array:
 # Existing authoritative polygons, never narrowed to fit a proposed pocket.
 var result=semantic_masks(scene)
 result.append_array(scene.get_node('PathFoliageFinish').get_meta('route_polygons'))
 for r in preload('res://scripts/local_terrain_layers.gd').EXTRA_RESERVES:
  result.append(Grass.rect_poly(r))
 result.append(Grass.rect_poly(preload('res://scripts/rook_shop.gd').FOOTPRINT))
 result.append(Grass.rect_poly(preload('res://scripts/rook_shop.gd').CONNECTOR))
 # Entire selected Park A envelope, not merely its paving.
 result.append(Grass.rect_poly(Rect2(-22,-22.7,9.1,6.2)))
 # Preserve original fountain and launchpad apron, including polygon between samples.
 for spec in [[Vector2.ZERO,10.0],[Vector2(22,-16),11.0]]:
  var poly=PackedVector2Array()
  for i in range(64):poly.append(spec[0]+Vector2(cos(i*TAU/64),sin(i*TAU/64))*spec[1])
  result.append(poly)
 # All built solid volumes at plant height, not only grass's near-ground blockers.
 # Project actual collision geometry, not its rotated axis-aligned box.
 for col in scene.find_children('*','CollisionShape3D',true,false):
  if col.disabled or col.shape==null or not col.get_parent() is StaticBody3D:continue
  var mesh=col.shape.get_debug_mesh()
  var b:AABB=col.global_transform*mesh.get_aabb()
  if b.size.x>=60 or b.size.z>=60 or b.end.y<-.04 or b.position.y>1.5:continue
  var pts=PackedVector2Array()
  var vertices=PackedVector3Array()
  if col.shape is BoxShape3D:
   for x in [-.5,.5]:
    for y in [-.5,.5]:
     for z in [-.5,.5]:vertices.append(col.shape.size*Vector3(x,y,z))
  elif col.shape is ConvexPolygonShape3D:vertices=col.shape.points
  elif col.shape is CylinderShape3D:
   for i in range(64):
    for y in [-.5,.5]:vertices.append(Vector3(cos(i*TAU/64)*col.shape.radius/cos(PI/64),y*col.shape.height,sin(i*TAU/64)*col.shape.radius/cos(PI/64)))
  else:
   for surface in range(mesh.get_surface_count()):vertices.append_array(mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
  for v in vertices:
   var q:Vector3=col.global_transform*v;pts.append(Vector2(q.x,q.z))
  if pts.size()>=3:
   # Keep original Grass collider padding in addition to the full-canopy shoulder.
   var pad=.12 if col.shape is CylinderShape3D else .10
   result.append_array(Geometry2D.offset_polygon(Geometry2D.convex_hull(pts),pad))
 # Actual quest-board interaction radius, in addition to solid sign geometry.
 var board=PackedVector2Array()
 for i in range(64):board.append(Vector2(-5.8,-9.1)+Vector2(cos(i*TAU/64),sin(i*TAU/64))*2.8)
 result.append(board)
 for bench in scene.get_tree().get_nodes_in_group('usable_seats'):
  if not scene.is_ancestor_of(bench):continue
  for local in bench.get_meta('seat_exit_local',[]):
   var p:Vector3=bench.to_global(local)
   result.append(Grass.rect_poly(Rect2(Vector2(p.x,p.z)-Vector2.ONE*.75,Vector2.ONE*1.5)))
 return result
static var _verified_foliage:Array=[]
static func existing_foliage(_scene:Node3D)->Array:
 # Same verified native authority in every renderer. No dummy-getter fallback.
 if not _verified_foliage.is_empty():return _verified_foliage
 var data=JSON.parse_string(FileAccess.get_file_as_string('res://assets/planting_review/verified-native-foliage.json'))
 if not data is Dictionary or data.get('schema',0)!=1 or not data.has('source_sha256') or not data.has('polygons'):
  push_error('Missing/invalid native foliage authority; planting fails closed')
  return [Grass.rect_poly(Rect2(-1000,-1000,2000,2000))]
 for path in data.source_sha256:
  if FileAccess.get_sha256(path)!=data.source_sha256[path]:
   push_error('Native foliage authority is stale; planting fails closed until native re-export: '+path)
   return [Grass.rect_poly(Rect2(-1000,-1000,2000,2000))]
 for row in data.polygons:
  var poly=PackedVector2Array()
  for p in row:poly.append(Vector2(p[0],p[1]))
  _verified_foliage.append(poly)
 return _verified_foliage
static func live_existing_foliage(scene:Node3D)->Array:
 var result=[]
 for garden in scene.find_children('LocalMarketSurroundings','Node3D',true,false):
  for node in garden.find_children('*','MeshInstance3D',true,false):
   if node.visible and node.mesh!=null:result.append(rectangle(node.global_transform*node.mesh.get_aabb()))
 for root_name in ['NaturalBorder','SouthernGroundcover','WalkwayPlanting','RouteGardens','ReferenceFoliage','RaisedHideoutTerrace','MarketSurroundings','HallRoutePark']:
  var root=scene.get_node_or_null(root_name)
  if root==null:continue
  for node in root.find_children('*','MultiMeshInstance3D',true,false):
   if not node.visible or 'grass' in str(node.name).to_lower():continue
   for i in range(node.multimesh.instance_count):
    var b:AABB=node.global_transform*node.multimesh.get_instance_transform(i)*node.multimesh.mesh.get_aabb()
    result.append(rectangle(b))
  if true:
   for node in root.find_children('*','MeshInstance3D',true,false):
    if node.visible and node.mesh!=null:result.append(rectangle(node.global_transform*node.mesh.get_aabb()))
 return result
static func add_to(scene:Node3D)->Node3D:
 assert(scene.global_transform.is_equal_approx(Transform3D.IDENTITY))
 assert(scene.has_node('ContinuousGrass') and scene.has_node('HallRoutePark'))
 assert(not scene.has_node('IntentionalPlantingPockets'))
 var masks=preservation_masks(scene)
 var old_foliage=existing_foliage(scene)
 var root=Node3D.new();root.name='IntentionalPlantingPockets';scene.add_child(root)
 var sources=[];var meshes=[];var groups=[[],[],[]]
 for asset in ASSETS:
  var source=load('res://assets/planting_dense/'+asset+'.glb').instantiate()
  var nodes=source.find_children('*','MeshInstance3D',true,false)
  assert(nodes.size()==1 and nodes[0].transform.is_equal_approx(Transform3D.IDENTITY))
  sources.append(source);meshes.append(nodes[0].mesh)
 var journal=[];var rejected=[];var counts={};var triangles=0
 var data=JSON.parse_string(FileAccess.get_file_as_string('res://assets/planting_review/dense-accepted-placement.json'))
 assert(data.placements.size()==47)
 rejected.append_array(data.preflight_rejected)
 for bed in BED_IDS:counts[bed]=0
 for proposed in data.placements:
  var p=Vector2(proposed.x,proposed.z)
  var index=ASSETS.find(proposed.asset);assert(index>=0)
  var scale_factor:float=proposed.scale
  var y=Terrain.pre_park_mesh_height(p)
  var t=Transform3D(Basis(Vector3.UP,proposed.yaw).scaled(Vector3.ONE*scale_factor),Vector3(p.x,y,p.y))
  var b:AABB=t*meshes[index].get_aabb()
  # Seat each whole mass into the lowest sampled terrain, avoiding floating outer roots.
  var low=y
  for x in [b.position.x,(b.position.x+b.end.x)*.5,b.end.x]:
   for z in [b.position.z,(b.position.z+b.end.z)*.5,b.end.z]:low=minf(low,Terrain.pre_park_mesh_height(Vector2(x,z)))
  t.origin.y=low-(.025 if index==2 else .005)
  b=t*meshes[index].get_aabb()
  assert(b.size.y<=MAX_HEIGHT)
  var reason=''
  if Terrain.stream_wet(p.x,p.y):reason='wet ground'
  elif overlap(b,masks,PATH_CLEARANCE):reason='protected footprint or full path shoulder'
  elif overlap(b,old_foliage,.08):reason='existing planting retained'
  if not reason.is_empty():
   rejected.append({'bed':proposed.bed,'cluster':proposed.cluster,'at':p,'reason':reason});continue
  groups[index].append(t);counts[proposed.bed]+=1
  triangles+=meshes[index].get_faces().size()/3
  journal.append({'bed':proposed.bed,'cluster':proposed.cluster,'asset':ASSETS[index],'transform':t,'bounds':b})
 assert(triangles<=MAX_TRIANGLES)
 for index in range(ASSETS.size()):
  if not groups[index].is_empty():
   var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
   mm.mesh=meshes[index];mm.instance_count=groups[index].size()
   for i in range(groups[index].size()):mm.set_instance_transform(i,groups[index][i])
   var batch=MultiMeshInstance3D.new();batch.name=ASSETS[index];batch.multimesh=mm
   batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   root.add_child(batch)
  sources[index].free()
 root.set_meta('journal',journal);root.set_meta('rejected',rejected);root.set_meta('bed_counts',counts)
 root.set_meta('budget',{'candidates':48,'accepted':journal.size(),'triangles':triangles,'batches':root.get_child_count(),'colliders':0,'lights':0,'state_fields':0})
 # Rejected candidates remain rejected; never weaken buffers or silently relocate.
 return root
