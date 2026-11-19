extends Node
## TASKS queue item 3 (visualpass 109/110/209/231/232, playtest2 ship walkway): third-person camera
## collision. scripts/player.gd (pinned) places the third-person camera with one thin ray against
## physics colliders only (hit + normal * 0.2), so the view enters anything that is visual-only
## (lamp heads, rail posts, tree trunks, turf above its walk collider) or that the ray threads past.
## This node is a child of the player and runs after it (physics and render frame): it re-solves
## the same boom (eye + basis * (0, 1, 3.5)) as a sphere sweep ("spring arm") against
##   1. the normal physics world (all layers, player excluded), and
##   2. a camera-only mirror space built from the visible static meshes of the settlement
##      (its own PhysicsServer3D space, so no gameplay ray, trader check or build query sees it).
## The boom shortens instantly when blocked and eases back out. First person is untouched.
const NAME := "CameraCollision"
const PROBE_RADIUS := 0.24
## Near-plane corner of a 76 deg camera at 16:10 is ~0.09 m from the eye; the test uses 0.10.
const CLEARANCE_RADIUS := 0.10
const BOOM := Vector3(0, 1.0, 3.5)
const PIVOT_LIFT := 0.02
const MIN_BOOM := 0.25
const EASE_OUT_SPEED := 5.0
## Settlement region mirrored for the camera (m). Far scenery and the sky shell are left out.
const REGION_X := Vector2(-75, 75)
const REGION_Z := Vector2(-75, 85)
const REGION_Y := Vector2(-6, 30)
const MAX_MESH_SPAN := 250.0
const MIN_MESH_SPAN := 0.2
## Not solid to a camera: the transparent dome shell, animals, map/preview viewports.
const SKIP_NAMES := ["DomeSurface", "AmbientWildlife"]
const BUILD_BUDGET_MS := 4.0
const REFRESH_PER_FRAME := 160

var player: CharacterBody3D
var space: RID
var shapes := {}          # Mesh -> ConcavePolygonShape3D (shared by instances)
var entries: Array = []   # [body RID, MeshInstance3D, last Transform3D]
var pending: Array = []   # MeshInstance3D still to mirror
var built := false
var build_ms := 0.0
var mirrored_tris := 0
var refresh_cursor := 0
var boom_length := -1.0
var last_solve_us := 0
var max_solve_us := 0
var solves := 0
var total_solve_us := 0
var enabled := true
var sphere := SphereShape3D.new()

static func attach(p: Node, scan_root: Node = null) -> Node:
	if not is_instance_valid(p) or not (p is CharacterBody3D) or p.get("camera") == null: return null
	var existing = p.get_node_or_null(NAME)
	if existing != null: return existing
	var n = load("res://raid/scripts/camera_collision.gd").new()
	n.name = NAME
	n.player = p
	p.add_child(n)
	n.start(scan_root if scan_root != null else p.get_parent())
	return n

func _ready() -> void:
	process_priority = 1000
	process_physics_priority = 1000
	sphere.radius = PROBE_RADIUS

func start(scan_root: Node) -> void:
	space = PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(space, true)
	pending = collect(scan_root)
	# Nearest first, so the area around the player is covered in the first frames.
	var at: Vector3 = player.global_position
	pending.sort_custom(func(a, b): return a.global_position.distance_squared_to(at) > b.global_position.distance_squared_to(at))

func collect(scan_root: Node) -> Array:
	var out: Array = []
	if not is_instance_valid(scan_root): return out
	var w3d: World3D = player.get_world_3d()
	var stack: Array = [scan_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == player or node is CanvasLayer or node is SubViewport: continue
		if str(node.name) in SKIP_NAMES: continue
		for c in node.get_children(): stack.append(c)
		if node is MeshInstance3D and mirrorable(node, w3d): out.append(node)
	return out

static func region_hit(a: AABB) -> bool:
	return a.end.x > REGION_X.x and a.position.x < REGION_X.y and a.end.z > REGION_Z.x and a.position.z < REGION_Z.y \
		and a.end.y > REGION_Y.x and a.position.y < REGION_Y.y

func mirrorable(m: MeshInstance3D, w3d: World3D) -> bool:
	if m.mesh == null or not m.is_visible_in_tree() or m.get_world_3d() != w3d: return false
	if m.transparency > 0.5: return false
	var a: AABB = m.global_transform * m.get_aabb()
	var span := maxf(a.size.x, maxf(a.size.y, a.size.z))
	if span < MIN_MESH_SPAN or a.size.x > MAX_MESH_SPAN or a.size.z > MAX_MESH_SPAN: return false
	return region_hit(a)

func mirror(m: MeshInstance3D) -> void:
	if not is_instance_valid(m) or m.mesh == null: return
	var sh = shapes.get(m.mesh)
	if sh == null:
		sh = m.mesh.create_trimesh_shape()
		if sh == null: return
		shapes[m.mesh] = sh
		mirrored_tris += sh.get_faces().size() / 3
	var b := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_add_shape(b, sh.get_rid())
	PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM, m.global_transform)
	PhysicsServer3D.body_set_space(b, space)
	entries.append([b, m, m.global_transform])

func build_step(budget_ms: float) -> void:
	var t0 := Time.get_ticks_usec()
	while not pending.is_empty() and (Time.get_ticks_usec() - t0) < budget_ms * 1000.0:
		mirror(pending.pop_back())
	build_ms += (Time.get_ticks_usec() - t0) / 1000.0
	if pending.is_empty(): built = true

## Finish the mirror now (tests, or a caller that can afford the ~1 s once).
func build_all() -> void:
	while not built: build_step(1000.0)

## Doors swing, built pieces get removed, props get hidden: follow a slice of the mirror per frame.
func refresh_step() -> void:
	var n := entries.size()
	if n == 0: return
	for i in mini(REFRESH_PER_FRAME, n):
		refresh_cursor = (refresh_cursor + 1) % entries.size()
		var e: Array = entries[refresh_cursor]
		var m = e[1]
		if not is_instance_valid(m) or not m.is_inside_tree():
			PhysicsServer3D.free_rid(e[0])
			entries.remove_at(refresh_cursor)
			if entries.is_empty(): return
			refresh_cursor = refresh_cursor % entries.size()
			continue
		var visible: bool = m.is_visible_in_tree()
		PhysicsServer3D.body_set_shape_disabled(e[0], 0, not visible)
		if visible and m.global_transform != e[2]:
			e[2] = m.global_transform
			PhysicsServer3D.body_set_state(e[0], PhysicsServer3D.BODY_STATE_TRANSFORM, e[2])

func mirror_state() -> PhysicsDirectSpaceState3D:
	return PhysicsServer3D.space_get_direct_state(space)

func pivot() -> Vector3:
	return player.global_position + Vector3(0, float(player.camera_eye_height) + PIVOT_LIFT, 0)

func desired() -> Vector3:
	return pivot() + player.basis * BOOM

## Safe fraction of the sweep from a to b for the probe sphere in one space.
func sweep(state: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, exclude: Array) -> float:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis(), a)
	q.motion = b - a
	q.exclude = exclude
	var r: PackedFloat32Array = state.cast_motion(q)
	return r[0] if r.size() > 0 else 1.0

## Boom length the probe allows right now (no smoothing).
func solve_length() -> float:
	return solve_for(pivot(), desired())

func solve_for(a: Vector3, b: Vector3) -> float:
	var full := a.distance_to(b)
	var safe := sweep(player.get_world_3d().direct_space_state, a, b, [player.get_rid()])
	if space.is_valid(): safe = minf(safe, sweep(mirror_state(), a, b, []))
	return maxf(full * safe, minf(MIN_BOOM, full))

func place(dt: float) -> void:
	if not enabled or not is_instance_valid(player) or not player.third_person or player.camera == null: 
		boom_length = -1.0
		return
	var t0 := Time.get_ticks_usec()
	var target := solve_length()
	if boom_length < 0.0 or target < boom_length: boom_length = target
	else: boom_length = move_toward(boom_length, target, EASE_OUT_SPEED * maxf(dt, 0.0))
	var a := pivot()
	var dir := (desired() - a).normalized()
	player.camera.global_position = a + dir * boom_length
	last_solve_us = Time.get_ticks_usec() - t0
	max_solve_us = maxi(max_solve_us, last_solve_us)
	total_solve_us += last_solve_us
	solves += 1

func _physics_process(delta: float) -> void:
	if not built: build_step(BUILD_BUDGET_MS)
	else: refresh_step()
	place(delta)

func _process(delta: float) -> void:
	# Mouse look turns the player between physics frames; keep the boom solved for this render.
	place(delta)

func _exit_tree() -> void:
	for e in entries: PhysicsServer3D.free_rid(e[0])
	entries.clear()
	if space.is_valid(): PhysicsServer3D.free_rid(space)
	space = RID()
