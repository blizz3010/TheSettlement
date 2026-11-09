extends RefCounted
# Read-only static map scene: never duplicate scripts, lights, physics or actors.
# Materials are detached static daylight versions; gameplay meshes are shared read-only.
const ROOTS=["SettlementTerrain","SettlementOuterTerrain","NorthernStream/ShallowFlow","InnLakesideV088/BroadExteriorLake","InnLakesideV088/RearBalcony","InnLakesideV088/EastBalcony","WestTraderFrontage","EastTraderFrontage","RookReferenceArt","TailorAtelier","SettlementInnExpansion/Inn/RoofRemovableForCutaway","SettlementInnExpansion/TerraceAndApproach","LaunchpadShip/Art","LaunchpadApproach","MarketExpansion","HallSurroundPaths","HallRoutePark","ApproachPathFinish"]
const OMIT=["actor","npc","traderstudy","mannequin","grass","particle","smoke","flame","spark","cloud","dome","collision","clothingsdisplay","relocatedstarterclothing","blockout","placeholder","reservation"]
static func admitted(node:MeshInstance3D)->bool:
 if node.mesh==null:return false
 var path=str(node.get_path()).to_lower()
 for term in OMIT:
  if term in path:return false
 if not node.is_visible_in_tree() and not "roof" in path:return false
 var bounds=node.global_transform*node.mesh.get_aabb()
 # Reject minor trim; keep architectural planes/roof forms and genuine ground pads.
 return bounds.size.x>=.18 and bounds.size.z>=.18 and bounds.size.x*bounds.size.z>=.12
static func material(source:Material,kind:String)->StandardMaterial3D:
 var result=StandardMaterial3D.new()
 result.roughness=.95;result.cull_mode=BaseMaterial3D.CULL_DISABLED
 result.albedo_color={"terrain":Color("647754"),"water":Color("5793a1"),"building":Color("c6b594"),"canopy":Color("58784d")}.get(kind,Color("c6b594"))
 if source is BaseMaterial3D and kind=="building":
  result.albedo_color=source.albedo_color
  result.albedo_color.a=1
  result.albedo_texture=source.albedo_texture
 elif source is ShaderMaterial and kind=="building":
  for key in ["base_color","albedo_color","color"]:
   var color=source.get_shader_parameter(key)
   if color is Color:result.albedo_color=color;result.albedo_color.a=1;break
 # Do not inherit emission, transparency, animation, wind or time-of-day shaders.
 return result
static func snapshot(world:Node3D)->Node3D:
 var root=Node3D.new();root.name="StaticMapScene"
 var seen={};var sources=[];var omitted=0;var missing=[]
 for required in ["LaunchpadShip/Art","LaunchpadApproach","SettlementInnExpansion/Inn/RoofRemovableForCutaway","SettlementInnExpansion/TerraceAndApproach","InnLakesideV088/BroadExteriorLake","TailorAtelier","RookReferenceArt"]:
  if not world.has_node(required):missing.append(required)
 var owners=[]
 for path in ROOTS:
  var owner=world.get_node_or_null(path)
  if owner is Node3D:owners.append(owner)
 var hall=world.get("hall_visual_root")
 if is_instance_valid(hall):owners.append(hall)
 else:missing.append("Town Hall art")
 # Original plaza and routes are top-level visual meshes, not a separate path root.
 for node in world.get_children():
  if node is MeshInstance3D and node.mesh:
   var a=node.mesh.get_aabb()
   if a.size.y<.3 and a.size.x*a.size.z>=4:owners.append(node)
 for owner in owners:
  var path=str(owner.get_path()).to_lower()
  var kind="water" if "shallowflow" in path or "broadexteriorlake" in path else ("terrain" if "terrain" in path else "building")
  for node in ([owner] if owner is MeshInstance3D else [])+owner.find_children("*","MeshInstance3D",true,false):
   if seen.has(node.get_instance_id()):continue
   seen[node.get_instance_id()]=true
   if not admitted(node):omitted+=1;continue
   var mesh=MeshInstance3D.new();mesh.mesh=node.mesh;mesh.transform=node.global_transform
   mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind=="building" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   for i in range(mesh.mesh.get_surface_count()):mesh.set_surface_override_material(i,material(node.get_active_material(i),kind))
   root.add_child(mesh);sources.append(str(node.get_path()))
 # Actual surviving border-tree instances reduced to calm canopy masses.
 var canopies=0
 var border=world.get_node_or_null("NaturalBorder")
 if border:
  for batch in border.get_children():
   if not batch is MultiMeshInstance3D or not "tree" in str(batch.name) or batch.multimesh==null:continue
   var mm=batch.multimesh
   var count=mm.instance_count if mm.visible_instance_count<0 else mini(mm.instance_count,mm.visible_instance_count)
   for i in range(count):
    var a=(batch.global_transform*mm.get_instance_transform(i))*mm.mesh.get_aabb()
    if a.size.y<1:continue
    var mesh=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=.5;sphere.height=1;sphere.radial_segments=12;sphere.rings=6
    mesh.mesh=sphere;mesh.position=a.get_center()+Vector3(0,a.size.y*.2,0);mesh.scale=Vector3(a.size.x,maxf(a.size.y*.55,1),a.size.z)
    mesh.material_override=material(null,"canopy");root.add_child(mesh);canopies+=1
 root.set_meta("map_snapshot",{"mesh_count":sources.size(),"canopies":canopies,"omitted":omitted,"sources":sources,"missing":missing})
 return root
