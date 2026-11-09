extends RefCounted
# Original procedural study. GLB bytes and geometry stay unchanged; COLOR stores
# the longest local axis of each disconnected timber member, never visible tint.
const SHADER = preload("res://assets/materials/architecture_surface.gdshader")
static var mesh_cache: Dictionary = {}
static var material_cache: Dictionary = {}
static func kind_for(name: String) -> int:
	if name.begins_with("Oiled_Timber_"): return 1
	if name == "Weathered_Bronze": return 2
	if name == "Polished_Bronze_Edges": return 3
	return 0
static func find_root(parents: Array[int], i: int) -> int:
	while parents[i] != i:
		parents[i] = parents[parents[i]]
		i = parents[i]
	return i
static func join(parents: Array[int], a: int, b: int):
	parents[find_root(parents,b)] = find_root(parents,a)
static func axis_colors(arrays: Array) -> PackedColorArray:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var parents: Array[int] = []
	var welded: Dictionary = {}
	for i in range(vertices.size()):
		parents.append(i)
		var p = vertices[i]
		var key = Vector3i(roundi(p.x*100000),roundi(p.y*100000),roundi(p.z*100000))
		if welded.has(key): join(parents,i,welded[key])
		else: welded[key]=i
	if indices.is_empty():
		for i in range(0,vertices.size(),3):
			join(parents,i,i+1);join(parents,i,i+2)
	else:
		for i in range(0,indices.size(),3):
			join(parents,indices[i],indices[i+1]);join(parents,indices[i],indices[i+2])
	var bounds: Dictionary = {}
	for i in range(vertices.size()):
		var root = find_root(parents,i)
		if bounds.has(root): bounds[root]=bounds[root].expand(vertices[i])
		else: bounds[root]=AABB(vertices[i],Vector3.ZERO)
	var colors = PackedColorArray()
	for i in range(vertices.size()):
		var b: AABB = bounds[find_root(parents,i)]
		var axis = b.size.max_axis_index()
		var c = Color(0,0,0,1)
		c[axis]=1.0
		colors.append(c)
	return colors
static func prepared_mesh(source: Mesh) -> ArrayMesh:
	if source.has_meta("reference_grain_prepared"): return source
	var key = source.get_instance_id()
	if mesh_cache.has(key): return mesh_cache[key]
	var mesh = ArrayMesh.new()
	for s in range(source.get_surface_count()):
		var arrays = source.surface_get_arrays(s)
		var original = source.surface_get_material(s)
		if original and kind_for(original.resource_name)==1:
			arrays[Mesh.ARRAY_COLOR]=axis_colors(arrays)
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(s),arrays)
		mesh.surface_set_material(s,original)
	mesh.set_meta("reference_grain_prepared",true)
	mesh_cache[key]=mesh
	return mesh
static func styled_material(original: StandardMaterial3D) -> ShaderMaterial:
	var kind = kind_for(original.resource_name)
	var key = str(kind)+str(original.albedo_color)
	if material_cache.has(key): return material_cache[key]
	var mat = ShaderMaterial.new()
	mat.shader=SHADER
	mat.resource_name="Reference_"+original.resource_name
	mat.set_shader_parameter("kind",kind)
	# Warm reference palette, not a global lighting change.
	mat.set_shader_parameter("tint",original.albedo_color.darkened(0.48 if kind==1 else (0.36 if kind==2 else 0.18)))
	mat.set_shader_parameter("roughness",0.80 if kind==1 else (0.64 if kind==2 else 0.44))
	mat.set_shader_parameter("metallic",0.0 if kind==1 else (0.68 if kind==2 else 0.76))
	material_cache[key]=mat
	return mat
static func apply(node: Node):
	if node is MeshInstance3D and node.mesh:
		var targeted=false
		for s in range(node.mesh.get_surface_count()):
			var original=node.mesh.surface_get_material(s)
			if original is StandardMaterial3D and kind_for(original.resource_name)>0: targeted=true
		if targeted:
			node.mesh=prepared_mesh(node.mesh)
			for s in range(node.mesh.get_surface_count()):
				var original=node.mesh.surface_get_material(s)
				if original is StandardMaterial3D and kind_for(original.resource_name)>0:
					node.set_surface_override_material(s,styled_material(original))
	for child in node.get_children(): apply(child)
