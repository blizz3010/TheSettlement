extends RefCounted
# ISOLATED ARCHITECTURAL STUDY ONLY. Existing buy service relocated, not duplicated.
const FOOTPRINT=Rect2(26,29.5,8,7)
const CONNECTOR=Rect2(29,27,3,3)
const COUNTER=Vector3(30,1.3,34.0)
static func customer_access(p:Vector3)->bool:
 return p.x>=28.6 and p.x<=31.4 and p.z>=31.2 and p.z<=33.8 and absf(p.y)<=.6
static func block(art:Node3D,physics:Node3D,n:String,p:Vector3,size:Vector3,color:Color,solid=true):
 var mesh=MeshInstance3D.new();mesh.name=n;mesh.position=p
 var box=BoxMesh.new();box.size=size;mesh.mesh=box
 var mat=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.85;mesh.material_override=mat;art.add_child(mesh)
 if solid:
  var body=StaticBody3D.new();body.name=n;body.position=p
  body.set_meta('audio_surface','stone')
  var shape=CollisionShape3D.new();var box_shape=BoxShape3D.new();box_shape.size=size;shape.shape=box_shape;body.add_child(shape);physics.add_child(body)
 return mesh
static func add_to(scene:Node3D):
 var art=Node3D.new();art.name='EastTraderFrontage';scene.add_child(art)
 art.set_meta('role','rook_supplies');art.set_meta('stage','architectural_blockout_not_final_art')
 var physics=Node3D.new();physics.name='EastTraderCollision';scene.add_child(physics)
 var stone=Color('#b6ad94');var wood=Color('#6b5747');var cloth=Color('#b88a5d')
 # Coordinates remain world-space for auditable plan and collider journal.
 block(art,physics,'Floor flush stone',Vector3(30,-.025,33),Vector3(7.4,.05,6.4),stone)
 block(art,physics,'Back wall',Vector3(30,1.95,36.1),Vector3(7.4,3.9,.2),stone)
 for x in [26.4,33.6]:block(art,physics,'Side wall',Vector3(x,1.95,33),Vector3(.2,3.9,6.4),stone)
 for x in [27.4,32.6]:block(art,physics,'Front stonework',Vector3(x,1.3,29.9),Vector3(1.8,2.6,.2),stone)
 block(art,physics,'Header',Vector3(30,3.75,29.9),Vector3(7.4,.3,.25),wood)
 block(art,physics,'Roof blockout',Vector3(30,4.0,33),Vector3(7.8,.2,6.8),cloth)
 block(art,physics,'Rear counter',Vector3(30,.55,34.5),Vector3(4,1.1,.8),wood)
 block(art,physics,'Mineral specimen wall reservation',Vector3(26.85,1.5,32.65),Vector3(.5,2.6,4.1),Color('#657f82'))
 block(art,physics,'Pick axe sickle rack reservation',Vector3(33.15,1.4,32.5),Vector3(.5,2.4,3.0),Color('#756649'))
 block(art,physics,'NPC placeholder not approved likeness',Vector3(30,.85,35.35),Vector3(.5,1.7,.5),Color('#8c9490'))
 # Non-solid grade-level connector does not add a raised threshold.
 var connector=block(art,physics,'Rook connector',Vector3(30.5,.015,28.5),Vector3(3,.08,3),stone,false)
 # Existing material category identity retained; no specimen stock or tool item IDs.
 var examples=Node3D.new();examples.name='EastTraderMaterialExamples';scene.add_child(examples)
 examples.set_meta('visual_only',true);examples.set_meta('accepted_categories',['timber','stone','metal_scrap'])
 scene.set_meta('rook_relocation',{'old_anchor':Vector3(8,0,-3),'new_anchor':Vector3(30,0,33),'new_services':0,'same_buy_service':true})

static func finalize_routes(scene:Node3D):
 # Called after existing paving/audio reconciliation and before grass; append, never replace.
 var connector=scene.get_node('EastTraderFrontage/Rook connector')
 connector.material_override=scene.courtyard_material('paving',Color(.46,.44,.38,1))
 var polygon=preload('res://scripts/market_expansion.gd').paving_footprint(connector.mesh,connector.global_transform)
 var market=scene.get_node('MarketExpansion')
 var masks=market.get_meta('paving_polygons',[]).duplicate();masks.append(polygon);market.set_meta('paving_polygons',masks)
 for body in scene.find_children('*','StaticBody3D',true,false):
  if body.has_meta('audio_ground_regions'):
   var polygons=body.get_meta('market_paving_polygons',[]).duplicate();polygons.append(polygon);body.set_meta('market_paving_polygons',polygons)
