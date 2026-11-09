extends RefCounted
# Isolated physical blockout. New service fronts are art only; no service/state binding.
const SPECS=[{'id':'Psy','at':Vector3(31,0,2),'yaw':0.0,'width':8.0,'depth':7.0,'title':'PSY · GEAR & ARMOR','color':Color('#526f72')},{'id':'Atlas','at':Vector3(25,0,18),'yaw':-PI/2,'width':7.0,'depth':8.0,'title':'ATLAS · RECOVERY','color':Color('#637465')},{'id':'Dan','at':Vector3(6,0,24),'yaw':PI,'width':10.0,'depth':7.0,'title':'DAN · PLAYER MARKETPLACE','color':Color('#aa7647')}]
static func mat(c:Color,metal=0.0)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=c;m.roughness=.8;m.metallic=metal;return m
static func box(root:Node3D,n:String,p:Vector3,size:Vector3,m:Material,solid=false):
 var part=Node3D.new();part.name=n;part.position=p;root.add_child(part)
 var mesh=MeshInstance3D.new();var shape=BoxMesh.new();shape.size=size;mesh.mesh=shape;mesh.material_override=m;part.add_child(mesh)
 if solid:
  var body=StaticBody3D.new();body.set_meta('audio_surface','stone' if ('Limestone' in n or 'cream' in n) else ('metal' if 'Bronze' in n else 'wood'));part.add_child(body)
  var col=CollisionShape3D.new();var b=BoxShape3D.new();b.size=size;col.shape=b;body.add_child(col)
 return part
static func label(root:Node3D,text:String,p:Vector3,size=30):
 var l=Label3D.new();l.text=text;l.position=p;l.font_size=size;l.pixel_size=.006;l.modulate=Color('#f5e8c9');l.outline_size=4;l.no_depth_test=false;root.add_child(l);return l
static func sphere(root:Node3D,p:Vector3,scale:Vector3,m:Material):
 var node=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=.5;mesh.height=1;mesh.radial_segments=16;mesh.rings=8;node.mesh=mesh;node.position=p;node.scale=scale;node.material_override=m;root.add_child(node)
static func paving_footprint(mesh:Mesh,t:Transform3D)->PackedVector2Array:
 var points=PackedVector2Array()
 for vertex in mesh.get_faces():
  var p=t*vertex;points.append(Vector2(p.x,p.z))
 return Geometry2D.convex_hull(points)
static func _cancelled(scene:Node3D)->bool:
 return not is_instance_valid(scene) or scene.is_queued_for_deletion() or ("startup_cancel_requested" in scene and scene.startup_cancel_requested)
static func _abort_owned(scene:Node3D,root:Node3D,reason:String):
 if is_instance_valid(scene):scene.set_meta('market_build_failure',reason)
 if is_instance_valid(root) and is_instance_valid(scene) and root.get_parent()==scene and root.get_meta('market_build_owner',0)==scene.get_instance_id():
  scene.remove_child(root);root.free()
 return null
static func _can_begin(scene:Node3D)->bool:
 if _cancelled(scene):return false
 if scene.has_node('MarketExpansion'):
  scene.set_meta('market_build_failure','Existing or foreign MarketExpansion; no mutation')
  return false
 return true
static func add_to(scene:Node3D):
 if not _can_begin(scene):return null
 if not _can_begin(scene):return null
 var root=Node3D.new();root.name='MarketExpansion';root.set_meta('market_build_owner',scene.get_instance_id());scene.add_child(root)
 var paving_polygons=[]
 var stone=scene.courtyard_material('market_stone',Color(.46,.44,.38,1));var timber_source=mat(Color('#967752'));timber_source.resource_name='Oiled_Timber_Market';var timber=preload('res://scripts/architecture_materials.gd').styled_material(timber_source);var bronze=scene.courtyard_material('market_bronze',Color('#9b7944'),'bronze');var cream=mat(Color('#c9bc98'));var dark=mat(Color('#293e3a'));var glow=mat(Color('#e9bb6c'));var pale=mat(Color('#ded1ad'))
 var paths=[ [Vector3(0,0,10),Vector3(0,0,15),Vector3(6,0,17),Vector3(17,0,12),Vector3(14,0,0),Vector3(11,0,-9)], [Vector3(17,0,12),Vector3(31,0,10),Vector3(31,0,7)], [Vector3(17,0,12),Vector3(18,0,19),Vector3(17,0,29),Vector3(9,0,30),Vector3(-6,0,30)], [Vector3(17,0,29),Vector3(27,0,26),Vector3(31,0,27)] ]
 for path in paths:
  for point in path:
   # Psy terminates in its rectangular apron; a disc here intruded into the plinth.
   if point.is_equal_approx(Vector3(31,0,7)):continue
   var join=MeshInstance3D.new();var disc=CylinderMesh.new();disc.top_radius=2;disc.bottom_radius=2;disc.height=.08;disc.radial_segments=24;join.mesh=disc;join.material_override=stone;join.position=point+Vector3(0,.008,0);root.add_child(join)
   paving_polygons.append(paving_footprint(join.mesh,join.global_transform))
  for i in range(path.size()-1):
   var a=path[i];var b=path[i+1];var p=(a+b)/2;p.y=.005
   var slab=box(root,'Market path',p,Vector3(4,.08,a.distance_to(b)+.2),stone,false);slab.look_at_from_position(p,b+Vector3(0,.005,0),Vector3.UP)
   paving_polygons.append(paving_footprint(slab.get_child(0).mesh,slab.get_child(0).global_transform))
 for spec in SPECS:
  var shop=Node3D.new();shop.name=spec.id+'Stand';root.add_child(shop);shop.position=spec.at;shop.rotation.y=spec.yaw;shop.set_meta('service_status','starter_clothing_only_marketplace_planned' if spec.id=='Dan' else 'visual_blockout_not_implemented')
  var w:float=spec.width;var d:float=spec.depth;var front=d/2-.7;var back=-d/2+.3
  var canvas=mat(spec.color)
  var apron=box(shop,'Customer stone apron',Vector3(0,.005,d/2+1.5),Vector3(w,.08,3.4),stone,false)
  paving_polygons.append(paving_footprint(apron.get_child(0).mesh,apron.get_child(0).global_transform))
  box(shop,'Limestone plinth',Vector3(0,.04,0),Vector3(w,.16,d),stone,true)
  box(shop,'Back cream wall',Vector3(0,1.8,back),Vector3(w-.4,3.4,.18),cream,true)
  for x in [-w/2+.25,w/2-.25]:
   box(shop,'Timber sidewall',Vector3(x,1.35,-.5),Vector3(.18,2.5,d-1.6),timber,true)
   for z in [back,front]:
    box(shop,'Bronze foot',Vector3(x,.28,z),Vector3(.36,.4,.36),bronze,true)
    box(shop,'Timber post',Vector3(x,2.0,z),Vector3(.2,3.5,.2),timber,true)
  box(shop,'Upper front beam',Vector3(0,3.7,front),Vector3(w,.24,.25),bronze,true)
  box(shop,'Roof',Vector3(0,4.05,-.5),Vector3(w,.20,d-1),timber,true)
  var canopy=box(shop,'Role canvas awning',Vector3(0,3.65,front-.5),Vector3(w-.2,.12,2.0),canvas);canopy.rotation.x=.1
  box(shop,'Sign backing',Vector3(0,3.1,front+.08),Vector3(w-.8,.62,.10),dark)
  label(shop,spec.title,Vector3(0,3.12,front+.145),30 if spec.id!='Dan' else 28)
  box(shop,'Counter case',Vector3(0,.6,front-.6),Vector3(w-1.2,1.1,.8),timber,true)
  box(shop,'Limestone counter',Vector3(0,1.17,front-.6),Vector3(w-1.05,.14,1.0),stone,true)
  label(shop,'STARTER CLOTHING · MARKETPLACE PLANNED' if spec.id=='Dan' else 'PLANNED SERVICE · NOT AVAILABLE',Vector3(0,.64,front-.175),19)
  for x in [-w/2+.7,w/2-.7]:
   preload('res://scripts/market_supported_practicals.gd').add_one(shop,spec,x,load('res://scripts/market_expansion.gd'),bronze,glow)
  # Wall examples communicate offering without introducing inventory or characters.
  if spec.id=='Psy':
   label(shop,'ARMOR     •     HELMETS     •     GEAR',Vector3(0,2.85,back+.15),20)
  elif spec.id=='Atlas':
   for x in [-2,-.65,.7,2.05]:
    box(shop,'Tagged return locker',Vector3(x,1.6,back+.45),Vector3(1.15,2.45,.65),canvas)
    box(shop,'Locker bronze frame',Vector3(x,1.6,back+.79),Vector3(1.04,2.31,.03),bronze)
    box(shop,'Locker face',Vector3(x,1.6,back+.82),Vector3(.95,2.22,.04),dark)
    box(shop,'Return tag',Vector3(x,2.13,back+.86),Vector3(.33,.18,.02),pale)
    box(shop,'Locker latch',Vector3(x+.3,1.55,back+.88),Vector3(.08,.24,.06),bronze)
   label(shop,'TAGGED RETURNS · COLLECTION',Vector3(0,2.97,back+.2),20)
  else:
   box(shop,'Listings board frame',Vector3(0,2.05,back+.25),Vector3(4.4,2.1,.15),bronze)
   box(shop,'Listings board',Vector3(0,2.05,back+.35),Vector3(4.15,1.85,.05),dark)
   for x in [-1.25,0,1.25]:
    for y in [1.65,2.35]:box(shop,'Empty listing card',Vector3(x,y,back+.39),Vector3(.85,.45,.025),pale)
   label(shop,'PLAYER LEVEL 20 · PLANNED',Vector3(0,3.12,back+.18),20)
   for x in [-3.4,3.4]:
    for y in [.7,1.4,2.1]:box(shop,'Consignment cubby',Vector3(x,y,back+.6),Vector3(1,.5,.75),timber)
   box(shop,'Exchange terminal base',Vector3(2.5,1.34,front-.65),Vector3(.6,.2,.5),bronze)
   var screen=box(shop,'Inactive exchange screen',Vector3(2.5,1.65,front-.8),Vector3(.72,.5,.08),dark);screen.rotation.x=-.15
 for spec in SPECS:
  preload('res://scripts/market_facades.gd').apply(root.get_node(spec.id+'Stand'),spec,load('res://scripts/market_expansion.gd'),{'wood':timber,'bronze':bronze,'stone':stone,'cream':cream,'dark':dark})
  preload('res://scripts/market_detail.gd').apply(root.get_node(spec.id+'Stand'),spec,load('res://scripts/market_expansion.gd'),{'wood':timber,'bronze':bronze,'stone':stone,'cream':cream,'dark':dark})
  preload('res://scripts/market_wall_finish.gd').apply(root.get_node(spec.id+'Stand'),spec,load('res://scripts/market_expansion.gd'),{'wood':timber,'bronze':bronze,'stone':stone,'cream':cream,'dark':dark})
  preload('res://scripts/trader_selective_finish.gd').apply(root.get_node(spec.id+'Stand'),spec,load('res://scripts/market_expansion.gd'),{'wood':timber,'bronze':bronze,'stone':stone,'cream':cream,'dark':dark})
  var envelope=preload('res://scripts/trader_side_envelope_finish.gd').apply(root.get_node(spec.id+'Stand'),spec,load('res://scripts/market_expansion.gd'),{'wood':timber,'bronze':bronze,'stone':stone,'cream':cream,'dark':dark})
  if not envelope.get('ok',false):return _abort_owned(scene,root,'Side envelope '+str(spec.id)+': '+str(envelope.get('reason','Unknown failure')))
 preload('res://scripts/market_surroundings.gd').apply(root,SPECS,load('res://scripts/market_expansion.gd'),{'wood':timber,'bronze':bronze,'stone':stone,'cream':cream,'dark':dark})
 preload('res://scripts/market_signage.gd').apply(root,SPECS,load('res://scripts/market_expansion.gd'),{'wood':timber,'bronze':bronze,'stone':stone,'cream':cream,'dark':dark})
 for spec in SPECS:
  preload('res://scripts/market_review_finish.gd').apply(root.get_node(spec.id+'Stand'),spec,load('res://scripts/rook_shop_art.gd'))
 for spec in SPECS:
  if spec.id in ['Psy','Atlas']:preload('res://scripts/shop_surround_detail.gd').apply(root.get_node(spec.id+'Stand'),spec)
 preload('res://scripts/dan_material_detail.gd').apply(root.get_node('DanStand'))
 preload('res://scripts/hideout_terrace.gd').batch_static_visuals(root)
 for child in root.get_children():
  if child is MultiMeshInstance3D:child.name='Market material batch'
 if _cancelled(scene):return _abort_owned(scene,root,'Startup cancelled before publication')
 # Extend ground-region audio with exact new visual paving, without extra floor collision.
 var aprons=[]
 for spec in SPECS:
  var shop=root.get_node(spec.id+'Stand');var center=shop.to_global(Vector3(0,0,spec.depth/2+1.5))
  var half=Vector2(1.7,spec.width/2) if absf(spec.yaw)>0.1 and absf(spec.yaw)<3.0 else Vector2(spec.width/2,1.7)
  aprons.append(Rect2(Vector2(center.x,center.z)-half,half*2))
 var audio_targets=[]
 for body in scene.find_children('*','StaticBody3D',true,false):
  if body.has_meta('audio_ground_regions'):audio_targets.append(body)
 root.set_meta('paving_polygons',paving_polygons)
 # External scene/audio metadata publication is deferred until final nonyielding commit.
 preload("res://scripts/visible_trader_study.gd").attach_to_market(root)
 if _cancelled(scene):return _abort_owned(scene,root,'Startup cancelled before return')
 for body in audio_targets:
  if not is_instance_valid(body) or not body.is_inside_tree():return _abort_owned(scene,root,'Audio target disappeared before publication')
 # No await/callback between final validation and all external metadata writes.
 for body in audio_targets:
  body.set_meta('market_paving_paths',paths);body.set_meta('market_paving_aprons',aprons);body.set_meta('market_paving_polygons',paving_polygons)
 scene.set_meta('market_expansion',{'new_visual_stands':3,'live_new_services':0,'progress_changes':false})
 return root

# Opt-in loading successor scheduling. Original synchronous APIs above remain unchanged.
static func add_to_staged(scene:Node3D):
 if not _can_begin(scene):return null
 var startup_owner:Node=scene
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("market operation 1"):return null
 if not _can_begin(scene):return null
 var root=Node3D.new();root.name='MarketExpansion';root.set_meta('market_build_owner',scene.get_instance_id());scene.add_child(root)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("market operation 2"):return _abort_owned(scene,root,'Startup cancelled')
 var paving_polygons=[]
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("market operation 3"):return _abort_owned(scene,root,'Startup cancelled')
 var stone=scene.courtyard_material('market_stone',Color(.46,.44,.38,1));var timber_source=mat(Color('#967752'));timber_source.resource_name='Oiled_Timber_Market';var timber=preload('res://scripts/architecture_materials.gd').styled_material(timber_source);var bronze=scene.courtyard_material('market_bronze',Color('#9b7944'),'bronze');var cream=mat(Color('#c9bc98'));var dark=mat(Color('#293e3a'));var glow=mat(Color('#e9bb6c'));var pale=mat(Color('#ded1ad'))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("market operation 4"):return _abort_owned(scene,root,'Startup cancelled')
 var paths=[ [Vector3(0,0,10),Vector3(0,0,15),Vector3(6,0,17),Vector3(17,0,12),Vector3(14,0,0),Vector3(11,0,-9)], [Vector3(17,0,12),Vector3(31,0,10),Vector3(31,0,7)], [Vector3(17,0,12),Vector3(18,0,19),Vector3(17,0,29),Vector3(9,0,30),Vector3(-6,0,30)], [Vector3(17,0,29),Vector3(27,0,26),Vector3(31,0,27)] ]
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("market operation 5"):return _abort_owned(scene,root,'Startup cancelled')
 for path in paths:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("market loop 6"):return _abort_owned(scene,root,'Startup cancelled')
  for point in path:
   if startup_owner != null:
    if await startup_owner._startup_checkpoint("market loop 7"):return _abort_owned(scene,root,'Startup cancelled')
   # Psy terminates in its rectangular apron; a disc here intruded into the plinth.
   if point.is_equal_approx(Vector3(31,0,7)):continue
   var join=MeshInstance3D.new();var disc=CylinderMesh.new();disc.top_radius=2;disc.bottom_radius=2;disc.height=.08;disc.radial_segments=24;join.mesh=disc;join.material_override=stone;join.position=point+Vector3(0,.008,0);root.add_child(join)
   paving_polygons.append(paving_footprint(join.mesh,join.global_transform))
  for i in range(path.size()-1):
   if startup_owner != null:
    if await startup_owner._startup_checkpoint("market loop 8"):return _abort_owned(scene,root,'Startup cancelled')
   var a=path[i];var b=path[i+1];var p=(a+b)/2;p.y=.005
   var slab=box(root,'Market path',p,Vector3(4,.08,a.distance_to(b)+.2),stone,false);slab.look_at_from_position(p,b+Vector3(0,.005,0),Vector3.UP)
   paving_polygons.append(paving_footprint(slab.get_child(0).mesh,slab.get_child(0).global_transform))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("market operation 9"):return _abort_owned(scene,root,'Startup cancelled')
 for spec in SPECS:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("market loop 10"):return _abort_owned(scene,root,'Startup cancelled')
  var shop=Node3D.new();shop.name=spec.id+'Stand';root.add_child(shop);shop.position=spec.at;shop.rotation.y=spec.yaw;shop.set_meta('service_status','starter_clothing_only_marketplace_planned' if spec.id=='Dan' else 'visual_blockout_not_implemented')
  var w:float=spec.width;var d:float=spec.depth;var front=d/2-.7;var back=-d/2+.3
  var canvas=mat(spec.color)
  var apron=box(shop,'Customer stone apron',Vector3(0,.005,d/2+1.5),Vector3(w,.08,3.4),stone,false)
  paving_polygons.append(paving_footprint(apron.get_child(0).mesh,apron.get_child(0).global_transform))
  box(shop,'Limestone plinth',Vector3(0,.04,0),Vector3(w,.16,d),stone,true)
  box(shop,'Back cream wall',Vector3(0,1.8,back),Vector3(w-.4,3.4,.18),cream,true)
  for x in [-w/2+.25,w/2-.25]:
   if startup_owner != null:
    if await startup_owner._startup_checkpoint("market loop 11"):return _abort_owned(scene,root,'Startup cancelled')
   box(shop,'Timber sidewall',Vector3(x,1.35,-.5),Vector3(.18,2.5,d-1.6),timber,true)
   for z in [back,front]:
    if startup_owner != null:
     if await startup_owner._startup_checkpoint("market loop 12"):return _abort_owned(scene,root,'Startup cancelled')
    box(shop,'Bronze foot',Vector3(x,.28,z),Vector3(.36,.4,.36),bronze,true)
    box(shop,'Timber post',Vector3(x,2.0,z),Vector3(.2,3.5,.2),timber,true)
  box(shop,'Upper front beam',Vector3(0,3.7,front),Vector3(w,.24,.25),bronze,true)
  box(shop,'Roof',Vector3(0,4.05,-.5),Vector3(w,.20,d-1),timber,true)
  var canopy=box(shop,'Role canvas awning',Vector3(0,3.65,front-.5),Vector3(w-.2,.12,2.0),canvas);canopy.rotation.x=.1
  box(shop,'Sign backing',Vector3(0,3.1,front+.08),Vector3(w-.8,.62,.10),dark)
  label(shop,spec.title,Vector3(0,3.12,front+.145),30 if spec.id!='Dan' else 28)
  box(shop,'Counter case',Vector3(0,.6,front-.6),Vector3(w-1.2,1.1,.8),timber,true)
  box(shop,'Limestone counter',Vector3(0,1.17,front-.6),Vector3(w-1.05,.14,1.0),stone,true)
  label(shop,'STARTER CLOTHING · MARKETPLACE PLANNED' if spec.id=='Dan' else 'PLANNED SERVICE · NOT AVAILABLE',Vector3(0,.64,front-.175),19)
  for x in [-w/2+.7,w/2-.7]:
   if startup_owner != null:
    if await startup_owner._startup_checkpoint("market loop 13"):return _abort_owned(scene,root,'Startup cancelled')
   preload('res://scripts/market_supported_practicals.gd').add_one(shop,spec,x,load('res://scripts/market_expansion.gd'),bronze,glow)
  # Wall examples communicate offering without introducing inventory or characters.
  if spec.id=='Psy':
   label(shop,'ARMOR     •     HELMETS     •     GEAR',Vector3(0,2.85,back+.15),20)
  elif spec.id=='Atlas':
   for x in [-2,-.65,.7,2.05]:
    if startup_owner != null:
     if await startup_owner._startup_checkpoint("market loop 14"):return _abort_owned(scene,root,'Startup cancelled')
    box(shop,'Tagged return locker',Vector3(x,1.6,back+.45),Vector3(1.15,2.45,.65),canvas)
    box(shop,'Locker bronze frame',Vector3(x,1.6,back+.79),Vector3(1.04,2.31,.03),bronze)
    box(shop,'Locker face',Vector3(x,1.6,back+.82),Vector3(.95,2.22,.04),dark)
    box(shop,'Return tag',Vector3(x,2.13,back+.86),Vector3(.33,.18,.02),pale)
    box(shop,'Locker latch',Vector3(x+.3,1.55,back+.88),Vector3(.08,.24,.06),bronze)
   label(shop,'TAGGED RETURNS · COLLECTION',Vector3(0,2.97,back+.2),20)
  else:
   box(shop,'Listings board frame',Vector3(0,2.05,back+.25),Vector3(4.4,2.1,.15),bronze)
   box(shop,'Listings board',Vector3(0,2.05,back+.35),Vector3(4.15,1.85,.05),dark)
   for x in [-1.25,0,1.25]:
    if startup_owner != null:
     if await startup_owner._startup_checkpoint("market loop 15"):return _abort_owned(scene,root,'Startup cancelled')
    for y in [1.65,2.35]:
     if startup_owner != null:
      if await startup_owner._startup_checkpoint("market loop 16"):return _abort_owned(scene,root,'Startup cancelled')
     box(shop,'Empty listing card',Vector3(x,y,back+.39),Vector3(.85,.45,.025),pale)
   label(shop,'PLAYER LEVEL 20 · PLANNED',Vector3(0,3.12,back+.18),20)
   for x in [-3.4,3.4]:
    if startup_owner != null:
     if await startup_owner._startup_checkpoint("market loop 17"):return _abort_owned(scene,root,'Startup cancelled')
    for y in [.7,1.4,2.1]:
     if startup_owner != null:
      if await startup_owner._startup_checkpoint("market loop 18"):return _abort_owned(scene,root,'Startup cancelled')
     box(shop,'Consignment cubby',Vector3(x,y,back+.6),Vector3(1,.5,.75),timber)
   box(shop,'Exchange terminal base',Vector3(2.5,1.34,front-.65),Vector3(.6,.2,.5),bronze)
   var screen=box(shop,'Inactive exchange screen',Vector3(2.5,1.65,front-.8),Vector3(.72,.5,.08),dark);screen.rotation.x=-.15
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("market operation 19"):return _abort_owned(scene,root,'Startup cancelled')
 for spec in SPECS:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("market loop 20"):return _abort_owned(scene,root,'Startup cancelled')
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("market helper market_facades"):return _abort_owned(scene,root,'Startup cancelled')
  preload('res://scripts/market_facades.gd').apply(root.get_node(spec.id+'Stand'),spec,load('res://scripts/market_expansion.gd'),{'wood':timber,'bronze':bronze,'stone':stone,'cream':cream,'dark':dark})
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("market helper market_detail"):return _abort_owned(scene,root,'Startup cancelled')
  preload('res://scripts/market_detail.gd').apply(root.get_node(spec.id+'Stand'),spec,load('res://scripts/market_expansion.gd'),{'wood':timber,'bronze':bronze,'stone':stone,'cream':cream,'dark':dark})
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("market helper market_wall_finish"):return _abort_owned(scene,root,'Startup cancelled')
  preload('res://scripts/market_wall_finish.gd').apply(root.get_node(spec.id+'Stand'),spec,load('res://scripts/market_expansion.gd'),{'wood':timber,'bronze':bronze,'stone':stone,'cream':cream,'dark':dark})
  preload('res://scripts/trader_selective_finish.gd').apply(root.get_node(spec.id+'Stand'),spec,load('res://scripts/market_expansion.gd'),{'wood':timber,'bronze':bronze,'stone':stone,'cream':cream,'dark':dark})
  var envelope=preload('res://scripts/trader_side_envelope_finish.gd').apply(root.get_node(spec.id+'Stand'),spec,load('res://scripts/market_expansion.gd'),{'wood':timber,'bronze':bronze,'stone':stone,'cream':cream,'dark':dark})
  if not envelope.get('ok',false):return _abort_owned(scene,root,'Side envelope '+str(spec.id)+': '+str(envelope.get('reason','Unknown failure')))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("market operation 21"):return _abort_owned(scene,root,'Startup cancelled')
 preload('res://scripts/market_surroundings.gd').apply(root,SPECS,load('res://scripts/market_expansion.gd'),{'wood':timber,'bronze':bronze,'stone':stone,'cream':cream,'dark':dark})
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("market operation 22"):return _abort_owned(scene,root,'Startup cancelled')
 preload('res://scripts/market_signage.gd').apply(root,SPECS,load('res://scripts/market_expansion.gd'),{'wood':timber,'bronze':bronze,'stone':stone,'cream':cream,'dark':dark})
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("market operation 23"):return _abort_owned(scene,root,'Startup cancelled')
 for spec in SPECS:
  preload('res://scripts/market_review_finish.gd').apply(root.get_node(spec.id+'Stand'),spec,load('res://scripts/rook_shop_art.gd'))
 for spec in SPECS:
  if spec.id in ['Psy','Atlas']:preload('res://scripts/shop_surround_detail.gd').apply(root.get_node(spec.id+'Stand'),spec)
 preload('res://scripts/dan_material_detail.gd').apply(root.get_node('DanStand'))
 preload('res://scripts/hideout_terrace.gd').batch_static_visuals(root)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("market operation 24"):return _abort_owned(scene,root,'Startup cancelled')
 for child in root.get_children():
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("market loop 25"):return _abort_owned(scene,root,'Startup cancelled')
  if child is MultiMeshInstance3D:child.name='Market material batch'
 if _cancelled(scene):return _abort_owned(scene,root,'Startup cancelled before publication')
 # Extend ground-region audio with exact new visual paving, without extra floor collision.
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("market operation 26"):return _abort_owned(scene,root,'Startup cancelled')
 var aprons=[]
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("market operation 27"):return _abort_owned(scene,root,'Startup cancelled')
 for spec in SPECS:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("market loop 28"):return _abort_owned(scene,root,'Startup cancelled')
  var shop=root.get_node(spec.id+'Stand');var center=shop.to_global(Vector3(0,0,spec.depth/2+1.5))
  var half=Vector2(1.7,spec.width/2) if absf(spec.yaw)>0.1 and absf(spec.yaw)<3.0 else Vector2(spec.width/2,1.7)
  aprons.append(Rect2(Vector2(center.x,center.z)-half,half*2))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("market operation 29"):return _abort_owned(scene,root,'Startup cancelled')
 var audio_targets=[]
 for body in scene.find_children('*','StaticBody3D',true,false):
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("market loop 30"):return _abort_owned(scene,root,'Startup cancelled')
  if body.has_meta('audio_ground_regions'):audio_targets.append(body)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("market operation 31"):return _abort_owned(scene,root,'Startup cancelled')
 root.set_meta('paving_polygons',paving_polygons)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("market operation 32"):return _abort_owned(scene,root,'Startup cancelled')
 # External scene/audio metadata publication is deferred until final nonyielding commit.
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("market operation 33"):return _abort_owned(scene,root,'Startup cancelled')
 preload("res://scripts/visible_trader_study.gd").attach_to_market(root)
 if _cancelled(scene):return _abort_owned(scene,root,'Startup cancelled before return')
 for body in audio_targets:
  if not is_instance_valid(body) or not body.is_inside_tree():return _abort_owned(scene,root,'Audio target disappeared before publication')
 # No await/callback between final validation and all external metadata writes.
 for body in audio_targets:
  body.set_meta('market_paving_paths',paths);body.set_meta('market_paving_aprons',aprons);body.set_meta('market_paving_polygons',paving_polygons)
 scene.set_meta('market_expansion',{'new_visual_stands':3,'live_new_services':0,'progress_changes':false})
 return root
