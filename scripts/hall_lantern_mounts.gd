extends RefCounted
# Four original suspended nave lanterns lacked any visible suspension.
# Original mesh and light coordinates stay exact. Two central fixtures already
# intersect the nave columns and are intentionally outside this narrow repair.
const FIXTURE_X := [-3.0, 3.0]
const FIXTURE_Z := [-17.0, -29.0]
const CAP_TOP := 5.03
const ROOF_UNDERSIDE := 7.10
static func add_box(root: Node3D, label: String, center: Vector3, size: Vector3, material: Material):
 var mesh := MeshInstance3D.new()
 mesh.name = label
 mesh.position = center
 var box := BoxMesh.new()
 box.size = size
 mesh.mesh = box
 mesh.material_override = material
 root.add_child(mesh)
 return mesh
static func add_to(scene: Node3D) -> Node3D:
 assert(not scene.has_node('TownHallLanternMounts'), 'Mounts must only be installed once')
 var root := Node3D.new()
 root.name = 'TownHallLanternMounts'
 scene.add_child(root)
 var bronze := StandardMaterial3D.new()
 bronze.albedo_color = Color(.25, .16, .074)
 bronze.metallic = .65
 bronze.roughness = .6
 for x in FIXTURE_X:
  for z in FIXTURE_Z:
   # Slight overlap into cap and roof removes floating-point gaps.
   add_box(root, 'Bronze suspension rod', Vector3(x, (CAP_TOP + ROOF_UNDERSIDE) * .5, z), Vector3(.035, ROOF_UNDERSIDE - CAP_TOP + .04, .035), bronze)
   add_box(root, 'Roof mounting rosette', Vector3(x, ROOF_UNDERSIDE - .015, z), Vector3(.18, .06, .18), bronze)
   add_box(root, 'Cap suspension collar', Vector3(x, CAP_TOP, z), Vector3(.09, .065, .09), bronze)
 root.set_meta('repair_scope', {'original_fixtures_moved': 0, 'original_lights_changed': 0, 'new_lights': 0, 'new_colliders': 0, 'supported_fixtures': 4})
 return root
