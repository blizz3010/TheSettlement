extends RefCounted
# Late visual-only finish. Existing authority, route polygons, seats and collision
# are immutable. Selected grass cuts have independent masks and exact buffer proof.
const Terrain=preload('res://scripts/settlement_terrain.gd')
const Union=preload('res://scripts/route_union.gd')
const Grass=preload('res://scripts/continuous_grass.gd')
const ROOK=Rect2(28,27,4,3)
const BENCHES=['HallGardenBenchWest','HallGardenBenchEast','GardenBenchLeft','GardenBenchRight','AtlasRoadFacingBench']
static func circle(p:Vector2,r:float)->PackedVector2Array:
 var out=PackedVector2Array()
 for i in 32:out.append(p+Vector2(cos(i*TAU/32.0),sin(i*TAU/32.0))*r)
 return out
static func material(c:Color,rough:float=.94)->ShaderMaterial:
 var m=ShaderMaterial.new();m.shader=load('res://assets/materials/courtyard_surface.gdshader')
 m.set_shader_parameter('tint',c);m.set_shader_parameter('roughness',rough)
 m.set_shader_parameter('grain_scale',32.0);m.set_shader_parameter('variation',.15);m.set_shader_parameter('bump_strength',.018)
 return m
static func mesh_patch(parent:Node3D,label:String,poly:PackedVector2Array,mat:Material,level:float=NAN)->MeshInstance3D:
 var indices=Geometry2D.triangulate_polygon(poly);assert(not indices.is_empty())
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for k in range(0,indices.size(),3):
  for j in [0,1,2]:
   var q=poly[indices[k+j]];var y=Terrain.height_at(q.x,q.y)+.008 if is_nan(level) else level
   st.set_normal(Vector3.UP);st.set_uv(q);st.add_vertex(Vector3(q.x,y,q.y))
 st.set_material(mat);var n=MeshInstance3D.new();n.name=label;n.mesh=st.commit();n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(n);return n
static func bevel(parent:Node3D,label:String,outer:PackedVector2Array,inner:PackedVector2Array,level:float,mat:Material):
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in outer.size():
  var j=(i+1)%outer.size();var a=Vector3(outer[i].x,Terrain.height_at(outer[i].x,outer[i].y)+.008,outer[i].y);var b=Vector3(outer[j].x,Terrain.height_at(outer[j].x,outer[j].y)+.008,outer[j].y)
  var c=Vector3(inner[j].x,level,inner[j].y);var d=Vector3(inner[i].x,level,inner[i].y)
  for tri in [[a,b,c],[a,c,d]]:
   var normal=(tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
   for v in tri:st.set_normal(normal);st.set_uv(Vector2(v.x,v.z));st.add_vertex(v)
 st.set_material(mat);var n=MeshInstance3D.new();n.name=label;n.mesh=st.commit();n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(n)
static func root_pocket(parent:Node3D,p:Vector3,r:float,mat:Material,masks:Array,label:String):
 var poly=circle(Vector2(p.x,p.z),r);mesh_patch(parent,label,poly,mat)
 masks.append({'label':label,'polygon':poly,'bounds':Rect2(Vector2(p.x-r,p.z-r),Vector2.ONE*r*2)})
static func prepare_benches(world:Node3D,root:Node3D,masks:Array,soil:Material,stone:Material)->Array:
 var rows=[]
 for name in BENCHES:
  var bench=world.find_child(name,true,false)
  if not bench is Node3D:continue
  var poly=PackedVector2Array();var inner=PackedVector2Array()
  var reach=2.05 if name in ['GardenBenchLeft','GardenBenchRight'] else 1.65
  for v in [Vector2(-1.32,-reach),Vector2(1.32,-reach),Vector2(1.32,.53),Vector2(-1.32,.53)]:
   var p=bench.global_transform*Vector3(v.x,0,v.y);poly.append(Vector2(p.x,p.z))
  for v in [Vector2(-1.18,-1.27),Vector2(1.18,-1.27),Vector2(1.18,.40),Vector2(-1.18,.40)]:
   var p=bench.global_transform*Vector3(v.x,0,v.y);inner.append(Vector2(p.x,p.z))
  var base=Terrain.height_at(bench.global_position.x,bench.global_position.z)
  var height=maxf(base+.012,bench.global_position.y+.002)
  # Shallow bevel drops to terrain at the outside, with no invisible collision curb.
  bevel(root,name+'Approach',poly,inner,height,soil)
  mesh_patch(root,name+'FootPad',inner,stone,height)
  var bounds=Rect2(poly[0],Vector2.ZERO)
  for p in poly:bounds=bounds.expand(p)
  masks.append({'label':name+'Approach','polygon':poly,'bounds':bounds})
  rows.append({'bench':str(world.get_path_to(bench)),'height':height,'mask':poly,'seat_transform':bench.global_transform,'seat_origin':bench.get_meta('seat_local_origin'),'exits':bench.get_meta('seat_exit_local')})
 return rows
static func finish_fountain(world:Node3D)->int:
 var count=0
 for n in world.find_children('*','MeshInstance3D',true,false):
  if n.mesh==null:continue
  for s in n.mesh.get_surface_count():
   var original=n.mesh.surface_get_material(s)
   if original==null or not original.resource_name.begins_with('Limestone_Fountain_'):continue
   var old=n.get_active_material(s)
   if not old is ShaderMaterial:continue
   var m=old.duplicate() as ShaderMaterial;m.shader=load('res://shaders/fountain_contact_v094.gdshader')
   m.set_shader_parameter('contact_mode',2 if n.mesh.get_aabb().size.x>7.0 else 1)
   n.set_surface_override_material(s,m);count+=1
 return count
static func finish_palettes(world:Node3D)->Array:
 var garden=world.find_child('ApprovedGardensV086',true,false);var rows=[]
 if garden==null:return rows
 var specs={'PsyHillside':[Vector2(41.3,2.2),Color('ab9aa8')],'RookSide':[Vector2(39.5,29),Color('bca878')],'InnApproach':[Vector2(19.5,40.7),Color('a28bb6')],'HomeMarketBed':[Vector2(-9.3,22),Color('bcb69a')]}
 for region in garden.get_children():
  if not specs.has(str(region.name)):continue
  var spec=specs[str(region.name)]
  for n in region.find_children('Variation_*','MultiMeshInstance3D',true,false):
   var m=ShaderMaterial.new();m.shader=load('res://shaders/garden_palette_v094.gdshader')
   m.set_shader_parameter('accent',spec[1]);m.set_shader_parameter('cluster_center',spec[0]);m.set_shader_parameter('cluster_radius',2.2)
   m.set_shader_parameter('leaf_value',.91 if str(n.name).ends_with('cover') else 1.0)
   n.material_override=m
   rows.append({'batch':str(world.get_path_to(n)),'instances':n.multimesh.instance_count,'geometry_unchanged':true,'instance_buffer_unchanged':true})
  for n in region.find_children('*','MeshInstance3D',true,false):
   for s in n.mesh.get_surface_count():
    var old=n.get_active_material(s)
    if old is StandardMaterial3D and old.resource_name=='Leaves':
     var m=old.duplicate();m.albedo_color*=Color(.93,.95,.98,1);n.set_surface_override_material(s,m)
    elif old is StandardMaterial3D and old.resource_name=='SETTLEMENT_Foliage_Vertex':
     var m=old.duplicate();m.albedo_color*=Color(.94,.96,1.0,1);n.set_surface_override_material(s,m)
    elif old is ShaderMaterial and old.shader.resource_path=='res://shaders/approved_blossom_v086.gdshader':
     var m=ShaderMaterial.new();m.shader=load('res://shaders/garden_palette_v094.gdshader');m.set_shader_parameter('palette_mode',2);m.set_shader_parameter('vertex_mode',old.get_shader_parameter('vertex_mode'));m.set_shader_parameter('albedo_texture',old.get_shader_parameter('albedo_texture'));n.set_surface_override_material(s,m)
 return rows
static func finish_lamps(world:Node3D,root:Node3D,masks:Array,soil:Material,stone:Material)->Array:
 var result=[];var done={}
 for lamp in world.find_children('*','OmniLight3D',true,false):
  var fixture=lamp.get_parent()
  if not fixture is Node3D or fixture==world or done.has(fixture):continue
  var p=fixture.global_position
  # Ground lantern family only. Never wall brackets, ceiling lights or service signs.
  var path=str(world.get_path_to(fixture))
  if not ('PlazaIslandComposition' in path or 'ApprovedGardensV086' in path or 'AtlasStripV085' in path):continue
  if lamp.position.y<.35 or lamp.position.y>.85:continue
  if absf(p.y-Terrain.height_at(p.x,p.z))>.14:continue
  if Rect2(-9.3,-32.3,18.6,18.6).has_point(Vector2(p.x,p.z)):continue
  done[fixture]=true
  root_pocket(root,p,.40,soil,masks,'LampSoil%d'%result.size())
  var foot=Grass.rect_poly(Rect2(Vector2(p.x-.21,p.z-.21),Vector2(.42,.42)))
  var collar=Grass.rect_poly(Rect2(Vector2(p.x-.27,p.z-.27),Vector2(.54,.54)))
  var height=maxf(p.y+.003,Terrain.height_at(p.x,p.z)+.012)
  bevel(root,'LampFootingSlope%d'%result.size(),collar,foot,height,soil)
  mesh_patch(root,'LampFooting%d'%result.size(),foot,stone,height)
  result.append({'fixture':path,'position':p,'radius':.40,'light_unchanged':true})
 return result
static func finish_roots(world:Node3D,root:Node3D,masks:Array,soil:Material)->Array:
 var rows=[]
 for name in ['Tree_left','Tree_right']:
  var tree=world.find_child(name,true,false)
  if tree is Node3D:
   root_pocket(root,tree.global_position,.60,soil,masks,name+'RootPocket');rows.append({'source':str(world.get_path_to(tree)),'radius':.60})
 var garden=world.find_child('ApprovedGardensV086',true,false)
 if garden!=null:
  for region in garden.get_children():
   var evergreen=region.get_node_or_null('Variation_evergreen')
   if not evergreen is MultiMeshInstance3D:continue
   var selected=[]
   for i in evergreen.multimesh.instance_count:
    var p=(evergreen.global_transform*evergreen.multimesh.get_instance_transform(i)).origin
    # Two separate shrub groups per bed, not a blanket thinning pass.
    if p.length_squared()<1.0:continue
    var close=false
    for q in selected:
     if p.distance_to(q)<2.5:close=true
    if close:continue
    selected.append(p);root_pocket(root,p,.40,soil,masks,str(region.name)+'ShrubSoil%d'%selected.size())
    rows.append({'source':str(world.get_path_to(evergreen)),'instance':i,'radius':.40})
    if selected.size()==2:break
 return rows
static func finish_edges(world:Node3D,root:Node3D,stone:Material)->Dictionary:
 var surface=world.get_node_or_null('MarketExpansion/MarketRouteExactVisualUnion')
 if not surface is MeshInstance3D:return {'segments':0,'reason':'No market surface in fixture'}
 var polygons=surface.get_meta('polygons',[])
 if polygons.is_empty():polygons=world.get_node('MarketExpansion').get_meta('paving_polygons',[])
 polygons=Union.union_exact(polygons)
 if polygons.is_empty():return {'segments':0,'reason':'No closed route union'}
 # Read the exact visual mesh boundary, avoiding internal seams in source rectangles.
 var edges={}
 for s in surface.mesh.get_surface_count():
  var faces=surface.mesh.surface_get_arrays(s);var vs=faces[Mesh.ARRAY_VERTEX];var ix=faces[Mesh.ARRAY_INDEX]
  for k in range(0,ix.size() if ix!=null and ix.size()>0 else vs.size(),3):
   var tri=[]
   for j in 3:tri.append(vs[ix[k+j]] if ix!=null and ix.size()>0 else vs[k+j])
   if not (is_equal_approx(tri[0].y,.045) and is_equal_approx(tri[1].y,.045) and is_equal_approx(tri[2].y,.045)):continue
   for j in 3:
    var a=Vector2(tri[j].x,tri[j].z);var b=Vector2(tri[(j+1)%3].x,tri[(j+1)%3].z)
    var key=[var_to_str(a),var_to_str(b)];key.sort();var id='|'.join(key)
    if edges.has(id):edges[id].count+=1
    else:edges[id]={'a':a,'b':b,'count':1}
 var count=0;var area=0.0
 for edge in edges.values():
  if edge.count!=1 or edge.a.distance_to(edge.b)<.35:continue
  var a=edge.a;var b=edge.b;var dir=(b-a).normalized();var inward=Vector2(-dir.y,dir.x)
  var mid=(a+b)*.5
  if not Union.inside_any(mid+inward*.06,polygons):inward=-inward
  if not Union.inside_any(mid+inward*.06,polygons):continue
  # Keep the accepted Rook approach byte-for-byte and visually unlayered.
  if ROOK.grow(.15).has_point(mid):continue
  var parts=maxi(1,int(a.distance_to(b)/.9))
  for i in parts:
   var start=a.lerp(b,float(i)/parts)+dir*.012;var end=a.lerp(b,float(i+1)/parts)-dir*.012
   var p=PackedVector2Array([start+inward*.018,end+inward*.018,end+inward*.14,start+inward*.14]);p=Union.normalized(p)
   for poly in polygons:
    for piece in Geometry2D.intersect_polygons(p,poly):
     if Geometry2D.is_polygon_clockwise(piece) or Union.area([piece])<.001:continue
     if not Geometry2D.intersect_polygons(piece,Grass.rect_poly(ROOK)).is_empty():continue
     mesh_patch(root,'FlushMarketCourse%d'%count,piece,stone,.047);count+=1;area+=Union.area([piece])
 return {'segments':count,'area':area,'inside_existing_routes':true,'collision_changes':0}
static func trim_grass(world:Node3D,masks:Array)->Dictionary:
 var prepared=[];var journal=[];var before_counts={'all':0,'near':0,'far':0};var removed_counts={'all':0,'near':0,'far':0}
 var categories_before={'near':0,'far':0,'Home':0,'Atlas':0,'supplemental':0};var categories_removed=categories_before.duplicate()
 for mask in masks:
  if mask.bounds.intersects(ROOK):return {'ok':false,'reason':'Contact mask overlaps preserved Rook apron'}
 for batch in world.find_children('*','MultiMeshInstance3D',true,false):
  var label=str(batch.name).to_lower()
  if not ('grass' in label or label.begins_with('lawnchunk_') or label.begins_with('groundnear_') or label.begins_with('groundfar_')):continue
  if batch.multimesh==null or batch.multimesh.mesh==null:continue
  var old=batch.multimesh;var kind='near' if label.begins_with('groundnear_') else ('far' if label.begins_with('groundfar_') else 'other')
  var path=str(world.get_path_to(batch));var category=kind if kind!='other' else ('Home' if 'home' in path.to_lower() else ('Atlas' if 'AtlasStripV085' in path else 'supplemental'))
  categories_before[category]+=old.instance_count
  before_counts.all+=old.instance_count
  if kind!='other':before_counts[kind]+=old.instance_count
  var local_bounds=old.custom_aabb if old.custom_aabb.size.length_squared()>0.0 else batch.get_aabb()
  var whole=batch.global_transform*local_bounds;var bounds=Rect2(Vector2(whole.position.x,whole.position.z),Vector2(whole.size.x,whole.size.z));var local_masks=[]
  for mask in masks:
   if bounds.intersects(mask.bounds.grow(.08)):local_masks.append(mask)
  if local_masks.is_empty():continue
  var keep=[];var rejected=[];var shown=0
  for i in old.instance_count:
   var ab=batch.global_transform*old.get_instance_transform(i)*old.mesh.get_aabb()
   var r=Rect2(Vector2(ab.position.x,ab.position.z),Vector2(ab.size.x,ab.size.z)).grow(.08)
   var hit=false
   for mask in local_masks:
    if r.intersects(mask.bounds) and not Geometry2D.intersect_polygons(Grass.rect_poly(r),mask.polygon).is_empty():hit=true;break
   if hit:rejected.append(i)
   else:
    keep.append(i)
    if old.visible_instance_count<0 or i<old.visible_instance_count:shown+=1
  if rejected.is_empty():continue
  var next=MultiMesh.new();next.transform_format=old.transform_format;next.use_colors=old.use_colors;next.use_custom_data=old.use_custom_data;next.mesh=old.mesh;next.custom_aabb=old.custom_aabb;next.instance_count=keep.size()
  for j in keep.size():
   var i=keep[j];next.set_instance_transform(j,old.get_instance_transform(i))
   if old.use_colors:next.set_instance_color(j,old.get_instance_color(i))
   if old.use_custom_data:next.set_instance_custom_data(j,old.get_instance_custom_data(i))
  next.visible_instance_count=-1 if old.visible_instance_count<0 else shown
  var source=old.buffer.to_byte_array();var target=next.buffer.to_byte_array();var stride=int(source.size()/old.instance_count)
  if target.size()!=keep.size()*stride:return {'ok':false,'reason':'Grass buffer length changed'}
  for j in keep.size():
   if target.slice(j*stride,(j+1)*stride)!=source.slice(keep[j]*stride,(keep[j]+1)*stride):return {'ok':false,'reason':'Retained grass changed'}
  for i in rejected:
   var ab=batch.global_transform*old.get_instance_transform(i)*old.mesh.get_aabb()
   var r=Rect2(Vector2(ab.position.x,ab.position.z),Vector2(ab.size.x,ab.size.z)).grow(.08)
   var verified=false
   for mask in masks:
    if r.intersects(mask.bounds) and not Geometry2D.intersect_polygons(Grass.rect_poly(r),mask.polygon).is_empty():verified=true;break
   if not verified:return {'ok':false,'reason':'Rejected grass outside contact masks'}
  var metadata=null
  if batch.has_meta('source_transforms'):
   var transforms=batch.get_meta('source_transforms')
   if transforms is Array and transforms.size()==old.instance_count:
    metadata=[]
    for i in keep:metadata.append(transforms[i])
  prepared.append({'batch':batch,'old':old,'next':next,'metadata':metadata})
  categories_removed[category]+=rejected.size()
  removed_counts.all+=rejected.size()
  if kind!='other':removed_counts[kind]+=rejected.size()
  journal.append({'batch':str(world.get_path_to(batch)),'before':old.instance_count,'after':next.instance_count,'removed':rejected.size(),'kind':kind,'category':category,'retained_buffer_exact':true,'removed_bounds_verified':true,'wind_buffer':.08,'removed_indices':rejected})
 if 'startup_cancel_requested' in world and world.startup_cancel_requested:return {'ok':false,'reason':'Loading cancelled before contact-grass commit'}
 for entry in prepared:
  if entry.batch.multimesh!=entry.old:return {'ok':false,'reason':'Grass changed before commit'}
 for entry in prepared:
  entry.batch.multimesh=entry.next
  if entry.metadata!=null:entry.batch.set_meta('source_transforms',entry.metadata)
 for mask in masks:
  var coordinates=[]
  for p in mask.polygon:coordinates.append([p.x,p.y])
  mask['coordinates']=coordinates
 var after_counts={};var categories_after={}
 for key in before_counts:after_counts[key]=before_counts[key]-removed_counts[key]
 for key in categories_before:categories_after[key]=categories_before[key]-categories_removed[key]
 return {'ok':true,'categories_before':categories_before,'categories_after':categories_after,'categories_removed':categories_removed,'before_counts':before_counts,'after_counts':after_counts,'removed_counts':removed_counts,'journal':journal,'new_masks':masks}
static func batch_contacts(root:Node3D)->Dictionary:
 var groups={};var meshes=0;var vertices=0
 for node in root.get_children():
  if not node is MeshInstance3D:continue
  assert(node.transform==Transform3D.IDENTITY)
  for surface in node.mesh.get_surface_count():
   var mat=node.mesh.surface_get_material(surface);var key=mat.get_instance_id()
   if not groups.has(key):
    var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_material(mat);groups[key]=st
   groups[key].append_from(node.mesh,surface,node.transform)
   vertices+=node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].size()
  meshes+=1;node.free()
 for key in groups:
  var n=MeshInstance3D.new();n.name='BatchedContactSurface';n.mesh=groups[key].commit();n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(n)
 return {'source_meshes':meshes,'draw_meshes':groups.size(),'vertices':vertices,'triangles':vertices/3,'shadow_casters':0}
static func apply(world:Node3D)->Dictionary:
 if world.has_meta('paths_gardens_v094'):return world.get_meta('paths_gardens_v094')
 if 'startup_cancel_requested' in world and world.startup_cancel_requested:return {'ok':false,'reason':'Loading cancelled before contact finish'}
 for name in BENCHES:
  if not world.find_child(name,true,false) is Node3D:return {'ok':false,'reason':'Missing contact bench: '+name}
 var approved=world.find_child('ApprovedGardensV086',true,false)
 if approved==null or world.get_node_or_null('MarketExpansion/MarketRouteExactVisualUnion')==null:return {'ok':false,'reason':'Contact finish requires completed landscape and exact market surface'}
 var plants=0;var batches=approved.find_children('Variation_*','MultiMeshInstance3D',true,false)
 for b in batches:plants+=b.multimesh.instance_count
 if batches.size()!=20 or plants!=230:return {'ok':false,'reason':'Approved garden instance contract changed'}
 if not world.get_meta('rook_centered_approach',{}).get('ok',false):return {'ok':false,'reason':'Rook trim must finish before contact masks'}
 var began=Time.get_ticks_usec()
 var root=Node3D.new();root.name='PathsGardensFinishV094';world.add_child(root)
 var soil=material(Color('625a46'));var stone=material(Color(.43,.42,.37));var masks=[]
 var benches=prepare_benches(world,root,masks,soil,stone)
 var lamps=finish_lamps(world,root,masks,soil,stone)
 var roots=finish_roots(world,root,masks,soil)
 var prepared_at=Time.get_ticks_usec()
 var grass=trim_grass(world,masks)
 var trimmed_at=Time.get_ticks_usec()
 if not grass.ok:root.free();return grass
 var palettes=finish_palettes(world);var fountain=finish_fountain(world);var edges=finish_edges(world,root,stone)
 var geometry=batch_contacts(root)
 var finished_at=Time.get_ticks_usec()
 var result={'timings_msec':{'prepare':(prepared_at-began)/1000.0,'trim':(trimmed_at-prepared_at)/1000.0,'finish':(finished_at-trimmed_at)/1000.0,'total':(finished_at-began)/1000.0},'geometry':geometry,'ok':true,'benches':benches,'lamps':lamps,'roots':roots,'grass':grass,'palette_batches':palettes,'fountain_surfaces':fountain,'edges':edges,'collision_changes':0,'route_authority_changes':0,'save_changes':0}
 root.set_meta('contact_masks',masks);world.set_meta('paths_gardens_v094',result)
 print('PATHS_GARDENS_V094_READY benches=',benches.size(),' lamps=',lamps.size(),' roots=',roots.size(),' grass_removed=',grass.removed_counts.all,' edge_segments=',edges.segments)
 return result
