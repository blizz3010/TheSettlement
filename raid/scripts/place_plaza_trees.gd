# place_plaza_trees.gd: swap the two lime CommonTree_1 "lollipop" trees in PlazaIslandComposition for the
# plaza_tree set, keeping their names, ground contact and yaw. Call once right after the composition is instantiated,
# e.g. in plaza_island_landscape.gd after `visual=SCENE.instantiate();visual.name='PlazaIslandComposition'`:
#     preload('res://raid/scripts/place_plaza_trees.gd').apply(visual)
# composition.scn itself stays byte-identical (it is sha-pinned in vendor/large-assets/manifest.json).
extends RefCounted
const DIR := "res://assets/plaza_trees/"
const SWAPS := {"Tree_left": "plaza_tree_a", "Tree_right": "plaza_tree_b"}
const SOLIDS := {"Tree_left": "TreeSolid_left", "Tree_right": "TreeSolid_right"}
# metres from the camera; hard switch with a little hysteresis (no alpha fade on cut-out foliage)
const LOD_RANGES := [[0.0, 32.0], [32.0, 75.0], [75.0, 0.0]]
const MARGIN := 2.0

static func apply(visual: Node3D) -> Array:
	var placed := []
	for old_name in SWAPS:
		var old := visual.get_node_or_null(old_name) as MeshInstance3D
		if old == null: continue
		var x_axis := old.transform.basis.x.normalized()
		var yaw := atan2(-x_axis.z, x_axis.x)
		var ground := (old.transform * old.get_aabb()).position.y      # lollipop root bottom = ground (-0.05 there)
		var tree := (load(DIR + SWAPS[old_name] + ".gltf") as PackedScene).instantiate() as Node3D
		tree.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(old.position.x, ground, old.position.z))
		set_lod_ranges(tree)
		var solid := visual.get_node_or_null(SOLIDS[old_name])
		if solid: visual.remove_child(solid); solid.free()            # old trimesh of the whole bark mesh
		visual.remove_child(old); old.free()
		tree.name = old_name                                          # paths_gardens_v094.finish_roots finds it by name
		visual.add_child(tree)
		if visual.owner: tree.owner = visual.owner
		placed.append({"name": old_name, "asset": SWAPS[old_name], "position": tree.position, "yaw_deg": rad_to_deg(yaw)})
	return placed

static func set_lod_ranges(tree: Node3D) -> void:
	for mi in tree.find_children("*_LOD*", "MeshInstance3D", true, false):
		var k := int(String(mi.name).right(1))
		mi.visibility_range_begin = LOD_RANGES[k][0]; mi.visibility_range_end = LOD_RANGES[k][1]
		mi.visibility_range_begin_margin = MARGIN if k > 0 else 0.0
		mi.visibility_range_end_margin = MARGIN if k < 2 else 0.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if k == 2: mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
