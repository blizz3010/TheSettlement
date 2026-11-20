extends RefCounted
## PR B: helpers shared by the P2B kit installers (p2_walls_fixes.gd and the scripts it calls).
## Hand LODs (`*_LOD0/1/2`): hard switches at `ends` metres (no alpha fade), small hysteresis.
static func set_lods(root: Node, ends: Array, margin := 1.5) -> void:
	for mi in root.find_children("*_LOD?", "MeshInstance3D", true, false):
		var k := int(String(mi.name).right(1))
		var g := mi as GeometryInstance3D
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		g.visibility_range_begin = 0.0 if k == 0 else float(ends[k - 1])
		g.visibility_range_begin_margin = 0.0 if k == 0 else margin
		g.visibility_range_end = float(ends[k]) if k < ends.size() else 0.0
		g.visibility_range_end_margin = margin if k < ends.size() else 0.0

static func tris(root: Node, lod: int) -> int:
	var t := 0
	for mi in root.find_children("*_LOD%d" % lod, "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh: t += (mi as MeshInstance3D).mesh.get_faces().size() / 3
	return t

## Drop every imported `_col` body (and its hidden holder mesh) under n; returns how many.
static func drop_col(n: Node) -> int:
	var c := 0
	for body in n.find_children("*", "StaticBody3D", true, false):
		if not is_instance_valid(body): continue
		var holder := body.get_parent()
		if holder is MeshInstance3D and not String(holder.name).contains("_LOD"):
			holder.get_parent().remove_child(holder); holder.free()
		else:
			body.get_parent().remove_child(body); body.free()
		c += 1
	return c

## Collect the lamp-glass materials of an instanced kit piece (unique per imported scene).
static func lamp_materials(n: Node, into: Array) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null: continue
		for s in m.get_surface_count():
			var mat := m.surface_get_material(s) as BaseMaterial3D
			if mat and String(mat.resource_name) == "SS_LampGlass" and not into.has(mat):
				into.append(mat)

static func marker(n: Node, name: String) -> Node3D:
	return n.find_child(name, true, false) as Node3D

static func shadows_off(n: Node) -> void:
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
