extends Node3D
## Simple hostile: an abandoned sentry turret. Tracks the player inside its range with
## clear line of sight, telegraphs (lens brightens) for warmup seconds, then fires a
## hitscan shot every fire_interval seconds. Primitive-built, mid-stylized palette.
const Kit = preload("res://raid/scripts/hazard_zone.gd")
var detection_range := 18.0
var warmup := 0.9
var fire_interval := 1.6
var damage := 12.0
var turn_speed := 2.6  # rad/s
var source := "sentry turret"
var active_check: Callable
var player: Node3D
var health: Node
var head: Node3D
var muzzle: Node3D
var lens_material: StandardMaterial3D
var tracer: MeshInstance3D
var flash_light: OmniLight3D
var body: StaticBody3D
var aim := 0.0
var cooldown := 0.0
var tracer_left := 0.0
var shots := 0
var hits := 0
var tracking := false

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh; node.position = pos; node.rotation = rot; node.material_override = m
	parent.add_child(node)
	return node

func build() -> void:
	name = "SentryTurret"
	var concrete := Kit.mat(Color("8d8a80"))
	var olive := Kit.mat(Color("56603f"), 0.25, 0.6)
	var olive_dark := Kit.mat(Color("3d4530"), 0.3, 0.55)
	var steel := Kit.mat(Color("3a3f42"), 0.7, 0.4)
	var stripe := Kit.mat(Color("d9a93a"))
	var plinth := CylinderMesh.new(); plinth.top_radius = 0.62; plinth.bottom_radius = 0.75; plinth.height = 0.45; plinth.radial_segments = 16
	_mesh(self, plinth, Vector3(0, 0.22, 0), concrete)
	var band := CylinderMesh.new(); band.top_radius = 0.64; band.bottom_radius = 0.64; band.height = 0.08; band.radial_segments = 16
	_mesh(self, band, Vector3(0, 0.40, 0), stripe)
	var mast := CylinderMesh.new(); mast.top_radius = 0.16; mast.bottom_radius = 0.2; mast.height = 0.7; mast.radial_segments = 12
	_mesh(self, mast, Vector3(0, 0.8, 0), steel)
	head = Node3D.new(); head.name = "Head"; head.position = Vector3(0, 1.28, 0); add_child(head)
	var shell := BoxMesh.new(); shell.size = Vector3(0.62, 0.42, 0.72)
	_mesh(head, shell, Vector3.ZERO, olive)
	var brow := BoxMesh.new(); brow.size = Vector3(0.66, 0.08, 0.5)
	_mesh(head, brow, Vector3(0, 0.24, -0.08), olive_dark)
	for side in [-1, 1]:
		var cheek := BoxMesh.new(); cheek.size = Vector3(0.08, 0.34, 0.6)
		_mesh(head, cheek, Vector3(side * 0.35, -0.02, 0), olive_dark)
	var barrel := CylinderMesh.new(); barrel.top_radius = 0.045; barrel.bottom_radius = 0.06; barrel.height = 0.7; barrel.radial_segments = 10
	_mesh(head, barrel, Vector3(0.12, -0.04, -0.66), steel, Vector3(PI / 2, 0, 0))
	var shroud := CylinderMesh.new(); shroud.top_radius = 0.08; shroud.bottom_radius = 0.08; shroud.height = 0.18; shroud.radial_segments = 10
	_mesh(head, shroud, Vector3(0.12, -0.04, -0.42), olive_dark, Vector3(PI / 2, 0, 0))
	lens_material = Kit.mat(Color("ff3b2a"), 0.0, 0.2, 0.6)
	var lens := SphereMesh.new(); lens.radius = 0.075; lens.height = 0.15; lens.radial_segments = 12; lens.rings = 6
	_mesh(head, lens, Vector3(-0.14, 0.04, -0.37), lens_material)
	var antenna := CylinderMesh.new(); antenna.top_radius = 0.008; antenna.bottom_radius = 0.012; antenna.height = 0.5; antenna.radial_segments = 6
	_mesh(head, antenna, Vector3(-0.22, 0.45, 0.22), steel)
	muzzle = Node3D.new(); muzzle.name = "Muzzle"; muzzle.position = Vector3(0.12, -0.04, -1.02); head.add_child(muzzle)
	flash_light = OmniLight3D.new(); flash_light.light_color = Color("ffb067"); flash_light.omni_range = 4.0; flash_light.light_energy = 0.0
	muzzle.add_child(flash_light)
	tracer = MeshInstance3D.new(); tracer.name = "Tracer"
	var beam := BoxMesh.new(); beam.size = Vector3(0.025, 0.025, 1.0); tracer.mesh = beam
	tracer.material_override = Kit.mat(Color("ffd08a"), 0.0, 0.3, 3.0)
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tracer.visible = false; tracer.top_level = true
	add_child(tracer)
	body = StaticBody3D.new(); body.name = "TurretCollision"
	var shape := CollisionShape3D.new(); var cyl := CylinderShape3D.new(); cyl.radius = 0.7; cyl.height = 1.6
	shape.shape = cyl; shape.position = Vector3(0, 0.8, 0); body.add_child(shape); add_child(body)
	var warn := Label3D.new(); warn.text = "SENTRY ZONE"; warn.font_size = 36; warn.pixel_size = 0.006
	warn.modulate = Color("e9c25a"); warn.outline_size = 6; warn.position = Vector3(0, 2.15, 0)
	warn.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(warn)

func target_point() -> Vector3:
	return player.global_position + Vector3(0, 1.2, 0)

func has_line_of_sight() -> bool:
	if not is_inside_tree() or player == null: return false
	var from := muzzle.global_position
	var query := PhysicsRayQueryParameters3D.create(from, target_point())
	var exclude: Array[RID] = [body.get_rid()]
	if player is CollisionObject3D: exclude.append(player.get_rid())
	query.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func can_engage() -> bool:
	if player == null or not is_instance_valid(player) or health == null or health.dead: return false
	if active_check.is_valid() and not active_check.call(): return false
	if global_position.distance_to(player.global_position) > detection_range: return false
	return has_line_of_sight()

func step(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	if tracer_left > 0.0:
		tracer_left -= delta
		if tracer_left <= 0.0: tracer.visible = false; flash_light.light_energy = 0.0
	tracking = can_engage()
	if not tracking:
		aim = maxf(0.0, aim - delta * 2.0)
		lens_material.emission_energy_multiplier = 0.6
		return false
	# Yaw the head toward the player (its -Z is the barrel direction).
	var to := player.global_position - head.global_position
	var desired := atan2(-to.x, -to.z) - global_rotation.y
	head.rotation.y = rotate_toward(head.rotation.y, desired, turn_speed * delta)
	aim = minf(warmup, aim + delta)
	lens_material.emission_energy_multiplier = 0.6 + 5.0 * (aim / warmup)
	if aim < warmup or cooldown > 0.0: return false
	return fire()

func fire() -> bool:
	shots += 1
	cooldown = fire_interval
	var from := muzzle.global_position
	var to := target_point()
	tracer.visible = true; tracer_left = 0.09
	tracer.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), (from + to) * 0.5)
	tracer.scale = Vector3(1, 1, from.distance_to(to))
	flash_light.light_energy = 3.0
	var landed: bool = health.damage(damage, source)
	if landed: hits += 1
	return landed

func _physics_process(delta: float) -> void:
	step(delta)
