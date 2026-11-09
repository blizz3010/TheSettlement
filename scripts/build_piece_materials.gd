extends RefCounted
# Local adapter for original code-native stairs and railings only. Geometry is unchanged.
# Explicit member axes prevent tall solid treads from receiving vertical grain.
const SHADER = preload("res://assets/materials/build_piece_surface.gdshader")
static var mesh_cache: Dictionary = {}
static var material_cache: Dictionary = {}
static func apply_box(node: MeshInstance3D, bronze: bool, grain_axis: int):
	assert(node.mesh is BoxMesh)
	assert(grain_axis >= 0 and grain_axis <= 2)
	var source: BoxMesh = node.mesh
	var key = str(source.size) + ":" + str(grain_axis)
	if not mesh_cache.has(key):
		var arrays = source.surface_get_arrays(0)
		var colors = PackedColorArray()
		var color = Color(0,0,0,1)
		color[grain_axis] = 1.0
		colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
		colors.fill(color)
		arrays[Mesh.ARRAY_COLOR] = colors
		var prepared = ArrayMesh.new()
		prepared.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh_cache[key] = prepared
	node.mesh = mesh_cache[key]
	if not material_cache.has(bronze):
		var material = ShaderMaterial.new()
		material.shader = SHADER
		material.resource_name = "BuildPiece_WeatheredBronze" if bronze else "BuildPiece_Timber"
		material.set_shader_parameter("kind", 2 if bronze else 1)
		# Keep the exact existing code-native base colors; no second darkening pass.
		material.set_shader_parameter("tint", Color("88724b") if bronze else Color("705135"))
		material.set_shader_parameter("roughness", 0.64 if bronze else 0.80)
		material.set_shader_parameter("metallic", 0.68 if bronze else 0.0)
		material_cache[bronze] = material
	node.material_override = material_cache[bronze]
