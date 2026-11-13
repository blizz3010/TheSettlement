extends RefCounted
## Reusable mid-stylized settlement dressing kit.
## Trees: irregular faceted inner mass + leaf-clump cards, visible forks,
## darker desaturated greens that sit next to the existing mid-distance trees.
## Ivy: fewer, larger leaf clusters instead of stringy single leaves.

const TREE_SEEDS := [11017, 22031, 33047, 44057]
const TREE_SPECS := [
	{"height": 5.70, "spread": 1.00, "lean": 0.05, "forks": 4},
	{"height": 5.35, "spread": 1.16, "lean": -0.04, "forks": 4},
	{"height": 4.55, "spread": 0.92, "lean": 0.07, "forks": 3},
	{"height": 6.35, "spread": 0.86, "lean": -0.03, "forks": 4}
]

static var _tree_templates: Array = []
static var _shared_mats: Dictionary = {}
static var _shared_meshes: Dictionary = {}


static func materials() -> Dictionary:
	if not _shared_mats.is_empty():
		return _shared_mats
	var out := {}
	out["leaf_mat"] = _mat(Color(1, 1, 1), 0.88, true)
	out["petal_mat"] = _mat(Color(1, 1, 1), 0.72, true)
	out["stem_mat"] = _mat(Color(0.30, 0.38, 0.20), 0.9, false)
	out["vine_stem"] = _mat(Color(0.26, 0.20, 0.12), 0.92, false)
	out["wood"] = _mat(Color(0.45, 0.30, 0.16), 0.78, false)
	out["wood_dark"] = _mat(Color(0.28, 0.17, 0.10), 0.84, false)
	out["wood_light"] = _mat(Color(0.58, 0.42, 0.26), 0.74, false)
	out["stone"] = _mat(Color(0.62, 0.56, 0.44), 0.88, false)
	out["stone_warm"] = _mat(Color(0.70, 0.62, 0.48), 0.86, false)
	out["soil"] = _mat(Color(0.22, 0.15, 0.10), 0.95, false)
	out["bronze"] = _mat(Color(0.42, 0.28, 0.12), 0.45, false, 0.55)
	out["trunk"] = _mat(Color(0.23, 0.16, 0.11), 0.90, false)
	out["trunk_dark"] = _mat(Color(0.16, 0.11, 0.08), 0.92, false)
	# Inner canopy mass: darker, desaturated olive, no vertex color.
	out["lobe"] = _mat(Color(0.15, 0.21, 0.13), 0.92, false)
	out["glass"] = _emissive(Color(1.0, 0.82, 0.48), Color(1.0, 0.72, 0.32), 2.4)
	out["ink"] = _mat(Color(0.93, 0.87, 0.70), 0.55, false)
	_shared_mats = out
	return out


static func meshes() -> Dictionary:
	if not _shared_meshes.is_empty():
		return _shared_meshes
	_shared_meshes = {
		"leaf": _leaf_mesh(),
		"clump": _clump_mesh(),
		"lobe": _faceted_lobe_mesh(),
		"grass": _grass_tuft_mesh(),
		"fern": _fern_mesh(),
		"flower_head": _flower_head_mesh(),
		"flower_stem": _flower_stem_mesh()
	}
	return _shared_meshes


static func add_tree(parent: Node3D, n: String, at: Vector3, variant: int, height_scale: float = 1.0, yaw: float = 0.0) -> Node3D:
	_ensure_tree_templates()
	var idx := variant % TREE_SPECS.size()
	var inst: Node3D = _tree_templates[idx].duplicate()
	inst.name = n
	inst.position = at
	inst.rotation.y = yaw
	inst.scale = Vector3(height_scale, height_scale, height_scale)
	parent.add_child(inst)
	return inst


static func variant_count() -> int:
	return TREE_SPECS.size()


static func _ensure_tree_templates() -> void:
	if _tree_templates.size() == TREE_SPECS.size():
		return
	_tree_templates.clear()
	var mats := materials()
	var msh := meshes()
	for i in range(TREE_SPECS.size()):
		var holder := Node3D.new()
		holder.name = "TreeVariant%d" % i
		_build_tree(holder, i, mats, msh)
		_tree_templates.append(holder)


static func _build_tree(tree: Node3D, variant: int, mats: Dictionary, msh: Dictionary) -> void:
	var spec: Dictionary = TREE_SPECS[variant]
	var rng := RandomNumberGenerator.new()
	rng.seed = TREE_SEEDS[variant]
	var height: float = spec["height"]
	var spread: float = spec["spread"]
	var lean: float = spec["lean"]
	var forks: int = spec["forks"]
	tree.rotation.z = lean

	# Visible trunk in two tones, slight taper, then a crown fork.
	_tube(tree, "TrunkBase", Vector3(0, 0, 0), Vector3(0.04, height * 0.28, 0.01), 0.20, 0.14, mats["trunk_dark"], true)
	_tube(tree, "TrunkMid", Vector3(0.04, height * 0.28, 0.01), Vector3(0.02, height * 0.52, -0.02), 0.14, 0.09, mats["trunk"], false)
	var fork_at := Vector3(0.02, height * 0.52, -0.02)
	_tube(tree, "TrunkToFork", fork_at, Vector3(0.05, height * 0.62, 0.0), 0.09, 0.07, mats["trunk"], false)

	var branches: Array = []
	for f in range(forks):
		var yaw := float(f) / float(forks) * TAU + rng.randf_range(-0.28, 0.28)
		var lift := rng.randf_range(0.38, 0.70)
		var length := rng.randf_range(1.15, 1.85) * spread
		var start: Vector3 = fork_at + Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.08, 0.12), rng.randf_range(-0.06, 0.06))
		var tip := start + Vector3(cos(yaw) * length, lift * length * 0.85 + rng.randf_range(0.1, 0.45), sin(yaw) * length)
		# Keep tips inside a reasonable crown, not a perfect sphere.
		tip.y = clampf(tip.y, height * 0.58, height * 0.96)
		_tube(tree, "Branch%d" % f, start, tip, 0.065, 0.032, mats["trunk"], false)
		branches.append({"from": start, "to": tip})
		# Secondary forks on most primaries, for a readable branch silhouette.
		if rng.randf() < 0.82:
			var mid: Vector3 = start.lerp(tip, rng.randf_range(0.45, 0.68))
			var yaw2 := yaw + rng.randf_range(0.7, 1.3) * (1.0 if f % 2 == 0 else -1.0)
			var length2 := length * rng.randf_range(0.40, 0.62)
			var tip2 := mid + Vector3(cos(yaw2) * length2, rng.randf_range(0.15, 0.55), sin(yaw2) * length2)
			tip2.y = clampf(tip2.y, height * 0.55, height * 0.98)
			_tube(tree, "Fork%d" % f, mid, tip2, 0.038, 0.020, mats["trunk"], false)
			branches.append({"from": mid, "to": tip2})

	# A couple of lower mid-story branches so the trunk isn't a bare pole.
	for k in range(2):
		var yaw := 1.1 + k * 2.3 + rng.randf_range(-0.2, 0.2)
		var start := Vector3(0.03, height * (0.34 + k * 0.08), 0.0)
		var tip := start + Vector3(cos(yaw) * 0.7 * spread, 0.25, sin(yaw) * 0.7 * spread)
		_tube(tree, "LowBranch%d" % k, start, tip, 0.045, 0.022, mats["trunk"], false)
		branches.append({"from": start, "to": tip})

	# Irregular faceted inner mass — 2–3 lumpy hulls, not a bubble cluster.
	var lobe_count := 2 if forks <= 3 else 3
	for i in range(lobe_count):
		var yaw := float(i) / float(lobe_count) * TAU + rng.randf_range(-0.3, 0.3)
		var center := Vector3(
			cos(yaw) * 0.45 * spread * rng.randf_range(0.4, 1.0),
			height * rng.randf_range(0.66, 0.82),
			sin(yaw) * 0.45 * spread * rng.randf_range(0.4, 1.0)
		)
		# Kept smaller than the clump shell so it only reads as inner shadow.
		var sx := rng.randf_range(1.00, 1.30) * spread
		var sy := rng.randf_range(0.70, 0.95)
		var sz := rng.randf_range(0.95, 1.25) * spread
		var mi := MeshInstance3D.new()
		mi.name = "InnerLobe%d" % i
		mi.mesh = msh["lobe"]
		mi.material_override = mats["lobe"]
		mi.position = center
		mi.scale = Vector3(sx, sy, sz)
		mi.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.0, TAU), rng.randf_range(-0.3, 0.3))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		tree.add_child(mi)

	# Leaf-clump cards along the branches, with gaps for silhouette breakup.
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for b in branches:
		var from_p: Vector3 = b["from"]
		var to_p: Vector3 = b["to"]
		var steps := 3
		for s in range(steps):
			if s < steps - 1 and rng.randf() < 0.12:
				continue  # leave mid-branch gaps
			var t := 0.45 + 0.50 * (float(s) / float(steps - 1))
			var p: Vector3 = from_p.lerp(to_p, t)
			var along: Vector3 = (to_p - from_p).normalized()
			# Spray a few clumps off the branch, not a spherical shell.
			var spray := 3 if s == steps - 1 else 2
			for j in range(spray):
				if rng.randf() < 0.08:
					continue
				var side := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.8), rng.randf_range(-1, 1))
				if side.length_squared() < 0.01:
					side = Vector3.UP
				side = side.normalized()
				# Avoid aligning with the branch too tightly.
				if absf(side.dot(along)) > 0.85:
					side = along.cross(Vector3.UP)
					if side.length_squared() < 0.01:
						side = Vector3.RIGHT
					side = side.normalized()
				var offset := side * rng.randf_range(0.15, 0.55) + along * rng.randf_range(-0.08, 0.20)
				var q: Vector3 = p + offset
				var scale := rng.randf_range(0.88, 1.32)
				if s == steps - 1:
					scale *= rng.randf_range(1.08, 1.28)
				xforms.append(_clump_xform(q, along, rng, scale))
				colors.append(_canopy_color(rng))
	# A few drooping edge clumps for a less-rounded hem.
	for i in range(6):
		var yaw := rng.randf_range(0.0, TAU)
		var q := Vector3(cos(yaw) * 1.15 * spread, height * rng.randf_range(0.58, 0.78), sin(yaw) * 1.15 * spread)
		xforms.append(_clump_xform(q, Vector3.UP, rng, rng.randf_range(0.85, 1.15)))
		colors.append(_canopy_color(rng))

	# Crown cover: clumps over the top of the crown (seen from elevated cameras),
	# grouped around the branch tips so the top stays lumpy with a few gaps.
	var tips: Array = []
	for b in branches:
		var tp: Vector3 = b["to"]
		if tp.y > height * 0.55:
			tips.append(tp)
	for tp in tips:
		var n := rng.randi_range(3, 5)
		for j in range(n):
			var off := Vector3(rng.randf_range(-0.55, 0.55), rng.randf_range(0.05, 0.45), rng.randf_range(-0.55, 0.55)) * spread
			var q: Vector3 = tp + off
			var up_dir := (q - Vector3(0, height * 0.62, 0)).normalized().lerp(Vector3.UP, 0.5)
			xforms.append(_clump_xform(q, up_dir, rng, rng.randf_range(1.0, 1.35)))
			colors.append(_canopy_color(rng))

	_spawn_colored(tree, "LeafClumps", msh["clump"], mats["leaf_mat"], xforms, colors, true)


static func _clump_xform(p: Vector3, along: Vector3, rng: RandomNumberGenerator, scale: float) -> Transform3D:
	var up := along
	if up.length_squared() < 0.0001:
		up = Vector3.UP
	else:
		up = up.normalized()
	var target := p + up
	var basis := Basis.looking_at(up, Vector3.UP if absf(up.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT)
	basis = basis.rotated(basis.y, rng.randf_range(0.0, TAU))
	basis = basis.rotated(basis.x, rng.randf_range(-0.35, 0.35))
	basis = basis.scaled(Vector3(scale, scale, scale))
	return Transform3D(basis, p)


static func _canopy_color(rng: RandomNumberGenerator) -> Color:
	# Darker, less saturated olives — sampled from the existing mid-distance tree.
	var palette := [
		Color(0.20, 0.31, 0.18),
		Color(0.24, 0.36, 0.22),
		Color(0.28, 0.40, 0.24),
		Color(0.22, 0.34, 0.26),
		Color(0.26, 0.37, 0.20),
		Color(0.18, 0.28, 0.17),
		Color(0.30, 0.40, 0.27)
	]
	var c: Color = palette[rng.randi_range(0, palette.size() - 1)]
	c.r = clampf(c.r + rng.randf_range(-0.02, 0.02), 0.14, 0.36)
	c.g = clampf(c.g + rng.randf_range(-0.02, 0.025), 0.24, 0.44)
	c.b = clampf(c.b + rng.randf_range(-0.02, 0.02), 0.14, 0.32)
	return c


static func ivy_clusters(
		leaves: Array[Transform3D],
		colors: Array[Color],
		rng: RandomNumberGenerator,
		face: float,
		y0: float,
		y1: float,
		a0: float,
		a1: float,
		outward: Vector3,
		keep_sign_window: bool,
		south_face: bool = false
	) -> void:
	outward = outward.normalized()
	# Climbing cover as spaced clusters, not a grid of tiny leaves.
	var a := a0 + 0.18
	var row := 0
	while a < a1:
		var y := y0 + 0.20 + (0.18 if row % 2 == 0 else 0.0)
		while y < y1 - 0.05:
			var jitter_a := rng.randf_range(-0.10, 0.10)
			var jitter_y := rng.randf_range(-0.08, 0.08)
			var aa := a + jitter_a
			var yy := y + jitter_y
			if aa < a0 or aa > a1 or yy < y0 or yy > y1:
				y += 0.48
				continue
			var p := _face_point(face, yy, aa, south_face) + outward * rng.randf_range(0.02, 0.08)
			if keep_sign_window and in_home_sign(p):
				y += 0.48
				continue
			if rng.randf() < 0.16:
				y += 0.48
				continue
			_push_cluster(leaves, colors, rng, p, outward, 0.30, 0.46, rng.randi_range(4, 6))
			y += 0.48
		a += 0.52
		row += 1
	# Hanging curtains: a few large clusters down each strand, not a string of singles.
	var strand_a := a0 + 0.22
	while strand_a < a1:
		if rng.randf() < 0.22:
			strand_a += rng.randf_range(0.50, 0.70)
			continue
		var length := rng.randf_range(1.15, 1.85)
		var bunches := 3
		for i in range(bunches):
			var t := float(i) / float(bunches - 1)
			var yy := y1 - 0.08 - t * length
			if yy < y0 + 0.08:
				break
			var sway := sin(strand_a * 1.7 + t * 2.2) * 0.10
			var p := _face_point(face, yy, strand_a + sway, south_face)
			p += outward * (0.05 + t * 0.12)
			if keep_sign_window and in_home_sign(p):
				continue
			_push_cluster(leaves, colors, rng, p, outward, 0.32, 0.50, 4)
		strand_a += rng.randf_range(0.50, 0.72)


static func hanging_trailers(
		leaves: Array[Transform3D],
		colors: Array[Color],
		rng: RandomNumberGenerator,
		origin: Vector3,
		outward: Vector3,
		count: int
	) -> void:
	outward = outward.normalized()
	for t in range(count):
		var length := rng.randf_range(0.85, 1.45)
		var ox := rng.randf_range(-0.10, 0.10)
		var oz := rng.randf_range(-0.10, 0.10)
		var bunches := 3
		for s in range(bunches):
			var u := float(s) / float(bunches - 1)
			var q: Vector3 = origin + outward * (0.06 + u * 0.12) + Vector3(ox, -u * length, oz)
			q.x += sin(u * 3.0 + t) * 0.05
			_push_cluster(leaves, colors, rng, q, outward, 0.26, 0.40, 4)


static func in_home_sign(p: Vector3) -> bool:
	return p.x >= -16.15 and p.x <= -15.55 and p.z >= 9.36 and p.z <= 11.44 and p.y >= 2.06 and p.y <= 2.78


static func _face_point(face: float, y: float, a: float, south_face: bool) -> Vector3:
	if south_face:
		return Vector3(a, y, face)
	return Vector3(face, y, a)


static func _push_cluster(
		leaves: Array[Transform3D],
		colors: Array[Color],
		rng: RandomNumberGenerator,
		p: Vector3,
		outward: Vector3,
		min_s: float,
		max_s: float,
		count: int
	) -> void:
	outward = outward.normalized()
	for i in range(count):
		var offset := Vector3(
			rng.randf_range(-0.08, 0.08),
			rng.randf_range(-0.08, 0.08),
			rng.randf_range(-0.08, 0.08)
		)
		var q: Vector3 = p + offset + outward * rng.randf_range(0.00, 0.05)
		_push_leaf(leaves, colors, rng, q, outward, min_s, max_s)


static func _push_leaf(
		leaves: Array[Transform3D],
		colors: Array[Color],
		rng: RandomNumberGenerator,
		p: Vector3,
		outward: Vector3,
		min_s: float,
		max_s: float
	) -> void:
	if outward.length_squared() < 0.0001:
		outward = Vector3.RIGHT
	else:
		outward = outward.normalized()
	var up := Vector3.UP.rotated(outward, rng.randf_range(-0.7, 0.7))
	if absf(up.dot(outward)) > 0.92:
		up = Vector3.UP
	var basis := Basis.looking_at(outward, up)
	basis = basis.rotated(outward, rng.randf_range(-0.55, 0.55))
	var tilt_axis: Vector3 = basis.x.normalized()
	basis = basis.rotated(tilt_axis, rng.randf_range(-0.45, 0.45))
	var s := rng.randf_range(min_s, max_s)
	basis = basis.scaled(Vector3(s, s, s * 0.55))
	leaves.append(Transform3D(basis, p))
	colors.append(_ivy_color(rng))


static func _ivy_color(rng: RandomNumberGenerator) -> Color:
	# A bit livelier than the tree canopy, still not lime.
	var palette := [
		Color(0.20, 0.34, 0.16),
		Color(0.24, 0.40, 0.18),
		Color(0.30, 0.44, 0.20),
		Color(0.22, 0.32, 0.16),
		Color(0.28, 0.38, 0.18),
		Color(0.34, 0.42, 0.20)
	]
	var c: Color = palette[rng.randi_range(0, palette.size() - 1)]
	c.r = clampf(c.r + rng.randf_range(-0.02, 0.02), 0.12, 0.40)
	c.g = clampf(c.g + rng.randf_range(-0.02, 0.03), 0.24, 0.50)
	return c


static func _tube(parent: Node3D, n: String, a: Vector3, b: Vector3, r0: float, r1: float, mat: Material, solid: bool) -> Node3D:
	var node := Node3D.new()
	node.name = n
	var mid: Vector3 = (a + b) * 0.5
	node.position = mid
	var dir: Vector3 = b - a
	var length := dir.length()
	if length < 0.001:
		parent.add_child(node)
		return node
	var y := dir / length
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 0.0001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z: Vector3 = x.cross(y).normalized()
	node.basis = Basis(x, y, z)
	parent.add_child(node)
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r1
	mesh.bottom_radius = r0
	mesh.height = length
	mesh.radial_segments = 8
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = mat
	node.add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		body.set_meta("audio_surface", "wood")
		var col := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = maxf(r0, r1)
		sh.height = length
		col.shape = sh
		body.add_child(col)
		node.add_child(body)
	return node


static func spawn_colored(
		root: Node3D,
		n: String,
		mesh: Mesh,
		mat: Material,
		xforms: Array[Transform3D],
		colors: Array[Color],
		cast_shadow: bool
	) -> void:
	_spawn_colored(root, n, mesh, mat, xforms, colors, cast_shadow)


static func spawn_plain(root: Node3D, n: String, mesh: Mesh, mat: Material, xforms: Array[Transform3D], cast_shadow: bool) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = n
	inst.multimesh = mm
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inst)


static func _spawn_colored(
		root: Node3D,
		n: String,
		mesh: Mesh,
		mat: Material,
		xforms: Array[Transform3D],
		colors: Array[Color],
		cast_shadow: bool
	) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i] if i < colors.size() else Color(0.22, 0.32, 0.20))
	var inst := MultiMeshInstance3D.new()
	inst.name = n
	inst.multimesh = mm
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inst)


static func _mat(color: Color, roughness: float, vertex_color: bool, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.vertex_color_use_as_albedo = vertex_color
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


static func _emissive(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(albedo, 0.35, false)
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	return m


static func _leaf_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array([
		Vector3(0, 0.55, 0.01),
		Vector3(0.22, 0.18, 0.01),
		Vector3(0.16, -0.12, 0.01),
		Vector3(0.0, -0.42, 0.01),
		Vector3(-0.14, -0.10, 0.01),
		Vector3(-0.20, 0.20, 0.01),
		Vector3(0.0, 0.08, 0.03)
	])
	var tris := PackedInt32Array([0, 1, 6, 1, 2, 6, 2, 3, 6, 3, 4, 6, 4, 5, 6, 5, 0, 6])
	for i in range(0, tris.size(), 3):
		_add_tri(st, pts[tris[i]], pts[tris[i + 1]], pts[tris[i + 2]], Color.WHITE)
		_add_tri(st, pts[tris[i]], pts[tris[i + 2]], pts[tris[i + 1]], Color.WHITE)
	st.generate_normals()
	return st.commit()


static func _clump_mesh() -> ArrayMesh:
	# One foliage puff: several faceted cards around a center, irregular outline.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in range(7):
		var yaw := float(i) / 7.0 * TAU + rng.randf_range(-0.2, 0.2)
		var pitch := rng.randf_range(-0.6, 0.8)
		var origin := Vector3(cos(yaw) * 0.18, sin(pitch) * 0.16, sin(yaw) * 0.18)
		var normal := (origin + Vector3(0, 0.12, 0)).normalized()
		var tangent := normal.cross(Vector3.UP)
		if tangent.length_squared() < 0.0001:
			tangent = normal.cross(Vector3.RIGHT)
		tangent = tangent.normalized()
		var bitan := normal.cross(tangent).normalized()
		var w := rng.randf_range(0.22, 0.34)
		var h := rng.randf_range(0.28, 0.44)
		var tip: Vector3 = origin + bitan * h + normal * 0.02
		var left: Vector3 = origin - tangent * w + bitan * h * 0.15
		var right: Vector3 = origin + tangent * w + bitan * h * 0.15
		var base: Vector3 = origin - bitan * h * 0.25
		_add_tri(st, base, left, tip, Color.WHITE)
		_add_tri(st, base, tip, right, Color.WHITE)
		_add_tri(st, base, tip, left, Color.WHITE)
		_add_tri(st, base, right, tip, Color.WHITE)
	st.generate_normals()
	return st.commit()


static func _faceted_lobe_mesh() -> ArrayMesh:
	# Low-poly irregular hull. Start with an octahedron, subdivide once, displace.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts := PackedVector3Array([
		Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1),
		Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0)
	])
	var faces := PackedInt32Array([
		0, 1, 2, 0, 2, 3, 0, 3, 4, 0, 4, 1,
		5, 2, 1, 5, 3, 2, 5, 4, 3, 5, 1, 4
	])
	# Subdivide once.
	var mid_cache := {}
	var new_faces := PackedInt32Array()
	var verts_out := verts.duplicate()
	for i in range(0, faces.size(), 3):
		var a := faces[i]
		var b := faces[i + 1]
		var c := faces[i + 2]
		var ab := _mid_index(verts_out, mid_cache, a, b)
		var bc := _mid_index(verts_out, mid_cache, b, c)
		var ca := _mid_index(verts_out, mid_cache, c, a)
		new_faces.append_array(PackedInt32Array([a, ab, ca, ab, b, bc, ca, bc, c, ab, bc, ca]))
	# Normalize, then apply low-frequency displacement so the hull stays lumpy, not spherical.
	for i in range(verts_out.size()):
		var v: Vector3 = verts_out[i]
		if v.length_squared() > 0.0001:
			v = v.normalized()
		var n := 0.22 * sin(v.x * 3.1 + v.z * 2.4) + 0.16 * sin(v.y * 4.2 + v.x * 1.7) + 0.10 * sin(v.z * 5.0)
		verts_out[i] = v * (0.5 + n)
	for i in range(0, new_faces.size(), 3):
		_add_tri(st, verts_out[new_faces[i]], verts_out[new_faces[i + 1]], verts_out[new_faces[i + 2]], Color.WHITE)
	st.generate_normals()
	return st.commit()


static func _mid_index(verts: PackedVector3Array, cache: Dictionary, a: int, b: int) -> int:
	var key := "%d-%d" % [mini(a, b), maxi(a, b)]
	if cache.has(key):
		return cache[key]
	var mid: Vector3 = (verts[a] + verts[b]) * 0.5
	var idx := verts.size()
	verts.append(mid)
	cache[key] = idx
	return idx


static func _grass_tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in range(11):
		var yaw := float(i) / 11.0 * TAU + rng.randf_range(-0.15, 0.15)
		var h := rng.randf_range(0.22, 0.48)
		var lean := rng.randf_range(0.05, 0.22)
		var w := rng.randf_range(0.018, 0.032)
		var dir := Vector3(cos(yaw), 0, sin(yaw))
		var base := dir * rng.randf_range(0.01, 0.05)
		var mid := base + dir * lean * 0.45 + Vector3(0, h * 0.55, 0)
		var tip := base + dir * lean + Vector3(0, h, 0)
		var side := dir.cross(Vector3.UP).normalized()
		var c := Color(1, 1, 1)
		_add_tri(st, base + side * w, mid + side * w * 0.7, mid - side * w * 0.7, c)
		_add_tri(st, base + side * w, mid - side * w * 0.7, base - side * w, c)
		_add_tri(st, mid + side * w * 0.7, tip, mid - side * w * 0.7, c)
		_add_tri(st, base + side * w, mid - side * w * 0.7, mid + side * w * 0.7, c)
		_add_tri(st, base + side * w, base - side * w, mid - side * w * 0.7, c)
		_add_tri(st, mid + side * w * 0.7, mid - side * w * 0.7, tip, c)
	st.generate_normals()
	return st.commit()


static func _fern_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Color.WHITE
	for f in range(6):
		var yaw := float(f) / 6.0 * TAU
		var dir := Vector3(cos(yaw), 0, sin(yaw))
		var side := dir.cross(Vector3.UP).normalized()
		var length := 0.55 if f % 2 == 0 else 0.42
		var segments := 7
		for s in range(segments):
			var u := float(s) / float(segments)
			var arch := Vector3(0, 0.18 + u * 0.22 - u * u * 0.25, 0)
			var p := dir * (u * length) + arch
			var leaflet := (1.0 - u) * 0.16 + 0.04
			var tip := p + side * leaflet + Vector3(0, 0.01, 0)
			var tip2 := p - side * leaflet + Vector3(0, 0.01, 0)
			var mid := p + dir * 0.03 + Vector3(0, 0.02, 0)
			_add_tri(st, p, mid, tip, c)
			_add_tri(st, p, tip, mid, c)
			_add_tri(st, p, mid, tip2, c)
			_add_tri(st, p, tip2, mid, c)
	st.generate_normals()
	return st.commit()


static func _flower_stem_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Color(0.32, 0.48, 0.18)
	for k in range(2):
		var base := Vector3(k * 0.05 - 0.02, 0, k * 0.04)
		var tip := base + Vector3(k * 0.03, 0.28 + k * 0.05, 0)
		var side := Vector3(0.012, 0, 0)
		_add_tri(st, base + side, tip + side, tip - side, c)
		_add_tri(st, base + side, tip - side, base - side, c)
		_add_tri(st, base + side, tip - side, tip + side, c)
		_add_tri(st, base + side, base - side, tip - side, c)
	st.generate_normals()
	return st.commit()


static func _flower_head_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := Color.WHITE
	for k in range(2):
		var tip := Vector3(k * 0.05 - 0.02, 0.28 + k * 0.05, k * 0.04) + Vector3(k * 0.03, 0, 0)
		for i in range(5):
			var ang := float(i) / 5.0 * TAU
			var radial := Vector3(cos(ang), 0.15, sin(ang)) * 0.09
			var petal_tip := tip + radial + Vector3(0, 0.04, 0)
			var a := tip + Vector3(cos(ang - 0.4) * 0.03, 0.01, sin(ang - 0.4) * 0.03)
			var b := tip + Vector3(cos(ang + 0.4) * 0.03, 0.01, sin(ang + 0.4) * 0.03)
			_add_tri(st, a, petal_tip, b, white)
			_add_tri(st, a, b, petal_tip, white)
		_add_tri(st, tip + Vector3(0.02, 0.02, 0), tip + Vector3(0, 0.03, 0.02), tip + Vector3(-0.02, 0.02, 0), white)
		_add_tri(st, tip + Vector3(-0.02, 0.02, 0), tip + Vector3(0, 0.03, -0.02), tip + Vector3(0.02, 0.02, 0), white)
	st.generate_normals()
	return st.commit()


static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 0.0000001:
		return
	n = n.normalized()
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(a)
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(c)
