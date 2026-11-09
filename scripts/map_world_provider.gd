extends RefCounted
# Static, north-up cartographic survey. Only authored surfaces are admitted.
# The panel owns invalidation; this adapter never changes the world.
static func polygon(mesh:Mesh,t:Transform3D)->PackedVector2Array:
 var points=PackedVector2Array()
 for vertex in mesh.get_faces():
  var p=t*vertex
  if p.is_finite():points.append(Vector2(p.x,p.z))
 var result=Geometry2D.convex_hull(points) if points.size()>2 else PackedVector2Array()
 if result.size()>1 and result[0].is_equal_approx(result[-1]):result.remove_at(result.size()-1)
 return result
static func add_mesh(layers:Dictionary,kind:String,node:MeshInstance3D,triangles=false):
 if node.mesh==null:return
 if not triangles:
  var poly=polygon(node.mesh,node.global_transform)
  if poly.size()>2:layers[kind].append({"polygon":poly,"source":str(node.get_path())})
  return
 var faces=node.mesh.get_faces()
 for i in range(0,faces.size()-2,3):
  var poly=PackedVector2Array();var height=0.0
  for j in range(3):
   var p=node.global_transform*faces[i+j];poly.append(Vector2(p.x,p.z));height+=p.y/3.0
  if absf((poly[1]-poly[0]).cross(poly[2]-poly[0]))>.001:layers[kind].append({"polygon":poly,"height":height,"source":str(node.get_path())})
static func footprint(layers:Dictionary,node:Node3D,kind="buildings"):
 # One intentional silhouette per authored building/root, not per trim mesh.
 var points=PackedVector2Array()
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null:continue
  var a: AABB=mesh.mesh.get_aabb()
  for i in range(8):
   var v=mesh.global_transform*a.get_endpoint(i);points.append(Vector2(v.x,v.z))
 if points.size()<3:return
 var poly=Geometry2D.convex_hull(points)
 if poly.size()>1 and poly[0].is_equal_approx(poly[-1]):poly.remove_at(poly.size()-1)
 layers[kind].append({"polygon":poly,"source":str(node.get_path())})
static func construction(world:Node3D)->Array:
 var rows=[];var pieces=world.get("pieces")
 if not is_instance_valid(pieces):return rows
 for shape in pieces.find_children("*","CollisionShape3D",true,false):
  if not shape.shape is BoxShape3D or not shape.get_parent().has_meta("build_cell"):continue
  var mesh=BoxMesh.new();mesh.size=shape.shape.size
  rows.append({"polygon":polygon(mesh,shape.global_transform),"source":str(shape.get_path())})
 return rows
static func survey(world:Node3D)->Dictionary:
 var layers={"terrain":[],"water":[],"paths":[],"buildings":[],"landmarks":[],"missing":[]}
 for spec in [["SettlementTerrain/GroundRelief","terrain"],["SettlementOuterTerrain/GroundRelief","terrain"],["NorthernStream/ShallowFlow","water"],["InnLakesideV088/BroadExteriorLake","water"]]:
  var node=world.get_node_or_null(spec[0])
  if node is MeshInstance3D:add_mesh(layers,spec[1],node,true)
  else:layers.missing.append(spec[0])
 for node in [world]+world.find_children("*","Node3D",true,false):
  for key in ["paving_polygons","footprints"]:
   if node.has_meta(key):
    for poly in node.get_meta(key):
     if poly is PackedVector2Array:layers.paths.append({"polygon":poly.duplicate(),"source":str(node.get_path())+":"+key})
  if node is MeshInstance3D and node.get_parent()==world:
   if node.mesh is BoxMesh and node.mesh.size.y<.3 and node.mesh.size.x*node.mesh.size.z>=4 and node.mesh.size.x<60 and node.mesh.size.z<60:add_mesh(layers,"paths",node)
   elif node.mesh is CylinderMesh and node.mesh.height<.3 and node.mesh.top_radius>1:add_mesh(layers,"paths",node)
 # Deliberate major roof/floor owners. No furniture, actors, vegetation or dome.
 for path in ["WestTraderFrontage","EastTraderFrontage/Floor flush stone","TailorAtelier/Atelier floor","SettlementInnExpansion/Inn/RoofRemovableForCutaway","MarketExpansion/PsyStand/Limestone plinth","MarketExpansion/AtlasStand/Limestone plinth","MarketExpansion/DanStand/Limestone plinth"]:
  var node=world.get_node_or_null(path)
  if node is MeshInstance3D:add_mesh(layers,"buildings",node)
  elif node is Node3D:footprint(layers,node)
  else:layers.missing.append(path)
 for shape in world.find_children("*","CollisionShape3D",true,false):
  if not shape.shape is BoxShape3D:continue
  var body=shape.get_parent()
  if body.name=="Level floor" and body.get_parent().name=="TownHallCollision":
   var mesh=BoxMesh.new();mesh.size=shape.shape.size
   layers.buildings.append({"polygon":polygon(mesh,shape.global_transform),"source":str(shape.get_path())})
 # Include the actual platform, hull and connected approach (not a guessed icon footprint).
 var ship=world.get_node_or_null("LaunchpadShip")
 if ship is Node3D:
  var art=ship.get_node_or_null("Art")
  if art:footprint(layers,art)
  layers.landmarks.append({"name":"Ship","at":Vector2(ship.global_position.x,ship.global_position.z),"source":str(ship.get_path())})
 else:layers.missing.append("LaunchpadShip")
 for path in ["LaunchpadApproach","SettlementInnExpansion/TerraceAndApproach","InnLakesideV088/RearBalcony","InnLakesideV088/EastBalcony"]:
  var node=world.get_node_or_null(path)
  if node:
   for mesh in ([node] if node is MeshInstance3D else [])+node.find_children("*","MeshInstance3D",true,false):
    if mesh.mesh and mesh.mesh.get_aabb().size.y<.65:add_mesh(layers,"paths",mesh)
 var inn=world.get_node_or_null("SettlementInnExpansion/Inn")
 if inn:layers.landmarks.append({"name":"Inn","at":Vector2(inn.global_position.x,inn.global_position.z),"source":str(inn.get_path())})
 else:layers.missing.append("SettlementInnExpansion/Inn")
 var lake=world.get_node_or_null("InnLakesideV088/BroadExteriorLake")
 if lake:
  var a=lake.global_transform*lake.mesh.get_aabb()
  layers.landmarks.append({"name":"Lake","at":Vector2(a.get_center().x,minf(a.get_center().z,72)),"source":str(lake.get_path())})
 for spec in [["FountainCollision","Fountain"],["RequestBoard","Requests"],["WestTraderFrontage","Cookhouse"],["MarketExpansion/PsyStand","Psy"],["MarketExpansion/AtlasStand","Atlas"],["MarketExpansion/DanStand","Dan"],["TailorAtelier","Tailor & Dyes"]]:
  var node=world.get_node_or_null(spec[0])
  if node is Node3D:layers.landmarks.append({"name":spec[1],"at":Vector2(node.global_position.x,node.global_position.z),"source":str(node.get_path())})
 # Existing actual gameplay anchors, not guessed points from concept art.
 for spec in [["Your Home",world.PLOT],["Fishing spot",world.FISHING_SPOT],["Rook’s Supplies",world.SUPPLIES_COUNTER],["Town Hall",world.HallGeometry.ANCHOR]]:
  layers.landmarks.append({"name":spec[0],"at":Vector2(spec[1].x,spec[1].z),"source":"world constant"})
 # A separate live trader landmark; keep the casting-spot landmark above unchanged.
 var fishing_trader=world.get("fishing_trader")
 if is_instance_valid(fishing_trader) and fishing_trader.is_inside_tree() and not fishing_trader.is_queued_for_deletion():
  var scenery=fishing_trader.scenery
  if is_instance_valid(scenery) and scenery.is_inside_tree() and not scenery.is_queued_for_deletion() and scenery.result.get("ok",false):
   var actor=scenery.actor
   if is_instance_valid(actor) and actor is Node3D and actor.is_inside_tree() and not actor.is_queued_for_deletion() and scenery.is_ancestor_of(actor) and world.is_ancestor_of(actor):
    layers.landmarks.append({"name":"Fishing supplies","at":Vector2(actor.global_position.x,actor.global_position.z),"source":str(actor.get_path())})
 if is_instance_valid(world.cooking_test) and is_instance_valid(world.cooking_test.station):
  var station=world.cooking_test.station
  layers.landmarks.append({"name":"Griddle","at":Vector2(station.global_position.x,station.global_position.z),"source":str(station.get_path())})
 if is_instance_valid(world.cooking_nook_visuals):
  for pad in world.cooking_nook_visuals.find_children("ConnectedWorkPad","MeshInstance3D",true,false):add_mesh(layers,"paths",pad,true)
 return layers
