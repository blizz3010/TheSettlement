extends Node
## Queue item 2a (Michael, Nov 19): "make jumping a little higher so you can jump over stuff".
## scripts/player.gd is pinned (tools/pinned-r8-runtime.json): its step_motion sets
## `velocity.y = 6` on the take-off frame (gravity 20), a foot rise of about 0.95 m at 60 Hz.
## This child node runs right after the player's own _physics_process (same priority, later in
## tree order) and raises only that take-off velocity, on the frame it is set, to
## JUMP_VELOCITY. Gravity, air control, step-up, floor snap and landing are unchanged.
## Measured (raid/tests/test_jump_tuning.gd, 60 Hz): base peak 0.95 m, a running jump gets over
## thin rails up to ~1.0 m but never 1.1 m. At 6.25 the peak is ~1.03 m: 1.1 m railings (the ship
## ramp rail, pad edge rail, terrace barriers) become jumpable, while 1.15 m rails/planting beds,
## the 1.28 m pad retaining wall, fences and walls still block. Above ~6.4 the capsule's rounded
## bottom starts riding over 1.15 m edges, so keep this below that.
const BASE_JUMP_VELOCITY := 6.0 # scripts/player.gd step_motion take-off
const JUMP_VELOCITY := 6.25
const NAME := "JumpTuning"
var player: CharacterBody3D
var boosted := 0
var jump_velocity := JUMP_VELOCITY

static func attach(p: Node) -> Node:
	if not is_instance_valid(p) or not p is CharacterBody3D: return null
	var existing = p.get_node_or_null(NAME)
	if existing != null: return existing
	var n = load("res://raid/scripts/jump_tuning.gd").new()
	n.name = NAME
	n.player = p
	n.process_physics_priority = p.process_physics_priority
	p.add_child(n)
	return n

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or player.get("seated") == true: return
	# Only the take-off frame carries exactly the base velocity: every airborne frame has had
	# gravity applied, and a ceiling hit on take-off changes it, so neither is boosted.
	if absf(player.velocity.y - BASE_JUMP_VELOCITY) < 0.0001 and not player.is_on_floor():
		player.velocity.y = jump_velocity
		boosted += 1
