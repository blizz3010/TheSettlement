extends RefCounted
## TASKS item 9 far-scenery preview options, render-only, no pinned edits.
## A: painted hills plus a sparse treeline around the unfinished sectors.
## B: A, plus alpine/apron paint, layered ridge silhouettes, dense treeline.
## C: B, plus thickened dome ribs (the original 5.5 cm ribs are hidden).
## A and B hide the original thin ribs so the comparison is a clear yes/no.
##
## Toggle: env FAR_SCENERY_OPTION=off|A|B|C overrides PREVIEW below.
## Default is off so this branch matches main until a preview is requested.
## Apply after PR #5's lake fix so MiddleRidge keeps the reshaped mesh and
## lake_cut is turned off.

const PREVIEW := ""
const META := "far_scenery_option"
const SEED := 2026111509
const Lake := preload("res://scripts/inn_lake_v088.gd")
const Meshes := preload("res://raid/scripts/far_scenery_test.gd")
const PAINT := preload("res://raid/shaders/far_terrain_paint_v100.gdshader")
const CANOPY := preload("res://raid/shaders/far_canopy_v100.gdshader")
const RIDGE := preload("res://raid/shaders/far_ridge_silhouette_v100.gdshader")
const RIB := preload("res://raid/shaders/far_dome_rib_v100.gdshader")

const R_MIN := 74.0
const R_MAX := 330.0
const GRID := 8.0
const RUIN_A := Vector2(145, -95)
const SOUTH_AZ := -90.0
const SOUTH_HALF := 52.0
const RIB_COLOR := Color("93c4be")
const RIB_THICK := 0.055
const RIB_NEW_THICK := 0.28
const DOME_RX := 65.0
const DOME_RY := 42.0
const DOME_CY := -1.0

static func option_id() -> String:
	var env := OS.get_environment("FAR_SCENERY_OPTION").strip_edges().to_upper()
	if env == "":
		env = PREVIEW.strip_edges().to_upper()
	if env in ["A", "B", "C"]:
		return env
	return "OFF"


static func south_weight(p: Vector2) -> float:
	var az := rad_to_deg(atan2(p.y, p.x))
	var off := absf(wrapf(az - SOUTH_AZ, -180.0, 180.0))
	return 1.0 - smoothstep(SOUTH_HALF - 8.0, SOUTH_HALF + 4.0, off)


static func _index(faces: PackedVector3Array) -> Dictionary:
	var bins := {}
	for i in range(0, faces.size(), 3):
		var a := faces[i]
		var b := faces[i + 1]
		var c := faces[i + 2]
		var lo := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
		var hi := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
		var mid := (lo + hi) * 0.5
		if mid.length() > R_MAX + 120.0:
			continue
		for gz in range(floori(lo.y / GRID), floori(hi.y / GRID) + 1):
			for gx in range(floori(lo.x / GRID), floori(hi.x / GRID) + 1):
				var k := Vector2i(gx, gz)
				if not bins.has(k):
					bins[k] = PackedInt32Array()
				bins[k].append(i)
	return bins


static func _ground(faces: PackedVector3Array, bins: Dictionary, p: Vector2) -> Array:
	var best := -INF
	var normal_y := 1.0
	for i in bins.get(Vector2i(floori(p.x / GRID), floori(p.y / GRID)), PackedInt32Array()):
		var a := faces[i]
		var b := faces[i + 1]
		var c := faces[i + 2]
		var v0 := Vector2(b.x - a.x, b.z - a.z)
		var v1 := Vector2(c.x - a.x, c.z - a.z)
		var v2 := p - Vector2(a.x, a.z)
		var det := v0.cross(v1)
		if absf(det) < 0.000001:
			continue
		var u := v2.cross(v1) / det
		var v := v0.cross(v2) / det
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			var h := a.y + u * (b.y - a.y) + v * (c.y - a.y)
			if h > best:
				best = h
				normal_y = absf((b - a).cross(c - a).normalized().y)
	return [best, normal_y]


static func _clear(p: Vector2, footprint: float) -> bool:
	if p.length() < R_MIN:
		return false
	if Lake.lake_distance(p) < 1.15 + footprint / 75.0:
		return false
	if p.distance_to(RUIN_A) < 40.0 + footprint:
		return false
	var ray := RUIN_A.normalized()
	var along := p.dot(ray)
	var across := absf(p.cross(ray))
	if along > 85.0 - footprint and along < 180.0 + footprint and across < 14.0 + footprint:
		return false
	return true


static func _paint_node(node: MeshInstance3D, band: int, lake_cut: bool) -> void:
	var old = node.material_override
	var mat := ShaderMaterial.new()
	mat.shader = PAINT
	var tint := Color(1, 1, 1, 1)
	if old is ShaderMaterial:
		var b = old.get_shader_parameter("terrain_band")
		if b != null:
			band = int(b)
		var t = old.get_shader_parameter("original_tint")
		if t == null:
			t = old.get_shader_parameter("tint")
		if t != null:
			tint = t
	elif old is StandardMaterial3D:
		tint = old.albedo_color
	mat.set_shader_parameter("terrain_band", band)
	mat.set_shader_parameter("original_tint", tint)
	mat.set_shader_parameter("paint_full", true)
	mat.set_shader_parameter("south_protect", true)
	mat.set_shader_parameter("lake_cut", lake_cut)
	node.set_meta("pre_far_option_material", old)
	node.material_override = mat


static func paint_terrain(backdrop: Node3D, world: Node3D, opt: String) -> Array:
	var changed := []
	var lake_fixed := world.has_meta("inn_lake_mountain_fix")
	var jobs := [
		["MiddleRidge", 0, not lake_fixed],
		["OuterFoothills", 1, false],
		["ScenicGroundApron", 3, false],
	]
	if opt != "A":
		jobs.append(["DistantAlpineRange", 2, false])
	for job in jobs:
		var node := backdrop.get_node_or_null(job[0]) as MeshInstance3D
		if node == null:
			continue
		_paint_node(node, job[1], job[2])
		changed.append(job[0])
	return changed


static func plant_clusters(backdrop: Node3D, root: Node3D, opt: String) -> Dictionary:
	var faces: PackedVector3Array = backdrop.terrain_vertices
	var bins := _index(faces)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var meshes := [Meshes.broadleaf_cluster_mesh(), Meshes.conifer_mesh()]
	var groups := [[], []]
	var target := 480 if opt == "A" else 2100
	var attempts := 0
	var accepted := 0
	var r_lo := 140.0 if opt == "A" else R_MIN
	var r_hi := 230.0 if opt == "A" else R_MAX
	while accepted < target and attempts < target * 28:
		attempts += 1
		var az := rng.randf_range(-PI, PI)
		var r := sqrt(rng.randf_range(r_lo * r_lo, r_hi * r_hi))
		var p := Vector2(cos(az), sin(az)) * r
		if rng.randf() < south_weight(p):
			continue
		var cover: float
		if opt == "A":
			# Sparse crest band, with meadow gaps.
			cover = 0.22 + 0.16 * sin(p.x * 0.031 + p.y * 0.017) + 0.10 * sin(p.y * 0.047)
		else:
			cover = 0.54 + 0.24 * sin(p.x * 0.031 + p.y * 0.017) + 0.18 * sin(p.y * 0.047 - p.x * 0.012) + 0.12 * sin(p.x * 0.11 + 1.3)
			# Extra density along two treeline ridges.
			var crest := minf(absf(r - 175.0), absf(r - 280.0))
			if crest < 22.0:
				cover += 0.28
		if rng.randf() > clampf(cover, 0.0, 0.95):
			continue
		var kind := 1 if rng.randf() < (0.35 if r < 160.0 else 0.62) else 0
		var height := rng.randf_range(8.0, 13.0) * (1.0 + (r - R_MIN) / R_MAX * 0.6)
		if opt == "A":
			height *= 1.15
		var footprint := height * 0.35
		if not _clear(p, footprint):
			continue
		var g := _ground(faces, bins, p)
		var y: float = g[0]
		if not is_finite(y) or y < 0.6 or y > 70.0:
			continue
		if g[1] < 0.55:
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(height * rng.randf_range(0.9, 1.25), height, height * rng.randf_range(0.9, 1.25)))
		var tint := Color(rng.randf_range(0.86, 1.08), rng.randf_range(0.9, 1.08), rng.randf_range(0.84, 1.0))
		if kind == 0 and rng.randf() < 0.06:
			tint = Color(1.25, 0.95, 0.7)
		groups[kind].append([Transform3D(basis, Vector3(p.x, y - 0.3, p.y)), tint])
		accepted += 1
	var mat := ShaderMaterial.new()
	mat.shader = CANOPY
	var tris := 0
	var batches := 0
	for kind in 2:
		if groups[kind].is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes[kind]
		mm.instance_count = groups[kind].size()
		for i in groups[kind].size():
			mm.set_instance_transform(i, groups[kind][i][0])
			mm.set_instance_color(i, groups[kind][i][1])
		var node := MultiMeshInstance3D.new()
		node.name = "FarOptionClusters" + ("Broadleaf" if kind == 0 else "Conifer")
		node.multimesh = mm
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 620.0
		root.add_child(node)
		tris += mm.instance_count * meshes[kind].get_faces().size() / 3
		batches += 1
	return {"instances": accepted, "broadleaf": groups[0].size(), "conifer": groups[1].size(), "triangles": tris, "batches": batches,
		"mesh_triangles": [meshes[0].get_faces().size() / 3, meshes[1].get_faces().size() / 3]}


static func _ridge_ring(st: SurfaceTool, radius: float, height: float, phase: float, color: Color, segments: int) -> int:
	var tris := 0
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var wobble0 := 1.0 + 0.08 * sin(a0 * 5.0 + phase) + 0.04 * sin(a0 * 11.0)
		var wobble1 := 1.0 + 0.08 * sin(a1 * 5.0 + phase) + 0.04 * sin(a1 * 11.0)
		var h0 := height * (0.72 + 0.28 * (0.5 + 0.5 * sin(a0 * 3.0 + phase)))
		var h1 := height * (0.72 + 0.28 * (0.5 + 0.5 * sin(a1 * 3.0 + phase)))
		var inner0 := Vector3(cos(a0) * radius * 0.92 * wobble0, h0 * 0.15, sin(a0) * radius * 0.92 * wobble0)
		var inner1 := Vector3(cos(a1) * radius * 0.92 * wobble1, h1 * 0.15, sin(a1) * radius * 0.92 * wobble1)
		var crest0 := Vector3(cos(a0) * radius * wobble0, h0, sin(a0) * radius * wobble0)
		var crest1 := Vector3(cos(a1) * radius * wobble1, h1, sin(a1) * radius * wobble1)
		var outer0 := Vector3(cos(a0) * radius * 1.12 * wobble0, h0 * 0.20, sin(a0) * radius * 1.12 * wobble0)
		var outer1 := Vector3(cos(a1) * radius * 1.12 * wobble1, h1 * 0.20, sin(a1) * radius * 1.12 * wobble1)
		for tri in [[inner0, crest0, inner1], [inner1, crest0, crest1], [crest0, outer0, crest1], [crest1, outer0, outer1]]:
			var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			if n.y < 0:
				n = -n
			for v in tri:
				st.set_normal(n)
				st.set_color(color.darkened(0.08) if v.y < h0 * 0.5 else color)
				st.add_vertex(v)
			tris += 1
	return tris


static func add_layer_ridges(root: Node3D) -> Dictionary:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var t1 := _ridge_ring(st, 268.0, 52.0, 0.4, Color(0.22, 0.30, 0.22), 28)
	var t2 := _ridge_ring(st, 455.0, 88.0, 1.7, Color(0.30, 0.36, 0.38), 24)
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = RIDGE
	var node := MeshInstance3D.new()
	node.name = "FarOptionLayerRidges"
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 1400.0
	root.add_child(node)
	return {"triangles": t1 + t2, "rings": 2}


static func find_original_ribs(world: Node3D) -> Array:
	var ribs := []
	for child in world.get_children():
		if not (child is MeshInstance3D and child.mesh is BoxMesh):
			continue
		var sz: Vector3 = child.mesh.size
		if absf(sz.x - RIB_THICK) > 0.003 or absf(sz.y - RIB_THICK) > 0.003:
			continue
		var mat = child.material_override
		if mat is StandardMaterial3D and mat.albedo_color.is_equal_approx(RIB_COLOR):
			ribs.append(child)
	return ribs


static func hide_original_ribs(world: Node3D) -> int:
	var ribs := find_original_ribs(world)
	for rib in ribs:
		rib.set_meta("pre_far_option_visible", rib.visible)
		rib.visible = false
	return ribs.size()


static func _tube_segment(st: SurfaceTool, p1: Vector3, p2: Vector3, radius: float, color: Color, sides: int) -> void:
	var axis := p2 - p1
	var length := axis.length()
	if length < 0.0001:
		return
	var mid := (p1 + p2) * 0.5
	var basis := Basis.looking_at(axis.normalized(), Vector3.UP if absf(axis.normalized().y) < 0.92 else Vector3.RIGHT)
	# looking_at points -Z at the target; the tube runs along Z.
	var z := basis.z * (length * 0.5)
	var x := basis.x * radius
	var y := basis.y * radius
	for i in sides:
		var a := TAU * i / sides
		var b := TAU * (i + 1) / sides
		var r0 := x * cos(a) + y * sin(a)
		var r1 := x * cos(b) + y * sin(b)
		var q00 := mid - z + r0
		var q01 := mid - z + r1
		var q10 := mid + z + r0
		var q11 := mid + z + r1
		var n := ((q01 - q00).cross(q10 - q00)).normalized()
		for v in [q00, q01, q11, q00, q11, q10]:
			st.set_normal(n)
			st.set_color(color)
			st.add_vertex(v)


static func add_dome_ribs(root: Node3D) -> Dictionary:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 24
	var color := Color("93c4be")
	for a in range(0, 180, 30):
		for step in steps:
			var t0 := float(step) * PI / steps
			var t1 := float(step + 1) * PI / steps
			var p1 := Vector3(cos(t0) * DOME_RX, DOME_CY + sin(t0) * DOME_RY, 0).rotated(Vector3.UP, deg_to_rad(a))
			var p2 := Vector3(cos(t1) * DOME_RX, DOME_CY + sin(t1) * DOME_RY, 0).rotated(Vector3.UP, deg_to_rad(a))
			_tube_segment(st, p1, p2, RIB_NEW_THICK * 0.5, color, 5)
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = RIB
	var node := MeshInstance3D.new()
	node.name = "FarOptionDomeRibs"
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
	return {"triangles": mesh.get_faces().size() / 3, "thickness_m": RIB_NEW_THICK, "meridians": 6}


static func apply(world: Node3D) -> Dictionary:
	if world.has_meta(META):
		return world.get_meta(META)
	var opt := option_id()
	if opt == "OFF":
		var skipped := {"ok": true, "skipped": true, "option": "OFF"}
		world.set_meta(META, skipped)
		return skipped
	var backdrop := world.get_node_or_null("ValleyBackdrop") as Node3D
	if backdrop == null or not backdrop.get("terrain_vertices") is PackedVector3Array:
		return {"ok": false, "reason": "ValleyBackdrop terrain unavailable", "option": opt}
	var t0 := Time.get_ticks_usec()
	var root := Node3D.new()
	root.name = "FarSceneryOption" + opt
	var hidden := hide_original_ribs(world)
	var painted := paint_terrain(backdrop, world, opt)
	var clusters := plant_clusters(backdrop, root, opt)
	var ridges := {}
	var ribs := {}
	if opt != "A":
		ridges = add_layer_ridges(root)
	if opt == "C":
		ribs = add_dome_ribs(root)
	world.add_child(root)
	var result := {
		"ok": true,
		"skipped": false,
		"option": opt,
		"painted": painted,
		"hidden_original_ribs": hidden,
		"build_ms": (Time.get_ticks_usec() - t0) / 1000.0,
	}
	result.merge(clusters)
	if not ridges.is_empty():
		result["layer_ridges"] = ridges
	if not ribs.is_empty():
		result["dome_ribs"] = ribs
	world.set_meta(META, result)
	return result
