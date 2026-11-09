extends RefCounted
# Inn-only visual finish. Existing physical geometry, routes and service state stay authoritative.
const SURFACE=preload('res://shaders/inn_surface_v094.gdshader')
const INTERIOR_LAYER=524288 # Dedicated visual layer 20; no overlap with market or basement lamps.
static func finish(hex:String,kind:int=0,axis:int=0,roughness:float=.82)->ShaderMaterial:
 var m=ShaderMaterial.new();m.shader=SURFACE;m.set_shader_parameter('tint',Color(hex));m.set_shader_parameter('kind',kind);m.set_shader_parameter('grain_axis',axis);m.set_shader_parameter('roughness',roughness);return m
static func plain(hex:String,roughness:float=.8)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=Color(hex);m.roughness=roughness;return m
static func box(parent:Node3D,label:String,at:Vector3,size:Vector3,m:Material)->MeshInstance3D:
 var node=MeshInstance3D.new();node.name=label;node.position=at;var mesh=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.material_override=m;node.layers=INTERIOR_LAYER;parent.add_child(node);return node
static func cylinder(parent:Node3D,label:String,p:Vector3,radius:float,height:float,m:Material,top:float=-1.0)->MeshInstance3D:
 var n=MeshInstance3D.new();n.name=label;n.position=p;var mesh=CylinderMesh.new();mesh.bottom_radius=radius;mesh.top_radius=radius if top<0 else top;mesh.height=height;mesh.radial_segments=12;mesh.rings=1;n.mesh=mesh;n.material_override=m;n.layers=INTERIOR_LAYER;parent.add_child(n);return n
static func beam(parent:Node3D,label:String,a:Vector3,b:Vector3,w:float,d:float,m:Material):
 var n=box(parent,label,(a+b)*.5,Vector3(w,d,a.distance_to(b)),m);n.basis=Basis.looking_at(b-a,Vector3.UP);return n
static func mug(parent:Node3D,p:Vector3,m:Dictionary):
 cylinder(parent,'Stoneware mug',p+Vector3(0,.065,0),.057,.13,m.ceramic,.062)
 cylinder(parent,'Mug dark opening',p+Vector3(0,.132,0),.047,.005,m.dark)
 # Three slim handle pieces are intentionally simpler than a many-segment torus.
 box(parent,'Mug handle outer',p+Vector3(.089,.068,0),Vector3(.018,.08,.023),m.ceramic)
 for y in [.035,.101]:box(parent,'Mug handle bridge',p+Vector3(.072,y,0),Vector3(.04,.018,.023),m.ceramic)
static func jug(parent:Node3D,p:Vector3,m:Dictionary):
 cylinder(parent,'Serving jug belly',p+Vector3(0,.115,0),.105,.23,m.ceramic,.087)
 cylinder(parent,'Serving jug neck',p+Vector3(0,.265,0),.064,.09,m.ceramic,.075)
 cylinder(parent,'Serving jug mouth',p+Vector3(0,.312,0),.057,.006,m.dark)
 box(parent,'Jug handle',p+Vector3(.13,.18,0),Vector3(.035,.19,.045),m.ceramic)
 for y in [.095,.26]:box(parent,'Jug handle bridge',p+Vector3(.105,y,0),Vector3(.085,.027,.045),m.ceramic)
static func roof_lining(root:Node3D,m:Dictionary):
 var roof=root.get_node('RoofRemovableForCutaway')
 var lining=MeshInstance3D.new();lining.name='InwardTimberRoofLiningV094'
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 # A separate inward-facing skin 45 mm below the original weather roof, with
 # explicit inward normals. Same eaves/ridge footprint; no culling workaround.
 var a=Vector3(-8.5,6.355,-6.5);var b=Vector3(8.5,6.355,-6.5);var c=Vector3(-8.5,6.355,6.5);var d=Vector3(8.5,6.355,6.5);var l=Vector3(-8.5,8.155,0);var r=Vector3(8.5,8.155,0)
 for tri in [[a,l,b],[b,l,r],[l,c,r],[r,c,d],[a,c,l],[b,r,d]]:
  var normal=-(tri[1]-tri[0]).cross(tri[2]-tri[0]).normalized()
  for p in tri:st.set_normal(normal);st.add_vertex(p)
 lining.mesh=st.commit();lining.material_override=m.roof;lining.layers=INTERIOR_LAYER;roof.add_child(lining)
 # Finite edge closures only bridge the 45 mm shell depth, within the old roof bounds.
 for z in [-6.5,6.5]:box(roof,'RoofEaveClosure',Vector3(0,6.3775,z-signf(z)*.0225),Vector3(17,.045,.045),m.roof)
 for x in [-8.4775,8.4775]:
  beam(roof,'RoofGableClosure',Vector3(x,6.3775,-6.5),Vector3(x,8.1775,0),.045,.045,m.roof)
  beam(roof,'RoofGableClosure',Vector3(x,8.1775,0),Vector3(x,6.3775,6.5),.045,.045,m.roof)
static func practical(parent:Node3D,label:String,p:Vector3,energy:float,radius:float,m:Dictionary):
 var fixture=Node3D.new();fixture.name=label;fixture.position=p;parent.add_child(fixture)
 box(fixture,'Hanging stem',Vector3(0,.32,0),Vector3(.025,.64,.025),m.iron)
 box(fixture,'Lantern amber panes',Vector3.ZERO,Vector3(.20,.27,.20),m.glow)
 for x in [-.115,.115]:
  for z in [-.115,.115]:box(fixture,'Lantern corner',Vector3(x,0,z),Vector3(.023,.32,.023),m.iron)
 for y in [-.17,.17]:box(fixture,'Lantern cap',Vector3(0,y,0),Vector3(.29,.045,.29),m.iron)
 var light=OmniLight3D.new();light.name='WarmPracticalLight';light.light_color=Color('ffd5a3');light.light_energy=energy;light.omni_range=radius;light.omni_attenuation=1.15;light.light_cull_mask=INTERIOR_LAYER;light.shadow_enabled=false;fixture.add_child(light)
 # These modest local lamps stay on like the existing exterior lanterns. The
 # original sun/sky day-night controller is untouched, as are all quality settings.
static func batch(parent:Node3D):
 var groups={};var meshes=parent.find_children('*','MeshInstance3D',true,false)
 for n in meshes:
  var key=n.material_override.get_instance_id()
  if not groups.has(key):
   var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);groups[key]={'st':st,'material':n.material_override,'names':[]}
  var t=n.transform;var ancestor=n.get_parent()
  while ancestor!=parent:t=ancestor.transform*t;ancestor=ancestor.get_parent()
  for surface in n.mesh.get_surface_count():
   var expanded=SurfaceTool.new();expanded.create_from(n.mesh,surface);expanded.deindex()
   groups[key].st.append_from(expanded.commit(),0,t)
  groups[key].names.append(str(parent.get_path_to(n)));n.free()
 for key in groups:
  var data=groups[key];var n=MeshInstance3D.new();n.name='InteriorStaticBatch';n.mesh=data.st.commit();n.material_override=data.material;n.layers=INTERIOR_LAYER;n.set_meta('source_names',data.names);parent.add_child(n)
 parent.set_meta('batched_draw_surfaces',groups.size());parent.set_meta('source_mesh_count',meshes.size())
static func apply(inn:Node3D)->Dictionary:
 if inn.has_meta('inn_interior_v094'):return inn.get_meta('inn_interior_v094')
 var m={'wood':finish('89613e'),'upright':finish('745035',0,1),'edge':finish('65462f'),'roof':finish('967650',0,0),'floor':finish('906a49',1,2),'plaster':finish('c7b79a',2),'linen':finish('c7b79a',3),'green':finish('65766a',3),'iron':plain('403a31',.62),'ceramic':plain('b9aa86',.36),'dark':plain('3f3427'),'glass':plain('566b54',.3)}
 var warm=plain('f4cf8d');warm.emission_enabled=true;warm.emission=Color('ffc77c');warm.emission_energy_multiplier=.65;m.glow=warm
 roof_lining(inn,m)
 var root=Node3D.new();root.name='InnCommonRoomFinishV094';inn.add_child(root)
 # Refinish existing common-room surfaces only; their BoxMeshes, transforms and
 # colliders are retained byte-for-byte by construction. No shared furniture edits.
 var floor=inn.get_node('FoundationAndVeranda/GroundFloorDeck');floor.material_override=m.floor;floor.layers=INTERIOR_LAYER
 for n in inn.get_node('GroundGatheringAndBar').get_children():
  if not n is MeshInstance3D:continue
  var name=str(n.name);n.layers=INTERIOR_LAYER
  n.material_override=m.upright if 'Leg' in name else m.wood
  if name=='FutureActivityTableTop':n.material_override=m.green
 for n in inn.get_node('InternalStair').get_children():
  if n is MeshInstance3D:
   n.layers=INTERIOR_LAYER;n.material_override=m.floor if 'Tread' in str(n.name) or 'Landing' in str(n.name) else m.iron
 for n in inn.get_node('UpperRoomsAndLanding').get_children():
  if n is MeshInstance3D and 'Floor' in str(n.name):n.material_override=m.floor;n.layers=INTERIOR_LAYER
 # Plaster liners sit just inside the original wall faces. Split main and east
 # door openings exactly match existing clearances, with no threshold geometry.
 box(root,'West interior plaster',Vector3(-7.691,1.53,0),Vector3(.018,3.06,11.6),m.plaster)
 box(root,'Rear interior plaster',Vector3(0,1.53,5.791),Vector3(15.4,3.06,.018),m.plaster)
 for x in [-4.5,4.5]:box(root,'Front wing interior plaster',Vector3(x,1.53,-5.791),Vector3(6.6,3.06,.018),m.plaster)
 box(root,'Entry interior header',Vector3(0,2.83,-5.791),Vector3(2.4,.46,.018),m.plaster)
 for spec in [[-5.8,1.375],[2.625,5.8]]:
  var z=(spec[0]+spec[1])*.5;var length=spec[1]-spec[0]
  box(root,'East interior plaster',Vector3(7.691,1.53,z),Vector3(.018,3.06,length),m.plaster)
  box(root,'East skirting',Vector3(7.665,.10,z),Vector3(.045,.20,length),m.edge)
 box(root,'East door interior header',Vector3(7.691,2.83,2),Vector3(.018,.46,1.25),m.plaster)
 box(root,'West skirting',Vector3(-7.665,.10,0),Vector3(.045,.20,11.6),m.edge)
 box(root,'Rear skirting',Vector3(0,.10,5.765),Vector3(15.3,.20,.045),m.edge)
 for x in [-4.5,4.5]:box(root,'Entry wing skirting',Vector3(x,.10,-5.765),Vector3(6.6,.20,.045),m.edge)
 # Pale boarded ceiling, with modest cross beams respecting the stairwell opening.
 box(root,'Common ceiling main',Vector3(-1.9,3.067,0),Vector3(12,.018,11.6),m.plaster)
 box(root,'Common ceiling south',Vector3(5.8,3.067,3),Vector3(3.6,.018,5.6),m.plaster)
 box(root,'Common ceiling north',Vector3(5.8,3.067,-5.15),Vector3(3.6,.018,1.3),m.plaster)
 for z in [-4.9,-.4,4.8]:box(root,'Common ceiling crossbeam',Vector3(-1.9,2.985,z),Vector3(11.95,.15,.16),m.edge)
 for x in [-7.59,3.95]:box(root,'Common ceiling perimeter beam',Vector3(x,2.985,0),Vector3(.14,.15,11.6),m.edge)
 box(root,'Rear ceiling continuation',Vector3(5.8,2.985,4.8),Vector3(3.6,.15,.16),m.edge)
 # Bar panel joinery and supported shelves retain the existing counter silhouette.
 for x in [-6.98,-5.9,-4.8,-3.7,-2.62]:box(root,'Bar face stile',Vector3(x,.53,2.003),Vector3(.065,.86,.04),m.edge)
 for y in [.13,.95]:box(root,'Bar face rail',Vector3(-4.8,y,2.003),Vector3(4.43,.065,.04),m.edge)
 for x in [-6.98,-2.62]:box(root,'Bar end support',Vector3(x,.52,2.30),Vector3(.12,1.04,.35),m.upright)
 box(root,'Bar polished lip',Vector3(-4.8,1.067,1.732),Vector3(4.7,.045,.035),m.edge)
 for x in [-7.12,-2.88]:
  box(root,'Backbar upright',Vector3(x,1.32,5.62),Vector3(.12,2.64,.13),m.upright)
  for y in [.65,1.55,2.40]:beam(root,'Shelf supporting bracket',Vector3(x,y-.24,5.59),Vector3(x,y-.035,5.25),.055,.055,m.edge)
 # Finished furniture aprons and stretchers fit entirely within original extents.
 for spec in [[-4.7,-2.4,2.5,1.1],[2.7,-2.4,2.5,1.1],[2.2,3.8,2.5,1.6]]:
  var x=spec[0];var z=spec[1];var width=spec[2];var depth=spec[3]
  for side in [-1,1]:
   box(root,'Table end apron',Vector3(x+side*(width*.5-.15),.65,z),Vector3(.07,.15,depth-.18),m.edge)
   box(root,'Table long apron',Vector3(x,.65,z+side*(depth*.5-.12)),Vector3(width-.22,.15,.07),m.edge)
  box(root,'Table lower stretcher',Vector3(x,.24,z),Vector3(width-.30,.07,.08),m.edge)
 # One restrained runner per communal table. Existing seating and all pull-back
 # spaces stay in place; props occupy tabletops and shelves, never the entry aisle.
 for x in [-4.7,2.7]:
  box(root,'Table linen runner',Vector3(x,.815,-2.4),Vector3(1.7,.008,.37),m.linen)
  jug(root,Vector3(x+.35,.82,-2.4),m)
  mug(root,Vector3(x-.52,.82,-2.55),m);mug(root,Vector3(x+.67,.82,-2.21),m)
 box(root,'Bar folded linen',Vector3(-3.2,1.145,2.15),Vector3(.54,.018,.32),m.linen)
 box(root,'Bar serving tray',Vector3(-5.7,1.147,2.1),Vector3(.72,.025,.41),m.edge)
 for x in [-5.9,-5.67]:mug(root,Vector3(x,1.16,2.1),m)
 jug(root,Vector3(-4.35,1.145,2.14),m)
 for y in [1.60,2.45]:
  for x in [-6.8,-6.56,-4.85,-4.61]:
   var h=.25 if x<-6 else .32
   cylinder(root,'Backbar bottle',Vector3(x,y+h*.5,5.43),.072,h,m.glass,.057)
   cylinder(root,'Bottle neck',Vector3(x,y+h+.045,5.43),.033,.09,m.glass)
  for x in [-3.55,-3.29]:mug(root,Vector3(x,y,5.40),m)
 jug(root,Vector3(-6.7,.70,5.42),m);jug(root,Vector3(-6.35,.70,5.42),m)
 # Four low-cost, interior-only practical lights. No omni shadows or spill onto
 # exterior facades, lake, scenery or vegetation. Day/night remains cosmetic.
 practical(root,'West table lantern',Vector3(-4.7,2.48,-2.4),1.15,5.8,m)
 practical(root,'East table lantern',Vector3(2.7,2.48,-2.4),1.05,5.4,m)
 practical(root,'Bar lantern',Vector3(-4.8,2.48,2.5),1.25,5.8,m)
 practical(root,'Activity lantern',Vector3(2.2,2.48,3.8),.95,5.7,m)
 batch(root)
 var result={'ok':true,'roof_lining_triangles':6,'roof_single_sided':true,'practical_lights':4,'shadowed_lights':0,'interior_light_mask':INTERIOR_LAYER,'detail_draw_surfaces':root.get_meta('batched_draw_surfaces'),'detail_source_meshes':root.get_meta('source_mesh_count'),'collisions_changed':false,'furniture_positions_changed':false,'save_changes':false,'day_night_changes':false}
 inn.set_meta('inn_interior_v094',result);return result
