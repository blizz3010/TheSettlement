extends RefCounted
const GARDEN_POCKETS = [Rect2(-16.2,-27,3.8,4),Rect2(12.4,-27,3.8,4)]
# Registry is authored from actual bench transforms; no persistent gameplay state.
static func register_bench(bench: Node3D):
 bench.add_to_group('usable_seats')
 bench.set_meta('seat_local_origin',Vector3(0,.52,-.14))
 bench.set_meta('seat_exit_local',[Vector3(0,.01,-1.05),Vector3(-.6,.01,-1.05),Vector3(.6,.01,-1.05),Vector3(0,.01,-.65),Vector3(-.65,.01,-.65),Vector3(.65,.01,-.65)])
static func target(scene: Node3D, player: CharacterBody3D) -> Node3D:
 if player.seated: return null
 var best: Node3D = null
 var best_distance := 2.3
 for bench in scene.get_tree().get_nodes_in_group('usable_seats'):
  var point: Vector3 = bench.to_global(Vector3(0,.70,-.14))
  var delta: Vector3 = point-player.camera.global_position
  if player.global_position.distance_to(bench.global_position)>2.3 or delta.length()>3.0: continue
  if (-player.camera.global_basis.z).dot(delta.normalized())<.85: continue
  var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position,point,player.collision_mask,[player.get_rid()])
  ray.hit_from_inside = true
  var hit = player.get_world_3d().direct_space_state.intersect_ray(ray)
  if not hit.is_empty() and not bench.is_ancestor_of(hit.collider): continue
  var distance := player.global_position.distance_to(bench.global_position)
  if distance < best_distance:
   best = bench
   best_distance = distance
 return best
static func sit(player: CharacterBody3D, bench: Node3D) -> bool:
 var exits: Array[Vector3] = []
 for point in bench.get_meta('seat_exit_local'): exits.append(bench.to_global(point))
 return player.try_begin_sit(bench.to_global(bench.get_meta('seat_local_origin')),bench.global_rotation.y,exits)
static func add_to(scene: Node3D):
 var original = scene.find_child('PlazaBenchEast',true,false)
 if original != null: register_bench(original)
 # Narrow outdoor pockets outside the hall's side paths. Same existing bench art.
 # Never add the rejected west fountain bench or block trader/Rook approaches.
 var manifest=JSON.parse_string(FileAccess.get_file_as_string('res://assets/source/plaza_bench_v019/manifest.json'))
 for side in [-1,1]:
  var bench := Node3D.new()
  bench.name='HallGardenBenchWest' if side<0 else 'HallGardenBenchEast'
  bench.position=Vector3(side*14.4,0,-25)
  bench.rotation.y=side*PI/2
  scene.add_child(bench)
  var art=load('res://assets/kit/plaza_bench.glb').instantiate()
  bench.add_child(art)
  preload('res://scripts/architecture_materials.gd').apply(art)
  var body := StaticBody3D.new()
  body.name='MemberCollision'
  bench.add_child(body)
  for member in manifest.members:
   var shape := CollisionShape3D.new()
   var box := BoxShape3D.new()
   box.size=Vector3(member.size[0],member.size[1],member.size[2])
   shape.shape=box
   shape.position=Vector3(member.position[0],member.position[1],member.position[2])
   body.add_child(shape)
  register_bench(bench)
