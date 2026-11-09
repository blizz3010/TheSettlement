extends Node3D
# Local decorative paving only. No collision, service, cooking or save mutation.
const PAD=Rect2(-12.1,6.15,1.8,2.8)
const Z0=6.35
const Z1=7.45
var host
var requested=false
var attempted=false
var result:Dictionary={}
var grass_journal:Array=[]
var installed_stamp:Dictionary={}
var installed_result:Dictionary={}
func setup(world):name='CookingNookVisuals';host=world
func active()->bool:
 return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(host) and host.is_inside_tree() and not host.is_queued_for_deletion() and host.world_initialized and not host.startup_cancel_requested and (not host.staged_startup or host.world_activated or host.startup_preparing_assets)
func begin_after_activation(world):
 if requested or attempted or not is_inside_tree() or is_queued_for_deletion():return
 setup(world)
 if not active():return
 requested=true
 var tree=get_tree()
 while active():
  if not is_instance_valid(host.park_west_visuals) or host.park_west_visuals.is_queued_for_deletion():result=fail('West park prerequisite missing');attempted=true;return
  if not host.park_west_visuals.requested and not host.park_west_visuals.attempted:result=fail('West park activation unavailable');attempted=true;return
  if not is_instance_valid(host.four_area_gardens) or host.four_area_gardens.is_queued_for_deletion():result=fail('Landscape prerequisite missing');attempted=true;return
  if not host.four_area_gardens.requested and not host.four_area_gardens.attempted:result=fail('Landscape activation unavailable');attempted=true;return
  if not host.four_area_gardens.result.is_empty() and not host.four_area_gardens.result.get('ok',false):result=fail('Landscape installation failed');attempted=true;return
  if host.park_west_visuals.attempted and host.four_area_gardens.attempted:break
  await tree.physics_frame
 if not active():return
 result=install();attempted=true
static func fail(reason:String)->Dictionary:return {'ok':false,'reason':reason}
static func edge_at(poly:PackedVector2Array,z:float)->Variant:
 var hits=[]
 for i in range(poly.size()):
  var a=poly[i];var b=poly[(i+1)%poly.size()]
  if (a.y<=z and b.y>z) or (b.y<=z and a.y>z):hits.append(a.x+(z-a.y)*(b.x-a.x)/(b.y-a.y))
 if hits.size()!=2:return null
 return minf(hits[0],hits[1])
static func rect_poly(rect:Rect2)->PackedVector2Array:
 return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
static func grass_stamp(batch:MultiMeshInstance3D,mm:MultiMesh)->Dictionary:
 return {'transform':batch.transform,'visible':batch.visible,'layers':batch.layers,'mm':mm,'mesh':mm.mesh,'mesh_arrays':var_to_bytes(mm.mesh.surface_get_arrays(0)).hex_encode().sha256_text(),'mesh_primitive':mm.mesh.surface_get_primitive_type(0),'buffer':var_to_bytes(mm.buffer).hex_encode().sha256_text(),'format':mm.transform_format,'colors':mm.use_colors,'custom':mm.use_custom_data,'count':mm.instance_count,'visible_count':mm.visible_instance_count}
static func grass_row_valid(row:Dictionary)->bool:
 var batch=row.node.get_ref()
 if not is_instance_valid(batch) or batch.is_queued_for_deletion() or batch.multimesh!=row.after:return false
 if not row.before.mesh is ArrayMesh or not row.after.mesh is ArrayMesh or row.before.mesh.get_surface_count()!=1 or row.after.mesh.get_surface_count()!=1:return false
 return grass_stamp(batch,row.after)==row.after_stamp and grass_stamp(batch,row.before)==row.before_stamp
func visual_stamp(mesh:MeshInstance3D)->Dictionary:
 var material=mesh.material_override
 var values={}
 if material is ShaderMaterial and material.shader!=null:
  for param in material.shader.get_shader_uniform_list():values[param.name]=material.get_shader_parameter(param.name)
 return {'node':mesh.get_instance_id(),'transform':mesh.transform,'visible':mesh.visible,'layers':mesh.layers,'mesh':mesh.mesh,'primitive':mesh.mesh.surface_get_primitive_type(0),'arrays':var_to_bytes(mesh.mesh.surface_get_arrays(0)).hex_encode().sha256_text(),'material':material,'shader':material.shader if material is ShaderMaterial else null,'parameters':values}
func owned_valid()->bool:
 if transform!=Transform3D.IDENTITY or not is_instance_valid(host) or host.global_transform!=Transform3D.IDENTITY or get_child_count()!=1:return false
 var node=get_child(0)
 if not node is MeshInstance3D or node.is_queued_for_deletion() or node.mesh==null or node.mesh.get_surface_count()!=1:return false
 if visual_stamp(node)!=installed_stamp:return false
 for row in grass_journal:
  if not grass_row_valid(row):return false
 return true
static func polygon_area(poly:PackedVector2Array)->float:
 var sum=0.0
 for i in range(poly.size()):sum+=poly[i].cross(poly[(i+1)%poly.size()])
 return absf(sum)*.5
static func on_edge(p:Vector2,poly:PackedVector2Array)->bool:
 for i in range(poly.size()):
  if p.distance_to(Geometry2D.get_closest_point_to_segment(p,poly[i],poly[(i+1)%poly.size()]))<=.00003:return true
 return false
func retained_stone(boundary:PackedVector2Array)->Dictionary:
 var terrace=host.get_node_or_null('RaisedHideoutTerrace');var path=host.get_node_or_null('RaisedHideoutTerrace/Approach path')
 if terrace==null or not path is Node3D or path.is_queued_for_deletion():return fail('Named original approach slab missing')
 var shapes=path.find_children('*','CollisionShape3D',true,false)
 if shapes.size()!=1 or shapes[0].is_queued_for_deletion() or shapes[0].disabled or not shapes[0].shape is BoxShape3D:return fail('Named slab collider changed')
 var col=shapes[0];var size=col.shape.size
 if not size.is_equal_approx(Vector3(2.6,.08,sqrt(13.0)+.25)) or col.global_position.distance_to(Vector3(-6,.015,8.5))>.00002:return fail('Named slab dimensions changed')
 var expected_basis=Basis.looking_at(Vector3(-7,.015,10)-Vector3(-6,.015,8.5),Vector3.UP)
 for axis in [0,1,2]:
  if col.global_transform.basis[axis].distance_to(expected_basis[axis])>.00002:return fail('Named slab orientation changed')
 var matches=[]
 for batch in terrace.find_children('*','MultiMeshInstance3D',true,false):
  var mm=batch.multimesh
  if batch.is_queued_for_deletion() or not batch.is_visible_in_tree() or mm==null or not mm.mesh is BoxMesh or mm.mesh.size!=Vector3.ONE:continue
  for i in range(mm.instance_count):
   if mm.visible_instance_count!=-1 and i>=mm.visible_instance_count:continue
   var t=batch.global_transform*mm.get_instance_transform(i)
   if t.origin.distance_to(col.global_position)>.00002:continue
   var exact=true;var vertices=PackedVector3Array();var points=PackedVector2Array()
   for x in [-.5,.5]:
    for y in [-.5,.5]:
     for z in [-.5,.5]:
      var local=Vector3(x,y,z);var v=t*local
      if v.distance_to(col.global_transform*(local*size))>.00002:exact=false
      vertices.append(v);points.append(Vector2(v.x,v.z))
   if not exact:return fail('Approach render/collider geometry mismatch')
   var poly=Geometry2D.convex_hull(points)
   if poly.size()!=5 or poly[0]!=poly[4]:return fail('Unexpected approach slab polygon')
   poly.resize(4)
   var top=-INF
   for v in vertices:top=maxf(top,v.y)
   matches.append({'batch_path':str(host.get_path_to(batch)),'instance':i,'transform':t,'polygon':poly,'aabb':load('res://scripts/intentional_planting_pockets.gd').rectangle(t*mm.mesh.get_aabb()),'top':top,'collider_path':str(host.get_path_to(col))})
 if matches.size()!=1:return fail('Approach slab render match is not unique')
 var supports=[]
 for mesh in host.get_children():
  if not mesh is MeshInstance3D or not mesh.mesh is CylinderMesh:continue
  if mesh.mesh.top_radius!=10 or mesh.mesh.bottom_radius!=10 or mesh.mesh.radial_segments!=64 or not is_equal_approx(mesh.mesh.height,.14):continue
  if mesh.global_position.distance_to(Vector3(0,-.02,0))>.00002:continue
  var points=PackedVector2Array();var top=-INF
  for vertex in mesh.mesh.get_faces():
   var v=mesh.global_transform*vertex;points.append(Vector2(v.x,v.z));top=maxf(top,v.y)
  var hull=Geometry2D.convex_hull(points)
  if hull.size()!=65 or hull[0]!=hull[64]:return fail('Plaza support hull changed')
  hull.resize(64)
  if hull!=boundary:return fail('Plaza metadata differs from actual support')
  supports.append({'path':str(host.get_path_to(mesh)),'top':top})
 if supports.size()!=1:return fail('Plaza support match is not unique')
 return {'ok':true,'slab':matches[0],'plaza':supports[0]}
func install()->Dictionary:
 if not active() or transform!=Transform3D.IDENTITY or host.global_transform!=Transform3D.IDENTITY:return fail('Inactive or transformed host')
 if get_child_count()!=0:
  if not owned_valid():return fail('Foreign or stale nook')
  return installed_result.duplicate(true)
 for controller in [host.cooking_test,host.park_layered_visuals,host.park_west_visuals]:
  if not is_instance_valid(controller) or controller.is_queued_for_deletion():return fail('Missing or queued prerequisite')
 if not is_instance_valid(host.cooking_test.station) or not host.park_layered_visuals.result.get('ok',false) or not host.park_west_visuals.result.get('ok',false):return fail('Cooking and parks must finish first')
 for controller in [host.park_layered_visuals,host.park_west_visuals]:
  if not is_instance_valid(controller.visual) or controller.visual.is_queued_for_deletion() or not controller.visual.is_inside_tree():return fail('Park visual missing or queued')
 var station=host.cooking_test.station
 if station.global_position.distance_to(Vector3(-11.2,-.05,6.7))>.02:return fail('Unexpected griddle location')
 var tiles=host.get_node_or_null('SupportedPlazaTiles')
 if tiles==null or not tiles.has_meta('support_polygon'):return fail('Actual plaza boundary unavailable')
 var boundary=tiles.get_meta('support_polygon')
 # Geometry2D.convex_hull closes its64-vertex result by repeating vertex0.
 if not boundary is PackedVector2Array or boundary.size()!=65:return fail('Expected closed64-vertex plaza hull')
 if boundary[0]!=boundary[64]:return fail('Plaza hull is not exactly closed')
 boundary=boundary.duplicate();boundary.resize(64)
 for p in boundary:
  if not p.is_finite() or absf(p.length()-10)>.002:return fail('Unexpected plaza footprint')
 var x0=edge_at(boundary,Z0);var x1=edge_at(boundary,Z1)
 if x0==null or x1==null or x0<-8 or x0>-6 or x1<-8 or x1>-6:return fail('Plaza attachment outside expected sector')
 var donor=tiles.get_node_or_null('Paver_-8_5')
 if not donor is MeshInstance3D or donor.mesh==null or not donor.material_override is ShaderMaterial:return fail('Exact plaza stone donor unavailable')
 var apron=PackedVector2Array([Vector2(PAD.end.x-.02,Z0),Vector2(x0+.025,Z0),Vector2(x1+.025,Z1),Vector2(PAD.end.x-.02,Z1)])
 var merged=Geometry2D.merge_polygons(rect_poly(PAD),apron)
 if merged.size()!=1:return fail('Disconnected nook paving')
 var footprint:PackedVector2Array=merged[0]
 var stone=retained_stone(boundary)
 if not stone.ok:return stone
 var joined=Geometry2D.merge_polygons(boundary,stone.slab.polygon)
 if joined.size()!=1:return fail('Existing stone union is ambiguous')
 var clipped=Geometry2D.clip_polygons(footprint,joined[0])
 if clipped.size()!=1 or clipped[0].size()<3 or Geometry2D.is_polygon_clockwise(clipped[0]):return fail('New paving is empty, disconnected or a hole')
 var before_area=polygon_area(footprint);footprint=clipped[0]
 if polygon_area(footprint)<=0 or not Geometry2D.intersect_polygons(footprint,boundary).is_empty() or not Geometry2D.intersect_polygons(footprint,stone.slab.polygon).is_empty():return fail('New paving still overlaps original stone')
 # These later-installed meshes must be checked here, never awaited by cooking itself.
 for park in [host.park_layered_visuals.visual,host.park_west_visuals.visual]:
  for mesh in park.find_children('*','MeshInstance3D',true,false):
   var box=mesh.global_transform*mesh.mesh.get_aabb()
   if not Geometry2D.intersect_polygons(footprint,rect_poly(Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)))).is_empty():return fail('Installed park overlaps nook')
 # Preserve authored vegetation, including the47 additions; only fine lawn tufts are clipped below.
 var Plants=load('res://scripts/intentional_planting_pockets.gd')
 var all_authored=Plants.live_existing_foliage(host);var stone_rows=[]
 for i in range(all_authored.size()):
  if all_authored[i]==stone.slab.aabb:stone_rows.append(i)
 if stone_rows.size()!=1:return fail('Exact retained stone preservation row not unique')
 for i in range(all_authored.size()):
  var poly=stone.slab.polygon if i==stone_rows[0] else all_authored[i]
  if not Geometry2D.intersect_polygons(footprint,poly).is_empty():return fail('Authored geometry overlaps apron')
 var pockets=host.get_node_or_null('IntentionalPlantingPockets')
 if pockets==null:return fail('Plant layer unavailable')
 for batch in pockets.get_children():
  if not batch is MultiMeshInstance3D:return fail('Unexpected planting child')
  for i in range(batch.multimesh.instance_count):
   var box=(batch.global_transform*batch.multimesh.get_instance_transform(i))*batch.multimesh.mesh.get_aabb()
   if not Geometry2D.intersect_polygons(footprint,rect_poly(Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)))).is_empty():return fail('Existing47 planting overlaps apron')
 var gardens=host.get_node_or_null('FourAreaGardens')
 if gardens==null or gardens.is_queued_for_deletion() or not is_instance_valid(host.four_area_gardens) or host.four_area_gardens.is_queued_for_deletion() or not host.four_area_gardens.result.get('ok',false):return fail('Installed landscaping unavailable')
 for node in gardens.find_children('*','Node3D',true,false):
  var bounds=[]
  if node is MeshInstance3D and node.mesh!=null:bounds.append(node.global_transform*node.mesh.get_aabb())
  elif node is MultiMeshInstance3D and node.multimesh!=null:
   var mm=node.multimesh
   if mm.mesh==null:return fail('Landscape mesh missing')
   for i in range(mm.instance_count):bounds.append((node.global_transform*mm.get_instance_transform(i))*mm.mesh.get_aabb())
  for box in bounds:
   if not Geometry2D.intersect_polygons(footprint,rect_poly(Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)))).is_empty():return fail('New landscaping overlaps nook')
 var indices=Geometry2D.triangulate_polygon(footprint)
 if indices.is_empty():return fail('Invalid paving polygon')
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for index in indices:
  var p=footprint[index]
  # Actual retained surface heights: plaza .05, approach slab .055.
  # Edge classifier allows only clipper's numeric coordinate quantization, not geometric clearance.
  var y=-.035
  if on_edge(p,boundary):y=stone.plaza.top
  if on_edge(p,stone.slab.polygon):y=stone.slab.top
  surface.set_normal(Vector3.UP);surface.add_vertex(Vector3(p.x,y,p.y))
 var visual=MeshInstance3D.new();visual.name='ConnectedWorkPad';visual.mesh=surface.commit();visual.material_override=donor.material_override.duplicate(true)
 # Reuse the delivered world-aligned limestone joints; no new surface or raised edge.
 visual.material_override.shader=load('res://assets/route_limestone_candidate.gdshader')
 visual.material_override.set_shader_parameter('route_min_y',-1.0);visual.material_override.set_shader_parameter('route_max_y',1.0)
 visual.material_override.set_shader_parameter('slab_meters',.65);visual.material_override.set_shader_parameter('joint_width_meters',.016)
 var pending=[];var grass=host.get_node_or_null('ContinuousGrass')
 if grass==null:visual.free();return fail('Fine grass layer unavailable')
 var removed=0
 for batch in grass.get_children():
  if not batch is MultiMeshInstance3D:continue
  var old:MultiMesh=batch.multimesh
  if old==null or not old.mesh is ArrayMesh or old.mesh.get_surface_count()!=1 or old.visible_instance_count!=-1:visual.free();return fail('Invalid or selectively hidden grass batch')
  var aabb=batch.global_transform*old.get_aabb()
  if Geometry2D.intersect_polygons(footprint,rect_poly(Rect2(Vector2(aabb.position.x,aabb.position.z),Vector2(aabb.size.x,aabb.size.z)))).is_empty():continue
  var keep=[]
  for i in range(old.instance_count):
   var box=(batch.global_transform*old.get_instance_transform(i))*old.mesh.get_aabb()
   if Geometry2D.intersect_polygons(footprint,rect_poly(Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)))).is_empty():keep.append(i)
  if keep.size()==old.instance_count:continue
  var next=MultiMesh.new();next.transform_format=old.transform_format;next.use_colors=old.use_colors;next.use_custom_data=old.use_custom_data;next.mesh=old.mesh;next.instance_count=keep.size()
  for j in range(keep.size()):
   var i=keep[j];next.set_instance_transform(j,old.get_instance_transform(i))
   if old.use_colors:next.set_instance_color(j,old.get_instance_color(i))
   if old.use_custom_data:next.set_instance_custom_data(j,old.get_instance_custom_data(i))
  pending.append({'node':weakref(batch),'before':old,'after':next,'kept_indices':keep,'before_stamp':grass_stamp(batch,old),'after_stamp':grass_stamp(batch,next)});removed+=old.instance_count-keep.size()
 # Commit only after every geometry/resource preparation succeeds. No yield.
 add_child(visual)
 for row in pending:row.node.get_ref().multimesh=row.after
 grass_journal=pending
 installed_stamp=visual_stamp(visual)
 installed_result={'ok':true,'footprint':footprint,'plaza_boundary':boundary,'attachment':apron,'fine_tufts_removed':removed,'grass_batches':pending.size(),'colliders_added':0,'retained_stone':stone,'local_stone_row':stone_rows[0],'other_authored_rows_unchanged':all_authored.size()-1,'new_area_before_clip':before_area,'new_area_after_clip':polygon_area(footprint)}
 return installed_result.duplicate(true)
func _exit_tree():
 for row in grass_journal:
  var node=row.node.get_ref()
  if grass_row_valid(row):node.multimesh=row.before
 grass_journal.clear()
