extends Node3D
# Marked north/fishing-sector addition only. All original v093 forests remain intact.
# Installed after the lake adapter. Terrain topology, water, original vegetation,
# ruins, colliders, sky, lights and saved state remain authoritative. Only the
# three distant terrain materials are refined; the exact lake cut is retained.
const Lake=preload('res://scripts/inn_lake_v088.gd')
const Settings=preload('res://scripts/game_settings.gd')
const TERRAIN_SHADER=preload('res://shaders/distant_terrain_v094.gdshader')
const FOREST_SHADER=preload('res://shaders/north_forest_v094.gdshader')
const SEED=2026110493
const SECTORS=16
const GRID=32.0
const DENSITY=[0.16,0.35,0.68,1.0]
const DISTANCE=[235.0,350.0,480.0,600.0]
const LOD_BIAS=[0.6,0.8,1.0,1.3]
const BANDS=[Vector2(100,220),Vector2(220,420),Vector2(420,650)]
const TARGETS=[2250,800,300]
var quality=2
var batches:Array[MultiMeshInstance3D]=[]
var material:ShaderMaterial
var audit:Dictionary={}
var positions:Array[Vector3]=[]
var placement_records:Array[Dictionary]=[]
var grounding_grid:Dictionary={}
var ground_faces:PackedVector3Array
var baseline_roots:Array[Vector3]=[]
var minimum_radius=INF
var nearest_lake=INF
var full_triangles=0

static func apply(world:Node3D)->Dictionary:
 if world.has_node('NorthWoodlandStage2'):
  var existing=world.get_node('NorthWoodlandStage2')
  return {'ok':true,'already_installed':true,'audit':existing.audit}
 if world.get_node_or_null('DistantValleyV093')==null:return {'ok':false,'reason':'Original distant valley must remain installed'}
 var backdrop=world.get_node_or_null('ValleyBackdrop')
 if backdrop==null or not backdrop.get('terrain_vertices') is PackedVector3Array:return {'ok':false,'reason':'Original scenic terrain unavailable'}
 var lake_result:Dictionary=world.get_meta('inn_lake_v088',{})
 if not lake_result.get('ok',false) or not lake_result.get('backdrop',{}).get('present',false):return {'ok':false,'reason':'Lake exclusion must be installed before distant scenery'}
 var candidate=load('res://scripts/north_woodland_stage2_v094.gd').new()
 candidate.name='NorthWoodlandStage2'
 candidate.build(backdrop)
 if not candidate.audit.get('ok',false):
  var failure=candidate.audit.duplicate(true);candidate.free();return failure
 candidate.refine_terrain(backdrop)
 world.add_child(candidate)
 return {'ok':true,'audit':candidate.audit}

func _ready():
 add_to_group('distant_scenery_quality')
 set_quality(Settings.new().current_scenery_quality(self))

func set_quality(value:int):
 quality=clampi(value,0,3)
 if material!=null:material.set_shader_parameter('render_distance',DISTANCE[quality])
 var visible=0
 for batch in batches:
  var count=maxi(1,int(batch.multimesh.instance_count*DENSITY[quality]))
  batch.multimesh.visible_instance_count=count
  # Entire spatial batch may be culled only beyond its actual radius. The shader
  # independently collapses every instance at the chosen camera distance.
  var box: AABB=batch.multimesh.custom_aabb
  batch.visibility_range_end=DISTANCE[quality]+box.size.length()*.5+2.0
  # MultiMesh LOD sees the batch transform, not each tree's height scale.
  batch.lod_bias=LOD_BIAS[quality]*float(batch.get_meta('lod_reference_scale',1.0))
  visible+=count
 audit['quality']=quality;audit['density_limit']=visible;audit['render_distance']=DISTANCE[quality]

func _index_ground(backdrop:Node3D):
 ground_faces=backdrop.terrain_vertices
 for i in range(0,ground_faces.size(),3):
  var a=ground_faces[i];var b=ground_faces[i+1];var c=ground_faces[i+2]
  var low=Vector2(minf(a.x,minf(b.x,c.x)),minf(a.z,minf(b.z,c.z)))
  var high=Vector2(maxf(a.x,maxf(b.x,c.x)),maxf(a.z,maxf(b.z,c.z)))
  for z in range(floori(low.y/GRID),floori(high.y/GRID)+1):
   for x in range(floori(low.x/GRID),floori(high.x/GRID)+1):
    var key=Vector2i(x,z)
    if not grounding_grid.has(key):grounding_grid[key]=PackedInt32Array()
    grounding_grid[key].append(i)
 for entry in backdrop.get_meta('approved_forest_journal',[]):
  if Lake.lake_distance(Vector2(entry.root.x,entry.root.z))>=1.0:baseline_roots.append(entry.root)

func ground_height(p:Vector2)->float:
 var highest=-INF
 for i in grounding_grid.get(Vector2i(floori(p.x/GRID),floori(p.y/GRID)),PackedInt32Array()):
  var a:Vector3=ground_faces[i];var b:Vector3=ground_faces[i+1];var c:Vector3=ground_faces[i+2]
  var v0=Vector2(b.x-a.x,b.z-a.z);var v1=Vector2(c.x-a.x,c.z-a.z);var v2=p-Vector2(a.x,a.z)
  var determinant=v0.cross(v1)
  if absf(determinant)<.000001:continue
  var u=v2.cross(v1)/determinant;var v=v0.cross(v2)/determinant
  if u>=-.00001 and v>=-.00001 and u+v<=1.00001:highest=maxf(highest,a.y+u*(b.y-a.y)+v*(c.y-a.y))
 return highest

func clear_position(p:Vector2,footprint:float)->bool:
 if p.length()<76.0+footprint:return false
 if absf(atan2(p.x,-p.y))+asin(footprint/p.length())>deg_to_rad(52.0):return false
 # Bound the whole canopy, not only its trunk, outside water and its visual bank.
 if Lake.lake_distance(p)<1.085+footprint/minf(Lake.RADII.x,Lake.RADII.y):return false
 # Preserve authored ruin shelves and a clear approach to their waterfall face.
 if p.distance_to(Vector2(145,-95))<37.0+footprint or p.distance_to(Vector2(-150,125))<32.0+footprint:return false
 var ray=Vector2(145,-95).normalized();var along=p.dot(ray);var across=absf(p.cross(ray))
 if along>85.0-footprint and along<180.0+footprint and across<12.0+footprint:return false
 for root in baseline_roots:
  if p.distance_squared_to(Vector2(root.x,root.z))<pow(5.0+footprint,2):return false
 return true

func build(backdrop:Node3D):
 var began=Time.get_ticks_msec()
 _index_ground(backdrop)
 material=ShaderMaterial.new();material.shader=FOREST_SHADER
 var meshes=[woodland_mesh(false),woodland_mesh(true)]
 var mesh_radii=[]
 for mesh in meshes:
  var maximum=0.0
  for vertex in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:maximum=maxf(maximum,Vector2(vertex.x,vertex.z).length())
  mesh_radii.append(maximum)
 var groups:Dictionary={}
 var rng=RandomNumberGenerator.new();rng.seed=SEED
 var band_counts=[]
 for band in BANDS.size():
  var accepted=0
  for attempt in range(TARGETS[band]*16):
   if accepted>=TARGETS[band]:break
   var angle=rng.randf_range(deg_to_rad(218.0),deg_to_rad(322.0))
   var radius=sqrt(rng.randf_range(BANDS[band].x*BANDS[band].x,BANDS[band].y*BANDS[band].y))
   var p=Vector2(cos(angle),sin(angle))*radius
   # Large uneven wooded patches leave rock/meadow openings instead of a fence.
   var cover=.53+.21*sin(p.x*.035+p.y*.018)+.18*sin(p.y*.051-p.x*.014)
   if rng.randf()>cover:continue
   var height=rng.randf_range(5.0,9.0) if band==0 else rng.randf_range(7.0,11.0)
   var kind=1 if rng.randf()<(0.28 if band==0 else 0.62) else 0
   var width=rng.randf_range(.84,1.14)
   var footprint=height*width*mesh_radii[kind]
   if not clear_position(p,footprint):continue
   var y=ground_height(p)
   if not is_finite(y) or y<.7 or y>95.0:continue
   var origin=Vector3(p.x,y-.15,p.y)
   var sector=mini(SECTORS-1,floori(angle/TAU*SECTORS))
   var key=Vector3i(band,sector,kind)
   if not groups.has(key):groups[key]=[]
   var transform=Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(height*width,height,height*width)),origin)
   var tint=Color(rng.randf_range(.88,1.08),rng.randf_range(.90,1.08),rng.randf_range(.83,1.02))
   # Keep the small mountain forests green; flowering foreground accents are
   # authored separately in the marked individual-tree stage.
   var color_choice=rng.randf()
   if kind==0 and color_choice<.16:tint=Color(1.06,1.04,.86)
   groups[key].append({'transform':transform,'color':tint})
   placement_records.append({'origin':origin,'radius':footprint,'kind':kind})
   positions.append(origin);minimum_radius=minf(minimum_radius,p.length());nearest_lake=minf(nearest_lake,Lake.lake_distance(p));accepted+=1
  band_counts.append(accepted)
 var keys=groups.keys();keys.sort()
 for key in keys:
  var entries:Array=groups[key];var mesh:Mesh=meshes[key.z]
  var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=mesh;mm.instance_count=entries.size()
  var bounds=AABB();var reference_scale=0.0
  for i in entries.size():
   var entry=entries[i];reference_scale+=entry.transform.basis.y.length();mm.set_instance_transform(i,entry.transform);mm.set_instance_color(i,entry.color)
   var box:AABB=entry.transform*mesh.get_aabb();bounds=box if i==0 else bounds.merge(box)
  mm.custom_aabb=bounds.grow(.2)
  var batch=MultiMeshInstance3D.new();batch.name='Forest_%d_%02d_%s'%[key.x,key.y,'Pine' if key.z else 'Broadleaf'];batch.multimesh=mm;batch.material_override=material;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  batch.set_meta('lod_reference_scale',reference_scale/entries.size())
  batch.set_meta('source_transforms',entries.map(func(entry):return entry.transform));batch.set_meta('band',key.x);batch.set_meta('sector',key.y)
  add_child(batch);batches.append(batch);full_triangles+=mesh.get_faces().size()/3*entries.size()
 audit={'ok':not batches.is_empty(),'seed':SEED,'instances':positions.size(),'batches':batches.size(),'band_counts':band_counts,'full_detail_triangle_upper_bound':full_triangles,'minimum_root_radius':minimum_radius,'minimum_lake_distance':nearest_lake,'new_colliders':0,'new_lights':0,'new_textures':0,'new_shadow_casters':0,'runtime_process_callbacks':0,'baseline_geometry_unchanged':true,'revision':94,'scope':'North/fishing only, 40 degree core and 52 degree soft edge','lake_geometry_unchanged':true,'build_msec_cpu_observation':Time.get_ticks_msec()-began,'fps_measured':false}
 grounding_grid.clear();ground_faces=PackedVector3Array();baseline_roots.clear()

static func _face(parts:Array,a:Vector3,b:Vector3,c:Vector3,color:Color):parts.append([a,b,c,color])
static func _tube(parts:Array,start:Vector3,finish:Vector3,r0:float,r1:float,sides:int,color:Color):
 var axis=(finish-start).normalized();var right=axis.cross(Vector3.RIGHT if absf(axis.x)<.8 else Vector3.FORWARD).normalized();var forward=axis.cross(right).normalized()
 for i in sides:
  var a=TAU*i/sides;var b=TAU*(i+1)/sides
  var p=start+(right*cos(a)+forward*sin(a))*r0;var q=start+(right*cos(b)+forward*sin(b))*r0
  var u=finish+(right*cos(a)+forward*sin(a))*r1;var v=finish+(right*cos(b)+forward*sin(b))*r1
  _face(parts,p,u,q,color);_face(parts,q,u,v,color)
func refine_terrain(backdrop:Node3D):
 var changed=[]
 for name in ['MiddleRidge','OuterFoothills','DistantAlpineRange']:
  var node=backdrop.get_node_or_null(name) as MeshInstance3D
  if node==null:continue
  var old=node.material_override
  var refined=ShaderMaterial.new();refined.shader=TERRAIN_SHADER
  refined.set_shader_parameter('terrain_band',2 if name=='DistantAlpineRange' else (1 if name=='OuterFoothills' else 0))
  if old is ShaderMaterial:refined.set_shader_parameter('original_tint',old.get_shader_parameter('tint'))
  node.set_meta('pre_distant_v094_material',old)
  node.material_override=refined;changed.append(name)
 audit['refined_terrain_materials']=changed

# Low-cost volume crowns maintain a wooded silhouette at every LOD.
# All levels keep several overlapping lobes rather than reducing to one diamond.
static func woodland_mesh(pine:bool)->ArrayMesh:
 var vertices=PackedVector3Array();var normals=PackedVector3Array();var colors=PackedColorArray();var levels=[]
 for level in 3:
  var parts=[]
  _tube(parts,Vector3.ZERO,Vector3(0,.76,0),.034,.012,6 if level==0 else 4,Color('1b2018'))
  if pine:
   var rings=11 if level==0 else (9 if level==1 else 7)
   var sides=10 if level==0 else (8 if level==1 else 6)
   for ring in rings-1:
    var t=float(ring)/float(rings-1);var u=float(ring+1)/float(rings-1)
    for side in sides:
     var a=TAU*side/sides;var b=TAU*(side+1)/sides
     var r=.25*pow(1.0-t,.78)*(1.0 if ring%2==0 else .77)
     var rr=.25*pow(1.0-u,.78)*(1.0 if (ring+1)%2==0 else .77)
     var pa=Vector3(cos(a)*r*(1.0+.07*sin(side*2.7+ring)),.10+t*.94,sin(a)*r)
     var pb=Vector3(cos(b)*r*(1.0+.07*sin((side+1)*2.7+ring)),.10+t*.94,sin(b)*r)
     var qa=Vector3(cos(a)*rr,.10+u*.94,sin(a)*rr);var qb=Vector3(cos(b)*rr,.10+u*.94,sin(b)*rr)
     var color=Color('2b4937').lightened(.04*t+.025*sin(side*1.7))
     _face(parts,pa,qa,pb,color);_face(parts,pb,qa,qb,color)
  else:
   var lobes=7 if level<2 else 5
   var sides=8 if level==0 else (6 if level==1 else 5)
   var rings=5 if level==0 else (4 if level==1 else 3)
   for lobe in lobes:
    var a=TAU*lobe/lobes+.3
    var center=Vector3(cos(a)*.18,.67+.16*sin(a*1.7),sin(a)*.18)
    if lobe==lobes-1:center=Vector3(0,.88,0)
    if level==0:_tube(parts,Vector3(0,.35,0),center,.018,.007,4,Color('1b2018'))
    _ellipsoid(parts,center,Vector3(.235,.22,.235),sides,rings,Color('35513d').lightened((lobe%3)*.018),lobe)
  var ids=PackedInt32Array()
  for face in parts:
   var normal=(face[1]-face[0]).cross(face[2]-face[0]).normalized()
   for vertex_index in [0,2,1]:
    var point=face[vertex_index]
    var smooth_normal=face[4][vertex_index] if face.size()>4 else normal
    ids.append(vertices.size());vertices.append(point);normals.append(smooth_normal);colors.append(face[3])
  levels.append(ids)
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=levels[0]
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{.024:levels[1],.075:levels[2]})
 return mesh

static func _ellipsoid(parts:Array,center:Vector3,radius:Vector3,sides:int,rings:int,color:Color,seed:int):
 for ring in rings:
  var t0=PI*ring/rings;var t1=PI*(ring+1)/rings
  for side in sides:
   var a=TAU*side/sides;var b=TAU*(side+1)/sides
   var p=center+Vector3(cos(a)*sin(t0),cos(t0),sin(a)*sin(t0))*radius*(1.0+.16*sin(side*2.1+ring*3.3+seed))
   var q=center+Vector3(cos(b)*sin(t0),cos(t0),sin(b)*sin(t0))*radius*(1.0+.16*sin((side+1)*2.1+ring*3.3+seed))
   var r=center+Vector3(cos(a)*sin(t1),cos(t1),sin(a)*sin(t1))*radius*(1.0+.16*sin(side*2.1+(ring+1)*3.3+seed))
   var v=center+Vector3(cos(b)*sin(t1),cos(t1),sin(b)*sin(t1))*radius*(1.0+.16*sin((side+1)*2.1+(ring+1)*3.3+seed))
   var tint=color.lightened(.035*sin(side*1.71+seed*3.0+ring*.7))
   if ring>0:_canopy_face(parts,p,q,r,tint,center,radius)
   if ring<rings-1:_canopy_face(parts,q,v,r,tint,center,radius)

static func _canopy_face(parts:Array,a:Vector3,b:Vector3,c:Vector3,color:Color,center:Vector3,radius:Vector3):
 parts.append([a,b,c,color,[((a-center)/(radius*radius)).normalized(),((b-center)/(radius*radius)).normalized(),((c-center)/(radius*radius)).normalized()]])
