extends RefCounted
## Mid-stylized hideout-approach style test, v3 (tree fix).
## v2 direction approved; sphere-cluster canopies replaced with mid-stylized
## broadleaf variants from settlement_visuals_kit.gd, and ivy tamed into
## larger, fewer clusters.
## Makes the everyday view of the bare retaining walls and stair approach
## obviously dressed: ivy and hanging plants on the wall faces, planters,
## a layered paving-to-turf border, fuller trees framing the stairs, and
## a few props. The 12x12 build turf, stairs and approach path stay clear.
## Hooked from raid/scripts/ship_settlement_preview.gd only.
## Procedural meshes are generated here because the kit foliage reads too
## low-poly / lollipop-like for a mid-stylized judgment.

const Kit = preload("res://raid/scripts/settlement_visuals_kit.gd")
const ROOT_NAME := "SettlementVisualsStyleTest"
const SEED := 20261113

static func apply(world: Node3D) -> Node3D:
	if world.has_node(ROOT_NAME):
		return world.get_node(ROOT_NAME)
	var root := Node3D.new()
	root.name = ROOT_NAME
	root.set_meta("visual_only", true)
	root.set_meta("style_test", "hideout_approach_v3")
	world.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var mats := _materials()
	var meshes := _meshes()
	_add_wall_ivy(root, rng, mats, meshes)
	_add_hanging_plants(root, rng, mats, meshes)
	_add_planters(root, rng, mats, meshes)
	_add_verge(root, rng, mats, meshes)
	_add_trees(root, rng, mats)
	_add_props(root, mats)
	_add_lights(root)
	var budget := _budget(root)
	root.set_meta("budget", budget)
	print("settlement_visuals_style_test v3 budget ", budget)
	return root


static func _materials() -> Dictionary:
	var out := {}
	out["leaf_mat"] = _mat(Color(1, 1, 1), 0.86, true)
	out["petal_mat"] = _mat(Color(1, 1, 1), 0.72, true)
	out["stem_mat"] = _mat(Color(0.33, 0.42, 0.18), 0.9, false)
	out["vine_stem"] = _mat(Color(0.28, 0.22, 0.12), 0.92, false)
	out["wood"] = _mat(Color(0.45, 0.30, 0.16), 0.78, false)
	out["wood_dark"] = _mat(Color(0.28, 0.17, 0.10), 0.84, false)
	out["wood_light"] = _mat(Color(0.58, 0.42, 0.26), 0.74, false)
	out["stone"] = _mat(Color(0.62, 0.56, 0.44), 0.88, false)
	out["stone_warm"] = _mat(Color(0.70, 0.62, 0.48), 0.86, false)
	out["soil"] = _mat(Color(0.22, 0.15, 0.10), 0.95, false)
	out["bronze"] = _mat(Color(0.42, 0.28, 0.12), 0.45, false, 0.55)
	out["trunk"] = _mat(Color(0.34, 0.23, 0.14), 0.88, false)
	out["trunk_dark"] = _mat(Color(0.24, 0.16, 0.10), 0.9, false)
	out["canopy_a"] = _mat(Color(0.22, 0.42, 0.16), 0.78, false)
	out["canopy_b"] = _mat(Color(0.30, 0.50, 0.18), 0.74, false)
	out["canopy_c"] = _mat(Color(0.40, 0.56, 0.20), 0.72, false)
	out["canopy_d"] = _mat(Color(0.28, 0.38, 0.16), 0.8, false)
	out["glass"] = _emissive(Color(1.0, 0.82, 0.48), Color(1.0, 0.72, 0.32), 2.4)
	out["ink"] = _mat(Color(0.93, 0.87, 0.70), 0.55, false)
	return out


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


static func _meshes() -> Dictionary:
	return {
		"leaf": _leaf_mesh(),
		"grass": _grass_tuft_mesh(),
		"fern": _fern_mesh(),
		"flower_head": _flower_head_mesh()
	}


static func _add_wall_ivy(root: Node3D, rng: RandomNumberGenerator, mats: Dictionary, meshes: Dictionary) -> void:
	# Leave ivy in front of the retaining stone courses (outer east face ~ -15.93).
	# "Your Home" plaque sits at (-15.91, 2.38, 10.40), 1.85 x 0.48 — keep a window.
	var leaves: Array[Transform3D] = []
	var colors: Array[Color] = []
	# East face, south of the stairs — the everyday hero wall.
	Kit.ivy_clusters(leaves, colors, rng, -15.80, 0.10, 2.95, 7.20, 13.28, Vector3.RIGHT, true)
	# East face, short strip north of the stairs before the stash porch.
	Kit.ivy_clusters(leaves, colors, rng, -15.80, 0.10, 2.95, 16.72, 17.95, Vector3.RIGHT, false)
	# South face, from the SE corner west along the approach.
	Kit.ivy_clusters(leaves, colors, rng, 6.82, 0.10, 2.95, -24.4, -16.15, Vector3.FORWARD * -1.0, false, true)
	# Porch east face, lighter (elevated cameras see it).
	Kit.ivy_clusters(leaves, colors, rng, -12.82, 0.10, 2.95, 18.15, 21.85, Vector3.RIGHT, false)
	_spawn_colored(root, "IvyLeaves", meshes["leaf"], mats["leaf_mat"], leaves, colors, true)


static func _ivy_panel(
		leaves: Array[Transform3D],
		colors: Array[Color],
		stems: Array[Transform3D],
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
	# Climbing cover.
	var z := a0
	while z < a1:
		var y := y0
		while y < y1:
			var jitter_a := rng.randf_range(-0.07, 0.07)
			var jitter_y := rng.randf_range(-0.05, 0.05)
			var a := z + jitter_a
			var yy := y + jitter_y
			if a < a0 or a > a1 or yy < y0 or yy > y1:
				y += 0.17
				continue
			var p := _face_point(face, yy, a, south_face) + outward * rng.randf_range(0.00, 0.07)
			if keep_sign_window and _in_home_sign(p):
				y += 0.17
				continue
			if rng.randf() < 0.12:
				y += 0.17
				continue
			_push_leaf(leaves, colors, rng, p, outward, 0.22, 0.34)
			if rng.randf() < 0.18:
				stems.append(_stem_xform(p - outward * 0.02, outward, 0.22, 0.028))
			y += 0.17
		z += 0.19
	# Hanging curtains from the coping.
	var strand_a := a0 + 0.12
	while strand_a < a1:
		if rng.randf() < 0.12:
			strand_a += rng.randf_range(0.28, 0.42)
			continue
		var length := rng.randf_range(1.35, 2.45)
		var steps := 10
		for i in range(steps):
			var t := float(i) / float(steps - 1)
			var yy := y1 - 0.04 - t * length
			if yy < y0 + 0.05:
				break
			var sway := sin(strand_a * 2.1 + t * 3.4) * 0.10
			var p := _face_point(face, yy, strand_a + sway, south_face)
			p += outward * (0.04 + t * 0.16)
			if keep_sign_window and _in_home_sign(p):
				continue
			_push_leaf(leaves, colors, rng, p, outward, 0.24, 0.36)
		strand_a += rng.randf_range(0.26, 0.40)


static func _face_point(face: float, y: float, a: float, south_face: bool) -> Vector3:
	if south_face:
		return Vector3(a, y, face)
	return Vector3(face, y, a)


static func _in_home_sign(p: Vector3) -> bool:
	return p.x >= -16.15 and p.x <= -15.55 and p.z >= 9.36 and p.z <= 11.44 and p.y >= 2.06 and p.y <= 2.78


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
	colors.append(_leaf_color(rng))


static func _leaf_color(rng: RandomNumberGenerator) -> Color:
	var palette := [
		Color(0.20, 0.38, 0.14),
		Color(0.26, 0.48, 0.16),
		Color(0.34, 0.54, 0.18),
		Color(0.44, 0.60, 0.20),
		Color(0.30, 0.42, 0.16),
		Color(0.50, 0.58, 0.22),
		Color(0.46, 0.36, 0.14)
	]
	var c: Color = palette[rng.randi_range(0, palette.size() - 1)]
	c.r = clampf(c.r + rng.randf_range(-0.03, 0.03), 0.08, 0.7)
	c.g = clampf(c.g + rng.randf_range(-0.03, 0.04), 0.18, 0.72)
	return c


static func _add_hanging_plants(root: Node3D, rng: RandomNumberGenerator, mats: Dictionary, meshes: Dictionary) -> void:
	# Baskets hang off the east coping, outside the top rail and off the 12x12 turf.
	var spots: Array[Vector3] = [
		Vector3(-15.88, 2.92, 8.15),
		Vector3(-15.88, 2.92, 9.15),
		Vector3(-15.88, 2.92, 12.15),
		Vector3(-15.88, 2.92, 12.95),
		Vector3(-15.88, 2.92, 17.25),
		Vector3(-18.4, 2.92, 6.88),
		Vector3(-20.8, 2.92, 6.88)
	]
	var leaves: Array[Transform3D] = []
	var colors: Array[Color] = []
	var i := 0
	for p in spots:
		var holder := Node3D.new()
		holder.name = "HangingBasket%02d" % i
		holder.position = p
		root.add_child(holder)
		_box(holder, "Rim", Vector3(0, 0.04, 0), Vector3(0.36, 0.08, 0.28), mats["wood"], false)
		_box(holder, "Bowl", Vector3(0, -0.05, 0), Vector3(0.30, 0.12, 0.24), mats["wood_dark"], false)
		_box(holder, "Soil", Vector3(0, 0.07, 0), Vector3(0.28, 0.04, 0.22), mats["soil"], false)
		var outward := Vector3.RIGHT if p.z > 7.3 else Vector3(0, 0, -1)
		# A few larger clusters at the lip, then short clustered trailers.
		for _j in range(4):
			var lip: Vector3 = p + Vector3(rng.randf_range(-0.10, 0.10), rng.randf_range(0.02, 0.14), rng.randf_range(-0.08, 0.08))
			Kit.hanging_trailers(leaves, colors, rng, lip, outward + Vector3(0, 0.5, 0), 1)
		Kit.hanging_trailers(leaves, colors, rng, p, outward, 3)
		i += 1
	_spawn_colored(root, "HangingLeaves", meshes["leaf"], mats["leaf_mat"], leaves, colors, true)


static func _add_planters(root: Node3D, rng: RandomNumberGenerator, mats: Dictionary, meshes: Dictionary) -> void:
	# Along the east wall base, both sides of the stairs, and the south wall foot.
	# Positions stay off the approach path and stair mouth.
	var specs := [
		{"at": Vector3(-15.42, 0.22, 8.05), "size": Vector3(0.42, 0.44, 1.20), "yaw": 0.0},
		{"at": Vector3(-15.42, 0.22, 10.40), "size": Vector3(0.42, 0.44, 1.40), "yaw": 0.0},
		{"at": Vector3(-15.42, 0.22, 12.22), "size": Vector3(0.42, 0.44, 1.05), "yaw": 0.0},
		{"at": Vector3(-15.42, 0.22, 17.20), "size": Vector3(0.42, 0.44, 0.95), "yaw": 0.0},
		{"at": Vector3(-18.55, 0.22, 6.48), "size": Vector3(1.25, 0.44, 0.42), "yaw": 0.0},
		{"at": Vector3(-21.40, 0.22, 6.48), "size": Vector3(1.20, 0.44, 0.42), "yaw": 0.0}
	]
	var tufts: Array[Transform3D] = []
	var tuft_colors: Array[Color] = []
	var ferns: Array[Transform3D] = []
	var fern_colors: Array[Color] = []
	var flowers: Array[Transform3D] = []
	var flower_colors: Array[Color] = []
	var i := 0
	for spec in specs:
		var at: Vector3 = spec["at"]
		var size: Vector3 = spec["size"]
		var holder := Node3D.new()
		holder.name = "Planter%02d" % i
		holder.position = at
		root.add_child(holder)
		_box(holder, "Box", Vector3(0, 0, 0), size, mats["stone"], true, "stone")
		_box(holder, "Cap", Vector3(0, size.y * 0.5 + 0.025, 0), Vector3(size.x + 0.05, 0.05, size.z + 0.05), mats["wood"], false)
		_box(holder, "Soil", Vector3(0, size.y * 0.5 + 0.01, 0), Vector3(size.x - 0.08, 0.06, size.z - 0.08), mats["soil"], false)
		var long_axis := Vector3(0, 0, 1) if size.z >= size.x else Vector3(1, 0, 0)
		var long := maxf(size.x, size.z)
		var count := 5
		for k in range(count):
			var u := (float(k) / float(count - 1) - 0.5) * (long - 0.25)
			var p := at + long_axis * u + Vector3(0, size.y * 0.5 + 0.08, 0)
			p += Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05))
			if k % 2 == 0:
				ferns.append(_plant_xform(p, rng, 0.85, 1.15))
				fern_colors.append(_leaf_color(rng))
			else:
				tufts.append(_plant_xform(p, rng, 0.9, 1.2))
				tuft_colors.append(_grass_color(rng))
			if rng.randf() < 0.85:
				var fp := p + Vector3(rng.randf_range(-0.12, 0.12), 0.02, rng.randf_range(-0.12, 0.12))
				flowers.append(_plant_xform(fp, rng, 0.85, 1.2))
				flower_colors.append(_flower_color(rng, k))
			# A little overflow down the face.
			if rng.randf() < 0.7:
				var over := p + Vector3(0.16 if at.x > -16.5 else 0.0, -0.18, 0.16 if at.z < 7.0 else 0.0)
				tufts.append(_plant_xform(over, rng, 0.7, 1.0))
				tuft_colors.append(_grass_color(rng))
		i += 1
	_spawn_colored(root, "PlanterGrass", meshes["grass"], mats["leaf_mat"], tufts, tuft_colors, false)
	_spawn_colored(root, "PlanterFerns", meshes["fern"], mats["leaf_mat"], ferns, fern_colors, false)
	_spawn_colored(root, "PlanterFlowers", meshes["flower_head"], mats["petal_mat"], flowers, flower_colors, false)
	_spawn_plain(root, "PlanterFlowerStems", _flower_stem_mesh(), mats["stem_mat"], flowers, false)


static func _add_verge(root: Node3D, rng: RandomNumberGenerator, mats: Dictionary, meshes: Dictionary) -> void:
	var tufts: Array[Transform3D] = []
	var tuft_colors: Array[Color] = []
	var ferns: Array[Transform3D] = []
	var fern_colors: Array[Color] = []
	var flowers: Array[Transform3D] = []
	var flower_colors: Array[Color] = []
	# Where paving meets turf, south of the stairs along the east wall foot.
	_scatter_rect(tufts, tuft_colors, ferns, fern_colors, flowers, flower_colors, rng,
		Rect2(Vector2(-15.15, 7.25), Vector2(3.4, 5.95)), 70, 22, 36)
	# South wall foot, west of the SE corner.
	_scatter_rect(tufts, tuft_colors, ferns, fern_colors, flowers, flower_colors, rng,
		Rect2(Vector2(-23.6, 6.15), Vector2(7.3, 0.85)), 40, 14, 22)
	# South shoulder of the stair / path (west of the paving, south of the rail).
	_scatter_rect(tufts, tuft_colors, ferns, fern_colors, flowers, flower_colors, rng,
		Rect2(Vector2(-11.6, 11.15), Vector2(3.1, 2.05)), 28, 10, 16)
	# North shoulder of the stair, east of the stash porch.
	_scatter_rect(tufts, tuft_colors, ferns, fern_colors, flowers, flower_colors, rng,
		Rect2(Vector2(-12.4, 16.75), Vector2(3.6, 1.35)), 18, 7, 10)
	_spawn_colored(root, "VergeGrass", meshes["grass"], mats["leaf_mat"], tufts, tuft_colors, false)
	_spawn_colored(root, "VergeFerns", meshes["fern"], mats["leaf_mat"], ferns, fern_colors, false)
	_spawn_colored(root, "VergeFlowers", meshes["flower_head"], mats["petal_mat"], flowers, flower_colors, false)
	_spawn_plain(root, "VergeFlowerStems", _flower_stem_mesh(), mats["stem_mat"], flowers, false)


static func _scatter_rect(
		tufts: Array[Transform3D],
		tuft_colors: Array[Color],
		ferns: Array[Transform3D],
		fern_colors: Array[Color],
		flowers: Array[Transform3D],
		flower_colors: Array[Color],
		rng: RandomNumberGenerator,
		rect: Rect2,
		n_grass: int,
		n_fern: int,
		n_flower: int
	) -> void:
	for i in range(n_grass):
		var p := _rand_in(rect, rng)
		if _blocked(p):
			continue
		p.y = 0.0
		tufts.append(_plant_xform(p, rng, 0.85, 1.35))
		tuft_colors.append(_grass_color(rng))
	for i in range(n_fern):
		var p := _rand_in(rect, rng)
		if _blocked(p):
			continue
		p.y = 0.0
		ferns.append(_plant_xform(p, rng, 0.9, 1.25))
		fern_colors.append(_leaf_color(rng))
	for i in range(n_flower):
		var p := _rand_in(rect, rng)
		if _blocked(p):
			continue
		p.y = 0.02
		flowers.append(_plant_xform(p, rng, 0.9, 1.3))
		flower_colors.append(_flower_color(rng, i))


static func _rand_in(rect: Rect2, rng: RandomNumberGenerator) -> Vector3:
	return Vector3(
		rng.randf_range(rect.position.x, rect.position.x + rect.size.x),
		0.0,
		rng.randf_range(rect.position.y, rect.position.y + rect.size.y)
	)


static func _blocked(p: Vector3) -> bool:
	# 12x12 build turf on top of the terrace.
	if p.x >= -30.0 and p.x <= -18.0 and p.z >= 9.0 and p.z <= 21.0 and p.y > 2.4:
		return true
	# Interior of the retaining volume (don't bury plants in the wall).
	if p.x <= -16.05 and p.x >= -32.0 and p.z >= 7.02 and p.z <= 22.98 and p.y < 2.9:
		return true
	# Stairs, including rails' inner volume.
	if p.x >= -16.2 and p.x <= -8.15 and p.z >= 13.32 and p.z <= 16.68:
		return true
	# Final approach slab (x -8.28..-5.68, z 10.0..16.6).
	if p.x >= -8.35 and p.x <= -5.60 and p.z >= 9.95 and p.z <= 16.65:
		return true
	# First approach path, ~2.6 m wide from (-5, 7) to (-7, 10).
	var a := Vector3(-5.0, 0, 7.0)
	var b := Vector3(-7.0, 0, 10.0)
	if _dist_to_segment(Vector3(p.x, 0, p.z), a, b) < 1.4:
		return true
	return false


static func _dist_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf(((p - a).dot(ab)) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _add_trees(root: Node3D, rng: RandomNumberGenerator, mats: Dictionary) -> void:
	# Framing trees use kit variants 0 and 1 — mid-stylized broadleaf, not sphere clusters.
	Kit.add_tree(root, "FrameTreeSouth", Vector3(-13.05, 0, 7.35), 0, 0.98, 0.55)
	Kit.add_tree(root, "FrameTreeNorth", Vector3(-11.55, 0, 18.20), 1, 1.05, -0.70)


static func _make_tree(parent: Node3D, n: String, at: Vector3, rng: RandomNumberGenerator, mats: Dictionary, height: float, lean: float) -> void:
	var tree := Node3D.new()
	tree.name = n
	tree.position = at
	tree.rotation.z = lean
	parent.add_child(tree)
	# Tapered trunk in two tones, with a couple of mid branches.
	_cylinder(tree, "TrunkBase", Vector3(0, 0.45, 0), 0.16, 0.22, 0.90, mats["trunk_dark"], true)
	_cylinder(tree, "TrunkMid", Vector3(0.02, 1.55, 0.01), 0.10, 0.16, 1.40, mats["trunk"], false)
	_cylinder(tree, "TrunkTop", Vector3(0.05, 2.55, -0.02), 0.06, 0.10, 0.85, mats["trunk"], false)
	_cylinder(tree, "BranchA", Vector3(0.35, 2.15, 0.10), 0.03, 0.055, 0.85, mats["trunk"], false).rotation = Vector3(0.4, 0.6, 1.05)
	_cylinder(tree, "BranchB", Vector3(-0.25, 2.35, -0.15), 0.028, 0.05, 0.70, mats["trunk"], false).rotation = Vector3(-0.3, -0.4, -0.95)
	_cylinder(tree, "BranchC", Vector3(0.10, 2.70, 0.25), 0.024, 0.045, 0.60, mats["trunk"], false).rotation = Vector3(0.8, 0.2, 0.2)
	# Irregular multi-lobe canopy — mid-stylized, not a lollipop.
	var lobes := [
		{"p": Vector3(0.05, height - 1.15, 0.0), "s": Vector3(1.85, 1.45, 1.75), "m": "canopy_b"},
		{"p": Vector3(0.85, height - 1.55, 0.45), "s": Vector3(1.25, 1.05, 1.20), "m": "canopy_c"},
		{"p": Vector3(-0.75, height - 1.45, 0.55), "s": Vector3(1.20, 1.10, 1.15), "m": "canopy_a"},
		{"p": Vector3(-0.35, height - 1.70, -0.80), "s": Vector3(1.15, 1.00, 1.10), "m": "canopy_d"},
		{"p": Vector3(0.55, height - 0.70, -0.35), "s": Vector3(1.10, 0.90, 1.05), "m": "canopy_c"},
		{"p": Vector3(0.15, height - 2.15, 0.70), "s": Vector3(1.00, 0.85, 0.95), "m": "canopy_a"},
		{"p": Vector3(-0.90, height - 2.00, -0.20), "s": Vector3(0.95, 0.80, 0.90), "m": "canopy_d"},
		{"p": Vector3(0.70, height - 2.05, -0.55), "s": Vector3(0.90, 0.75, 0.85), "m": "canopy_b"}
	]
	var i := 0
	for lobe in lobes:
		var s: Vector3 = lobe["s"] * rng.randf_range(0.92, 1.08)
		_sphere(tree, "Lobe%02d" % i, lobe["p"], s, mats[lobe["m"]], false)
		i += 1


static func _add_props(root: Node3D, mats: Dictionary) -> void:
	# Crates at the SE corner, lantern by the south stair rail, bench in the
	# grass court, and a small post sign at the path shoulder.
	var crates := Node3D.new()
	crates.name = "CrateStack"
	crates.position = Vector3(-15.10, 0, 7.35)
	root.add_child(crates)
	_box(crates, "CrateA", Vector3(0, 0.28, 0), Vector3(0.52, 0.56, 0.46), mats["wood"], true, "wood")
	_box(crates, "CrateABand", Vector3(0, 0.28, 0), Vector3(0.54, 0.06, 0.48), mats["wood_dark"], false)
	_box(crates, "CrateB", Vector3(0.46, 0.22, 0.12), Vector3(0.40, 0.44, 0.38), mats["wood_light"], true, "wood")
	_box(crates, "CrateBBand", Vector3(0.46, 0.22, 0.12), Vector3(0.42, 0.05, 0.40), mats["wood_dark"], false)
	_box(crates, "CrateC", Vector3(0.12, 0.66, 0.06), Vector3(0.34, 0.24, 0.32), mats["wood"], true, "wood")

	var lamp := Node3D.new()
	lamp.name = "LanternPost"
	lamp.position = Vector3(-10.15, 0, 12.68)
	root.add_child(lamp)
	_cylinder(lamp, "Post", Vector3(0, 1.05, 0), 0.045, 0.055, 2.10, mats["wood_dark"], true, "wood")
	_box(lamp, "Arm", Vector3(0.18, 2.08, 0), Vector3(0.36, 0.05, 0.05), mats["wood_dark"], false)
	_box(lamp, "Cap", Vector3(0.34, 2.22, 0), Vector3(0.26, 0.05, 0.26), mats["bronze"], false)
	_box(lamp, "Cage", Vector3(0.34, 2.02, 0), Vector3(0.20, 0.28, 0.20), mats["bronze"], false)
	_box(lamp, "Glass", Vector3(0.34, 2.02, 0), Vector3(0.16, 0.22, 0.16), mats["glass"], false)
	var light := OmniLight3D.new()
	light.name = "LanternGlow"
	light.position = Vector3(0.34, 2.02, 0)
	light.light_color = Color(1.0, 0.78, 0.48)
	light.light_energy = 1.35
	light.omni_range = 5.5
	light.shadow_enabled = false
	lamp.add_child(light)

	var bench := Node3D.new()
	bench.name = "GardenBench"
	bench.position = Vector3(-13.10, 0, 9.55)
	bench.rotation.y = -0.55
	root.add_child(bench)
	_box(bench, "Seat", Vector3(0, 0.42, 0), Vector3(1.36, 0.07, 0.42), mats["wood_light"], true, "wood")
	_box(bench, "SeatGap", Vector3(0, 0.445, 0.0), Vector3(1.30, 0.01, 0.08), mats["wood"], false)
	_box(bench, "Back", Vector3(0, 0.78, -0.18), Vector3(1.36, 0.36, 0.06), mats["wood"], false)
	_box(bench, "BackRail", Vector3(0, 0.98, -0.18), Vector3(1.40, 0.05, 0.07), mats["wood_dark"], false)
	_box(bench, "LegL", Vector3(-0.58, 0.21, 0), Vector3(0.08, 0.42, 0.36), mats["wood_dark"], true, "wood")
	_box(bench, "LegR", Vector3(0.58, 0.21, 0), Vector3(0.08, 0.42, 0.36), mats["wood_dark"], true, "wood")

	var sign := Node3D.new()
	sign.name = "HomePlotSign"
	sign.position = Vector3(-9.20, 0, 12.22)
	sign.rotation.y = -2.0
	root.add_child(sign)
	_cylinder(sign, "Post", Vector3(0, 0.55, 0), 0.035, 0.04, 1.10, mats["wood_dark"], true, "wood")
	_box(sign, "Board", Vector3(0, 1.12, 0.03), Vector3(0.62, 0.32, 0.05), mats["wood"], false)
	_box(sign, "Edge", Vector3(0, 1.12, 0.05), Vector3(0.66, 0.04, 0.03), mats["bronze"], false)
	var label := Label3D.new()
	label.name = "Caption"
	label.text = "Home plot"
	label.font_size = 52
	label.pixel_size = 0.0032
	label.modulate = Color("#ecddae")
	label.outline_modulate = Color(0.18, 0.12, 0.06, 0.9)
	label.outline_size = 6
	label.position = Vector3(0, 1.12, 0.07)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sign.add_child(label)


static func _add_lights(root: Node3D) -> void:
	# Short-range warm fills so the hero wall and planters read in shadow.
	# No shadows, tight range, so out-of-patch cameras stay unchanged.
	var wall := OmniLight3D.new()
	wall.name = "WallFill"
	wall.position = Vector3(-14.6, 1.85, 10.5)
	wall.light_color = Color(1.0, 0.86, 0.68)
	wall.light_energy = 0.70
	wall.omni_range = 6.5
	wall.shadow_enabled = false
	root.add_child(wall)
	var south := OmniLight3D.new()
	south.name = "SouthFill"
	south.position = Vector3(-18.5, 1.6, 7.4)
	south.light_color = Color(1.0, 0.88, 0.70)
	south.light_energy = 0.45
	south.omni_range = 5.0
	south.shadow_enabled = false
	root.add_child(south)


static func _plant_xform(p: Vector3, rng: RandomNumberGenerator, min_s: float, max_s: float) -> Transform3D:
	var yaw := rng.randf_range(0.0, TAU)
	var s := rng.randf_range(min_s, max_s)
	var basis := Basis.from_euler(Vector3(rng.randf_range(-0.08, 0.08), yaw, rng.randf_range(-0.08, 0.08)))
	basis = basis.scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s))
	return Transform3D(basis, p)


static func _grass_color(rng: RandomNumberGenerator) -> Color:
	var palette := [
		Color(0.28, 0.50, 0.16),
		Color(0.36, 0.56, 0.18),
		Color(0.44, 0.62, 0.20),
		Color(0.24, 0.42, 0.14),
		Color(0.50, 0.64, 0.22)
	]
	return palette[rng.randi_range(0, palette.size() - 1)]


static func _flower_color(rng: RandomNumberGenerator, i: int) -> Color:
	var palette := [
		Color(0.72, 0.30, 0.62),
		Color(0.86, 0.68, 0.20),
		Color(0.88, 0.42, 0.50),
		Color(0.92, 0.88, 0.78),
		Color(0.55, 0.38, 0.78),
		Color(0.90, 0.55, 0.22)
	]
	var c: Color = palette[(i + rng.randi_range(0, 2)) % palette.size()]
	c.r = clampf(c.r + rng.randf_range(-0.05, 0.05), 0.3, 1.0)
	c.g = clampf(c.g + rng.randf_range(-0.05, 0.05), 0.15, 1.0)
	c.b = clampf(c.b + rng.randf_range(-0.05, 0.05), 0.1, 1.0)
	return c


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
		mm.set_instance_color(i, colors[i] if i < colors.size() else Color(0.3, 0.5, 0.18))
	var inst := MultiMeshInstance3D.new()
	inst.name = n
	inst.multimesh = mm
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inst)


static func _spawn_plain(root: Node3D, n: String, mesh: Mesh, mat: Material, xforms: Array[Transform3D], cast_shadow: bool) -> void:
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


static func _box(parent: Node3D, n: String, pos: Vector3, size: Vector3, mat: Material, solid: bool, surface: String = "stone") -> Node3D:
	var node := Node3D.new()
	node.name = n
	node.position = pos
	parent.add_child(node)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	node.add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		body.set_meta("audio_surface", surface)
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		col.shape = sh
		body.add_child(col)
		node.add_child(body)
	return node


static func _cylinder(
		parent: Node3D,
		n: String,
		pos: Vector3,
		r_top: float,
		r_bottom: float,
		height: float,
		mat: Material,
		solid: bool,
		surface: String = "wood"
	) -> Node3D:
	var node := Node3D.new()
	node.name = n
	node.position = pos
	parent.add_child(node)
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bottom
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = mat
	node.add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		body.set_meta("audio_surface", surface)
		var col := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = maxf(r_top, r_bottom)
		sh.height = height
		col.shape = sh
		body.add_child(col)
		node.add_child(body)
	return node


static func _sphere(parent: Node3D, n: String, pos: Vector3, scale: Vector3, mat: Material, solid: bool) -> Node3D:
	var node := Node3D.new()
	node.name = n
	node.position = pos
	parent.add_child(node)
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 8
	mi.mesh = mesh
	mi.material_override = mat
	mi.scale = scale
	node.add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.5
		col.shape = sh
		col.scale = scale
		body.add_child(col)
		node.add_child(body)
	return node


static func _stem_xform(p: Vector3, outward: Vector3, length: float, radius: float) -> Transform3D:
	var basis := Basis.looking_at(outward, Vector3.UP)
	basis = basis.scaled(Vector3(radius, length, radius))
	return Transform3D(basis, p + Vector3(0, length * 0.5, 0))


static func _stem_box() -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 1, 1)
	return mesh


static func _leaf_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Asymmetric teardrop in XY, slight midrib thickness along Z.
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
		# Backface so leaves read from both sides under OpenGL3.
		_add_tri(st, pts[tris[i]], pts[tris[i + 2]], pts[tris[i + 1]], Color.WHITE)
	st.generate_normals()
	return st.commit()


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
		# Two-segment blade, tapered.
		_add_tri(st, base + side * w, mid + side * w * 0.7, mid - side * w * 0.7, c)
		_add_tri(st, base + side * w, mid - side * w * 0.7, base - side * w, c)
		_add_tri(st, mid + side * w * 0.7, tip, mid - side * w * 0.7, c)
		# Backfaces.
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
	# Petal clusters sit at stem height; green stems are a separate mesh.
	for k in range(2):
		var tip := Vector3(k * 0.05 - 0.02, 0.28 + k * 0.05, k * 0.04) + Vector3(k * 0.03, 0, 0)
		# Five petals around the tip. Vertex color on petals is white so
		# MultiMesh instance colors can tint them.
		for i in range(5):
			var ang := float(i) / 5.0 * TAU
			var radial := Vector3(cos(ang), 0.15, sin(ang)) * 0.09
			var petal_tip := tip + radial + Vector3(0, 0.04, 0)
			var a := tip + Vector3(cos(ang - 0.4) * 0.03, 0.01, sin(ang - 0.4) * 0.03)
			var b := tip + Vector3(cos(ang + 0.4) * 0.03, 0.01, sin(ang + 0.4) * 0.03)
			_add_tri(st, a, petal_tip, b, white)
			_add_tri(st, a, b, petal_tip, white)
		# Center disc, slightly golden — will also pick up instance tint.
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


static func _budget(root: Node3D) -> Dictionary:
	var triangles := 0
	var meshes := 0
	var instances := 0
	var lights := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
		var mesh: Mesh = node.mesh
		if mesh:
			for s in range(mesh.get_surface_count()):
				triangles += _mesh_tris(mesh)
	for node in root.find_children("*", "MultiMeshInstance3D", true, false):
		meshes += 1
		var mm: MultiMesh = node.multimesh
		if mm and mm.mesh:
			instances += mm.instance_count
			triangles += _mesh_tris(mm.mesh) * mm.instance_count
	for _node in root.find_children("*", "Light3D", true, false):
		lights += 1
	return {"triangles": triangles, "meshes": meshes, "instances": instances, "lights": lights}


static func _mesh_tris(mesh: Mesh) -> int:
	var total := 0
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
			total += int(arrays[Mesh.ARRAY_INDEX].size() / 3)
		elif arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
			total += int(arrays[Mesh.ARRAY_VERTEX].size() / 3)
	return total
