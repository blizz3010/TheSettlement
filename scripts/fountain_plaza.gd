extends RefCounted
# Geometry in metres; matches editable source manifest. No gameplay/state mutation.
const OUTER_RADIUS := 2.9
const INNER_RADIUS := 2.4
const RIM_TOP := 0.71
const WATER_SHADER = preload("res://assets/materials/fountain_water.gdshader")
static func add_cylinder(parent: Node3D, label: String, radius: float, height: float, y: float):
 var body = StaticBody3D.new()
 body.name = label
 var shape = CollisionShape3D.new()
 var cylinder = CylinderShape3D.new()
 cylinder.radius=radius
 cylinder.height=height
 shape.shape=cylinder
 body.position.y=y
 body.add_child(shape)
 parent.add_child(body)
static func build_collision(parent: Node3D):
 var root=Node3D.new()
 root.name="FountainCollision"
 parent.add_child(root)
 # Annular wall, not an invisible full cylinder hovering over the basin.
 var rim=StaticBody3D.new()
 rim.name="SegmentedRim"
 root.add_child(rim)
 for i in range(48):
  var points=PackedVector3Array()
  for y in [0.09,RIM_TOP]:
   for r in [INNER_RADIUS,OUTER_RADIUS]:
    for a in [i*TAU/48.0,(i+1)*TAU/48.0]:
     points.append(Vector3(cos(a)*r,y,sin(a)*r))
  var shape=CollisionShape3D.new()
  var convex=ConvexPolygonShape3D.new()
  convex.points=points
  shape.shape=convex
  rim.add_child(shape)
 add_cylinder(root,"PoolFloor",2.78,0.18,0.19)
 add_cylinder(root,"CentralFoot",1.31,0.22,0.39)
 add_cylinder(root,"CentralDrum",1.23,0.52,0.76)
 add_cylinder(root,"CentralCoping",1.365,0.13,1.085)
 # Sculpture collision follows the exported mesh, not its open bounding box.
 var art=load("res://assets/kit/fountain.glb").instantiate()
 for node in art.find_children("*","MeshInstance3D",true,false):
  var shape=CollisionShape3D.new()
  var faces=PackedVector3Array()
  var mesh_faces=node.mesh.get_faces()
  for k in range(0,mesh_faces.size(),3):
   if minf(mesh_faces[k].y,minf(mesh_faces[k+1].y,mesh_faces[k+2].y)) >= 1.16:
    for j in range(3): faces.append(node.transform*mesh_faces[k+j])
  var data=ConcavePolygonShape3D.new()
  data.set_faces(faces)
  shape.shape=data
  var body=StaticBody3D.new()
  body.name="Sculpture"
  body.add_child(shape)
  root.add_child(body)
 art.free()
 preload("res://scripts/fountain_construction_detail.gd").add_to(parent)
static func style_water(node: Node):
 if node is MeshInstance3D:
  for i in range(node.mesh.get_surface_count()):
   var source=node.mesh.surface_get_material(i)
   if source == null: continue
   if source.resource_name in ["Fountain_Pool_Water","Fountain_Falling_Water"]:
    var mat=ShaderMaterial.new()
    mat.shader=WATER_SHADER
    mat.set_shader_parameter("falling",source.resource_name=="Fountain_Falling_Water")
    node.set_surface_override_material(i,mat)
 for child in node.get_children(): style_water(child)

# Scoped overrides: called only on fountain and its apron, never shared materials.
static func style_surfaces(node: Node):
 if node is MeshInstance3D and str(node.name)=="fountain_apron":
  var seam=preload("res://scripts/fountain_seam_v100.gd").apply(node)
  if not seam.get("ok",false):push_error("Fountain seam: "+str(seam))
 if node is MeshInstance3D:
  for i in range(node.mesh.get_surface_count()):
   var source=node.mesh.surface_get_material(i)
   if source == null: continue
   var label=source.resource_name
   var stone=label.begins_with("Limestone_Fountain_")
   var bronze=label in ["Weathered_Bronze","Polished_Bronze_Edges"]
   if not stone and not bronze: continue
   var mat=ShaderMaterial.new()
   mat.shader=load("res://assets/materials/courtyard_surface.gdshader")
   var tint=Color(0.32,0.265,0.19)
   if stone:
    var tones=[Color(0.40,0.385,0.35),Color(0.43,0.412,0.375),Color(0.46,0.44,0.40),Color(0.42,0.40,0.365)]
    tint=tones[int(label.get_slice("_",2))%4]
   elif label=="Polished_Bronze_Edges": tint=Color(0.43,0.35,0.245)
   mat.set_shader_parameter("tint",tint)
   mat.set_shader_parameter("metallic",0.64 if bronze else 0.0)
   mat.set_shader_parameter("roughness",0.61 if bronze else 0.83)
   mat.set_shader_parameter("variation",0.24 if bronze else 0.25)
   mat.set_shader_parameter("grain_scale",24.0 if bronze else 16.0)
   mat.set_shader_parameter("bump_strength",0.018 if bronze else 0.032)
   mat.set_shader_parameter("patina",0.30 if bronze else 0.0)
   node.set_surface_override_material(i,mat)
 for child in node.get_children(): style_surfaces(child)
