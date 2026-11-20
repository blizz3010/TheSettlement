extends RefCounted
## PR B (P2 "rear balcony undercroft is unfinished"): Artie's settlement_inn_undercroft kit under the Inn's
## rear and east balconies (inn_lake_v088.gd / inn_joined_decks_v098.gd slabs on piles; nothing there today).
## World placement from NOTE-FOR-GAMER.md (bay frame y 0 = slab underside, world 3.12; z 0 = Inn wall face):
##   rear  bay_4m   at (cx, 3.12, 58.7) rot 0, cx -6 / -2 / 2 / 6 (x -8..8). Artie's optional fifth bay at
##         cx 10 is left out: its landing would overlap the second east bay (x 8..12, z 58.7..59.8).
##   east  bay_3p25 at (7.9, 3.12, 54.925) and (7.9, 3.12, 58.15), rot +90 (out over the lake, +X).
##   piles pile_dressing_28 on the rear row (x -8..8 step 4, z 62.6) and the east row (x 11.6, z 53.3 /
##         56.5 / 59.8, turned 90 so the braces run along the row); pile_dressing_35 on the extended
##         supports (x -8.7 / 0 / 8.7, z 60) and the corner pile (11.6, 62.6). The repo's piles are kept.
## Props go on the bays' mk_prop_* slots (marker transform = prop transform), as in Artie's previews.
## Landing and prop _col bodies are kept (the landing is walkable, 0.5 m over the water). Everything sits
## under the slab, so none of it casts sun shadows. Lantern glass + one dusk light per bay go to the lamp cycle.
const Kit = preload("res://raid/scripts/p2b_kit.gd")
const DIR := "res://assets/settlement_inn_undercroft/"
const P := "settlement_inn_undercroft_"
const NAME := "P2InnUndercroft"
const SLAB_Y := 3.12
const BAY_LODS := [22.0, 55.0]
const PROP_LODS := [15.0, 40.0]
const LIGHT_COLOR := Color("ffb366")
const LIGHT_ENERGY := 2.6
const LIGHT_RANGE := 7.5
## [asset, world position, yaw deg, props {slot: asset}]
const BAYS := [
	["bay_4m", Vector3(-6, SLAB_Y, 58.7), 0.0, {"shelf_unit_1": "shelf_unit", "crab_pots_1": "crab_pots", "ladder_dock_1": "ladder_dock"}],
	["bay_4m", Vector3(-2, SLAB_Y, 58.7), 0.0, {"barrel_stack_1": "barrel_stack", "boat_hung_1": "boat_hung"}],
	["bay_4m", Vector3(2, SLAB_Y, 58.7), 0.0, {"shelf_unit_1": "shelf_unit", "boat_hung_1": "boat_hung", "ladder_dock_1": "ladder_dock"}],
	["bay_4m", Vector3(6, SLAB_Y, 58.7), 0.0, {"barrel_stack_1": "barrel_stack", "crab_pots_1": "crab_pots", "ladder_dock_1": "ladder_dock"}],
	["bay_3p25", Vector3(7.9, SLAB_Y, 54.925), 90.0, {"crate_stack_1": "crate_stack"}],
	["bay_3p25", Vector3(7.9, SLAB_Y, 58.15), 90.0, {"net_rack_1": "net_rack", "ladder_dock_1": "ladder_dock"}],
]
const PILES := [
	["pile_dressing_28", Vector3(-8, SLAB_Y, 62.6), 0.0], ["pile_dressing_28", Vector3(-4, SLAB_Y, 62.6), 0.0],
	["pile_dressing_28", Vector3(0, SLAB_Y, 62.6), 0.0], ["pile_dressing_28", Vector3(4, SLAB_Y, 62.6), 0.0],
	["pile_dressing_28", Vector3(8, SLAB_Y, 62.6), 0.0],
	["pile_dressing_28", Vector3(11.6, SLAB_Y, 53.3), 90.0], ["pile_dressing_28", Vector3(11.6, SLAB_Y, 56.5), 90.0],
	["pile_dressing_28", Vector3(11.6, SLAB_Y, 59.8), 90.0],
	["pile_dressing_35", Vector3(-8.7, SLAB_Y, 60), 0.0], ["pile_dressing_35", Vector3(0, SLAB_Y, 60), 0.0],
	["pile_dressing_35", Vector3(8.7, SLAB_Y, 60), 0.0], ["pile_dressing_35", Vector3(11.6, SLAB_Y, 62.6), 0.0],
]

static func piece(id: String) -> Node3D:
	return (load(DIR + P + id + ".gltf") as PackedScene).instantiate() as Node3D

static func apply(world: Node3D, lamps: Array, lights: Array) -> Dictionary:
	var inn := world.get_node_or_null("SettlementInnExpansion/Inn") as Node3D
	if inn == null:
		return {"ok": false, "reason": "SettlementInnExpansion/Inn missing"}
	if inn.has_node(NAME):
		return inn.get_node(NAME).get_meta("p2b", {"ok": true, "reused": true})
	var root := Node3D.new(); root.name = NAME
	inn.add_child(root)
	root.global_transform = Transform3D.IDENTITY   # placements below are world coordinates
	var counts := {}
	var n_lights := 0
	for b in BAYS:
		var bay := piece(b[0])
		bay.name = "%s_%d" % [b[0], root.get_child_count()]
		bay.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(b[2])), b[1])
		Kit.set_lods(bay, BAY_LODS)
		root.add_child(bay)
		counts[b[0]] = int(counts.get(b[0], 0)) + 1
		var slots: Dictionary = (b[3] as Dictionary).duplicate()
		slots["lantern_hung_1"] = "lantern_hung"; slots["lantern_hung_2"] = "lantern_hung"
		var lamp_pts := []
		for slot in slots:
			var mk := Kit.marker(bay, "mk_prop_" + slot)
			if mk == null: continue
			var prop := piece(slots[slot])
			prop.name = slots[slot]
			bay.add_child(prop)
			prop.global_transform = mk.global_transform
			Kit.set_lods(prop, PROP_LODS)
			counts[slots[slot]] = int(counts.get(slots[slot], 0)) + 1
			if slots[slot] == "lantern_hung":
				Kit.lamp_materials(prop, lamps)
				var ml := Kit.marker(prop, "mk_light")
				lamp_pts.append(ml.global_position if ml else prop.global_position)
		if lamp_pts.size() > 0:
			var l := OmniLight3D.new(); l.name = "DuskLight"
			l.light_color = LIGHT_COLOR; l.omni_range = LIGHT_RANGE; l.shadow_enabled = false
			l.distance_fade_enabled = true; l.distance_fade_begin = 40.0; l.distance_fade_length = 15.0
			root.add_child(l)
			var c := Vector3.ZERO
			for q in lamp_pts: c += q
			l.global_position = c / lamp_pts.size()
			lights.append([l, LIGHT_ENERGY]); n_lights += 1
	for pdef in PILES:
		var pile := piece(pdef[0])
		pile.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(pdef[2])), pdef[1])
		Kit.set_lods(pile, PROP_LODS)
		root.add_child(pile)
		counts[pdef[0]] = int(counts.get(pdef[0], 0)) + 1
	Kit.shadows_off(root)
	var cols := root.find_children("*", "StaticBody3D", true, false).size()
	var res := {"ok": int(counts.get("bay_4m", 0)) == 4 and int(counts.get("bay_3p25", 0)) == 2, "counts": counts,
		"lights": n_lights, "colliders": cols, "lod0_tris": Kit.tris(root, 0), "lod1_tris": Kit.tris(root, 1)}
	root.set_meta("p2b", res)
	return res
