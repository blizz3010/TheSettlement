extends RefCounted
## Settlement visuals rollout chunk 2: dresses the remaining bare zones from the
## coverage map with the approved mid-stylized kit (border grass, ferns, flowers,
## broadleaf trees, boulders, a few props). Visual only. Ground heights come from
## SettlementTerrain so plants sit on the sloped west mound.
## Keeps clear: paths, trader fronts, ship approach, future sites A/B, the inn
## lake, the hideout reservation and its 12x12 build turf.

const Kit = preload("res://raid/scripts/settlement_visuals_kit.gd")
const Terrain = preload("res://scripts/settlement_terrain.gd")
const ROOT_NAME := "SettlementVisualsRollout2"

# Rects that must stay empty (x, z, w, d), world metres.
const KEEP_CLEAR := [
	Rect2(-34.5, 4.5, 24.0, 21.0),   # hideout reservation + stash + rails (1 m margin)
	Rect2(-19.0, 10.0, 14.0, 9.0),   # both stair flights
	Rect2(-27.0, -9.0, 23.0, 11.0),  # original west paved route and counter (1 m margin)
	Rect2(-11.0, 31.5, 10.0, 9.0),   # future site A (1 m margin)
	Rect2(5.0, 33.5, 10.0, 9.0),     # future site B (1 m margin)
	Rect2(-13.0, -36.0, 26.0, 26.0), # hall shell and entrances
	Rect2(24.5, -4.0, 13.0, 14.0),   # Psy shop + apron
	Rect2(18.0, 11.0, 14.0, 15.0),   # Atlas shop
	Rect2(-2.0, 18.0, 16.0, 12.0)    # Dan shop + apron
]
const KEEP_CLEAR_DISCS := [
	[Vector2(-7.0, 2.0), 4.5],    # west trader front
	[Vector2(-11.2, 6.7), 2.0],   # griddle station
	[Vector2(-5.8, -9.1), 3.0],   # request board
	[Vector2(22.0, -16.0), 12.0]  # launch pad + ship approach
]
const PATH_CLEARANCE := 2.1

# Zones. Each: name, seed, drifts [centre, radius, grass, fern, flower],
# trees [pos, variant, scale, yaw], rocks [pos, scale].
static func zones() -> Array:
	return [
		{
			# Open lawn between the hideout's north foot and the lake shore.
			# Stops at z 34 (shore stays clear) and x -12.5 (site A stays clear).
			"name": "NorthLawn", "seed": 52001,
			"drifts": [
				[Vector2(-28.0, 27.4), 2.6, 46, 8, 18],
				[Vector2(-23.0, 26.3), 2.0, 34, 6, 14],
				[Vector2(-16.6, 26.2), 2.4, 42, 8, 18],
				[Vector2(-14.6, 30.4), 2.2, 38, 7, 16],
				[Vector2(-20.6, 31.6), 2.8, 48, 9, 20],
				[Vector2(-29.2, 31.2), 2.2, 36, 6, 14]
			],
			"trees": [
				[Vector2(-29.4, 30.2), 0, 1.0, 0.4],
				[Vector2(-13.4, 32.2), 1, 0.95, 2.1],
				[Vector2(-25.4, 33.0), 2, 1.05, -1.2]
			],
			"rocks": [
				[Vector2(-27.0, 28.6), Vector3(0.70, 0.45, 0.60)],
				[Vector2(-21.8, 32.6), Vector3(0.55, 0.36, 0.50)],
				[Vector2(-15.8, 29.2), Vector3(0.80, 0.50, 0.65)],
				[Vector2(-17.4, 26.9), Vector3(0.40, 0.28, 0.38)]
			]
		},
		{
			# Outer west mound: open lawn beyond the tree band behind the tailor,
			# inside the grass radius (r < 46).
			"name": "WestMound", "seed": 52002,
			"drifts": [
				[Vector2(-41.0, -14.0), 3.0, 50, 10, 18],
				[Vector2(-44.0, -6.0), 2.8, 46, 9, 16],
				[Vector2(-40.0, -1.5), 2.4, 38, 7, 14],
				[Vector2(-42.0, 2.5), 2.4, 38, 7, 14],
				[Vector2(-38.6, -19.0), 2.4, 38, 7, 12],
				[Vector2(-45.0, -12.0), 2.6, 44, 8, 16],
				[Vector2(-46.0, 3.0), 2.2, 34, 6, 12]
			],
			"trees": [
				[Vector2(-43.0, -17.0), 3, 1.0, 0.9],
				[Vector2(-45.0, -2.0), 1, 0.92, -0.6],
				[Vector2(-40.5, -8.5), 0, 1.05, 2.6],
				[Vector2(-46.4, -14.6), 2, 1.0, -2.0]
			],
			"rocks": [
				[Vector2(-42.6, -11.6), Vector3(1.10, 0.70, 0.90)],
				[Vector2(-43.6, -12.6), Vector3(0.60, 0.40, 0.55)],
				[Vector2(-39.2, -4.2), Vector3(0.85, 0.55, 0.75)],
				[Vector2(-44.8, 0.8), Vector3(0.70, 0.45, 0.60)],
				[Vector2(-40.0, -16.4), Vector3(0.90, 0.60, 0.80)],
				[Vector2(-45.2, -8.4), Vector3(0.50, 0.34, 0.45)]
			]
		}
	]


static func apply(world: Node3D, zone_list: Array) -> Node3D:
	if world.has_node(ROOT_NAME):
		return world.get_node(ROOT_NAME)
	var root := Node3D.new()
	root.name = ROOT_NAME
	root.set_meta("visual_only", true)
	world.add_child(root)
	for z in zone_list:
		_build_zone(root, z)
	return root


static func blocked(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	for r in KEEP_CLEAR:
		if r.has_point(p):
			return true
	for d in KEEP_CLEAR_DISCS:
		if p.distance_to(d[0]) < d[1]:
			return true
	for path in Terrain.PATHS:
		if Terrain.segment_distance(p, path[0], path[1]) < PATH_CLEARANCE:
			return true
	return false


static func ground(x: float, z: float) -> float:
	return Terrain.height_at(x, z)


static func _build_zone(root: Node3D, zone: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = zone["name"]
	root.add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(zone.get("seed", 1))
	var mats := Kit.materials()
	var msh := Kit.meshes()
	var grass: Array[Transform3D] = []
	var grass_c: Array[Color] = []
	var ferns: Array[Transform3D] = []
	var fern_c: Array[Color] = []
	var flowers: Array[Transform3D] = []
	var flower_c: Array[Color] = []
	for d in zone.get("drifts", []):
		_drift(d[0], float(d[1]), int(d[2]), rng, grass, grass_c, 0.85, 1.35, "grass")
		_drift(d[0], float(d[1]) * 0.8, int(d[3]), rng, ferns, fern_c, 0.85, 1.30, "fern")
		_drift(d[0], float(d[1]) * 0.9, int(d[4]), rng, flowers, flower_c, 0.90, 1.30, "flower")
	Kit.spawn_colored(holder, "BorderGrass", msh["grass"], mats["leaf_mat"], grass, grass_c, false)
	Kit.spawn_colored(holder, "Ferns", msh["fern"], mats["leaf_mat"], ferns, fern_c, false)
	Kit.spawn_colored(holder, "Flowers", msh["flower_head"], mats["petal_mat"], flowers, flower_c, false)
	Kit.spawn_plain(holder, "FlowerStems", msh["flower_stem"], mats["stem_mat"], flowers, false)
	var ti := 0
	for t in zone.get("trees", []):
		var at: Vector2 = t[0]
		if blocked(at.x, at.y):
			push_warning("rollout2 tree in keep-clear: %s" % str(at))
			continue
		Kit.add_tree(holder, "%sTree%d" % [zone["name"], ti], Vector3(at.x, ground(at.x, at.y) - 0.04, at.y), int(t[1]), float(t[2]), float(t[3]))
		ti += 1
	var rocks: Array[Transform3D] = []
	for r in zone.get("rocks", []):
		var at: Vector2 = r[0]
		if blocked(at.x, at.y):
			continue
		var s: Vector3 = r[1]
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0, TAU), rng.randf_range(-0.2, 0.2))).scaled(s)
		rocks.append(Transform3D(b, Vector3(at.x, ground(at.x, at.y) + s.y * 0.15, at.y)))
	Kit.spawn_plain(holder, "Boulders", msh["lobe"], mats["stone"], rocks, true)


static func _drift(c: Vector2, radius: float, n: int, rng: RandomNumberGenerator, out: Array[Transform3D], cols: Array[Color], s0: float, s1: float, kind: String) -> void:
	# Irregular drift: dense core, ragged edge (radius wobbles with angle).
	var placed := 0
	var tries := 0
	var phase := rng.randf_range(0.0, TAU)
	while placed < n and tries < n * 4:
		tries += 1
		var ang := rng.randf_range(0.0, TAU)
		var edge := radius * (1.0 + 0.28 * sin(ang * 3.0 + phase) + 0.12 * sin(ang * 5.0 - phase))
		var r := edge * sqrt(rng.randf()) * (0.55 + 0.45 * rng.randf())
		var x := c.x + cos(ang) * r
		var z := c.y + sin(ang) * r
		if blocked(x, z):
			continue
		var y := ground(x, z) - 0.03
		var s := rng.randf_range(s0, s1)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.08, 0.08), rng.randf_range(0.0, TAU), rng.randf_range(-0.08, 0.08))).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s))
		out.append(Transform3D(basis, Vector3(x, y, z)))
		cols.append(_color(kind, rng))
		placed += 1


static func _color(kind: String, rng: RandomNumberGenerator) -> Color:
	match kind:
		"grass":
			var g := [Color(0.24, 0.38, 0.15), Color(0.30, 0.44, 0.17), Color(0.36, 0.46, 0.18), Color(0.28, 0.36, 0.16)]
			return g[rng.randi_range(0, g.size() - 1)]
		"fern":
			var f := [Color(0.18, 0.32, 0.15), Color(0.22, 0.36, 0.17), Color(0.26, 0.38, 0.18)]
			return f[rng.randi_range(0, f.size() - 1)]
		_:
			var p := [Color(0.62, 0.40, 0.78), Color(0.92, 0.76, 0.28), Color(0.90, 0.52, 0.62), Color(0.94, 0.90, 0.78), Color(0.84, 0.44, 0.30)]
			return p[rng.randi_range(0, p.size() - 1)]
