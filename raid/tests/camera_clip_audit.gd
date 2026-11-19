extends RefCounted
## Shared by test_camera_collision.gd and the item 3 probes. Finds the spots a settler can walk to
## (flood fill over floor levels from the spawn, 1 m cells, step <= 0.45 m, capsule clear) and
## judges a camera position against the camera mirror (visible meshes) and the physics world:
##   touch  - a 0.10 m sphere (encloses the 76 deg near plane) overlaps geometry;
##   inside - the camera is under turf or inside a closed mesh (rays see back faces).
const CELL := 0.75
const MAX_STEP := 0.45
const LEVELS := 3
var world: Node
var cc: Node
var main: PhysicsDirectSpaceState3D
var vis: PhysicsDirectSpaceState3D
var prid: RID
var capsule := CapsuleShape3D.new()
var touch_sphere := SphereShape3D.new()
var cells := {}    # Vector2i -> Array[float] floor heights
var reach: Array = []  # [Vector3 foot]

func _init(w: Node, camera_collision: Node) -> void:
	world = w
	cc = camera_collision
	main = w.get_world_3d().direct_space_state
	vis = cc.mirror_state()
	prid = w.player.get_rid()
	capsule.radius = 0.32
	capsule.height = 1.8
	touch_sphere.radius = cc.CLEARANCE_RADIUS

func floors_at(x: float, z: float) -> Array:
	var out: Array = []
	var top := 30.0
	for i in LEVELS + 3:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, -8, z), world.player.collision_mask, [prid])
		var h := main.intersect_ray(q)
		if h.is_empty(): break
		if h.normal.y > 0.6 and capsule_clear(h.position): out.append(h.position.y)
		top = h.position.y - 0.05
		if out.size() >= LEVELS: break
	return out

func capsule_clear(foot: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = capsule
	q.transform = Transform3D(Basis(), foot + Vector3(0, 0.93, 0))
	q.exclude = [prid]
	q.collision_mask = world.player.collision_mask
	return main.intersect_shape(q, 1).is_empty()

## Flood fill from the seeds over the region (x0..x1, z0..z1). Returns the reachable feet.
func flood(seeds: Array, x0: float, x1: float, z0: float, z1: float) -> Array:
	var seen := {}
	var queue: Array = []
	for start in seeds:
		var key0 := Vector2i(roundi(start.x / CELL), roundi(start.z / CELL))
		if not cells.has(key0): cells[key0] = floors_at(key0.x * CELL, key0.y * CELL)
		var f0: Array = cells[key0]
		var best := -1
		for i in f0.size():
			if best < 0 or absf(f0[i] - start.y) < absf(f0[best] - start.y): best = i
		if best < 0 or absf(f0[best] - start.y) > 1.0: continue
		var sk0 := "%d,%d,%d" % [key0.x, key0.y, roundi(f0[best] * 4)]
		if seen.has(sk0): continue
		seen[sk0] = true
		queue.append([key0, f0[best]])
	var head := 0
	while head < queue.size():
		var cur: Array = queue[head]; head += 1
		var k: Vector2i = cur[0]
		var y: float = cur[1]
		reach.append(Vector3(k.x * CELL, y, k.y * CELL))
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = k + d
			if n.x * CELL < x0 or n.x * CELL > x1 or n.y * CELL < z0 or n.y * CELL > z1: continue
			if not cells.has(n): cells[n] = floors_at(n.x * CELL, n.y * CELL)
			for fy in cells[n]:
				if absf(fy - y) > MAX_STEP: continue
				var sk := "%d,%d,%d" % [n.x, n.y, roundi(fy * 4)]
				if seen.has(sk): continue
				seen[sk] = true
				queue.append([n, fy])
	return reach

func touches(c: Vector3) -> String:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = touch_sphere
	q.transform = Transform3D(Basis(), c)
	var r := vis.intersect_shape(q, 1)
	if not r.is_empty(): return mirror_name(r[0].rid)
	q.exclude = [prid]
	var r2 := main.intersect_shape(q, 1)
	if not r2.is_empty(): return "physics:" + str(r2[0].collider.name if is_instance_valid(r2[0].collider) else "?")
	return ""

## Under a surface (the ray up meets a face from behind) or enclosed (>= 4 of 6 rays see backs).
func inside(c: Vector3) -> String:
	var backs := 0
	var first := ""
	for d in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var q := PhysicsRayQueryParameters3D.create(c, c + d * 3.0)
		q.hit_back_faces = true
		var h := vis.intersect_ray(q)
		if h.is_empty(): continue
		if h.normal.dot(d) > 0.05:
			backs += 1
			if first.is_empty(): first = mirror_name(h.rid)
			if d == Vector3.UP and h.position.distance_to(c) < 2.5: return "under:" + first
	return ("enclosed:" + first) if backs >= 4 else ""

var names := {}
func mirror_name(rid: RID) -> String:
	if names.is_empty():
		for e in cc.entries: names[e[0]] = str(world.get_path_to(e[1])) if is_instance_valid(e[1]) else "?"
	return names.get(rid, "?")

## Pinned scripts/player.gd placement: one ray, hit + normal * 0.2.
func pinned_camera(pivot: Vector3, desired: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(pivot, desired)
	q.exclude = [prid]
	var h := main.intersect_ray(q)
	return h.position + h.normal * 0.2 if not h.is_empty() else desired

func probe_camera(pivot: Vector3, desired: Vector3) -> Vector3:
	return pivot + (desired - pivot).normalized() * cc.solve_for(pivot, desired)
