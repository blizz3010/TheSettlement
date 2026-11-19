extends Node
## Ori's Nov 18 playtest: the concrete path already boards (raid/tests/test_ship_boarding_route.gd),
## but nothing pointed a new player to it, and the grass on both sides of the ramp ran into a
## dead-end corner between the ramp side (its wooden rail) and the pad's retaining wall, which
## looked like a way in. Runtime-only addition; pad, ramp, rails, path and pinned files unchanged.
##  - Two timber way signs ("SHIP" + arrow) at the plaza end of the stone path and at its turn
##    north to the ramp, set off the paving so the full path width stays clear.
##  - A glowing ring on PadDeck marking the boarding zone (ShipContract.in_zone, r 1.7).
##  - A low stone-kerbed hedge bed filling each ramp-side pocket (collision + visual), so the
##    grass no longer funnels into the corner. It sits outside the ramp rail; ramp width unchanged.
##  - An approach hint in the existing prompt panel around the pad and on the south path/ramp,
##    only when no other prompt is shown and boarding is not yet possible.
const NAME := "ShipBoardingWayfinding"
const ZONE_LOCAL := Vector3(0.0, 1.28, 4.8)
## Pocket beds in ship-local coordinates: x from just outside the ramp rail (1.56) outward,
## z from inside the pad wall to 3.5 m south of it. Collision top is above a running jump (0.9 m).
const BED_X := Vector2(1.62, 3.1)
const BED_Z := Vector2(7.0, 10.5)
const BED_HEIGHT := 1.15
const GROUND_Y := -0.1
const HINT_GROUND := "Ship • Board from the south ramp: follow the stone path to the glowing ring"
const HINT_PAD := "Ship • Step into the glowing ring by the ship to board"
var world: Node
var ship: Node3D
var hint_active := false

static func install(w: Node) -> Node:
	if not is_instance_valid(w) or not w.is_inside_tree(): return null
	var existing = w.get_node_or_null(NAME)
	if existing != null: return existing
	var s = w.get_node_or_null("LaunchpadShip")
	if s == null: return null
	var node = load("res://raid/scripts/ship_boarding_wayfinding.gd").new()
	node.name = NAME
	node.world = w
	node.ship = s
	node.process_priority = 100 # after the world's own prompt pass
	w.add_child(node)
	node.build()
	return node

static func mat(color: Color, emission := 0.0, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func box(parent: Node3D, n: String, pos: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func build() -> void:
	var wood := mat(Color(0.36, 0.23, 0.12))
	var plank := mat(Color(0.24, 0.16, 0.09))
	var ink := mat(Color(0.96, 0.86, 0.56), 0.7)
	# Plaza end of StoneConnector0 (5.2, 7.8): sign faces the plaza (north), arrow east.
	make_sign("ShipSignPlaza", Vector3(3.7, 0.0, 8.9), PI, wood, plank, ink)
	# Turn of StoneConnector1 -> 2 at (22, 10): sign faces the path (west), arrow north.
	make_sign("ShipSignRampTurn", Vector3(24.1, 0.0, 11.7), -PI * 0.5, wood, plank, ink)
	# Boarding ring on PadDeck.
	var ring := MeshInstance3D.new()
	ring.name = "BoardingRing"
	var t := TorusMesh.new(); t.inner_radius = 1.5; t.outer_radius = 1.7; t.rings = 48; t.ring_segments = 6
	ring.mesh = t
	ring.material_override = mat(Color(0.35, 0.95, 0.85), 1.6, true)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(1.0, 0.04, 1.0)
	add_child(ring)
	ring.global_position = ship.to_global(ZONE_LOCAL + Vector3(0, 0.012, 0))
	# Ramp-side pocket beds.
	var stone := mat(Color(0.50, 0.48, 0.44))
	var hedge := mat(Color(0.15, 0.26, 0.10))
	var hedge_light := mat(Color(0.20, 0.33, 0.13))
	for side in [-1.0, 1.0]:
		var body := StaticBody3D.new()
		body.name = "RampPocketBed" + ("West" if side < 0 else "East")
		add_child(body)
		var cx: float = side * (BED_X.x + BED_X.y) * 0.5
		var cz: float = (BED_Z.x + BED_Z.y) * 0.5
		var size := Vector3(BED_X.y - BED_X.x, BED_HEIGHT, BED_Z.y - BED_Z.x)
		body.global_transform = Transform3D(ship.global_basis, ship.to_global(Vector3(cx, GROUND_Y + BED_HEIGHT * 0.5, cz)))
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = size
		cs.shape = bs; body.add_child(cs)
		box(body, "Kerb", Vector3(0, -BED_HEIGHT * 0.5 + 0.21, 0), Vector3(size.x, 0.42, size.z), stone)
		# Clipped shrub clumps (two staggered rows) rather than a flat block.
		var shrub := SphereMesh.new(); shrub.radius = 0.42; shrub.height = 0.72; shrub.radial_segments = 10; shrub.rings = 5
		var rows := 2
		var per_row := int(floor((size.z - 0.2) / 0.56))
		for r in rows:
			for k in per_row:
				var mi := MeshInstance3D.new(); mi.name = "Shrub%d_%d" % [r, k]
				mi.mesh = shrub
				mi.material_override = hedge if (r + k) % 3 != 0 else hedge_light
				var x := (r - (rows - 1) * 0.5) * (size.x * 0.48)
				var z := -size.z * 0.5 + 0.38 + k * 0.56 + (0.2 if r == 1 else 0.0)
				var sc := 0.92 + 0.12 * float((r * 7 + k * 3) % 5) / 4.0
				mi.scale = Vector3(sc, sc, sc)
				mi.position = Vector3(x, -BED_HEIGHT * 0.5 + 0.42 + 0.3, clampf(z, -size.z * 0.5 + 0.3, size.z * 0.5 - 0.3))
				body.add_child(mi)

func make_sign(n: String, at: Vector3, yaw: float, wood: Material, plank: Material, ink: Material) -> void:
	var root := Node3D.new()
	root.name = n
	add_child(root)
	root.global_position = at
	root.rotation.y = yaw
	# Thin post collision only, so it reads as solid without snagging the path edge.
	var body := StaticBody3D.new(); body.name = "PostCollision"; root.add_child(body)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.14, 1.7, 0.14)
	cs.shape = bs; cs.position = Vector3(0, 0.85, 0); body.add_child(cs)
	box(root, "Post", Vector3(0, 0.85, 0), Vector3(0.12, 1.7, 0.12), wood)
	box(root, "Board", Vector3(0, 1.48, 0.08), Vector3(0.95, 0.46, 0.05), plank)
	# Arrow on the board front (+z), pointing board-local -x (east at the plaza, north at the turn).
	box(root, "ArrowShaft", Vector3(0.06, 1.38, 0.112), Vector3(0.42, 0.07, 0.02), ink)
	var head := MeshInstance3D.new(); head.name = "ArrowHead"
	var pm := PrismMesh.new(); pm.size = Vector3(0.2, 0.18, 0.02); head.mesh = pm
	head.material_override = ink
	head.position = Vector3(-0.24, 1.38, 0.112)
	head.rotation.z = PI * 0.5
	root.add_child(head)
	var label := Label3D.new(); label.name = "Text"
	label.text = "SHIP"
	label.font_size = 72; label.pixel_size = 0.0035; label.outline_size = 8
	label.modulate = Color(0.96, 0.88, 0.62)
	label.position = Vector3(0, 1.58, 0.112)
	root.add_child(label)

func hint_text() -> String:
	if not is_instance_valid(world) or not is_instance_valid(ship): return ""
	var p = world.get("player")
	if not is_instance_valid(p) or not p.enabled or p.seated: return ""
	if world.get("build_mode") == true or world.modal_open(): return ""
	var local: Vector3 = ship.to_local(p.global_position)
	var d := Vector2(local.x - ZONE_LOCAL.x, local.z - ZONE_LOCAL.z).length()
	if d <= 1.7: return ""
	var r := Vector2(local.x, local.z).length()
	if r < 7.9 and local.y > 1.0: return HINT_PAD
	# Around the pad (e.g. on the grass beside its wall), or on the south path and ramp.
	var on_south_route := local.z > 6.0 and local.z < 28.0 and local.x > -12.0 and local.x < 6.0
	return HINT_GROUND if r < 12.0 or on_south_route else ""

func _process(_delta: float) -> void:
	hint_active = false
	if not is_instance_valid(world) or world.get("world_activated") != true: return
	var prompt = world.get("prompt"); var panel = world.get("prompt_panel")
	if not is_instance_valid(prompt) or not is_instance_valid(panel): return
	# Never override a real interaction prompt, including the boarding prompt itself.
	if panel.visible or not str(prompt.text).is_empty(): return
	if world.has_method("ship_can_embark") and world.ship_can_embark(): return
	var text := hint_text()
	if text.is_empty(): return
	prompt.text = text
	panel.show()
	hint_active = true
	if world.has_method("layout_status_panel"): world.layout_status_panel()
