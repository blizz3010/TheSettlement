extends RefCounted
# Scoped v034 gentle LEAF-only wind. Existing town construction stays authoritative.
const ROOT="res://assets/foliage_wind/"
const BORDER=["border_tree_a","border_tree_b","border_shrub_a","border_shrub_b"]
static func _mesh(file:String)->Mesh:
 var source=load(ROOT+file+".glb").instantiate()
 var nodes=source.find_children("*","MeshInstance3D",true,false)
 assert(nodes.size()==1)
 var result=nodes[0].mesh
 assert(result.get_surface_count()==1)
 source.free()
 return result
static func _phase(p:Vector3)->float:
 return fposmod(p.x*.73+p.z*.41,TAU)
static func _material(phase:float)->ShaderMaterial:
 var material=ShaderMaterial.new()
 material.shader=load(ROOT+"leaf_wind.gdshader")
 material.set_shader_parameter("phase_offset",phase)
 return material
static func apply_to(scene:Node3D)->void:
 assert(not scene.has_meta("leaf_wind_applied"),"Wind must be applied exactly once")
 var border=scene.get_node("NaturalBorder")
 for name in BORDER:
  var node=border.get_node(name) as MultiMeshInstance3D
  var old=node.multimesh
  var transforms:Array=node.get_meta("source_transforms")
  assert(transforms.size()==old.instance_count)
  assert(not old.use_colors and not old.use_custom_data,"Unexpected preexisting instance channels; review before replacing")
  var replacement=MultiMesh.new()
  replacement.transform_format=MultiMesh.TRANSFORM_3D
  replacement.use_colors=true
  replacement.use_custom_data=true
  replacement.mesh=_mesh(name)
  replacement.instance_count=old.instance_count
  replacement.visible_instance_count=old.visible_instance_count
  for i in range(old.instance_count):
   var transform:Transform3D=transforms[i]
   replacement.set_instance_transform(i,transform)
   replacement.set_instance_color(i,Color.WHITE)
   replacement.set_instance_custom_data(i,Color(_phase(transform.origin),0,0,1))
  node.multimesh=replacement
  node.material_override=_material(0.0)
  node.extra_cull_margin=.05
  node.set_meta("leaf_wind",true)
 var near=scene.get_node("ReferenceFoliage")
 for i in range(4):
  _near(near.get_node("Tree%d"%i),"Broadleaf_Tree_A")
  _near(near.get_node("Shrub%d"%i),"Low_Shrub_A" if i%2==0 else "Low_Shrub_B")
 scene.set_meta("leaf_wind_applied",true)
static func _near(root:Node3D,file:String)->void:
 var nodes=root.find_children("*","MeshInstance3D",true,false)
 assert(nodes.size()==1)
 var node=nodes[0] as MeshInstance3D
 node.mesh=_mesh(file)
 node.material_override=_material(_phase(root.position))
 node.extra_cull_margin=.05
 node.set_meta("leaf_wind",true)
