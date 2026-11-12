extends Node
## In-engine takeoff using the live settlement ship. Skippable; always hands off.
signal finished(raid_id: String, skipped: bool)

const DURATION := 8.0
const SKIP_FADE := 0.28
const AUDIO_PATH := "res://raid/audio/ship_takeoff_rumble.wav"
const NOZZLES := [Vector3(4.76, 3.08, -2.15), Vector3(4.76, 3.08, 2.15)]

var raid_id := "relay_ridge"
var playing := false
var skipped := false
var elapsed := 0.0
var fade_started := false
var skip_elapsed := 0.0
var host: Node
var ship: Node3D
var ship_home: Transform3D
var camera: Camera3D
var previous_camera: Camera3D
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var audio: AudioStreamPlayer
var effects: Node3D
var glow_meshes: Array = []
var glow_lights: Array = []
var thrust: Array = []
var dust: GPUParticles3D
var shimmer: GPUParticles3D
var skip_label: Label
var hidden_hud: Control
var hud_was_visible := true
var lift_rig: Node3D

func duration() -> float:
	return DURATION

func begin(world: Node) -> void:
	if playing:
		return
	host = world
	ship = world.get_node_or_null("LaunchpadShip") as Node3D
	if ship == null and is_instance_valid(world):
		ship = world.find_child("LaunchpadShip", true, false) as Node3D
	playing = true
	skipped = false
	elapsed = 0.0
	set_process(true)
	set_process_unhandled_input(true)
	_ensure_lift_rig()
	_capture_camera()
	_build_camera()
	_build_fade()
	_build_effects()
	_start_audio()
	if is_instance_valid(host) and host.get("player") is Node:
		var player = host.player
		if player != null:
			player.set("enabled", false)
			if player is CharacterBody3D:
				player.velocity = Vector3.ZERO
	_hide_gameplay_hud()

func request_skip() -> void:
	if not playing or skipped:
		return
	skipped = true
	fade_started = true
	skip_elapsed = 0.0
	if is_instance_valid(audio):
		audio.stop()

func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE:
			request_skip()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		request_skip()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += maxf(delta, 0.0)
	var t = clampf(elapsed / DURATION, 0.0, 1.0)
	if not skipped:
		_update_camera(t)
		_update_ship(t)
		_update_fx(t)
		if elapsed >= DURATION - 1.15:
			fade_started = true
		if is_instance_valid(fade_rect):
			var fade_t = 0.0
			if fade_started:
				fade_t = clampf((elapsed - (DURATION - 1.15)) / 1.15, 0.0, 1.0)
			fade_rect.color.a = fade_t
		if elapsed >= DURATION:
			_complete()
		return
	# Skip path: short fade from the current frame, then the same handoff.
	skip_elapsed += maxf(delta, 0.0)
	var fade_t = clampf(skip_elapsed / SKIP_FADE, 0.0, 1.0)
	if is_instance_valid(fade_rect):
		fade_rect.color.a = maxf(fade_rect.color.a, fade_t)
	_update_ship(clampf(t + 0.08, 0.0, 1.0))
	if fade_t >= 1.0:
		_complete()

func _capture_camera() -> void:
	previous_camera = get_viewport().get_camera_3d()

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "TakeoffCamera"
	camera.fov = 55.0
	camera.current = true
	if is_instance_valid(host):
		host.add_child(camera)
	else:
		add_child(camera)
	_update_camera(0.0)

func _climb_body() -> Node3D:
	if is_instance_valid(lift_rig):
		return lift_rig
	if is_instance_valid(ship):
		return ship
	return null

func _ship_origin() -> Vector3:
	var body := _climb_body()
	if body != null:
		return body.global_position
	return Vector3(22, 0, -16)

func _update_camera(t: float) -> void:
	if not is_instance_valid(camera):
		return
	# Origin already includes the ship's current lift. Do not add lift again
	# to the look target — that pointed the late camera into empty sky.
	var origin := _ship_origin()
	# Boarding-side orbit, then a chase in the last ~2s so the hull stays in frame.
	var yaw := 0.55 + t * 0.65
	var radius := 13.0 + t * 6.0
	var height := 3.6 + t * 3.2
	var chase := smoothstep(0.70, 0.90, t)
	yaw = lerpf(yaw, 0.35, chase)
	radius = lerpf(radius, 14.5, chase)
	height = lerpf(height, 1.8, chase)
	var pos := origin + Vector3(sin(yaw) * radius, height, cos(yaw) * radius)
	pos += Vector3(4.0, 0.0, 0.0) * chase
	camera.fov = lerpf(55.0, 50.0, chase)
	camera.global_position = pos
	var look := origin + Vector3(0.0, lerpf(3.2, 2.4, chase), 0.0)
	if pos.distance_squared_to(look) > 0.0001:
		camera.look_at(look, Vector3.UP)

func _lift_height(t: float) -> float:
	# Engines spool, then a smooth climb.
	var spool = clampf((t - 0.16) / 0.18, 0.0, 1.0)
	var climb = 0.0
	if t > 0.22:
		var u = clampf((t - 0.22) / 0.78, 0.0, 1.0)
		climb = u * u * (28.0 + u * 16.0)
	return spool * 0.35 + climb

func _ensure_lift_rig() -> void:
	# LaunchpadShip owns both the pad and the shuttle. Lift only the shuttle
	# (Art + construction details) so the pad stays on the ground.
	if is_instance_valid(lift_rig) or not is_instance_valid(ship):
		return
	var art := ship.get_node_or_null("Art") as Node3D
	if art == null:
		return
	lift_rig = Node3D.new()
	lift_rig.name = "TakeoffRig"
	ship.add_child(lift_rig)
	for path in ["Art", "ShipConstructionV096"]:
		var node := ship.get_node_or_null(path) as Node3D
		if node == null:
			continue
		var saved := node.global_transform
		ship.remove_child(node)
		lift_rig.add_child(node)
		node.global_transform = saved

func _update_ship(t: float) -> void:
	var body := _climb_body()
	if body == null:
		return
	if ship_home == Transform3D():
		ship_home = body.global_transform
	var lifted := ship_home
	lifted.origin.y += _lift_height(t)
	# Slight nose-up as it leaves the pad.
	var tilt := clampf((t - 0.25) * 0.18, 0.0, 0.12)
	lifted.basis = ship_home.basis.rotated(ship_home.basis.x, -tilt)
	body.global_transform = lifted

func _update_fx(t: float) -> void:
	var ignite = clampf((t - 0.04) / 0.18, 0.0, 1.0)
	var power = ignite * (0.65 + 0.35 * clampf((t - 0.2) / 0.3, 0.0, 1.0))
	for mesh in glow_meshes:
		if not is_instance_valid(mesh):
			continue
		var mat = mesh.material_override as StandardMaterial3D
		if mat == null:
			continue
		mat.emission_energy_multiplier = 0.4 + power * 6.8
		mat.albedo_color.a = 0.25 + power * 0.55
	for light in glow_lights:
		if is_instance_valid(light):
			light.light_energy = power * 4.6
	for particles in thrust:
		if is_instance_valid(particles):
			particles.emitting = power > 0.05
			particles.amount_ratio = clampf(power, 0.15, 1.0)
	if is_instance_valid(dust):
		dust.emitting = t > 0.12 and t < 0.72
		dust.amount_ratio = clampf((0.72 - t) * 2.0, 0.0, 1.0) * ignite
	if is_instance_valid(shimmer):
		shimmer.emitting = t > 0.1
		shimmer.amount_ratio = clampf(power, 0.2, 1.0)

func _build_effects() -> void:
	effects = Node3D.new()
	effects.name = "TakeoffEffects"
	var climb := _climb_body()
	if climb != null:
		climb.add_child(effects)
	elif is_instance_valid(ship):
		ship.add_child(effects)
	else:
		add_child(effects)
		effects.global_position = _ship_origin()
	for i in NOZZLES.size():
		var at: Vector3 = NOZZLES[i]
		var glow = MeshInstance3D.new()
		glow.name = "EngineGlow%d" % i
		var sphere = SphereMesh.new()
		sphere.radius = 0.38
		sphere.height = 0.76
		glow.mesh = sphere
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(1.0, 0.55, 0.18, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.48, 0.12)
		mat.emission_energy_multiplier = 0.4
		glow.material_override = mat
		glow.position = at
		effects.add_child(glow)
		glow_meshes.append(glow)
		var light = OmniLight3D.new()
		light.position = at + Vector3(0.55, 0.0, 0.0)
		light.light_color = Color(1.0, 0.55, 0.22)
		light.omni_range = 8.0
		light.light_energy = 0.0
		effects.add_child(light)
		glow_lights.append(light)
		var jet = GPUParticles3D.new()
		jet.name = "Thruster%d" % i
		jet.position = at
		jet.rotation_degrees = Vector3(0, 0, -90)
		jet.amount = 64
		jet.lifetime = 0.45
		jet.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(16, 8, 8))
		jet.process_material = _thrust_material()
		var jet_mesh = SphereMesh.new()
		jet_mesh.radius = 0.11
		jet_mesh.height = 0.22
		jet.draw_pass_1 = jet_mesh
		jet.emitting = false
		effects.add_child(jet)
		thrust.append(jet)
	dust = GPUParticles3D.new()
	dust.name = "PadDust"
	dust.position = Vector3(0, 0.12, 0)
	dust.amount = 96
	dust.lifetime = 1.35
	dust.visibility_aabb = AABB(Vector3(-12, -1, -12), Vector3(24, 8, 24))
	dust.process_material = _dust_material()
	var dust_pass = QuadMesh.new()
	dust_pass.size = Vector2(0.55, 0.55)
	dust.draw_pass_1 = dust_pass
	dust.emitting = false
	effects.add_child(dust)
	if is_instance_valid(ship) and is_instance_valid(lift_rig):
		var dust_xform := dust.global_transform
		effects.remove_child(dust)
		ship.add_child(dust)
		dust.global_transform = dust_xform
	shimmer = GPUParticles3D.new()
	shimmer.name = "HeatShimmer"
	shimmer.position = Vector3(0, 0.4, 0)
	shimmer.amount = 40
	shimmer.lifetime = 1.1
	shimmer.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 14, 12))
	shimmer.process_material = _shimmer_material()
	var haze = QuadMesh.new()
	haze.size = Vector2(0.9, 1.4)
	shimmer.draw_pass_1 = haze
	shimmer.emitting = false
	effects.add_child(shimmer)

func _thrust_material() -> ParticleProcessMaterial:
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 11.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 16.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.35
	mat.scale_max = 1.1
	mat.color = Color(1.0, 0.62, 0.22, 0.9)
	mat.damping_min = 1.0
	mat.damping_max = 3.0
	return mat

func _dust_material() -> ParticleProcessMaterial:
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 4.4
	mat.emission_ring_inner_radius = 1.2
	mat.emission_ring_height = 0.1
	mat.emission_ring_axis = Vector3.UP
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 50.0
	mat.initial_velocity_min = 0.6
	mat.initial_velocity_max = 2.8
	mat.gravity = Vector3(0, -0.4, 0)
	mat.scale_min = 0.7
	mat.scale_max = 1.8
	mat.color = Color(0.62, 0.55, 0.42, 0.45)
	return mat

func _shimmer_material() -> ParticleProcessMaterial:
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 18.0
	mat.initial_velocity_min = 1.2
	mat.initial_velocity_max = 3.4
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.8
	mat.scale_max = 1.8
	mat.color = Color(1.0, 0.78, 0.45, 0.18)
	return mat

func _build_fade() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 128
	fade_layer.name = "TakeoffFade"
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.02, 0.03, 0.04, 0.0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	fade_layer.add_child(fade_rect)
	skip_label = Label.new()
	skip_label.text = "Esc · Space · Click to skip"
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_label.anchor_left = 0
	skip_label.anchor_right = 1
	skip_label.anchor_top = 1
	skip_label.anchor_bottom = 1
	skip_label.offset_top = -64
	skip_label.offset_bottom = -24
	skip_label.add_theme_font_size_override("font_size", 16)
	skip_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78, 0.85))
	fade_layer.add_child(skip_label)

func _start_audio() -> void:
	audio = AudioStreamPlayer.new()
	audio.name = "TakeoffRumble"
	audio.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	audio.volume_db = -6.0
	add_child(audio)
	if ResourceLoader.exists(AUDIO_PATH):
		audio.stream = load(AUDIO_PATH)
	# Playing a stream under the headless Dummy driver can leave
	# AudioStreamPlaybackWAV in ObjectDB at exit. Windowed runs still play.
	if audio.stream != null and DisplayServer.get_name() != "headless":
		audio.play()

func _complete() -> void:
	if not playing:
		return
	playing = false
	set_process(false)
	set_process_unhandled_input(false)
	_stop_audio()
	_restore_gameplay_hud()
	if is_instance_valid(camera):
		camera.current = false
	if is_instance_valid(previous_camera):
		previous_camera.current = true
	var id := raid_id
	var was_skipped := skipped
	finished.emit(id, was_skipped)

func is_playing() -> bool:
	return playing

func _stop_audio() -> void:
	if not is_instance_valid(audio):
		audio = null
		return
	audio.stop()
	audio.stream = null
	audio.free()
	audio = null

func _hide_gameplay_hud() -> void:
	# The skip hint lives on this cutscene's CanvasLayer, not hud_root.
	if not is_instance_valid(host):
		return
	var root: Variant = host.get("hud_root")
	if root is Control:
		hidden_hud = root
		hud_was_visible = root.visible
		root.visible = false

func _restore_gameplay_hud() -> void:
	if is_instance_valid(hidden_hud):
		hidden_hud.visible = hud_was_visible
	hidden_hud = null

func _exit_tree() -> void:
	_restore_gameplay_hud()
	_stop_audio()
