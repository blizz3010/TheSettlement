extends SceneTree
## Focused headless physics/interaction acceptance, not rendered or Windows proof.
## Run with --fixed-fps 60 and a disposable XDG profile.
const WALK_SPEED := 4.2
const STEP := 1.0 / 60.0
var checks := 0
var failures: Array = []
var route_results: Array = []
var poi_results: Array = []
var scene
var walked_metres := 0.0
var max_ground_error := 0.0
var returns := 0

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize():
	call_deferred("run")

func place(p: Vector2):
	scene.player.position = Vector3(p.x, scene.generator.height_at(p) + 0.08, p.y)
	scene.player.velocity = Vector3.ZERO
	for frame in 30:
		scene.player.step_motion(Vector3.ZERO, WALK_SPEED, false, STEP)
		await physics_frame

func walk_to(goal: Vector2, label: String, limit_frames: int = -1) -> bool:
	var start := Vector2(scene.player.position.x, scene.player.position.z)
	var budget := ceili((start.distance_to(goal) / WALK_SPEED + 3.0) * 120.0) if limit_frames < 0 else limit_frames
	for frame in budget:
		var at := Vector2(scene.player.position.x, scene.player.position.z)
		if at.distance_to(goal) < 0.15:
			scene.player.velocity = Vector3.ZERO
			return true
		var toward := (goal - at).normalized()
		var before: Vector3 = scene.player.position
		scene.player.step_motion(Vector3(toward.x, 0, toward.y), WALK_SPEED, false, STEP)
		await physics_frame
		var moved := Vector2(scene.player.position.x, scene.player.position.z)
		walked_metres += Vector2(before.x, before.z).distance_to(moved)
		max_ground_error = maxf(max_ground_error, absf(scene.player.position.y - scene.generator.height_at(moved)))
		if scene.player.position.y < -2.0 or moved.distance_to(at) > 0.5:
			check(false, label + ": fall or unexpected relocation")
			return false
	print("WALK_BLOCKED ", label, " at ", scene.player.position, " goal ", goal)
	return false

func target(kind: String, id: String) -> Dictionary:
	for item in scene.targets:
		if item.kind == kind and item.poi.id == id:
			return item
	return {}

func aim_and_use(item: Dictionary, label: String) -> bool:
	scene.player.camera.look_at(item.node.global_position)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var selected: Dictionary = scene._nearest_target()
	var matched: bool = not selected.is_empty() and selected.node == item.node
	check(matched, label + ": unobstructed camera target")
	if not matched:
		return false
	# The headless display does not implement mouse capture. Exercise the unchanged
	# handler after real camera/raycast selection, not the native keyboard gate.
	scene._interact(selected)
	return true

func click_button(text: String):
	for button in scene.modal.find_children("*", "Button", true, false):
		if button.text == text:
			button.pressed.emit()
			return
	check(false, "Button exists: " + text)

func visit_poi(poi: Dictionary):
	var origin: Vector2 = poi.at
	# Each visit starts at its existing trail forecourt. No repositioning within a visit.
	var forecourt := origin + Vector2(0, 18 if poi.id in ["camp", "substation"] else 24)
	await place(forecourt)
	var reached := true
	if poi.lock != "":
		reached = await walk_to(origin + Vector2(-9, 9), poi.id + " field supplies") and reached
		check(reached, poi.id + ": walk from trail to field supplies")
		if not reached:
			return
		aim_and_use(target("clue", poi.id), poi.id + " supplies")
		if poi.lock == "key": check(scene.raid_state.held.has(poi.id + "_key"), "Physical key collected")
		elif poi.lock == "keycard": check(scene.raid_state.held.has(poi.id + "_card"), "Physical keycard collected")
		elif poi.lock == "code": check(scene.raid_state.notes.get(poi.id, "") == scene.raid_state.code_for(poi.id), "Code note retained")
		else: check(scene.raid_state.clues.has(poi.id), "Puzzle clue retained")
	if poi.lock == "puzzle":
		# Keep clear of the three solid switch posts while walking between them.
		for number in [2, 1, 3]:
			var switch_item: Dictionary = {}
			for item in scene.targets:
				if item.kind == "switch" and item.number == number:
					switch_item = item
			var goal := origin + Vector2(-4 + (number - 1) * 4, 11)
			reached = await walk_to(goal, "weather switch %d" % number) and reached
			aim_and_use(switch_item, "weather switch %d" % number)
		check(scene.raid_state.switch_step == 3, "Physical switches solve sequence")
		reached = await walk_to(origin + Vector2(2, 7), "weather doorway approach") and reached
		reached = await walk_to(origin + Vector2(0, 1.4), "weather archive approach") and reached
	else:
		reached = await walk_to(origin + Vector2(0, 7.4), poi.id + " doorway approach") and reached
	check(reached, poi.id + ": walk to doorway")
	if not reached:
		return
	if poi.lock != "":
		aim_and_use(target("door", poi.id), poi.id + " door")
		if poi.lock == "code":
			var entries = scene.modal.find_children("*", "LineEdit", true, false)
			check(entries.size() == 1, "Code entry panel exists")
			if entries.size() != 1:
				return
			var entry = entries[0]
			entry.text = "%04d" % ((int(scene.raid_state.code_for(poi.id)) + 1) % 10000)
			click_button("Unlock")
			check(scene.modal.visible and not scene.raid_state.unlocked.get(poi.id, false), "Wrong code leaves actual door locked")
			entry.text = scene.raid_state.notes[poi.id]
			click_button("Unlock")
		check(scene.raid_state.unlocked.get(poi.id, false) and not scene.door_nodes[poi.id].visible, poi.id + ": credential opens physical door")
		await physics_frame
		await physics_frame
	var cache = target("cache", poi.id)
	var cache_goal := Vector2(cache.node.global_position.x, cache.node.global_position.z + 2.0)
	reached = await walk_to(cache_goal, poi.id + " interior cache")
	check(reached, poi.id + ": walk through doorway to cache")
	if reached:
		aim_and_use(cache, poi.id + " loot cache")
		check(scene.raid_state.searched.has(poi.id), poi.id + ": cache searched through interaction handler")
		var first_roll: int = scene.raid_state.searched.get(poi.id, -1)
		aim_and_use(cache, poi.id + " repeat cache")
		check(scene.raid_state.searched.get(poi.id, -1) == first_roll and scene.toast.text == "Already searched this raid.", poi.id + ": repeat cache cannot reroll")
	# Leave by the same doorway, avoiding the centre switch on the weather forecourt.
	# Cross the centre of the 2.6 m entrance before turning around outside props.
	reached = await walk_to(origin + Vector2(0, 7), poi.id + " return outside") and reached
	check(reached, poi.id + ": leave room without jumping")
	poi_results.append({"id": poi.id, "traversed": reached})

func run():
	var start_ms := Time.get_ticks_msec()
	scene = load("res://raid/relay_ridge.tscn").instantiate()
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 60000
	while not scene.is_raid_ready() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(scene.is_raid_ready(), "Actual scene reaches generation/spawn readiness")
	if not scene.is_raid_ready():
		scene.free()
		quit(1)
		return
	scene.player.set_physics_process(false)
	# Calls unchanged production movement once per 60 Hz physics step.
	# --fixed-fps affects wall time, not simulation step or movement speed.
	for index in scene.generator.routes.size():
		for reverse in [false, true]:
			var route: Array = scene.generator.routes[index].duplicate()
			if reverse:
				route.reverse()
			await place(route[0])
			var reached := true
			for point in route.slice(1):
				if not await walk_to(point, "trail %d reverse=%s" % [index, reverse]):
					reached = false
					break
			check(reached, "Entire trail %d traversable reverse=%s without jumping" % [index, reverse])
			route_results.append({"route": index, "reverse": reverse, "reached": reached})
			print("TRAIL_COMPLETE ", index, " reverse=", reverse, " reached=", reached)
	for poi in scene.generator.pois:
		await visit_poi(poi)
		print("POI_COMPLETE ", poi.id)
	# Both extraction posts can be targeted from their route endpoints.
	for index in scene.Config.EXTRACTS.size():
		await place(scene.Config.EXTRACTS[index])
		aim_and_use(target("extract", "extract%d" % index), "extraction %d" % index)
		check(scene.modal.visible, "Extraction confirmation opens %d" % index)
		click_button("Keep exploring")
		check(not scene.modal.visible and scene.player.enabled, "Extraction cancellation restores controls %d" % index)
	scene.return_requested.connect(func(): returns += 1)
	scene._exit_panel("Leave preview?")
	click_button("Return to settlement")
	check(returns == 1 and not scene.ready_for_play and not scene.player.enabled, "Return emits once and disables raid controls")
	print("RELAY_WALKTHROUGH_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "route_runs": route_results, "pois": poi_results, "walked_metres": walked_metres, "max_ground_error": max_ground_error, "wall_time_ms": Time.get_ticks_msec() - start_ms, "rendered": false, "native_input_tested": false, "interaction_mode": "real_raycast_and_handler", "settlement_travel_tested": false}))
	scene.free()
	await preload("res://raid/tests/audio_shutdown.gd").drain(self)
	quit(0 if failures.is_empty() else 1)
