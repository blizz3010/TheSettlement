extends Node3D
# User-marked far-bank meadow only. No water, terrain, collision, fishing or save changes.
const Terrain=preload('res://scripts/settlement_terrain.gd')
const Stream=preload('res://scripts/settlement_stream.gd')
const Settings=preload('res://scripts/game_settings.gd')
const GRASS_SHADER=preload('res://shaders/riverbank_grass_v094.gdshader')
const SEED=2026110494
const LIMIT=64.0
const FRACTION=[.22,.45,.72,1.0]
const RANGE=[42.0,60.0,85.0,110.0]
var quality=2
var batches:Array[MultiMeshInstance3D]=[]
var grass_batches:Array[MultiMeshInstance3D]=[]
var audit={}
var grass_material:ShaderMaterial
var lattice={}
var shore=[]
var occupied=[]
var records=[]
var groups={}
var meshes={}
var mesh_radii={}
var rng=RandomNumberGenerator.new()

static func apply(world:Node3D)->Dictionary:
 if world.has_node('NorthRiverbankStage1'):return {'ok':true,'already_installed':true,'audit':world.get_node('NorthRiverbankStage1').audit}
 if world.get_node_or_null('NorthernStream/ShallowFlow')==null or world.get_node_or_null('SettlementOuterTerrain/GroundRelief')==null:return {'ok':false,'reason':'Riverbank requires original stream and connected terrain'}
 var candidate=load('res://scripts/riverbank_stage1_v094.gd').new();candidate.name='NorthRiverbankStage1';candidate.build(world.get_node('NorthernStream/ShallowFlow'))
 if not candidate.audit.get('ok',false):candidate.free();return {'ok':false,'reason':'Riverbank geometry preparation failed'}
 world.add_child(candidate)
 return {'ok':true,'audit':candidate.audit}

func _ready():
 add_to_group('plaza_grass_quality')
 set_quality(Settings.new().current_grass_quality(self))

func set_quality(value:int):
 quality=clampi(value,0,3)
 grass_material.set_shader_parameter('detail_distance',RANGE[quality])
 var count=0
 for batch in batches:
  var radius=batch.multimesh.custom_aabb.size.length()*.5
  batch.visibility_range_end=RANGE[quality]+radius+3.0
 for batch in grass_batches:
  batch.multimesh.visible_instance_count=maxi(1,int(batch.multimesh.instance_count*FRACTION[quality]));count+=batch.multimesh.visible_instance_count
 audit['grass_quality']=quality;audit['grass_density_limit']=count;audit['detail_distance']=RANGE[quality]

func shoreline(x:float)->float:
 var at=clampf((x+40.0)*2.0,0.0,float(shore.size()-1))
 var i=floori(at);return lerpf(shore[i],shore[mini(i+1,shore.size()-1)],at-i)

func height_vertex(x:int,z:int)->float:
 var key=Vector2i(x,z)
 if not lattice.has(key):lattice[key]=Terrain.height_at(float(x),float(z))
 return lattice[key]

func ground(p:Vector2)->float:
 var x=floori(p.x);var z=floori(p.y);var u=p.x-x;var v=p.y-z
 var a=height_vertex(x,z);var b=height_vertex(x+1,z);var c=height_vertex(x,z+1);var d=height_vertex(x+1,z+1)
 return a+(b-a)*u+(c-a)*v if u+v<=1 else d+(c-d)*(1-u)+(b-d)*(1-v)

func inside(p:Vector2,radius:float)->bool:
 if absf(p.x)+radius>39.0 or p.length()+radius>LIMIT:return false
 # Every footprint stays north of the exact original half-metre water edge.
 for dx in [-radius,0.0,radius]:
  if p.y+radius>shoreline(p.x+dx)-.10:return false
 if p.y-radius< -64.0:return false
 # Conservative full fishing stance/cast corridor; no north-side exception.
 if Rect2(p-Vector2.ONE*radius,Vector2.ONE*radius*2).intersects(Rect2(13.6,-46.1,2.8,5.9),true):return false
 return true

func radius_for(mesh:Mesh,scale:Vector3)->float:
 if not mesh_radii.has(mesh):
  var radius=0.0
  for surface in mesh.get_surface_count():
   for p in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:radius=maxf(radius,Vector2(p.x,p.z).length())
  mesh_radii[mesh]=radius
 # Conservative across all yaw angles and non-uniform XZ scales.
 return mesh_radii[mesh]*maxf(scale.x,scale.z)

func place(kind:String,p:Vector2,scale:Vector3,clear_rocks:bool=true)->bool:
 var mesh:Mesh=meshes[kind]
 var radius=radius_for(mesh,scale)+(.035*scale.x if kind=='grass' else 0.0)
 if not inside(p,radius):return false
 if clear_rocks:
  for rock in occupied:
   if p.distance_squared_to(rock.p)<pow(radius+rock.r+.06,2):return false
 var y=ground(p)-mesh.get_aabb().position.y*scale.y-(.035 if kind=='rock' else .012)
 var transform=Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(scale),Vector3(p.x,y,p.y))
 var segment=clampi(int((p.x+40.0)/10.0),0,7)
 var key=kind+'_'+str(segment)
 if not groups.has(key):groups[key]=[]
 groups[key].append(transform);records.append({'kind':kind,'position':p,'radius':radius,'transform':transform})
 if kind=='rock':occupied.append({'p':p,'r':radius})
 return true

static func imported_mesh(path:String)->Mesh:
 var root=load(path).instantiate();var list=root.find_children('*','MeshInstance3D',true,false)
 assert(list.size()==1 and list[0].transform.is_equal_approx(Transform3D.IDENTITY))
 var mesh=list[0].mesh;root.free();return mesh

static func river_rock_mesh()->ArrayMesh:
 # Private mesh/material copies: soften only the added bank stones, never the
 # shared licensed rock resource or any existing settlement object.
 var source=imported_mesh('res://assets/quaternius/Rock_Medium_1.gltf')
 var mesh=ArrayMesh.new()
 for surface in source.get_surface_count():
  var arrays=source.surface_get_arrays(surface)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL].duplicate()
  var sums={}
  for i in vertices.size():
   var key=Vector3i(roundi(vertices[i].x*100000),roundi(vertices[i].y*100000),roundi(vertices[i].z*100000))
   sums[key]=sums.get(key,Vector3.ZERO)+normals[i]
  for i in vertices.size():
   var key=Vector3i(roundi(vertices[i].x*100000),roundi(vertices[i].y*100000),roundi(vertices[i].z*100000))
   normals[i]=sums[key].normalized()
  arrays[Mesh.ARRAY_NORMAL]=normals
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var material=source.surface_get_material(surface).duplicate() as StandardMaterial3D
  material.albedo_color=Color(.52,.55,.48);material.roughness=1.0
  mesh.surface_set_material(surface,material)
 return mesh

func build(water:MeshInstance3D=null):
 var start=Time.get_ticks_msec();rng.seed=SEED
 var edge={}
 if water!=null:
  for vertex in water.mesh.get_faces():
   var p=water.global_transform*vertex;var key=roundi(p.x*2.0)
   if absf(p.x*2.0-key)>.00001:audit={'ok':false,'reason':'Unexpected original water lattice'};return
   edge[key]=minf(edge.get(key,INF),p.z)
 for i in 161:
  var x=-40.0+float(i)*.5
  if water!=null:
   if not edge.has(roundi(x*2.0)):audit={'ok':false,'reason':'Original water edge missing'};return
   shore.append(edge[roundi(x*2.0)])
  else:
   # Isolated structural fixture only. Production reads the actual water mesh.
   shore.append(Terrain.stream_z(x)-Stream.bank_offset(x,-1.0))
 meshes['rock']=river_rock_mesh()
 meshes['fern']=imported_mesh('res://assets/groundcover/ground_fern_a.glb')
 var garden=load('res://assets/approved_gardens_v086.scn').instantiate()
 for kind in ['cover','daisy','violet','evergreen','airy']:
  var found=garden.find_children('Variation_'+kind,'MultiMeshInstance3D',true,false);assert(not found.is_empty());meshes[kind]=found[0].multimesh.mesh
 garden.free();meshes['grass']=grass_mesh()
 grass_material=ShaderMaterial.new();grass_material.shader=GRASS_SHADER
 # Irregular, low shore stones. Original water surface is untouched and visible.
 var x=-37.5
 while x<38.0:
  var width=rng.randf_range(.34,.84)
  var scale=Vector3(width/3.225,width/3.225*rng.randf_range(.53,.85),width/3.225*rng.randf_range(.75,1.12))
  var radius=radius_for(meshes.rock,scale)
  var p=Vector2(x,shoreline(x)-radius-rng.randf_range(.15,.46))
  place('rock',p,scale,false)
  x+=rng.randf_range(.43,.74)
 # Larger accents sit in the field and support planted groups, leaving open meadow.
 for point in [Vector2(-28,-55.0),Vector2(-17,-59.0),Vector2(4,-54.2),Vector2(25,-53.3),Vector2(34,-50.8)]:
  var width=rng.randf_range(1.7,2.45);place('rock',point,Vector3(width/3.225,width/3.225*.66,width/3.225*.91),false)
 var anchors=[]
 for ax in [-35.0,-28.0,-20.0,-9.0,2.0,12.0,24.0,33.0]:anchors.append(Vector2(ax,shoreline(ax)-rng.randf_range(2.0,3.4)))
 for p in [Vector2(-23,-57),Vector2(-8,-61),Vector2(13,-59),Vector2(28,-53)]:anchors.append(p)
 var requested={'fern':95,'cover':170,'daisy':140,'violet':28,'evergreen':28,'airy':36}
 for kind in requested:
  var accepted=0
  for attempt in int(requested[kind])*16:
   if accepted>=requested[kind]:break
   var anchor:Vector2=anchors[rng.randi_range(0,anchors.size()-1)]
   var p=anchor+Vector2(rng.randf_range(-2.2,2.2),rng.randf_range(-1.2,1.2))
   var scale=rng.randf_range(.63,1.12)
   if kind=='daisy':scale=rng.randf_range(.34,.65)
   elif kind=='violet':scale=rng.randf_range(.55,.9)
   elif kind=='fern':scale=rng.randf_range(1.35,2.25)
   elif kind in ['evergreen','airy']:scale=rng.randf_range(.65,1.05)
   if place(kind,p,Vector3.ONE*scale):accepted+=1
 # Meadow grass remains short in the center, taller at the planted bank margins.
 var grass_count=0
 for attempt in 50000:
  if grass_count>=5600:break
  var p=Vector2(rng.randf_range(-38.5,38.5),rng.randf_range(-63.5,-46.0))
  if not inside(p,.22):continue
  var depth=shoreline(p.x)-p.y
  var density=.70+.18*sin(p.x*.36+p.y*.19)+.12*cos(p.y*.73-p.x*.14)
  if rng.randf()>density:continue
  var height=rng.randf_range(.55,.95) if depth<3.5 or depth>10.0 else rng.randf_range(.32,.58)
  if place('grass',p,Vector3(rng.randf_range(.72,1.15),height,rng.randf_range(.72,1.15))):grass_count+=1
 var triangles=0;var counts={};var keys=groups.keys();keys.sort()
 for key in keys:
  var kind=key.get_slice('_',0);var entries:Array=groups[key];var mesh:Mesh=meshes[kind]
  var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=entries.size()
  var bounds=AABB()
  for i in entries.size():
   mm.set_instance_transform(i,entries[i]);var box=entries[i]*mesh.get_aabb();bounds=box if i==0 else bounds.merge(box)
  mm.custom_aabb=bounds.grow(.06)
  var batch=MultiMeshInstance3D.new();batch.name='Bank_'+key;batch.multimesh=mm;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  batch.set_meta('source_transforms',entries);batch.set_meta('bank_kind',kind)
  if kind=='grass':batch.material_override=grass_material;grass_batches.append(batch)
  add_child(batch);batches.append(batch)
  triangles+=mesh.get_faces().size()/3*entries.size();counts[kind]=counts.get(kind,0)+entries.size()
 audit={'ok':grass_count==5600,'scope':'User-marked north bank meadow only','seed':SEED,'counts':counts,'batches':batches.size(),'full_detail_triangle_upper_bound':triangles,'new_colliders':0,'water_changes':0,'terrain_geometry_changes':0,'existing_object_changes':0,'new_lights':0,'new_texture_files':0,'runtime_process_callbacks':0,'build_msec_cpu_observation':Time.get_ticks_msec()-start,'fps_measured':false}
 set_quality(2);lattice.clear()

static func grass_mesh()->ArrayMesh:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for blade in 7:
  var a=blade*2.39996323;var base=Vector3(cos(a),0,sin(a))*.13*sqrt(float(blade)/7.0)
  var side=Vector3(cos(a+.9),0,sin(a+.9));var bend=Vector3(cos(a),0,sin(a))*.12
  var height=.23+.13*sin(blade*1.7+.8)
  for segment in 2:
   var t=float(segment)/2.0;var u=float(segment+1)/2.0
   var p=base+Vector3.UP*height*t+bend*t*t;var q=base+Vector3.UP*height*u+bend*u*u
   var w=.018*(1.0-t);var ww=.018*(1.0-u)
   var points=[p-side*w,q-side*ww,p+side*w,p+side*w,q-side*ww,q+side*ww]
   for i in 6:
    st.set_uv(Vector2(0.0,u if i in [1,4,5] else t));st.set_color(Color('4c6d35').darkened((blade%3)*.04));st.add_vertex(points[i])
 st.generate_normals();return st.commit()
