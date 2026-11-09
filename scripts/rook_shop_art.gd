extends RefCounted
# Reference-led isolated Rook shop art; every mesh is visual-only over accepted blockout collision.
static func mat(hex:String,metal=0.0,rough=.82)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=Color(hex);m.metallic=metal;m.roughness=rough;return m
static func box(root:Node3D,n:String,p:Vector3,size:Vector3,m:Material)->MeshInstance3D:
 var node=MeshInstance3D.new();node.name=n;node.position=p;var mesh=BoxMesh.new();mesh.size=size
 if m is ShaderMaterial:
  var arrays=mesh.surface_get_arrays(0);var colors=PackedColorArray();var color=Color(0,0,0,1);color[size.max_axis_index()]=1.0
  colors.resize(arrays[Mesh.ARRAY_VERTEX].size());colors.fill(color);arrays[Mesh.ARRAY_COLOR]=colors
  var prepared=ArrayMesh.new();prepared.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);node.mesh=prepared
 else:node.mesh=mesh
 node.material_override=m;root.add_child(node);return node
static func sphere(root:Node3D,n:String,p:Vector3,size:Vector3,m:Material)->MeshInstance3D:
 var node=MeshInstance3D.new();node.name=n;node.position=p;var mesh=SphereMesh.new();mesh.radius=.5;mesh.height=1;mesh.radial_segments=10;mesh.rings=5;node.mesh=mesh;node.scale=size;node.material_override=m;root.add_child(node);return node
static func beam(root:Node3D,n:String,a:Vector3,b:Vector3,w:float,m:Material):
 var obj=box(root,n,(a+b)/2,Vector3(w,w,a.distance_to(b)),m);obj.basis=Basis.looking_at(b-a,Vector3.UP if absf((b-a).normalized().y)<.99 else Vector3.RIGHT);return obj
static func label(root:Node3D,n:String,text:String,p:Vector3,size:int,pixel:float,color:Color):
 var l=Label3D.new();l.name=n;l.text=text;l.position=p;l.font_size=size;l.pixel_size=pixel;l.modulate=color;l.outline_size=2;l.outline_modulate=Color('#28211c');l.no_depth_test=false;root.add_child(l);return l
static func mesh_from(root:Node3D,n:String,faces:Array,m:Material):
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for p in faces:st.add_vertex(p)
 st.generate_normals();var obj=MeshInstance3D.new();obj.name=n;obj.mesh=st.commit();obj.material_override=m;root.add_child(obj);return obj
static func parcel(root:Node3D,center:Vector3,scale:float,m:Material):
 # Review MK10: preserve the main fascia and one left-hand secondary emblem.
 if not center.is_equal_approx(Vector3(-2.70,3.42,3.43)) and not center.is_equal_approx(Vector3(-2.65,2.20,3.42)):return
 var vertices=[Vector3(0,.4,0),Vector3(-.35,.2,0),Vector3(0,0,0),Vector3(.35,.2,0),Vector3(-.35,-.2,0),Vector3(0,-.4,0),Vector3(.35,-.2,0)]
 for pair in [[0,1],[1,2],[2,3],[3,0],[1,4],[4,5],[5,6],[6,3],[2,5],[0,2]]:beam(root,'Parcel emblem inlay',center+vertices[pair[0]]*scale,center+vertices[pair[1]]*scale,.025*scale,m)
static func banner(root:Node3D,p:Vector3,m:Material,bronze:Material):
 var faces=[];var width=.62;var height=1.25
 for i in range(8):
  var x0=-width/2+i*width/8;var x1=x0+width/8
  var bottom0=-height+absf(x0)*.30;var bottom1=-height+absf(x1)*.30
  var a=p+Vector3(x0,0,0);var b=p+Vector3(x1,0,0);var c=p+Vector3(x1,bottom1,.07*sin(i*.7));var d=p+Vector3(x0,bottom0,.07*sin((i-1)*.7))
  faces.append_array([a,c,b,a,d,c])
 mesh_from(root,'Hanging cloth supply flag',faces,m)
 box(root,'Flag bronze pole',p+Vector3(0,.025,0),Vector3(.78,.045,.045),bronze)
 parcel(root,p+Vector3(0,-.55,.08),.55,bronze)
static func crystal(root:Node3D,p:Vector3,r:float,h:float,m:Material,tilt:float):
 var faces=[]
 for i in range(6):
  var a=i*TAU/6;var b=(i+1)*TAU/6
  var a0=Vector3(cos(a)*r,0,sin(a)*r);var b0=Vector3(cos(b)*r,0,sin(b)*r)
  var a1=Vector3(cos(a)*r,h*.72,sin(a)*r);var b1=Vector3(cos(b)*r,h*.72,sin(b)*r);var tip=Vector3(r*.15,h,0)
  faces.append_array([a0,b1,b0,a0,a1,b1,a1,tip,b1])
 var obj=mesh_from(root,'Faceted mineral specimen',faces,m);obj.position=p;obj.rotation.z=tilt;return obj
static func foliage(root:Node3D,p:Vector3,size:float,leaf:Material,flower:Material,serial:int):
 for i in range(7):
  var a=i*TAU/7+serial*.8;var out=Vector3(cos(a),.3+float(i%3)*.2,sin(a));var across=Vector3(-sin(a),0,cos(a))
  var mid=p+out*size*.4;var tip=p+out*size;var faces=[p,mid-across*size*.22,tip,p,tip,mid+across*size*.22]
  for k in range(faces.size()):faces[k].z=clampf(faces[k].z,-3.48,3.48)
  mesh_from(root,'Leaf spray',faces,leaf)
 if serial%3==0:
  for j in range(4):sphere(root,'Small violet flower',p+Vector3(cos(j*TAU/4)*.045,size*.28,sin(j*TAU/4)*.045),Vector3(.09,.07,.09),flower)
static func lantern(root:Node3D,p:Vector3,m:Dictionary,energy:float):
 box(root,'Lantern dark backplate',p+Vector3(0,0,-.12),Vector3(.30,.46,.06),m.dark)
 box(root,'Warm lantern glass',p,Vector3(.16,.29,.16),m.glow)
 for x in [-.10,.10]:
  for z in [-.10,.10]:box(root,'Lantern bronze upright',p+Vector3(x,0,z),Vector3(.035,.34,.035),m.bronze)
 for y in [-.18,.18]:box(root,'Lantern bronze cap',p+Vector3(0,y,0),Vector3(.27,.055,.26),m.bronze)
 var light=OmniLight3D.new();light.name='Rook warm local practical';root.add_child(light);light.position=p+Vector3(0,-.03,.35);light.light_color=Color('#ffd799');light.light_energy=energy;light.omni_range=5.0;light.omni_attenuation=1.5;light.shadow_enabled=false
static func batch_static(root:Node3D):
 var groups={}
 var inverse=root.global_transform.affine_inverse()
 for node in root.find_children('*','MeshInstance3D',true,false):
  var material=node.material_override
  var key=material.get_instance_id()
  if not groups.has(key):
   var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);groups[key]={'st':st,'material':material,'sources':[]}
  # Normalize topology before merging: mixing indexed primitives and unindexed
  # custom extrusions otherwise leaves the latter outside the active index buffer.
  for surf in range(node.mesh.get_surface_count()):
   var normalized=SurfaceTool.new();normalized.create_from(node.mesh,surf);normalized.deindex()
   groups[key].st.append_from(normalized.commit(),0,inverse*node.global_transform)
  groups[key].sources.append(str(node.get_path()));node.free()
 for key in groups:
  var group=groups[key];var node=MeshInstance3D.new();node.name='Rook static material batch';node.mesh=group.st.commit();node.material_override=group.material;root.add_child(node);node.set_meta('source_meshes',group.sources)
 root.set_meta('batched_draw_surfaces',groups.size())
static func add_to(scene:Node3D):
 var original=scene.get_node('EastTraderFrontage')
 for mesh in original.get_children():
  if mesh is MeshInstance3D and mesh.name!='Rook connector':mesh.visible=false
 var old_label=scene.get_node_or_null('EastServiceLabel')
 if old_label:
  old_label.visible=false;old_label.set_meta("hide_service_caption",true)
 var art=Node3D.new();art.name='RookReferenceArt';scene.add_child(art);art.position=Vector3(30,0,33);art.rotation.y=PI
 var m={'stone':mat('#bcaf97'),'stone2':mat('#d3c3a6'),'plaster':mat('#cec5ae'),'wood':mat('#684b34'),'dark':mat('#302d27'),'bronze':mat('#aa8043',.60,.60),'edge':mat('#b8b5a5',.65,.46),'cloth':mat('#ded0ae'),'rust':mat('#aa6640'),'teal':mat('#426964'),'wrap':mat('#b9aa8d'),'blade':mat('#363b3e',.62,.66),'cyan':mat('#57b4b6',.35,.45),'glow':mat('#ffcf7e'),'leaf':mat('#51764c'),'flower':mat('#9561a2')}
 var timber=ShaderMaterial.new();timber.shader=preload('res://assets/materials/architecture_surface.gdshader');timber.set_shader_parameter('kind',1);timber.set_shader_parameter('tint',Color('#73543a'));timber.set_shader_parameter('roughness',.82);m.wood=timber
 m.cloth.cull_mode=BaseMaterial3D.CULL_DISABLED;m.rust.cull_mode=BaseMaterial3D.CULL_DISABLED;m.leaf.cull_mode=BaseMaterial3D.CULL_DISABLED
 m.glow.emission_enabled=true;m.glow.emission=Color('#ffb951');m.glow.emission_energy_multiplier=.65
 m.cyan.emission_enabled=true;m.cyan.emission=Color('#45aeb2');m.cyan.emission_energy_multiplier=.28
 var material_detail=preload('res://scripts/rook_material_detail.gd').configure(art,m)
 # Floor masonry and warm plaster retain the complete accepted physical envelope.
 box(art,'Continuous floor bedding',Vector3(0,-.025,0),Vector3(7.4,.05,6.4),m.stone)
 for x in range(9):
  for z in range(8):box(art,'Cut limestone floor tile',Vector3(-3.24+x*.81,.007,-2.8+z*.8),Vector3(.79,.014,.78),m.stone2 if (x+z)%4==0 else m.stone)
 box(art,'Rear cream plaster',Vector3(0,1.95,-3.1),Vector3(7.4,3.9,.2),m.plaster)
 for side in [-1,1]:
  box(art,'Side cream plaster',Vector3(side*3.6,1.95,0),Vector3(.2,3.9,6.4),m.plaster)
  box(art,'Front wing plaster',Vector3(side*2.6,1.3,3.1),Vector3(1.8,2.6,.2),m.plaster)
  # Individually coursed dressed front stone, not a flat cream slab.
  for row in range(3):
   for col in range(3):
    box(art,'Front dressed stone block',Vector3(side*2.6+(col-1)*.57,.14+row*.27,3.23),Vector3(.55,.25,.24),m.stone2 if (row+col)%3==0 else m.stone)
  for row in range(2):
   for z in range(10):box(art,'Side footing stone',Vector3(side*3.72,.14+row*.27,-2.75+z*.60),Vector3(.20,.25,.57),m.stone)
 for x in [-3.48,-1.72,1.72,3.48]:
  box(art,'Front timber upright',Vector3(x,2.05,3.17),Vector3(.30 if absf(x)>3 else .20,3.7,.28 if absf(x)>3 else .22),m.wood)
  for y in [.36,2.85,3.78]:
   box(art,'Bronze post collar',Vector3(x,y,3.18),Vector3(.36 if absf(x)>3 else .25,.12,.34 if absf(x)>3 else .27),m.bronze)
   for dx in [-.075,.075]:sphere(art,'Collar round rivet',Vector3(x+dx,y,3.37 if absf(x)>3 else 3.33),Vector3(.035,.035,.02),m.edge)
  if absf(x)>3:beam(art,'Angled timber knee',Vector3(x,2.85,3.16),Vector3(x-signf(x)*.6,3.8,3.16),.12,m.wood)
 for x in [-3.48,3.48]:
  box(art,'Rear timber upright',Vector3(x,1.95,-2.98),Vector3(.20,3.9,.20),m.wood)
  box(art,'Side roof ledger',Vector3(x,3.84,0),Vector3(.20,.14,6.3),m.wood)
 for z in [-3.1,3.1]:box(art,'Roof crossbeam',Vector3(0,3.87,z),Vector3(7.35,.18,.20),m.wood)
 box(art,'Dark timber roof soffit',Vector3(0,3.97,0),Vector3(7.8,.14,5.8),m.wood)
 # Visual-only reference refinement: draped cloth remains inside the accepted C envelope.
 # Shorter soffit reveals the cloth's front silhouette without changing roof collision.
 var faces=[]
 for ix in range(20):
  for iz in range(10):
   var quad=[]
   for ij in [Vector2(ix,iz),Vector2(ix+1,iz),Vector2(ix+1,iz+1),Vector2(ix,iz+1)]:
    var u=ij.x/20;var v=ij.y/10;quad.append(Vector3((u-.5)*7.85,4.45-.13*v-.24*sin(u*PI)+.018*sin(v*TAU*3.0)*sin(u*PI),(v-.5)*6.85))
   for k in [0,2,1,0,3,2]:faces.append(quad[k])
 mesh_from(art,'Cream stretched canopy',faces,m.cloth)
 var drape=[];var hem=[]
 for i in range(24):
  var x0=-3.925+i*7.85/24;var x1=x0+7.85/24
  var y0=4.32-.24*sin(float(i)/24*PI);var y1=4.32-.24*sin(float(i+1)/24*PI)
  var a=Vector3(x0,y0,3.43);var b=Vector3(x1,y1,3.43);var c=b-Vector3(0,.27,0);var d=a-Vector3(0,.27,0)
  drape.append_array([a,c,b,a,d,c])
  hem.append_array([d,c-Vector3(0,.035,0),c,d,d-Vector3(0,.035,0),c-Vector3(0,.035,0)])
 mesh_from(art,'Hanging cream fabric drape',drape,m.cloth)
 mesh_from(art,'Soft draped rust hem',hem,m.rust)
 for x in [-3.8,3.8]:
  var sag=.24*sin((x/7.85+.5)*PI)
  beam(art,'Canopy bronze stay',Vector3(x,4.45-sag,-3.425),Vector3(x,4.32-sag,3.425),.045,m.bronze)
  box(art,'Canopy corner pin',Vector3(x,4.10,3.425),Vector3(.065,.55,.065),m.bronze)
 # Wide physical sign is part of the storefront, never camera-facing floating text.
 box(art,'Sign carved timber backing',Vector3(0,3.42,3.32),Vector3(6.50,.64,.14),m.dark)
 for y in [3.12,3.72]:box(art,'Sign bronze long border',Vector3(0,y,3.41),Vector3(6.54,.045,.045),m.bronze)
 for x in [-3.25,3.25]:box(art,'Sign bronze short border',Vector3(x,3.42,3.41),Vector3(.045,.62,.045),m.bronze)
 label(art,'Physical shop lettering',"ROOK'S SUPPLIES",Vector3(.35,3.43,3.405),64,.0050,Color('#f2e3bf'))
 parcel(art,Vector3(-2.70,3.42,3.43),.62,m.stone2)
 for side in [-1,1]:
  banner(art,Vector3(side*2.65,2.75,3.34),m.rust if side<0 else m.teal,m.bronze)
  lantern(art,Vector3(side*1.92,2.50,3.29),m,.8)
 # Rear transaction counter remains exactly within accepted solid; grained timber panels.
 box(art,'Counter wood carcass',Vector3(0,.55,-1.5),Vector3(4,1.1,.8),m.wood)
 box(art,'Counter dressed stone top',Vector3(0,1.11,-1.5),Vector3(4.08,.08,.88),m.stone2)
 for x in range(15):box(art,'Counter vertical timber slat',Vector3(-1.86+x*.265,.55,-1.085),Vector3(.24,.93,.04),m.wood if x%3 else m.dark)
 for y in [.15,.98]:box(art,'Counter bronze band',Vector3(0,y,-1.05),Vector3(3.95,.055,.035),m.bronze)
 parcel(art,Vector3(0,.60,-1.02),.6,m.bronze)
 box(art,'Counter ledger',Vector3(-1.25,1.18,-1.45),Vector3(.44,.07,.34),m.teal)
 for i in range(3):box(art,'Basic timber sample',Vector3(.8+i*.18,1.20,-1.4),Vector3(.14,.12,.23),m.wood)
 # Mineral specimen grid on visitor's RIGHT: custom clustered facets, no stock counts/UI.
 var display=Node3D.new();display.name='Mineral specimen wall';art.add_child(display);display.position=Vector3(3.15,0,-.25);display.rotation.y=-PI/2
 box(display,'Specimen dark backing',Vector3(0,1.75,-.06),Vector3(4.4,2.72,.10),m.dark)
 var mineral_colors=['#b8964b','#6c9e9e','#9586af','#b6b6aa','#bd6d46','#779b73','#547f9b','#c7a66b','#a17c9b','#7f939b','#ad774f','#75876b','#b7a6bf','#9ba8a5','#bca879']
 for row in range(3):
  for col in range(5):
   var x=-1.76+col*.88;var y=.62+row*.82
   box(display,'Mineral shelf',Vector3(x,y-.10,.10),Vector3(.83,.07,.38),m.wood)
   box(display,'Specimen label holder',Vector3(x,y-.12,.31),Vector3(.24,.08,.025),m.bronze)
   var stone=mat(mineral_colors[row*5+col],.22,.52)
   for j in range(3):crystal(display,Vector3(x+(j-1)*.14,y-.05,.13),.11,.28+.11*((col+row+j)%3),stone,(j-1)*.22)
 for col in range(6):box(display,'Mineral grid upright',Vector3(-2.2+col*.88,1.7,.12),Vector3(.055,2.58,.39),m.bronze)
 for row in range(4):box(display,'Mineral grid horizontal',Vector3(0,.49+row*.82,.13),Vector3(4.4,.045,.39),m.bronze)
 label(display,'Specimen wall title','MINERAL SPECIMENS',Vector3(0,3.15,.12),36,.0045,Color('#f1dfb9'))
 for col in range(5):
  var x=-1.76+col*.88
  box(display,'Lower specimen storage case',Vector3(x,.20,.10),Vector3(.76,.35,.36),m.wood)
  for dx in [-.27,.27]:box(display,'Storage case bronze strap',Vector3(x+dx,.20,.30),Vector3(.035,.33,.025),m.bronze)
  box(display,'Storage case latch',Vector3(x,.26,.32),Vector3(.08,.09,.035),m.bronze)
 # Exact three tool types on opposite wall; genuine designed silhouettes, not generic shovel.
 var tools=Node3D.new();tools.name='Approved gathering tool displays';art.add_child(tools);tools.position=Vector3(-3.15,0,-.1);tools.rotation.y=PI/2
 box(tools,'Tool rack timber backing',Vector3(0,1.7,-.08),Vector3(4.2,2.6,.12),m.wood)
 for x in [-1.35,0,1.35]:
  box(tools,'Tool rack bronze support',Vector3(x,1.60,.02),Vector3(.04,2.25,.04),m.bronze)
 var kinds=['Mining pick','Woodcutting axe','Harvest sickle']
 for i in range(3):
  var t=preload('res://scripts/rook_reference_tools.gd').make(tools,kinds[i],load('res://scripts/rook_shop_art.gd'),m);t.position=Vector3(-1.10+i*1.35,.72,.12)
  label(tools,'Tool type caption',kinds[i].to_upper(),Vector3(-1.35+i*1.35,.48,.12),24,.0027,Color('#eadabc'))
 label(tools,'Gathering wall title','GATHERING TOOLS',Vector3(0,3.15,.10),36,.0045,Color('#f1dfb9'))
 # Neutral staff mannequin remains explicitly placeholder; no approved named face invented.
 pass # Coverage adapter: Neutral mannequin head replaced by skinned staff.
 pass # Coverage adapter: Neutral work apron replaced by skinned staff.
 pass # Coverage adapter: old mannequin arms replaced by skinned staff.
 banner(art,Vector3(1.2,3.15,-2.94),m.teal,m.bronze)
 var rear=Node3D.new();rear.name='Rear practical';art.add_child(rear);rear.position=Vector3(0,2.85,-2.85);lantern(rear,Vector3.ZERO,m,1.6)
 # Small woven runner anchors the straight clear aisle, no collider / gameplay effect.
 box(art,'Woven teal runner',Vector3(0,.025,.85),Vector3(2.3,.018,2.7),m.teal)
 for x in [-1.10,1.10]:box(art,'Runner bronze colored edge',Vector3(x,.036,.85),Vector3(.055,.004,2.65),m.cloth)
 for z in [-.44,2.14]:box(art,'Runner end weave',Vector3(0,.037,z),Vector3(2.2,.004,.055),m.cloth)
 # Front stone planters/vines stay beside rather than inside the accepted aisle.
 for side in [-1,1]:
  box(art,'Front stone planter',Vector3(side*2.8,.33,3.12),Vector3(.78,.58,.58),m.stone)
  box(art,'Planter dressed lip',Vector3(side*2.8,.64,3.12),Vector3(.84,.10,.64),m.stone2)
  for i in range(8):foliage(art,Vector3(side*2.8+(i%3-1)*.18,.68+(i%2)*.05,3.37),.36+.025*(i%4),m.leaf,m.flower,i)
  # Dense corner cascades, not leaves across the sign or usable entrance.
  for i in range(24):
   var row=i/3;var lane=i%3-1
   foliage(art,Vector3(side*(3.39+lane*.12),3.99-row*.18,3.30+.025*(i%2)),.25+.035*(i%3),m.leaf,m.flower,0 if i%6==0 else i*3+1)
  for i in range(10):
   foliage(art,Vector3(side*(3.37-i*.115),4.25,2.88+.14*(i%2)),.23+.025*(i%3),m.leaf,m.flower,i*3+1)
 # Budget metadata and explicit non-gameplay status; no extra collision/state changes.
 var meshes=art.find_children('*','MeshInstance3D',true,false);var triangles=0
 for mesh in meshes:triangles+=mesh.mesh.get_faces().size()/3
 art.set_meta('art_budget',{'meshes':meshes.size(),'triangles':triangles,'new_collision':0,'new_gameplay':false,'named_npc_likeness':false})
 assert(art.find_children('*','CollisionObject3D',true,false).is_empty())
 preload('res://scripts/rook_stock_finish.gd').apply(art,m,load('res://scripts/rook_shop_art.gd'))
 preload('res://scripts/market_review_finish.gd').rook(art,load('res://scripts/rook_shop_art.gd'),m)
 batch_static(art)
 material_detail.finish(art,m,load('res://scripts/rook_shop_art.gd'))
 return art

# Opt-in loading successor scheduling. Original synchronous APIs above remain unchanged.
static func add_to_staged(scene:Node3D):
 var startup_owner:Node=scene
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 9"):return null
 var original=scene.get_node('EastTraderFrontage')
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 10"):return null
 for mesh in original.get_children():
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 11"):return null
  if mesh is MeshInstance3D and mesh.name!='Rook connector':mesh.visible=false
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 12"):return null
 var old_label=scene.get_node_or_null('EastServiceLabel')
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 13"):return null
 if old_label:
  old_label.visible=false;old_label.set_meta("hide_service_caption",true)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 14"):return null
 var art=Node3D.new();art.name='RookReferenceArt';scene.add_child(art);art.position=Vector3(30,0,33);art.rotation.y=PI
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 15"):return null
 var m={'stone':mat('#bcaf97'),'stone2':mat('#d3c3a6'),'plaster':mat('#cec5ae'),'wood':mat('#684b34'),'dark':mat('#302d27'),'bronze':mat('#aa8043',.60,.60),'edge':mat('#b8b5a5',.65,.46),'cloth':mat('#ded0ae'),'rust':mat('#aa6640'),'teal':mat('#426964'),'wrap':mat('#b9aa8d'),'blade':mat('#363b3e',.62,.66),'cyan':mat('#57b4b6',.35,.45),'glow':mat('#ffcf7e'),'leaf':mat('#51764c'),'flower':mat('#9561a2')}
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 16"):return null
 var timber=ShaderMaterial.new();timber.shader=preload('res://assets/materials/architecture_surface.gdshader');timber.set_shader_parameter('kind',1);timber.set_shader_parameter('tint',Color('#73543a'));timber.set_shader_parameter('roughness',.82);m.wood=timber
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 17"):return null
 m.cloth.cull_mode=BaseMaterial3D.CULL_DISABLED;m.rust.cull_mode=BaseMaterial3D.CULL_DISABLED;m.leaf.cull_mode=BaseMaterial3D.CULL_DISABLED
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 18"):return null
 m.glow.emission_enabled=true;m.glow.emission=Color('#ffb951');m.glow.emission_energy_multiplier=.65
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 19"):return null
 m.cyan.emission_enabled=true;m.cyan.emission=Color('#45aeb2');m.cyan.emission_energy_multiplier=.28
 var material_detail=preload('res://scripts/rook_material_detail.gd').configure(art,m)
 # Floor masonry and warm plaster retain the complete accepted physical envelope.
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 20"):return null
 box(art,'Continuous floor bedding',Vector3(0,-.025,0),Vector3(7.4,.05,6.4),m.stone)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 21"):return null
 for x in range(9):
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 22"):return null
  for z in range(8):
   if startup_owner != null:
    if await startup_owner._startup_checkpoint("Rook loop 23"):return null
   box(art,'Cut limestone floor tile',Vector3(-3.24+x*.81,.007,-2.8+z*.8),Vector3(.79,.014,.78),m.stone2 if (x+z)%4==0 else m.stone)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 24"):return null
 box(art,'Rear cream plaster',Vector3(0,1.95,-3.1),Vector3(7.4,3.9,.2),m.plaster)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 25"):return null
 for side in [-1,1]:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 26"):return null
  box(art,'Side cream plaster',Vector3(side*3.6,1.95,0),Vector3(.2,3.9,6.4),m.plaster)
  box(art,'Front wing plaster',Vector3(side*2.6,1.3,3.1),Vector3(1.8,2.6,.2),m.plaster)
  # Individually coursed dressed front stone, not a flat cream slab.
  for row in range(3):
   if startup_owner != null:
    if await startup_owner._startup_checkpoint("Rook loop 27"):return null
   for col in range(3):
    if startup_owner != null:
     if await startup_owner._startup_checkpoint("Rook loop 28"):return null
    box(art,'Front dressed stone block',Vector3(side*2.6+(col-1)*.57,.14+row*.27,3.23),Vector3(.55,.25,.24),m.stone2 if (row+col)%3==0 else m.stone)
  for row in range(2):
   if startup_owner != null:
    if await startup_owner._startup_checkpoint("Rook loop 29"):return null
   for z in range(10):
    if startup_owner != null:
     if await startup_owner._startup_checkpoint("Rook loop 30"):return null
    box(art,'Side footing stone',Vector3(side*3.72,.14+row*.27,-2.75+z*.60),Vector3(.20,.25,.57),m.stone)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 31"):return null
 for x in [-3.48,-1.72,1.72,3.48]:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 32"):return null
  box(art,'Front timber upright',Vector3(x,2.05,3.17),Vector3(.30 if absf(x)>3 else .20,3.7,.28 if absf(x)>3 else .22),m.wood)
  for y in [.36,2.85,3.78]:
   if startup_owner != null:
    if await startup_owner._startup_checkpoint("Rook loop 33"):return null
   box(art,'Bronze post collar',Vector3(x,y,3.18),Vector3(.36 if absf(x)>3 else .25,.12,.34 if absf(x)>3 else .27),m.bronze)
   for dx in [-.075,.075]:
    if startup_owner != null:
     if await startup_owner._startup_checkpoint("Rook loop 34"):return null
    sphere(art,'Collar round rivet',Vector3(x+dx,y,3.37 if absf(x)>3 else 3.33),Vector3(.035,.035,.02),m.edge)
  if absf(x)>3:beam(art,'Angled timber knee',Vector3(x,2.85,3.16),Vector3(x-signf(x)*.6,3.8,3.16),.12,m.wood)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 35"):return null
 for x in [-3.48,3.48]:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 36"):return null
  box(art,'Rear timber upright',Vector3(x,1.95,-2.98),Vector3(.20,3.9,.20),m.wood)
  box(art,'Side roof ledger',Vector3(x,3.84,0),Vector3(.20,.14,6.3),m.wood)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 37"):return null
 for z in [-3.1,3.1]:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 38"):return null
  box(art,'Roof crossbeam',Vector3(0,3.87,z),Vector3(7.35,.18,.20),m.wood)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 39"):return null
 box(art,'Dark timber roof soffit',Vector3(0,3.97,0),Vector3(7.8,.14,5.8),m.wood)
 # Visual-only reference refinement: draped cloth remains inside the accepted C envelope.
 # Shorter soffit reveals the cloth's front silhouette without changing roof collision.
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 40"):return null
 var faces=[]
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 41"):return null
 for ix in range(20):
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 42"):return null
  for iz in range(10):
   if startup_owner != null:
    if await startup_owner._startup_checkpoint("Rook loop 43"):return null
   var quad=[]
   for ij in [Vector2(ix,iz),Vector2(ix+1,iz),Vector2(ix+1,iz+1),Vector2(ix,iz+1)]:
    if startup_owner != null:
     if await startup_owner._startup_checkpoint("Rook loop 44"):return null
    var u=ij.x/20;var v=ij.y/10;quad.append(Vector3((u-.5)*7.85,4.45-.13*v-.24*sin(u*PI)+.018*sin(v*TAU*3.0)*sin(u*PI),(v-.5)*6.85))
   for k in [0,2,1,0,3,2]:
    if startup_owner != null:
     if await startup_owner._startup_checkpoint("Rook loop 45"):return null
    faces.append(quad[k])
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 46"):return null
 mesh_from(art,'Cream stretched canopy',faces,m.cloth)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 47"):return null
 var drape=[];var hem=[]
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 48"):return null
 for i in range(24):
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 49"):return null
  var x0=-3.925+i*7.85/24;var x1=x0+7.85/24
  var y0=4.32-.24*sin(float(i)/24*PI);var y1=4.32-.24*sin(float(i+1)/24*PI)
  var a=Vector3(x0,y0,3.43);var b=Vector3(x1,y1,3.43);var c=b-Vector3(0,.27,0);var d=a-Vector3(0,.27,0)
  drape.append_array([a,c,b,a,d,c])
  hem.append_array([d,c-Vector3(0,.035,0),c,d,d-Vector3(0,.035,0),c-Vector3(0,.035,0)])
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 50"):return null
 mesh_from(art,'Hanging cream fabric drape',drape,m.cloth)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 51"):return null
 mesh_from(art,'Soft draped rust hem',hem,m.rust)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 52"):return null
 for x in [-3.8,3.8]:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 53"):return null
  var sag=.24*sin((x/7.85+.5)*PI)
  beam(art,'Canopy bronze stay',Vector3(x,4.45-sag,-3.425),Vector3(x,4.32-sag,3.425),.045,m.bronze)
  box(art,'Canopy corner pin',Vector3(x,4.10,3.425),Vector3(.065,.55,.065),m.bronze)
 # Wide physical sign is part of the storefront, never camera-facing floating text.
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 54"):return null
 box(art,'Sign carved timber backing',Vector3(0,3.42,3.32),Vector3(6.50,.64,.14),m.dark)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 55"):return null
 for y in [3.12,3.72]:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 56"):return null
  box(art,'Sign bronze long border',Vector3(0,y,3.41),Vector3(6.54,.045,.045),m.bronze)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 57"):return null
 for x in [-3.25,3.25]:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 58"):return null
  box(art,'Sign bronze short border',Vector3(x,3.42,3.41),Vector3(.045,.62,.045),m.bronze)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 59"):return null
 label(art,'Physical shop lettering',"ROOK'S SUPPLIES",Vector3(.35,3.43,3.405),64,.0050,Color('#f2e3bf'))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 60"):return null
 parcel(art,Vector3(-2.70,3.42,3.43),.62,m.stone2)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 61"):return null
 for side in [-1,1]:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 62"):return null
  banner(art,Vector3(side*2.65,2.75,3.34),m.rust if side<0 else m.teal,m.bronze)
  lantern(art,Vector3(side*1.92,2.50,3.29),m,.8)
 # Rear transaction counter remains exactly within accepted solid; grained timber panels.
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 63"):return null
 box(art,'Counter wood carcass',Vector3(0,.55,-1.5),Vector3(4,1.1,.8),m.wood)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 64"):return null
 box(art,'Counter dressed stone top',Vector3(0,1.11,-1.5),Vector3(4.08,.08,.88),m.stone2)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 65"):return null
 for x in range(15):
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 66"):return null
  box(art,'Counter vertical timber slat',Vector3(-1.86+x*.265,.55,-1.085),Vector3(.24,.93,.04),m.wood if x%3 else m.dark)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 67"):return null
 for y in [.15,.98]:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 68"):return null
  box(art,'Counter bronze band',Vector3(0,y,-1.05),Vector3(3.95,.055,.035),m.bronze)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 69"):return null
 parcel(art,Vector3(0,.60,-1.02),.6,m.bronze)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 70"):return null
 box(art,'Counter ledger',Vector3(-1.25,1.18,-1.45),Vector3(.44,.07,.34),m.teal)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 71"):return null
 for i in range(3):
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 72"):return null
  box(art,'Basic timber sample',Vector3(.8+i*.18,1.20,-1.4),Vector3(.14,.12,.23),m.wood)
 # Mineral specimen grid on visitor's RIGHT: custom clustered facets, no stock counts/UI.
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 73"):return null
 var display=Node3D.new();display.name='Mineral specimen wall';art.add_child(display);display.position=Vector3(3.15,0,-.25);display.rotation.y=-PI/2
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 74"):return null
 box(display,'Specimen dark backing',Vector3(0,1.75,-.06),Vector3(4.4,2.72,.10),m.dark)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 75"):return null
 var mineral_colors=['#b8964b','#6c9e9e','#9586af','#b6b6aa','#bd6d46','#779b73','#547f9b','#c7a66b','#a17c9b','#7f939b','#ad774f','#75876b','#b7a6bf','#9ba8a5','#bca879']
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 76"):return null
 for row in range(3):
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 77"):return null
  for col in range(5):
   if startup_owner != null:
    if await startup_owner._startup_checkpoint("Rook loop 78"):return null
   var x=-1.76+col*.88;var y=.62+row*.82
   box(display,'Mineral shelf',Vector3(x,y-.10,.10),Vector3(.83,.07,.38),m.wood)
   box(display,'Specimen label holder',Vector3(x,y-.12,.31),Vector3(.24,.08,.025),m.bronze)
   var stone=mat(mineral_colors[row*5+col],.22,.52)
   for j in range(3):
    if startup_owner != null:
     if await startup_owner._startup_checkpoint("Rook loop 79"):return null
    crystal(display,Vector3(x+(j-1)*.14,y-.05,.13),.11,.28+.11*((col+row+j)%3),stone,(j-1)*.22)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 80"):return null
 for col in range(6):
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 81"):return null
  box(display,'Mineral grid upright',Vector3(-2.2+col*.88,1.7,.12),Vector3(.055,2.58,.39),m.bronze)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 82"):return null
 for row in range(4):
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 83"):return null
  box(display,'Mineral grid horizontal',Vector3(0,.49+row*.82,.13),Vector3(4.4,.045,.39),m.bronze)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 84"):return null
 label(display,'Specimen wall title','MINERAL SPECIMENS',Vector3(0,3.15,.12),36,.0045,Color('#f1dfb9'))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 85"):return null
 for col in range(5):
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 86"):return null
  var x=-1.76+col*.88
  box(display,'Lower specimen storage case',Vector3(x,.20,.10),Vector3(.76,.35,.36),m.wood)
  for dx in [-.27,.27]:
   if startup_owner != null:
    if await startup_owner._startup_checkpoint("Rook loop 87"):return null
   box(display,'Storage case bronze strap',Vector3(x+dx,.20,.30),Vector3(.035,.33,.025),m.bronze)
  box(display,'Storage case latch',Vector3(x,.26,.32),Vector3(.08,.09,.035),m.bronze)
 # Exact three tool types on opposite wall; genuine designed silhouettes, not generic shovel.
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 88"):return null
 var tools=Node3D.new();tools.name='Approved gathering tool displays';art.add_child(tools);tools.position=Vector3(-3.15,0,-.1);tools.rotation.y=PI/2
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 89"):return null
 box(tools,'Tool rack timber backing',Vector3(0,1.7,-.08),Vector3(4.2,2.6,.12),m.wood)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 90"):return null
 for x in [-1.35,0,1.35]:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 91"):return null
  box(tools,'Tool rack bronze support',Vector3(x,1.60,.02),Vector3(.04,2.25,.04),m.bronze)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 92"):return null
 var kinds=['Mining pick','Woodcutting axe','Harvest sickle']
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 93"):return null
 for i in range(3):
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 94"):return null
  var t=preload('res://scripts/rook_reference_tools.gd').make(tools,kinds[i],load('res://scripts/rook_shop_art.gd'),m);t.position=Vector3(-1.10+i*1.35,.72,.12)
  label(tools,'Tool type caption',kinds[i].to_upper(),Vector3(-1.35+i*1.35,.48,.12),24,.0027,Color('#eadabc'))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 95"):return null
 label(tools,'Gathering wall title','GATHERING TOOLS',Vector3(0,3.15,.10),36,.0045,Color('#f1dfb9'))
 # Neutral staff mannequin remains explicitly placeholder; no approved named face invented.
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 96"):return null
 pass # Coverage adapter: Neutral mannequin head replaced by skinned staff.
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 97"):return null
 pass # Coverage adapter: Neutral work apron replaced by skinned staff.
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 98"):return null
 for side in [-1,1]:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 99"):return null
  pass # Coverage adapter: Neutral mannequin arm replaced by skinned staff.
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 100"):return null
 banner(art,Vector3(1.2,3.15,-2.94),m.teal,m.bronze)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 101"):return null
 var rear=Node3D.new();rear.name='Rear practical';art.add_child(rear);rear.position=Vector3(0,2.85,-2.85);lantern(rear,Vector3.ZERO,m,1.6)
 # Small woven runner anchors the straight clear aisle, no collider / gameplay effect.
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 102"):return null
 box(art,'Woven teal runner',Vector3(0,.025,.85),Vector3(2.3,.018,2.7),m.teal)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 103"):return null
 for x in [-1.10,1.10]:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 104"):return null
  box(art,'Runner bronze colored edge',Vector3(x,.036,.85),Vector3(.055,.004,2.65),m.cloth)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 105"):return null
 for z in [-.44,2.14]:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 106"):return null
  box(art,'Runner end weave',Vector3(0,.037,z),Vector3(2.2,.004,.055),m.cloth)
 # Front stone planters/vines stay beside rather than inside the accepted aisle.
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 107"):return null
 for side in [-1,1]:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 108"):return null
  box(art,'Front stone planter',Vector3(side*2.8,.33,3.12),Vector3(.78,.58,.58),m.stone)
  box(art,'Planter dressed lip',Vector3(side*2.8,.64,3.12),Vector3(.84,.10,.64),m.stone2)
  for i in range(8):
   if startup_owner != null:
    if await startup_owner._startup_checkpoint("Rook loop 109"):return null
   foliage(art,Vector3(side*2.8+(i%3-1)*.18,.68+(i%2)*.05,3.37),.36+.025*(i%4),m.leaf,m.flower,i)
  # Dense corner cascades, not leaves across the sign or usable entrance.
  for i in range(24):
   if startup_owner != null:
    if await startup_owner._startup_checkpoint("Rook loop 110"):return null
   var row=i/3;var lane=i%3-1
   foliage(art,Vector3(side*(3.39+lane*.12),3.99-row*.18,3.30+.025*(i%2)),.25+.035*(i%3),m.leaf,m.flower,0 if i%6==0 else i*3+1)
  for i in range(10):
   if startup_owner != null:
    if await startup_owner._startup_checkpoint("Rook loop 111"):return null
   foliage(art,Vector3(side*(3.37-i*.115),4.25,2.88+.14*(i%2)),.23+.025*(i%3),m.leaf,m.flower,i*3+1)
 # Budget metadata and explicit non-gameplay status; no extra collision/state changes.
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 112"):return null
 var meshes=art.find_children('*','MeshInstance3D',true,false);var triangles=0
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 113"):return null
 for mesh in meshes:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 114"):return null
  triangles+=mesh.mesh.get_faces().size()/3
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 115"):return null
 art.set_meta('art_budget',{'meshes':meshes.size(),'triangles':triangles,'new_collision':0,'new_gameplay':false,'named_npc_likeness':false})
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 116"):return null
 assert(art.find_children('*','CollisionObject3D',true,false).is_empty())
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 117"):return null
 preload('res://scripts/rook_stock_finish.gd').apply(art,m,load('res://scripts/rook_shop_art.gd'))
 preload('res://scripts/market_review_finish.gd').rook(art,load('res://scripts/rook_shop_art.gd'),m)
 await _batch_static_staged(art,startup_owner)
 if startup_owner != null and startup_owner.startup_cancel_requested:return null
 material_detail.finish(art,m,load('res://scripts/rook_shop_art.gd'))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 118"):return null
 if startup_owner != null and startup_owner.startup_cancel_requested:return null
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 119"):return null
 return art

static func _batch_static_staged(root:Node3D,startup_owner:Node=null):
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 1"):return
 var groups={}
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 2"):return
 var inverse=root.global_transform.affine_inverse()
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 3"):return
 for node in root.find_children('*','MeshInstance3D',true,false):
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 4"):return
  var material=node.material_override
  var key=material.get_instance_id()
  if not groups.has(key):
   var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);groups[key]={'st':st,'material':material,'sources':[]}
  # Normalize topology before merging: mixing indexed primitives and unindexed
  # custom extrusions otherwise leaves the latter outside the active index buffer.
  for surf in range(node.mesh.get_surface_count()):
   if startup_owner != null:
    if await startup_owner._startup_checkpoint("Rook loop 5"):return
   var normalized=SurfaceTool.new();normalized.create_from(node.mesh,surf);normalized.deindex()
   groups[key].st.append_from(normalized.commit(),0,inverse*node.global_transform)
  groups[key].sources.append(str(node.get_path()));node.free()
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 6"):return
 for key in groups:
  if startup_owner != null:
   if await startup_owner._startup_checkpoint("Rook loop 7"):return
  var group=groups[key];var node=MeshInstance3D.new();node.name='Rook static material batch';node.mesh=group.st.commit();node.material_override=group.material;root.add_child(node);node.set_meta('source_meshes',group.sources)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("Rook operation 8"):return
 root.set_meta('batched_draw_surfaces',groups.size())
# Same authored geometry; only the staged entry permits budget-driven yields.
