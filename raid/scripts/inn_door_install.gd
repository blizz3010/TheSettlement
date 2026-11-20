extends Node
## PR B (P2 "Inn front is an open portal"): Artie's settlement_inn_door kit in the two door openings the
## Inn already has (inn_architecture.gd main doorway x -1.2..1.2, 2.6 m; inn_front_v087.gd east side
## door z 1.375..2.625). Placement from NOTE-FOR-GAMER.md, Inn-local: main (0, 0, -5.9) rot 180 deg,
## side (7.8, 0, 2.0) rot +90 deg. The repo's EntryLintel, lanterns and jambs stay; their lights already
## sit at the kit's mk_light markers, so no extra door lights are added.
## The doorways are the walk-in route, so the leaves swing open outward (main 100 deg, side 95 deg) when the
## player comes within OPEN_RADIUS of either face and close after they leave. Leaf collision is only on
## while a leaf is fully shut (so a moving leaf never shoves the player); the frames keep no collider.
## This node is the controller; static apply() installs it.
const Kit = preload("res://raid/scripts/p2b_kit.gd")
const DIR := "res://assets/settlement_inn_door/"
const NAME := "P2InnDoors"
const LODS := [18.0, 45.0]
const OPEN_RADIUS := 3.4
const CLOSE_RADIUS := 4.2
const SWING_DEG_PER_S := 220.0
## [asset, inn-local position, yaw deg, [[leaf node prefix, open deg], ...]]
const DOORS := [
	["settlement_inn_door_main", Vector3(0, 0, -5.9), 180.0, [["settlement_inn_door_main_leaf_l", -100.0], ["settlement_inn_door_main_leaf_r", 100.0]]],
	["settlement_inn_door_side", Vector3(7.8, 0, 2.0), 90.0, [["settlement_inn_door_side_leaf", -95.0]]],
]
var player: Node3D
var doors: Array = []   # {node, leaves: [{nodes, rest, open_deg, cols}], angle 0..1, target, forced}

static func apply(world: Node3D, lamps: Array, _lights: Array) -> Dictionary:
	var inn := world.get_node_or_null("SettlementInnExpansion/Inn") as Node3D
	if inn == null:
		return {"ok": false, "reason": "SettlementInnExpansion/Inn missing"}
	if inn.has_node(NAME):
		return inn.get_node(NAME).get_meta("p2b", {"ok": true, "reused": true})
	var ctl = load("res://raid/scripts/inn_door_install.gd").new()
	ctl.name = NAME
	ctl.player = world.get("player") as Node3D
	inn.add_child(ctl)
	var placed := []
	for d in DOORS:
		var n := (load(DIR + d[0] + ".gltf") as PackedScene).instantiate() as Node3D
		n.name = d[0]
		n.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(d[2])), d[1])
		Kit.set_lods(n, LODS)
		inn.add_child(n)
		Kit.lamp_materials(n, lamps)
		var entry := {"node": n, "leaves": [], "angle": 0.0, "target": 0.0, "forced": -1}
		for lf in d[3]:
			var nodes := []
			var rest := []
			for k in 3:
				var ln := n.find_child("%s_LOD%d" % [lf[0], k], true, false) as Node3D
				if ln: nodes.append(ln); rest.append(ln.transform)
			var cols := []
			for ln in nodes:
				for c in (ln as Node).find_children("*", "CollisionShape3D", true, false): cols.append(c)
			entry.leaves.append({"nodes": nodes, "rest": rest, "open_deg": lf[1], "cols": cols})
		# frame collision (if any) is not needed: the wall solids already frame the opening
		for body in n.find_children("*", "StaticBody3D", true, false):
			if not String(body.get_parent().name).contains("_leaf"):
				body.get_parent().remove_child(body); body.free()
		ctl.doors.append(entry)
		placed.append({"asset": d[0], "global": n.global_position.snappedf(0.001), "leaves": entry.leaves.size(),
			"leaf_cols": entry.leaves.reduce(func(acc, l): return acc + l.cols.size(), 0), "lod0_tris": Kit.tris(n, 0)})
	var res := {"ok": placed.size() == 2, "doors": placed, "inn_origin": inn.global_position.snappedf(0.001)}
	ctl.set_meta("p2b", res)
	return res

## Test / cutscene hook: force a door open (1), shut (0) or back to proximity (-1).
func force(index: int, state: int) -> void:
	doors[index].forced = state

func door_center(d: Dictionary) -> Vector3:
	var n: Node3D = d.node
	return n.to_global(Vector3(0, 1.2, 0))

func _physics_process(delta: float) -> void:
	for d in doors:
		var target := float(d.target)
		if int(d.forced) >= 0:
			target = float(d.forced)
		elif is_instance_valid(player):
			var dist := player.global_position.distance_to(door_center(d))
			if dist < OPEN_RADIUS: target = 1.0
			elif dist > CLOSE_RADIUS: target = 0.0
		d.target = target
		var a := move_toward(float(d.angle), target, delta * SWING_DEG_PER_S / 100.0)
		if is_equal_approx(a, float(d.angle)) and a == target and d.has("applied"):
			continue
		d.angle = a; d.applied = true
		for lf in d.leaves:
			var deg := float(lf.open_deg) * smoothstep(0.0, 1.0, a)
			for i in lf.nodes.size():
				var rest: Transform3D = lf.rest[i]
				(lf.nodes[i] as Node3D).transform = Transform3D(rest.basis.rotated(Vector3.UP, deg_to_rad(deg)), rest.origin)
			for c in lf.cols:
				(c as CollisionShape3D).set_deferred("disabled", a > 0.001)
