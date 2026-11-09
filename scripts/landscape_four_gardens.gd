extends Node3D
# Four reference-led garden islands. Existing world resources and routes are read-only.
const ROOT_NAME='FourAreaGardens'
const REGIONS=[
 {'name':'PlazaApproach','center':Vector2(-3.4,12.0),'radii':Vector2(2.1,3.0),'tree':Vector2(-3.5,12.1)},
 {'name':'ShipViewIsland','center':Vector2(5.5,11.6),'radii':Vector2(3.4,2.1),'tree':Vector2(5.6,11.8)},
 {'name':'FountainEastBorder','center':Vector2(10.7,-3.8),'radii':Vector2(2.0,4.0),'tree':Vector2(10.7,-4.1)},
 {'name':'DanStairGarden','center':Vector2(-3.1,20.8),'radii':Vector2(2.8,3.0),'tree':Vector2(-3.3,21.0)}]
const ASSETS=['groundcover/ground_fern_a','groundcover/ground_shrub_a','groundcover/ground_flowers_purple','groundcover/ground_flowers_yellow','planting_dense/compact_broadleaf_mound','planting_dense/small_rock_group']
var host
var requested=false
var attempted=false
var result={}
var visual:Node3D
var prop_visuals=[]
var lawn_mesh:Mesh
func setup(world):
 name='FourAreaGardenController';host=world
func active()->bool:
 return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(host) and host.is_inside_tree() and not host.is_queued_for_deletion() and host.world_initialized and (not host.staged_startup or host.world_activated or host.startup_preparing_assets) and not host.startup_cancel_requested
func begin_after_activation(world):
 if requested or world!=host or not active():return
 requested=true
 var tree=get_tree()
 while active():
  if not is_instance_valid(host.cooking_test) or not is_instance_valid(host.park_layered_visuals) or not is_instance_valid(host.park_west_visuals):result={'ok':false,'reason':'Garden prerequisite missing'};return
  if host.park_west_visuals.is_queued_for_deletion() or not host.park_west_visuals.requested:result={'ok':false,'reason':'Original park cancelled'};return
  if host.park_west_visuals.attempted:break
  await tree.physics_frame
 if not active():return
 if not host.park_west_visuals.result.get('ok',false):result={'ok':false,'reason':'Original park not ready'};return
 result=install()
static func rect_poly(r:Rect2)->PackedVector2Array:return PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
static func segment_distance(p:Vector2,a:Vector2,b:Vector2)->float:
 var d=b-a;return p.distance_to(a+d*clampf((p-a).dot(d)/d.length_squared(),0,1))
func route_clear(p:Vector2,radius:float,plaza:PackedVector2Array)->bool:
 if Geometry2D.is_point_in_polygon(p,plaza):return false
 for i in range(plaza.size()-1):
  if segment_distance(p,plaza[i],plaza[i+1])<radius+.18:return false
 for path in preload('res://scripts/market_landscape.gd').PATHS:
  for i in range(path.size()-1):
   if segment_distance(p,path[i],path[i+1])<2.15+radius:return false
 # Actual original north/west paving and west materials customer strip.
 for r in [Rect2(-3.5,-21,7,18),Rect2(-24,-6.5,24,5),Rect2(-5.7,.55,2.6,2.9),Rect2(1,17.5,10,10),Rect2(18,14.5,11,7),Rect2(27,-1.5,8,10),Rect2(19.9,-9,4.2,20.7)]:
  if r.grow(radius+.2).has_point(p):return false
 return true
func ground_supports()->Dictionary:
 var bodies=[]
 for node in host.get_children():
  if node is StaticBody3D and node.get_meta('audio_ground_regions',false)==true:bodies.append(node)
 if bodies.size()!=1:return {'ok':false,'reason':'Original ground owner ambiguous'}
 var body=bodies[0]
 if body.is_queued_for_deletion() or body.transform!=Transform3D(Basis.IDENTITY,Vector3(0,-.35,0)):return {'ok':false,'reason':'Original ground transform changed'}
 var shapes=body.get_children();var expected=preload('res://scripts/hall_basement_blockout.gd').pieces(Rect2(-54,-54,108,108))
 if shapes.size()!=4 or expected.size()!=4:return {'ok':false,'reason':'Original ground support count changed'}
 for i in range(4):
  var c=shapes[i];var patch=expected[i]
  if not c is CollisionShape3D or not c.shape is BoxShape3D or c.disabled or c.is_queued_for_deletion():return {'ok':false,'reason':'Invalid original ground support'}
  if c.shape.size!=Vector3(patch.size.x,.6,patch.size.y) or c.transform!=Transform3D(Basis.IDENTITY,Vector3(patch.get_center().x,0,patch.get_center().y)):return {'ok':false,'reason':'Original ground split changed'}
 return {'ok':true,'shapes':shapes}
func obstacles(ground:Array)->Array:
 var out=[]
 for c in host.find_children('*','CollisionShape3D',true,false):
  if c.disabled or c.is_queued_for_deletion() or not c.get_parent() is StaticBody3D:continue
  var s=c.shape;var b:AABB
  if s is BoxShape3D:b=AABB(-s.size*.5,s.size)
  elif s is CylinderShape3D:b=AABB(Vector3(-s.radius,-s.height*.5,-s.radius),Vector3(s.radius*2,s.height,s.radius*2))
  elif s is CapsuleShape3D:b=AABB(Vector3(-s.radius,-s.height*.5,-s.radius),Vector3(s.radius*2,s.height,s.radius*2))
  elif s is ConvexPolygonShape3D:
   if s.points.is_empty():continue
   b=AABB(s.points[0],Vector3.ZERO)
   for p in s.points:b=b.expand(p)
  else:continue
  var world=c.global_transform*b
  # Ground support only; never ignore ordinary platforms or building bounds.
  if c in ground:continue
  if world.end.y<-.06 or world.position.y>2.5:continue
  var points=PackedVector2Array()
  if s is ConvexPolygonShape3D:
   for point in s.points:
    var v=c.global_transform*point;points.append(Vector2(v.x,v.z))
  elif s is CylinderShape3D:
   # Circumscribed64-gon, never an inscribed underestimate of the round solid.
   var radius=s.radius/cos(PI/64.0)
   for i in range(64):
    for y in [-s.height*.5,s.height*.5]:
     var v=c.global_transform*Vector3(cos(i*TAU/64)*radius,y,sin(i*TAU/64)*radius);points.append(Vector2(v.x,v.z))
  else:
   for x in [b.position.x,b.end.x]:
    for y in [b.position.y,b.end.y]:
     for z in [b.position.z,b.end.z]:
      var v=c.global_transform*Vector3(x,y,z);points.append(Vector2(v.x,v.z))
  var hull=Geometry2D.convex_hull(points)
  if hull.size()>=4:out.append(hull)
 return out
func fine_lawn(batch:MultiMeshInstance3D)->bool:
 var holder=host.get_node_or_null('ContinuousGrass')
 if holder==null or holder.get_parent()!=host or holder.transform!=Transform3D.IDENTITY or batch.get_parent()!=holder or batch.is_queued_for_deletion():return false
 var fields=str(batch.name).split('_')
 if fields.size()!=3 or fields[0]!='LawnChunk' or not fields[1].is_valid_int() or not fields[2].is_valid_int():return false
 var cx=int(fields[1]);var cz=int(fields[2])
 if str(batch.name)!='LawnChunk_%d_%d'%[cx,cz] or batch.transform!=Transform3D(Basis.IDENTITY,Vector3(cx*10,0,cz*10)):return false
 var mm=batch.multimesh
 if mm==null or mm.mesh==null or mm.transform_format!=MultiMesh.TRANSFORM_3D or not mm.use_colors or mm.use_custom_data:return false
 var m=batch.material_override
 if not m is ShaderMaterial or m.shader!=load('res://assets/materials/continuous_blades.gdshader'):return false
 if mm.mesh.get_surface_count()!=1 or not mm.mesh is ArrayMesh or mm.mesh.surface_get_primitive_type(0)!=Mesh.PRIMITIVE_TRIANGLES:return false
 if lawn_mesh==null:lawn_mesh=preload('res://scripts/continuous_grass.gd').blade_mesh()
 return var_to_bytes(mm.mesh.surface_get_arrays(0))==var_to_bytes(lawn_mesh.surface_get_arrays(0))
func visual_obstacles()->Array:
 var result=[];prop_visuals=[]
 for mesh in host.find_children('*','MeshInstance3D',true,false):
  if mesh.mesh!=null and mesh.is_visible_in_tree():
   var b=mesh.global_transform*mesh.mesh.get_aabb();result.append(b);prop_visuals.append(b)
 for batch in host.find_children('*','MultiMeshInstance3D',true,false):
  if not batch.is_visible_in_tree() or batch.multimesh==null or batch.multimesh.mesh==null:continue
  var lawn=fine_lawn(batch)
  var mm=batch.multimesh;var count=mm.instance_count if mm.visible_instance_count<0 else mini(mm.instance_count,mm.visible_instance_count)
  for i in range(count):
   var b=(batch.global_transform*mm.get_instance_transform(i))*mm.mesh.get_aabb();result.append(b)
   if not lawn:prop_visuals.append(b)
 return result
static func visual_clear(b:AABB,visuals:Array,minimum_height:float)->bool:
 for other in visuals:
  if other.end.y<=minimum_height or other.size.x>80 or other.size.z>80:continue
  if b.intersects(other):return false
 return true
func clear(p:Vector2,radius:float,plaza:PackedVector2Array,blocked:Array)->bool:
 if not route_clear(p,radius,plaza):return false
 for poly in blocked:
  if Geometry2D.is_point_in_polygon(p,poly):return false
  for i in range(poly.size()-1):
   if segment_distance(p,poly[i],poly[i+1])<radius+.12:return false
 return true
static func material(hex:String)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=Color(hex);m.roughness=.86;return m
static func box(root:Node3D,n:String,p:Vector3,size:Vector3,m:Material):
 var v=MeshInstance3D.new();v.name=n;var mesh=BoxMesh.new();mesh.size=size;v.mesh=mesh;v.position=p;v.material_override=m;root.add_child(v)
static func bollard(root:Node3D,p:Vector3):
 var h=Node3D.new();h.name='GardenLantern';h.position=p;root.add_child(h)
 var wood=material('725338');var bronze=material('aa8150');var glow=material('f8d896');glow.emission_enabled=true;glow.emission=Color('ffce7d');glow.emission_energy_multiplier=.65
 box(h,'Timber',Vector3(0,.36,0),Vector3(.13,.72,.13),wood)
 box(h,'BronzeFoot',Vector3(0,.045,0),Vector3(.21,.09,.21),bronze)
 box(h,'WarmCore',Vector3(0,.61,0),Vector3(.16,.27,.16),glow)
 box(h,'Cap',Vector3(0,.77,0),Vector3(.25,.055,.25),bronze)
 for x in [-.105,.105]:
  for z in [-.105,.105]:box(h,'Cage',Vector3(x,.61,z),Vector3(.025,.29,.025),bronze)
 # Emissive practical only, no new shadow maps or lighting/exposure changes.
static func bench(root:Node3D,p:Vector3,yaw:float):
 var h=Node3D.new();h.name='DecorativeGardenBench';h.position=p;h.rotation.y=yaw;root.add_child(h)
 var wood=material('a27b4d');var bronze=material('8e7048')
 for x in [-.62,.62]:
  box(h,'BronzeLegLeft' if x<0 else 'BronzeLegRight',Vector3(x,.23,0),Vector3(.075,.46,.46),bronze)
  box(h,'Back upright',Vector3(x,.65,-.20),Vector3(.065,.7,.065),bronze)
  box(h,'Arm',Vector3(x,.68,.02),Vector3(.075,.07,.49),bronze)
 for z in [-.16,-.05,.06,.17]:box(h,'Seat timber',Vector3(0,.47,z),Vector3(1.42,.06,.085),wood)
 for y in [.69,.81,.93]:box(h,'Back timber',Vector3(0,y,-.23),Vector3(1.42,.085,.055),wood)
 # Decorative only: no interaction hint or false seating service.
func install()->Dictionary:
 if not active():return {'ok':false,'reason':'World inactive'}
 if attempted:return result
 attempted=true
 if host.has_node(ROOT_NAME):return {'ok':false,'reason':'Foreign garden root'}
 var tiles=host.get_node_or_null('SupportedPlazaTiles')
 if tiles==null:return {'ok':false,'reason':'Original plaza missing'}
 var plaza=tiles.get_meta('support_polygon',PackedVector2Array())
 if not plaza is PackedVector2Array or plaza.size()!=65 or plaza[0]!=plaza[-1]:return {'ok':false,'reason':'Original plaza hull changed'}
 var ground=ground_supports()
 if not ground.ok:return ground
 var blocked=obstacles(ground.shapes);var existing_visuals=visual_obstacles();var root=Node3D.new();root.name=ROOT_NAME
 var templates={};var journal=[];var counts={};var tree_count=0;var bench_count=0
 for asset in ASSETS:
  var packed=load('res://assets/'+asset+'.glb')
  if not packed is PackedScene:root.free();return {'ok':false,'reason':'Missing garden asset '+asset}
  var source=packed.instantiate();var nodes=source.find_children('*','MeshInstance3D',true,false)
  if nodes.size()!=1 or nodes[0].mesh==null or nodes[0].transform!=Transform3D.IDENTITY:source.free();root.free();return {'ok':false,'reason':'Unexpected garden mesh '+asset}
  templates[asset]={'mesh':nodes[0].mesh,'material':nodes[0].material_override};source.free()
 for region in REGIONS:
  print('LANDSCAPE_REGION_BEGIN ',region.name)
  var group=Node3D.new();group.name=region.name;root.add_child(group);var transforms={}
  for asset in ASSETS:transforms[asset]=[]
  var occupied=[]
  var tp:Vector2=region.tree
  if clear(tp,.6,plaza,blocked):
   var tree_resource=load('res://assets/kit/reference_broadleaf_tree_a.glb')
   if not tree_resource is PackedScene:root.free();return {'ok':false,'reason':'Tree asset missing'}
   var tree=tree_resource.instantiate()
   if not tree is Node3D:tree.free();root.free();return {'ok':false,'reason':'Invalid tree root'}
   var tree_nodes=tree.find_children('*','MeshInstance3D',true,false)
   if tree_nodes.size()!=1 or tree_nodes[0].get_parent()!=tree or tree_nodes[0].transform!=Transform3D.IDENTITY or tree_nodes[0].mesh==null:tree.free();root.free();return {'ok':false,'reason':'Unexpected tree hierarchy'}
   # Existing leafy mound meshes add a fuller crown, entirely above walking headroom.
   var crown_centers=[Vector3(-1.05,3.5,.25),Vector3(.95,3.75,.5),Vector3(.05,4.45,-.15),Vector3(-.35,3.8,-1.05),Vector3(.25,3.35,1.05)]
   for i in range(crown_centers.size()):
    var leaf=MeshInstance3D.new();leaf.name='LeafyCrown%02d'%i;leaf.mesh=templates['planting_dense/compact_broadleaf_mound'].mesh;leaf.material_override=templates['planting_dense/compact_broadleaf_mound'].material;leaf.position=crown_centers[i];leaf.scale=Vector3(1.85,2.6,1.85);leaf.rotation.y=i*1.7;tree.add_child(leaf)
   tree_nodes=tree.find_children('*','MeshInstance3D',true,false)
   tree.name='CanopyTree';tree.position=Vector3(tp.x,-.045,tp.y);tree.rotation.y=region.center.x*.3
   var tree_ok=true;var tree_bounds=AABB();var first=true;var low_bounds=AABB();var low_first=true
   for node in tree_nodes:
    var t=tree.transform*node.transform;var b=t*node.mesh.get_aabb();tree_bounds=b if first else tree_bounds.merge(b);first=false
    # Exact broad-phase: a triangle cannot intersect a box disjoint from its mesh bounds.
    var nearby=[]
    for other in existing_visuals:
     if other.end.y>1.8 and other.size.x<=80 and other.size.z<=80 and b.intersects(other):nearby.append(other)
    var faces=node.mesh.get_faces()
    print('LANDSCAPE_TREE_MESH ',region.name,' ',node.name,' triangles=',faces.size()/3,' nearby=',nearby.size())
    if faces.size()%3!=0:tree_ok=false;break
    for i in range(0,faces.size(),3):
     var a=t*faces[i];var b0=t*faces[i+1];var c=t*faces[i+2]
     var tri=AABB(a,Vector3.ZERO).expand(b0).expand(c)
     if not visual_clear(tri,nearby,1.8):tree_ok=false
     if minf(a.y,minf(b0.y,c.y))>2.2:continue
     low_bounds=tri if low_first else low_bounds.merge(tri);low_first=false
     var center=Vector2(tri.get_center().x,tri.get_center().z);var radius=Vector2(tri.size.x,tri.size.z).length()*.5
     if not clear(center,radius+.12,plaza,blocked):tree_ok=false
   if first or low_first:tree_ok=false
   if tree_ok:
    group.add_child(tree);tree_count+=1
    var low_rect=Rect2(Vector2(low_bounds.position.x,low_bounds.position.z),Vector2(low_bounds.size.x,low_bounds.size.z)).grow(.12)
    occupied.append(low_rect);journal.append({'region':region.name,'kind':'tree','world_bounds':tree_bounds,'low_branch_reserved':low_rect,'triangles_screened_below':2.2})
    var body=StaticBody3D.new();body.name='GardenTreeTrunk';body.position=tree.position+Vector3(0,1.05,0);group.add_child(body)
    var shape=CollisionShape3D.new();var cylinder=CylinderShape3D.new();cylinder.radius=.25;cylinder.height=2.1;shape.shape=cylinder;body.add_child(shape)
   else:tree.free()
  for offset in [Vector2(0,2.5),Vector2(-2.4,0),Vector2(2.4,0),Vector2(0,-2.5)]:
   var bp=region.center+offset;var bench_rect=Rect2(bp-Vector2.ONE*.95,Vector2.ONE*1.9)
   if not clear(bp,.95,plaza,blocked):continue
   var bench_ok=true
   for area in occupied:
    if area.intersects(bench_rect):bench_ok=false
   var trial=Node3D.new();bench(trial,Vector3(bp.x,-.045,bp.y),atan2(-bp.x,-bp.y));var item=trial.get_child(0)
   for part in item.get_children():
    var part_bounds=(item.transform*part.transform)*part.mesh.get_aabb()
    # Only the two ground-touching legs may meet exact original fine lawn.
    var obstacles_for_part=prop_visuals if str(part.name) in ['BronzeLegLeft','BronzeLegRight'] else existing_visuals
    if not visual_clear(part_bounds,obstacles_for_part,-1.0):bench_ok=false
   var approach=item.transform*AABB(Vector3(-.8,0,.3),Vector3(1.6,2.1,.9))
   var approach_rect=Rect2(Vector2(approach.position.x,approach.position.z),Vector2(approach.size.x,approach.size.z))
   if not clear(Vector2(approach.get_center().x,approach.get_center().z),Vector2(approach.size.x,approach.size.z).length()*.5,plaza,blocked) or not visual_clear(approach,prop_visuals,-1.0):bench_ok=false
   for area in occupied:
    if area.intersects(approach_rect):bench_ok=false
   if bench_ok:
    trial.remove_child(item);group.add_child(item);bench_count+=1;occupied.append(bench_rect.merge(approach_rect));trial.free();break
   trial.free()
  var lp=region.center+Vector2(-1.15,.75);var lamp_rect=Rect2(lp-Vector2.ONE*.22,Vector2.ONE*.44);var lamp_ok=clear(lp,.22,plaza,blocked) and visual_clear(AABB(Vector3(lp.x-.22,-.045,lp.y-.22),Vector3(.44,.85,.44)),existing_visuals,.08)
  for area in occupied:
   if area.intersects(lamp_rect):lamp_ok=false
  if lamp_ok:bollard(group,Vector3(lp.x,-.045,lp.y));occupied.append(lamp_rect)
  # Layered irregular clusters, not a uniformly spaced flower grid or soil slab.
  var is_fountain=region.name=='FountainEastBorder'
  var samples=720 if is_fountain else 320
  var fountain_edges=[]
  if is_fountain:
   for edge in range(plaza.size()-1):
    var midpoint=(plaza[edge]+plaza[edge+1])*.5
    if midpoint.x>8.5 and absf(midpoint.y)<5.0:fountain_edges.append(edge)
   if fountain_edges.is_empty():root.free();return {'ok':false,'reason':'Fountain arc missing'}
  for i in range(samples):
   var angle=i*2.399963+region.center.x;var radial=sqrt(float(i+1)/float(samples))
   var p:Vector2=region.center+Vector2(cos(angle)*region.radii.x,sin(angle)*region.radii.y)*radial
   if is_fountain:
    # Follow the actual rendered plaza edge, with all original clearance predicates.
    var edge=fountain_edges[i%fountain_edges.size()]
    var along=fmod(float(i)*.61803398875,1.0)
    var boundary=plaza[edge].lerp(plaza[edge+1],along)
    p=boundary+boundary.normalized()*(.65+float(i%11)*.075)
   var ai=0
   if i%5<2:ai=2+(i%2)
   elif i%5==2:ai=1
   elif i%5==3:ai=4
   if i%53==0:ai=5
   var asset=ASSETS[ai];var scale=1.1+float(i%4)*.12
   if ai==4:scale=1.0+float(i%3)*.12
   if ai==5:scale=.55
   if is_fountain:scale=.65+float(i%4)*.07
   var mesh=templates[asset].mesh;var b=mesh.get_aabb();var radius=Vector2(maxf(absf(b.position.x),absf(b.end.x)),maxf(absf(b.position.z),absf(b.end.z))).length()*scale
   if not clear(p,radius,plaza,blocked):continue
   var overlaps_prop=false
   for area in occupied:
    if area.grow(radius).has_point(p):overlaps_prop=true;break
   if overlaps_prop:continue
   var t=Transform3D(Basis(Vector3.UP,i*.71).scaled(Vector3.ONE*scale),Vector3(p.x,-.045,p.y));transforms[asset].append(t)
  var count=0
  for asset in ASSETS:
   var list=transforms[asset]
   if list.is_empty():continue
   var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=templates[asset].mesh;mm.instance_count=list.size()
   for i in range(list.size()):mm.set_instance_transform(i,list[i])
   var batch=MultiMeshInstance3D.new();batch.name=asset.get_file();batch.multimesh=mm;batch.material_override=templates[asset].material;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;group.add_child(batch);count+=list.size()
   for t in list:journal.append({'region':region.name,'asset':asset,'transform':t,'bounds':t*mm.mesh.get_aabb()})
  print('LANDSCAPE_REGION_DONE ',region.name,' plants=',count)
  counts[region.name]=count
  if count<16:root.free();return {'ok':false,'reason':'Too little clear planting space in '+region.name,'counts':counts}
 if not active():root.free();return {'ok':false,'reason':'Cancelled before garden commit'}
 host.add_child(root);visual=root
 result={'ok':true,'counts':counts,'trees':tree_count,'new_trunk_colliders':tree_count,'new_lights':0,'decorative_benches':bench_count,'journal':journal,'existing_world_mutated':false}
 return result
func _exit_tree():
 if is_instance_valid(visual):visual.queue_free()
