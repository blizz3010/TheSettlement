extends Node3D
# Owned, one-shot elevated inn placement. No gameplay or catalogue writes.
const Access=preload('res://scripts/inn_terrace_access.gd')
const Gardens=preload('res://scripts/landscape_four_gardens.gd')
const Relocation=preload('res://scripts/inn_shrub_relocation.gd')
var host:Node3D
var owned:Node3D
var relocation:Node3D
var result={}
var support_observations=[]
var support_sink:Callable
var requested=false
var attempted=false
func setup(world):name='InnSiteController';host=world
func active()->bool:
 return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(host) and host.is_inside_tree() and not host.is_queued_for_deletion() and host.world_initialized and not host.startup_cancel_requested and (not host.staged_startup or host.world_activated or host.startup_preparing_assets)
func begin_after_activation(world):
 if requested or attempted or world!=host or not active():return
 requested=true
 var tree=get_tree();var started=Time.get_ticks_msec()
 while active():
  if not is_instance_valid(host.cooking_nook_visuals) or host.cooking_nook_visuals.is_queued_for_deletion() or not is_instance_valid(host.fishing_trader) or host.fishing_trader.is_queued_for_deletion():
   result=refuse('Existing controller unavailable');attempted=true;return
  if host.cooking_nook_visuals.attempted and not host.fishing_trader.result.is_empty():break
  if Time.get_ticks_msec()-started>30000:
   result=refuse('Existing visual activation did not settle');attempted=true;return
  await tree.physics_frame
  if not active():return
 if not active():return
 await tree.physics_frame
 if not active():return
 result=install(host);attempted=true
 print('INN_STARTUP_RESULT ',result)

static func relative(node:Node3D,root:Node3D)->Transform3D:
 var t=node.transform;var parent=node.get_parent()
 while parent!=null and parent!=root:
  if not parent is Node3D:return Transform3D.IDENTITY
  t=parent.transform*t;parent=parent.get_parent()
 return root.transform*t
func refuse(reason:String,details:Dictionary={},candidate:Node3D=null)->Dictionary:
 if support_sink.is_valid():support_sink.call(support_observations)
 if is_instance_valid(candidate):candidate.free()
 result={'ok':false,'reason':reason,'details':details,'inn_published':false}
 print('INN_STARTUP_REFUSED ',result)
 return result
func install(world:Node3D)->Dictionary:
 if owned!=null or not result.is_empty():return refuse('Already attempted')
 if not is_inside_tree() or get_parent()!=world or is_queued_for_deletion() or global_transform!=Transform3D.IDENTITY:return refuse('Controller not owned by world')
 host=world
 if not host.world_initialized or (host.staged_startup and not host.world_activated and not host.startup_preparing_assets) or host.startup_cancel_requested or (host.process_mode==Node.PROCESS_MODE_DISABLED and not host.startup_preparing_assets):return refuse('Inactive physics world')
 if host.has_node('SettlementInnExpansion'):return refuse('Existing inn owner')
 var market=host.get_node_or_null('MarketExpansion')
 if market==null:return refuse('Missing paving owner')
 var expected=PackedVector2Array([Vector2(-6.1,28),Vector2(9.1,28),Vector2(9.1,32),Vector2(-6.1,32),Vector2(-6.1,28)])
 var matches=0
 for polygon in market.get_meta('paving_polygons',[]):
  if polygon==expected:matches+=1
 if matches!=1:return refuse('Actual southern paving edge changed')
 var inspector=Gardens.new();inspector.host=host;var ground=inspector.ground_supports();inspector.free()
 if not ground.get('ok',false):return refuse('Original support binding failed',ground)
 var exempt_shapes=ground.shapes.duplicate();var exempt_visuals=[]
 var split=host.get_node_or_null('HallBasementBlockout')
 if split==null:return refuse('Missing split ground')
 var render=[]
 for child in split.get_children():
  if child is MeshInstance3D:render.append(child)
 if render.size()!=4:return refuse('Split ground render count changed')
 for shape in ground.shapes:
  var matching=[]
  for mesh in render:
   if mesh.mesh is BoxMesh and mesh.mesh.size==shape.shape.size and mesh.global_transform==shape.global_transform:matching.append(mesh)
  if matching.size()!=1 or matching[0] in exempt_visuals:return refuse('Split ground render identity changed')
  exempt_visuals.append(matching[0])
 var ground_bodies=[]
 for shape in ground.shapes:
  if not shape.get_parent() in ground_bodies:ground_bodies.append(shape.get_parent())
 for spec in [['SettlementTerrain/GroundRelief','SettlementTerrain/WalkableRelief'],['SettlementOuterTerrain/GroundRelief','SettlementOuterTerrain/WalkableOuterGround']]:
  var visual=host.get_node_or_null(spec[0]);var body=host.get_node_or_null(spec[1])
  if not visual is MeshInstance3D or not body is StaticBody3D:return refuse('Terrain owner missing',{'path':spec})
  exempt_visuals.append(visual);ground_bodies.append(body)
  for shape in body.get_children():
   if shape is CollisionShape3D:exempt_shapes.append(shape)
 var supports=[]
 for point in Access.sample_points():
  var query=PhysicsRayQueryParameters3D.create(Vector3(point.x,20,point.y),Vector3(point.x,-10,point.y));query.exclude=[host.player.get_rid()]
  var hit=host.get_world_3d().direct_space_state.intersect_ray(query)
  var observation={'query_xz':[point.x,point.y],'hit':not hit.is_empty()}
  if not hit.is_empty():
   observation['raw_position']=[hit.position.x,hit.position.y,hit.position.z]
   observation['normal']=[hit.normal.x,hit.normal.y,hit.normal.z]
   observation['source']=str(host.get_path_to(hit.collider))
  support_observations.append(observation)
  if hit.is_empty() or not hit.collider in ground_bodies or hit.normal.y<.8 or not hit.position.is_finite():return refuse('Support unavailable or unsuitable',observation)
  var lateral_error=Vector2(hit.position.x,hit.position.z).distance_to(point)
  observation['lateral_error']=lateral_error
  # Vertical ray identity uses the exact query XZ. Preserve raw solver output and Y unchanged.
  # Prior durable first-six residuals were 4.7683716e-7 m; reject anything above 10 micrometres.
  if lateral_error>.00001:return refuse('Support ray deviated laterally',observation)
  supports.append({'position':Vector3(point.x,hit.position.y,point.y),'source':observation.source,'raw_position':observation.raw_position,'query_xz':observation.query_xz,'lateral_error':lateral_error})
 if support_sink.is_valid():support_sink.call(support_observations)
 var prepared=Access.prepare(supports)
 if not prepared.get('ok',false):return refuse('Measured terrace preparation refused',prepared)
 var candidate:Node3D=prepared.root
 var meshes=candidate.find_children('*','MeshInstance3D',true,false);var boxes=[]
 var envelope=load('res://scripts/settlement_envelope.gd')
 for mesh in meshes:
  if mesh.mesh==null:return refuse('Candidate empty mesh',{},candidate)
  var bounds=relative(mesh,candidate)*mesh.mesh.get_aabb();boxes.append({'path':str(candidate.get_path_to(mesh)),'bounds':bounds})
  for x in [bounds.position.x,bounds.end.x]:
   for y in [bounds.position.y,bounds.end.y]:
    for z in [bounds.position.z,bounds.end.z]:
     if y<-.5 or y>12 or Vector2(x,z).length()>envelope.radius_at(y)-.05:return refuse('Candidate outside physical envelope',{'part':str(mesh.name),'corner':Vector3(x,y,z)},candidate)
 # Never publish solid scenery around a player who walked into the site during activation.
 if not is_instance_valid(host.player) or not is_instance_valid(host.player.body_shape) or not host.player.body_shape.shape is CapsuleShape3D:return refuse('Player capsule unavailable',{},candidate)
 var player_shape=host.player.body_shape.shape
 var player_local=AABB(Vector3(-player_shape.radius,-player_shape.height*.5,-player_shape.radius),Vector3(player_shape.radius*2,player_shape.height,player_shape.radius*2))
 var player_bounds=host.player.body_shape.global_transform*player_local
 for box in boxes:
  if player_bounds.intersects(box.bounds):return refuse('Player occupies proposed inn geometry',{'part':box.path},candidate)
 # Precompute original visual obstacles once; no authored shrub/flower exceptions except the exact scheduled mover.
 var obstacles=[];var lawn=load('res://scripts/continuous_grass.gd').blade_mesh()
 var moving=host.get_node_or_null('NaturalBorder/border_shrub_b')
 for node in host.find_children('*','GeometryInstance3D',true,false):
  if node in exempt_visuals or not node.is_visible_in_tree() or node.is_queued_for_deletion():continue
  if node is MeshInstance3D and node.mesh!=null:obstacles.append({'path':str(host.get_path_to(node)),'mesh':node.mesh,'transform':node.global_transform})
  elif node is MultiMeshInstance3D and node.multimesh!=null and node.multimesh.mesh!=null:
   if Relocation.fine_lawn(node,host,lawn):continue
   var mm=node.multimesh;var count=mm.instance_count if mm.visible_instance_count<0 else mini(mm.instance_count,mm.visible_instance_count)
   for i in range(count):
    if node==moving and i==Relocation.INDEX:continue
    obstacles.append({'path':str(host.get_path_to(node))+':'+str(i),'mesh':mm.mesh,'transform':node.global_transform*mm.get_instance_transform(i)})
 for shape in host.find_children('*','CollisionShape3D',true,false):
  if shape in exempt_shapes or shape.disabled or shape.shape==null or not shape.get_parent() is StaticBody3D:continue
  var mesh=shape.shape.get_debug_mesh()
  if mesh==null:return refuse('Unknown collider geometry',{'path':str(host.get_path_to(shape))},candidate)
  obstacles.append({'path':str(host.get_path_to(shape)),'mesh':mesh,'transform':shape.global_transform})
 for box in boxes:
  for obstacle in obstacles:
   var conflict=conflict_evidence(obstacle.mesh,obstacle.transform,box.bounds)
   if not conflict.is_empty():return refuse('Inn/approach conflicts existing scenery',{'part':box.path,'existing':obstacle.path,'evidence':conflict},candidate)
 relocation=Relocation.new();relocation.name='InnShrubRelocation';host.add_child(relocation)
 var move=relocation.relocate(host)
 if not move.get('ok',false):relocation.free();relocation=null;return refuse('Single shrub destination refused',move,candidate)
 # All preflight work above is synchronous. Publication follows the single authorized move.
 owned=candidate;host.add_child(owned)
 result={'ok':true,'support_count':supports.size(),'riser_height':prepared.riser_height,'paving_joint':candidate.get_meta('paving_joint',{}),'shrub':move.journal,'mesh_parts':boxes.size(),'inn_published':true,'scope':'Candidate geometry screened; actual player route still required'}
 return result
func remove_owned()->bool:
 if is_instance_valid(owned):owned.free()
 owned=null
 var restored=true
 if is_instance_valid(relocation):restored=relocation.restore();relocation.free()
 relocation=null
 return restored
func _exit_tree():
 # The host may be traversing its children during exit. Never synchronously
 # remove/free siblings here; explicit remove_owned() remains synchronous.
 if not is_instance_valid(host) or host.is_queued_for_deletion():
  owned=null;relocation=null
  return
 if is_instance_valid(owned):owned.queue_free()
 owned=null
 if is_instance_valid(relocation):
  relocation.restore()
  relocation.queue_free()
 relocation=null

static func xyz(v:Vector3)->Array:return [v.x,v.y,v.z]
static func bounds_row(b:AABB)->Dictionary:return {'min':xyz(b.position),'max':xyz(b.end)}
static func conflict_evidence(mesh:Mesh,t:Transform3D,bounds:AABB)->Dictionary:
 var broad=t*mesh.get_aabb()
 if not broad.intersects(bounds):return {}
 if broad.size.x<=5 and broad.size.z<=5:return {'kind':'small_mesh_bounds','candidate':bounds_row(bounds),'obstacle':bounds_row(broad)}
 var faces=mesh.get_faces()
 if faces.is_empty():return {'kind':'empty_faces_fail_closed','candidate':bounds_row(bounds),'obstacle':bounds_row(broad)}
 for i in range(0,faces.size()-2,3):
  var a=t*faces[i];var b=t*faces[i+1];var c=t*faces[i+2]
  var face=AABB(a,Vector3.ZERO);face=face.expand(b);face=face.expand(c)
  if face.intersects(bounds):return {'kind':'triangle_bounds','triangle_index':i/3,'vertices':[xyz(a),xyz(b),xyz(c)],'triangle_bounds':bounds_row(face),'candidate':bounds_row(bounds)}
 return {}
