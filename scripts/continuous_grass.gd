extends RefCounted
# Authored lawn + fine opaque blades. No collision, wind/state or footprint changes.
const CHUNK_SIZE=10.0
const CANDIDATES_PER_CHUNK=400
const TRIANGLES_PER_TUFT=5
const RADIUS=51.0
const MAX_INSTANCES=35000
static func ground_material()->ShaderMaterial:
 var m=ShaderMaterial.new();m.shader=preload('res://assets/materials/continuous_lawn.gdshader');return m
static func rect_poly(r:Rect2)->PackedVector2Array:
 return PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
static func masks(scene:Node3D,include_park:bool=true)->Array:
 var out=[]
 for r in preload("res://scripts/seat_interaction.gd").GARDEN_POCKETS:out.append(rect_poly(r))
 # Original plaza paths, full civic building and its surrounding walks, original traders.
 for r in [Rect2(-3.7,-21.2,7.4,18.4),Rect2(-24.2,-6.7,24.4,5.4),Rect2(-10.3,-33.5,20.6,20.3),Rect2(-10.6,-1.7,7.2,7.6),Rect2(5.0,-7.5,7.0,9.0),Rect2(20.1,-9.0,3.8,12.5)]:out.append(rect_poly(r))
 for bounds in preload('res://scripts/hideout_terrace.gd').reservations()+preload('res://scripts/market_landscape.gd').envelopes():
  out.append(rect_poly(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)).grow(.08)))
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
 # Collision roots also exclude sockets, tree trunks, stairs and new route patches.
 for col in scene.find_children('*','CollisionShape3D',true,false):
  if not include_park and park!=null and park.is_ancestor_of(col):continue
  if col.disabled or col.shape==null:continue
  var shape=col.shape
  if shape is BoxShape3D:
   if shape.size.x>60 or shape.size.z>60:continue # ground/outer boundary, not obstacles
   var b:AABB=col.global_transform*AABB(-shape.size*.5,shape.size)
   if b.position.y>.18 or b.end.y<-.04:continue
   out.append(rect_poly(Rect2(Vector2(b.position.x,b.position.z),Vector2(b.size.x,b.size.z)).grow(.10)))
  elif shape is CylinderShape3D:
   var p:Vector3=col.global_position
   if p.y-shape.height*.5>.18 or p.y+shape.height*.5<-.04:continue
   var poly=PackedVector2Array()
   for i in range(16):poly.append(Vector2(p.x,p.z)+Vector2(cos(i*TAU/16),sin(i*TAU/16))*(shape.radius+.12))
   out.append(poly)
 return out
static func safe(p:Vector2,polygons:Array)->bool:
 if p.length()>RADIUS or p.length()<10.15 or p.distance_to(Vector2(22,-16))<8.15:return false
 for polygon in polygons:
  if Geometry2D.is_point_in_polygon(p,polygon):return false
 return true
static func blade_mesh()->ArrayMesh:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 # Five low, outward-swept leaves form a broad irregular tuft, not an upright V.
 for i in range(TRIANGLES_PER_TUFT):
  var a=float(i)*2.399;var dir=Vector3(cos(a),0,sin(a));var cross_dir=Vector3(-dir.z,0,dir.x)
  var offset=dir*([.018,.07,.04,.095,.065][i])
  var height=[.065,.105,.08,.055,.09][i];var width=[.024,.018,.027,.02,.022][i]
  var normal=(Vector3.UP+cross_dir*.12).normalized()
  for p in [offset-cross_dir*width,offset+Vector3(0,height,0)+dir*(.08+i*.012),offset+cross_dir*width]:
   st.set_normal(normal);st.add_vertex(p)
 return st.commit()
# Both launch paths execute the same deterministic builder. Each step does at most
# 32 candidate samples, preserving RNG call order across chunk boundaries.
static func add_to(scene:Node3D)->Node3D:
 var builder=GrassBuild.new(scene,ground_material,masks,blade_mesh,safe)
 while not builder.step():pass
 return builder.holder
static func add_to_staged(scene:Node3D)->Node3D:
 var builder=GrassBuild.new(scene,ground_material,masks,blade_mesh,safe)
 while not builder.step():
  if await scene._startup_checkpoint("continuous grass: "+builder.stage_label):return null
 return builder.holder

class GrassBuild:
 extends RefCounted
 var scene:Node3D
 var ground_factory:Callable
 var masks_factory:Callable
 var blade_factory:Callable
 var safe_point:Callable
 var holder:Node3D
 var lawn:ShaderMaterial
 var ground_count=0
 var journal=[]
 var polygons=[]
 var source_polygons=[]
 var mesh:ArrayMesh
 var material:ShaderMaterial
 var terrain=null
 var rng=RandomNumberGenerator.new()
 var count=0
 var chunks=0
 var anchors=[]
 var cx=-5
 var cz=-5
 var sample=0
 var transforms=[]
 var colors=[]
 var phase=0
 var stage_label="ground surfaces"
 func _init(owner:Node3D,make_ground:Callable,make_masks:Callable,make_blade:Callable,is_safe:Callable):
  scene=owner;ground_factory=make_ground;masks_factory=make_masks;blade_factory=make_blade;safe_point=is_safe
 func step()->bool:
  if phase==0:
   assert(not scene.has_node('ContinuousGrass'))
   holder=Node3D.new();holder.name='ContinuousGrass';scene.add_child(holder)
   lawn=ground_factory.call()
   lawn.set_shader_parameter("stream_enabled",scene.has_node("SettlementTerrain"))
   for target in scene.find_children('*','MeshInstance3D',true,false):
    if target.get_meta('terrain_turf',false) or (target.mesh is BoxMesh and is_equal_approx(target.mesh.size.y,.6) and is_equal_approx(target.global_position.y,-.35)):
     target.material_override=lawn;ground_count+=1
   phase=1;stage_label="ground surfaces complete";return false
  if phase==1:
   # Keep original art resources intact; supersede tall grass display only.
   for node in scene.find_children('*','MultiMeshInstance3D',true,false):
    if 'ground_grass_a' in str(node.name):
     journal.append({'node':str(node.get_path()),'old_visible':node.visible,'change':'superseded by continuous short grass'});node.visible=false
    elif 'ground_flowers_' in str(node.name):
     for i in range(node.multimesh.instance_count):
      var old:Transform3D=node.multimesh.get_instance_transform(i);var t=old;t.basis=t.basis.scaled_local(Vector3(.72,.72,.72));node.multimesh.set_instance_transform(i,t)
     journal.append({'node':str(node.get_path()),'change':'flower-only scale .72, authored anchors retained'})
   phase=2;stage_label="legacy grass and flower reconciliation complete";return false
  if phase==2:
   polygons=masks_factory.call(scene)
   source_polygons=masks_factory.call(scene,false)
   mesh=blade_factory.call();material=ShaderMaterial.new();material.shader=preload('res://assets/materials/continuous_blades.gdshader')
   if scene.has_node('SettlementTerrain') and ResourceLoader.exists('res://scripts/settlement_terrain.gd'):terrain=load('res://scripts/settlement_terrain.gd')
   rng.seed=510204
   phase=3;stage_label="occupancy masks complete";return false
  if phase==3:
   var center=Vector3(cx*CHUNK_SIZE,0,cz*CHUNK_SIZE)
   var last=mini(sample+32,CANDIDATES_PER_CHUNK)
   while sample<last:
    sample+=1
    var p=Vector2(center.x+rng.randf_range(-5.0,5.0),center.z+rng.randf_range(-5.0,5.0))
    if not safe_point.call(p,source_polygons):continue
    var y=-.048
    if terrain!=null:
     if terrain.stream_wet(p.x,p.y):continue
     y=terrain.height_at(p.x,p.y)+.003
     if scene.has_node('HallRoutePark') and preload('res://scripts/park_hall_grade.gd').inside(p):y=terrain.park_surface_height(p)+.003
    var scale_y=rng.randf_range(.60,1.30);var scale_xz=rng.randf_range(.75,1.25)
    var t=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(scale_xz,scale_y,scale_xz)),Vector3(p.x,y,p.y)-center)
    var tint=Color(.145,.205,.075).lerp(Color(.215,.275,.115),rng.randf())
    # Preserve original draws before the new park mask, identically for both APIs.
    if not safe_point.call(p,polygons):continue
    transforms.append(t);anchors.append(Vector3(p.x,y,p.y));colors.append(tint)
   stage_label="candidate batch %d,%d sample %d"%[cx,cz,sample]
   if sample<CANDIDATES_PER_CHUNK:return false
   if not transforms.is_empty():
    var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=mesh;mm.instance_count=transforms.size()
    for i in range(transforms.size()):mm.set_instance_transform(i,transforms[i]);mm.set_instance_color(i,colors[i])
    var batch=MultiMeshInstance3D.new();batch.name='LawnChunk_%d_%d'%[cx,cz];batch.position=center;batch.multimesh=mm;batch.material_override=material;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    batch.visibility_range_end=31.0;batch.visibility_range_end_margin=1.0;holder.add_child(batch)
    count+=transforms.size();chunks+=1
   sample=0;transforms=[];colors=[];cz+=1
   if cz>5:cz=-5;cx+=1
   if cx>5:phase=4
   return false
  assert(count<=MAX_INSTANCES,'Grass budget exceeded')
  holder.set_meta('anchors',anchors);holder.set_meta('masks',polygons);holder.set_meta('journal',journal)
  holder.set_meta('budget',{'instances':count,'triangles':count*TRIANGLES_PER_TUFT,'chunks':chunks,'ground_surfaces':ground_count,'max_visible_distance':31.0,'collision_shapes':0,'lights':0})
  return true
