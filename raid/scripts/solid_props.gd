extends RefCounted
## TASKS queue item 3: solid collision where the settlement only had visuals. Tree trunks
## (Broadleaf/Common trees in the plaza gardens, "east of Rook", the inn approach, home garden;
## the rollout trunk meshes) and lamp posts that had no collider get a simple upright cylinder on
## the normal physics layer, so the player (and therefore the first-person eye and the camera
## pivot) can no longer walk into them. Posts that already have a collider are left alone.
## Runtime only: one StaticBody3D "SolidProps" under the world. Calling again (the staged-startup
## second pass) rebuilds it, so props added in between are covered.
const NAME := "SolidProps"
const REGION := AABB(Vector3(-75, -6, -75), Vector3(150, 36, 160))
const TRUNK_BAND := 1.0      # metres above the lowest vertex used to find the trunk
const MIN_RADIUS := 0.12
const MAX_RADIUS := 0.45
const MIN_HEIGHT := 2.0
const LEAF_WORDS := ["lobe", "crown", "leaves", "branch", "foliage", "canopy", "flag", "cloth"]

static func install(world: Node3D) -> Node:
	if not is_instance_valid(world): return null
	var existing = world.get_node_or_null(NAME)
	if existing != null:
		world.remove_child(existing)
		existing.free()
	var body := StaticBody3D.new()
	body.name = NAME
	body.set_meta("audio_surface", "wood")
	world.add_child(body)
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var player = world.get("player")
	var exclude: Array = [player.get_rid()] if is_instance_valid(player) else []
	var report := {"trees": 0, "trunks": 0, "lamps": 0, "skipped_solid": 0}
	var stack: Array = [world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == player or n == body or n is CanvasLayer or n is SubViewport: continue
		for c in n.get_children(): stack.append(c)
		if not (n is Node3D) or not n.is_visible_in_tree(): continue
		var kind := classify(n)
		if kind.is_empty(): continue
		var post := post_for(n, kind)
		if post.is_empty(): continue
		if has_collider(space, post, exclude):
			report.skipped_solid += 1
			continue
		add_cylinder(body, post, str(n.name))
		report[kind + "s"] += 1
	body.set_meta("solid_props", report)
	return body

static func classify(n: Node) -> String:
	var own := str(n.name).to_lower()
	for w in LEAF_WORDS:
		if own.contains(w): return ""
	if n is MeshInstance3D:
		var parent := str(n.get_parent().name).to_lower() if n.get_parent() != null else ""
		if own.contains("trunk") or parent.contains("trunk"): return "trunk"
		if own.contains("tree"): return "tree"
		return ""
	# Lamp groups are Node3D roots with several small meshes (socket, upright, lantern).
	if (own.contains("lamp") or own.contains("lantern")) and not (n is VisualInstance3D): return "lamp"
	return ""

static func world_vertices(m: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	if m.mesh == null: return out
	var xf: Transform3D = m.global_transform
	for s in m.mesh.get_surface_count():
		var arr = m.mesh.surface_get_arrays(s)
		for v in arr[Mesh.ARRAY_VERTEX]: out.append(xf * v)
	return out

## Upright cylinder {center, radius, height} from the lowest band of the vertices.
static func post_from(verts: PackedVector3Array, band: float, min_height: float) -> Dictionary:
	if verts.is_empty(): return {}
	var lo := INF
	var hi := -INF
	for v in verts:
		lo = minf(lo, v.y); hi = maxf(hi, v.y)
	if hi - lo < min_height * 0.5: return {}
	var c := Vector2.ZERO
	var k := 0
	for v in verts:
		if v.y <= lo + band:
			c += Vector2(v.x, v.z); k += 1
	if k == 0: return {}
	c /= k
	var d: Array = []
	for v in verts:
		if v.y <= lo + band: d.append(Vector2(v.x, v.z).distance_to(c))
	d.sort()
	var r := clampf(float(d[int((d.size() - 1) * 0.8)]), MIN_RADIUS, MAX_RADIUS)
	var h := clampf(hi - lo, min_height, 2.8)
	var center := Vector3(c.x, lo + h * 0.5, c.y)
	if not REGION.has_point(center): return {}
	return {"center": center, "radius": r, "height": h}

static func post_for(n: Node3D, kind: String) -> Dictionary:
	if kind == "lamp":
		var verts := PackedVector3Array()
		for m in n.find_children("*", "MeshInstance3D", true, false):
			if m.is_visible_in_tree(): verts.append_array(world_vertices(m))
		var a := aabb_of(verts)
		if a.size.y < 1.0 or a.size.x > 1.2 or a.size.z > 1.2: return {}
		var p := post_from(verts, 0.5, 1.0)
		if not p.is_empty(): p.radius = minf(p.radius, 0.2)
		return p
	var mi := n as MeshInstance3D
	var verts2 := world_vertices(mi)
	if kind == "trunk":
		var a2 := aabb_of(verts2)
		if a2.size.y < 0.8 or a2.size.x > 1.2 or a2.size.z > 1.2: return {}
		return {"center": a2.get_center(), "radius": clampf(maxf(a2.size.x, a2.size.z) * 0.45, MIN_RADIUS, MAX_RADIUS), "height": a2.size.y}
	var a3 := aabb_of(verts2)
	if a3.size.y < MIN_HEIGHT: return {}
	return post_from(verts2, TRUNK_BAND, MIN_HEIGHT)

static func aabb_of(verts: PackedVector3Array) -> AABB:
	if verts.is_empty(): return AABB()
	var a := AABB(verts[0], Vector3.ZERO)
	for v in verts: a = a.expand(v)
	return a

static func has_collider(space: PhysicsDirectSpaceState3D, post: Dictionary, exclude: Array) -> bool:
	var probe := CylinderShape3D.new()
	probe.radius = maxf(post.radius * 0.6, 0.06)
	probe.height = minf(post.height * 0.6, 1.2)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = probe
	q.transform = Transform3D(Basis(), post.center)
	q.exclude = exclude
	return not space.intersect_shape(q, 1).is_empty()

static func add_cylinder(body: StaticBody3D, post: Dictionary, label: String) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = post.radius
	shape.height = post.height
	var col := CollisionShape3D.new()
	col.name = "Solid_" + label.validate_node_name()
	col.shape = shape
	body.add_child(col)
	col.global_position = post.center
