extends "res://scripts/settlement.gd"
## Additive review adapter; the approved settlement script remains unchanged.
const ShipContract = preload("res://raid/scripts/ship_contract.gd")
var ship_contract = ShipContract.new()
const Catalog = preload("res://raid/scripts/raid_catalog.gd")
var ship_selected_raid_id := "relay_ridge"
const ShipSelection = preload("res://raid/scripts/ship_raid_selection.gd")
var ship_selection: CanvasLayer
var ship_selection_generation := 0
var ship_selection_binding: Dictionary = {}

func modal_open(include_cooking:bool=true,include_fishing_trader:bool=true,include_preview_traders:bool=true) -> bool:
	return is_instance_valid(ship_selection) or super.modal_open(include_cooking, include_fishing_trader, include_preview_traders)

func _process(delta):
	if ship_contract.busy: return
	super._process(delta)
	if ship_can_embark():
		prompt.text = key_label("interact") + "  Select raid • Ship deployment"
		prompt_panel.show()
		layout_status_panel()

func ship_can_embark() -> bool:
	if ship_contract.busy or not character_slot_bound or not world_initialized or not world_activated or startup_cancel_requested: return false
	if not is_instance_valid(player) or not player.enabled or player.seated or not player.is_on_floor(): return false
	if build_mode or moving_stash or modal_open() or fishing_session.active(): return false
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return false
	# Match the baseline's service precedence, reevaluated at the input event.
	if not aimed_door().is_empty() or workbench_accessible() or not aimed_furniture("lantern").is_empty(): return false
	if stash_accessible() or player.position.distance_to(BOARD) < 2.8 or can_use_steward(): return false
	if is_instance_valid(trader_previews) and not trader_previews.nearest().is_empty(): return false
	if tailor_accessible() or supplies_accessible() or Seats.target(self, player) != null or fishing_accessible(): return false
	if is_instance_valid(cooking_test) and (cooking_test.vendor_accessible() or cooking_test.accessible()): return false
	if is_instance_valid(fishing_trader) and fishing_trader.accessible(): return false
	return ship_has_boarding_support()

func ship_has_boarding_support() -> bool:
	# The unchanged physical predicate is separate so real collision/controller
	# checks do not need to bypass headless mouse capture or the startup gates.
	var ship = get_node_or_null("LaunchpadShip")
	if ship == null or not ShipContract.in_zone(ship.to_local(player.global_position)): return false
	# Require actual pad support and clear line to the boarding point, not just radius.
	var space = get_world_3d().direct_space_state
	var support = PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.25, player.global_position - Vector3.UP * 0.8)
	support.exclude = [player.get_rid()]
	var hit = space.intersect_ray(support)
	if hit.is_empty() or hit.collider != ship.get_node_or_null("Collision/PadDeck"): return false
	var sight = PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 1.4, ship.to_global(Vector3(0, 2.68, 4.8)))
	sight.exclude = [player.get_rid()]
	return space.intersect_ray(sight).is_empty()

func _input(event):
	if not is_instance_valid(ship_selection): return
	if event is InputEventKey:
		if event.pressed and not event.echo and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE):
			_close_ship_selection()
			get_viewport().set_input_as_handled()
		elif event.is_action("interact"):
			# Even if Interact is rebound to Enter/Space, it cannot activate a GUI button.
			get_viewport().set_input_as_handled()

func _unhandled_input(event):
	if ship_contract.busy: return
	if is_instance_valid(ship_selection):
		# Block baseline quick-load/build/menu shortcuts while choosing a destination.
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("interact") and ship_can_embark():
		get_viewport().set_input_as_handled()
		_open_ship_selection()
		return
	super._unhandled_input(event)

func _open_ship_selection():
	if is_instance_valid(ship_selection) or not ship_can_embark(): return
	ship_selection_generation += 1
	var generation = ship_selection_generation
	ship_selection_binding = {"slot": _character_slot, "path": character_save_path, "appearance": character_appearance.duplicate(true)}
	ship_selection = ShipSelection.new()
	ship_selection.deploy_requested.connect(func(raid_id: String): _confirm_ship_selection(generation, raid_id))
	ship_selection.cancelled.connect(func():
		if generation == ship_selection_generation: _close_ship_selection()
	)
	add_child(ship_selection)
	if is_instance_valid(player):
		player.enabled = false
		player.velocity = Vector3.ZERO
	if is_instance_valid(prompt_panel): prompt_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_ship_selection(recapture := true):
	if not is_instance_valid(ship_selection): return
	ship_selection.hide()
	ship_selection.queue_free()
	ship_selection = null
	ship_selection_binding.clear()
	ship_selection_generation += 1
	var can_resume = world_initialized and world_activated and not startup_cancel_requested and not ship_contract.busy and not modal_open()
	if is_instance_valid(player):
		player.enabled = can_resume
		player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if recapture and can_resume and cooking_window_focused else Input.MOUSE_MODE_VISIBLE

func _confirm_ship_selection(generation: int, raid_id := "relay_ridge"):
	if generation != ship_selection_generation or not is_instance_valid(ship_selection) or ship_contract.busy: return
	if not Catalog.contains(raid_id):
		return
	if not cooking_window_focused:
		_close_ship_selection(false)
		return
	var binding_unchanged = ship_selection_binding == {"slot": _character_slot, "path": character_save_path, "appearance": character_appearance}
	_close_ship_selection()
	# Restore normal input state synchronously, then rerun the unchanged boarding
	# checks, including physical pad support, service precedence and live position.
	if not binding_unchanged or not ship_can_embark():
		message("Departure cancelled. Return to the ship and select the raid again.")
		return
	if not ship_contract.begin(self):
		message("Could not save before departure. You remain in the settlement.")
		return
	ship_selected_raid_id = raid_id
	if is_instance_valid(player): player.enabled = false
	call_deferred("_depart_ship_preview")

func open_options():
	# The inherited close-request handler can run before this subclass receives
	# its notification. Dismiss selection before its modal check in either order.
	_close_ship_selection(false)
	super.open_options()

func _notification(what):
	# Godot dispatches notifications to inherited scripts too. Do not call the
	# baseline handler twice; it still owns focus bookkeeping and the quit dialog.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_close_ship_selection(false)

func _depart_ship_preview():
	if not ship_contract.busy or not is_inside_tree() or is_queued_for_deletion(): return
	var host = load("res://raid/scripts/ship_transition.gd").new()
	host.binding = ship_contract.binding.duplicate(true)
	host.raid_id = ship_selected_raid_id
	get_tree().root.add_child(host)
	get_tree().current_scene = host
	# Bare free() is not resolved as a self method by the Windows export parser.
	# Exit the tree immediately, so old physics, UI, focus handlers and audio are
	# gone before the raid opens. Queue destruction through the bound Node API.
	host.call_deferred("open_raid")
	get_parent().remove_child(self)
	queue_free()

func activate_loaded_world():
	super.activate_loaded_world()
	preload("res://raid/scripts/settlement_visuals_style_test.gd").apply(self)
