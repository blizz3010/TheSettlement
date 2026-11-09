extends RefCounted
## Connected, walkable landscape relief. Existing town slabs and the basement stay intact.
## Heights are deterministic world-space metres, shared with grass and other ground flora.
const Park = preload("res://scripts/park_hall_grade.gd")
const Layers = preload("res://scripts/local_terrain_layers.gd")
static var _park_lattice_cache:Dictionary={}
const BASE_Y = -0.05
const EXTENT = 54
const GRID = 1.0
const PATHS = [
 [Vector2(0,10),Vector2(0,15)], [Vector2(0,15),Vector2(6,17)],
 [Vector2(6,17),Vector2(17,12)], [Vector2(17,12),Vector2(14,0)],
 [Vector2(14,0),Vector2(11,-9)], [Vector2(17,12),Vector2(31,10)],
 [Vector2(31,10),Vector2(31,7)], [Vector2(17,12),Vector2(18,19)],
 [Vector2(18,19),Vector2(17,29)], [Vector2(17,29),Vector2(9,30)],
 [Vector2(9,30),Vector2(-6,30)], [Vector2(17,29),Vector2(27,26)],
 [Vector2(27,26),Vector2(31,27)], [Vector2(5.2,7.8),Vector2(11,10)],
 [Vector2(11,10),Vector2(22,10)], [Vector2(22,10),Vector2(22,-8)],
 [Vector2(-5,7),Vector2(-7,10)], [Vector2(-7,10),Vector2(-8.28,15)]
]
const RESERVES = [
 preload("res://scripts/seat_interaction.gd").GARDEN_POCKETS[0],
 preload("res://scripts/seat_interaction.gd").GARDEN_POCKETS[1],
 preload("res://scripts/rook_shop.gd").FOOTPRINT, # Shared Rook study footprint C.
 preload("res://scripts/rook_shop.gd").CONNECTOR, # Shared connector; existing terminal retained.
 Rect2(-12,-35,24,24), # Hall shell, basement and planted entrances.
 Rect2(-34,5,23,20), # Expanded hideout terrace, stash and safety rails.
 Rect2(-18,11,12,7), # Both terrace stair flights.
 Rect2(-26,-8,21,9), # Original west paved route and counter.
 Rect2(25.5,-3,11,12), # Psy shop and apron.
 Rect2(19,12,12,13), # Atlas shop, side apron and entry.
 Rect2(-1,19,14,10) # Dan shop and entry apron.
]

static func segment_distance(p:Vector2,a:Vector2,b:Vector2)->float:
 var delta=b-a
 return p.distance_to(a+delta*clampf((p-a).dot(delta)/delta.length_squared(),0,1))

static func rect_distance(p:Vector2,r:Rect2)->float:
 return p.distance_to(Vector2(clampf(p.x,r.position.x,r.end.x),clampf(p.y,r.position.y,r.end.y)))

static func relief_mask(p:Vector2)->float:
 var clearance=p.length()-14.0
 clearance=minf(clearance,p.distance_to(Vector2(22,-16))-10.0)
 for r in RESERVES:clearance=minf(clearance,rect_distance(p,r))
 for path in PATHS:clearance=minf(clearance,segment_distance(p,path[0],path[1])-3.2)
 for lamp in [Vector2(3.1,12.3),Vector2(34,12.8),Vector2(-14.6,-15),Vector2(-10.9,11.8)]:clearance=minf(clearance,p.distance_to(lamp)-1.5)
 return smoothstep(0.0,11.0,maxf(0.0,clearance))

static func height_at(x:float,z:float)->float:
 var p=Vector2(x,z)
 if Park.inside(p):
  var delta=park_surface_height(p)-pre_park_mesh_height(p)
  if absf(delta)<.000001:return pre_park_height_at(x,z)
  return pre_park_height_at(x,z)+delta
 return pre_park_height_at(x,z)

static func pre_park_height_at(x:float,z:float)->float:
 return maxf(BASE_Y,baseline_height_at(x,z)+layer_delta_at(x,z))

static func park_lattice_height(x:int,z:int)->float:
 # Only the fixed local mesh lattice is cached; never arbitrary moving actor samples.
 if x< -24 or x> -11 or z< -24 or z> -15:return pre_park_height_at(x,z)
 var key=Vector2i(x,z)
 if not _park_lattice_cache.has(key):_park_lattice_cache[key]=pre_park_height_at(x,z)
 assert(_park_lattice_cache.size()<=140,'Bounded park lattice cache')
 return _park_lattice_cache[key]

static func pre_park_mesh_height(p:Vector2)->float:
 var x=floorf(p.x);var z=floorf(p.y);var u=p.x-x;var v=p.y-z
 var a=park_lattice_height(int(x),int(z));var b=park_lattice_height(int(x)+1,int(z))
 var c=park_lattice_height(int(x),int(z)+1);var d=park_lattice_height(int(x)+1,int(z)+1)
 return a+(b-a)*u+(c-a)*v if u+v<=1 else d+(c-d)*(1-u)+(b-d)*(1-v)

static func park_surface_height(p:Vector2)->float:
 return Park.surface_height(p,func(q:Vector2):return park_vertex_height(q))

static func park_vertex_height(p:Vector2)->float:
 return Park.grade(p,pre_park_mesh_height(p))

static func layer_delta_at(x:float,z:float)->float:
 # The added contribution uses the actual 1 m triangle plane. Existing baseline
 # shaping is untouched, and the new foliage/capsule offset has no interpolation gap.
 if not Layers.affects(Vector2(x,z)):return 0.0
 var ix=floorf(x);var iz=floorf(z);var u=x-ix;var v=z-iz
 var a=Vector2(ix,iz);var b=Vector2(ix+1,iz);var c=Vector2(ix,iz+1);var d=Vector2(ix+1,iz+1)
 var ha=Layers.delta(a,relief_mask(a));var hb=Layers.delta(b,relief_mask(b))
 var hc=Layers.delta(c,relief_mask(c));var hd=Layers.delta(d,relief_mask(d))
 return ha+(hb-ha)*u+(hc-ha)*v if u+v<=1.0 else hd+(hc-hd)*(1-u)+(hb-hd)*(1-v)

static func baseline_height_at(x:float,z:float)->float:
 var p=Vector2(x,z)
 var broad=1.10+0.30*sin(x*.105+z*.055)+0.23*cos(z*.16-x*.035)
 # Broad connected shoulders and shallow saddles, not isolated floating mounds.
 var hills=0.0
 for hill in [Vector4(-37,-9,2.2,17),Vector4(-23,-39,2.0,18),Vector4(2,40,1.8,16),Vector4(41,18,1.6,17),Vector4(38,-34,1.4,18)]:
  var d=p.distance_squared_to(Vector2(hill.x,hill.y))/(hill.w*hill.w)
  hills+=hill.z*exp(-d)
 var natural=BASE_Y+relief_mask(p)*(broad+hills)
 if absf(x)>=52.0:return natural
 var distance=absf(z-stream_z(x))
 if distance>=9.0:return natural
 var bed=stream_water_y(x)-.20+.025*sin(x*.51)
 # Cut only the positive relief; the old base slab is never exposed above the bed.
 var bank=bed+.62*smoothstep(.6,2.8,distance)
 var carved=lerpf(bank,natural,smoothstep(3.0,9.0,distance))
 return maxf(BASE_Y,lerpf(natural,carved,1.0-smoothstep(40.0,52.0,absf(x))))

static func stream_z(x:float)->float:
 return -46.5+2.0*sin(x*.105)+.45*sin(x*.24)

static func stream_water_y(x:float)->float:
 return .34-.0012*x

static func stream_wet(x:float,z:float)->bool:
 if absf(x)>=42.5 or absf(z-stream_z(x))>=8.5 or height_at(x,z)>=stream_water_y(x)+.05:return false
 var side=-1.0 if z<stream_z(x) else 1.0
 # Ignore a separate low town reserve beyond the first bank.
 for i in range(1,ceili(absf(z-stream_z(x))/.2)):
  if height_at(x,stream_z(x)+side*i*.2)>=stream_water_y(x)+.05:return false
 return true

static func bank_grounded(p:Vector3)->Vector3:
 var result=p
 if stream_wet(p.x,p.z):
  var side=-1.0 if p.z<stream_z(p.x) else 1.0
  for i in range(18):
   result.z+=side*.5
   if not stream_wet(result.x,result.z) and height_at(result.x,result.z)>stream_water_y(result.x)+.15:break
 result.y+=height_at(result.x,result.z)-BASE_Y
 return result

static func normal_at(x:float,z:float)->Vector3:
 var step=.25
 return Vector3(height_at(x-step,z)-height_at(x+step,z),2*step,height_at(x,z-step)-height_at(x,z+step)).normalized()

static func add_to(scene:Node3D)->Node3D:
 if scene.has_node('SettlementTerrain'):return scene.get_node('SettlementTerrain')
 var root=Node3D.new();root.name='SettlementTerrain';scene.add_child(root)
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var stone=SurfaceTool.new();stone.begin(Mesh.PRIMITIVE_TRIANGLES);var stone_vertices=0
 var faces=PackedVector3Array()
 for zi in range(-EXTENT,EXTENT):
  for xi in range(-EXTENT,EXTENT):
   if Park.affected_cell(xi,zi):
    var patch=Park.cell_faces(xi,zi,func(p:Vector2):return park_vertex_height(p))
    for i in range(0,patch.size(),3):
     var normal=(patch[i+2]-patch[i]).cross(patch[i+1]-patch[i]).normalized()
     for j in range(3):
      var p=patch[i+j];st.set_normal(normal);st.set_uv(Vector2(p.x,p.z)*.2)
      st.set_color(Color(.225,.295,.185));st.add_vertex(p);faces.append(p)
    continue
   var a=Vector3(xi,height_at(xi,zi),zi)
   var b=Vector3(xi+1,height_at(xi+1,zi),zi)
   var c=Vector3(xi,height_at(xi,zi+1),zi+1)
   var d=Vector3(xi+1,height_at(xi+1,zi+1),zi+1)
   if maxf(maxf(a.y,b.y),maxf(c.y,d.y))<=BASE_Y+.002:continue
   for p in [a,b,c,b,d,c]:
    st.set_normal(normal_at(p.x,p.z));st.set_uv(Vector2(p.x,p.z)*.2)
    var shade=.94+.045*sin(p.x*.23+p.z*.11)
    var color=Color(.225,.295,.185)*shade
    if absf(p.x)<43 and absf(p.z-stream_z(p.x))<8.5:
     var wet=1.0-smoothstep(stream_water_y(p.x)+.08,stream_water_y(p.x)+.42,p.y)
     color=color.lerp(Color(.25,.23,.17),wet)
    st.set_color(color);st.add_vertex(p);faces.append(p)
   # Overlay uses exactly the same triangulation, not a second height approximation.
   for tri in [[a,b,c],[b,d,c]]:
    var center=(tri[0]+tri[1]+tri[2])/3.0
    if Layers.stone_face(Vector2(center.x,center.z)):
     for p in tri:
      stone.set_normal(normal_at(p.x,p.z));stone.set_uv(Vector2(p.x,p.z))
      stone.set_color(Color(.43,.40,.33)*(0.94+.06*sin(p.z*5.7)))
      stone.add_vertex(p+Vector3(0,.004,0));stone_vertices+=1
 var mesh=st.commit()
 var surface=MeshInstance3D.new();surface.name='GroundRelief';surface.mesh=mesh
 var mat=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=1.0
 surface.material_override=mat;surface.set_meta('terrain_turf',true);root.add_child(surface)
 if stone_vertices>0:
  var facing=MeshInstance3D.new();facing.name='LowStoneTerraceFacing';facing.mesh=stone.commit()
  var facing_mat=StandardMaterial3D.new();facing_mat.vertex_color_use_as_albedo=true;facing_mat.roughness=1.0
  facing.material_override=facing_mat;root.add_child(facing)
 root.set_meta('local_layering','option_one_fixed_access');root.set_meta('stone_facing_triangles',stone_vertices/3)
 var body=StaticBody3D.new();body.name='WalkableRelief';body.set_meta('audio_surface','grass');root.add_child(body)
 var collision=CollisionShape3D.new();var shape=ConcavePolygonShape3D.new();shape.set_faces(faces);collision.shape=shape;body.add_child(collision)
 root.set_meta('triangle_count',faces.size()/3)
 root.set_meta('grounding_journal',ground_flora(scene))
 var wildlife=preload('res://scripts/terrain_wildlife_grounding.gd').new();root.add_child(wildlife)
 return root

static func ground_flora(scene:Node3D)->Array:
 var journal=[]
 # These instanced plants have ground-level origins and no collision bodies.
 for holder_name in ['NaturalBorder','SouthernGroundcover','WalkwayPlanting','RouteGardens']:
  var holder=scene.get_node_or_null(holder_name)
  if holder==null:continue
  for batch in holder.get_children():
   if not batch is MultiMeshInstance3D:continue
   var transforms=batch.get_meta('source_transforms',[])
   for i in range(batch.multimesh.instance_count):
    var t=batch.multimesh.get_instance_transform(i)
    var old=t.origin
    var next=bank_grounded(old)
    if Park.inside(Vector2(old.x,old.z)) and not 'tree' in str(batch.name).to_lower():
     next.y=old.y+park_surface_height(Vector2(old.x,old.z))-BASE_Y
    var height=next.y-old.y
    if next.is_equal_approx(old):continue
    t.origin=next;batch.multimesh.set_instance_transform(i,t)
    # A bank relocation changes horizontal wind phase as well as its root.
    if batch.get_meta('leaf_wind',false) and batch.multimesh.use_custom_data:
     batch.multimesh.set_instance_custom_data(i,Color(preload('res://scripts/foliage_wind.gd')._phase(next),0,0,1))
    if transforms.size()>i:transforms[i]=t
    journal.append({'holder':holder_name,'batch':str(batch.name),'index':i,'rise':height,'from':old,'to':next})
   if not transforms.is_empty():batch.set_meta('source_transforms',transforms)
 # Rooted trees retain matching visual and trunk-collider rises.
 var near=scene.get_node_or_null('ReferenceFoliage')
 if near!=null:
  for node in near.get_children():
   if not node is Node3D:continue
   var old=node.global_position;var next=bank_grounded(old);var h=next.y-old.y
   if not next.is_equal_approx(old):
    node.global_position=next
    for mesh in node.find_children('*','MeshInstance3D',true,false):
     if mesh.get_meta('leaf_wind',false) and mesh.material_override is ShaderMaterial:
      mesh.material_override.set_shader_parameter('phase_offset',preload('res://scripts/foliage_wind.gd')._phase(next))
    journal.append({'root':str(node.get_path()),'rise':h,'from':old,'to':next})
 var gardens=scene.get_node_or_null('RouteGardens')
 if gardens!=null:
  for node in gardens.get_children():
   if node is StaticBody3D and str(node.name).begins_with('Tree trunk'):
    var old=node.global_position;var next=bank_grounded(old);var h=next.y-old.y
    if not next.is_equal_approx(old):node.global_position=next;journal.append({'root':str(node.get_path()),'rise':h,'from':old,'to':next})
 # Decorative independent pots are moved as whole imported roots. Matching root
 # lanterns and lights are grounded independently below, preserving their offsets.
 for node in scene.get_children():
  if not node is Node3D:continue
  var is_pot='/planter.glb' in node.scene_file_path or '/planter_fern_variant.glb' in node.scene_file_path
  var is_lantern='/lantern.glb' in node.scene_file_path
  if not (is_pot or is_lantern or node is OmniLight3D):continue
  var old=node.global_position;var next=bank_grounded(old);var h=next.y-old.y
  if not next.is_equal_approx(old):node.global_position=next;journal.append({'root':str(node.get_path()),'rise':h,'from':old,'to':next})
 return journal

# Optional coroutine entry point used only by the isolated loading successor.
# add_to()/ground_flora() remain synchronous for existing direct-launch callers.
static func _cached_grid_height(cache:Dictionary,x:int,z:int)->float:
 var key=Vector2i(x,z)
 if not cache.has(key):cache[key]=height_at(x,z)
 return cache[key]

static func _cached_grid_normal(cache:Dictionary,x:int,z:int)->Vector3:
 var key=Vector2i(x,z)
 if not cache.has(key):cache[key]=normal_at(x,z)
 return cache[key]

static func add_to_staged(scene:Node3D)->Node3D:
 if scene.has_node('SettlementTerrain'):return scene.get_node('SettlementTerrain')
 var root=Node3D.new();root.name='SettlementTerrain';scene.add_child(root)
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var stone=SurfaceTool.new();stone.begin(Mesh.PRIMITIVE_TRIANGLES);var stone_vertices=0
 var faces=PackedVector3Array()
 # Pure height/normal memoization reuses identical float results at shared grid
 # vertices; face order, winding, attributes and the one-mesh collider are unchanged.
 var height_cache:Dictionary={}
 var normal_cache:Dictionary={}
 var work=0
 for zi in range(-EXTENT,EXTENT):
  for xi in range(-EXTENT,EXTENT):
   work+=1
   if work%8==0 and await scene._startup_checkpoint("terrain mesh cell %d"%work):return null
   if Park.affected_cell(xi,zi):
    var patch=Park.cell_faces(xi,zi,func(p:Vector2):return park_vertex_height(p))
    for i in range(0,patch.size(),3):
     var normal=(patch[i+2]-patch[i]).cross(patch[i+1]-patch[i]).normalized()
     for j in range(3):
      var p=patch[i+j];st.set_normal(normal);st.set_uv(Vector2(p.x,p.z)*.2)
      st.set_color(Color(.225,.295,.185));st.add_vertex(p);faces.append(p)
    continue
   var a=Vector3(xi,_cached_grid_height(height_cache,xi,zi),zi)
   var b=Vector3(xi+1,_cached_grid_height(height_cache,xi+1,zi),zi)
   var c=Vector3(xi,_cached_grid_height(height_cache,xi,zi+1),zi+1)
   var d=Vector3(xi+1,_cached_grid_height(height_cache,xi+1,zi+1),zi+1)
   if maxf(maxf(a.y,b.y),maxf(c.y,d.y))<=BASE_Y+.002:continue
   for p in [a,b,c,b,d,c]:
    st.set_normal(_cached_grid_normal(normal_cache,int(p.x),int(p.z)));st.set_uv(Vector2(p.x,p.z)*.2)
    var shade=.94+.045*sin(p.x*.23+p.z*.11)
    var color=Color(.225,.295,.185)*shade
    if absf(p.x)<43 and absf(p.z-stream_z(p.x))<8.5:
     var wet=1.0-smoothstep(stream_water_y(p.x)+.08,stream_water_y(p.x)+.42,p.y)
     color=color.lerp(Color(.25,.23,.17),wet)
    st.set_color(color);st.add_vertex(p);faces.append(p)
   # Overlay uses exactly the same triangulation, not a second height approximation.
   for tri in [[a,b,c],[b,d,c]]:
    var center=(tri[0]+tri[1]+tri[2])/3.0
    if Layers.stone_face(Vector2(center.x,center.z)):
     for p in tri:
      stone.set_normal(normal_at(p.x,p.z));stone.set_uv(Vector2(p.x,p.z))
      stone.set_color(Color(.43,.40,.33)*(0.94+.06*sin(p.z*5.7)))
      stone.add_vertex(p+Vector3(0,.004,0));stone_vertices+=1
 if await scene._startup_checkpoint("terrain surface commit"):return null
 var mesh=st.commit()
 if await scene._startup_checkpoint("terrain surface committed"):return null
 var surface=MeshInstance3D.new();surface.name='GroundRelief';surface.mesh=mesh
 var mat=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=1.0
 surface.material_override=mat;surface.set_meta('terrain_turf',true);root.add_child(surface)
 if stone_vertices>0:
  var facing=MeshInstance3D.new();facing.name='LowStoneTerraceFacing';facing.mesh=stone.commit()
  var facing_mat=StandardMaterial3D.new();facing_mat.vertex_color_use_as_albedo=true;facing_mat.roughness=1.0
  facing.material_override=facing_mat;root.add_child(facing)
 root.set_meta('local_layering','option_one_fixed_access');root.set_meta('stone_facing_triangles',stone_vertices/3)
 var body=StaticBody3D.new();body.name='WalkableRelief';body.set_meta('audio_surface','grass');root.add_child(body)
 var collision=CollisionShape3D.new();var shape=ConcavePolygonShape3D.new();shape.set_faces(faces);collision.shape=shape;body.add_child(collision)
 if await scene._startup_checkpoint("terrain collision committed"):return null
 root.set_meta('triangle_count',faces.size()/3)
 var journal=await ground_flora_staged(scene)
 if scene.startup_cancel_requested:return null
 root.set_meta('grounding_journal',journal)
 var wildlife=preload('res://scripts/terrain_wildlife_grounding.gd').new();root.add_child(wildlife)
 if await scene._startup_checkpoint("terrain flora complete"):return null
 return root


static func ground_flora_staged(scene:Node3D)->Array:
 var journal=[]
 var work=0
 # These instanced plants have ground-level origins and no collision bodies.
 for holder_name in ['NaturalBorder','SouthernGroundcover','WalkwayPlanting','RouteGardens']:
  work+=1
  if work%16==0 and await scene._startup_checkpoint("terrain flora item %d"%work):return []
  var holder=scene.get_node_or_null(holder_name)
  if holder==null:continue
  for batch in holder.get_children():
   work+=1
   if work%16==0 and await scene._startup_checkpoint("terrain flora item %d"%work):return []
   if not batch is MultiMeshInstance3D:continue
   var transforms=batch.get_meta('source_transforms',[])
   for i in range(batch.multimesh.instance_count):
    work+=1
    if work%16==0 and await scene._startup_checkpoint("terrain flora item %d"%work):return []
    var t=batch.multimesh.get_instance_transform(i)
    var old=t.origin
    var next=bank_grounded(old)
    if Park.inside(Vector2(old.x,old.z)) and not 'tree' in str(batch.name).to_lower():
     next.y=old.y+park_surface_height(Vector2(old.x,old.z))-BASE_Y
    var height=next.y-old.y
    if next.is_equal_approx(old):continue
    t.origin=next;batch.multimesh.set_instance_transform(i,t)
    # A bank relocation changes horizontal wind phase as well as its root.
    if batch.get_meta('leaf_wind',false) and batch.multimesh.use_custom_data:
     batch.multimesh.set_instance_custom_data(i,Color(preload('res://scripts/foliage_wind.gd')._phase(next),0,0,1))
    if transforms.size()>i:transforms[i]=t
    journal.append({'holder':holder_name,'batch':str(batch.name),'index':i,'rise':height,'from':old,'to':next})
   if not transforms.is_empty():batch.set_meta('source_transforms',transforms)
 # Rooted trees retain matching visual and trunk-collider rises.
 var near=scene.get_node_or_null('ReferenceFoliage')
 if near!=null:
  for node in near.get_children():
   work+=1
   if work%16==0 and await scene._startup_checkpoint("terrain flora item %d"%work):return []
   if not node is Node3D:continue
   var old=node.global_position;var next=bank_grounded(old);var h=next.y-old.y
   if not next.is_equal_approx(old):
    node.global_position=next
    for mesh in node.find_children('*','MeshInstance3D',true,false):
     work+=1
     if work%16==0 and await scene._startup_checkpoint("terrain flora item %d"%work):return []
     if mesh.get_meta('leaf_wind',false) and mesh.material_override is ShaderMaterial:
      mesh.material_override.set_shader_parameter('phase_offset',preload('res://scripts/foliage_wind.gd')._phase(next))
    journal.append({'root':str(node.get_path()),'rise':h,'from':old,'to':next})
 var gardens=scene.get_node_or_null('RouteGardens')
 if gardens!=null:
  for node in gardens.get_children():
   work+=1
   if work%16==0 and await scene._startup_checkpoint("terrain flora item %d"%work):return []
   if node is StaticBody3D and str(node.name).begins_with('Tree trunk'):
    var old=node.global_position;var next=bank_grounded(old);var h=next.y-old.y
    if not next.is_equal_approx(old):node.global_position=next;journal.append({'root':str(node.get_path()),'rise':h,'from':old,'to':next})
 # Decorative independent pots are moved as whole imported roots. Matching root
 # lanterns and lights are grounded independently below, preserving their offsets.
 for node in scene.get_children():
  work+=1
  if work%16==0 and await scene._startup_checkpoint("terrain flora item %d"%work):return []
  if not node is Node3D:continue
  var is_pot='/planter.glb' in node.scene_file_path or '/planter_fern_variant.glb' in node.scene_file_path
  var is_lantern='/lantern.glb' in node.scene_file_path
  if not (is_pot or is_lantern or node is OmniLight3D):continue
  var old=node.global_position;var next=bank_grounded(old);var h=next.y-old.y
  if not next.is_equal_approx(old):node.global_position=next;journal.append({'root':str(node.get_path()),'rise':h,'from':old,'to':next})
 return journal
