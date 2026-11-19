# place_distant_hills.gd - P2 "Distant scenery on Medium: faceted mountains" (visualpass shot 79/185, findings.md).
# Render-only swap of the faceted far rings for the smooth distant_hills chunk sets. Geometry, footprint and placement
# come from the same functions as scripts/distant_mountains.gd and far_scenery_options.gd, so it drops in 1:1.
#
#   * The pinned source scripts (valley_backdrop.gd, distant_mountains.gd) are NOT edited. The original MeshInstances stay
#     in the tree (hidden), so ValleyBackdrop.terrain_vertices, tree grounding, lake joins and tests keep working.
#   * Adds node "DistantHills" (Node3D) under the world: 16 chunks x LOD0/1/2 per set, visibility ranges per quality,
#     joins group 'distant_scenery_quality' (game_settings.apply_scenery_quality calls set_quality).
#   * Optionally welds + smooths MiddleRidge / ScenicGroundApron normals in place (same vertices, same face order).
#   * DISTANT_HILLS=off skips everything (A/B and benches).
#
# Install: in ship_settlement_preview.gd right AFTER far_scenery_options.apply(self):
#     if world_activated: preload("res://raid/scripts/place_distant_hills.gd").install(self)
extends Node3D

const DIR := "res://assets/distant_hills/"
const SETS := [
	{"id": "distant_hills_foothills", "replaces": "OuterFoothills"},
	{"id": "distant_hills_alpine", "replaces": "DistantAlpineRange"},
	{"id": "distant_hills_ridges", "replaces": "FarSceneryLayerRidges"},
]
# [LOD0 end, LOD1 end] in metres, camera -> chunk, by scenery_quality 0 Low / 1 Medium / 2 High / 3 Ultra.
# LOD2 has no end (the rings must always close the horizon; the old meshes had none / 1400 m).
const RANGES := [[300.0, 650.0], [450.0, 900.0], [650.0, 1200.0], [900.0, 1600.0]]
const MARGIN := 15.0      # hysteresis so chunks don't flip LOD at the boundary
const SMOOTH_NODES := ["MiddleRidge", "ScenicGroundApron"]

var chunks := []          # [MeshInstance3D, lod]
var report := {}

static func install(world: Node, smooth_near := true) -> Dictionary:
	if OS.get_environment("DISTANT_HILLS") == "off":
		return {"ok": true, "skipped": true}
	var old := world.get_node_or_null("DistantHills")
	if old:
		return {"ok": true, "skipped": true, "reason": "already installed"}
	var dh = load("res://raid/scripts/place_distant_hills.gd").new()
	dh.name = "DistantHills"
	world.add_child(dh)
	return dh._build(world, smooth_near)

func _build(world: Node, smooth_near: bool) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var replaced := []
	var tris := {}
	for s in SETS:
		var original := world.find_child(s.replaces, true, false) as MeshInstance3D
		if original == null:
			continue                      # e.g. FAR_SCENERY_OPTION=off -> no layer ridges, keep it that way
		var scene: PackedScene = load(DIR + s.id + ".gltf")
		if scene == null:
			push_warning("distant_hills: missing " + s.id)
			continue
		var inst := scene.instantiate()
		inst.name = s.id
		add_child(inst)
		var n := 0
		for mi in inst.find_children("*_LOD?", "MeshInstance3D", true, false):
			var lod := int(String(mi.name).right(1))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # as the originals: no far shadows
			mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			chunks.append([mi, lod])
			if lod == 0:
				n += mi.mesh.get_faces().size() / 3
		original.visible = false
		original.set_meta("distant_hills_replaced_by", get_path_to(inst))
		replaced.append(s.replaces)
		tris[s.id] = n
	var smoothed := []
	if smooth_near:
		for nm in SMOOTH_NODES:
			var mi := world.find_child(nm, true, false) as MeshInstance3D
			if mi and mi.mesh and _smooth_normals(mi):
				smoothed.append(nm)
	add_to_group("distant_scenery_quality")
	var q := 1
	var Settings = load("res://scripts/game_settings.gd")
	if Settings:
		q = Settings.new().current_scenery_quality(self)
	set_quality(q)
	report = {"ok": true, "replaced": replaced, "smoothed": smoothed, "chunks": chunks.size(), "lod0_tris": tris,
		"quality": q, "build_ms": (Time.get_ticks_usec() - t0) / 1000.0}
	return report

func set_quality(value: int) -> void:
	var r: Array = RANGES[clampi(value, 0, 3)]
	for c in chunks:
		var mi: MeshInstance3D = c[0]
		if not is_instance_valid(mi):
			continue
		match int(c[1]):
			0:
				mi.visibility_range_begin = 0.0
				mi.visibility_range_end = r[0]
			1:
				mi.visibility_range_begin = r[0]
				mi.visibility_range_end = r[1]
			_:
				mi.visibility_range_begin = r[1]
				mi.visibility_range_end = 0.0
		mi.visibility_range_begin_margin = MARGIN if mi.visibility_range_begin > 0.0 else 0.0
		mi.visibility_range_end_margin = MARGIN if mi.visibility_range_end > 0.0 else 0.0

# Weld by position (1 cm) and give every corner the area-weighted average normal. Vertex count, order, colours,
# UVs and indices are untouched, so get_faces()/terrain_vertices consumers see identical triangles.
static func _smooth_normals(mi: MeshInstance3D) -> bool:
	var src: Mesh = mi.mesh
	if not (src is ArrayMesh):
		return false
	var out := ArrayMesh.new()
	for si in src.get_surface_count():
		var arr: Array = src.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var tri_count := (idx.size() if idx.size() > 0 else v.size()) / 3
		var key_of := func(p: Vector3) -> Vector3i: return Vector3i(roundi(p.x * 100.0), roundi(p.y * 100.0), roundi(p.z * 100.0))
		var acc := {}
		for t in tri_count:
			var i0 := idx[t * 3] if idx.size() > 0 else t * 3
			var i1 := idx[t * 3 + 1] if idx.size() > 0 else t * 3 + 1
			var i2 := idx[t * 3 + 2] if idx.size() > 0 else t * 3 + 2
			var fn := (v[i1] - v[i0]).cross(v[i2] - v[i0])      # area-weighted, sign from winding
			if fn.y < 0.0:
				fn = -fn                                          # these rings are drawn cull-disabled; keep normals up
			for i in [i0, i1, i2]:
				var k: Vector3i = key_of.call(v[i])
				acc[k] = acc.get(k, Vector3.ZERO) + fn
		var n := PackedVector3Array()
		n.resize(v.size())
		for i in v.size():
			var a: Vector3 = acc.get(key_of.call(v[i]), Vector3.UP)
			n[i] = a.normalized() if a.length() > 0.000001 else Vector3.UP
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(src.surface_get_primitive_type(si), arr)
		var m := src.surface_get_material(si)
		if m:
			out.surface_set_material(out.get_surface_count() - 1, m)
	mi.set_meta("distant_hills_flat_mesh", src)
	mi.mesh = out
	return true
