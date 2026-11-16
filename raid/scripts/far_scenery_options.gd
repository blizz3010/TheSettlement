extends RefCounted
## TASKS item 9 far scenery, option B, render-only, no pinned edits.
## On by default in the normal game (play_title → ship settlement).
## FAR_SCENERY_OPTION=off (also 0 / false) turns it off for tests and benches.
## Paints unfinished hills and the alpine backdrop, plants a dense treeline,
## and adds low-detail layered ridge silhouettes with a varied skyline.
## Original 5.5 cm dome ribs are hidden at runtime; settlement.gd is not edited.
## Apply after PR #5's lake fix so MiddleRidge keeps the reshaped mesh and
## lake_cut is turned off.

const META := "far_scenery_option"
const SEED := 2026111509
const Lake := preload("res://scripts/inn_lake_v088.gd")
const Meshes := preload("res://raid/scripts/far_scenery_test.gd")
const PAINT := preload("res://raid/shaders/far_terrain_paint_v100.gdshader")
const CANOPY := preload("res://raid/shaders/far_canopy_v100.gdshader")
const RIDGE := preload("res://raid/shaders/far_ridge_silhouette_v100.gdshader")

const R_MIN := 74.0
const R_MAX := 330.0
const GRID := 8.0
const RUIN_A := Vector2(145, -95)
const SOUTH_AZ := -90.0
const SOUTH_HALF := 52.0
const RIB_COLOR := Color("93c4be")
const RIB_THICK := 0.055


static func enabled() -> bool:
	var env := OS.get_environment("FAR_SCENERY_OPTION").strip_edges().to_lower()
	return env not in ["off", "0", "false"]


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


static func paint_terrain(backdrop: Node3D, world: Node3D) -> Array:
	var changed := []
	var lake_fixed := world.has_meta("inn_lake_mountain_fix")
	var jobs := [
		["MiddleRidge", 0, not lake_fixed],
		["OuterFoothills", 1, false],
		["ScenicGroundApron", 3, false],
		["DistantAlpineRange", 2, false],
	]
	for job in jobs:
		var node := backdrop.get_node_or_null(job[0]) as MeshInstance3D
		if node == null:
			continue
		_paint_node(node, job[1], job[2])
		changed.append(job[0])
	return changed


static func plant_clusters(backdrop: Node3D, root: Node3D) -> Dictionary:
	var faces: PackedVector3Array = backdrop.terrain_vertices
	var bins := _index(faces)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var meshes := [Meshes.broadleaf_cluster_mesh(), Meshes.conifer_mesh()]
	var groups := [[], []]
	var target := 2100
	var attempts := 0
	var accepted := 0
	while accepted < target and attempts < target * 28:
		attempts += 1
		var az := rng.randf_range(-PI, PI)
		var r := sqrt(rng.randf_range(R_MIN * R_MIN, R_MAX * R_MAX))
		var p := Vector2(cos(az), sin(az)) * r
		if rng.randf() < south_weight(p):
			continue
		var cover := 0.54 + 0.24 * sin(p.x * 0.031 + p.y * 0.017) + 0.18 * sin(p.y * 0.047 - p.x * 0.012) + 0.12 * sin(p.x * 0.11 + 1.3)
		var crest := minf(absf(r - 175.0), absf(r - 280.0))
		if crest < 22.0:
			cover += 0.28
		if rng.randf() > clampf(cover, 0.0, 0.95):
			continue
		var kind := 1 if rng.randf() < (0.35 if r < 160.0 else 0.62) else 0
		var height := rng.randf_range(8.0, 13.0) * (1.0 + (r - R_MIN) / R_MAX * 0.6)
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
		node.name = "FarSceneryClusters" + ("Broadleaf" if kind == 0 else "Conifer")
		node.multimesh = mm
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 620.0
		root.add_child(node)
		tris += mm.instance_count * meshes[kind].get_faces().size() / 3
		batches += 1
	return {"instances": accepted, "broadleaf": groups[0].size(), "conifer": groups[1].size(), "triangles": tris, "batches": batches,
		"mesh_triangles": [meshes[0].get_faces().size() / 3, meshes[1].get_faces().size() / 3]}


static func _ridge_profile(az: float, phase: float) -> Vector2:
	# x = radius scale, y = height scale. Several frequencies plus a few
	# mountain passes so the skyline is a range, not a flat band.
	# Keep wobble modest so the inner foot stays outside the lake (~206 m).
	var r := 1.0 + 0.06 * sin(az * 3.0 + phase) + 0.04 * sin(az * 5.0 - phase * 1.3) + 0.02 * sin(az * 11.0 + phase * 0.4)
	var longw := 0.62 + 0.38 * sin(az * 2.0 + phase)
	var peaks := 0.0
	var freqs := [3.0, 5.0, 8.0, 13.0]
	var amps := [0.22, 0.16, 0.12, 0.08]
	for k in 4:
		var ph := phase * (1.0 + 0.37 * k) + k * 1.7
		var s := 0.5 + 0.5 * sin(az * freqs[k] + ph)
		peaks += amps[k] * pow(s, 2.4)
	var h := 0.38 * longw + peaks - 0.035 * absf(sin(az * 7.0 - phase))
	var pass_w := 0.0
	for p in 3:
		var center := phase + p * 2.15
		var d := absf(wrapf(az - center, -PI, PI))
		var width := 0.22 + 0.08 * sin(phase + p)
		pass_w = maxf(pass_w, 1.0 - smoothstep(0.0, width, d))
	h *= lerpf(1.0, 0.30, pass_w * 0.85)
	h *= 1.0 + 0.04 * sin(az * 23.0 + phase)
	return Vector2(r, clampf(h, 0.20, 1.20))


static func _ridge_ring(st: SurfaceTool, radius: float, height: float, phase: float, color: Color, segments: int) -> int:
	var tris := 0
	var rows := 5
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var p0 := _ridge_profile(a0, phase)
		var p1 := _ridge_profile(a1, phase)
		# Narrow, steep ridge so the inner slope is a horizon silhouette, not a
		# ramp across the valley or the lake (far shore is ~206 m from origin).
		var h0 := height * p0.y
		var h1 := height * p1.y
		var ring0 := [
			Vector3(cos(a0) * radius * p0.x * 0.96, h0 * 0.18, sin(a0) * radius * p0.x * 0.96),
			Vector3(cos(a0) * radius * p0.x * 0.98, h0 * 0.62, sin(a0) * radius * p0.x * 0.98),
			Vector3(cos(a0) * radius * p0.x, h0, sin(a0) * radius * p0.x),
			Vector3(cos(a0) * radius * p0.x * 1.05, h0 * 0.58, sin(a0) * radius * p0.x * 1.05),
			Vector3(cos(a0) * radius * p0.x * 1.08, h0 * 0.16, sin(a0) * radius * p0.x * 1.08),
		]
		var ring1 := [
			Vector3(cos(a1) * radius * p1.x * 0.96, h1 * 0.18, sin(a1) * radius * p1.x * 0.96),
			Vector3(cos(a1) * radius * p1.x * 0.98, h1 * 0.62, sin(a1) * radius * p1.x * 0.98),
			Vector3(cos(a1) * radius * p1.x, h1, sin(a1) * radius * p1.x),
			Vector3(cos(a1) * radius * p1.x * 1.05, h1 * 0.58, sin(a1) * radius * p1.x * 1.05),
			Vector3(cos(a1) * radius * p1.x * 1.08, h1 * 0.16, sin(a1) * radius * p1.x * 1.08),
		]
		var crest_frac := [0.0, 0.45, 1.0, 0.42, 0.0]
		for row in range(rows - 1):
			var quad := [ring0[row], ring0[row + 1], ring1[row], ring1[row + 1]]
			for tri in [[quad[0], quad[1], quad[2]], [quad[2], quad[1], quad[3]]]:
				var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
				if n.y < 0.0:
					n = -n
				for vi in 3:
					var v: Vector3 = tri[vi]
					var cf: float = crest_frac[row] if vi == 0 or (vi == 2 and tri == [quad[0], quad[1], quad[2]]) else crest_frac[row + 1]
					# The two mid/crest vertices of the first tri: index 1 is row+1 of ring0.
					if tri == [quad[0], quad[1], quad[2]]:
						cf = [crest_frac[row], crest_frac[row + 1], crest_frac[row]][vi]
					else:
						cf = [crest_frac[row], crest_frac[row + 1], crest_frac[row + 1]][vi]
					var col := color.lerp(color.darkened(0.18), 1.0 - cf)
					col.a = cf
					st.set_normal(n)
					st.set_color(col)
					st.add_vertex(v)
				tris += 1
	return tris


static func add_layer_ridges(root: Node3D) -> Dictionary:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Nearer green foothills, farther cooler alpine backdrop. Low triangle count.
	# Crests sit well behind the lake (far shore ~206 m). Even with wobble and
	# the inner foot at 0.96, the near ring stays outside ~285 m.
	var t1 := _ridge_ring(st, 320.0, 72.0, 0.4, Color(0.22, 0.30, 0.22), 40)
	var t2 := _ridge_ring(st, 510.0, 118.0, 1.7, Color(0.32, 0.38, 0.42), 36)
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = RIDGE
	var node := MeshInstance3D.new()
	node.name = "FarSceneryLayerRidges"
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


static func apply(world: Node3D) -> Dictionary:
	if world.has_meta(META):
		return world.get_meta(META)
	if not enabled():
		var skipped := {"ok": true, "skipped": true, "option": "OFF"}
		world.set_meta(META, skipped)
		return skipped
	var backdrop := world.get_node_or_null("ValleyBackdrop") as Node3D
	if backdrop == null or not backdrop.get("terrain_vertices") is PackedVector3Array:
		return {"ok": false, "reason": "ValleyBackdrop terrain unavailable"}
	var t0 := Time.get_ticks_usec()
	var root := Node3D.new()
	root.name = "FarScenery"
	var hidden := hide_original_ribs(world)
	var painted := paint_terrain(backdrop, world)
	var clusters := plant_clusters(backdrop, root)
	var ridges := add_layer_ridges(root)
	world.add_child(root)
	var result := {
		"ok": true,
		"skipped": false,
		"option": "B",
		"painted": painted,
		"hidden_original_ribs": hidden,
		"layer_ridges": ridges,
		"build_ms": (Time.get_ticks_usec() - t0) / 1000.0,
	}
	result.merge(clusters)
	world.set_meta(META, result)
	return result
