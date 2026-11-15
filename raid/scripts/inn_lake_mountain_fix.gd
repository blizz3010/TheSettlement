extends RefCounted
## TASKS item 10: the hill ridge behind the inn lake was half invisible and
## looked like it clipped into the water.
##
## Root cause: ValleyBackdrop/MiddleRidge is a ring of hills (r = 70-235 m, up
## to ~23 m high) that physically runs through the lake ellipse. The lake
## adapters never reshaped it; their shaders (lake_scenery_cut_v088, then
## distant_terrain_v094) just discard every fragment inside the ellipse. That
## slices the hills open along the shore: you see through them, and their dark
## cull-disabled back faces and cut walls stand in the water.
##
## Fix (render-only, no pinned file touched): rebuild MiddleRidge with the
## sectors near the lake refined, lower every vertex under a smooth shore
## profile so the hills slope down into the water, and give it a copy of the
## terrain shader without the discard. Trees standing on the lowered slopes are
## moved down with the ground. No collision exists on this scenery.

const Lake := preload("res://scripts/inn_lake_v088.gd")
const SHADER := preload("res://raid/shaders/inn_lake_ridge_v100.gdshader")
const SEGMENTS := 192
const ROWS := 6
const SUB_RADIAL := 10
const SUB_ANGULAR := 3
const BAND := 1.75          # refine sectors whose quads come this close (lake_distance)
const BANK_COLOR := Color(0.27, 0.30, 0.22)
const META := "inn_lake_mountain_fix"

# Meters outside the lake shore (negative = inside the water).
static func shore_meters(p: Vector2) -> float:
	var d := Lake.lake_distance(p)
	if d <= 0.0001:
		return -75.0
	return (d - 1.0) * (p - Lake.CENTER).length() / d

# Highest the ridge may be at this point: a bank that leaves the water ~0.7 m
# inside the ellipse and steepens with distance from the shore.
static func shore_cap(p: Vector2) -> float:
	var m := shore_meters(p)
	if m < 0.0:
		return maxf(Lake.WATER_Y + 0.4 + 0.6 * m, Lake.WATER_Y - 3.0)
	return Lake.WATER_Y + 0.4 + 0.5 * m + 0.018 * m * m

static func capped(v: Vector3) -> Vector3:
	return Vector3(v.x, minf(v.y, shore_cap(Vector2(v.x, v.z))), v.z)

static func _quad_point(a: Vector3, b: Vector3, d: Vector3, e: Vector3, u: float, v: float) -> Vector3:
	# Exactly on the original two triangles (a,b,d) and (d,b,e).
	if u + v <= 1.0:
		return a + (b - a) * u + (d - a) * v
	return e + (d - e) * (1.0 - u) + (b - e) * (1.0 - v)

static func _near_lake(a: Vector3, b: Vector3, d: Vector3, e: Vector3) -> bool:
	for u in [0.0, 0.25, 0.5, 0.75, 1.0]:
		for v in [0.0, 0.5, 1.0]:
			var p := _quad_point(a, b, d, e, u, v)
			if Lake.lake_distance(Vector2(p.x, p.z)) < BAND:
				return true
	return false

static func _shade(c: Color, original_y: float, y: float) -> Color:
	if y >= original_y - 0.01:
		return c
	# Lowered ground near the waterline reads as an earthy bank, not hill haze.
	var wet := 1.0 - smoothstep(Lake.WATER_Y + 0.2, Lake.WATER_Y + 3.0, y)
	return c.lerp(BANK_COLOR, 0.55 * wet)

static func build_mesh(source: Mesh) -> Dictionary:
	var arrays := source.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices = arrays[Mesh.ARRAY_INDEX]
	var faces := PackedVector3Array()
	var face_colors := PackedColorArray()
	if indices != null and indices.size() > 0:
		for k in indices:
			faces.append(verts[k]); face_colors.append(colors[k] if colors != null and colors.size() > k else Color.WHITE)
	else:
		faces = verts
		face_colors = colors if colors != null and colors.size() == verts.size() else PackedColorArray()
		if face_colors.is_empty():
			face_colors.resize(verts.size()); face_colors.fill(Color.WHITE)
	if faces.size() != ROWS * SEGMENTS * 6:
		return {"ok": false, "reason": "MiddleRidge layout changed (%d vertices)" % faces.size()}
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var refined_quads := 0
	var lowered := 0
	var max_above_inside := -INF
	for row in ROWS:
		for i in SEGMENTS:
			var base := (row * SEGMENTS + i) * 6
			var a := faces[base]; var b := faces[base + 1]; var d := faces[base + 2]; var e := faces[base + 5]
			# Sanity: the second triangle must be (d, b, e).
			if not faces[base + 3].is_equal_approx(d) or not faces[base + 4].is_equal_approx(b):
				return {"ok": false, "reason": "MiddleRidge triangle order changed at row %d seg %d" % [row, i]}
			var c1 := face_colors[base]; var c2 := face_colors[base + 3]
			if not _near_lake(a, b, d, e):
				for pair in [[a, c1], [b, c1], [d, c1]]:
					st.set_color(pair[1]); st.add_vertex(pair[0])
				for pair in [[d, c2], [b, c2], [e, c2]]:
					st.set_color(pair[1]); st.add_vertex(pair[0])
				continue
			refined_quads += 1
			var grid := []
			var shades := []
			for ru in SUB_RADIAL + 1:
				var line := []
				var line_c := []
				for av in SUB_ANGULAR + 1:
					var u := float(ru) / SUB_RADIAL
					var v := float(av) / SUB_ANGULAR
					var p := _quad_point(a, b, d, e, u, v)
					var q := capped(p)
					if q.y < p.y - 0.001:
						lowered += 1
					if Lake.lake_distance(Vector2(q.x, q.z)) < 1.0:
						max_above_inside = maxf(max_above_inside, q.y)
					line.append(q)
					line_c.append(_shade(c1 if u + v <= 1.0 else c2, p.y, q.y))
				grid.append(line)
				shades.append(line_c)
			for ru in SUB_RADIAL:
				for av in SUB_ANGULAR:
					var p00: Vector3 = grid[ru][av]; var p10: Vector3 = grid[ru + 1][av]
					var p01: Vector3 = grid[ru][av + 1]; var p11: Vector3 = grid[ru + 1][av + 1]
					var k00: Color = shades[ru][av]; var k10: Color = shades[ru + 1][av]
					var k01: Color = shades[ru][av + 1]; var k11: Color = shades[ru + 1][av + 1]
					# Same winding as the original (a, b, d) / (d, b, e).
					st.set_color(k00); st.add_vertex(p00)
					st.set_color(k10); st.add_vertex(p10)
					st.set_color(k01); st.add_vertex(p01)
					st.set_color(k01); st.add_vertex(p01)
					st.set_color(k10); st.add_vertex(p10)
					st.set_color(k11); st.add_vertex(p11)
	st.generate_normals()
	return {"ok": true, "mesh": st.commit(), "refined_quads": refined_quads, "lowered_vertices": lowered, "max_y_inside_lake": max_above_inside}

# Ground height of the ORIGINAL ridge at p, from its own triangles.
static func _ridge_sampler(source: Mesh, xform: Transform3D) -> Dictionary:
	var faces := source.get_faces()
	var bins := {}
	for t in range(0, faces.size(), 3):
		var tri := [xform * faces[t], xform * faces[t + 1], xform * faces[t + 2]]
		var lo := Vector2(minf(tri[0].x, minf(tri[1].x, tri[2].x)), minf(tri[0].z, minf(tri[1].z, tri[2].z)))
		var hi := Vector2(maxf(tri[0].x, maxf(tri[1].x, tri[2].x)), maxf(tri[0].z, maxf(tri[1].z, tri[2].z)))
		if Lake.lake_distance((lo + hi) * 0.5) > BAND + 1.0:
			continue
		for gz in range(floori(lo.y / 8.0), floori(hi.y / 8.0) + 1):
			for gx in range(floori(lo.x / 8.0), floori(hi.x / 8.0) + 1):
				var key := Vector2i(gx, gz)
				if not bins.has(key):
					bins[key] = []
				bins[key].append(tri)
	return bins

static func _sample(bins: Dictionary, p: Vector2) -> float:
	var best := -INF
	for tri in bins.get(Vector2i(floori(p.x / 8.0), floori(p.y / 8.0)), []):
		var hit = Geometry3D.segment_intersects_triangle(Vector3(p.x, 400.0, p.y), Vector3(p.x, -50.0, p.y), tri[0], tri[1], tri[2])
		if hit is Vector3:
			best = maxf(best, hit.y)
	return best

static func ground_trees(world: Node3D, bins: Dictionary) -> Dictionary:
	var moved := 0
	var batches := 0
	for node in world.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		var mm := mmi.multimesh
		if mm == null or mm.transform_format != MultiMesh.TRANSFORM_3D or mm.instance_count == 0:
			continue
		var touched := false
		var provenance = mmi.get_meta("instance_transforms") if mmi.has_meta("instance_transforms") else null
		var bounds := mm.custom_aabb
		for i in mm.instance_count:
			var local := mm.get_instance_transform(i)
			var root := mmi.global_transform * local.origin
			var p := Vector2(root.x, root.z)
			var d := Lake.lake_distance(p)
			if d < 0.98 or d > BAND + 0.5 or p.length() < 68.0:
				continue
			var cap := shore_cap(p)
			if root.y <= cap + 0.05:
				continue
			var original := _sample(bins, p)
			# Only trees that actually stand on the ridge surface (roots are
			# usually buried a little).
			if original == -INF or absf(root.y - original) > 1.5 or original <= cap:
				continue
			var target := Vector3(root.x, root.y - (original - cap), root.z)
			var next := local
			next.origin = mmi.global_transform.affine_inverse() * target
			mm.set_instance_transform(i, next)
			if provenance is Array and i < provenance.size() and provenance[i] is Transform3D and provenance[i].is_equal_approx(local):
				provenance[i] = next
			if bounds.size != Vector3.ZERO and mm.mesh != null:
				bounds = bounds.merge(next * mm.mesh.get_aabb())
			moved += 1
			touched = true
		if touched:
			batches += 1
			if mm.custom_aabb.size != Vector3.ZERO:
				mm.custom_aabb = bounds
	return {"moved_tree_instances": moved, "batches": batches}

static func apply(world: Node3D) -> Dictionary:
	if world.has_meta(META):
		return world.get_meta(META)
	var ridge := world.get_node_or_null("ValleyBackdrop/MiddleRidge") as MeshInstance3D
	if ridge == null or ridge.mesh == null or ridge.mesh.get_surface_count() != 1:
		return {"ok": false, "reason": "MiddleRidge missing"}
	if not world.get_meta("inn_lake_v088", {}).get("ok", false):
		return {"ok": false, "reason": "Inn lake not installed"}
	if not ridge.global_transform.is_equal_approx(Transform3D.IDENTITY):
		return {"ok": false, "reason": "Unexpected MiddleRidge transform"}
	var original_mesh := ridge.mesh
	var built := build_mesh(original_mesh)
	if not built.get("ok", false):
		world.set_meta(META, built)
		return built
	var bins := _ridge_sampler(original_mesh, ridge.global_transform)
	var old_material := ridge.material_override
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var band := 0
	var tint := Color(0.34, 0.42, 0.36, 1.0)
	if old_material is ShaderMaterial:
		var b = old_material.get_shader_parameter("terrain_band")
		if b != null: band = int(b)
		var t = old_material.get_shader_parameter("original_tint")
		if t == null: t = old_material.get_shader_parameter("tint")
		if t != null: tint = t
	elif old_material is StandardMaterial3D:
		tint = old_material.albedo_color
	material.set_shader_parameter("terrain_band", band)
	material.set_shader_parameter("original_tint", tint)
	ridge.set_meta("pre_lake_fix_mesh", original_mesh)
	ridge.set_meta("pre_lake_fix_material", old_material)
	ridge.mesh = built.mesh
	ridge.material_override = material
	var trees := ground_trees(world, bins)
	var result := {"ok": true, "refined_quads": built.refined_quads, "lowered_vertices": built.lowered_vertices, "max_y_inside_lake": built.max_y_inside_lake, "water_y": Lake.WATER_Y, "triangles": ridge.mesh.get_faces().size() / 3}
	result.merge(trees)
	world.set_meta(META, result)
	return result
