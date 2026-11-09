extends RefCounted
# Psy/Atlas presentation only. Existing holders, collision, roofs, counters and routes stay exact.
const Controller=preload('res://scripts/rook_material_detail.gd')
const Builder=preload('res://scripts/rook_shop_art.gd')
const Architecture=preload('res://scripts/architecture_materials.gd')
const Envelope=preload('res://scripts/trader_side_envelope_finish.gd')

static func kind_for(path:String,source:Material)->int:
 # Material identity also covers Godot's anonymous duplicate names. Child-owner exclusions
 # retain imported goods, signs, gardens and practicals instead of guessing their roles.
 for excluded in ['offeringdetail/','authoredphysicaltradersign/','localmarketsurroundings/','supported market lantern','customer stone apron','limestone plinth','rust red outfitter roof','teal recovery utility canopy']:
  if excluded in path:return -1
 if source is ShaderMaterial:
  var shader_path=source.shader.resource_path
  if shader_path in ['res://assets/materials/market_wall_timber.gdshader','res://assets/materials/architecture_surface.gdshader']:return 0
  if shader_path=='res://assets/materials/courtyard_surface.gdshader':return 3 if float(source.get_shader_parameter('metallic'))>.1 else 1
 if source is StandardMaterial3D:
  if source.albedo_color.is_equal_approx(Color('#c9bc98')):return 2
  if source.albedo_color.is_equal_approx(Color('#637465')) or source.albedo_color.is_equal_approx(Color('#317c79')) or source.albedo_color.is_equal_approx(Color('#293e3a')):return 3
 return -1

static func grain_mesh(source:Mesh)->ArrayMesh:
 # Existing Psy sideboards are ArrayMeshes without a surface material. Prepare all
 # disconnected members explicitly, rather than relying on imported-material names.
 var prepared=ArrayMesh.new()
 for index in range(source.get_surface_count()):
  var arrays=source.surface_get_arrays(index)
  var unindexed=arrays[Mesh.ARRAY_INDEX]==null
  if unindexed:arrays[Mesh.ARRAY_INDEX]=PackedInt32Array()
  arrays[Mesh.ARRAY_COLOR]=Architecture.axis_colors(arrays)
  if unindexed:arrays[Mesh.ARRAY_INDEX]=null
  prepared.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return prepared

static func surface(controller,source:Material,kind:int)->Material:
 var key='source_'+str(source.get_instance_id())+'_'+str(kind)
 for row in controller.bank:
  if row.key==key:return row.detail
 var tint=Color('#5c3c22');var rough=.86;var metallic=0.0
 if source is StandardMaterial3D:
  tint=source.albedo_color;rough=source.roughness;metallic=source.metallic
 elif source is ShaderMaterial:
  var value=source.get_shader_parameter('tint')
  if value is Color:tint=value
  if value is Vector4:tint=Color(value.x,value.y,value.z,value.w)
  value=source.get_shader_parameter('roughness')
  if value!=null:rough=float(value)
  value=source.get_shader_parameter('metallic')
  if value!=null:metallic=float(value)
 var detail=ShaderMaterial.new();detail.shader=Controller.SURFACE
 detail.set_shader_parameter('kind',kind);detail.set_shader_parameter('tint',tint)
 detail.set_shader_parameter('roughness',rough);detail.set_shader_parameter('metallic',metallic)
 var low=StandardMaterial3D.new();low.albedo_color=tint;low.roughness=rough;low.metallic=metallic
 if source is StandardMaterial3D:low.cull_mode=source.cull_mode
 controller.bank.append({'detail':detail,'low':low,'key':key})
 return detail

static func refine(root:Node3D,shop:Node3D,controller,name:String)->int:
 var visual=Node3D.new();visual.name=name;shop.add_child(visual)
 var count=0
 for mesh in root.find_children('*','MeshInstance3D',true,false):
  if not mesh.material_override or mesh.mesh==null:continue
  var path=str(shop.get_path_to(mesh)).to_lower()
  if path.begins_with('materialdetail/') or path.begins_with(name.to_lower()+'/'):continue
  var kind=kind_for(path,mesh.material_override)
  if kind<0:continue
  mesh.material_override=surface(controller,mesh.material_override,kind)
  mesh.mesh=grain_mesh(mesh.mesh) # Color carries each member's grain axis.
  mesh.reparent(visual,true);count+=1
 if count==0:visual.free();return 0
 Builder.batch_static(visual)
 for mesh in visual.find_children('*','MeshInstance3D',true,false):controller.register_mesh(mesh)
 return count

static func apply(shop:Node3D,spec:Dictionary):
 assert(spec.id in ['Psy','Atlas'])
 assert(not shop.has_node('MaterialDetail'))
 assert(shop.has_node('SideEnvelopeCandidate'))
 var materials={};var controller=Controller.configure(shop,materials)
 # Added joinery matches existing quiet side timber and dressed footing palette.
 for row in controller.bank:
  var tint=null
  if row.key=='wood':tint=Color(.36,.235,.135)
  elif row.key=='stone':tint=Color(.46,.44,.38)
  elif row.key=='bronze':tint=Color('#9b7944')
  if tint!=null:row.detail.set_shader_parameter('tint',tint);row.low.albedo_color=tint
 var profiles=[]
 for side in [-1,1]:
  var x=side*(spec.width/2-.25)
  profiles.append({'side':side,'lines':Envelope._profile(shop,Envelope._roofs(shop,spec),x,-spec.depth/2+.39,spec.depth/2-.79)})
 var count=refine(shop,shop,controller,'SurroundMaterialSurfaces')
 controller.joinery=Node3D.new();controller.joinery.name='HighJoinery';controller.add_child(controller.joinery)
 controller.stock=Node3D.new();controller.stock.name='MaxShopGoods';controller.add_child(controller.stock)
 edge_joinery(controller.joinery,spec,profiles,materials)
 if spec.id=='Atlas':return_supplies(controller,controller.stock,spec,materials)
 controller.seal_groups(Builder)
 controller.set_meta('surround_finish',{'role':spec.id,'refined_meshes':count,'new_services':0,'original_geometry_unchanged':true})
 return controller

static func finish_repair(shop:Node3D,repair:Node3D):
 # The existing rear repairs arrive after market batching; only their visual children move.
 if shop.name not in ['PsyStand','AtlasStand']:return
 var controller=shop.get_node('MaterialDetail')
 var count=refine(repair,shop,controller,'RearRepairMaterialSurfaces')
 controller.set_quality(controller.quality)
 controller.set_meta('rear_repair_meshes_refined',count)

static func edge_joinery(root:Node3D,spec:Dictionary,profiles:Array,m:Dictionary):
 var w:float=spec.width;var d:float=spec.depth;var back=-d/2+.3;var front=d/2-.7
 # Narrow dressed cap joins the existing footing to its timber sill, inside the old plinth.
 Builder.box(root,'Rear footing dressed cap',Vector3(0,.614,back-.19),Vector3(w-.30,.055,.12),m.stone)
 for side in [-1,1]:
  var x=side*(w/2-.12)
  Builder.box(root,'Side footing dressed cap',Vector3(x,.614,(back+front)*.5),Vector3(.16,.055,front-back+.05),m.stone)
  # Complete the short existing front-corner footing return, behind the customer-facing post.
  Builder.box(root,'Side footing front return',Vector3(side*(w/2-.15),.36,front-.32),Vector3(.16,.48,.48),m.stone)
  for z in [back+.08,(back+front)*.5,front-.12]:
   for y in [.78,2.51]:
    Builder.box(root,'Frame bronze square fixing',Vector3(side*(w/2-.055),y,z),Vector3(.012,.038,.038),m.bronze)
  for profile in profiles:
   if profile.side!=side:continue
   for line in profile.lines:
    Builder.beam(root,'Side eave edge bead',Vector3(x,line.y-.07,line.x),Vector3(x,line.w-.07,line.z),.045,m.bronze)
 # Raised rear caps are small finish pieces, not new structural infill.
 var rear_y=4.315 if spec.id=='Psy' else 3.97
 Builder.box(root,'Rear eave edge bead',Vector3(0,rear_y,back-.19),Vector3(w-.26,.045,.045),m.bronze)
 for x in [-w/2+.3,-w/6,w/6,w/2-.3]:
  for y in [.78,3.39]:
   Builder.box(root,'Rear frame square fixing',Vector3(x,y,back-.233),Vector3(.038,.038,.012),m.bronze)

static func return_supplies(c,root:Node3D,spec:Dictionary,m:Dictionary):
 # A single organized return-handling tray rests on the existing unused handover inset.
 # Blank tags and closed parcels are presentation, never inventory or a promised service.
 var p=Vector3(1.5,1.375,spec.depth/2-.7-.63)
 Builder.box(root,'Return sorting tray floor',p,Vector3(1.18,.025,.43),m.wood)
 for side in [-1,1]:
  Builder.box(root,'Return sorting tray end',p+Vector3(side*.58,.07,0),Vector3(.025,.14,.43),m.bronze)
  Builder.box(root,'Return sorting tray lip',p+Vector3(0,.055,side*.205),Vector3(1.18,.11,.025),m.wood)
 Builder.box(root,'Return sorting tray divider',p+Vector3(.18,.065,0),Vector3(.025,.13,.40),m.wood)
 var parcel=p+Vector3(-.20,.1025,0)
 Builder.box(root,'Closed tagged return',parcel,Vector3(.55,.18,.29),m.wrap)
 Builder.box(root,'Return parcel narrow tie',parcel+Vector3(0,.094,0),Vector3(.025,.008,.29),m.bronze)
 Builder.box(root,'Return parcel blank tag',parcel+Vector3(.12,.098,.04),Vector3(.14,.012,.08),m.cloth)
 for i in range(3):
  Builder.box(root,'Sorted blank return cards',p+Vector3(.38,.0185+i*.012,.06),Vector3(.22,.012,.12),m.cloth)
 c.cylinder(root,'Return twine spool',p+Vector3(.38,.0775,-.10),.045,.13,m.wrap)
 c.cylinder(root,'Twine spindle cap',p+Vector3(.38,.1485,-.10),.053,.012,m.wood)
