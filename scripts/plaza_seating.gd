extends RefCounted
const ArchitectureMaterials = preload("res://scripts/architecture_materials.gd")
static func add_to(parent: Node3D):
 var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/plaza_bench_v019/manifest.json"))
 # West candidate rejected: it blocks the preserved X=-3.65 fountain tangent.
 for side in [1]:
  var bench=Node3D.new()
  bench.name="PlazaBenchWest" if side<0 else "PlazaBenchEast"
  bench.position=Vector3(side*2.97,0,2.97)
  bench.rotation.y=side*PI/4
  parent.add_child(bench)
  var art=load("res://assets/kit/plaza_bench.glb").instantiate()
  art.name="Art"
  bench.add_child(art)
  ArchitectureMaterials.apply(art)
  # Individual visible slats, supports and legs; no enclosing invisible box.
  var body=StaticBody3D.new()
  body.name="MemberCollision"
  bench.add_child(body)
  for member in manifest.members:
   var shape=CollisionShape3D.new()
   var box=BoxShape3D.new()
   box.size=Vector3(member.size[0],member.size[1],member.size[2])
   shape.shape=box
   shape.position=Vector3(member.position[0],member.position[1],member.position[2])
   shape.name=member.name
   body.add_child(shape)
