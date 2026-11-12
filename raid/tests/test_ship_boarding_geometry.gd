extends SceneTree
## Real ship assembly/collision and production player motion, in a small fixture.
## Does not launch the full settlement, save, or certify native input/rendering.
const Ship = preload("res://scripts/launchpad_ship.gd")
const Player = preload("res://scripts/player.gd")
const STEP := 1.0 / 60.0
var checks := 0
var failures: Array = []
var routes: Array = []
var world
var ship: Node3D

class GeometryWorld:
	extends "res://raid/scripts/ship_settlement_preview.gd"
	func _ready(): pass
	func _process(_delta): pass

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize(): call_deferred("run")

func place(local: Vector3):
	world.player.global_position = ship.to_global(local)
	world.player.velocity = Vector3.ZERO
	for frame in 30:
		world.player.step_motion(Vector3.ZERO, 4.2, false, STEP)
		await physics_frame

func walk_to(local: Vector2, speed: float) -> bool:
	var goal: Vector2 = local + Vector2(ship.global_position.x, ship.global_position.z)
	var start := Vector2(world.player.position.x, world.player.position.z)
	var budget := ceili((start.distance_to(goal) / speed + 4.0) * 120)
	for frame in budget:
		var at := Vector2(world.player.position.x, world.player.position.z)
		if at.distance_to(goal) < 0.12:
			for settle in 8:
				world.player.step_motion(Vector3.ZERO, speed, false, STEP)
				await physics_frame
			return true
		var direction := (goal - at).normalized()
		var before: Vector3 = world.player.position
		world.player.step_motion(Vector3(direction.x, 0, direction.y), speed, false, STEP)
		await physics_frame
		if world.player.position.y < -0.1 or before.distance_to(world.player.position) > 0.5:
			return false
	return false

func run():
	world = GeometryWorld.new()
	root.add_child(world)
	# A flat settlement ground fixture, not a replacement ship ramp or pad.
	Ship.box(world, "FixtureGround", Vector3(22, -0.1, -4), Vector3(40, 0.2, 50), "stone")
	ship = Ship.add_to(world)
	world.player = Player.new()
	world.add_child(world.player)
	world.player.set_physics_process(false)
	check(ship.get_node_or_null("Collision/PadDeck") is StaticBody3D, "Actual pad deck collider exists")
	check(ship.get_meta("ship_construction_v096", {}).get("ok", false), "Original ship construction checks pass")
	for speed in [2.4, 4.2, 7.0]:
		for x in [-0.7, 0.0, 0.7]:
			await place(Vector3(x, 0.08, 18))
			check(world.player.is_on_floor(), "Approach starts grounded at %s / %s" % [speed, x])
			check(not world.ship_has_boarding_support(), "Southern approach is not a boarding point")
			var reached: bool = await walk_to(Vector2(x, 4.8), speed)
			check(reached, "Walk intact ramp to deck at %s / %s" % [speed, x])
			check(world.player.is_on_floor(), "Deck arrival is grounded")
			check(absf(ship.to_local(world.player.global_position).y - 1.28) < 0.03, "Feet supported on actual pad height")
			check(world.ship_has_boarding_support(), "Production physical boarding predicate accepts arrival")
			var returned: bool = await walk_to(Vector2(x, 18), speed)
			check(returned and world.player.position.y < 0.08, "Walk back down intact ramp")
			check(not world.ship_has_boarding_support(), "Leaving deck removes boarding eligibility")
			routes.append({"speed": speed, "lane": x, "arrival": reached, "return": returned})
	await place(Vector3(0, 1.36, 4.8))
	check(world.ship_has_boarding_support(), "Center accepts before temporary obstruction")
	var obstruction = Ship.box(world, "TestSightBlocker", ship.to_global(Vector3(0, 2.3, 4.55)), Vector3(1.2, 1.3, 0.15), "metal")
	# Sight ray endpoint is z=4.8. Move the player south, within the zone, so the
	# fixture blocker lies between the player and that point without intersecting.
	await place(Vector3(0, 1.36, 5.7))
	obstruction.position = ship.to_global(Vector3(0, 2.3, 5.1))
	await physics_frame
	check(not world.ship_has_boarding_support(), "Solid sight obstruction rejects physical boarding")
	obstruction.free()
	await physics_frame
	check(world.ship_has_boarding_support(), "Removing obstruction restores physical boarding")
	world.player.position = ship.to_global(Vector3(0, 0, 4.8))
	check(not world.ship_has_boarding_support(), "Below-pad position rejects boarding")
	world.player.position = ship.to_global(Vector3(0, 1.28, 0))
	check(not world.ship_has_boarding_support(), "Hull center rejects boarding")
	world.player.position = ship.to_global(Vector3(0, 1.28, 10))
	check(not world.ship_has_boarding_support(), "Ramp outside deck zone rejects boarding")
	world.free()
	print("SHIP_BOARDING_GEOMETRY_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "routes": routes, "scope": "Real ship collision, production player, and production physical predicate; isolated ground fixture, no full title/startup, mouse input, saves, or rendered/Windows acceptance"}))
	quit(0 if failures.is_empty() else 1)
