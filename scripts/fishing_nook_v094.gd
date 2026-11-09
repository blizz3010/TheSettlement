extends RefCounted
# FI01–FI03. Terrain/water and casting are authoritative; this is surface dressing.
const Terrain=preload('res://scripts/settlement_terrain.gd')
const Stream=preload('res://scripts/settlement_stream.gd')
const Home=preload('res://scripts/home_finish_v094.gd')
const Visual=preload('res://scripts/fishing_finish_helpers_v094.gd')
const CAST=Rect2(Vector2(13.95,-45.749),Vector2(2.1,5.1))
const CLEAR_CENTER=Vector2(17.00153,-38.79084)
const CLEAR_RADII=Vector2(1.45,1.25)
static func support(x:float,z:float)->float:return Terrain.pre_park_mesh_height(Vector2(x,z))
static func clear_bounds(box:AABB)->bool:return not Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).intersects(CAST.grow(.08),true)
static func patch(root:Node3D,label:String,rect:Rect2,nook:bool)->int:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var count=0
 var step=.20
 for ix in ceili(rect.size.x/step):
  for iz in ceili(rect.size.y/step):
   var p=rect.position+Vector2(ix*step,iz*step)
   var points=[p,p+Vector2(step,0),p+Vector2(0,step),p+Vector2(step,step)]
   for ids in [[0,1,2],[1,3,2]]:
    var vertices=[];var weights=[];var valid=true
    for id in ids:
     var q:Vector2=points[id];var h=support(q.x,q.y);var weight=0.0
     if nook:
      var d=((q-CLEAR_CENTER)/CLEAR_RADII).length()
      if d>1.0:valid=false;break
      weight=1.0-smoothstep(.68,1.0,d)
     else:
      var depth=h-Terrain.stream_water_y(q.x)
      if depth<.018 or depth>.46 or q.y<Terrain.stream_z(q.x):valid=false;break
      weight=(1.0-smoothstep(.16,.46,depth))*.76
     if CAST.grow(.08).has_point(q):valid=false;break
     vertices.append(Vector3(q.x,h+.007,q.y));weights.append(weight)
    if not valid:continue
    var normal=(vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).normalized()
    for i in 3:st.set_normal(normal);st.set_color(Color(1,1,1,weights[i]));st.add_vertex(vertices[i])
    count+=1
 if count==0:return 0
 var n=MeshInstance3D.new();n.name=label;n.mesh=st.commit();n.material_override=Home.finish_material(Color(.22,.182,.125) if nook else Color(.18,.165,.125),2);n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(n)
 return count
static func apply(world:Node3D,visual:Node3D,feet:Vector3,tree:Vector3,toward:Vector3,right:Vector3)->Dictionary:
 assert(not visual.has_node('FishingNookFinishV094'))
 var root=Node3D.new();root.name='FishingNookFinishV094';visual.add_child(root)
 # Reuse all three original rods, reels, handles and tackle trays without relocation.
 var rack=Node3D.new();rack.name='ExistingRodSupport';root.add_child(rack)
 var timber=Home.finish_material(Color(.30,.215,.13));var metal=Visual.material(Color(.26,.285,.24))
 var center=Vector3(tree.x,feet.y,tree.z)+toward*.47
 for side in [-1,1]:
  var foot=center+right*side*.40
  Visual.segment(rack,'Rack leg',foot,foot+Vector3.UP*.93,.026,Color(.29,.21,.13))
 Visual.segment(rack,'Support cross rail',center-right*.44+Vector3.UP*.78,center+right*.44+Vector3.UP*.78,.034,Color(.29,.21,.13))
 # V96-03: physical board faces the southern customer arrival; no billboard.
 var sign=Node3D.new();sign.name='PhysicalFishingSign';root.add_child(sign)
 sign.position=center+Vector3.UP*1.07+toward*.06
 sign.basis=Basis.IDENTITY
 Home.box(sign,'Timber sign board',Vector3.ZERO,Vector3(.82,.35,.045),timber)
 for x in [-.34,.34]:Home.box(sign,'Board mount',Vector3(x,-.19,-.018),Vector3(.03,.13,.035),metal)
 var letters=MeshInstance3D.new();letters.name='Mounted service lettering'
 var text=TextMesh.new();text.font=preload('res://assets/fonts/DejaVuSerif.ttf');text.text='FISHING\nSUPPLIES';text.font_size=44;text.pixel_size=.0028;text.depth=.003
 letters.mesh=text;letters.material_override=Visual.material(Color(.73,.65,.44));letters.position=Vector3(0,0,.025);sign.add_child(letters)
 # One hooded rack-side practical. Downward cone cannot wash the far bank.
 var lamp_at=center+right*.48+Vector3(0,2.08,.90)
 Visual.segment(root,'Practical bracket',center+right*.40+Vector3.UP*.90,lamp_at,.022,Color(.26,.285,.24))
 Home.box(root,'Practical hood',lamp_at+Vector3.UP*.035,Vector3(.26,.08,.22),metal)
 Home.box(root,'Practical back shield',lamp_at+Vector3(0,-.065,-.095),Vector3(.26,.15,.03),metal)
 var lamp=SpotLight3D.new();lamp.name='Fishing rack warm practical';root.add_child(lamp)
 lamp.position=lamp_at
 lamp.look_at(feet+Vector3(0,.55,.50),Vector3.UP)
 lamp.light_color=Color(1.0,.79,.54);lamp.light_energy=1.15
 lamp.spot_range=3.6;lamp.spot_angle=52.0;lamp.spot_attenuation=1.4
 lamp.shadow_enabled=false;lamp.light_specular=.15
 var nook_triangles=patch(root,'Worn work clearing',Rect2(CLEAR_CENTER-CLEAR_RADII,CLEAR_RADII*2),true)
 var bank_triangles=patch(root,'Reachable damp bank',Rect2(3.0,-46,20.0,5.8),false)
 # Low pebbles and three-stem reed clusters occupy only the two flanking bank sections.
 var pebble_mesh=SphereMesh.new();pebble_mesh.radius=1;pebble_mesh.height=2;pebble_mesh.radial_segments=8;pebble_mesh.rings=4
 var pebbles=0;var reeds=0
 for i in 36:
  var x=3.4+i*.54
  var z=Terrain.stream_z(x)+Stream.bank_offset(x,1)+.24+.11*sin(i*2.13)
  var p=Vector3(x,support(x,z),z)
  var size=Vector3(.08+.04*(i%3),.035+.012*(i%2),.065+.025*(i%4))
  if not clear_bounds(AABB(p-size,size*2)):continue
  var n=MeshInstance3D.new();n.name='Grounded shore pebble';n.mesh=pebble_mesh;n.material_override=Visual.material(Color(.28,.285,.24).darkened(.04*(i%3)));n.position=p+Vector3(0,size.y*.38,0);n.scale=size;n.rotation.y=i*2.4;root.add_child(n);pebbles+=1
 for x in [3.8,5.5,7.3,9.4,11.4,12.6,17.4,19.1,21.2,22.3]:
  var z=Terrain.stream_z(x)+Stream.bank_offset(x,1)+.52
  var y=support(x,z)
  var bounds=AABB(Vector3(x-.18,y,z-.18),Vector3(.36,.48,.36))
  if not clear_bounds(bounds):continue
  for j in 3:
   var base=Vector3(x+(j-1)*.06,y-.025,z+.035*j)
   var tip=base+Vector3((j-1)*.045,.28+.075*j,.055)
   Visual.segment(root,'Short bank reed',base,tip,.011,Color(.29,.34,.14))
  reeds+=1
 for n in root.find_children('*','MeshInstance3D',true,false):
  # Surface patch AABBs span the open casting gap, so inspect triangle vertices instead.
  if n.name in ['Reachable damp bank','Worn work clearing']:
   for p in n.mesh.get_faces():assert(not CAST.grow(.075).has_point(Vector2(p.x,p.z)))
  else:assert(clear_bounds(n.global_transform*n.mesh.get_aabb()),'Fishing finish crossed cast clearance')
 var grass=apply_grass_clearance(world)
 var result={'ok':true,'nook_triangles':nook_triangles,'bank_triangles':bank_triangles,'pebbles':pebbles,'reed_clusters':reeds,'new_rods':0,'new_tackle_cases':0,'floating_labels':0,'new_colliders':0,'new_lights':1,'grass':grass,'terrain_changed':false,'water_changed':false}
 result.visual_batches=Home.batch_visuals(root)
 root.set_meta('fishing_nook_v094',result)
 return result
static func apply_grass_clearance(world:Node3D)->Dictionary:
 # Local duplicated materials preserve every source buffer and all LOD/quality controls.
 # Only coverage batches touching this nook or reachable south-bank band use the masked shader.
 var rows=[]
 for n in world.find_children('*','MultiMeshInstance3D',true,false):
  var m=n.material_override as ShaderMaterial
  if m==null or m.shader==null or m.shader.resource_path not in ['res://assets/settlement_grass_v086/grass_lod.gdshader','res://shaders/fishing_grass_v094.gdshader']:continue
  var a=n.global_transform*n.get_aabb()
  if not Rect2(Vector2(a.position.x,a.position.z),Vector2(a.size.x,a.size.z)).intersects(Rect2(3,-46,20,8.5)):continue
  var hash_before=hash(n.multimesh.buffer);var total=n.multimesh.instance_count
  var changed=0
  for i in total:
   var p=(n.global_transform*n.multimesh.get_instance_transform(i)).origin
   var in_nook=((Vector2(p.x,p.z)-CLEAR_CENTER)/CLEAR_RADII).length()<1.0
   var course=Terrain.stream_z(p.x)
   var in_bank=p.x>3 and p.x<23 and p.z>course and p.z<course+4 and p.y-Terrain.stream_water_y(p.x)<.46 and not CAST.grow(.08).has_point(Vector2(p.x,p.z))
   if in_nook or in_bank:changed+=1
  if changed==0:continue
  var local=m.duplicate() as ShaderMaterial
  local.shader=preload('res://shaders/fishing_grass_v094.gdshader')
  for parameter in ['color','color2','noise','noiseScale','near_mode','near_start','near_end','far_end']:local.set_shader_parameter(parameter,m.get_shader_parameter(parameter))
  n.material_override=local
  assert(hash(n.multimesh.buffer)==hash_before and n.multimesh.instance_count==total)
  rows.append({'path':str(world.get_path_to(n)),'total_retained':total,'locally_shortened':changed,'buffer_unchanged':true})
 return {'batches':rows,'removed_instances':0,'authority_polygons_changed':false,'nook_bounds':Rect2(CLEAR_CENTER-CLEAR_RADII,CLEAR_RADII*2),'bank_bounds':Rect2(3,-46,20,8.5),'casting_mask_untouched':true}

static func finalize_grass(world:Node3D)->Dictionary:
 var nook=world.get_node_or_null('FishingTraderVisualController/FishingTraderVisuals/FishingNookFinishV094')
 if nook==null:return {'ok':false,'reason':'Final fishing nook missing'}
 var result=nook.get_meta('fishing_nook_v094',{})
 if result.get('grass_finalized',false):return {'ok':true,'grass':result.grass,'idempotent':true}
 var grass=apply_grass_clearance(world)
 if grass.batches.is_empty():return {'ok':false,'reason':'Final fishing clearing coverage missing'}
 result.grass=grass;result.grass_finalized=true;nook.set_meta('fishing_nook_v094',result)
 print('FISHING_NOOK_FINAL_GRASS_READY ',JSON.stringify(grass))
 return {'ok':true,'grass':grass,'idempotent':false}
