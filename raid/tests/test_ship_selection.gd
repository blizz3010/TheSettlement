extends SceneTree
## Real selector/adapter/host with an isolated settlement double, not native travel.
const Catalog = preload("res://raid/scripts/raid_catalog.gd")
const Selection = preload("res://raid/scripts/ship_raid_selection.gd")
const Host = preload("res://raid/scripts/ship_transition.gd")
var checks := 0
var failures: Array = []

class FakePlayer:
	extends CharacterBody3D
	var enabled := true

class FakeOptions:
	extends Control
	var quit_requests := 0
	func request_quit(): quit_requests += 1
	func open(): show()

class TestSettlement:
	extends "res://raid/scripts/ship_settlement_preview.gd"
	var allowed := true
	var save_ok := true
	var saves := 0
	var departures := 0
	var feedback := ""
	var other_modal := false
	func _ready():
		player = FakePlayer.new()
		add_child(player)
		world_initialized = true
		world_activated = true
		character_slot_bound = true
		_character_slot = "slot_2"
		_character_appearance = {"name": "Selection test", "nested": {"value": 1}}
		options_panel = FakeOptions.new()
		add_child(options_panel)
		options_panel.hide()
		for field in ["build_wheel", "inventory_panel", "dialog", "request_panel", "supplies_panel", "workbench_panel"]:
			var control = PanelContainer.new()
			add_child(control)
			control.hide()
			set(field, control)
	func _process(_delta): pass
	func modal_open(_cooking:bool=true,_fishing:bool=true,_previews:bool=true) -> bool:
		return is_instance_valid(ship_selection) or other_modal or (is_instance_valid(options_panel) and options_panel.visible)
	func ship_can_embark() -> bool:
		# Physical/mouse capture guards are not replaced in production. Headless
		# cannot capture the mouse, so this double models only eligibility state.
		return allowed and not ship_contract.busy and not modal_open() and world_initialized and world_activated and character_slot_bound and not startup_cancel_requested and player.enabled
	func save_game(_show_notice := true) -> bool:
		saves += 1
		return save_ok
	func message(text): feedback = text
	func _depart_ship_preview(): departures += 1

func check(value: bool, description: String):
	checks += 1
	if not value:
		failures.append(description)
		push_error(description)

func key(code: Key, echo_value := false) -> InputEventKey:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo_value
	return event

func make_world():
	var result = TestSettlement.new()
	root.add_child(result)
	return result

func _initialize(): call_deferred("run")

func run():
	check(Catalog.contains("relay_ridge") and Catalog.contains("cinder_basin") and Catalog.RAIDS.size() == 2, "Exactly two known raid destinations")
	check(Catalog.scene_path("relay_ridge") == "res://raid/relay_ridge.tscn" and Catalog.scene_path("cinder_basin") == "res://raid/cinder_basin.tscn", "Each destination has its distinct scene")
	check(Catalog.scene_path("res://main.tscn").is_empty() and not Catalog.contains(""), "Unknown/raw paths are not destinations")
	var host = Host.new()
	host.raid_id = "res://main.tscn"
	check(host._create_raid() == null, "Host refuses unregistered paths")
	host.free()
	for raid_id in Catalog.RAIDS:
		host = Host.new()
		host.raid_id = raid_id
		var actual_raid = host._create_raid()
		check(actual_raid != null and actual_raid.scene_file_path == Catalog.scene_path(raid_id), "Host instantiates the selected real scene: " + raid_id)
		check(actual_raid != null and actual_raid.has_signal("return_requested") and actual_raid.has_method("is_raid_ready") and actual_raid.has_method("get_raid_failure"), "Selected raid supports the complete host contract: " + raid_id)
		if actual_raid != null: actual_raid.free()
		host.free()

	for action in ["interact", "skills", "quests", "inventory", "view", "build", "rotate", "map"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var old_events = InputMap.action_get_events("interact")
	InputMap.action_erase_events("interact")
	InputMap.action_add_event("interact", key(KEY_G))
	var world = make_world()
	world._unhandled_input(key(KEY_E))
	check(not is_instance_valid(world.ship_selection) and world.saves == 0, "Old key after remap does not open selector")
	world._unhandled_input(key(KEY_G, true))
	check(not is_instance_valid(world.ship_selection) and world.saves == 0, "Echo cannot open selector")
	world.allowed = false
	world.other_modal = true
	world._unhandled_input(key(KEY_G))
	check(not is_instance_valid(world.ship_selection), "Blocked boarding cannot open selector")
	world.allowed = true
	world.other_modal = false
	world._unhandled_input(key(KEY_G))
	check(is_instance_valid(world.ship_selection) and world.saves == 0 and world.departures == 0, "Interact only opens selector, no save or departure")
	check(not world.player.enabled and world.modal_open(), "Selector disables movement and participates in modal guards")
	check(world.ship_selection.cancel_button.has_focus(), "Cancel has initial keyboard focus")
	var first = world.ship_selection
	var first_generation = world.ship_selection_generation
	world._unhandled_input(key(KEY_G))
	world._open_ship_selection()
	check(world.ship_selection == first and world.ship_selection_generation == first_generation and world.saves == 0, "Repeated input cannot replace selector or depart")
	first.raid_buttons.cinder_basin.pressed.emit()
	check(first.selected_raid_id == "cinder_basin" and first.raid_buttons.cinder_basin.button_pressed and not first.raid_buttons.relay_ridge.button_pressed, "Cinder Basin button selects only its own destination")
	check("Cinder Basin" in first.deploy_button.text and "salt flats" in first.description.text, "Selection updates destination details and explicit deploy label")
	first.select_raid("unregistered")
	check(first.selected_raid_id == "cinder_basin", "Unknown selection cannot replace valid destination")
	first.cancel_button.pressed.emit()
	check(not is_instance_valid(world.ship_selection) and world.saves == 0 and world.player.enabled, "Cancel restores controls without saving or traveling")
	first.deploy_button.pressed.emit()
	check(world.saves == 0, "Dismissed selector callback cannot deploy")
	world._open_ship_selection()
	var second = world.ship_selection
	first.deploy_button.pressed.emit()
	check(world.ship_selection == second and world.saves == 0, "Old callback cannot affect a newly opened selection")
	world._input(key(KEY_ESCAPE))
	check(not is_instance_valid(world.ship_selection) and world.player.enabled and world.saves == 0, "Escape cancels without opening Options or saving")
	world._open_ship_selection()
	world._unhandled_input(key(KEY_F9))
	world._unhandled_input(key(KEY_B))
	check(is_instance_valid(world.ship_selection) and not world.player.enabled and world.saves == 0, "Load/build shortcuts stay blocked while choosing")
	world._confirm_ship_selection(world.ship_selection_generation, "unknown")
	check(is_instance_valid(world.ship_selection) and world.saves == 0, "Unknown deploy target is rejected before save")
	world.allowed = false
	world.ship_selection.deploy_button.pressed.emit()
	check(not is_instance_valid(world.ship_selection) and world.saves == 0 and not world.ship_contract.busy, "Deploy rechecks live eligibility before saving")
	world.allowed = true
	world._open_ship_selection()
	world._character_appearance.nested.value = 2
	world.ship_selection.deploy_button.pressed.emit()
	check(world.saves == 0 and not world.ship_contract.busy, "Changed appearance invalidates selection before save")
	world._open_ship_selection()
	world._character_slot = "invalid_slot"
	world.ship_selection.deploy_button.pressed.emit()
	check(world.saves == 0, "Changed character save destination invalidates selection")
	world._character_slot = "slot_2"
	world._open_ship_selection()
	world._character_slot = "slot_1"
	world.ship_selection.deploy_button.pressed.emit()
	check(world.saves == 0, "Changed character slot invalidates selection")
	world._open_ship_selection()
	world.startup_cancel_requested = true
	world.ship_selection.deploy_button.pressed.emit()
	check(world.saves == 0 and not world.player.enabled, "Startup cancellation blocks deployment and control restoration")
	world.startup_cancel_requested = false
	world.player.enabled = true
	world._open_ship_selection()
	world.other_modal = true
	world.ship_selection.deploy_button.pressed.emit()
	check(world.saves == 0 and not world.player.enabled, "A newer modal prevents deployment and keeps control ownership")
	world.other_modal = false
	world.player.enabled = true
	world._open_ship_selection()
	world.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not is_instance_valid(world.ship_selection) and world.saves == 0 and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Focus loss cancels selection with no mouse recapture or save")
	check(not world.cooking_window_focused, "Original inherited focus notification still runs")
	world.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(world.cooking_window_focused, "Original inherited focus-in notification still runs")
	world._open_ship_selection()
	world.save_ok = false
	world.ship_selection.deploy_button.pressed.emit()
	check(world.saves == 1 and not world.ship_contract.busy and world.player.enabled and not is_instance_valid(world.ship_selection), "Failed save leaves active settlement and no selection lock")
	check("Could not save" in world.feedback, "Save failure is explained")
	world.save_ok = true
	world._open_ship_selection()
	var final_selector = world.ship_selection
	final_selector.raid_buttons.cinder_basin.pressed.emit()
	final_selector.deploy_button.pressed.emit()
	final_selector.deploy_button.pressed.emit()
	world._unhandled_input(key(KEY_G))
	await process_frame
	check(world.saves == 2 and world.departures == 1 and world.ship_contract.busy, "Explicit deploy commits once despite repeated confirmation/input")
	check(world.ship_selected_raid_id == "cinder_basin", "Confirmed second map ID is retained for transition")
	check(world.ship_contract.binding.slot == "slot_1" and world.ship_contract.binding.appearance.nested.value == 2, "Departure retains the current exact character binding")
	check(not world.player.enabled, "Controls are disabled between committed save and deferred departure")
	world.free()

	# Remapped UI activation keys must not turn a boarding key into confirmation.
	for code in [KEY_ENTER, KEY_SPACE]:
		InputMap.action_erase_events("interact")
		InputMap.action_add_event("interact", key(code))
		world = make_world()
		world._unhandled_input(key(code))
		world.ship_selection.deploy_button.grab_focus()
		world._input(key(code))
		check(root.is_input_handled() and world.saves == 0 and is_instance_valid(world.ship_selection), "Interact consumes GUI activation before focused Deploy: " + str(code))
		world._close_ship_selection()
		world.free()
	InputMap.action_erase_events("interact")
	for event in old_events: InputMap.action_add_event("interact", event)

	world = make_world()
	world._open_ship_selection()
	world.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(not is_instance_valid(world.ship_selection) and world.saves == 0, "Window close dismisses selector without travel")
	check(world.options_panel.quit_requests == 1 and world.options_panel.visible and not world.player.enabled, "Original quit-confirmation flow retains control")
	world.free()

	var original_size = root.content_scale_size
	for viewport_size in [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(640, 480)]:
		root.content_scale_size = viewport_size
		var ui = Selection.new()
		root.add_child(ui)
		for i in 3: await process_frame
		for raid_id in Catalog.RAIDS:
			ui.select_raid(raid_id)
			await process_frame
			var viewport_rect = Rect2(Vector2.ZERO, Vector2(viewport_size))
			check(viewport_rect.encloses(ui.panel.get_global_rect()), "Selection panel fits viewport " + str(viewport_size) + " / " + raid_id)
			check(ui.panel.get_global_rect().encloses(ui.deploy_button.get_global_rect()) and ui.panel.get_global_rect().encloses(ui.cancel_button.get_global_rect()), "Both actions stay visible inside panel " + str(viewport_size) + " / " + raid_id)
		ui.free()
	root.content_scale_size = original_size
	print("RELAY_SHIP_SELECTION_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "scope": "Selection UI and real adapter/host with settlement doubles; no rendered boarding or production save I/O"}))
	quit(0 if failures.is_empty() else 1)
