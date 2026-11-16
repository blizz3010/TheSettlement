extends Node3D
## TASKS item 21: raster occlusion culling for the settlement (Compatibility renderer supports it).
## project.godot is pinned and leaves rendering/occlusion_culling/use_occlusion_culling off, so
## the viewport flag is turned on here and occluders are built at runtime from opaque static
## geometry (hall shell, buildings, planters, fountain, terrain). Grass hidden behind them is
## then skipped per sub-chunk by the engine; nothing visible changes.
const NODE_NAME := "SettlementOccluders"
const MAX_TRIS_PER_MESH := 20000
const MAX_TOTAL_TRIS := 120000
const MIN_EXTENT := 0.9

var world: Node3D
var occluder_count := 0
var occluder_tris := 0
var skipped := {}

static func install(host: Node3D) -> Node:
	if host == null or not is_instance_valid(host): return null
	var existing := host.get_node_or_null(NODE_NAME)
	if existing != null: return existing
	if OS.get_environment("SETTLEMENT_OCCLUSION_CULLING") == "off": return null
	var node = load("res://raid/scripts/settlement_occluders.gd").new()
	node.name = NODE_NAME
	node.world = host
	host.add_child(node)
	return node

static func _material_opaque(mat: Material) -> bool:
	if mat == null: return true
	if mat is BaseMaterial3D:
		return mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
	if mat is ShaderMaterial:
		if mat.shader == null: return false
		var code: String = mat.shader.code
		if code.contains("ALPHA") or code.contains("discard") or code.contains("blend_") : return false
		var rx := RegEx.create_from_string("VERTEX(\\.[xyz]+)?\\s*[\\+\\-\\*/]?=")
		if rx.search(code) != null: return false
		return true
	return false

static func _excluded(n: Node) -> bool:
	var p := n
	while p != null:
		if p is CharacterBody3D or p is RigidBody3D or p is AnimatableBody3D or p is Skeleton3D or p is Camera3D: return true
		if p.get_script() != null and str(p.get_script().resource_path).contains("npc"): return true
		p = p.get_parent()
	return false

func build() -> void:
	var candidates: Array = []
	for n in world.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		if not mi.is_visible_in_tree() or mi.mesh == null or mi.skin != null or mi.skeleton != NodePath("") and mi.has_node(mi.skeleton) and mi.get_node(mi.skeleton) is Skeleton3D:
			continue
		if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		if mi.transparency > 0.0: continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		var dims := [box.size.x, box.size.y, box.size.z]
		dims.sort()
		if dims[1] < MIN_EXTENT: continue
		var ok := true
		for si in mi.mesh.get_surface_count():
			var mat: Material = mi.material_override if mi.material_override != null else mi.get_active_material(si)
			if not _material_opaque(mat): ok = false; break
		if not ok or (mi.material_overlay != null): continue
		if _excluded(mi): continue
		candidates.append({"mi": mi, "size": dims[1] * dims[2]})
	candidates.sort_custom(func(a, b): return a.size > b.size)
	for c in candidates:
		var mi: MeshInstance3D = c.mi
		var faces: PackedVector3Array = mi.mesh.get_faces()
		var tris := faces.size() / 3
		if tris == 0 or tris > MAX_TRIS_PER_MESH: continue
		if occluder_tris + tris > MAX_TOTAL_TRIS: continue
		var occ := ArrayOccluder3D.new()
		var indices := PackedInt32Array()
		indices.resize(faces.size())
		for i in faces.size(): indices[i] = i
		occ.set_arrays(faces, indices)
		var oi := OccluderInstance3D.new()
		oi.occluder = occ
		oi.name = "Occ_%d" % occluder_count
		add_child(oi)
		oi.global_transform = mi.global_transform
		occluder_count += 1
		occluder_tris += tris
	get_viewport().use_occlusion_culling = true
	print("SETTLEMENT_OCCLUDERS built occluders=%d tris=%d candidates=%d" % [occluder_count, occluder_tris, candidates.size()])

func _ready():
	top_level = true
	global_transform = Transform3D.IDENTITY
	build()
