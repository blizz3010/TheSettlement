extends Node3D
# Only the marked north-facing exterior trees. Original positions, scale and the
# entire unmarked forest remain authoritative; no settlement foliage is changed.
const Wind=preload('res://scripts/foliage_wind.gd')
const Lake=preload('res://scripts/inn_lake_v088.gd')
const North=preload('res://scripts/north_woodland_stage2_v094.gd')
const Settings=preload('res://scripts/game_settings.gd')
const LEAF_SHADER=preload('res://shaders/north_leaves_v094.gdshader')
var batches:Array[MultiMeshInstance3D]=[]
var replacements=[]
var original_records=[]
var accent_records=[]
var audit={}
var quality=2

static func half_storage(value:float)->float:
 # Compatibility stores custom instance channels in half precision. Author new
 # blend/phase values in that exact format so native readback stays deterministic.
 var bytes=PackedByteArray();bytes.resize(2);bytes.encode_half(0,value);return bytes.decode_half(0)

static func weight(p:Vector3)->float:
 return smoothstep(cos(deg_to_rad(52.0)),cos(deg_to_rad(40.0)),Vector2(p.x,p.z).normalized().dot(Vector2(0,-1)))

static func apply(world:Node3D)->Dictionary:
 if world.has_node('NorthTreesStage3'):return {'ok':true,'already_installed':true,'audit':world.get_node('NorthTreesStage3').audit}
 var backdrop=world.get_node_or_null('ValleyBackdrop')
 if backdrop==null or not world.has_node('NorthWoodlandStage2'):return {'ok':false,'reason':'Marked north woodland must be installed first'}
 var candidate=load('res://scripts/north_trees_stage3_v094.gd').new();candidate.name='NorthTreesStage3'
 var result=candidate.prepare(backdrop)
 if not result.get('ok',false):candidate.free();return result
 # Commit only after both original batches and every placement are validated.
 for replacement in candidate.replacements:
  replacement.owner.set_meta('pre_north_tree_multimesh',replacement.owner.multimesh)
  replacement.owner.multimesh=replacement.multimesh
  replacement.owner.set_meta('instance_transforms',replacement.transforms)
 world.add_child(candidate)
 return {'ok':true,'audit':candidate.audit}

func _ready():
 add_to_group('distant_scenery_quality');set_quality(Settings.new().current_scenery_quality(self))

func set_quality(value:int):
 quality=clampi(value,0,3)
 for batch in batches:
  batch.lod_bias=[.6,.8,1.0,1.3][quality]*float(batch.get_meta('source_scale',1.0))
  if batch.get_meta('accent',false):batch.visibility_range_end=[235.0,350.0,480.0,600.0][quality]
 audit['quality']=quality

static func wood_lod(mesh:Mesh,first:bool)->PackedInt32Array:
 var a=mesh.surface_get_arrays(0);var uv2=a[Mesh.ARRAY_TEX_UV2]
 var lods=RenderingServer.mesh_get_surface(mesh.get_rid(),0).get('lods',[])
 var ids:PackedInt32Array=a[Mesh.ARRAY_INDEX]
 if not lods.is_empty():
  var bytes:PackedByteArray=lods[0 if first else lods.size()-1].index_data
  var stride=2 if a[Mesh.ARRAY_VERTEX].size()<=65536 else 4
  ids=PackedInt32Array()
  for i in bytes.size()/stride:ids.append(bytes.decode_u16(i*stride) if stride==2 else bytes.decode_u32(i*stride))
 var result=PackedInt32Array()
 for i in range(0,ids.size(),3):
  if uv2[ids[i]].y<.5 and uv2[ids[i+1]].y<.5 and uv2[ids[i+2]].y<.5:result.append_array(ids.slice(i,i+3))
 return result

static func leafy_mesh(source:Mesh)->Dictionary:
 assert(source.get_surface_count()==1)
 var original=source.surface_get_arrays(0);var a=[];a.resize(Mesh.ARRAY_MAX)
 for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_INDEX]:a[channel]=original[channel].duplicate()
 var groups={};var ids:PackedInt32Array=original[Mesh.ARRAY_INDEX];var uv=original[Mesh.ARRAY_TEX_UV];var uv2=original[Mesh.ARRAY_TEX_UV2]
 for i in range(0,ids.size(),3):
  if uv2[ids[i]].y<.5:continue
  var at=ids[i];var hinge=Vector3(uv[at].x,uv[at].y,uv2[at].x)
  if not groups.has(hinge):groups[hinge]=[]
  for j in 3:groups[hinge].append(ids[i+j])
 var bounds=source.get_aabb().grow(.00001);var added=0;var index=0
 for hinge in groups:
  var old:Array=groups[hinge].duplicate()
  # Two differently tilted opaque leaf fans give a fuller crown from below,
  # rather than stacking more almost-horizontal leaves at the same angle.
  for copy in 2:
   var angle=.68+float(index%5)*.19+float(copy)*1.17
   var rotation=Basis(Vector3.UP,angle)*Basis(Vector3.RIGHT,.52 if copy==0 else -.48)*Basis(Vector3.FORWARD,.21)
   var points=[];var allowed=true
   for at in old:
    var p=hinge+rotation*(original[Mesh.ARRAY_VERTEX][at]-hinge)*1.10
    if not bounds.has_point(p):allowed=false;break
    points.append(p)
   if allowed:
    for i in old.size():
     var at=old[i];var next=a[Mesh.ARRAY_VERTEX].size()
     a[Mesh.ARRAY_VERTEX].append(points[i]);a[Mesh.ARRAY_NORMAL].append((rotation*original[Mesh.ARRAY_NORMAL][at]).normalized())
     a[Mesh.ARRAY_COLOR].append(original[Mesh.ARRAY_COLOR][at]);a[Mesh.ARRAY_TEX_UV].append(uv[at]);a[Mesh.ARRAY_TEX_UV2].append(Vector2(uv2[at].x,2.0))
     a[Mesh.ARRAY_INDEX].append(next);groups[hinge].append(next)
    added+=old.size()/3
  index+=1
 var medium=wood_lod(source,true);var low=wood_lod(source,false)
 var mid_groups=0;var low_groups=0
 for hinge in groups:
  var rank=fposmod(sin(hinge.dot(Vector3(12.9898,78.233,37.719)))*43758.5453,1.0)
  if rank<.62:medium.append_array(PackedInt32Array(groups[hinge]));mid_groups+=1
  if rank<.32:low.append_array(PackedInt32Array(groups[hinge]));low_groups+=1
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a,[],{.36:medium,1.1:low})
 return {'mesh':mesh,'original_triangles':ids.size()/3,'added_triangles':added,'full_triangles':a[Mesh.ARRAY_INDEX].size()/3,'lod_triangles':[medium.size()/3,low.size()/3],'leaf_groups':groups.size(),'retained_groups':[mid_groups,low_groups]}

static func make_multimesh(mesh:Mesh,records:Array,bounds:AABB=AABB())->MultiMesh:
 var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.use_custom_data=true;mm.mesh=mesh;mm.instance_count=records.size()
 var measured=AABB()
 for i in records.size():
  var entry=records[i];mm.set_instance_transform(i,entry.transform);mm.set_instance_color(i,entry.color);mm.set_instance_custom_data(i,entry.custom)
  var box=entry.transform*mesh.get_aabb();measured=box if i==0 else measured.merge(box)
 mm.custom_aabb=bounds if bounds.has_volume() else measured.grow(.15)
 return mm

func add_batch(label:String,mesh:Mesh,records:Array,material:ShaderMaterial,shadows:bool,accent:bool=false):
 if records.is_empty():return
 var batch=MultiMeshInstance3D.new();batch.name=label;batch.multimesh=make_multimesh(mesh,records);batch.material_override=material
 batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 batch.set_meta('source_records',records);batch.set_meta('accent',accent)
 var scale=0.0
 for entry in records:scale+=entry.transform.basis.y.length()
 batch.set_meta('source_scale',scale/records.size());add_child(batch);batches.append(batch)

func prepare(backdrop:Node3D)->Dictionary:
 var selected_count=0;var outside_count=0;var added_triangles=0;var source_reports={};var mesh_cache={}
 var journal=backdrop.get_meta('approved_forest_journal',[])
 for kind in 2:
  var owner=backdrop.get_node_or_null('DistantTree'+str(kind)) as MultiMeshInstance3D
  if owner==null:return {'ok':false,'reason':'Expected original exterior tree batch missing'}
  var old=owner.multimesh
  if not old.use_colors or not old.use_custom_data or old.visible_instance_count not in [-1,old.instance_count]:return {'ok':false,'reason':'Unexpected original tree instance channels or visibility'}
  var expected=[]
  for entry in journal:
   if entry.source=='border_tree_'+('a' if kind==0 else 'b') and Lake.lake_distance(Vector2(entry.root.x,entry.root.z))>=1.0:expected.append(entry.transform)
  if expected.size()!=old.instance_count:return {'ok':false,'reason':'Original lake-filtered tree count differs from authority'}
  var inside=[];var outside=[]
  for i in old.instance_count:
   var transform=old.get_instance_transform(i)
   if not transform.is_equal_approx(expected[i]):return {'ok':false,'reason':'Native tree transform differs from lake-filtered authority'}
   var entry={'transform':transform,'color':old.get_instance_color(i),'custom':old.get_instance_custom_data(i)}
   var strength=weight(transform.origin)
   if strength>.0001:
    var custom:Color=entry.custom;custom.g=1.0 if i%4==1 else 0.0;custom.b=half_storage(strength);entry.custom=custom;inside.append(entry)
   else:outside.append(entry)
   original_records.append({'owner':owner.name,'transform':transform,'color':old.get_instance_color(i),'custom':old.get_instance_custom_data(i),'selected':strength>.0001})
  var report=leafy_mesh(old.mesh);mesh_cache[kind]=report.mesh;source_reports[str(kind)]=report.duplicate();source_reports[str(kind)].erase('mesh')
  var material=owner.material_override.duplicate() as ShaderMaterial;material.shader=LEAF_SHADER
  add_batch('NorthOriginal'+str(kind),report.mesh,inside,material,owner.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
  replacements.append({'owner':owner,'original_bounds':owner.get_aabb(),'original_lod':owner.lod_bias,'original_material':owner.material_override,'original_shadow':owner.cast_shadow,'multimesh':make_multimesh(old.mesh,outside,owner.get_aabb()),'transforms':outside.map(func(entry):return entry.transform)})
  selected_count+=inside.size();outside_count+=outside.size();added_triangles+=inside.size()*report.added_triangles
 var grounder=North.new();grounder._index_ground(backdrop)
 var rng=RandomNumberGenerator.new();rng.seed=2026110433
 var accents=[[],[]];var accent_meshes=[];var accent_reports=[]
 for file in ['border_shrub_a','border_shrub_b']:
  var report=leafy_mesh(Wind._mesh(file));accent_meshes.append(report.mesh);accent_reports.append(report)
 for attempt in 400:
  if accent_records.size()>=14:break
  var angle=rng.randf_range(deg_to_rad(-37.0),deg_to_rad(37.0));var radius=rng.randf_range(82.0,105.0)
  var p=Vector2(sin(angle),-cos(angle))*radius;var kind=accent_records.size()%2;var mesh:Mesh=accent_meshes[kind]
  var height=rng.randf_range(2.3,3.8);var scale=height/mesh.get_aabb().size.y
  var footprint=0.0
  for vertex in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:footprint=maxf(footprint,Vector2(vertex.x,vertex.z).length()*scale)
  footprint+=.15
  if not grounder.clear_position(p,footprint):continue
  var clear=true
  for existing in accent_records:
   if p.distance_to(Vector2(existing.transform.origin.x,existing.transform.origin.z))<footprint+existing.footprint+1.2:clear=false;break
  if not clear:continue
  var y=grounder.ground_height(p)
  if not is_finite(y):continue
  var transform=Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*scale),Vector3(p.x,y-mesh.get_aabb().position.y*scale-.025,p.y))
  var record={'transform':transform,'color':Color.WHITE,'custom':Color(half_storage(Wind._phase(transform.origin)),2.0 if accent_records.size()%3 else 3.0,1.0,1.0),'footprint':footprint}
  accents[kind].append(record);accent_records.append(record);added_triangles+=accent_reports[kind].full_triangles
 grounder.free()
 var material=ShaderMaterial.new();material.shader=LEAF_SHADER
 for kind in 2:add_batch('FloweringUnderstory'+str(kind),accent_meshes[kind],accents[kind],material,false,true)
 audit={'ok':accent_records.size()==14,'scope':'Marked north/fishing trees only','original_trees_retained':selected_count+outside_count,'refined_original_trees':selected_count,'untouched_outside_trees':outside_count,'new_flowering_accents':accent_records.size(),'added_full_detail_triangle_bound':added_triangles,'added_batches':batches.size(),'original_source_meshes_unchanged':true,'source_reports':source_reports,'new_colliders':0,'new_lights':0,'new_shadow_caster_instances':0,'new_texture_files':0,'runtime_process_callbacks':0,'fps_measured':false}
 return audit
