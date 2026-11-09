extends CharacterBody3D
var vitals=preload("res://scripts/player_vitals.gd").new()
var camera: Camera3D
var pitch := -0.04
var third_person := false
var enabled := true
var mouse_sensitivity := 0.002
var invert_y := false
const STANDING_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1
const STANDING_EYE := 1.68
const CROUCH_EYE := 0.98
const CROUCH_SPEED := 2.0
const EYE_SMOOTH_TIME := 0.065
const EYE_CLEARANCE_RADIUS := 0.08
var visual_eye_height := STANDING_EYE
var camera_eye_height := STANDING_EYE
var step_view_offset := 0.0
var eye_clearance_shape: SphereShape3D
var crouched := false
var body_shape: CollisionShape3D
var standing_shape: CapsuleShape3D
var step_supported := false
var last_motion_position := Vector3.INF
const SEATED_HEIGHT := .9
const SEATED_EYE := .8
var seated := false
var seated_exits: Array[Vector3] = []
var avatar: Node3D
func _ready():
	floor_snap_length = 0.32
	var shape = CollisionShape3D.new()
	body_shape = shape
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = STANDING_HEIGHT
	standing_shape = capsule.duplicate()
	eye_clearance_shape = SphereShape3D.new()
	eye_clearance_shape.radius = EYE_CLEARANCE_RADIUS
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	camera = Camera3D.new()
	camera.position = Vector3(0,1.68,0)
	camera.fov = 76
	camera.current = true
	add_child(camera)
	avatar = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.radius = 0.3
	mesh.height = 1.7
	avatar.mesh = mesh
	avatar.position.y = 0.9
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("526365")
	avatar.material_override = mat
	add_child(avatar)
	avatar.visible = false
func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and enabled:
		rotation.y -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch-event.relative.y*mouse_sensitivity*(-1.0 if invert_y else 1.0),-1.25,1.25)
		camera.rotation.x = pitch
func _physics_process(delta):
	var direction = Vector3.ZERO
	# Menus keep physics running but must not change stance from captured bindings.
	if controls_active():
		update_crouch(Input.is_action_pressed("crouch"))
	if controls_active():
		direction = Vector3(float(Input.is_action_pressed("right"))-float(Input.is_action_pressed("left")),0,float(Input.is_action_pressed("backward"))-float(Input.is_action_pressed("forward")))
		direction = (basis * direction).normalized()
	var speed = 7.0 if Input.is_action_pressed("sprint") else 4.2
	step_motion(direction,speed,controls_active() and Input.is_action_pressed("jump"),delta)
func step_motion(direction: Vector3, speed: float, jumping: bool, delta: float):
	if seated:
		velocity = Vector3.ZERO
		update_eye_height(delta)
		update_camera_view()
		return
	var foot_before = global_position
	var teleported = not last_motion_position.is_finite() or foot_before.distance_to(last_motion_position)>1.0
	if teleported:
		step_supported=false
		step_view_offset=0.0
	var was_grounded = not teleported and (is_on_floor() or (step_supported and velocity.y<=0))
	step_supported = false
	var stepped_up = false
	if crouched:
		speed = minf(speed, CROUCH_SPEED)
	velocity.x = move_toward(velocity.x,direction.x*speed,20*delta)
	velocity.z = move_toward(velocity.z,direction.z*speed,20*delta)
	if not was_grounded: velocity.y -= 20 * delta
	elif jumping: velocity.y = 6
	# Step up low foundation edges and the hall threshold; never teleport through tall walls.
	var horizontal = Vector3(velocity.x,0,velocity.z)*delta
	if was_grounded and not jumping and horizontal.length() > 0.001 and test_move(global_transform,horizontal):
		var raised = global_transform
		raised.origin.y += 0.32
		if not test_move(global_transform,Vector3(0,0.32,0)) and not test_move(raised,horizontal):
			global_position.y += 0.32
			stepped_up = true
	move_and_slide()
	if stepped_up and not jumping:
		var landing = move_and_collide(Vector3(0,-0.32,0))
		step_supported = landing != null and landing.get_normal().y>0.1
	# Settle onto the actual tread after the clearance sweep, not an artificial32cm hop.
	if was_grounded and not jumping and velocity.y<=0: apply_floor_snap()
	if position.y < -10: position = Vector3(0,1,11)
	last_motion_position=global_position
	var vertical_step=global_position.y-foot_before.y
	if was_grounded and not jumping and absf(vertical_step)<=0.34:
		step_view_offset=clampf(step_view_offset-vertical_step,-0.32,0.32)
	elif jumping or absf(vertical_step)>0.34: step_view_offset=0.0
	step_view_offset*=exp(-maxf(delta,0.0)/0.055)
	if absf(step_view_offset)<0.001: step_view_offset=0.0
	update_eye_height(delta)
	update_camera_view()

func update_camera_view():
	if third_person:
		var desired = global_position + Vector3(0,camera_eye_height+0.02,0) + basis * Vector3(0,1.0,3.5)
		var query = PhysicsRayQueryParameters3D.create(global_position+Vector3(0,camera_eye_height+0.02,0),desired)
		query.exclude = [get_rid()]
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		camera.global_position = hit.position + hit.normal*0.2 if hit else desired
	else: camera.position = Vector3(0,camera_eye_height,0)
func toggle_view():
	third_person = not third_person
	avatar.visible = third_person

func controls_active() -> bool:
	return enabled and not seated and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func eye_height() -> float:
	return SEATED_EYE if seated else CROUCH_EYE if crouched else STANDING_EYE

func can_stand() -> bool:
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = standing_shape
	query.transform = global_transform * Transform3D(Basis.IDENTITY, Vector3(0, STANDING_HEIGHT * 0.5 + 0.002, 0))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func update_crouch(requested: bool):
	if seated: return
	if requested == crouched: return
	# No mid-air capsule shrinking/ledge-grab exploit. Feet never move on transition.
	if requested and not is_on_floor(): return
	if not requested and not can_stand(): return
	crouched = requested
	var height = CROUCH_HEIGHT if crouched else STANDING_HEIGHT
	body_shape.shape.height = height
	body_shape.position.y = height * 0.5
	avatar.mesh.height = height - 0.1
	avatar.position.y = height * 0.5


func update_eye_height(delta: float):
	# Smooth the view only. Capsule/feet and standing clearance remain authoritative.
	var target = eye_height()
	visual_eye_height = lerpf(visual_eye_height, target, 1.0-exp(-maxf(delta,0.0)/EYE_SMOOTH_TIME))
	if absf(visual_eye_height-target)<0.001: visual_eye_height=target
	camera_eye_height=visual_eye_height+step_view_offset
	var sweep_base := SEATED_EYE if seated else CROUCH_EYE
	if camera_eye_height>sweep_base:
		# The shorter capsule may enter an overhang before the view finishes lowering.
		# Sweep a small eye-volume UP from the safe crouched eye and clamp instantly.
		var query=PhysicsShapeQueryParameters3D.new()
		query.shape=eye_clearance_shape
		query.transform=global_transform*Transform3D(Basis.IDENTITY,Vector3(0,sweep_base,0))
		query.motion=global_basis.y*(camera_eye_height-sweep_base)
		query.collision_mask=collision_mask
		query.exclude=[get_rid()]
		query.margin=0.01
		var safe=get_world_3d().direct_space_state.cast_motion(query)
		camera_eye_height=sweep_base+(camera_eye_height-sweep_base)*safe[0]
		if safe[0]<1.0: visual_eye_height=minf(visual_eye_height,camera_eye_height-step_view_offset)

# Sitting uses a short collision capsule above the seat, never a disabled body.
func seat_shape() -> CapsuleShape3D:
	var shape := CapsuleShape3D.new()
	shape.radius = .24
	shape.height = SEATED_HEIGHT
	return shape

func shape_clear_at(foot: Vector3, shape: CapsuleShape3D) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, foot + Vector3.UP * (shape.height * .5 + .005))
	query.exclude = [get_rid()]
	query.collision_mask = collision_mask
	query.margin = .002
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func seated_sweep_clear(a: Vector3, b: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = seat_shape()
	query.transform = Transform3D(Basis.IDENTITY, a + Vector3.UP * (SEATED_HEIGHT * .5 + .005))
	query.motion = b-a
	query.exclude = [get_rid()]
	query.collision_mask = collision_mask
	query.margin = .002
	return shape_clear_at(a, query.shape) and shape_clear_at(b, query.shape) and get_world_3d().direct_space_state.cast_motion(query)[0] >= .999

func grounded_exit(candidate: Vector3) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * .3, candidate - Vector3.UP * .3, collision_mask, [get_rid()])
	var hit = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or hit.normal.y < .8: return null
	var foot: Vector3 = hit.position + Vector3.UP * .006
	if not shape_clear_at(foot, standing_shape): return null
	# Ground under capsule footprint, not merely a pinhead or ledge edge.
	for offset in [Vector3(.25,0,0),Vector3(-.25,0,0),Vector3(0,0,.25),Vector3(0,0,-.25)]:
		q.from = foot + offset + Vector3.UP * .12
		q.to = foot + offset - Vector3.UP * .12
		var edge = get_world_3d().direct_space_state.intersect_ray(q)
		if edge.is_empty() or edge.normal.y < .8 or absf(edge.position.y-hit.position.y) > .06: return null
	return foot

func try_begin_sit(origin: Vector3, yaw: float, exits: Array[Vector3]) -> bool:
	if seated or not enabled or global_position.distance_to(origin)>2.3 or not is_on_floor(): return false
	if not shape_clear_at(origin, seat_shape()): return false
	# Raise safely before moving toward seat; no passage through chair backs/walls.
	var raised := Vector3(global_position.x, origin.y, global_position.z)
	if origin.y-global_position.y < .2 or origin.y-global_position.y > .8: return false
	if not seated_sweep_clear(global_position, raised) or not seated_sweep_clear(raised, origin): return false
	var can_exit := false
	for candidate in exits:
		var foot = grounded_exit(candidate)
		if foot != null and seated_sweep_clear(origin, Vector3(foot.x,origin.y,foot.z)) and seated_sweep_clear(Vector3(foot.x,origin.y,foot.z),foot): can_exit = true
	if not can_exit: return false
	var old_eye := global_position.y + camera_eye_height
	seated = true
	seated_exits = exits.duplicate()
	crouched = false
	global_position = origin
	rotation.y = yaw
	body_shape.shape = seat_shape()
	body_shape.position.y = SEATED_HEIGHT*.5
	avatar.mesh.height = SEATED_HEIGHT-.1
	avatar.mesh.radius = .22
	avatar.position.y = SEATED_HEIGHT*.5
	velocity = Vector3.ZERO
	step_supported = false
	step_view_offset = 0
	last_motion_position = global_position
	visual_eye_height = clampf(old_eye-global_position.y, SEATED_EYE, STANDING_EYE)
	update_eye_height(0)
	update_camera_view()
	return true

func try_stand_from_seat() -> bool:
	if not seated: return true
	for candidate in seated_exits:
		var foot = grounded_exit(candidate)
		if foot == null: continue
		var raised := Vector3(foot.x,global_position.y,foot.z)
		if not seated_sweep_clear(global_position,raised) or not seated_sweep_clear(raised,foot): continue
		var old_eye := global_position.y+camera_eye_height
		global_position = foot
		seated = false
		seated_exits.clear()
		body_shape.shape = standing_shape.duplicate()
		body_shape.position.y = STANDING_HEIGHT*.5
		avatar.mesh.height = STANDING_HEIGHT-.1
		avatar.mesh.radius = .3
		avatar.position.y = STANDING_HEIGHT*.5
		velocity = Vector3.ZERO
		step_supported = false
		step_view_offset = 0
		last_motion_position = global_position
		visual_eye_height = clampf(old_eye-global_position.y,CROUCH_EYE,STANDING_EYE)
		update_eye_height(0)
		update_camera_view()
		return true
	return false
