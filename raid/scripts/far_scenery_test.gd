extends RefCounted
## TASKS item 9: far-scenery style test, ONE sector only (east, +x).
## Render-only. No pinned file is edited, no collision is added.
##  - Paints MiddleRidge and OuterFoothills in the sector (grass / forest floor /
##    rock / dirt bands, layered aerial fade) via a copy of the v094 terrain
##    shader that keeps the finished southern sector exactly as it was.
##  - Adds low-detail tree clusters (two ~50-80 triangle meshes in one
##    MultiMesh each) in uneven forest patches on the slopes and along crests,
##    so the ridge silhouettes break up instead of reading as bare cones.
## Stays clear of the inn lake (PR #5 sector) and the ruin shelves.

const Lake := preload("res://scripts/inn_lake_v088.gd")
const PAINT := preload("res://raid/shaders/far_terrain_paint_v100.gdshader")
const CANOPY := preload("res://raid/shaders/far_canopy_v100.gdshader")
const META := "far_scenery_test"
const SEED := 2026111309
# Sector: azimuth atan2(z, x) in degrees, full paint inside, feathered edges.
const AZ_CENTER := 5.0
const AZ_FULL := 30.0
const AZ_EDGE := 45.0
const R_MIN := 74.0
const R_MAX := 330.0
const TARGET := 1700
const GRID := 8.0
const RUIN_A := Vector2(145, -95)

static func sector_weight(p: Vector2) -> float:
	var az := rad_to_deg(atan2(p.y, p.x))
	var off := absf(wrapf(az - AZ_CENTER, -180.0, 180.0))
	return 1.0 - smoothstep(AZ_FULL, AZ_EDGE, off)

# ---------- meshes ----------
static func _blob(st: SurfaceTool, c: Vector3, r: Vector3, color: Color, sides: int) -> void:
	# Faceted low dome: 1 ring + top + skirt, flat shaded.
	var top := c + Vector3(0, r.y, 0)
	var bottom := c - Vector3(0, r.y * 0.45, 0)
	var ring := []
	for i in sides:
		var a := TAU * i / sides + 0.37
		ring.append(c + Vector3(cos(a) * r.x, r.y * 0.15 * sin(a * 3.0), sin(a) * r.z))
	for i in sides:
		var p: Vector3 = ring[i]
		var q: Vector3 = ring[(i + 1) % sides]
		for tri in [[top, q, p], [p, q, bottom]]:
			var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			if n.y < 0 and tri[0] == top:
				n = -n
			for v in tri:
				st.set_normal(n)
				st.set_color(color if tri[0] == top else color.darkened(0.18))
				st.add_vertex(v)

static func _trunk(st: SurfaceTool, h: float, r: float, color: Color) -> void:
	for i in 4:
		var a := TAU * i / 4.0
		var b := TAU * (i + 1) / 4.0
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var q := Vector3(cos(b) * r, 0, sin(b) * r)
		var n := Vector3(cos((a + b) * 0.5), 0, sin((a + b) * 0.5))
		for v in [p, q, q + Vector3(0, h, 0), p, q + Vector3(0, h, 0), p + Vector3(0, h, 0)]:
			st.set_normal(n); st.set_color(color); st.add_vertex(v)

## Broadleaf cluster: 4 overlapping faceted crowns on a short trunk (unit height ~1).
static func broadleaf_cluster_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_trunk(st, 0.42, 0.035, Color(0.24, 0.20, 0.15))
	var greens := [Color(0.22, 0.34, 0.16), Color(0.27, 0.40, 0.18), Color(0.19, 0.30, 0.15), Color(0.30, 0.42, 0.20)]
	var lobes := [[Vector3(0, 0.66, 0), Vector3(0.34, 0.30, 0.32)], [Vector3(0.20, 0.55, 0.10), Vector3(0.24, 0.22, 0.22)], [Vector3(-0.18, 0.56, -0.08), Vector3(0.25, 0.22, 0.24)], [Vector3(0.02, 0.84, -0.04), Vector3(0.20, 0.18, 0.19)]]
	for i in lobes.size():
		_blob(st, lobes[i][0], lobes[i][1], greens[i], 7)
	return st.commit()

## Conifer: three stacked faceted cones (unit height 1).
static func conifer_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_trunk(st, 0.2, 0.03, Color(0.22, 0.18, 0.13))
	var tiers := [[0.16, 0.62, 0.30], [0.42, 0.84, 0.22], [0.64, 1.0, 0.14]]
	var cols := [Color(0.12, 0.24, 0.15), Color(0.14, 0.27, 0.16), Color(0.16, 0.30, 0.18)]
	for t in tiers.size():
		var base_y: float = tiers[t][0]
		var tip := Vector3(0, tiers[t][1], 0)
		var r: float = tiers[t][2]
		var sides := 6
		for i in sides:
			var a := TAU * i / sides
			var b := TAU * (i + 1) / sides
			var p := Vector3(cos(a) * r, base_y, sin(a) * r)
			var q := Vector3(cos(b) * r, base_y, sin(b) * r)
			var n := (q - p).cross(tip - p).normalized()
			if n.y < 0: n = -n
			for v in [p, tip, q]:
				st.set_normal(n); st.set_color(cols[t] if v == tip else cols[t].darkened(0.2)); st.add_vertex(v)
	return st.commit()

# ---------- ground ----------
static func _index(faces: PackedVector3Array) -> Dictionary:
	var bins := {}
	for i in range(0, faces.size(), 3):
		var a := faces[i]; var b := faces[i + 1]; var c := faces[i + 2]
		var lo := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
		var hi := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
		var mid := (lo + hi) * 0.5
		if mid.length() > R_MAX + 120.0 or sector_weight(mid) <= 0.0 and (hi - lo).length() < 200.0:
			continue
		for gz in range(floori(lo.y / GRID), floori(hi.y / GRID) + 1):
			for gx in range(floori(lo.x / GRID), floori(hi.x / GRID) + 1):
				var k := Vector2i(gx, gz)
				if not bins.has(k): bins[k] = PackedInt32Array()
				bins[k].append(i)
	return bins

static func _ground(faces: PackedVector3Array, bins: Dictionary, p: Vector2) -> Array:
	var best := -INF
	var normal_y := 1.0
	for i in bins.get(Vector2i(floori(p.x / GRID), floori(p.y / GRID)), PackedInt32Array()):
		var a := faces[i]; var b := faces[i + 1]; var c := faces[i + 2]
		var v0 := Vector2(b.x - a.x, b.z - a.z); var v1 := Vector2(c.x - a.x, c.z - a.z); var v2 := p - Vector2(a.x, a.z)
		var det := v0.cross(v1)
		if absf(det) < 0.000001: continue
		var u := v2.cross(v1) / det; var v := v0.cross(v2) / det
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			var h := a.y + u * (b.y - a.y) + v * (c.y - a.y)
			if h > best:
				best = h
				normal_y = absf((b - a).cross(c - a).normalized().y)
	return [best, normal_y]

static func _clear(p: Vector2, footprint: float) -> bool:
	if p.length() < R_MIN: return false
	if Lake.lake_distance(p) < 1.15 + footprint / 75.0: return false
	if p.distance_to(RUIN_A) < 40.0 + footprint: return false
	var ray := RUIN_A.normalized(); var along := p.dot(ray); var across := absf(p.cross(ray))
	if along > 85.0 - footprint and along < 180.0 + footprint and across < 14.0 + footprint: return false
	return true

# ---------- install ----------
static func paint_terrain(backdrop: Node3D, world: Node3D) -> Array:
	var changed := []
	var axis := Vector2(cos(deg_to_rad(AZ_CENTER)), sin(deg_to_rad(AZ_CENTER)))
	for name in ["MiddleRidge", "OuterFoothills"]:
		var node := backdrop.get_node_or_null(name) as MeshInstance3D
		if node == null: continue
		var old = node.material_override
		var mat := ShaderMaterial.new()
		mat.shader = PAINT
		var band := 1 if name == "OuterFoothills" else 0
		var tint := Color(1, 1, 1, 1)
		if old is ShaderMaterial:
			var b = old.get_shader_parameter("terrain_band")
			if b != null: band = int(b)
			var t = old.get_shader_parameter("original_tint")
			if t == null: t = old.get_shader_parameter("tint")
			if t != null: tint = t
		elif old is StandardMaterial3D:
			tint = old.albedo_color
		mat.set_shader_parameter("terrain_band", band)
		mat.set_shader_parameter("original_tint", tint)
		mat.set_shader_parameter("paint_dir", axis)
		mat.set_shader_parameter("paint_cos_full", cos(deg_to_rad(AZ_FULL)))
		mat.set_shader_parameter("paint_cos_edge", cos(deg_to_rad(AZ_EDGE)))
		# PR #5 reshapes MiddleRidge under the lake; keep the cut only without it.
		mat.set_shader_parameter("lake_cut", not (name == "MiddleRidge" and world.has_meta("inn_lake_mountain_fix")))
		node.set_meta("pre_far_test_material", old)
		node.material_override = mat
		changed.append(name)
	return changed

static func plant_clusters(backdrop: Node3D, root: Node3D) -> Dictionary:
	var faces: PackedVector3Array = backdrop.terrain_vertices
	var bins := _index(faces)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var meshes := [broadleaf_cluster_mesh(), conifer_mesh()]
	var groups := [[], []]
	var attempts := 0
	var accepted := 0
	while accepted < TARGET and attempts < TARGET * 30:
		attempts += 1
		var az := deg_to_rad(AZ_CENTER + rng.randf_range(-AZ_EDGE, AZ_EDGE))
		var r := sqrt(rng.randf_range(R_MIN * R_MIN, R_MAX * R_MAX))
		var p := Vector2(cos(az), sin(az)) * r
		var w := sector_weight(p)
		if rng.randf() > w: continue
		# Uneven woods: patches with meadow and rock openings, denser on lower slopes.
		var cover := 0.50 + 0.26 * sin(p.x * 0.031 + p.y * 0.017) + 0.20 * sin(p.y * 0.047 - p.x * 0.012) + 0.15 * sin(p.x * 0.11 + 1.3)
		if rng.randf() > cover: continue
		var kind := 1 if rng.randf() < (0.35 if r < 160.0 else 0.6) else 0
		var height := rng.randf_range(8.0, 13.0) * (1.0 + (r - R_MIN) / R_MAX * 0.6)
		var footprint := height * 0.35
		if not _clear(p, footprint): continue
		var g := _ground(faces, bins, p)
		var y: float = g[0]
		if not is_finite(y) or y < 0.6 or y > 70.0: continue
		if g[1] < 0.55: continue # too steep: leave rock showing
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(height * rng.randf_range(0.9, 1.25), height, height * rng.randf_range(0.9, 1.25)))
		var tint := Color(rng.randf_range(0.86, 1.08), rng.randf_range(0.9, 1.08), rng.randf_range(0.84, 1.0))
		if kind == 0 and rng.randf() < 0.06: tint = Color(1.25, 0.95, 0.7) # a few autumn crowns
		groups[kind].append([Transform3D(basis, Vector3(p.x, y - 0.3, p.y)), tint])
		accepted += 1
	var mat := ShaderMaterial.new()
	mat.shader = CANOPY
	var tris := 0
	var batches := 0
	for kind in 2:
		if groups[kind].is_empty(): continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes[kind]
		mm.instance_count = groups[kind].size()
		for i in groups[kind].size():
			mm.set_instance_transform(i, groups[kind][i][0])
			mm.set_instance_color(i, groups[kind][i][1])
		var node := MultiMeshInstance3D.new()
		node.name = "FarClusters" + ("Broadleaf" if kind == 0 else "Conifer")
		node.multimesh = mm
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 600.0
		root.add_child(node)
		tris += mm.instance_count * meshes[kind].get_faces().size() / 3
		batches += 1
	return {"instances": accepted, "broadleaf": groups[0].size(), "conifer": groups[1].size(), "triangles": tris, "batches": batches,
		"mesh_triangles": [meshes[0].get_faces().size() / 3, meshes[1].get_faces().size() / 3]}

static func apply(world: Node3D) -> Dictionary:
	if world.has_meta(META): return world.get_meta(META)
	var backdrop := world.get_node_or_null("ValleyBackdrop") as Node3D
	if backdrop == null or not backdrop.get("terrain_vertices") is PackedVector3Array:
		return {"ok": false, "reason": "ValleyBackdrop terrain unavailable"}
	var t0 := Time.get_ticks_usec()
	var root := Node3D.new()
	root.name = "FarSceneryStyleTest"
	var painted := paint_terrain(backdrop, world)
	var clusters := plant_clusters(backdrop, root)
	world.add_child(root)
	var result := {"ok": true, "sector_azimuth_deg": [AZ_CENTER - AZ_EDGE, AZ_CENTER + AZ_EDGE], "painted": painted, "build_ms": (Time.get_ticks_usec() - t0) / 1000.0}
	result.merge(clusters)
	world.set_meta(META, result)
	return result
