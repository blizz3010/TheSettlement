extends SceneTree
## Bounded procedural regression matrix, pinned to Godot 4.6.3.
## Run headless with --fixed-fps 60 and isolated disposable XDG directories.
## Optional user arguments: --matrix-index=N (one case), --contracts-only.
## This is physics/generation coverage, not rendered or native-input acceptance.
const Config = preload("res://raid/scripts/relay_config.gd")
const Generator = preload("res://raid/scripts/relay_generator.gd")
const KINDS = ["tree", "grass", "shrub", "rock"]
const WALK_SPEED = 4.2
const STEP = 1.0 / 60.0
const CASES = [
	{"name": "zero_noise_empty", "seed": 0, "amplitude": 0.0, "density": [0.0, 0.0, 0.0, 0.0], "expected_ready": true},
	{"name": "alternate_one", "seed": 1, "amplitude": 5.0, "density": [0.66, 0.68, 0.20, 0.17], "expected_ready": true},
	{"name": "adjacent_seed", "seed": 241108, "amplitude": 5.0, "density": [0.66, 0.68, 0.20, 0.17], "expected_ready": true},
	{"name": "maximum_seed", "seed": 2147483647, "amplitude": 5.0, "density": [0.66, 0.68, 0.20, 0.17], "expected_ready": true},
	{"name": "maximum_amplitude_dense", "seed": 7, "amplitude": 12.0, "density": [1.0, 1.0, 1.0, 1.0], "expected_ready": false},
	{"name": "maximum_amplitude_sparse", "seed": 42, "amplitude": 12.0, "density": [0.15, 0.10, 0.05, 0.05], "expected_ready": false},
]
var checks = 0
var failures: Array = []
var results: Array = []
var scene

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize():
	call_deferred("run")

func settings_for(item: Dictionary) -> Resource:
	var settings = Config.new()
	settings.map_seed = item.seed
	settings.terrain_amplitude = item.amplitude
	for index in KINDS.size():
		settings.set(KINDS[index] + "_density", item.density[index])
	return settings

func point_json(point: Vector2) -> Array:
	return [point.x, point.y]

func generator_checks(item: Dictionary, settings: Resource) -> Dictionary:
	var prefix = item.name + ": "
	var generator = Generator.new(settings)
	var repeat = Generator.new(settings_for(item))
	check(settings.valid(), prefix + "allowed settings accepted")
	var counts: Dictionary = {}
	for kind in KINDS:
		var placements = generator.placements(kind)
		counts[kind] = placements.size()
		check(placements == repeat.placements(kind), prefix + kind + " deterministic transforms")
		var legal = true
		for placement in placements:
			var point = Vector2(placement.position.x, placement.position.z)
			var margin = 2.0 if kind == "tree" else 0.8 if kind == "rock" else 0.0
			legal = legal and not generator.reserved(point, margin)
			legal = legal and generator.slope_at(point) <= 0.48
			legal = legal and is_equal_approx(placement.position.y, generator.height_at(point))
			legal = legal and is_finite(placement.yaw) and placement.scale >= 0.8 and placement.scale <= 1.25
		check(legal, prefix + kind + " placements respect exclusions, slopes, ground and bounds")
		var changed = settings_for(item)
		changed.set(kind + "_density", 0.0)
		var changed_generator = Generator.new(changed)
		check(changed_generator.placements(kind).is_empty(), prefix + "zero " + kind + " density removes layer")
		# Only this layer's density changes; every other layer must retain exact transforms.
		for other_kind in KINDS:
			if other_kind != kind:
				check(changed_generator.placements(other_kind) == generator.placements(other_kind), prefix + kind + " density leaves " + other_kind + " unchanged")
	var deterministic_heights = true
	var terrain_samples = 0
	for x in range(-192, 193, 16):
		for z in range(-192, 193, 16):
			var point = Vector2(x, z)
			var height = generator.height_at(point)
			deterministic_heights = deterministic_heights and is_finite(height) and height == repeat.height_at(point)
			terrain_samples += 1
	check(deterministic_heights, prefix + "finite deterministic terrain on 625-point grid")
	check(generator.pois == Config.new().pois() and generator.routes == Config.new().routes(), prefix + "fixed POIs and trails independent of seed/density")
	var flat_pads = true
	for pad in generator.pads:
		for offset in [Vector2.ZERO, Vector2(4, 4), Vector2(-4, -4)]:
			flat_pads = flat_pads and is_equal_approx(generator.height_at(pad.at + offset), generator.height_at(pad.at))
	check(flat_pads, prefix + "POI, spawn and extraction pad cores stay flat")
	var max_grade = 0.0
	var grade_samples = 0
	var steepest_segment: Dictionary = {}
	var routes_avoid_footprints = true
	for route_index in generator.routes.size():
		var route: Array = generator.routes[route_index]
		for segment_index in range(route.size() - 1):
			var start: Vector2 = route[segment_index]
			var end: Vector2 = route[segment_index + 1]
			for step in range(ceili(start.distance_to(end))):
				var point = start.move_toward(end, step)
				var next = start.move_toward(end, step + 1)
				var grade = absf(generator.height_at(next) - generator.height_at(point)) / maxf(point.distance_to(next), 0.001)
				if grade > max_grade:
					max_grade = grade
					steepest_segment = {"route": route_index, "segment": segment_index, "at": point_json(point), "grade": grade}
				grade_samples += 1
				for poi in generator.pois:
					if absf(point.x - poi.at.x) < 7.0 and absf(point.y - poi.at.y) < 6.0:
						routes_avoid_footprints = false
	check((max_grade < 0.7) == item.expected_ready, prefix + "one-metre trail grades match known safe/unsafe fixture")
	check(routes_avoid_footprints, prefix + "all trails avoid solid building footprints")
	var travel_layout = generator.validate_travel_layout()
	check(travel_layout == repeat.validate_travel_layout(), prefix + "triangle-grade preflight deterministic")
	check(travel_layout.ok == item.expected_ready, prefix + "triangle-grade preflight accepts safe and refuses known unsafe layout")
	check(travel_layout.samples > 10000 and travel_layout.grade_limit == 0.7, prefix + "preflight retains corridor sampling and grade threshold")
	var output = item.duplicate(true)
	output.merge({"counts": counts, "terrain_samples": terrain_samples, "grade_samples": grade_samples, "max_route_grade": max_grade, "steepest_segment": steepest_segment, "travel_layout": travel_layout})
	return output

func collision_checks(item: Dictionary, output: Dictionary):
	var space = scene.get_world_3d().direct_space_state
	var max_error = 0.0
	var samples = 0
	var unsupported: Array = []
	var blocked: Array = []
	# Centre and both sides of a 1.2 m walking corridor, sampled each metre.
	for route in scene.generator.routes:
		for index in range(route.size() - 1):
			var start: Vector2 = route[index]
			var end: Vector2 = route[index + 1]
			var direction = (end - start).normalized()
			var lateral = Vector2(-direction.y, direction.x)
			for step in range(ceili(start.distance_to(end)) + 1):
				for offset in [-0.6, 0.0, 0.6]:
					var point = start.move_toward(end, step) + lateral * offset
					var height = scene.generator.height_at(point)
					var ray = PhysicsRayQueryParameters3D.create(Vector3(point.x, height + 1.0, point.y), Vector3(point.x, height - 1.0, point.y))
					ray.exclude = [scene.player.get_rid()]
					var hit = space.intersect_ray(ray)
					samples += 1
					if hit.is_empty():
						unsupported.append(point_json(point))
						continue
					max_error = maxf(max_error, absf(hit.position.y - height))
					var probe = PhysicsShapeQueryParameters3D.new()
					probe.shape = scene.player.standing_shape
					probe.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, hit.position.y + 1.0, point.y))
					probe.exclude = [scene.player.get_rid()]
					var intersections = space.intersect_shape(probe, 1)
					if not intersections.is_empty():
						blocked.append({"at": point_json(point), "body": str(intersections[0].collider.get_path())})
	check(unsupported.is_empty(), item.name + ": all three-column trail samples have ground collision")
	check(max_error < 0.15, item.name + ": trail mesh/sampler discrepancy below 15 cm")
	check(blocked.is_empty(), item.name + ": standing capsule clear across 1.2 m trail corridor")
	output.merge({"collision_samples": samples, "max_mesh_sampler_error": max_error, "unsupported": unsupported, "blocked": blocked})

func walk_segment(start: Vector2, end: Vector2) -> Dictionary:
	scene.player.position = Vector3(start.x, scene.generator.height_at(start) + 0.08, start.y)
	scene.player.velocity = Vector3.ZERO
	for frame in 30:
		scene.player.step_motion(Vector3.ZERO, WALK_SPEED, false, STEP)
		await physics_frame
	var distance = 0.0
	var max_error = 0.0
	var anomalous = false
	var reached = false
	var used_frames = 0
	var budget = ceili((start.distance_to(end) / WALK_SPEED + 3.0) * 120.0)
	for frame in budget:
		var at = Vector2(scene.player.position.x, scene.player.position.z)
		if at.distance_to(end) < 0.15:
			reached = true
			break
		var direction = (end - at).normalized()
		scene.player.step_motion(Vector3(direction.x, 0, direction.y), WALK_SPEED, false, STEP)
		await physics_frame
		used_frames += 1
		var now = Vector2(scene.player.position.x, scene.player.position.z)
		var moved = now.distance_to(at)
		distance += moved
		max_error = maxf(max_error, absf(scene.player.position.y - scene.generator.height_at(now)))
		if not scene.player.position.is_finite() or scene.player.position.y < scene.generator.height_at(now) - 1.0 or moved > 0.5:
			anomalous = true
			break
	return {"start": point_json(start), "goal": point_json(end), "final": [scene.player.position.x, scene.player.position.y, scene.player.position.z], "reached": reached, "walked_metres": distance, "max_ground_error": max_error, "anomalous": anomalous, "frames": used_frames}

func scene_checks(item: Dictionary, settings: Resource, output: Dictionary):
	scene = load("res://raid/relay_ridge.tscn").instantiate()
	scene.settings = settings
	root.add_child(scene)
	var deadline = Time.get_ticks_msec() + 60000
	while not scene.is_raid_ready() and scene.get_raid_failure().is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not item.expected_ready:
		check(not scene.is_raid_ready() and not scene.build_result.get("ready", true), item.name + ": unsafe scene refuses readiness")
		check(not scene.get_raid_failure().is_empty() and scene.get_raid_failure() == scene.build_result.get("failure", ""), item.name + ": unsafe scene exposes explicit failure reason")
		check(scene.get_raid_failure().contains("too steep"), item.name + ": refusal identifies terrain grade")
		check(not is_instance_valid(scene.player) and not scene.has_node("SeededTerrain"), item.name + ": refusal precedes terrain and player construction")
		check(scene.build_result.get("travel_layout", {}) == output.travel_layout, item.name + ": actual scene uses the tested preflight result")
		var return_button: Button = null
		for button in scene.find_children("*", "Button", true, false):
			if button.text == "Return / Exit preview":
				return_button = button
		check(return_button != null and return_button.is_visible_in_tree(), item.name + ": refusal offers visible return button")
		var return_events = {"count": 0}
		scene.return_requested.connect(func(): return_events.count += 1)
		if return_button != null:
			return_button.pressed.emit()
			return_button.pressed.emit()
		check(return_events.count == 1, item.name + ": refusal return works and repeated click emits once")
		output.merge({"ready": false, "refused": not scene.get_raid_failure().is_empty(), "failure_reason": scene.get_raid_failure(), "failure_return_events": return_events.count})
		scene.free()
		await process_frame
		return
	check(scene.is_raid_ready(), item.name + ": actual generated scene reaches spawn readiness")
	if not scene.is_raid_ready():
		output["ready"] = false
		scene.free()
		await process_frame
		return
	# Exercise the unchanged production motion explicitly at 60 Hz. Disable world
	# processing so a safety teleport cannot conceal a terrain/traversal failure.
	scene.set_process(false)
	scene.player.enabled = false
	scene.player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	check(scene.build_result.terrain.chunks == 144 and scene.build_result.terrain.triangles == 73728, item.name + ": bounded terrain mesh")
	var counts_match = true
	for kind in KINDS:
		counts_match = counts_match and scene.build_result.foliage[kind] == output.counts[kind]
	check(counts_match, item.name + ": scene foliage matches deterministic generation")
	collision_checks(item, output)
	# Spawn approach, both entrances to each extraction, plus the steepest segment.
	var selected: Array = [[0, 0], [0, 9], [1, 6], [5, 3], [6, 0]]
	var steepest = [output.steepest_segment.route, output.steepest_segment.segment]
	if not selected.has(steepest):
		selected.append(steepest)
	var walks: Array = []
	for segment in selected:
		var route: Array = scene.generator.routes[segment[0]]
		var endpoints = [route[segment[1]], route[segment[1] + 1]]
		for reverse in [false, true]:
			var result = await walk_segment(endpoints[1] if reverse else endpoints[0], endpoints[0] if reverse else endpoints[1])
			result.merge({"route": segment[0], "segment": segment[1], "reverse": reverse})
			var label = "%s: route %d segment %d reverse=%s" % [item.name, segment[0], segment[1], reverse]
			check(result.reached and not result.anomalous, label + " production capsule reaches endpoint without jumping or teleport")
			check(result.max_ground_error < 0.2, label + " stays within 20 cm of sampled terrain")
			walks.append(result)
	output.merge({"ready": true, "walks": walks})
	scene.free()
	await process_frame

func run():
	var start = Time.get_ticks_msec()
	var case_index = -1
	var contracts_only = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--matrix-index="):
			case_index = int(argument.get_slice("=", 1))
		elif argument == "--contracts-only":
			contracts_only = true
	if case_index < -1 or case_index >= CASES.size():
		push_error("Matrix index out of range")
		quit(2)
		return
	for index in CASES.size():
		if case_index >= 0 and index != case_index:
			continue
		var checks_before = checks
		var failures_before = failures.size()
		var item: Dictionary = CASES[index]
		var settings = settings_for(item)
		var output = generator_checks(item, settings)
		print("RELAY_MATRIX_GENERATION ", JSON.stringify(output))
		if not contracts_only:
			await scene_checks(item, settings, output)
		output["checks"] = checks - checks_before
		output["failures"] = failures.slice(failures_before)
		results.append(output)
		print("RELAY_MATRIX_CASE ", JSON.stringify(output))
	print("RELAY_SEED_MATRIX_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "cases": results, "contracts_only": contracts_only, "wall_time_ms": Time.get_ticks_msec() - start, "rendered": false, "native_input_tested": false, "settlement_travel_tested": false}))
	quit(0 if failures.is_empty() else 1)
