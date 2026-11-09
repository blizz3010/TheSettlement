extends RefCounted
# Dan-only reference detail, installed before the general market batching pass.
# Base visual meshes are rebatched without moving their collision parents.
const Controller=preload('res://scripts/rook_material_detail.gd')
const Builder=preload('res://scripts/rook_shop_art.gd')
static func apply(shop:Node3D):
 assert(not shop.has_node('MaterialDetail'))
 var materials={}
 var controller=Controller.configure(shop,materials)
 # Match Dan's accepted darker sign/timber rather than copying Rook's palette.
 for row in controller.bank:
  if row.key=='wood':
   row.detail.set_shader_parameter('tint',Color('#685039'));row.low.albedo_color=Color('#685039')
  elif row.key=='dark':
   row.detail.set_shader_parameter('tint',Color('#293e3a'));row.low.albedo_color=Color('#293e3a')
 # Keep the corrected ochre canopy and pale metal fasteners in their accepted hues.
 for spec in [['canopy','cloth','#b49b6c',.94,0.0],['lettering_metal','bronze','#ecddae',.65,.25]]:
  for row in controller.bank.duplicate():
   if row.key!=spec[1]:continue
   var detail=row.detail.duplicate();var low=row.low.duplicate()
   detail.set_shader_parameter('tint',Color(spec[2]));detail.set_shader_parameter('roughness',spec[3]);detail.set_shader_parameter('metallic',spec[4])
   low.albedo_color=Color(spec[2]);low.roughness=spec[3];low.metallic=spec[4]
   controller.bank.append({'detail':detail,'low':low,'key':spec[0]});materials[spec[0]]=detail
 var visual=Node3D.new();visual.name='DanMaterialSurfaces';shop.add_child(visual)
 var count=0
 for mesh in shop.find_children('*','MeshInstance3D',true,false):
  if not mesh.material_override:continue # Imported multi-material offerings remain intact.
  var path=str(shop.get_path_to(mesh)).to_lower()
  if 'customer stone apron' in path or 'limestone plinth' in path:continue # Shared path authority untouched.
  var kind=material_kind(path,mesh.material_override)
  if kind.is_empty():continue
  # Do not reclassify dark cubby openings as wood, or alter lettering/ink.
  if 'open face' in path or 'ink rule' in path or 'handwritten' in path:continue
  if mesh.mesh is BoxMesh:
   var size=mesh.mesh.size;var arrays=mesh.mesh.surface_get_arrays(0)
   var colors=PackedColorArray();var color=Color(0,0,0,1);color[size.max_axis_index()]=1.0
   colors.resize(arrays[Mesh.ARRAY_VERTEX].size());colors.fill(color);arrays[Mesh.ARRAY_COLOR]=colors
   var prepared=ArrayMesh.new();prepared.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.mesh=prepared
  mesh.material_override=materials[kind]
  mesh.reparent(visual,true);count+=1
 Builder.batch_static(visual)
 for mesh in visual.find_children('*','MeshInstance3D',true,false):controller.register_mesh(mesh)
 controller.joinery=Node3D.new();controller.joinery.name='HighJoinery';controller.add_child(controller.joinery)
 controller.stock=Node3D.new();controller.stock.name='MaxShopGoods';controller.add_child(controller.stock)
 joinery(controller.joinery,materials)
 goods(controller,controller.stock,materials)
 controller.seal_groups(Builder)
 controller.set_meta('dan_base_meshes_refined',count)
 controller.set_meta('role','Dan')
 return controller

static func material_kind(path:String,source:Material)->String:
 # Specific metal parts win over words such as cloth/timber in a component name.
 if 'timber binding rivet' in path:return 'lettering_metal'
 if 'cloth stay' in path or 'cubby upright' in path:return 'bronze'
 if 'bronze' in path or 'brass' in path or 'collar' in path or 'binding' in path or 'mounting strap' in path:return 'bronze'
 if 'ochre market cloth awning' in path:return 'canopy'
 if 'cloth' in path or 'canvas' in path:return 'cloth'
 if 'cubby ledger spine' in path:return 'cloth' if source is StandardMaterial3D else 'wood'
 if 'timber' in path or 'wood' in path or 'counter case' in path or 'cubby' in path or 'roof' in path:return 'wood'
 if 'limestone counter' in path or 'stone pier' in path:return 'stone2'
 if 'cream' in path or 'plaster' in path or 'mineral' in path:return 'plaster'
 if 'listing card' in path or 'pinned varied listing' in path or 'ledger' in path:return 'cloth'
 return ''

static func joinery(root:Node3D,m:Dictionary):
 # Counter planks and existing post collars receive small fasteners and narrow rebates.
 for x in [-4.75,4.75]:
  for dx in [-.044,.044]:Builder.box(root,'Post face rebate',Vector3(x+dx,1.90,2.906),Vector3(.009,2.64,.006),m.dark)
  for y in [.45,3.45]:
   for dx in [-.07,.07]:
    Builder.box(root,'Collar square nail',Vector3(x+dx,y,2.941),Vector3(.031,.027,.012),m.bronze)
    Builder.box(root,'Collar nail slot',Vector3(x+dx,y,2.948),Vector3(.018,.004,.002),m.dark)
 for i in range(25):
  var x=-4.35+i*.35
  for y in [.24,1.00]:Builder.box(root,'Counter slat nail',Vector3(x,y,2.665),Vector3(.025,.025,.012),m.bronze)
 Builder.box(root,'Polished counter front edge',Vector3(0,1.19,2.708),Vector3(8.95,.027,.025),m.bronze)
 # Shelf edge strips and small join brackets stay within the existing cubbies.
 for side in [-1,1]:
  var x=side*3.4
  for y in [.70,1.40,2.10]:
   Builder.box(root,'Cubby fine front edge',Vector3(x,y+.255,-2.207),Vector3(1.0,.025,.018),m.bronze)
   for dx in [-.4,.4]:Builder.box(root,'Cubby join bracket',Vector3(x+dx,y+.20,-2.20),Vector3(.08,.10,.022),m.bronze)

static func goods(c,root:Node3D,m:Dictionary):
 # Market goods only; textiles/notions now belong to TailorAtelier.
 for side in [-1,1]:
  var x=side*3.4
  # Closed, tied consignment parcels are decorative, never stock or prices.
  for i in range(2):
   var p=Vector3(x,1.09+i*.17,-2.56)
   Builder.box(root,'Tied consignment parcel',p,Vector3(.62,.14,.42),m.wrap)
   Builder.box(root,'Parcel cross ribbon',p+Vector3(0,.072,0),Vector3(.035,.008,.42),m.bronze)
   Builder.box(root,'Parcel length ribbon',p+Vector3(0,.073,0),Vector3(.62,.008,.035),m.bronze)
 # Number plates distinguish the existing parcel cubbies at Max detail.
 for side in [-1,1]:
  for i in range(3):
   var p=Vector3(side*3.4,2.67-i*.7,-2.20)
   Builder.box(root,'Consignment cubby number plaque',p,Vector3(.23,.12,.014),m.dark)
