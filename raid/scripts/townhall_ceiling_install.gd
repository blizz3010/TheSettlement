extends RefCounted
## PR B (P2 "plain Town Hall ceiling and lamps"): Artie's settlement_townhall_ceiling kit in the nave.
## Placement from NOTE-FOR-GAMER.md, all at x 0, no rotation, y 0 (the kit's y is absolute in the hall frame):
##   truss at z -14.5 / -18.7 / -23 / -27.3 / -31.5 (the nave column lines, tie beam on the column caps)
##   bay_4p2 at z -16.6 / -29.4, bay_4p3 at z -20.85 / -25.15 (coffered liner under the bare roof slab)
##   lamps on the bays' mk_prop_lamp_* markers: chandeliers on the ridge, pendants on the aisle purlins.
## The repo's six amber lanterns (TownHallLanternLights / TownHallLanternMounts) are kept as they are,
## including the two at z -23 that sit in the column line (repo defect, not touched here).
## No collision (nothing is in reach). Ceiling pieces do not cast sun shadows (the roof slab already does).
## The lamp glass ships lit; the lamp cycle scales it by daylight. Only the two chandeliers get a dusk
## OmniLight (3.4 / 11 m, no shadow): with the six existing lantern lights that keeps the nave at the
## Compatibility renderer's 8 lights per mesh. The pendants glow through their glass only.
const Kit = preload("res://raid/scripts/p2b_kit.gd")
const DIR := "res://assets/settlement_townhall_ceiling/"
const P := "settlement_townhall_ceiling_"
const NAME := "P2TownHallCeiling"
const LODS := [30.0, 70.0]
const LAMP_LODS := [24.0, 60.0]
const TRUSS_Z := [-14.5, -18.7, -23.0, -27.3, -31.5]
const BAYS := [["bay_4p2", -16.6], ["bay_4p3", -20.85], ["bay_4p3", -25.15], ["bay_4p2", -29.4]]
const LIGHT_COLOR := Color("ffb366")

static func piece(id: String) -> Node3D:
	return (load(DIR + P + id + ".gltf") as PackedScene).instantiate() as Node3D

static func apply(world: Node3D, lamps: Array, lights: Array) -> Dictionary:
	if world.get_node_or_null("TownHallLanternLights") == null:
		return {"ok": false, "reason": "TownHallLanternLights missing (no Town Hall)"}
	if world.has_node(NAME):
		return world.get_node(NAME).get_meta("p2b", {"ok": true, "reused": true})
	var root := Node3D.new(); root.name = NAME
	world.add_child(root)
	var counts := {"truss": 0, "bay": 0, "chandelier": 0, "pendant": 0}
	for z in TRUSS_Z:
		var t := piece("truss"); t.position = Vector3(0, 0, z); Kit.set_lods(t, LODS); root.add_child(t)
		counts.truss += 1
	var markers := []
	for b in BAYS:
		var bay := piece(b[0]); bay.position = Vector3(0, 0, b[1]); Kit.set_lods(bay, LODS); root.add_child(bay)
		counts.bay += 1
		for mk in bay.find_children("mk_prop_lamp_*", "Node3D", true, false):
			markers.append(String(mk.name))
			var nm := String(mk.name)
			var kind := "pendant" if nm.contains("aisle") or nm.contains("pendant") else "chandelier"
			var lamp := piece("lamp_" + kind)
			lamp.name = kind
			bay.add_child(lamp)
			lamp.global_transform = (mk as Node3D).global_transform
			Kit.set_lods(lamp, LAMP_LODS)
			Kit.lamp_materials(lamp, lamps)
			counts[kind] += 1
			if kind == "chandelier":
				var l := OmniLight3D.new(); l.name = "DuskLight"
				l.light_color = LIGHT_COLOR; l.omni_range = 11.0; l.shadow_enabled = false
				lamp.add_child(l)
				var ml := Kit.marker(lamp, "mk_light")
				l.global_position = ml.global_position if ml else lamp.global_position + Vector3(0, -3.35, 0)
				lights.append([l, 3.4])
	Kit.drop_col(root)
	Kit.shadows_off(root)
	var res := {"ok": counts.truss == 5 and counts.bay == 4 and counts.chandelier == 2 and counts.pendant == 8,
		"counts": counts, "markers": markers, "lod0_tris": Kit.tris(root, 0), "lod1_tris": Kit.tris(root, 1)}
	root.set_meta("p2b", res)
	return res
