extends SceneTree
## Headless contract for the in-engine takeoff cutscene and raid handoff.
const Catalog = preload("res://raid/scripts/raid_catalog.gd")
const Cutscene = preload("res://raid/scripts/ship_takeoff_cutscene.gd")
const Host = preload("res://raid/scripts/ship_transition.gd")
var checks := 0
var failures: Array = []

class FakePlayer:
	extends CharacterBody3D
	var enabled := true

class HudHost:
	extends Node3D
	var hud_root: Control

class TestSettlement:
	extends "res://raid/scripts/ship_settlement_preview.gd"
	var allowed := true
	var save_ok := true
	var saves := 0
	var departures := 0
	var last_departed_raid := ""
	func _ready():
		player = FakePlayer.new()
		add_child(player)
		world_initialized = true
		world_activated = true
		character_slot_bound = true
		_character_slot = "slot_1"
		_character_appearance = {"name": "Takeoff test"}
		var ship = Node3D.new()
		ship.name = "LaunchpadShip"
		add_child(ship)
	func _process(_delta): pass
	func modal_open(_a:bool=true,_b:bool=true,_c:bool=true) -> bool:
		return is_instance_valid(ship_selection)
	func ship_can_embark() -> bool:
		return allowed and not ship_contract.busy and not is_instance_valid(ship_selection) and world_initialized and world_activated and character_slot_bound and player.enabled
	func save_game(_show_notice := true) -> bool:
		saves += 1
		return save_ok
	func message(_text): pass
	func _depart_ship_preview():
		departures += 1
		last_departed_raid = ship_selected_raid_id

class FakeRaid:
	extends Node
	signal return_requested
	func is_raid_ready(): return true
	func get_raid_failure() -> String: return ""

class TestHost:
	extends "res://raid/scripts/ship_transition.gd"
	var opened := 0
	func _create_raid() -> Node:
		return FakeRaid.new()
	func open_raid():
		opened += 1
		super.open_raid()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func key(code: Key) -> InputEventKey:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event

func click() -> InputEventMouseButton:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(80, 80)
	return event

func wait_until(fn: Callable, frames: int) -> bool:
	for _i in frames:
		if fn.call():
			return true
		await process_frame
	return fn.call()

func _initialize():
	call_deferred("run")

func run():
	check(Cutscene.DURATION >= 6.0 and Cutscene.DURATION <= 10.0, "Takeoff duration is 6–10 seconds")
	check(ResourceLoader.exists("res://raid/audio/ship_takeoff_rumble.wav") or FileAccess.file_exists("res://raid/audio/ship_takeoff_rumble.wav"), "Dedicated takeoff rumble exists")
	check(Catalog.contains("relay_ridge") and Catalog.contains("cinder_basin"), "Both raid destinations remain allowlisted")

	# Direct fixture: full play, then skip variants and handoff for both raid ids.
	for raid_id in ["relay_ridge", "cinder_basin"]:
		var world = Node3D.new()
		world.name = "Fixture"
		root.add_child(world)
		var ship = Node3D.new()
		ship.name = "LaunchpadShip"
		world.add_child(ship)
		var cutscene = Cutscene.new()
		cutscene.name = "ShipTakeoffCutscene"
		cutscene.raid_id = raid_id
		var result := {"id": "", "skipped": true, "count": 0}
		cutscene.finished.connect(func(id: String, skipped: bool):
			result.id = id
			result.skipped = skipped
			result.count += 1
		)
		world.add_child(cutscene)
		cutscene.begin(world)
		await process_frame
		check(cutscene.playing and cutscene.camera != null and cutscene.camera.current, raid_id + ": cutscene plays with a live camera")
		check(is_instance_valid(cutscene.audio) and cutscene.audio.stream != null, raid_id + ": rumble stream is attached")
		check(cutscene.thrust.size() == 2 and is_instance_valid(cutscene.dust) and is_instance_valid(cutscene.shimmer), raid_id + ": thrusters, pad dust and heat shimmer exist")
		# Play almost a second, then skip — proves play, skip, and handoff without a 16s wait per map.
		for _i in 40:
			await process_frame
		check(cutscene.playing and cutscene.elapsed >= 0.4 and not cutscene.skipped, raid_id + ": cutscene still playing before skip")
		var skip_event: InputEvent = key(KEY_ESCAPE) if raid_id == "relay_ridge" else key(KEY_SPACE)
		cutscene._unhandled_input(skip_event)
		check(cutscene.skipped, raid_id + ": skip input is accepted")
		check(await wait_until(func(): return int(result.count) >= 1, 45), raid_id + ": skip finishes the cutscene")
		check(result.id == raid_id and result.skipped and int(result.count) == 1, raid_id + ": finished reports the chosen raid and skip")
		var host = TestHost.new()
		host.raid_id = str(result.id)
		root.add_child(host)
		host.open_raid()
		await process_frame
		check(host.opened == 1 and is_instance_valid(host.raid) and not host.cover.visible, raid_id + ": skip hands off to the existing transition host")
		host.free()
		world.free()

	# Click skip, plus a full unskipped play on a short remaining fixture.
	var fixture = Node3D.new()
	root.add_child(fixture)
	var pad = Node3D.new()
	pad.name = "LaunchpadShip"
	fixture.add_child(pad)
	var cutscene = Cutscene.new()
	cutscene.raid_id = "relay_ridge"
	var click_result := {"count": 0, "skipped": false}
	cutscene.finished.connect(func(_id, skipped): click_result.count += 1; click_result.skipped = skipped)
	fixture.add_child(cutscene)
	cutscene.begin(fixture)
	await process_frame
	cutscene._unhandled_input(click())
	check(await wait_until(func(): return int(click_result.count) >= 1, 45) and click_result.skipped, "Mouse click skips the cutscene")
	fixture.free()

	# Full unskipped duration once, then handoff.
	fixture = Node3D.new()
	root.add_child(fixture)
	pad = Node3D.new()
	pad.name = "LaunchpadShip"
	fixture.add_child(pad)
	cutscene = Cutscene.new()
	cutscene.raid_id = "cinder_basin"
	var play_result := {"count": 0, "skipped": true}
	cutscene.finished.connect(func(_id, skipped): play_result.count += 1; play_result.skipped = skipped)
	fixture.add_child(cutscene)
	cutscene.begin(fixture)
	var budget = int(Cutscene.DURATION * 60.0) + 30
	check(await wait_until(func(): return int(play_result.count) >= 1, budget), "Unskipped cutscene reaches its natural end")
	check(int(play_result.count) == 1 and not play_result.skipped and cutscene.elapsed >= Cutscene.DURATION - 0.08, "Full play reports unskipped completion at the contract duration")

	# HUD hide + late chase: ship stays the look target in the last ~2 seconds.
	var hud_world = HudHost.new()
	root.add_child(hud_world)
	var hud_ship = Node3D.new()
	hud_ship.name = "LaunchpadShip"
	hud_world.add_child(hud_ship)
	var hud_root = Control.new()
	hud_root.name = "HUDRoot"
	hud_world.hud_root = hud_root
	hud_world.add_child(hud_root)
	var hud_cut = Cutscene.new()
	hud_world.add_child(hud_cut)
	hud_cut.begin(hud_world)
	await process_frame
	check(hud_root.visible == false, "Gameplay HUD is hidden while the cutscene plays")
	hud_cut._update_ship(0.85)
	hud_cut._update_camera(0.85)
	var late_origin: Vector3 = hud_ship.global_position
	var cam_pos: Vector3 = hud_cut.camera.global_position
	var look_dir: Vector3 = -hud_cut.camera.global_transform.basis.z
	var to_ship: Vector3 = (late_origin + Vector3(0, 2.4, 0) - cam_pos)
	check(to_ship.length() > 1.0 and look_dir.dot(to_ship.normalized()) > 0.9, "Late camera still aims at the climbing ship")
	hud_cut.request_skip()
	check(await wait_until(func(): return not hud_cut.playing, 45), "HUD fixture skip completes")
	check(hud_root.visible == true, "Gameplay HUD is restored after the cutscene")
	hud_world.free()

	var host = TestHost.new()
	host.raid_id = "cinder_basin"
	root.add_child(host)
	host.open_raid()
	await process_frame
	check(host.opened == 1 and is_instance_valid(host.raid), "Full play hands off Cinder Basin through ship_transition")
	host.free()
	fixture.free()

	# Production confirm path: deploy starts cutscene, skip deferred-departs once, both ids.
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
	for raid_id in ["relay_ridge", "cinder_basin"]:
		var world = TestSettlement.new()
		root.add_child(world)
		world._open_ship_selection()
		world.ship_selection.select_raid(raid_id)
		world.ship_selection.deploy_button.pressed.emit()
		await process_frame
		check(is_instance_valid(world.ship_takeoff) and world.ship_takeoff.playing and world.saves == 1 and world.departures == 0, raid_id + ": adapter plays the cutscene after a committed save")
		world.ship_takeoff.request_skip()
		check(await wait_until(func(): return world.departures >= 1, 45), raid_id + ": skipped cutscene hands off through _depart_ship_preview")
		check(world.departures == 1 and world.last_departed_raid == raid_id and world.ship_contract.busy, raid_id + ": departure keeps the selected raid and the original remove/queue contract hook")
		world.free()

	print("SHIP_TAKEOFF_CUTSCENE_TESTS ", JSON.stringify({
		"checks": checks,
		"failures": failures,
		"scope": "Takeoff cutscene play, skip (Esc/Space/click), and transition handoff for relay_ridge and cinder_basin; settlement doubles, no rendered Windows acceptance"
	}))
	quit(0 if failures.is_empty() else 1)
