extends RefCounted
## PR B, two sky / scenery tone fixes from the visual pass (findings.md P2 "distant scenery"):
##  plaza_trees: the Quaternius CommonTree crowns in the plaza gardens (Leaves_NormalTree_C.png, a pure lime
##    averaging RGB 88/123/0) clash with Artie's plaza trees and the darker garden trees. Their leaf surface
##    gets a per-instance override (raid/assets/materials/p2b_leaf_tone.gdshader, same texture, alpha
##    scissor and UVs) that remaps it to a natural mid green. Only crowns taller than 2 m in
##    PlazaIslandComposition (13 crowns) change; bushes and the shared material resource are untouched.
##  planet: the valley body in the day/night sky is ~31 % smaller and washes out by day
##    (raid/assets/materials/p2b_day_night_sky.gdshader, an unpinned copy; DayNightCycle keeps driving it).
const LEAF_SHADER := preload("res://raid/assets/materials/p2b_leaf_tone.gdshader")
const SKY_SHADER := preload("res://raid/assets/materials/p2b_day_night_sky.gdshader")
const LIME_TEX := "Leaves_NormalTree_C.png"
const MIN_HEIGHT := 2.0

static func plaza_trees(world: Node3D) -> Dictionary:
	var comp := world.find_child("PlazaIslandComposition", true, false) as Node3D
	if comp == null:
		return {"ok": false, "reason": "PlazaIslandComposition missing"}
	var toned := []
	var cache := {}
	for mi in comp.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree(): continue
		var bb: AABB = m.global_transform * m.get_aabb()
		if bb.size.y < MIN_HEIGHT: continue
		for s in m.mesh.get_surface_count():
			var src := m.get_active_material(s) as BaseMaterial3D
			if src == null or src.albedo_texture == null or not src.albedo_texture.resource_path.ends_with(LIME_TEX): continue
			if not cache.has(src):
				var sm := ShaderMaterial.new()
				sm.shader = LEAF_SHADER
				sm.resource_name = "P2BLeafTone"
				sm.set_shader_parameter("albedo_tex", src.albedo_texture)
				sm.set_shader_parameter("albedo_tint", src.albedo_color)
				sm.set_shader_parameter("alpha_scissor", src.alpha_scissor_threshold if src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.5)
				cache[src] = sm
			m.set_surface_override_material(s, cache[src])
			toned.append(str(world.get_path_to(m)))
	return {"ok": toned.size() > 0, "toned": toned.size(), "nodes": toned}

static func planet(world: Node3D) -> Dictionary:
	var cyc = world.get_node_or_null("DayNightCycle")
	if cyc == null or not (cyc.get("sky_material") is ShaderMaterial):
		return {"ok": false, "reason": "DayNightCycle sky material missing"}
	var sm: ShaderMaterial = cyc.sky_material
	var old: Shader = sm.shader
	if old == SKY_SHADER:
		return {"ok": true, "reused": true}
	var values := {}
	for u in old.get_shader_uniform_list():
		values[u.name] = sm.get_shader_parameter(u.name)
	sm.shader = SKY_SHADER
	for k in values:
		if values[k] != null: sm.set_shader_parameter(k, values[k])
	cyc.apply_lighting()
	return {"ok": true, "from": old.resource_path, "to": SKY_SHADER.resource_path, "params_kept": values.size(),
		"body_radius": 0.072, "body_radius_was": 0.105}
