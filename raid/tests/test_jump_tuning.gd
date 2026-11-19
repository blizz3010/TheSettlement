extends SceneTree
## Queue item 2a: raised jump via raid/scripts/jump_tuning.gd on the production player.gd.
## Headless fixture: flat ground and single obstacles; the real step_motion is driven at 60 Hz.
## A running jump must clear low railings, ledges and curbs up to the 1.1 m ship ramp railing and
## must NOT get over or onto 1.15 m rails or planting beds (fix/ship-boarding), the 1.28 m pad
## retaining wall, a 1.6 m fence or a 2.4 m wall.
## Also records the base (player.gd only) numbers for the before/after report.
const Player = preload("res://scripts/player.gd")
const JumpTuning = preload("res://raid/scripts/jump_tuning.gd")
const STEP := 1.0 / 60.0
const MARKER := "JUMP_TUNING_TESTS "
var checks := 0
var failures: Array = []
var report := {}
var root3d: Node3D
var obstacle: StaticBody3D

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize(): call_deferred("run")

func body(n: String, center: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new(); b.name = n
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = size
	cs.shape = bs; b.add_child(cs); b.position = center
	root3d.add_child(b)
	return b

func new_player(tuned: bool, velocity := -1.0) -> CharacterBody3D:
	var p = Player.new()
	root3d.add_child(p)
	p.set_physics_process(false)
	p.set_process_unhandled_input(false)
	if tuned:
		var t = JumpTuning.attach(p)
		if velocity > 0.0: t.jump_velocity = velocity
	return p

func settle(p, at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.rotation = Vector3.ZERO
	for i in 30:
		await physics_frame
		p.step_motion(Vector3.ZERO, 4.2, false, STEP)

func apex(tuned: bool) -> float:
	var p := new_player(tuned)
	await settle(p, Vector3(0, 0.05, 20))
	var y0: float = p.global_position.y
	var top := y0
	for f in 120:
		await physics_frame
		p.step_motion(Vector3.ZERO, 4.2, f == 0, STEP)
		top = maxf(top, p.global_position.y)
	p.queue_free()
	await physics_frame
	return top - y0

## Run at `speed` toward +x, jump `takeoff` metres before the obstacle's near face (x = 0).
## Returns "over" (landed past it), "on" (standing on top) or "blocked".
func attempt(tuned: bool, height: float, depth: float, speed: float, takeoff: float) -> String:
	var p := new_player(tuned)
	await settle(p, Vector3(-takeoff - 2.5, 0.05, 0))
	var dir := Vector3(1, 0, 0)
	var jumped := false
	for f in 240:
		await physics_frame
		var jump_now: bool = not jumped and p.global_position.x >= -takeoff - 0.32
		if jump_now: jumped = true
		p.step_motion(dir, speed, jump_now, STEP)
	var x: float = p.global_position.x
	var y: float = p.global_position.y
	p.queue_free()
	await physics_frame
	if x > depth + 0.33 and y < 0.3: return "over"
	if y > height - 0.2 and x > 0.0: return "on"
	return "blocked"

func sweep(tuned: bool, height: float, depth: float) -> Dictionary:
	if is_instance_valid(obstacle): obstacle.queue_free()
	await physics_frame
	obstacle = body("Obstacle", Vector3(depth * 0.5, height * 0.5, 0), Vector3(depth, height, 8))
	for i in 3: await physics_frame
	var result := {"over": 0, "on": 0, "blocked": 0, "tries": 0}
	for speed in [4.2, 7.0]:
		var d := 0.2
		while d <= 2.21:
			var r := await attempt(tuned, height, depth, speed, d)
			result[r] += 1
			result.tries += 1
			d += 0.15
	return result

func run() -> void:
	root3d = Node3D.new(); root3d.name = "JumpFixture"; root.add_child(root3d)
	body("Ground", Vector3(0, -0.1, 0), Vector3(200, 0.2, 200))
	for i in 3: await physics_frame
	var base_apex := await apex(false)
	var tuned_apex := await apex(true)
	report["base_jump_velocity"] = JumpTuning.BASE_JUMP_VELOCITY
	report["tuned_jump_velocity"] = JumpTuning.JUMP_VELOCITY
	report["base_peak_m"] = snappedf(base_apex, 0.001)
	report["tuned_peak_m"] = snappedf(tuned_apex, 0.001)
	print("JUMP_PEAKS base=%.3f tuned=%.3f" % [base_apex, tuned_apex])
	check(base_apex > 0.85 and base_apex < 1.0, "Base player.gd jump peak is about 0.9-1.0 m (pinned v=6, g=20)")
	check(tuned_apex > base_apex + 0.05, "Tuned jump is higher than the base jump")
	check(tuned_apex < 1.06, "Tuned jump peak stays well below 1.15 m obstacles (capsule edge ride-over starts ~1.09 m)")
	# name, height, depth, must clear (true) or must not get over/onto (false)
	var cases := [
		["curb", 0.30, 0.25, true],
		["ledge", 0.60, 0.6, true],
		["low_railing", 0.90, 0.10, true],
		["railing_1m", 1.00, 0.10, true],
		["ramp_railing_1_1m", 1.10, 0.10, true],
		["rail_1_15m", 1.15, 0.10, false],
		["planting_bed_1_15m", 1.15, 1.48, false],
		["pad_retaining_wall_1_28m", 1.28, 3.0, false],
		["fence_1_6m", 1.60, 0.12, false],
		["wall_2_4m", 2.40, 0.2, false],
	]
	var table := {}
	for c in cases:
		var before := await sweep(false, c[1], c[2])
		var after := await sweep(true, c[1], c[2])
		table[c[0]] = {"height": c[1], "base": before, "tuned": after}
		print("JUMP_CASE %s h=%.2f base=%s tuned=%s" % [c[0], c[1], before, after])
		if c[0] == "ramp_railing_1_1m":
			check(before.over == 0, "Base player.gd jump cannot clear the 1.1 m ramp railing (the playtest complaint)")
		if c[3] == true:
			check(after.over > 0, "Running jump clears %s (%.2f m)" % [c[0], c[1]])
		elif c[3] == false:
			check(after.over == 0 and after.on == 0, "Running jump does not get over or onto %s (%.2f m)" % [c[0], c[1]])
	report["cases"] = table
	report["checks"] = checks
	report["failures"] = failures
	print(MARKER, JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
