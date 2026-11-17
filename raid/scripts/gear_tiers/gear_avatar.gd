extends Node3D
## Third-person gear avatar (TASKS item 22, gear art E0). When the player wears a tiered
## piece that has real art (gear_art.gd) - or always, once the default outfit
## (raid/scripts/outfit/default_outfit.gd) is available - the third-person stand-in capsule of the pinned
## player.gd is swapped for the Appearance-Proof character rig wearing the skinned gear,
## driven by a small procedural walk / sprint / crouch cycle read from the player's own
## velocity and crouch state (pinned player.gd is untouched; this node only lives under its
## `avatar` holder, so V still shows/hides it exactly like the capsule).
## With no worn art nothing is installed and the capsule stays as before.
const SOURCE := "res://models/Appearance-Proof.glb"
const SELF_PATH := "res://raid/scripts/gear_tiers/gear_avatar.gd"
const GearArt = preload("res://raid/scripts/gear_tiers/gear_art.gd")
const DefaultOutfit = preload("res://raid/scripts/outfit/default_outfit.gd")
const SCALE := 1.12          # 1.55 m rig -> ~1.74 m, close to the 1.8 m player capsule
const ARMS_DOWN := 38.0
const ARMS_DOWN_VEST := 32.0
const SPRINT_VEST_OUT := 4.0
const SPRINT_SPEED := 5.0    # player.gd: 7.0 sprinting, 4.2 walking, 2.0 crouched
var player: Node
var rig: Node3D
var skeleton: Skeleton3D
var worn: Array = []
var phase := 0.0
var state := "idle"
var pose_override := ""      # captures/tests: "idle", "walk", "sprint", "crouch", "crouch_walk", "seated"
var override_phase := 0.0
var _rest_foot := 0.0

static func install(p: Node, worn_ids: Array) -> Node3D:
	if p == null or not is_instance_valid(p): return null
	var holder = p.get("avatar")
	if not holder is MeshInstance3D: return null
	var existing: Node3D = holder.get_node_or_null("GearAvatar")
	var art := []
	for id in worn_ids:
		if GearArt.has_art(str(id)): art.append(str(id))
	# With the default outfit available the character always shows (dressed, no gear);
	# without it, no worn art keeps the capsule as before.
	if art.is_empty() and not DefaultOutfit.available():
		if existing != null:
			holder.remove_child(existing); existing.queue_free()
		if holder.has_meta("gear_capsule_look"):
			var look: Array = holder.get_meta("gear_capsule_look")
			holder.layers = look[0]; holder.cast_shadow = look[1]; holder.remove_meta("gear_capsule_look")
		return null
	if existing == null:
		existing = load(SELF_PATH).new()
		existing.name = "GearAvatar"
		existing.player = p
		holder.add_child(existing)
	# player.gd keeps resizing avatar.mesh (crouch / seat), so the capsule mesh stays in place
	# and is only taken off every render layer (children such as this avatar are unaffected).
	if not holder.has_meta("gear_capsule_look"):
		holder.set_meta("gear_capsule_look", [holder.layers, holder.cast_shadow])
		holder.layers = 0
		holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	existing.set_worn(art)
	return existing

## Worn tiered defs straight from a gear locker state (gear_locker_state.gd).
static func worn_defs(locker_state) -> Array:
	var out := []
	if locker_state == null: return out
	for iid in locker_state.equipped_ids(): out.append(str(locker_state.owned[iid].def))
	return out

func _ready():
	var packed := load(SOURCE) as PackedScene
	if packed == null: return
	rig = packed.instantiate() as Node3D
	rig.name = "AvatarRig"
	add_child(rig)
	skeleton = rig.find_child("Skeleton3D", true, false) as Skeleton3D
	# One look: short hair (the helmet straps are fitted over it), one brow/eye set, and the
	# technical-neutral body skin toned down so it does not clip to white in daylight.
	for pair in [["hair_short02_v1", "hair_bob01_v1"], ["brow_009_v1", "brow_001_v1"], ["eye_brown_v1", "eye_blue_v1"]]:
		var keep := rig.find_child(pair[0], true, false)
		var drop := rig.find_child(pair[1], true, false)
		if keep is Node3D: keep.visible = true
		if drop is Node3D: drop.visible = false
	var body := rig.find_child("ProofBody", true, false) as MeshInstance3D
	if body != null and body.mesh != null:
		for si in body.mesh.get_surface_count():
			var m := body.get_active_material(si) as BaseMaterial3D
			if m == null: continue
			var t := m.duplicate() as BaseMaterial3D
			t.albedo_color = t.albedo_color * Color(0.66, 0.54, 0.46)
			body.set_surface_override_material(si, t)
	# Default outfit under the gear; the skin it covers is cut out of the body.
	if skeleton != null: DefaultOutfit.dress(skeleton, DefaultOutfit.ORDER, 0, body)
	# Holder sits at the capsule centre (player.gd moves it for crouch / seat); _process keeps
	# this node on the player's floor. Faces -Z like the player.
	position = Vector3(0, -0.9, 0)
	rotation.y = PI
	scale = Vector3.ONE * SCALE
	if skeleton != null:
		_rest_foot = skeleton.get_bone_global_rest(skeleton.find_bone("foot_r")).origin.y
		GearArt.show_worn(skeleton, worn, 0)

func _torso_gear() -> bool:
	return "jacket_torso" in GearArt.covered(worn)

func set_worn(ids: Array) -> void:
	worn = ids.duplicate()
	if skeleton != null: GearArt.show_worn(skeleton, worn, 0)

func outfit_pieces() -> Array:
	return DefaultOutfit.pieces_on(skeleton)

func attached_ids() -> Array:
	var out := []
	if skeleton == null: return out
	for c in skeleton.get_children():
		if c.has_meta("gear_art_id"): out.append(str(c.get_meta("gear_art_id")))
	return out

func _process(delta: float) -> void:
	if skeleton == null: return
	var holder := get_parent() as Node3D
	if holder != null: position.y = -holder.position.y
	if not pose_override.is_empty():
		apply_pose(pose_override, override_phase)
		return
	var v: Vector3 = player.get("velocity") if player != null and player.get("velocity") != null else Vector3.ZERO
	var speed := Vector2(v.x, v.z).length()
	var crouched: bool = player != null and player.get("crouched") == true
	if player != null and player.get("seated") == true: state = "seated"
	elif crouched: state = "crouch_walk" if speed > 0.3 else "crouch"
	elif speed > SPRINT_SPEED: state = "sprint"
	elif speed > 0.3: state = "walk"
	else: state = "idle"
	phase = fmod(phase + delta * (2.2 + speed * 1.15), TAU)
	apply_pose(state, phase)

# --------------------------------------------------------------------- posing
func _rot(bone: String, axis: Vector3, degrees: float) -> void:
	var i := skeleton.find_bone(bone)
	if i < 0 or is_zero_approx(degrees): return
	var g := skeleton.get_bone_global_pose(i)
	var parent := skeleton.get_bone_parent(i)
	var pg := skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var want := Basis(axis.normalized(), deg_to_rad(degrees)) * g.basis
	skeleton.set_bone_pose_rotation(i, (pg.basis.inverse() * want).get_rotation_quaternion())

## Sagittal-plane procedural poses. In rig space +Z is forward, so a negative turn about +X
## swings a hanging limb forward, a positive one bends a knee back or leans the spine forward.
func apply_pose(kind: String, ph: float) -> void:
	skeleton.reset_bone_poses()
	var s := sin(ph)
	var X := Vector3.RIGHT
	# A-pose (~48 deg out) -> arms hanging ~10 deg off the body; over a plate carrier they rest
	# on its cummerbund wings instead (~16 deg off), so the upper arms don't sink into the vest.
	var arms_down := ARMS_DOWN_VEST if _torso_gear() else ARMS_DOWN
	# Sprinting swings the upper arm well behind the body: over a carrier it clears the rear
	# plate corner only when held a little further out.
	if kind == "sprint" and _torso_gear(): arms_down -= SPRINT_VEST_OUT
	_rot("upperarm_l", Vector3.FORWARD, arms_down)
	_rot("upperarm_r", Vector3.FORWARD, -arms_down)
	match kind:
		"walk":
			_cycle(s, 24.0, 38.0, 18.0, 14.0, 4.0)
		"sprint":
			_rot("spine_01", X, 8.0); _rot("spine_03", X, 7.0); _rot("neck_01", X, -10.0)
			_cycle(s, 42.0, 80.0, 34.0, 55.0, 8.0)
		"crouch", "crouch_walk":
			var a := 0.35 if kind == "crouch_walk" else 0.0
			_rot("spine_01", X, 16.0); _rot("spine_03", X, 10.0); _rot("neck_01", X, -18.0)
			for side in ["l", "r"]:
				var k := s * a * (1.0 if side == "l" else -1.0)
				_rot("thigh_" + side, X, -78.0 - 22.0 * k)
				_rot("calf_" + side, X, 105.0 + 10.0 * k)
				_rot("foot_" + side, X, -24.0 + 8.0 * k)
				_rot("upperarm_" + side, X, -22.0 + 12.0 * k)
				_rot("lowerarm_" + side, X, -38.0)
		"seated":
			_rot("spine_01", X, -4.0)
			for side in ["l", "r"]:
				_rot("thigh_" + side, X, -88.0)
				_rot("calf_" + side, X, 86.0)
				_rot("upperarm_" + side, X, -14.0)
				_rot("lowerarm_" + side, X, -48.0)
			var pel := skeleton.get_bone_global_pose(skeleton.find_bone("pelvis")).origin.y
			if rig != null: rig.position.y = 0.09 / SCALE - pel
			return
		_:   # idle: breathing sway
			_rot("spine_03", X, 1.5 * s)
			for side in ["l", "r"]: _rot("lowerarm_" + side, X, -10.0)
	# Keep the lower foot on the floor (crouch lowers the hips).
	var low := minf(skeleton.get_bone_global_pose(skeleton.find_bone("foot_r")).origin.y,
		skeleton.get_bone_global_pose(skeleton.find_bone("foot_l")).origin.y)
	if rig != null: rig.position.y = _rest_foot - low

func _cycle(s: float, hip: float, knee: float, arm: float, elbow: float, twist: float) -> void:
	var X := Vector3.RIGHT
	for side in ["l", "r"]:
		var k := s if side == "l" else -s
		_rot("thigh_" + side, X, -hip * k)
		_rot("calf_" + side, X, knee * maxf(0.0, -k) + 6.0)
		_rot("foot_" + side, X, -6.0 * k)
		_rot("upperarm_" + side, X, arm * k)
		_rot("lowerarm_" + side, X, -elbow - 6.0 * maxf(0.0, -k))
	_rot("spine_03", Vector3.UP, twist * s)
	_rot("pelvis", Vector3.UP, -twist * 0.6 * s)
