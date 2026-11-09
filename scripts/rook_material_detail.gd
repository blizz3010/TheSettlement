extends Node3D
# Bounded trader reference detail. Rook defaults; Dan reuses the isolated controller.
# No physics, item IDs, NPC edits, route edits, scripts in gameplay state or new lights.
const SURFACE=preload('res://assets/materials/trader_detail_surface.gdshader')
const Settings=preload('res://scripts/game_settings.gd')
var quality=2
var bank=[]
var mesh_bindings=[]
var joinery:Node3D
var stock:Node3D
var complete=false

static func configure(art:Node3D,materials:Dictionary):
 var controller=load('res://scripts/rook_material_detail.gd').new()
 controller.name='MaterialDetail';art.add_child(controller)
 controller.add_to_group('material_detail_quality')
 var specs={
  'wood':[0,'#73543a',.83,0.0], 'dark':[0,'#302d27',.82,0.0],
  'stone':[1,'#bcaf97',.84,0.0], 'stone2':[5,'#d3c3a6',.62,0.0],
  'plaster':[2,'#cec5ae',.94,0.0], 'bronze':[3,'#aa8043',.55,.60],
  'edge':[3,'#b8b5a5',.44,.65], 'blade':[3,'#363b3e',.61,.62],
  'cloth':[4,'#ded0ae',.95,0.0], 'rust':[4,'#aa6640',.94,0.0],
  'teal':[4,'#426964',.93,0.0], 'wrap':[4,'#b9aa8d',.95,0.0],
  'jar_teal':[6,'#426964',.42,0.0], 'jar_rust':[6,'#aa6640',.45,0.0]
 }
 for key in specs:
  var spec=specs[key]
  var detailed=ShaderMaterial.new();detailed.shader=preload('res://assets/materials/rook_quiet_surface.gdshader') if art.name=='RookReferenceArt' else SURFACE
  detailed.set_shader_parameter('kind',spec[0]);detailed.set_shader_parameter('tint',Color(spec[1]))
  detailed.set_shader_parameter('roughness',spec[2]);detailed.set_shader_parameter('metallic',spec[3])
  var low=StandardMaterial3D.new();low.albedo_color=Color(spec[1]);low.roughness=spec[2];low.metallic=spec[3]
  if spec[0]==4:low.cull_mode=BaseMaterial3D.CULL_DISABLED
  controller.bank.append({'detail':detailed,'low':low,'key':key})
  materials[key]=detailed
 return controller

func finish(art:Node3D,m:Dictionary,build):
 # Existing art is already batched; extras remain separate so Low/Medium draw none.
 for node in art.find_children('*','MeshInstance3D',true,false):register_mesh(node)
 joinery=Node3D.new();joinery.name='HighJoinery';add_child(joinery)
 stock=Node3D.new();stock.name='MaxShopGoods';add_child(stock)
 add_joinery(joinery,m,build)
 add_shop_goods(stock,m,build)
 seal_groups(build)

func seal_groups(build):
 var totals={}
 for group in [joinery,stock]:
  var triangles=0
  for mesh in group.find_children('*','MeshInstance3D',true,false):triangles+=mesh.mesh.get_faces().size()/3
  build.batch_static(group)
  for mesh in group.find_children('*','MeshInstance3D',true,false):
   mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   mesh.visibility_range_end=32.0 if group==joinery else 22.0
   mesh.visibility_range_end_margin=3.0
   register_mesh(mesh)
  totals[str(group.name)]={'triangles':triangles,'surfaces':group.get_meta('batched_draw_surfaces')}
 assert(find_children('*','CollisionObject3D',true,false).is_empty())
 set_meta('detail_budget',{'groups':totals,'new_collisions':0,'new_lights':0,'decorative_only':true,'footprint_unchanged':true})
 complete=true
 set_quality(Settings.new().current_material_detail_quality(self))

func register_mesh(mesh:MeshInstance3D):
 for row in bank:
  if mesh.material_override==row.detail:
   mesh_bindings.append({'mesh':mesh,'row':row});return

func set_quality(value:int):
 quality=clampi(value,0,3)
 for row in bank:row.detail.set_shader_parameter('detail_quality',quality)
 for binding in mesh_bindings:
  if is_instance_valid(binding.mesh):binding.mesh.material_override=binding.row.low if quality==0 else binding.row.detail
 if is_instance_valid(joinery):joinery.visible=quality>=2
 if is_instance_valid(stock):stock.visible=quality>=3
 set_meta('effective_quality',quality)

func add_joinery(root:Node3D,m:Dictionary,b):
 # Narrow frame rebates and join plates read clearly only when close to the shop.
 for x in [-3.48,-1.72,1.72,3.48]:
  var z=3.317 if absf(x)>3 else 3.287
  for dx in [-.055,.055]:
   b.box(root,'Timber face inset',Vector3(x+dx,1.63,z),Vector3(.012,2.40,.007),m.dark)
  for y in [.36,2.85,3.78]:
   for dx in [-.075,.075]:
    b.box(root,'Forged screw slot',Vector3(x+dx,y,3.383 if absf(x)>3 else 3.343),Vector3(.019,.004,.003),m.dark)
 # Rafter rhythm and beam ends, contained beneath the existing canopy/roof.
 for z in [-2.4,-1.2,0.0,1.2,2.4]:
  b.box(root,'Visible ceiling rafter',Vector3(0,3.855,z),Vector3(6.7,.09,.11),m.wood)
  for x in [-3.25,3.25]:
   b.box(root,'Rafter brass join',Vector3(x,3.79,z),Vector3(.16,.035,.16),m.bronze)
 for side in [-1,1]:
  # A fine dressed edge on the planter plus the matching parcel identity.
  b.box(root,'Planter recessed face',Vector3(side*2.8,.36,3.415),Vector3(.65,.37,.012),m.stone2)
  b.parcel(root,Vector3(side*2.8,.36,3.429),.34,m.bronze)
  for dx in [-.34,.34]:
   for y in [.18,.57]:b.box(root,'Planter bronze corner',Vector3(side*2.8+dx,y,3.432),Vector3(.075,.06,.018),m.bronze)
 # A crisp counter lip with brass rails; no additional customer-side solid.
 b.box(root,'Counter polished nosing',Vector3(0,1.095,-1.046),Vector3(4.08,.028,.025),m.bronze)
 for x in range(15):
  var px=-1.86+x*.265
  for y in [.18,.95]:b.sphere(root,'Counter panel fixing',Vector3(px,y,-1.059),Vector3(.021,.021,.012),m.bronze)
 # Ledger leather corners and visible paper leaves remain on the existing counter.
 b.box(root,'Ledger page edges',Vector3(-1.25,1.193,-1.45),Vector3(.405,.025,.31),m.cloth)
 b.box(root,'Ledger leather cover',Vector3(-1.25,1.212,-1.45),Vector3(.44,.012,.34),m.teal)
 for x in [-1.43,-1.07]:
  for z in [-1.59,-1.31]:b.box(root,'Ledger bronze corner',Vector3(x,1.22,z),Vector3(.045,.005,.045),m.bronze)
 # Slim lattice added to the existing lanterns, with no extra lighting cost.
 for p in [Vector3(-1.92,2.50,3.29),Vector3(1.92,2.50,3.29),Vector3(0,2.85,-2.85)]:
  for dx in [-.05,.05]:
   b.box(root,'Lantern fine fret upright',p+Vector3(dx,0,.105),Vector3(.012,.29,.012),m.bronze)
  for y in [-.075,.075]:b.box(root,'Lantern fine fret cross',p+Vector3(0,y,.105),Vector3(.20,.012,.012),m.bronze)

func cylinder(root:Node3D,name:String,p:Vector3,r:float,h:float,material:Material,top=-1.0):
 var node=MeshInstance3D.new();node.name=name;node.position=p
 var mesh=CylinderMesh.new();mesh.bottom_radius=r;mesh.top_radius=r if top<0 else top;mesh.height=h;mesh.radial_segments=12;mesh.rings=1
 node.mesh=mesh;node.material_override=material;root.add_child(node);return node

func add_shop_goods(root:Node3D,m:Dictionary,b):
 # Small rear-wall stock flanks the staff. It never enters the clear center aisle.
 for side in [-1,1]:
  var x=side*2.36
  for y in [1.50,2.15]:
   b.box(root,'Rear goods shelf',Vector3(x,y,-2.78),Vector3(1.25,.075,.34),m.wood)
   for dx in [-.46,.46]:
    b.box(root,'Shelf bronze bracket',Vector3(x+dx,y-.15,-2.88),Vector3(.035,.30,.035),m.bronze)
    b.beam(root,'Shelf angled bracket',Vector3(x+dx,y-.27,-2.88),Vector3(x+dx,y-.06,-2.64),.025,m.bronze)
   # Max adds useful tied offcuts instead of generic glazed jars.
   for i in range(3):
    var px=x-.35+i*.35
    b.box(root,'Small bound supply offcut',Vector3(px,y+.14,-2.75),Vector3(.25,.18,.25),m.wood if side<0 else m.blade)
    b.box(root,'Offcut retaining band',Vector3(px,y+.235,-2.75),Vector3(.03,.012,.25),m.bronze)
 # Neatly tied supply parcels live only on the counter's far end.
 for i in range(3):
  var p=Vector3(1.56,1.18+i*.115,-1.60)
  b.box(root,'Wrapped material parcel',p,Vector3(.29,.10,.24),m.wrap)
  b.box(root,'Parcel cross tie',p+Vector3(0,.052,0),Vector3(.018,.005,.24),m.bronze)
  b.box(root,'Parcel length tie',p+Vector3(0,.053,0),Vector3(.29,.005,.018),m.bronze)
 # Two essential work plans now live in RookStockIdentity on every tier.
 # Add modest tool hangers and small storage pulls, retaining all original tools.
 for x in [-3.15,3.15]:
  for z in [-1.45,-.10,1.25]:
   b.box(root,'Wall display iron peg',Vector3(x,2.53,z),Vector3(.20,.025,.025),m.blade)
