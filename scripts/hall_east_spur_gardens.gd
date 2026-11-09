extends Node3D
# Fixed accepted Hall-east/spur recipe on v076. Shipped West and all original scenery stay owned and unchanged.
const Gardens=preload('res://scripts/landscape_four_gardens.gd')
const ObstacleIndex=preload('res://scripts/garden_obstacle_index.gd')
const Recipe=preload('res://scripts/hall_east_spur_baked_recipe.gd')
const GRASS_SHADER=preload('res://shaders/settlement_grass.gdshader')
const FOLIAGE_SHADER=preload('res://shaders/layered_foliage.gdshader')
const ROOT_NAME='HallEastSpurGardens'
const WEST_RECIPE_SHA256='57ec5799d19a2eaf90158a2a74b255ab1082a10040c07b398f2b86c09f77eb16'
const PREREQUISITE_TIMEOUT_MSEC=180000
const ASSETS=['Fern_1','Flower_3_Group','Flower_4_Group','Bush_Common_Flowers','Pebble_Round_1','CommonTree_3']
const REGIONS=[
 {'name':'HallBenchEastBack','back':'east','sample':Rect2(15.3,-26.8,1.2,3.6),'window':Rect2(14.5,-27.5,2.8,5),'attempts':160,'structural_target':3},
 {'name':'EasternSpurNorth','back':'north','sample':Rect2(27.5,22.5,2.5,1),'window':Rect2(26.8,21.8,3.9,2.4),'attempts':160,'structural_target':3}
]
const RESERVES=[Rect2(-30,9,12,12),Rect2(-10,32.5,8,7),Rect2(6,34.5,8,7),Rect2(26,29.5,8,7),Rect2(-1.5,29,3,13),Rect2(-9,42,18,17),Rect2(-9,43.2,18,17),Rect2(2.6,32,3,11.2),Rect2(-5.7,.55,2.6,2.9)]
var host
var bake_path:String=''
var bake_sha256:String=''
var visual:Node3D
# Preparation stays detached across yields; this owner also handles cancelled coroutines.
var pending_root:Node3D
var scatter_workspace:Node3D
var preparing=false
var preparation_generation=0
var slice_started_usec=0
var slice_guard_usec=0
var timings={}
var publication_started_usec=0
var delta_started_usec=0
signal preparation_finished
const PREPARATION_BUDGET_USEC=8000
var attempted=false
var requested=false
var result={}
var diagnostics={}
var bed_status={}
func setup(world,recipe_path:String='',recipe_sha256:String=''):
 host=world;name='HallEastSpurGardenController';bake_path=recipe_path;bake_sha256=recipe_sha256
func active()->bool:
 return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(host) and get_parent()==host and host.is_inside_tree() and not host.is_queued_for_deletion() and host.global_transform==Transform3D.IDENTITY and host.world_initialized and (not host.staged_startup or host.world_activated or host.startup_preparing_assets) and not host.startup_cancel_requested
func begin_after_activation(world):
 if requested or attempted or world!=host or not active():return
 requested=true
 await install()
 if active():print('HALL_EAST_SPUR_RESULT ',compact_result())
func delivered_west_state()->Dictionary:
 var west=host.market_edge_gardens
 if not is_instance_valid(west) or west==self or west.is_queued_for_deletion() or not west.is_inside_tree() or west.get_parent()!=host:return {'ok':false,'reason':'Shipped West controller missing'}
 if not west.attempted:return {'ok':false,'reason':'Shipped West is still preparing'}
 if not west.result.get('ok',false) or not west.result.get('baked_reuse',false) or west.result.get('recipe_sha256','')!=WEST_RECIPE_SHA256:return {'ok':false,'reason':'Shipped West did not publish its verified recipe'}
 var root=host.get_node_or_null('MarketEdgeGardens')
 if not is_instance_valid(root) or not root is Node3D or root.is_queued_for_deletion() or root!=west.visual or root.get_parent()!=host or root.global_transform!=Transform3D.IDENTITY:return {'ok':false,'reason':'Shipped West owned root changed'}
 return {'ok':true,'controller_id':west.get_instance_id(),'root_id':root.get_instance_id(),'controller_path':host.get_path_to(west),'root_path':host.get_path_to(root),'recipe_sha256':WEST_RECIPE_SHA256,'counts':west.result.counts.duplicate(true),'bed_status':west.result.bed_status.duplicate(true)}
static func west_material_snapshot(material)->Dictionary:
 if material==null:return {}
 var row={'id':material.get_instance_id(),'class':material.get_class(),'path':material.resource_path}
 if material is ShaderMaterial:
  if material.shader==null:return {'invalid':'Missing West shader'}
  row['shader_id']=material.shader.get_instance_id();row['shader_code']=material.shader.code
  var params={}
  for item in material.shader.get_shader_uniform_list():
   var value=material.get_shader_parameter(item.name)
   params[item.name]={'resource_id':value.get_instance_id(),'path':value.resource_path} if value is Resource else value
  row['parameters']=params
 elif material is StandardMaterial3D:
  row['albedo_color']=material.albedo_color;row['albedo_texture_id']=material.albedo_texture.get_instance_id() if material.albedo_texture!=null else 0
  row['normal_texture_id']=material.normal_texture.get_instance_id() if material.normal_texture!=null else 0
 return row
func capture_west_snapshot()->Dictionary:
 var ownership=delivered_west_state()
 if not ownership.ok:return ownership
 var west=host.market_edge_gardens;var owned=west.visual
 var nodes=[owned];nodes.append_array(owned.find_children('*','',true,false));var rows=[]
 for node in nodes:
  if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree():return {'ok':false,'reason':'Shipped West member unavailable'}
  var row={'id':node.get_instance_id(),'path':host.get_path_to(node),'parent':node.get_parent().get_instance_id(),'class':node.get_class(),'children':[]}
  for child in node.get_children():row.children.append(child.get_instance_id())
  if node is Node3D:row['transform']=node.transform;row['visible']=node.visible
  if node is MultiMeshInstance3D:
   var mm=node.multimesh
   if mm==null or not mm.mesh is ArrayMesh:return {'ok':false,'reason':'Shipped West mesh unavailable'}
   var mesh=mm.mesh;var surfaces=[]
   for i in range(mesh.get_surface_count()):surfaces.append({'primitive':mesh.surface_get_primitive_type(i),'arrays':mesh.surface_get_arrays(i).duplicate(true),'material':west_material_snapshot(mesh.surface_get_material(i))})
   row['multimesh']={'id':mm.get_instance_id(),'buffer':mm.buffer.duplicate(),'count':mm.instance_count,'visible_count':mm.visible_instance_count,'format':mm.transform_format,'custom':mm.use_custom_data,'colors':mm.use_colors,'aabb':mm.custom_aabb,'mesh':{'id':mesh.get_instance_id(),'aabb':mesh.get_aabb(),'surfaces':surfaces},'override':west_material_snapshot(node.material_override)}
  if node is StaticBody3D:row['collision_layer']=node.collision_layer;row['collision_mask']=node.collision_mask
  if node is CollisionShape3D:
   if not node.shape is ConcavePolygonShape3D:return {'ok':false,'reason':'Shipped West collider changed'}
   row['shape']={'id':node.shape.get_instance_id(),'disabled':node.disabled,'faces':node.shape.get_faces().duplicate(),'backface_collision':node.shape.backface_collision}
  rows.append(row)
 return {'ok':true,'ownership':ownership,'result':west.result.duplicate(true),'nodes':rows}
func wait_for_delivered_west(token:int)->Dictionary:
 var tree=get_tree();var started=Time.get_ticks_msec()
 while active() and token==preparation_generation:
  var west=host.market_edge_gardens
  if not is_instance_valid(west) or west.is_queued_for_deletion():return {'ok':false,'reason':'Shipped West controller missing'}
  if west.attempted:return delivered_west_state()
  if Time.get_ticks_msec()-started>PREREQUISITE_TIMEOUT_MSEC:return {'ok':false,'reason':'Shipped West did not settle within the prerequisite window'}
  await tree.physics_frame
  if not active() or token!=preparation_generation or get_tree()!=tree:return {'ok':false,'reason':'Cancelled while waiting for shipped West'}
 return {'ok':false,'reason':'Cancelled before shipped West was ready'}
static func rect(b:AABB)->Rect2:return Rect2(b.position.x,b.position.z,b.size.x,b.size.z)
static func points(r:Rect2)->PackedVector2Array:return PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
static func overlap(a:PackedVector2Array,b:PackedVector2Array)->bool:return not Geometry2D.intersect_polygons(a,b).is_empty()
static func nearby(b:AABB)->bool:
 for region in REGIONS:
  if rect(b).intersects(region.window,true):return true
 return false
static func collect_mesh(mesh:Mesh,t:Transform3D,output:Array,owner:String):
 var bounds=t*mesh.get_aabb()
 if not nearby(bounds):return
 if bounds.size.x<=5 and bounds.size.z<=5:output.append({'bounds':bounds,'owner':owner,'primitive':'whole_mesh_aabb'});return
 # Large art/sky/paving bounds are refined into actual triangles, never blanket-exempted.
 var faces=mesh.get_faces()
 if faces.is_empty():output.append({'bounds':bounds,'owner':owner,'primitive':'whole_mesh_aabb'});return
 for i in range(0,faces.size(),3):
  var b=AABB(t*faces[i],Vector3.ZERO);b=b.expand(t*faces[i+1]);b=b.expand(t*faces[i+2])
  if nearby(b):output.append({'bounds':b,'owner':owner,'primitive':'triangle_aabb','triangle':i/3})
# Conservative narrow phase: world obstacle expanded by the SAME .05m margin,
# transformed into candidate local space; each actual triangle AABB must be clear.
# Inverse-transformed obstacle AABB may overestimate, never omit actual overlap.
static func triangle_blocks(mesh:Mesh)->Array:
 var faces=mesh.get_faces()
 if faces.is_empty() or faces.size()%3!=0:return []
 var blocks=[];var triangles=[];var merged=AABB()
 for i in range(0,faces.size(),3):
  if not faces[i].is_finite() or not faces[i+1].is_finite() or not faces[i+2].is_finite():return []
  var b=AABB(faces[i],Vector3.ZERO).expand(faces[i+1]).expand(faces[i+2])
  merged=b if triangles.is_empty() else merged.merge(b);triangles.append(b)
  if triangles.size()==64:blocks.append({'bounds':merged,'triangles':triangles});triangles=[]
 if not triangles.is_empty():blocks.append({'bounds':merged,'triangles':triangles})
 return blocks
static func geometry_overlaps(blocks:Array,t:Transform3D,obstacle:AABB,wind:float)->bool:
 var local=t.affine_inverse()*obstacle.grow(.05)
 # Grass displacement is local before model transform; preserve full +/- .05 XZ wind range.
 if wind>0:local.position-=Vector3(wind,0,wind);local.size+=Vector3(wind*2,0,wind*2)
 for block in blocks:
  if not block.bounds.intersects(local):continue
  for triangle in block.triangles:
   if triangle.intersects(local):return true
 return false
func clear_scatter_workspace():
 if is_instance_valid(scatter_workspace):scatter_workspace.free()
 scatter_workspace=null
func reject(reason:String,root:Node3D=null)->Dictionary:
 clear_scatter_workspace()
 if publication_started_usec>0:timings['publication_segment_usec']=Time.get_ticks_usec()-publication_started_usec
 if delta_started_usec>0:timings.delta_screen_usec=Time.get_ticks_usec()-delta_started_usec
 if is_instance_valid(root):
  if root==pending_root:pending_root=null
  root.free()
 return {'ok':false,'reason':reason,'existing_world_mutated':false,'diagnostics':diagnostics.duplicate(true),'bed_status':bed_status.duplicate(true)}
func install()->Dictionary:
 if attempted:return result
 if preparing:
  await preparation_finished
  return result
 preparing=true;preparation_generation+=1
 var token=preparation_generation;var started=Time.get_ticks_usec()
 timings={'yield_count':0,'max_slice_usec':0,'max_support_guard_usec':0,'initial_snapshot_usec':0,'assets_usec':0,'final_snapshot_usec':0,'delta_screen_usec':0,'publication_usec':0}
 slice_started_usec=started
 var prepared=await prepare(token)
 # _exit_tree owns terminal cancellation and may already have released pending_root.
 if token!=preparation_generation:return result
 result=prepared;timings['total_elapsed_usec']=Time.get_ticks_usec()-started
 result['timings_usec']=timings.duplicate(true)
 preparing=false;attempted=true;preparation_finished.emit()
 return result
func capture_inputs()->Dictionary:
 if not active() or not is_inside_tree() or global_transform!=Transform3D.IDENTITY:return reject('Inactive/nonidentity host/controller')
 if host.has_node(ROOT_NAME):return reject('Existing or foreign owned root')
 var delivered_west=delivered_west_state()
 if not delivered_west.ok:return reject(delivered_west.reason)
 var west_runtime_state=capture_west_snapshot()
 if not west_runtime_state.ok:return reject(west_runtime_state.reason)
 if not is_instance_valid(host.four_area_gardens) or not host.four_area_gardens.result.get('ok',false):return reject('Existing gardens not ready')
 if not is_instance_valid(host.cooking_nook_visuals) or not host.cooking_nook_visuals.attempted or not host.cooking_nook_visuals.result.get('ok',false):return reject('Cooking nook not ready')
 if not is_instance_valid(host.player) or host.player.is_queued_for_deletion() or not host.player.is_inside_tree():return reject('Active player unavailable')
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
 var frozen_paths=[]
 for poly in paths:frozen_paths.append(poly.duplicate())
 paths=frozen_paths
 var inspector=Gardens.new();inspector.host=host
 var ground=inspector.ground_supports()
 if not ground.ok:inspector.free();return reject(ground.reason)
 var turf=host.get_node_or_null('SettlementTerrain/GroundRelief');var relief=host.get_node_or_null('SettlementTerrain/WalkableRelief')
 if not turf is MeshInstance3D or turf.mesh==null or not relief is StaticBody3D:inspector.free();return reject('Original terrain owners missing')
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
 # Bind existing seats, then protect their actual six exit probes and front approach.
 # No new bench registration, collider, position, or material changes here.
 for label in ['HallGardenBenchWest','HallGardenBenchEast']:
  var bench=host.get_node_or_null(label)
  if not bench is Node3D or bench.get_parent()!=host or bench.is_queued_for_deletion() or not bench.is_in_group('usable_seats'):inspector.free();return reject('Existing Hall seat missing: '+label)
  var expected=Node3D.new();var side=-1 if label=='HallGardenBenchWest' else 1
  expected.position=Vector3(side*14.4,0,-25);expected.rotation.y=side*PI/2
  var expected_transform=expected.transform;expected.free()
  if bench.global_transform!=expected_transform:inspector.free();return reject('Existing Hall seat transform changed: '+label)
  var expected_exits=[Vector3(0,.01,-1.05),Vector3(-.6,.01,-1.05),Vector3(.6,.01,-1.05),Vector3(0,.01,-.65),Vector3(-.65,.01,-.65),Vector3(.65,.01,-.65)]
  var exits=bench.get_meta('seat_exit_local',[])
  if bench.get_meta('seat_local_origin',null)!=Vector3(0,.52,-.14) or exits!=expected_exits:inspector.free();return reject('Existing Hall seat metadata changed: '+label)
  for local in exits:
   if not local is Vector3:inspector.free();return reject('Malformed seat exit: '+label)
   var exit=bench.to_global(local);reserved.append(Rect2(exit.x-.45,exit.z-.45,.9,.9))
  reserved.append(rect(bench.global_transform*AABB(Vector3(-.95,0,-1.5),Vector3(1.9,2,.95))))
 for area in preload('res://scripts/hideout_terrace.gd').reservations()+preload('res://scripts/market_landscape.gd').envelopes():reserved.append(rect(area))
 var occupied=[]
 for mesh in host.find_children('*','MeshInstance3D',true,false):
  if mesh.mesh==null or not mesh.is_visible_in_tree():continue
  if mesh==turf:continue
  # Only the four exact live render-support references; no other Hall/low geometry exemption.
  if mesh in support_visuals:continue
  collect_mesh(mesh.mesh,mesh.global_transform,occupied,str(host.get_path_to(mesh)))
 for batch in host.find_children('*','MultiMeshInstance3D',true,false):
  if not batch.is_visible_in_tree() or batch.multimesh==null or batch.multimesh.mesh==null:continue
  if inspector.fine_lawn(batch):continue # Exact inherited blade geometry/shader/lineage contract; buffers remain untouched.
  var mm=batch.multimesh;var count=mm.instance_count if mm.visible_instance_count<0 else mini(mm.visible_instance_count,mm.instance_count)
  for i in range(count):collect_mesh(mm.mesh,batch.global_transform*mm.get_instance_transform(i),occupied,str(host.get_path_to(batch))+" instance="+str(i))
 inspector.free()
 var solids=[]
 for c in host.find_children('*','CollisionShape3D',true,false):
  if c.disabled or c.shape==null or not c.get_parent() is StaticBody3D:continue
  if c in ground.shapes or c.get_parent()==relief:continue
  if c.shape is ConcavePolygonShape3D:
   var faces=c.shape.get_faces()
   for i in range(0,faces.size(),3):
    var b=AABB(c.global_transform*faces[i],Vector3.ZERO)
    b=b.expand(c.global_transform*faces[i+1]);b=b.expand(c.global_transform*faces[i+2]);solids.append({'bounds':b,'owner':str(host.get_path_to(c)),'primitive':'collision_triangle_aabb','triangle':i/3})
  else:solids.append({'bounds':c.global_transform*c.shape.get_debug_mesh().get_aabb(),'owner':str(host.get_path_to(c)),'primitive':'collision_shape_aabb'})
 var support_state=capture_support_state(ground,turf,relief,support_visuals)
 if not support_state.ok:return reject(support_state.reason)
 return {'ok':true,'paths':paths,'reserved':reserved,'occupied':occupied,'solids':solids,'ground':ground,'turf':turf,'relief':relief,'support_visuals':support_visuals,'support_state':support_state,'delivered_west':delivered_west,'west_runtime_state':west_runtime_state}
func prepare(token:int)->Dictionary:
 diagnostics['phase']='wait_for_shipped_west'
 var prerequisite_started=Time.get_ticks_usec();var prerequisite=await wait_for_delivered_west(token)
 timings['prerequisite_wait_usec']=Time.get_ticks_usec()-prerequisite_started
 if not prerequisite.ok:return reject(prerequisite.reason)
 slice_started_usec=Time.get_ticks_usec()
 diagnostics['phase']='load_recipe'
 var load_started=Time.get_ticks_usec()
 var loaded=Recipe.load_recipe(bake_path,bake_sha256,GRASS_SHADER,FOLIAGE_SHADER)
 timings['recipe_load_usec']=Time.get_ticks_usec()-load_started
 if not loaded.ok:return reject(loaded.reason)
 var recipe=loaded.data;var reference=recipe.reference;var journal=recipe.journal.duplicate(true)
 var counts=recipe.counts.duplicate(true);bed_status=recipe.bed_status.duplicate(true)
 var refused=reference.accepted.get('refused',{}).duplicate(true)
 diagnostics['phase']='initial_snapshot'
 var snapshot_started=Time.get_ticks_usec();var inputs=capture_inputs()
 timings.initial_snapshot_usec=Time.get_ticks_usec()-snapshot_started
 if not inputs.ok:return inputs
 var matched=Recipe.match_inputs(self,inputs,reference.initial)
 if not matched.ok:return reject(matched.reason)
 diagnostics['phase']='prepare_bound_meshes'
 var root=Node3D.new();root.name=ROOT_NAME;pending_root=root;var templates={}
 var assets_started=Time.get_ticks_usec()
 for asset in ASSETS:
  if budget_due():
   var resumed=await budget_yield(token,inputs)
   if not resumed.ok:return reject(resumed.reason,root)
  var packed=ResourceLoader.load('res://assets/quaternius/'+asset+'.gltf', 'PackedScene', ResourceLoader.CACHE_MODE_REUSE)
  if not packed is PackedScene:return reject('Missing existing art '+asset,root)
  var source=packed.instantiate()
  if not source is Node3D:
   if source!=null:source.free()
   return reject('Invalid art root '+asset,root)
  var meshes=source.find_children('*','MeshInstance3D',true,false)
  if source.transform!=Transform3D.IDENTITY or meshes.size()!=1 or meshes[0].get_parent()!=source or meshes[0].mesh==null or meshes[0].transform!=Transform3D.IDENTITY:source.free();return reject('Unexpected art transform '+asset,root)
  if asset.begins_with('CommonTree'):
   if meshes[0].mesh.get_surface_count()!=2:source.free();return reject('Unexpected tree surfaces '+asset,root)
   var trunk_material=meshes[0].get_active_material(0)
   if not trunk_material is StandardMaterial3D or trunk_material.normal_texture==null or not trunk_material.normal_texture.resource_path.contains('Bark_NormalTree_Normal'):source.free();return reject('Unexpected trunk surface '+asset,root)
  var private_mesh=meshes[0].mesh.duplicate()
  for surface in range(private_mesh.get_surface_count()):
   var original=meshes[0].get_active_material(surface)
   if not original is StandardMaterial3D or original.albedo_texture==null:source.free();return reject('Unexpected textured material '+asset,root)
   if asset.begins_with('CommonTree') and original.normal_texture!=null:
    var bark=original.duplicate() as StandardMaterial3D;bark.albedo_color=Color(.85,.85,.85);private_mesh.surface_set_material(surface,bark);continue
   var painted=ShaderMaterial.new();painted.shader=FOLIAGE_SHADER
   painted.set_shader_parameter('albedo_texture',original.albedo_texture)
   painted.set_shader_parameter('leaf_only',asset=='Bush_Common')
   private_mesh.surface_set_material(surface,painted)
  templates[asset]={'mesh':private_mesh,'material':null};source.free()
 for asset in ASSETS:
  if budget_due():
   var resumed=await budget_yield(token,inputs)
   if not resumed.ok:return reject(resumed.reason,root)
  if not templates.has(asset):continue
  var blocks=triangle_blocks(templates[asset].mesh)
  if blocks.is_empty():return reject('Unreadable candidate triangles '+asset,root)
  templates[asset]['blocks']=blocks
 timings.assets_usec=Time.get_ticks_usec()-assets_started
 var grass_templates={};var transforms={};var rows_by_region={}
 for label in Recipe.REGION_NAMES:
  var published=reference.published_grass[label];var blade=ArrayMesh.new()
  for surface in published.surfaces:
   if surface.get('primitive',-1)!=Mesh.PRIMITIVE_TRIANGLES or not surface.get('arrays') is Array:return reject('Baked blade surface invalid: '+label,root)
   blade.add_surface_from_arrays(surface.primitive,surface.arrays.duplicate(true))
  if blade.get_aabb()!=published.mesh_aabb:return reject('Reconstructed blade bounds differ from proof: '+label,root)
  var blocks=triangle_blocks(blade)
  if blocks.is_empty():return reject('Reconstructed blade triangles unavailable: '+label,root)
  var material=ShaderMaterial.new();material.shader=GRASS_SHADER
  material.set_shader_parameter('wind_strength',.08);material.set_shader_parameter('blade_height',1.0)
  grass_templates[label]={'mesh':blade,'blocks':blocks,'material':material,'rows':[],'culling':AABB()}
  transforms[label]={};rows_by_region[label]=[]
  for asset in ASSETS:transforms[label][asset]=[]
 for entry in journal:
  if budget_due():
   var resumed=await budget_yield(token,inputs)
   if not resumed.ok:return reject(resumed.reason,root)
  if not entry is Dictionary or not entry.get('region','') in Recipe.REGION_NAMES or not entry.get('transform') is Transform3D or not entry.get('bounds') is AABB or not entry.get('support') is Vector3:return reject('Invalid fixed recipe entry',root)
  var label=entry.region;var asset=entry.get('asset','');var t:Transform3D=entry.transform
  if asset!='ScatterGrass' and not templates.has(asset):return reject('Unknown fixed recipe asset',root)
  if not t.origin.is_finite() or not t.basis.x.is_finite() or not t.basis.y.is_finite() or not t.basis.z.is_finite() or t.basis.determinant()<=0:return reject('Invalid fixed recipe transform',root)
  var mesh=grass_templates[label].mesh if asset=='ScatterGrass' else templates[asset].mesh
  var expected:AABB=t*mesh.get_aabb()
  if asset=='ScatterGrass':
   expected=expected.grow(.08)
   if not entry.get('instance_custom') is Color or not entry.get('normal') is Vector3 or entry.get('wind_world',0.0)!=.08 or t.origin!=entry.support:return reject('Baked grass root/custom/wind contract changed',root)
   grass_templates[label].rows.append(entry)
   grass_templates[label].culling=expected if grass_templates[label].rows.size()==1 else grass_templates[label].culling.merge(expected)
  else:transforms[label][asset].append(t)
  if expected!=entry.bounds:return reject('Fixed recipe bounds differ from bound mesh',root)
  rows_by_region[label].append(entry)
 for label in Recipe.REGION_NAMES:
  var tree_count=0;var plant_count=0;var structural_count=0
  for asset in ASSETS:
   var count=transforms[label][asset].size()
   if asset=='CommonTree_3':tree_count+=count
   else:plant_count+=count
   if asset=='Bush_Common_Flowers':structural_count+=count
  var bed=bed_status[label];var grass=grass_templates[label];var published=reference.published_grass[label]
  if not bed.get('ok',false) or bed.get('plants',0)!=plant_count or bed.get('trees',0)!=tree_count or bed.get('structural',0)!=structural_count or plant_count<16 or structural_count<1 or tree_count<1 or bed.get('grass_clumps',-1)!=0 or bed.get('scatter_candidates',0)!=4000 or bed.get('grass_blades',0)!=grass.rows.size() or grass.rows.size()!=published.instance_count or counts[label]!=rows_by_region[label].size():return reject('Fixed regional recipe counts/minima mismatch: '+label,root)
  if grass.rows.is_empty() or grass.culling.grow(.01)!=published.custom_aabb:return reject('Fixed regional grass culling envelope mismatch: '+label,root)
 var screened=screen_recipe_delta(inputs,reference.initial,journal,templates,grass_templates,'initial')
 if not screened.ok:return reject('Initial bake obstacle check: '+screened.reason,root)
 timings['initial_changed_obstacle_records']=screened.changed_records
 journal=refuse_regions(root,screened.blocked_regions,counts,journal,refused)
 if journal.is_empty():return reject('Every fixed bed conflicts with current original scenery',root)
 diagnostics['phase']='build_fixed_instances'
 for label in Recipe.REGION_NAMES:
  if not bed_status[label].ok:continue
  var group=Node3D.new();group.name=label;root.add_child(group)
  for asset in ASSETS:
   var list=transforms[label][asset]
   if list.is_empty():continue
   var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=templates[asset].mesh;mm.instance_count=list.size()
   for i in range(list.size()):
    if budget_due():
     var resumed=await budget_yield(token,inputs)
     if not resumed.ok:return reject(resumed.reason,root)
    mm.set_instance_transform(i,list[i])
   var batch=MultiMeshInstance3D.new();batch.name=asset;batch.multimesh=mm;batch.material_override=templates[asset].material;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if asset=='CommonTree_3' else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;group.add_child(batch)
   if asset=='CommonTree_3':
    var trunk=ArrayMesh.new();trunk.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,templates[asset].mesh.surface_get_arrays(0).duplicate(true))
    var faces=trunk.get_faces()
    if faces.is_empty() or faces.size()%3!=0:return reject('Empty/malformed trunk triangles '+asset,root)
    for point in faces:
     if not point.is_finite():return reject('Nonfinite trunk triangle '+asset,root)
    var shape=ConcavePolygonShape3D.new();shape.set_faces(faces)
    for i in range(list.size()):
     if budget_due():
      var resumed=await budget_yield(token,inputs)
      if not resumed.ok:return reject(resumed.reason,root)
     var body=StaticBody3D.new();body.name=asset+'Trunk'+str(i);var collider=CollisionShape3D.new();collider.shape=shape;body.add_child(collider);body.transform=list[i];group.add_child(body)
  var grass=grass_templates[label];var grass_mm=MultiMesh.new();grass_mm.transform_format=MultiMesh.TRANSFORM_3D;grass_mm.use_custom_data=true;grass_mm.mesh=grass.mesh;grass_mm.instance_count=grass.rows.size()
  for i in range(grass.rows.size()):
   if budget_due():
    var resumed=await budget_yield(token,inputs)
    if not resumed.ok:return reject(resumed.reason,root)
   grass_mm.set_instance_transform(i,grass.rows[i].transform);grass_mm.set_instance_custom_data(i,grass.rows[i].instance_custom)
  grass_mm.custom_aabb=grass.culling.grow(.01)
  var grass_batch=MultiMeshInstance3D.new();grass_batch.name='DeliveredSingleBladeGrass';grass_batch.multimesh=grass_mm;grass_batch.material_override=grass.material;grass_batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;group.add_child(grass_batch)
 if not preparation_active(token):return reject('Cancelled before baked publication',root)
 record_slice();var final_started=Time.get_ticks_usec();publication_started_usec=final_started
 diagnostics['phase']='final_snapshot'
 var current=capture_inputs();timings.final_snapshot_usec=Time.get_ticks_usec()-final_started
 if not current.ok:return reject('Final bake inputs: '+str(current.reason),root)
 if current.support_state!=inputs.support_state:return reject('Support identity/geometry changed during fixed build',root)
 if current.delivered_west!=inputs.delivered_west or current.west_runtime_state!=inputs.west_runtime_state:return reject('Shipped West checked snapshot changed during fixed build',root)
 matched=Recipe.match_inputs(self,current,reference.initial)
 if not matched.ok:return reject('Final bake support/path/West check: '+matched.reason,root)
 var delta_started=Time.get_ticks_usec();delta_started_usec=delta_started
 screened=screen_recipe_delta(current,reference.initial,journal,templates,grass_templates,'final')
 if not screened.ok:return reject('Final bake obstacle check: '+screened.reason,root)
 timings.delta_screen_usec=Time.get_ticks_usec()-delta_started;delta_started_usec=0
 timings['changed_obstacle_records']=screened.changed_records
 var player=player_capsule_bounds()
 if not player.ok:return reject(player.reason,root)
 var blocked=screened.blocked_regions
 for entry in journal:
  if entry.asset=='CommonTree_3' and entry.bounds.grow(.05).intersects(player.bounds):blocked[entry.region]='Current player capsule overlaps baked tree'
 journal=refuse_regions(root,blocked,counts,journal,refused)
 if journal.is_empty() or root.get_child_count()==0:return reject('Every fixed bed failed current publication checks',root)
 if not preparation_active(token) or host.has_node(ROOT_NAME):return reject('Cancelled/conflicting root before baked publication',root)
 var publish_started=Time.get_ticks_usec();host.add_child(root);visual=root;pending_root=null
 timings.publication_usec=Time.get_ticks_usec()-publish_started;timings['publication_segment_usec']=Time.get_ticks_usec()-final_started;publication_started_usec=0
 record_slice();diagnostics['phase']='published'
 return {'ok':true,'counts':counts,'refused':refused,'diagnostics':diagnostics.duplicate(true),'bed_status':bed_status.duplicate(true),'journal':journal,'new_colliders':root.find_children('*','CollisionShape3D',true,false).size(),'existing_world_mutated':false,'baked_reuse':true,'runtime_sampling':false,'recipe_sha256':bake_sha256,'scope':'Exact fixed Hall-east/spur recipe with current support/route/West/obstacle/player revalidation; no runtime scatter'}
func screen_recipe_delta(current:Dictionary,initial:Dictionary,journal:Array,templates:Dictionary,grass_templates:Dictionary,phase:String)->Dictionary:
 var delta=changed_obstacles(initial.occupied,current.occupied)
 delta.append_array(changed_obstacles(initial.solids,current.solids))
 diagnostics['phase']=phase+'_obstacle_screen';diagnostics[phase+'_changed_obstacle_records']=delta.size()
 var index=ObstacleIndex.build(delta)
 if not index.ok:return {'ok':false,'reason':'Malformed changed obstacle index'}
 var blocked={};var blockers={}
 for entry in journal:
  if blocked.has(entry.region):continue
  for other in ObstacleIndex.candidates(index,entry.bounds.grow(.05)):
   if not entry.bounds.grow(.05).intersects(other.bounds):continue
   var overlap_now=Recipe.world_wind_overlaps(grass_templates[entry.region].blocks,entry.transform,other.bounds) if entry.asset=='ScatterGrass' else geometry_overlaps(templates[entry.asset].blocks,entry.transform,other.bounds,0.0)
   if overlap_now:
    blocked[entry.region]='Current obstruction overlaps fixed garden: '+str(other.owner)
    blockers[entry.region]={'owner':other.owner,'asset':entry.asset,'candidate_bounds':entry.bounds,'obstacle_bounds':other.bounds};break
 diagnostics[phase+'_blocking_obstacles']=blockers
 return {'ok':true,'changed_records':delta.size(),'blocked_regions':blocked}
func refuse_regions(root:Node3D,blocked:Dictionary,counts:Dictionary,journal:Array,refused:Dictionary)->Array:
 if blocked.is_empty():return journal
 var kept=[]
 for entry in journal:
  if not blocked.has(entry.region):kept.append(entry)
 for label in blocked:
  var group=root.get_node_or_null(NodePath(str(label)))
  if group!=null:group.free()
  refused[label]=int(refused.get(label,0))+int(counts.get(label,0));counts[label]=0
  bed_status[label]['ok']=false;bed_status[label]['reason']=str(blocked[label])
 return kept
func budget_due()->bool:return Time.get_ticks_usec()-slice_started_usec>=PREPARATION_BUDGET_USEC
func record_slice():
 timings.max_slice_usec=maxi(int(timings.max_slice_usec),slice_guard_usec+Time.get_ticks_usec()-slice_started_usec)
func preparation_active(token:int)->bool:
 return token==preparation_generation and preparing and active() and global_transform==Transform3D.IDENTITY and is_instance_valid(pending_root) and not pending_root.is_queued_for_deletion() and pending_root.get_parent()==null
func budget_yield(token:int,inputs:Dictionary)->Dictionary:
 record_slice();timings.yield_count+=1
 var tree=get_tree()
 await tree.process_frame
 if not preparation_active(token) or get_tree()!=tree:return {'ok':false,'reason':'Cancelled before physics-safe preparation slice'}
 await tree.physics_frame
 # Always validate before dereferencing detached children or captured live nodes.
 if not preparation_active(token) or get_tree()!=tree:return {'ok':false,'reason':'Cancelled during detached preparation'}
 if not is_instance_valid(host.player) or host.player.is_queued_for_deletion() or not host.player.is_inside_tree():return {'ok':false,'reason':'Player unavailable after preparation yield'}
 var guard_started=Time.get_ticks_usec();var west_now=capture_west_snapshot()
 var west_unchanged=west_now.ok and west_now==inputs.west_runtime_state
 slice_guard_usec=Time.get_ticks_usec()-guard_started
 timings['max_west_guard_usec']=maxi(int(timings.get('max_west_guard_usec',0)),slice_guard_usec)
 timings['total_west_guard_usec']=int(timings.get('total_west_guard_usec',0))+slice_guard_usec
 if not west_now.ok:return west_now
 if not west_unchanged:return {'ok':false,'reason':'Shipped West checked snapshot changed during fixed build'}
 # Fixed geometry construction performs no live support queries or acceptance.
 # Full support equality is required at initial and final synchronous snapshots.
 slice_started_usec=Time.get_ticks_usec()
 return {'ok':true}
static func support_shape_geometry(shape:Shape3D)->Dictionary:
 # Actual immutable shape data, not resource identity or an AABB-only checksum.
 if shape is BoxShape3D:return {'id':shape.get_instance_id(),'kind':'box','size':shape.size}
 if shape is ConcavePolygonShape3D:return {'id':shape.get_instance_id(),'kind':'concave','faces':shape.get_faces().duplicate(),'backface_collision':shape.backface_collision}
 if shape is ConvexPolygonShape3D:return {'id':shape.get_instance_id(),'kind':'convex','points':shape.points.duplicate()}
 if shape is HeightMapShape3D:return {'id':shape.get_instance_id(),'kind':'heightmap','width':shape.map_width,'depth':shape.map_depth,'data':shape.map_data.duplicate()}
 # The inherited support contract uses boxes and relief triangle meshes. New
 # unsupported support types refuse rather than silently weakening that contract.
 return {}
func capture_support_state(ground:Dictionary,turf,relief,support_visuals:Array)->Dictionary:
 if not is_instance_valid(turf) or not turf is MeshInstance3D or turf.is_queued_for_deletion() or not turf.is_inside_tree() or turf.mesh==null:return {'ok':false,'reason':'Terrain render support unavailable'}
 if not is_instance_valid(relief) or not relief is StaticBody3D or relief.is_queued_for_deletion() or not relief.is_inside_tree():return {'ok':false,'reason':'Terrain physical support unavailable'}
 if ground.shapes.is_empty() or not is_instance_valid(ground.shapes[0]):return {'ok':false,'reason':'Split ground supports unavailable'}
 var body=ground.shapes[0].get_parent()
 if not body is StaticBody3D or not body.is_inside_tree() or body.is_queued_for_deletion():return {'ok':false,'reason':'Split ground owner unavailable'}
 var render_owner=host.get_node_or_null('HallBasementBlockout')
 if not render_owner is Node3D or render_owner.is_queued_for_deletion():return {'ok':false,'reason':'Split ground render owner unavailable'}
 var out={'ok':true,'turf':[turf.get_instance_id(),turf.get_parent().get_instance_id(),turf.global_transform,turf.is_visible_in_tree(),turf.mesh.get_instance_id(),turf.mesh.get_aabb(),turf.mesh.get_faces().duplicate()],'bodies':[],'shapes':[],'renders':[],'render_owner':[render_owner.get_instance_id(),render_owner.get_parent().get_instance_id(),render_owner.global_transform,render_owner.get_child_count()]}
 for owner in [body,relief]:
  out.bodies.append([owner.get_instance_id(),owner.get_parent().get_instance_id(),owner.global_transform,owner.collision_layer,owner.collision_mask])
 var shapes=body.get_children()
 if shapes!=ground.shapes:return {'ok':false,'reason':'Split ground support membership changed'}
 shapes=shapes.duplicate();shapes.append_array(relief.find_children('*','CollisionShape3D',true,false))
 for c in shapes:
  if not is_instance_valid(c) or not c is CollisionShape3D or c.is_queued_for_deletion() or not c.is_inside_tree() or c.shape==null:return {'ok':false,'reason':'Physical support shape unavailable'}
  var geometry=support_shape_geometry(c.shape)
  if geometry.is_empty():return {'ok':false,'reason':'Unsupported physical support shape '+c.shape.get_class()}
  out.shapes.append([c.get_instance_id(),c.get_parent().get_instance_id(),c.global_transform,c.disabled,geometry])
 for mesh in support_visuals:
  if not is_instance_valid(mesh) or mesh.is_queued_for_deletion() or not mesh.is_inside_tree() or not mesh.mesh is BoxMesh:return {'ok':false,'reason':'Split ground render support unavailable'}
  out.renders.append([mesh.get_instance_id(),mesh.get_parent().get_instance_id(),mesh.global_transform,mesh.is_visible_in_tree(),mesh.mesh.get_instance_id(),mesh.mesh.size])
 return out
static func obstacle_groups(records:Array)->Dictionary:
 var groups={}
 for row in records:
  if not groups.has(row.owner):groups[row.owner]=[]
  groups[row.owner].append(row)
 return groups
static func changed_obstacles(before:Array,now:Array)->Array:
 # A fresh scene traversal catches moved/new/unhidden/reparented owners and changed
 # meshes or MultiMesh instance buffers. Deletions only leave a conservative gap.
 var old=obstacle_groups(before);var current=obstacle_groups(now);var delta=[]
 for owner in current:
  if not old.has(owner) or old[owner]!=current[owner]:delta.append_array(current[owner])
 return delta
func player_capsule_bounds()->Dictionary:
 if not is_instance_valid(host.player) or host.player.is_queued_for_deletion() or not host.player.is_inside_tree():return {'ok':false,'reason':'Current player unavailable for tree publication'}
 var c=host.player.body_shape
 if not is_instance_valid(c) or not c is CollisionShape3D or c.is_queued_for_deletion() or not c.is_inside_tree() or c.disabled or not c.shape is CapsuleShape3D:return {'ok':false,'reason':'Current player capsule unavailable for tree publication'}
 return {'ok':true,'bounds':c.global_transform*c.shape.get_debug_mesh().get_aabb()}
func _exit_tree():
 clear_scatter_workspace()
 preparation_generation+=1
 if is_instance_valid(pending_root):pending_root.free()
 pending_root=null
 if preparing:
  result=reject('Controller left tree during preparation')
  result['timings_usec']=timings.duplicate(true)
  preparing=false;attempted=true;preparation_finished.emit()
 if is_instance_valid(visual):visual.queue_free()


# Keep full journals in result for validation; avoid megabyte console serialization.
func compact_result()->Dictionary:
 var summary={}
 for key in ['ok','reason','counts','bed_status','timings_usec','new_colliders','baked_reuse','runtime_sampling','recipe_sha256']:
  if result.has(key):summary[key]=result[key]
 return summary
