extends SceneTree
var failures := 0
class TestSettlement:
	extends "res://raid/scripts/ship_settlement_preview.gd"
	var allowed := true
	var save_ok := true
	var saves := 0
	var departures := 0
	func modal_open(_cooking:bool=true,_fishing:bool=true,_previews:bool=true) -> bool: return is_instance_valid(ship_selection)
	func _ready(): pass
	func _process(_delta): pass
	func ship_can_embark() -> bool: return allowed and not ship_contract.busy and not is_instance_valid(ship_selection)
	func save_game(_show_notice := true) -> bool:
		saves += 1
		return save_ok
	func message(_text): pass
	func _depart_ship_preview(): departures += 1
class FakeRaid:
	extends Node
	signal return_requested
	var ready_flag := true
	func is_raid_ready(): return ready_flag
class TestHost:
	extends "res://raid/scripts/ship_transition.gd"
	var restores := 0
	var factory_mode := "ready"
	func _create_raid() -> Node:
		if factory_mode == "missing": return null
		if factory_mode == "invalid": return Node.new()
		var result = FakeRaid.new()
		result.ready_flag = factory_mode != "waiting"
		return result
	func _restore_title(): restores += 1
func check(value: bool, description: String):
	if not value:
		push_error(description)
		failures += 1
func key(code: Key, echo_value := false):
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo_value
	return event
func _initialize(): call_deferred("run")
func run():
	if not InputMap.has_action("interact"): InputMap.add_action("interact")
	var previous = InputMap.action_get_events("interact")
	InputMap.action_erase_events("interact")
	InputMap.action_add_event("interact", key(KEY_G))
	var world = TestSettlement.new()
	root.add_child(world)
	world._unhandled_input(key(KEY_E))
	check(world.saves == 0, "Old E key does not embark after remap")
	world._unhandled_input(key(KEY_G, true))
	check(world.saves == 0, "Key echo does not embark")
	world.allowed = false
	world._unhandled_input(key(KEY_G))
	check(world.saves == 0, "Stale/blocked interaction rejected")
	world.allowed = true
	world.save_ok = false
	world._unhandled_input(key(KEY_G))
	check(world.saves == 0 and is_instance_valid(world.ship_selection), "Interact opens selection without saving")
	world.ship_selection.deploy_button.pressed.emit()
	check(world.saves == 1 and not world.ship_contract.busy, "Failed save keeps settlement active")
	world.save_ok = true
	world._unhandled_input(key(KEY_G))
	world._unhandled_input(key(KEY_G))
	var selector = world.ship_selection
	selector.deploy_button.pressed.emit()
	selector.deploy_button.pressed.emit()
	await process_frame
	check(is_instance_valid(world.ship_takeoff) and world.ship_takeoff.playing, "Confirmed deploy starts the takeoff cutscene")
	world.ship_takeoff.request_skip()
	for _i in 45:
		await process_frame
		if world.departures >= 1:
			break
	check(world.saves == 2 and world.departures == 1, "Remapped interaction departs once despite duplicate input")
	world.free()
	InputMap.action_erase_events("interact")
	for event in previous: InputMap.action_add_event("interact", event)
	for mode in ["ready", "missing", "invalid", "waiting"]:
		var host = TestHost.new()
		host.factory_mode = mode
		root.add_child(host)
		host.open_raid()
		await process_frame
		if mode == "ready": check(not host.cover.visible, "Ready raid removes loading cover")
		else: check(host.cover.visible, "Failed or pending raid remains covered: " + mode)
		host.return_to_settlement()
		host.return_to_settlement()
		await process_frame
		check(host.restores == 1, "Cancel/return is idempotent: " + mode)
		host.free()
	print("Ship flow: ", "PASS" if failures == 0 else "FAIL", " (15 checks; real selection/input adapter, skippable takeoff, and host with test doubles)")
	quit(1 if failures else 0)
