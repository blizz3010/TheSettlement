extends Node3D
## Environmental hazard: a shorted relay cable live in a shallow puddle.
## Damages the player while their feet are inside the ring; the health component's
## i-frames set the hit rate. Primitive-built, mid-stylized raid palette.
var radius := 2.6
var damage := 12.0
var source := "live cable"
## Callable() -> bool supplied by the raid; hazards are inert while paused or downed.
var active_check: Callable
var player: Node3D
var health: Node
var sparks: Array[MeshInstance3D] = []
var light: OmniLight3D
var t := 0.0

static func mat(color: Color, metal := 0.0, rough := 0.8, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color; m.metallic = metal; m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true; m.emission = color; m.emission_energy_multiplier = glow
	return m

func _mesh(mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh; node.position = pos; node.rotation = rot; node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func build() -> void:
	name = "HazardLiveCable"
	var puddle := CylinderMesh.new()
	puddle.top_radius = radius; puddle.bottom_radius = radius; puddle.height = 0.04; puddle.radial_segments = 28
	_mesh(puddle, Vector3(0, 0.03, 0), mat(Color("24363b"), 0.6, 0.12))
	var sheen := CylinderMesh.new()
	sheen.top_radius = radius * 0.62; sheen.bottom_radius = radius * 0.62; sheen.height = 0.01; sheen.radial_segments = 24
	_mesh(sheen, Vector3(0.3, 0.055, -0.2), mat(Color("4d8a96"), 0.4, 0.05, 0.35))
	# Hazard-striped ring of low kerb blocks.
	var stripe_a := mat(Color("d9a93a"), 0.0, 0.7)
	var stripe_b := mat(Color("2b2b29"), 0.0, 0.8)
	for i in 20:
		var a := TAU * i / 20.0
		var block := BoxMesh.new(); block.size = Vector3(0.55, 0.09, 0.16)
		_mesh(block, Vector3(cos(a) * (radius + 0.12), 0.05, sin(a) * (radius + 0.12)), stripe_a if i % 2 == 0 else stripe_b, Vector3(0, -a + PI / 2, 0))
	# Snapped cable: two thick segments from a leaning post into the water.
	var post := CylinderMesh.new(); post.top_radius = 0.07; post.bottom_radius = 0.09; post.height = 2.4; post.radial_segments = 10
	_mesh(post, Vector3(-radius - 0.6, 1.15, 0.4), mat(Color("5b4a38")), Vector3(0, 0, 0.12))
	var cable_m := mat(Color("1c1f20"), 0.2, 0.5)
	var c1 := CylinderMesh.new(); c1.top_radius = 0.035; c1.bottom_radius = 0.035; c1.height = 2.2; c1.radial_segments = 8
	_mesh(c1, Vector3(-radius + 0.35, 1.25, 0.35), cable_m, Vector3(0, 0, -1.0))
	var c2 := CylinderMesh.new(); c2.top_radius = 0.035; c2.bottom_radius = 0.035; c2.height = 1.6; c2.radial_segments = 8
	_mesh(c2, Vector3(-0.7, 0.18, 0.2), cable_m, Vector3(0, 0.3, PI / 2 - 0.15))
	var spark_m := mat(Color("8fe8ff"), 0.0, 0.3, 4.0)
	for i in 5:
		var s := SphereMesh.new(); s.radius = 0.06; s.height = 0.12; s.radial_segments = 8; s.rings = 4
		sparks.append(_mesh(s, Vector3(-0.1 + i * 0.12, 0.12, 0.2 + (i % 2) * 0.1), spark_m))
	light = OmniLight3D.new()
	light.light_color = Color("8fe8ff"); light.omni_range = 5.0; light.light_energy = 1.2
	light.position = Vector3(0, 0.6, 0.2)
	add_child(light)
	# Warning sign.
	var sign_post := BoxMesh.new(); sign_post.size = Vector3(0.08, 1.5, 0.08)
	_mesh(sign_post, Vector3(radius + 0.7, 0.75, -0.6), mat(Color("4a4f4c"), 0.5, 0.5))
	var plate := BoxMesh.new(); plate.size = Vector3(0.62, 0.42, 0.04)
	_mesh(plate, Vector3(radius + 0.7, 1.45, -0.6), stripe_a)
	var label := Label3D.new()
	label.text = "LIVE\nCABLE"; label.font_size = 40; label.pixel_size = 0.004
	label.modulate = Color("1d1d1b"); label.outline_size = 0
	label.position = Vector3(radius + 0.7, 1.45, -0.575)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(label)

func contains(point: Vector3) -> bool:
	var local := to_local(point)
	return Vector2(local.x, local.z).length() <= radius and local.y > -0.6 and local.y < 1.4

func step(delta: float) -> bool:
	t += delta
	for i in sparks.size():
		sparks[i].visible = fmod(t * 7.0 + i * 1.7, 3.0) < 1.1
	light.light_energy = 0.6 + 0.8 * absf(sin(t * 23.0)) * float(fmod(t, 1.3) < 0.8)
	if health == null or player == null or not is_instance_valid(player): return false
	if active_check.is_valid() and not active_check.call(): return false
	if contains(player.global_position):
		return health.damage(damage, source)
	return false

func _physics_process(delta: float) -> void:
	step(delta)
