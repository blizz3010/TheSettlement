extends Node3D
# Additive low planting beside two existing routes. No path, grass-buffer or service edits.
const Gardens=preload('res://scripts/landscape_four_gardens.gd')
const ROOT_NAME='PathShoulderGardens'
const ASSETS=['groundcover/ground_fern_a','groundcover/ground_flowers_purple','groundcover/ground_flowers_yellow','planting_dense/compact_broadleaf_mound','planting_dense/small_rock_group']
const REGIONS=[{'name':'WestRouteNorth','x0':-22.0,'x1':-12.0,'edge_z':-6.5,'window':Rect2(-23,-9,12,2.5)},{'name':'SouthMarketNorth','x0':-5.6,'x1':-1.0,'edge_z':28.0,'window':Rect2(-7,25.5,7,2.5)}]
const RESERVES=[Rect2(-30,9,12,12),Rect2(-10,32.5,8,7),Rect2(6,34.5,8,7),Rect2(26,29.5,8,7),Rect2(-1.5,29,3,13),Rect2(-9,42,18,17),Rect2(-9,43.2,18,17),Rect2(2.6,32,3,11.2),Rect2(-5.7,.55,2.6,2.9)]
var host
var visual:Node3D
var attempted=false
var requested=false
var result={}
func setup(world):host=world;name='PathShoulderGardenController'
func active()->bool:
 return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(host) and get_parent()==host and host.is_inside_tree() and not host.is_queued_for_deletion() and host.global_transform==Transform3D.IDENTITY and host.world_initialized and (not host.staged_startup or host.world_activated or host.startup_preparing_assets) and not host.startup_cancel_requested
func begin_after_activation(world):
 if requested or attempted or world!=host or not active():return
 requested=true
 var tree=get_tree();var started=Time.get_ticks_msec()
 while active():
  if not is_instance_valid(host.inn_site) or host.inn_site.is_queued_for_deletion():
   result=reject('Delivered inn controller missing');attempted=true
   print('PATH_SHOULDER_RESULT ',compact_result());return
  if host.inn_site.attempted:break
  if Time.get_ticks_msec()-started>35000:
   result=reject('Delivered scenery did not settle');attempted=true
   print('PATH_SHOULDER_RESULT ',compact_result());return
  await tree.physics_frame
  if not active():return
 if not active():return
 await tree.physics_frame
 if not active():return
 install()
 print('PATH_SHOULDER_RESULT ',compact_result())
static func rect(b:AABB)->Rect2:return Rect2(b.position.x,b.position.z,b.size.x,b.size.z)
static func points(r:Rect2)->PackedVector2Array:return PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
static func overlap(a:PackedVector2Array,b:PackedVector2Array)->bool:return not Geometry2D.intersect_polygons(a,b).is_empty()
static func nearby(b:AABB)->bool:
 return rect(b).intersects(Rect2(-23,-9,12,2.5),true) or rect(b).intersects(Rect2(-7,25.5,7,2.5),true)
static func collect_mesh(mesh:Mesh,t:Transform3D,output:Array):
 var bounds=t*mesh.get_aabb()
 if not nearby(bounds):return
 if bounds.size.x<=5 and bounds.size.z<=5:output.append(bounds);return
 # Large art/sky/paving bounds are refined into actual triangles, never blanket-exempted.
 var faces=mesh.get_faces()
 if faces.is_empty():output.append(bounds);return
 for i in range(0,faces.size(),3):
  var b=AABB(t*faces[i],Vector3.ZERO);b=b.expand(t*faces[i+1]);b=b.expand(t*faces[i+2])
  if nearby(b):output.append(b)
func reject(reason:String,root:Node3D=null)->Dictionary:
 if is_instance_valid(root):root.free()
 return {'ok':false,'reason':reason,'existing_world_mutated':false}
func install()->Dictionary:
 if attempted:return result
 attempted=true
 result=prepare()
 return result
func prepare()->Dictionary:
 if not active() or not is_inside_tree() or global_transform!=Transform3D.IDENTITY:return reject('Inactive/nonidentity host/controller')
 if host.has_node(ROOT_NAME):return reject('Existing or foreign owned root')
 if not is_instance_valid(host.four_area_gardens) or not host.four_area_gardens.result.get('ok',false):return reject('Existing gardens not ready')
 if not is_instance_valid(host.cooking_nook_visuals) or not host.cooking_nook_visuals.attempted or not host.cooking_nook_visuals.result.get('ok',false):return reject('Cooking nook not ready')
 var finish=host.get_node_or_null('PathFoliageFinish');var market=host.get_node_or_null('MarketExpansion')
 if finish==null or market==null:return reject('Actual paving owners missing')
 var paths=finish.get_meta('route_polygons',[]).duplicate(true)
 var market_paths=market.get_meta('paving_polygons',[])
 if paths.is_empty() or market_paths.is_empty():return reject('Actual paving metadata absent')
 paths.append_array(market_paths)
 var west=Gardens.rect_poly(Rect2(-24,-6.5,24,5));var west_matches=0
 for p in paths:
  if p is PackedVector2Array and p==west:west_matches+=1
 if west_matches!=1:return reject('West route identity changed')
 # Use all actual polygons, including endpoint discs. Sampling bands are never clearance authority.
 for poly in paths:
  if not poly is PackedVector2Array or poly.size()<3:return reject('Malformed paving metadata')
 var inspector=Gardens.new();inspector.host=host
 var ground=inspector.ground_supports()
 if not ground.ok:inspector.free();return reject(ground.reason)
 var turf=host.get_node_or_null('SettlementTerrain/GroundRelief');var relief=host.get_node_or_null('SettlementTerrain/WalkableRelief')
 if not turf is MeshInstance3D or not relief is StaticBody3D:inspector.free();return reject('Original terrain owners missing')
 # Bind exactly the four split render supports to the already validated physical pieces.
 var ground_owner=host.get_node_or_null('HallBasementBlockout')
 if not ground_owner is Node3D or ground_owner.get_parent()!=host or ground_owner.is_queued_for_deletion() or ground_owner.transform!=Transform3D.IDENTITY:inspector.free();return reject('Split ground render owner changed')
 var rendered=[]
 for child in ground_owner.get_children():
  if child is MeshInstance3D:rendered.append(child)
 if rendered.size()!=4:inspector.free();return reject('Split ground render count changed')
 var support_visuals=[]
 for shape in ground.shapes:
  var matches=[]
  for mesh in rendered:
   if mesh.is_queued_for_deletion() or not mesh.is_visible_in_tree() or not mesh.mesh is BoxMesh:continue
   if mesh.mesh.size==shape.shape.size and mesh.global_transform==shape.global_transform:matches.append(mesh)
  if matches.size()!=1 or matches[0] in support_visuals:inspector.free();return reject('Split ground render/shape binding changed')
  support_visuals.append(matches[0])
 var reserved=RESERVES.duplicate()
 for area in preload('res://scripts/hideout_terrace.gd').reservations()+preload('res://scripts/market_landscape.gd').envelopes():reserved.append(rect(area))
 var occupied=[]
 for mesh in host.find_children('*','MeshInstance3D',true,false):
  if mesh.mesh==null or not mesh.is_visible_in_tree():continue
  if mesh==turf:continue
  # Only the four exact live render-support references; no other Hall/low geometry exemption.
  if mesh in support_visuals:continue
  collect_mesh(mesh.mesh,mesh.global_transform,occupied)
 for batch in host.find_children('*','MultiMeshInstance3D',true,false):
  if not batch.is_visible_in_tree() or batch.multimesh==null or batch.multimesh.mesh==null:continue
  if inspector.fine_lawn(batch):continue # Exact inherited blade geometry/shader/lineage contract; buffers remain untouched.
  var mm=batch.multimesh;var count=mm.instance_count if mm.visible_instance_count<0 else mini(mm.visible_instance_count,mm.instance_count)
  for i in range(count):collect_mesh(mm.mesh,batch.global_transform*mm.get_instance_transform(i),occupied)
 inspector.free()
 var solids=[]
 for c in host.find_children('*','CollisionShape3D',true,false):
  if c.disabled or c.shape==null or not c.get_parent() is StaticBody3D:continue
  if c in ground.shapes or c.get_parent()==relief:continue
  if c.shape is ConcavePolygonShape3D:
   var faces=c.shape.get_faces()
   for i in range(0,faces.size(),3):
    var b=AABB(c.global_transform*faces[i],Vector3.ZERO)
    b=b.expand(c.global_transform*faces[i+1]);b=b.expand(c.global_transform*faces[i+2]);solids.append(b)
  else:solids.append(c.global_transform*c.shape.get_debug_mesh().get_aabb())
 var root=Node3D.new();root.name=ROOT_NAME;var templates={}
 for asset in ASSETS:
  var packed=load('res://assets/'+asset+'.glb')
  if not packed is PackedScene:return reject('Missing existing art '+asset,root)
  var source=packed.instantiate()
  if not source is Node3D:
   if source!=null:source.free()
   return reject('Invalid art root '+asset,root)
  var meshes=source.find_children('*','MeshInstance3D',true,false)
  if source.transform!=Transform3D.IDENTITY or meshes.size()!=1 or meshes[0].get_parent()!=source or meshes[0].mesh==null or meshes[0].transform!=Transform3D.IDENTITY:source.free();return reject('Unexpected art transform '+asset,root)
  templates[asset]={'mesh':meshes[0].mesh,'material':meshes[0].material_override};source.free()
 var journal=[];var counts={};var refused={}
 for region in REGIONS:
  var group=Node3D.new();group.name=region.name;root.add_child(group);var transforms={}
  for asset in ASSETS:transforms[asset]=[]
  var count=0
  for i in range(150):
   var along=fmod(i*.61803398875,1.0);var x=lerpf(region.x0,region.x1,along)
   var z=region.edge_z-.42-fmod(i*.41421356237,1.0)*1.05
   var ai=0 if i%7<2 else (1+i%2 if i%7<5 else 3)
   if i%31==0:ai=4
   var asset=ASSETS[ai];var mesh=templates[asset].mesh
   var scale=.55+float(i%4)*.10
   if ai==3:scale=.55+float(i%3)*.08
   if ai==4:scale=.35
   var t=Transform3D(Basis(Vector3.UP,i*.71).scaled(Vector3.ONE*scale),Vector3(x,0,z));var b=t*mesh.get_aabb()
   var footprint=rect(b).grow(.12)
   if not region.window.encloses(footprint):continue
   var poly=points(footprint);var blocked=false
   for p in paths:
    if overlap(poly,p):blocked=true;break
   for reserve in reserved:
    if footprint.intersects(reserve,true):blocked=true
   if blocked:continue
   var q=PhysicsRayQueryParameters3D.create(Vector3(x,5,z),Vector3(x,-5,z));q.exclude=[host.player.get_rid()]
   var hit=host.get_world_3d().direct_space_state.intersect_ray(q)
   if hit.is_empty() or hit.normal.y<.9:continue
   if hit.collider!=relief and hit.collider!=ground.shapes[0].get_parent():continue
   # Center-root contact only; reject excessive height spread over four footprint corners.
   var supported=true
   for corner in points(rect(b)):
    var ray=PhysicsRayQueryParameters3D.create(Vector3(corner.x,5,corner.y),Vector3(corner.x,-5,corner.y));ray.exclude=q.exclude
    var contact=host.get_world_3d().direct_space_state.intersect_ray(ray)
    if contact.is_empty() or (contact.collider!=relief and contact.collider!=ground.shapes[0].get_parent()) or absf(contact.position.y-hit.position.y)>.08:supported=false;break
   if not supported:continue
   t.origin.y=hit.position.y-b.position.y-.003;b=t*mesh.get_aabb()
   if b.size.y>.75:continue
   for other in occupied:
    if b.grow(.05).intersects(other):blocked=true;break
   if not blocked:
    for other in solids:
     if b.grow(.05).intersects(other):blocked=true;break
   if blocked:continue
   transforms[asset].append(t);count+=1;journal.append({'region':region.name,'asset':asset,'transform':t,'bounds':b,'support':hit.position})
  counts[region.name]=count;refused[region.name]=150-count
  if count<12:return reject('Insufficient clear shoulder space: '+region.name+' '+str(count),root)
  for asset in ASSETS:
   var list=transforms[asset]
   if list.is_empty():continue
   var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=templates[asset].mesh;mm.instance_count=list.size()
   for i in range(list.size()):mm.set_instance_transform(i,list[i])
   var batch=MultiMeshInstance3D.new();batch.name=asset.get_file();batch.multimesh=mm;batch.material_override=templates[asset].material;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;group.add_child(batch)
 if not active():return reject('Cancelled before publication',root)
 host.add_child(root);visual=root
 return {'ok':true,'counts':counts,'refused':refused,'journal':journal,'new_colliders':0,'existing_world_mutated':false,'scope':'Two low planted shoulders; no gap repair, new trees, furniture or route changes'}
func _exit_tree():
 if is_instance_valid(visual):visual.queue_free()

# Keep full journals in result for validation; avoid megabyte console serialization.
func compact_result()->Dictionary:
 var summary={}
 for key in ['ok','reason','counts','bed_status','timings_usec','new_colliders','baked_reuse','runtime_sampling','recipe_sha256']:
  if result.has(key):summary[key]=result[key]
 return summary
