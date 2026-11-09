extends Node3D
# One continuous, render-only forest valley shared by every approved viewpoint.
# Installed after the existing lake adapter. Original terrain, water, vegetation,
# ruins, colliders, sky, lights and saved state remain authoritative and untouched.
const Lake=preload('res://scripts/inn_lake_v088.gd')
const Settings=preload('res://scripts/game_settings.gd')
const FOREST_SHADER=preload('res://shaders/distant_forest_v093.gdshader')
const SEED=2026110493
const SECTORS=16
const GRID=32.0
const DENSITY=[0.28,0.50,0.78,1.0]
const DISTANCE=[235.0,350.0,480.0,600.0]
const LOD_BIAS=[0.6,0.8,1.0,1.3]
const BANDS=[Vector2(112,205),Vector2(205,315),Vector2(315,460)]
const TARGETS=[750,1150,1450]
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
 if world.has_node('DistantValleyV093'):
  var existing=world.get_node('DistantValleyV093')
  return {'ok':true,'already_installed':true,'audit':existing.audit}
 var backdrop=world.get_node_or_null('ValleyBackdrop')
 if backdrop==null or not backdrop.get('terrain_vertices') is PackedVector3Array:return {'ok':false,'reason':'Original scenic terrain unavailable'}
 var lake_result:Dictionary=world.get_meta('inn_lake_v088',{})
 if not lake_result.get('ok',false) or not lake_result.get('backdrop',{}).get('present',false):return {'ok':false,'reason':'Lake exclusion must be installed before distant scenery'}
 var candidate=load('res://scripts/distant_valley_v093.gd').new()
 candidate.name='DistantValleyV093'
 candidate.build(backdrop)
 if not candidate.audit.get('ok',false):
  var failure=candidate.audit.duplicate(true);candidate.free();return failure
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
 if p.length()<108.0+footprint:return false
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
 var meshes=[approved_broadleaf_mesh(),tree_mesh(true)]
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
   var angle=rng.randf_range(0,TAU)
   var radius=sqrt(rng.randf_range(BANDS[band].x*BANDS[band].x,BANDS[band].y*BANDS[band].y))
   var p=Vector2(cos(angle),sin(angle))*radius
   # Large uneven wooded patches leave rock/meadow openings instead of a fence.
   var cover=.53+.21*sin(p.x*.035+p.y*.018)+.18*sin(p.y*.051-p.x*.014)
   if rng.randf()>cover:continue
   var height=rng.randf_range(7.5,12.0) if band==0 else rng.randf_range(8.0,15.0)
   var kind=1 if rng.randf()<(0.42 if band==0 else 0.67) else 0
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
   if kind==0 and rng.randf()<.055:tint=Color(1.13,.78,.80)
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
 audit={'ok':not batches.is_empty(),'seed':SEED,'instances':positions.size(),'batches':batches.size(),'band_counts':band_counts,'full_detail_triangle_upper_bound':full_triangles,'minimum_root_radius':minimum_radius,'minimum_lake_distance':nearest_lake,'new_colliders':0,'new_lights':0,'new_textures':0,'new_shadow_casters':0,'runtime_process_callbacks':0,'baseline_geometry_unchanged':true,'lake_geometry_unchanged':true,'build_msec_cpu_observation':Time.get_ticks_msec()-began,'fps_measured':false}
 grounding_grid.clear();ground_faces=PackedVector3Array();baseline_roots.clear()

# Reuse the approved broadleaf silhouette with its existing reduced topology.
# Original resources remain immutable. Normalize only this private render mesh.
static func approved_broadleaf_mesh()->ArrayMesh:
 var source=preload('res://scripts/foliage_wind.gd')._mesh('border_tree_a')
 var arrays=source.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
 var height=source.get_aabb().end.y
 for i in vertices.size():vertices[i]/=height
 arrays[Mesh.ARRAY_VERTEX]=vertices
 var imported_lods=RenderingServer.mesh_get_surface(source.get_rid(),0).get('lods',[])
 assert(imported_lods.size()==3)
 var indices=[]
 for entry in imported_lods:
  var bytes:PackedByteArray=entry.index_data;var decoded=PackedInt32Array()
  var stride=2 if vertices.size()<=65536 else 4
  decoded.resize(bytes.size()/stride)
  for i in decoded.size():decoded[i]=bytes.decode_u16(i*stride) if stride==2 else bytes.decode_u32(i*stride)
  indices.append(decoded)
 # Imported decimation keeps branches but drops almost every leaf (480 green
 # crown triangles at the first level, six at the next and none at the last).
 # Preserve the first reduced leafy crown while simplifying only the wood.
 var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
 var crown=PackedInt32Array()
 for i in range(0,indices[0].size(),3):
  var color:Color=colors[indices[0][i]]
  if color.g>color.r*1.1:
   crown.append_array(indices[0].slice(i,i+3))
 var lower=[]
 for level in [1,2]:
  var combined=crown.duplicate()
  for i in range(0,indices[level].size(),3):
   var color:Color=colors[indices[level][i]]
   if color.g<=color.r*1.1:combined.append_array(indices[level].slice(i,i+3))
  lower.append(combined)
 arrays[Mesh.ARRAY_INDEX]=indices[0]
 var mesh=ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{.025:lower[0],.085:lower[1]})
 return mesh

# Three opaque 3D mesh levels share one surface, chosen by Godot's mesh LOD.
# They are original simple silhouettes, not imported high-detail nearby assets.
static func tree_mesh(pine:bool)->ArrayMesh:
 var vertices=PackedVector3Array();var normals=PackedVector3Array();var colors=PackedColorArray();var all_indices=[]
 for level in range(3):
  var parts=[];var sides=12 if level==0 else (9 if level==1 else 7)
  _tube(parts,Vector3.ZERO,Vector3(0,.82 if pine else .70,0),.028,.014,6 if level==0 else 3,Color('554632'))
  if pine:
   var layers=8 if level==0 else (6 if level==1 else 5)
   for layer in layers:
    var t=float(layer)/layers
    var low=.08+t*.70;var high=minf(1.0,low+.30)
    _cone(parts,Vector3(0,low,0),.235*pow(1.0-t*.78,.82),high-low,sides,Color('294532').lightened(t*.045))
  else:
   var lobes=5 if level==0 else (3 if level==1 else 1)
   for lobe in lobes:
    var a=TAU*lobe/maxi(lobes,1)+.4
    var off=.145 if lobes>1 else 0.0
    var center=Vector3(cos(a)*off,.76+.10*sin(a*2.0+.6),sin(a)*off)
    if level==0:_tube(parts,Vector3(0,.41,0),center,.018,.008,4,Color('594b35'))
    var dimensions=Vector3(.225,.155,.205) if lobes>1 else Vector3(.31,.24,.29)
    _crown(parts,center,dimensions,sides,Color('4c6b3d').lightened((lobe%3)*.035))
  var indices=PackedInt32Array()
  for face in parts:
   var normal=(face[1]-face[0]).cross(face[2]-face[0]).normalized()
   for point in [face[0],face[1],face[2]]:
    indices.append(vertices.size());vertices.append(point);normals.append(normal);colors.append(face[3])
  all_indices.append(indices)
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=all_indices[0]
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{.025:all_indices[1],.085:all_indices[2]})
 return mesh

static func _face(parts:Array,a:Vector3,b:Vector3,c:Vector3,color:Color):parts.append([a,b,c,color])
static func _tube(parts:Array,start:Vector3,finish:Vector3,r0:float,r1:float,sides:int,color:Color):
 var axis=(finish-start).normalized();var right=axis.cross(Vector3.RIGHT if absf(axis.x)<.8 else Vector3.FORWARD).normalized();var forward=axis.cross(right).normalized()
 for i in sides:
  var a=TAU*i/sides;var b=TAU*(i+1)/sides
  var p=start+(right*cos(a)+forward*sin(a))*r0;var q=start+(right*cos(b)+forward*sin(b))*r0
  var u=finish+(right*cos(a)+forward*sin(a))*r1;var v=finish+(right*cos(b)+forward*sin(b))*r1
  _face(parts,p,u,q,color);_face(parts,q,u,v,color)
static func _cone(parts:Array,base:Vector3,radius:float,height:float,sides:int,color:Color):
 for i in sides:
  var a=TAU*i/sides;var b=TAU*(i+1)/sides
  var p=base+Vector3(cos(a)*radius,0,sin(a)*radius);var q=base+Vector3(cos(b)*radius,0,sin(b)*radius)
  _face(parts,p,base+Vector3(0,height,0),q,color.lightened(.025*(i%2)))
  _face(parts,base,p,q,color.darkened(.17))
static func _crown(parts:Array,center:Vector3,dimensions:Vector3,sides:int,color:Color):
 for i in sides:
  var a=TAU*i/sides;var b=TAU*(i+1)/sides
  var p=center+Vector3(cos(a),.05*sin(a*3),sin(a))*dimensions;var q=center+Vector3(cos(b),.05*sin(b*3),sin(b))*dimensions
  _face(parts,p,center+Vector3(0,dimensions.y,0),q,color.lightened(.03*(i%3)))
  _face(parts,p,q,center-Vector3(0,dimensions.y*.68,0),color.darkened(.16))
