extends Node3D
# Inn-only second finish pass: guest rooms, readable windows and retained approach/deck.
# All existing collision, service, roof, lake and placement contracts remain authoritative.
const Finish=preload('res://scripts/inn_interior_v094.gd')
const Cycle=preload('res://scripts/day_night_cycle.gd')
const INTERIOR_LAYER=524288
var pane_materials:Array=[]
var pane_levels:Array=[]
var clock:Node
var tick:float=0.0
func _process(delta:float)->void:
 tick+=delta
 if tick<.20:return
 tick=0.0;sync_window_lighting()
func sync_window_lighting()->void:
 if not is_instance_valid(clock):
  var ancestor=get_parent()
  while ancestor!=null:
   clock=ancestor.get_node_or_null('DayNightCycle')
   if clock!=null:break
   ancestor=ancestor.get_parent()
 var daylight=1.0
 if is_instance_valid(clock):daylight=Cycle.sample(clock.elapsed_seconds/clock.cycle_seconds).daylight
 for i in pane_materials.size():pane_materials[i].emission_energy_multiplier=lerpf(pane_levels[i],.045,daylight)
static func materials()->Dictionary:
 var glow=Finish.plain('f0d4a2');glow.emission_enabled=true;glow.emission=Color('ffd398');glow.emission_energy_multiplier=.35
 return {'glow':glow,'quiet_glass':Finish.plain('817f64',.52),'wood':Finish.finish('806044'),'edge':Finish.finish('644730'),'upright':Finish.finish('745338',0,1),'plaster':Finish.finish('c7b79a',2),'linen':Finish.finish('c7b79a',3),'sage':Finish.finish('768273',3),'ochre':Finish.finish('b38c56',3),'iron':Finish.plain('493e31',.7),'dark':Finish.plain('3d3428'),'soil':Finish.plain('4c3b2b'),'leaf':Finish.plain('596b3d'),'ceramic':Finish.plain('b9aa86',.4),'bread':Finish.plain('b98b4d'),'stone':Finish.plain('b4a58a'),'gold':Finish.plain('a28c64',.65)}
static func group(parent:Node3D,label:String)->Node3D:
 var n=Node3D.new();n.name=label;parent.add_child(n);return n
static func box(parent:Node3D,label:String,p:Vector3,size:Vector3,m:Material,interior:bool=true)->MeshInstance3D:
 var n=Finish.box(parent,label,p,size,m);n.layers=INTERIOR_LAYER if interior else 1;n.set_meta('finish_label',label);return n
static func cylinder(parent:Node3D,label:String,p:Vector3,r:float,h:float,m:Material,top:float=-1.0,interior:bool=true)->MeshInstance3D:
 var n=Finish.cylinder(parent,label,p,r,h,m,top);n.layers=INTERIOR_LAYER if interior else 1;n.set_meta('finish_label',label);return n
static func beam(parent:Node3D,label:String,a:Vector3,b:Vector3,w:float,d:float,m:Material,interior:bool=true):
 var n=box(parent,label,(a+b)*.5,Vector3(w,d,a.distance_to(b)),m,interior);n.basis=Basis.looking_at(b-a,Vector3.UP);return n
static func ellipsoid(parent:Node3D,label:String,p:Vector3,size:Vector3,m:Material,interior:bool=true):
 var n=MeshInstance3D.new();n.name=label;n.position=p;var mesh=SphereMesh.new();mesh.radius=.5;mesh.height=1;mesh.radial_segments=10;mesh.rings=5;n.mesh=mesh;n.scale=size;n.material_override=m;n.layers=INTERIOR_LAYER if interior else 1;parent.add_child(n);return n
static func batch(parent:Node3D):
 var batches={};var meshes=parent.find_children('*','MeshInstance3D',true,false)
 for n in meshes:
  var key=str(n.material_override.get_instance_id())+':'+str(n.layers)
  if not batches.has(key):
   var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);batches[key]={'st':st,'material':n.material_override,'layers':n.layers,'names':[],'bounds':[]}
  var t=n.transform;var ancestor=n.get_parent()
  while ancestor!=parent:t=ancestor.transform*t;ancestor=ancestor.get_parent()
  for surface in n.mesh.get_surface_count():
   var expanded=SurfaceTool.new();expanded.create_from(n.mesh,surface);expanded.deindex();batches[key].st.append_from(expanded.commit(),0,t)
  batches[key].names.append(n.get_meta('finish_label',str(parent.get_path_to(n))));batches[key].bounds.append(t*n.mesh.get_aabb());n.free()
 for key in batches:
  var data=batches[key];var n=MeshInstance3D.new();n.name='InnFinishBatch';n.mesh=data.st.commit();n.material_override=data.material;n.layers=data.layers;n.set_meta('source_names',data.names);n.set_meta('source_bounds',data.bounds);parent.add_child(n)
 parent.set_meta('source_meshes',meshes.size());parent.set_meta('draw_surfaces',batches.size())
static func plaque(parent:Node3D,title:String,p:Vector3,rotation_y:float,m:Dictionary,interior:bool=true):
 var n=group(parent,'MountedPlaque'+title);n.position=p;n.rotation.y=rotation_y
 box(n,'Plaque timber backing',Vector3.ZERO,Vector3(.34,.22,.045),m.edge,interior)
 var text=Label3D.new();text.name='EngravedRoomNumber';text.text=title;text.font_size=56;text.pixel_size=.0022;text.modulate=Color('e1cda5');text.position.z=.027;text.no_depth_test=false;text.billboard=BaseMaterial3D.BILLBOARD_DISABLED;text.outline_size=0;text.layers=INTERIOR_LAYER if interior else 1;n.add_child(text)
static func lamp(parent:Node3D,label:String,p:Vector3,energy:float,radius:float,m:Dictionary,wall:bool=false):
 var n=group(parent,label);n.position=p
 var glow=m.glow
 box(n,'Amber pane',Vector3.ZERO,Vector3(.16,.22,.16),glow)
 for y in [-.14,.14]:box(n,'Iron cap',Vector3(0,y,0),Vector3(.23,.04,.22),m.iron)
 for x in [-.095,.095]:box(n,'Upright frame',Vector3(x,0,0),Vector3(.022,.26,.20),m.iron)
 if wall:
  box(n,'Wall mounting plate',Vector3(0,.04,-.16),Vector3(.13,.36,.035),m.iron)
  box(n,'Wall bracket',Vector3(0,-.14,-.08),Vector3(.045,.045,.20),m.iron)
 else:cylinder(n,'Lamp foot',Vector3(0,-.175,0),.075,.04,m.iron)
 var light=OmniLight3D.new();light.name='GuestWarmPractical';light.light_color=Color('ffdbaf');light.light_energy=energy;light.omni_range=radius;light.omni_attenuation=1.25;light.shadow_enabled=false;light.light_cull_mask=INTERIOR_LAYER;n.add_child(light)
static func bread_basket(parent:Node3D,p:Vector3,m:Dictionary):
 box(parent,'Bread basket base',p+Vector3(0,.025,0),Vector3(.42,.05,.27),m.ochre)
 for x in [-.205,.205]:box(parent,'Basket end',p+Vector3(x,.075,0),Vector3(.025,.13,.27),m.ochre)
 for z in [-.13,.13]:
  box(parent,'Basket rim',p+Vector3(0,.115,z),Vector3(.43,.025,.025),m.edge)
  for x in [-.15,-.075,0,.075,.15]:box(parent,'Basket weave',p+Vector3(x,.068,z),Vector3(.038,.09,.018),m.ochre)
 for x in [-.115,.10]:ellipsoid(parent,'Bread loaf',p+Vector3(x,.115,0),Vector3(.17,.14,.22),m.bread)
static func curtain_width(x:float,width:float)->float:
 return width*(.11 if absf(x)>4 else .17)
static func interior_window(parent:Node3D,p:Vector3,width:float,height:float,rotation_y:float,m:Dictionary,add_pane:bool=true):
 var n=group(parent,'WindowInteriorReveal');n.position=p;n.rotation.y=rotation_y
 if add_pane:box(n,'Quiet glazed pane',Vector3(0,0,.055),Vector3(width,height,.018),m.quiet_glass)
 for x in [-width*.5,width*.5]:box(n,'Deep window jamb',Vector3(x,0,0),Vector3(.10,height+.16,.16),m.edge)
 for y in [-height*.5,height*.5]:box(n,'Window reveal sill',Vector3(0,y,.025),Vector3(width+.18,.10,.22),m.wood)
 # Added opaque panes sit at .055; their mullions must remain room-side of glass.
 var bar_z=.075 if add_pane else .012
 var bar_depth=.035 if add_pane else .06
 var count=2 if width>2 else 1
 for i in count:
  var x=0.0 if count==1 else (-1 if i==0 else 1)*width/6
  box(n,'Window interior mullion',Vector3(x,0,bar_z),Vector3(.055,height,bar_depth),m.wood)
 box(n,'Window crosspiece',Vector3(0,height*.08,bar_z),Vector3(width,.045,bar_depth),m.wood)
 var horizontal=p.z if absf(rotation_y+PI/2)<.1 else p.x
 var cw=curtain_width(horizontal,width)
 box(n,'Curtain rod',Vector3(0,height*.5+.13,.13),Vector3(width+.28,.025,.025),m.iron)
 for side in [-1,1]:
  box(n,'Soft linen curtain',Vector3(side*(width*.5-cw*.5),0,.115),Vector3(cw,height+.02,.045),m.linen)
  for i in 3:box(n,'Curtain fold',Vector3(side*(width*.5-cw*.5)+(i-1)*cw*.28,0,.145),Vector3(.018,height,.018),m.sage)
 n.set_meta('window_projection',{'width':width,'height':height,'center':p,'rotation_y':rotation_y,'curtain_width':cw})
# V96-08: one shallow framed print on each room's east partition. All pieces
# enter the existing room-material batch and remain present on every quality tier.
static func room_signature(parent:Node3D,number:int,p:Vector3,m:Dictionary):
 var frame=group(parent,'RoomSignature'+str(number));frame.position=p;frame.rotation.y=-PI/2
 box(frame,'Room '+str(number)+' framed linen print',Vector3.ZERO,Vector3(.86,.66,.04),m.edge)
 box(frame,'Print linen ground',Vector3(0,0,.026),Vector3(.76,.56,.012),m.linen)
 var ink=m.sage if number==1 else (m.ochre if number==2 else (m.lake_accent if number==3 else m.botanical_accent))
 if number==1 or number==3:
  # Lake horizon and two hill contours; room three adds a small setting sun.
  box(frame,'Lake horizon',Vector3(0,-.09,.036),Vector3(.63,.018,.008),ink)
  for spec in [[Vector3(-.31,-.04,.036),Vector3(-.10,.15,.036)],[Vector3(-.10,.15,.036),Vector3(.07,-.04,.036)],[Vector3(.03,.01,.036),Vector3(.18,.12,.036)],[Vector3(.18,.12,.036),Vector3(.31,-.04,.036)]]:
   beam(frame,'Sketched lakeside hill',spec[0],spec[1],.018,.008,ink)
  for i in 3:box(frame,'Lake reflection',Vector3(-.09+i*.07,-.14-i*.032,.036),Vector3(.30-i*.055,.012,.008),ink)
  if number==3:ellipsoid(frame,'Ochre sun',Vector3(.27,.18,.038),Vector3(.075,.075,.008),m.ochre)
 else:
  # Room two is a reed study, room four a paired botanical sprig.
  for side in [-1,1]:
   var x=side*.13
   beam(frame,'Botanical stem',Vector3(x,-.23,.036),Vector3(x+side*.04,.19,.036),.014,.008,ink)
   if number==2:
    box(frame,'Reed seed head',Vector3(x+side*.04,.15,.038),Vector3(.045,.16,.008),ink)
   else:
    for i in 3:
     var leaf=box(frame,'Pressed botanical leaf',Vector3(x+side*.055,-.10+i*.10,.038),Vector3(.095,.035,.008),ink);leaf.rotation.z=side*.45
 frame.set_meta('room_signature',number)
static func apply_interior(inn:Node3D)->Dictionary:
 if inn.has_meta('inn_guest_finish_v094'):return inn.get_meta('inn_guest_finish_v094')
 var m=materials();var root=group(inn,'InnGuestFinishV094')
 # Two quieter accent variations derived from the existing sage/ochre family.
 m.lake_accent=Finish.plain('6b7a70');m.botanical_accent=Finish.plain('9c956b')
 # Hospitality stays on the original counter and existing furniture footprints.
 box(root,'Counter work mat',Vector3(-4.35,1.143,2.1),Vector3(.75,.005,.46),m.sage)
 bread_basket(root,Vector3(-6.68,1.145,2.1),m)
 var menu=group(root,'HouseMenuPlaque');menu.position=Vector3(-2.10,1.85,5.755);menu.rotation.y=PI
 box(menu,'Menu backing',Vector3.ZERO,Vector3(.74,.89,.045),m.edge)
 box(menu,'Menu slate',Vector3(0,0,.026),Vector3(.64,.79,.018),m.dark)
 var text=Label3D.new();text.text='HOUSE FARE\n\nBread & broth\nWarm drinks';text.font_size=38;text.pixel_size=.0025;text.modulate=Color('d8c7a6');text.position.z=.042;text.outline_size=0;text.layers=INTERIOR_LAYER;menu.add_child(text)
 box(root,'West gathering rug',Vector3(-4.7,.008,-2.4),Vector3(3.12,.012,2.68),m.sage)
 for x in [-6.14,-3.26]:box(root,'Rug woven border',Vector3(x,.015,-2.4),Vector3(.045,.004,2.5),m.linen)
 # Backed seats stay inside the original stool extents rather than forcing a wall bench.
 for x in [-5.45,-3.95]:
  for y in [.60,.88]:box(root,'Gathering chair back rail',Vector3(x,y,-3.51),Vector3(.37,.065,.045),m.wood)
  for dx in [-.16,.16]:box(root,'Gathering chair upright',Vector3(x+dx,.71,-3.51),Vector3(.045,.52,.045),m.edge)
  box(root,'Gathering chair cushion',Vector3(x,.516,-3.35),Vector3(.35,.018,.34),m.ochre)
 box(root,'East table folded napkin',Vector3(2.12,.828,-2.22),Vector3(.24,.012,.18),m.sage)
 bread_basket(root,Vector3(-4.95,.823,-2.4),m)
 var upper=inn.get_node('UpperRoomsAndLanding')
 for n in upper.get_children():
  if not n is MeshInstance3D:continue
  var label=str(n.name)
  if label.begins_with('Room'):n.material_override=m.plaster;n.layers=INTERIOR_LAYER
  if label.begins_with('BedFrame'):n.material_override=m.wood;n.layers=INTERIOR_LAYER
  if label.begins_with('BedCover'):n.material_override=m.sage;n.layers=INTERIOR_LAYER
  if label.begins_with('BedPillow'):n.material_override=m.linen;n.layers=INTERIOR_LAYER
  if 'Landing' in label:n.material_override=Finish.finish('906a49',1,2);n.layers=INTERIOR_LAYER
  if label.begins_with('Room') and not 'Lintel' in label:
   var size=n.mesh.size
   if size.z>.2:
    for side in [-1,1]:box(root,'Partition skirting',Vector3(n.position.x+side*(size.x*.5+.018),3.30,n.position.z),Vector3(.035,.20,size.z),m.edge)
   else:
    for side in [-1,1]:box(root,'Door wall skirting',Vector3(n.position.x,3.30,n.position.z+side*.088),Vector3(size.x,.20,.035),m.edge)
 # Thin room-facing plaster sheets, not replacement external walls or openings.
 box(root,'Upper front sill plaster',Vector3(0,3.65,-5.788),Vector3(15.4,.9,.018),m.plaster)
 box(root,'Upper front header plaster',Vector3(0,5.95,-5.788),Vector3(15.4,.9,.018),m.plaster)
 box(root,'Front upper skirting',Vector3(0,3.30,-5.76),Vector3(15.3,.20,.045),m.edge)
 box(root,'Upper west plaster',Vector3(-7.688,4.75,0),Vector3(.024,3.1,11.6),m.plaster)
 box(root,'Upper rear plaster',Vector3(0,4.75,5.788),Vector3(15.35,3.1,.024),m.plaster)
 box(root,'Upper east plaster',Vector3(7.688,4.75,0),Vector3(.024,3.1,11.6),m.plaster)
 for x in [-7.66,7.66]:box(root,'Upper perimeter skirting',Vector3(x,3.30,0),Vector3(.045,.20,11.6),m.edge)
 box(root,'Rear upper skirting',Vector3(0,3.30,5.76),Vector3(15.3,.20,.045),m.edge)
 for n in inn.get_node('ExteriorWalls').get_children():
  if str(n.name).begins_with('UpperGlazing'):n.material_override=m.quiet_glass;n.layers=INTERIOR_LAYER
 for x in [-5.3,-3.1,3.1,5.3]:interior_window(root,Vector3(x,1.65,-5.765),1.35,1.65,0,m)
 for z in [-3.9,-1.3,4.6]:interior_window(root,Vector3(7.66,1.65,z),1.35,1.65,-PI/2,m)
 for x in [-5.75,-1.925,1.925,5.75]:interior_window(root,Vector3(x,4.8,-5.78),3.3,1.3,0,m,false)
 for x in [-5.7,-2.2,2.2,5.7]:interior_window(root,Vector3(x,4.8,5.765),1.6,1.5,PI,m)
 for z in [-3.9,-.9,2.1,4.7]:interior_window(root,Vector3(7.66,4.8,z),1.55,1.3,-PI/2,m)
 for x in [-5.2,-.2]:
  for z in [-3.0,3.7]:
   box(root,'Bed headboard',Vector3(x,3.88,z+1.045),Vector3(1.49,.50,.095),m.edge)
   box(root,'Headboard inset',Vector3(x,3.94,z+.99),Vector3(1.25,.25,.025),m.wood)
   box(root,'Bed footboard',Vector3(x,3.58,z-1.075),Vector3(1.48,.28,.065),m.edge)
   for side in [-1,1]:box(root,'Bedframe rim',Vector3(x+side*.725,3.69,z),Vector3(.065,.12,2.18),m.edge)
   ellipsoid(root,'Soft pillow crown',Vector3(x,3.89,z+.65),Vector3(1.12,.14,.40),m.linen)
   box(root,'Folded guest blanket',Vector3(x,3.794,z-.63),Vector3(1.36,.026,.65),m.ochre if z<0 else m.sage)
   for dx in [-.43,.43]:box(root,'Bed runner stripe',Vector3(x+dx,3.81,z-.63),Vector3(.035,.006,.65),m.linen)
   box(root,'Bedside attached shelf',Vector3(x+.96,3.88,z+.72),Vector3(.43,.065,.42),m.wood)
   beam(root,'Shelf support',Vector3(x+.72,3.58,z+.72),Vector3(x+1.08,3.85,z+.72),.045,.055,m.edge)
   lamp(root,'Guest bedside lantern',Vector3(x+.97,4.11,z+.73),.70,3.8,m)
   box(root,'Guest woven rug',Vector3(x,3.21,z),Vector3(2.38,.014,2.80),m.linen if z<0 else m.sage)
   box(root,'Compact guest chest',Vector3(x-1.26,3.39,z+.68),Vector3(.52,.36,.64),m.wood)
   box(root,'Guest chest lid',Vector3(x-1.26,3.585,z+.68),Vector3(.55,.04,.67),m.edge)
   for dz in [-.18,.18]:box(root,'Chest strap',Vector3(x-1.26,3.611,z+.68+dz),Vector3(.55,.012,.035),m.iron)
   box(root,'Chest latch',Vector3(x-1.26,3.48,z+.345),Vector3(.05,.10,.02),m.gold)
 var number=1
 for z in [-1.1,1.1]:
  for x in [-5.2,-.2]:
   for side in [-1,1]:
    for dx in [-.522,.522]:box(root,'Guest door jamb',Vector3(x+dx,4.31,z+side*.09),Vector3(.09,2.22,.055),m.edge)
    box(root,'Guest door lintel',Vector3(x,5.43,z+side*.09),Vector3(1.135,.10,.055),m.wood)
   box(root,'Flush guest threshold',Vector3(x,3.207,z),Vector3(.95,.012,.26),m.wood)
   plaque(root,str(number),Vector3(x+.78,4.82,z-signf(z)*.112),0 if z<0 else PI,m)
   room_signature(root,number,Vector3(x+2.41,4.95,-3.0 if z<0 else 3.4),m);number+=1
 box(root,'Central corridor runner',Vector3(-2.65,3.211,0),Vector3(9.65,.014,1.18),m.sage)
 for z in [-.54,.54]:box(root,'Runner border',Vector3(-2.65,3.222,z),Vector3(9.45,.004,.035),m.ochre)
 box(root,'North arrival runner',Vector3(-.45,3.211,-5.19),Vector3(12.5,.014,.70),m.sage)
 lamp(root,'Guest landing wall lantern',Vector3(3.46,5.0,-5.70),.80,4.3,m,true)
 plaque(root,'1–4',Vector3(3.46,4.45,-5.72),0,m)
 batch(root)
 var result={'ok':true,'guest_rooms':4,'numbered_thresholds':4,'new_practical_lights':5,'shadowed_lights':0,'collisions_changed':false,'routes_changed':false,'draw_surfaces':root.get_meta('draw_surfaces'),'source_meshes':root.get_meta('source_meshes'),'comfortable_group':'Backed existing west stools within retained footprint; no extra bench forced into aisle'}
 inn.set_meta('inn_guest_finish_v094',result);return result
static func local_bounds(node:Node3D)->AABB:
 var bounds=AABB();var first=true
 for mesh in node.find_children('*','MeshInstance3D',true,false):
  var t=mesh.transform;var ancestor=mesh.get_parent()
  while ancestor!=node:t=ancestor.transform*t;ancestor=ancestor.get_parent()
  var b=t*mesh.mesh.get_aabb();bounds=b if first else bounds.merge(b);first=false
 return bounds
static func finish_boxes(facade:Node3D,details:Node3D,m:Dictionary)->Dictionary:
 var boxes=[];var plants=[]
 for n in facade.get_children():
  if n is MeshInstance3D and n.mesh is BoxMesh and n.mesh.size.x>1.7 and n.mesh.size.x<2.8 and n.mesh.size.y>.25 and n.mesh.size.y<.29 and n.mesh.size.z>.3 and n.mesh.size.z<.5 and n.position.y>3.9 and n.position.y<4.0:boxes.append(n)
  elif n is Node3D and not n is MeshInstance3D and not n is Light3D and not n.find_children('*','MeshInstance3D',true,false).is_empty():
   if n!=details and n.position.y>3.8 and n.position.y<4.4:plants.append(n)
 var changed=0
 for i in boxes.size():
  var planter=boxes[i];var sz=planter.mesh.size;var soil_y=planter.position.y+sz.y*.5+.005
  var soil_front=planter.position.z-sz.z*.5+.04
  var safe_back=planter.position.z+sz.z*.5-.04
  # Legacy front/east boxes overlap the glass. The soil boundary alone is not
  # sufficient: keep all imported foliage outside the actual outward pane face.
  for pane in facade.get_children():
   if not pane is MeshInstance3D or not pane.mesh is BoxMesh:continue
   var glass_size=pane.mesh.size
   if not is_equal_approx(glass_size.z,.035) or glass_size.x<=1.3:continue
   if absf(pane.position.x-planter.position.x)>(glass_size.x+sz.x)*.5:continue
   if pane.position.y-glass_size.y*.5>soil_y+.34 or pane.position.y+glass_size.y*.5<soil_y:continue
   safe_back=minf(safe_back,pane.position.z-glass_size.z*.5-.025)
  assert(safe_back>soil_front,'Window box has no glass-safe soil depth')
  var safe_depth=safe_back-soil_front
  box(details,'Visible window box soil',Vector3(planter.position.x,soil_y,planter.position.z),Vector3(sz.x-.12,.015,sz.z-.08),m.soil,false)
  for dx in [-sz.x*.34,sz.x*.28]:
   box(details,'Flower box support',Vector3(planter.position.x+dx,planter.position.y-.12,planter.position.z+sz.z*.5-.02),Vector3(.07,.28,.10),m.edge,false)
  for plant in plants:
   if absf(plant.position.x-planter.position.x)>sz.x*.55 or absf(plant.position.z-planter.position.z)>.6:continue
   var b=local_bounds(plant);var desired=.22+float(changed%3)*.055
   var sx=plant.scale.x*(.78 if sz.x<2 else .86)
   plant.scale=Vector3(sx,desired/maxf(b.size.y,.001),sx)
   plant.position.y=soil_y-b.position.y*plant.scale.y
   plant.rotation.y=float(changed%5)*.46
   # Retained imported petals can project behind a rotated cluster. Fit its full
   # transformed bounds to the existing soil footprint, keeping every original mesh.
   var rotated=Transform3D(plant.basis,Vector3.ZERO)*b
   var fit=minf(1.0,minf(safe_depth/maxf(rotated.size.z,.001),(sz.x-.14)/maxf(rotated.size.x,.001)))
   plant.scale*=Vector3(fit,1,fit)
   rotated=Transform3D(plant.basis,Vector3.ZERO)*b
   plant.position.z=(soil_front+safe_back)*.5-rotated.get_center().z
   plant.position.x=clampf(plant.position.x,planter.position.x-sz.x*.5+.07-rotated.position.x,planter.position.x+sz.x*.5-.07-rotated.end.x)
   plant.set_meta('window_box_envelope',AABB(Vector3(planter.position.x-sz.x*.5+.07,soil_y,soil_front),Vector3(sz.x-.14,desired,safe_depth)))
   plant.set_meta('glass_outward_max_z',safe_back)
   changed+=1
  # A few short trailing leaves break identical upright outlines without hiding glass.
  for j in [0,1]:
   var x=planter.position.x+(-.28 if j==0 else .31)*sz.x
   var z=planter.position.z-sz.z*.5-.015
   for k in range(3 if (i+j)%2==0 else 2):
    var at=Vector3(x+sin(float(k+i))*.035,soil_y-.045-k*.07,z-.015*k)
    ellipsoid(details,'Short trailing foliage',at,Vector3(.13,.10,.07),m.leaf,false)
 return {'boxes':boxes.size(),'rescaled_original_clusters':changed,'max_upright_height':.33,'original_plant_assets_retained':true}
static func window_finish(facade:Node3D,details:Node3D,controller:Node3D,m:Dictionary)->Dictionary:
 var panes=[];var removed=0
 # Legacy factories deliberately allow generated duplicate node names. Match the
 # exact visual geometry contract, not only the first human-readable node name.
 for n in facade.get_children():
  if not n is MeshInstance3D or not n.mesh is BoxMesh:continue
  var sz=n.mesh.size
  if is_equal_approx(sz.z,.035) and sz.x>1.3 and sz.y>1.29 and n.material_override is StandardMaterial3D and n.material_override.emission_enabled:panes.append(n)
 for n in facade.get_children():
  if not n is MeshInstance3D or not n.mesh is BoxMesh:continue
  var sz=n.mesh.size
  for pane in panes:
   var lattice=is_equal_approx(sz.x,.018) and is_equal_approx(sz.y,.018) and is_equal_approx(n.position.z,pane.position.z-.08)
   var mullion=is_equal_approx(sz.x,.035) and is_equal_approx(sz.z,.035) and is_equal_approx(n.position.z,pane.position.z-.06)
   if (lattice or mullion) and absf(n.position.x-pane.position.x)<pane.mesh.size.x*.51 and absf(n.position.y-pane.position.y)<pane.mesh.size.y*.51:
    n.visible=false;removed+=1;break
 var glass=[]
 for i in range(4):
  var mat=Finish.plain(['b5a078','a69779','bcaa83','a5997d'][i],.56);mat.emission_enabled=true;mat.emission=Color('ffd29b');mat.emission_energy_multiplier=.045;glass.append(mat);controller.pane_materials.append(mat);controller.pane_levels.append([.32,.24,.40,.28][i])
 for i in panes.size():
  var pane=panes[i];var sz=pane.mesh.size;var p=pane.position;pane.material_override=glass[i%4]
  for side in [-1,1]:box(details,'Window deep outer jamb',p+Vector3(side*sz.x*.5,0,-.07),Vector3(.10,sz.y+.18,.16),m.edge,false)
  for side in [-1,1]:box(details,'Window deep outer sill',p+Vector3(0,side*sz.y*.5,-.07),Vector3(sz.x+.18,.10,.18),m.wood,false)
  var count=2 if sz.x>2 else 1
  for j in count:
   var dx=0.0 if count==1 else (-1 if j==0 else 1)*sz.x/6
   box(details,'Calm window mullion',p+Vector3(dx,0,-.07),Vector3(.055,sz.y,.065),m.wood,false)
  box(details,'Calm window crosspiece',p+Vector3(0,sz.y*.08,-.07),Vector3(sz.x,.045,.065),m.wood,false)
  var cw=curtain_width(p.x,sz.x);pane.set_meta('curtain_width',cw)
  for side in [-1,1]:box(details,'Visible room curtain',p+Vector3(side*(sz.x*.5-cw*.5),0,-.027),Vector3(cw,sz.y-.04,.018),m.linen,false)
 return {'panes':panes.size(),'hidden_dense_lattice_parts':removed,'day_emission':.045,'night_emission_range':[.24,.40],'new_lights':0}
static func apply_front(front:Node3D)->Dictionary:
 if front.has_meta('inn_window_finish_v094'):return front.get_meta('inn_window_finish_v094')
 var m=materials();var controller=load('res://scripts/inn_guest_finish_v094.gd').new();controller.name='InnWindowLightRhythm';front.add_child(controller)
 var reports=[]
 for facade in [front,front.get_node('CoherentEastFacade')]:
  var details=group(facade,'CalmWindowDetailsV094')
  var report=window_finish(facade,details,controller,m);report.planting=finish_boxes(facade,details,m);batch(details);report.draw_surfaces=details.get_meta('draw_surfaces');reports.append(report)
 var result={'ok':true,'facades':reports,'day_night_owner':'Local materials follow existing cosmetic DayNightCycle; no clock/global lighting edits'}
 front.set_meta('inn_window_finish_v094',result);return result
static func apply_approach(site:Node3D)->Dictionary:
 if site.has_meta('inn_approach_finish_v094'):return site.get_meta('inn_approach_finish_v094')
 var terrace=site.get_node('TerraceAndApproach');var m=materials();var details=group(terrace,'InnApproachFinishV094');var treads=0;var caps=0;var first_top=0.0
 for n in terrace.get_children():
  if not n is MeshInstance3D:continue
  var label=str(n.name)
  if label.begins_with('ApproachTread'):
   var sz=n.mesh.size;var top=n.position.y+sz.y*.5
   if label=='ApproachTread0':first_top=top
   box(details,'Step stone nosing',Vector3(n.position.x,top+.003,n.position.z-sz.z*.5+.045),Vector3(2.75,.006,.065),m.stone,false);treads+=1
  elif label.begins_with('RailPost'):
   n.material_override=m.upright
   box(details,'Capped stair post',n.position+Vector3(0,.575,0),Vector3(.12,.04,.12),m.gold,false);caps+=1
  elif label.begins_with('RailCap'):n.material_override=m.edge
 # A shallow mounted arrival marker belongs to the existing rail, outside its clear width.
 var marker=group(details,'ApproachArrivalMarker');marker.position=Vector3(5.54,first_top+.70,32.12);marker.rotation.y=PI
 box(marker,'Arrival marker backing',Vector3.ZERO,Vector3(.10,.25,.035),m.gold,false)
 # No extra furniture/planters, light, collider or out-of-footprint landing obstacles.
 batch(details)
 var result={'ok':true,'finished_treads':treads,'post_caps':caps,'nominal_stair_width':3.0,'between_original_rail_inner_faces':2.76,'new_lights':0,'collision_changes':false,'draw_surfaces':details.get_meta('draw_surfaces')}
 site.set_meta('inn_approach_finish_v094',result);return result
static func apply_lakeside(lake:Node3D,inn:Node3D)->Dictionary:
 if lake.has_meta('inn_deck_finish_v094'):return lake.get_meta('inn_deck_finish_v094')
 var m=materials();var details=group(lake,'InnDeckFinishV094');var deckmat=Finish.finish('806449',0,0);var posts=0;var benches=0
 for n in lake.get_children():
  if not n is MeshInstance3D:continue
  var label=str(n.name)
  if label=='RearBalcony' or label=='EastBalcony':n.material_override=deckmat
  if n.mesh is BoxMesh and n.mesh.size.is_equal_approx(Vector3(.12,1.1,.12)):
   box(details,'Balcony capped post',n.position+Vector3(0,.62,0),Vector3(.17,.045,.17),m.edge,false);posts+=1
  if n.mesh is BoxMesh and n.mesh.size.is_equal_approx(Vector3(2,.14,.52)):
   box(details,'Lakeside seat cushion',n.position+Vector3(0,.078,0),Vector3(1.88,.015,.44),m.sage,false);benches+=1
 # Alternating original board tops stay below the 3.4m walking plane and inside deck bounds.
 for spec in lake.get_meta('joined_deck_rects_v098',[Rect2(-8.7,60.1,17.4,2.9),Rect2(8.85,53,3.15,7.2)]):
  for i in range(ceili(spec.size.y/.22)):
   var depth=minf(.208,spec.end.y-(spec.position.y+i*.22)-.008)
   if depth<=0:continue
   var mat=m.wood if i%5==0 else (m.edge if i%7==0 else deckmat)
   box(details,'Restrained deck board variation',Vector3(spec.get_center().x,3.382,spec.position.y+i*.22+depth*.5+.006),Vector3(spec.size.x-.07,.004,depth),mat,false)
  for x in [spec.position.x-.008,spec.end.x+.008]:box(details,'Deck plank end fascia',Vector3(x,3.245,spec.get_center().y),Vector3(.035,.25,spec.size.y),m.edge,false)
  for z in [spec.position.y-.008,spec.end.y+.008]:box(details,'Deck edge endgrain',Vector3(spec.get_center().x,3.245,z),Vector3(spec.size.x,.25,.035),m.wood,false)
 box(details,'Rear deck bearing beam',Vector3(0,3.015,62.6),Vector3(17.35,.21,.22),m.edge,false)
 box(details,'East deck bearing beam',Vector3(11.6,3.015,56.6),Vector3(.22,.21,7.2),m.edge,false)
 for x in [-8,-4,0,4,8]:
  for side in [-1,1]:beam(details,'Rear deck support bracket',Vector3(x,2.30,62.6),Vector3(x+side*.63,2.95,62.6),.11,.13,m.upright,false)
 for z in [53.3,56.5,59.8]:
  beam(details,'East deck support bracket',Vector3(11.6,2.28,z),Vector3(10.95,2.96,z),.11,.13,m.upright,false)
 # Complete the existing two-seat lake grouping; retain the full inner walking strip.
 box(details,'Bench side table top',Vector3(-3,3.91,62.0),Vector3(.52,.055,.48),m.wood,false)
 for dx in [-.18,.18]:
  for dz in [-.16,.16]:box(details,'Bench side table leg',Vector3(-3+dx,3.635,62+dz),Vector3(.055,.50,.055),m.edge,false)
 cylinder(details,'Lake table cup',Vector3(-3,4.005,62),.055,.13,m.ceramic,-1,false)
 cylinder(details,'Lake table cup opening',Vector3(-3,4.073,62),.045,.005,m.dark,-1,false)
 # Rear wall construction joins the existing lower wall; no extra doorway or shoreline work.
 for x in [-7.65,-2.4,2.4,7.65]:box(details,'Rear wall timber stile',Vector3(x,4.97,58.73),Vector3(.10,2.9,.10),m.upright,false)
 for y in [3.60,6.44]:box(details,'Rear wall timber course',Vector3(0,y,58.73),Vector3(15.3,.12,.10),m.edge,false)
 batch(details)
 var rear=lake.get_node('LakesideFacade');var facade_detail=group(rear,'CalmRearWindowsV094')
 var controller=load('res://scripts/inn_guest_finish_v094.gd').new();controller.name='InnWindowLightRhythm';rear.add_child(controller)
 var windows=window_finish(rear,facade_detail,controller,m);windows.planting=finish_boxes(rear,facade_detail,m);batch(facade_detail)
 var result={'ok':true,'capped_posts':posts,'existing_benches_finished':benches,'added_wall_or_deck_collision':0,'new_lights':0,'inner_walking_strip_retained':not lake.has_meta('joined_deck_rects_v098'),'lake_terrain_changes':false,'deck_draw_surfaces':details.get_meta('draw_surfaces'),'windows':windows}
 lake.set_meta('inn_deck_finish_v094',result);return result
