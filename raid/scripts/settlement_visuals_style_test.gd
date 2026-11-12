extends RefCounted
## Contained mid-stylized dressing around the hideout terrace foot and stair approach.
## Reuses existing settlement foliage assets. Does not plant on the 12x12 build turf.
## Hooked from the unpinned ship_settlement_preview adapter only.

const ROOT_NAME := "SettlementVisualsStyleTest"
const TURF_MIN := Vector2(-30.0, 9.0)
const TURF_MAX := Vector2(-18.0, 21.0)
const PATH_CLEAR := 1.15

const ASSETS := {
	"grass": "res://assets/groundcover/ground_grass_a.glb",
	"fern": "res://assets/groundcover/ground_fern_a.glb",
	"shrub": "res://assets/groundcover/ground_shrub_a.glb",
	"flower_p": "res://assets/groundcover/ground_flowers_purple.glb",
	"flower_y": "res://assets/groundcover/ground_flowers_yellow.glb",
	"mound": "res://assets/planting_dense/compact_broadleaf_mound.glb",
	"rock": "res://assets/planting_dense/small_rock_group.glb",
	"tree": "res://assets/kit/reference_broadleaf_tree_a.glb",
	"shrub_kit_a": "res://assets/kit/reference_low_shrub_a.glb",
	"shrub_kit_b": "res://assets/kit/reference_low_shrub_b.glb"
}

static func apply(world: Node3D) -> Node3D:
	if world.has_node(ROOT_NAME):
		return world.get_node(ROOT_NAME)
	var root := Node3D.new()
	root.name = ROOT_NAME
	root.set_meta("visual_only", true)
	root.set_meta("style_test", "hideout_terrace_foot")
	world.add_child(root)
	var templates := _load_templates()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261112
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var placements: Dictionary = {}
	for key in templates.keys():
		placements[key] = []
	# Foot bands around the 16x16 retaining wall, plus stair-approach shoulders.
	_scatter_band(placements, rng, space, world, "south_foot", Vector2(-31.2, 5.55), Vector2(-16.6, 6.95), 78)
	_scatter_band(placements, rng, space, world, "north_foot", Vector2(-31.2, 23.15), Vector2(-16.6, 24.55), 70)
	_scatter_band(placements, rng, space, world, "west_foot", Vector2(-33.15, 7.4), Vector2(-32.15, 22.6), 64)
	_scatter_band(placements, rng, space, world, "east_south", Vector2(-16.15, 7.3), Vector2(-14.85, 13.15), 36)
	_scatter_band(placements, rng, space, world, "east_north", Vector2(-16.15, 16.85), Vector2(-14.85, 22.7), 36)
	_scatter_band(placements, rng, space, world, "approach_s", Vector2(-11.6, 10.4), Vector2(-8.4, 13.6), 28)
	_scatter_band(placements, rng, space, world, "approach_n", Vector2(-11.6, 16.4), Vector2(-8.4, 19.4), 26)
	_instance_batches(root, templates, placements)
	_add_feature_trees(root, templates, space, world)
	_add_wall_vines(root)
	_add_local_light(root)
	_record_budget(root)
	print("SETTLEMENT_VISUALS_STYLE_TEST ", root.get_meta("budget"))
	return root

static func _load_templates() -> Dictionary:
	var out := {}
	for key in ASSETS.keys():
		var path: String = ASSETS[key]
		if not ResourceLoader.exists(path):
			continue
		var packed = load(path)
		if packed == null:
			continue
		var inst: Node = packed.instantiate()
		var meshes: Array = inst.find_children("*", "MeshInstance3D", true, false)
		if meshes.is_empty():
			inst.free()
			continue
		var mesh: Mesh = meshes[0].mesh
		var mat: Material = meshes[0].material_override
		if mat == null and mesh != null and mesh.get_surface_count() > 0:
			mat = mesh.surface_get_material(0)
		out[key] = {"mesh": mesh, "material": mat}
		inst.free()
	return out

static func _ground_at(space: PhysicsDirectSpaceState3D, xz: Vector2, exclude: Array = []) -> Dictionary:
	var from := Vector3(xz.x, 14.0, xz.y)
	var to := Vector3(xz.x, -4.0, xz.y)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = exclude
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return {}
	if hit.normal.y < 0.55:
		return {}
	return hit

static func _on_build_turf(xz: Vector2, y: float) -> bool:
	# Raised turf and a small inward margin. Ground-level foot planting is allowed.
	if y < 2.4:
		return false
	return xz.x >= TURF_MIN.x and xz.x <= TURF_MAX.x and xz.y >= TURF_MIN.y and xz.y <= TURF_MAX.y

static func _on_stairs_or_path(xz: Vector2) -> bool:
	# Authored stair volume and the stone approach path.
	# Lower and upper flights run near x[-8.3, -16] at z=15, width ~3.2 m.
	if absf(xz.y - 15.0) < 1.75 and xz.x > -16.4 and xz.x < -7.9:
		return true
	# Mid landing around (-12.14, 15)
	if xz.distance_to(Vector2(-12.14, 15.0)) < 1.5:
		return true
	# Approach path samples from hideout_terrace.gd: (-5,7), (-7,10), (-8.28,15)
	if _dist_segment(xz, Vector2(-5.0, 7.0), Vector2(-7.0, 10.0)) < PATH_CLEAR:
		return true
	if _dist_segment(xz, Vector2(-7.0, 10.0), Vector2(-8.28, 15.0)) < PATH_CLEAR:
		return true
	# West trader apron / paving near (-7, 2)
	if xz.distance_to(Vector2(-7.0, 2.0)) < 3.4:
		return true
	return false

static func _dist_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 0.0001 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func _scatter_band(placements: Dictionary, rng: RandomNumberGenerator, space: PhysicsDirectSpaceState3D, world: Node3D, _label: String, mn: Vector2, mx: Vector2, count: int) -> void:
	var exclude: Array = []
	if is_instance_valid(world.get("player")):
		exclude.append(world.player.get_rid())
	var accepted := 0
	var attempts := 0
	while accepted < count and attempts < count * 8:
		attempts += 1
		var xz := Vector2(rng.randf_range(mn.x, mx.x), rng.randf_range(mn.y, mx.y))
		if _on_stairs_or_path(xz):
			continue
		var hit := _ground_at(space, xz, exclude)
		if hit.is_empty():
			continue
		var y: float = hit.position.y
		if _on_build_turf(xz, y):
			continue
		# Keep plants on the lower grade around the terrace, not up on the cap.
		if y > 1.15:
			continue
		var roll := rng.randf()
		var key := "grass"
		var scale := rng.randf_range(0.85, 1.25)
		if roll < 0.42:
			key = "grass"
			scale = rng.randf_range(0.9, 1.45)
		elif roll < 0.62:
			key = "fern"
			scale = rng.randf_range(0.75, 1.15)
		elif roll < 0.76:
			key = "flower_p" if rng.randf() < 0.55 else "flower_y"
			scale = rng.randf_range(0.8, 1.2)
		elif roll < 0.90:
			key = "shrub"
			scale = rng.randf_range(0.85, 1.2)
		elif roll < 0.96:
			key = "mound"
			scale = rng.randf_range(0.7, 1.05)
		else:
			key = "rock"
			scale = rng.randf_range(0.7, 1.1)
		if not placements.has(key):
			continue
		var yaw := rng.randf_range(0.0, TAU)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
		# Sit slightly into the ground so roots don't float on uneven grade.
		var origin := Vector3(xz.x, y - 0.02, xz.y)
		placements[key].append(Transform3D(basis, origin))
		accepted += 1

static func _tinted(base: Material, tint: Color) -> Material:
	if base == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = 0.88
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		return mat
	var mat: Material = base.duplicate()
	if mat is StandardMaterial3D:
		var std := mat as StandardMaterial3D
		std.albedo_color = std.albedo_color * tint
		std.roughness = clampf(std.roughness * 0.98 + 0.02, 0.55, 0.95)
	elif mat is ShaderMaterial:
		# Many foliage shaders expose albedo/color; leave the shader, add a modest instance tint via next_pass when possible.
		pass
	return mat

static func _instance_batches(root: Node3D, templates: Dictionary, placements: Dictionary) -> void:
	# Two or three slight tints per plant type for mid-stylized color variation.
	var tints := {
		"grass": [Color(0.92, 1.02, 0.78), Color(0.78, 0.95, 0.62), Color(0.62, 0.82, 0.48)],
		"fern": [Color(0.85, 1.0, 0.8), Color(0.7, 0.88, 0.6)],
		"shrub": [Color(0.9, 0.98, 0.75), Color(0.72, 0.86, 0.58)],
		"flower_p": [Color(1, 1, 1), Color(0.92, 0.88, 1.05)],
		"flower_y": [Color(1, 1, 1), Color(1.05, 0.96, 0.8)],
		"mound": [Color(0.88, 1.0, 0.72), Color(0.7, 0.86, 0.55)],
		"rock": [Color(1, 1, 1), Color(0.9, 0.88, 0.82)]
	}
	for key in placements.keys():
		var list: Array = placements[key]
		if list.is_empty() or not templates.has(key):
			continue
		var pal: Array = tints.get(key, [Color.WHITE])
		var buckets: Array = []
		for _i in pal.size():
			buckets.append([])
		for i in list.size():
			buckets[i % pal.size()].append(list[i])
		for b in buckets.size():
			var group: Array = buckets[b]
			if group.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = templates[key].mesh
			mm.instance_count = group.size()
			for i in group.size():
				mm.set_instance_transform(i, group[i])
			var batch := MultiMeshInstance3D.new()
			batch.name = "StyleTest_%s_%d" % [key, b]
			batch.multimesh = mm
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.material_override = _tinted(templates[key].material, pal[b])
			batch.set_meta("source_transforms", group)
			root.add_child(batch)

static func _add_feature_trees(root: Node3D, templates: Dictionary, space: PhysicsDirectSpaceState3D, world: Node3D) -> void:
	# Fuller mid-stylized silhouettes: a real kit tree plus stacked mound crowns.
	var spots: Array = [
		{"at": Vector2(-20.6, 5.15), "yaw": 0.4, "scale": 1.08},
		{"at": Vector2(-31.4, 20.6), "yaw": 2.3, "scale": 0.96},
		{"at": Vector2(-15.35, 21.8), "yaw": 5.1, "scale": 0.88}
	]
	var exclude: Array = []
	if is_instance_valid(world.get("player")):
		exclude.append(world.player.get_rid())
	var crowns := [
		Vector3(-0.85, 3.35, 0.2),
		Vector3(0.9, 3.55, 0.45),
		Vector3(0.1, 4.25, -0.2),
		Vector3(-0.4, 3.7, -0.95),
		Vector3(0.35, 3.2, 1.0)
	]
	for i in spots.size():
		var spec: Dictionary = spots[i]
		var hit := _ground_at(space, spec.at, exclude)
		if hit.is_empty() or _on_build_turf(spec.at, hit.position.y) or _on_stairs_or_path(spec.at):
			continue
		var holder := Node3D.new()
		holder.name = "StyleTestTree%d" % i
		holder.position = Vector3(spec.at.x, hit.position.y, spec.at.y)
		holder.rotation.y = spec.yaw
		holder.scale = Vector3.ONE * float(spec.scale)
		root.add_child(holder)
		if templates.has("tree"):
			var trunk := MeshInstance3D.new()
			trunk.name = "Broadleaf"
			trunk.mesh = templates["tree"].mesh
			trunk.material_override = templates["tree"].material
			trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			holder.add_child(trunk)
		if templates.has("mound"):
			for c in crowns.size():
				var leaf := MeshInstance3D.new()
				leaf.name = "FullerCrown%02d" % c
				leaf.mesh = templates["mound"].mesh
				leaf.material_override = _tinted(templates["mound"].material, Color(0.86, 1.02, 0.7) if c % 2 == 0 else Color(0.68, 0.86, 0.52))
				leaf.position = crowns[c]
				leaf.scale = Vector3(1.7, 2.35, 1.7)
				leaf.rotation.y = c * 1.55
				leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				holder.add_child(leaf)
		# Nearby mid shrubs for a clustered read.
		if templates.has("shrub_kit_a"):
			for s in 2:
				var bush := MeshInstance3D.new()
				bush.name = "Understory%d" % s
				bush.mesh = templates["shrub_kit_a" if s == 0 else "shrub_kit_b"].mesh if templates.has("shrub_kit_b") else templates["shrub_kit_a"].mesh
				bush.material_override = templates["shrub_kit_a"].material
				bush.position = Vector3(-1.1 + s * 1.9, 0.0, 0.7 - s * 1.15)
				bush.scale = Vector3.ONE * (0.95 + s * 0.12)
				bush.rotation.y = s * 1.7
				bush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				holder.add_child(bush)
		var body := StaticBody3D.new()
		body.name = "TrunkCollision"
		body.position = Vector3(0, 1.2, 0)
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.42
		cyl.height = 2.4
		shape.shape = cyl
		body.add_child(shape)
		holder.add_child(body)

static func _add_wall_vines(root: Node3D) -> void:
	# Painterly vine clusters on the blank retaining faces, not a realistic ivy sim.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# East face (toward the stairs) and a strip of the south face.
	_vine_panel(st, Vector3(-16.02, 0.35, 11.2), Vector3(0, 0, 1), 3.4, 2.55, 9)
	_vine_panel(st, Vector3(-16.02, 0.45, 18.8), Vector3(0, 0, 1), 3.2, 2.45, 8)
	_vine_panel(st, Vector3(-21.5, 0.3, 6.99), Vector3(1, 0, 0), 4.2, 2.4, 10)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "RetainingVines"
	mesh.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)

static func _vine_panel(st: SurfaceTool, origin: Vector3, along: Vector3, width: float, height: float, strands: int) -> void:
	var tangent := along.normalized()
	var out := Vector3(-tangent.z, 0, tangent.x)
	for i in strands:
		var u := (float(i) + 0.35) / float(strands)
		var xoff := (u - 0.5) * width
		var length := height * (0.55 + fmod(u * 7.13, 0.45))
		var base := origin + tangent * xoff
		var tip := base + Vector3(0, length, 0) + out * 0.04
		# Stem
		_box(st, (base + tip) * 0.5, Vector3(0.025, length, 0.025), Color(0.33, 0.42, 0.28), Basis.IDENTITY)
		var leaves := 5 + int(u * 3.0)
		for L in leaves:
			var t := (float(L) + 0.4) / float(leaves)
			var p: Vector3 = base.lerp(tip, t) + out * 0.03
			var side := 1.0 if (L + i) % 2 == 0 else -1.0
			var tip_leaf := p + tangent * (side * 0.16) + Vector3(0, 0.04, 0) + out * 0.05
			var col := Color(0.38, 0.52, 0.30) if L % 2 == 0 else Color(0.48, 0.62, 0.34)
			_triangle(st, p, p + Vector3(0, 0.07, 0) + tangent * (side * 0.05), tip_leaf, col)
			_triangle(st, p, tip_leaf, p + tangent * (side * 0.04) - Vector3(0, 0.03, 0), col.darkened(0.08))

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	for p in [a, b, c]:
		st.set_color(tint)
		st.add_vertex(p)

static func _box(st: SurfaceTool, p: Vector3, size: Vector3, tint: Color, basis: Basis) -> void:
	var box := BoxMesh.new()
	box.size = size
	for v in box.get_faces():
		st.set_color(tint)
		st.add_vertex(p + basis * v)

static func _add_local_light(root: Node3D) -> void:
	# Cheap warm fill so the new planting and the blank wall read less flat. Short range only.
	for spec in [
		{"name": "StairWarmFill", "pos": Vector3(-12.2, 2.35, 15.0), "energy": 0.35, "range": 6.5},
		{"name": "SouthWallFill", "pos": Vector3(-22.0, 1.8, 8.2), "energy": 0.22, "range": 5.5}
	]:
		var light := OmniLight3D.new()
		light.name = spec.name
		light.position = spec.pos
		light.light_color = Color(1.0, 0.78, 0.52)
		light.light_energy = spec.energy
		light.omni_range = spec.range
		light.shadow_enabled = false
		root.add_child(light)

static func _record_budget(root: Node3D) -> void:
	var triangles := 0
	var meshes := 0
	var instances := 0
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		meshes += 1
		if node is MultiMeshInstance3D and node.multimesh:
			instances += node.multimesh.instance_count
			var mesh: Mesh = node.multimesh.mesh
			if mesh:
				triangles += _mesh_tris(mesh) * node.multimesh.instance_count
		elif node is MeshInstance3D and node.mesh:
			instances += 1
			triangles += _mesh_tris(node.mesh)
	var lights := root.find_children("*", "Light3D", true, false).size()
	root.set_meta("budget", {"triangles": triangles, "meshes": meshes, "instances": instances, "lights": lights})

static func _mesh_tris(mesh: Mesh) -> int:
	var total := 0
	for i in mesh.get_surface_count():
		var arr = mesh.surface_get_arrays(i)
		var indices = arr[Mesh.ARRAY_INDEX] if arr.size() > Mesh.ARRAY_INDEX else null
		if indices:
			total += indices.size() / 3
		else:
			var verts = arr[Mesh.ARRAY_VERTEX]
			if verts:
				total += verts.size() / 3
	return total
