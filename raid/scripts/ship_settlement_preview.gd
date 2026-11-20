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
const MidstyleSwap = preload("res://raid/scripts/midstyle_swap.gd")
const MidstyleRollout = preload("res://raid/scripts/midstyle_rollout.gd")
const MidstyleRollout2 = preload("res://raid/scripts/midstyle_rollout2.gd")
const TraderBuyMenus = preload("res://raid/scripts/trader_buy_menus.gd")
const DanListings = preload("res://raid/scripts/dan_listings_install.gd")
const AtlasRecovery = preload("res://raid/scripts/atlas_recovery_install.gd")
const GearShop = preload("res://raid/scripts/gear_tiers/gear_shop_install.gd")
const RaidLoot = preload("res://raid/scripts/raid_loot/raid_loot_install.gd")
const RaidOutcome = preload("res://raid/scripts/raid_outcome.gd")
const ShipTakeoff = preload("res://raid/scripts/ship_takeoff_cutscene.gd")
var ship_takeoff: Node
const SettlementHealth = preload("res://raid/scripts/settlement_health.gd")
const TownHallRecovery = preload("res://raid/scripts/town_hall_recovery.gd")
const GrassViewCulling = preload("res://raid/scripts/grass_view_culling.gd")
const ShipBoardingWayfinding = preload("res://raid/scripts/ship_boarding_wayfinding.gd")
const HudTitleFade = preload("res://raid/scripts/hud_title_fade.gd")
const FirstRunGuide = preload("res://raid/scripts/first_run_guide.gd")
const JumpTuning = preload("res://raid/scripts/jump_tuning.gd")
const P2Art = preload("res://raid/scripts/p2_art.gd")
const P1VisualFixes = preload("res://raid/scripts/p1_visual_fixes.gd")
const CameraCollision = preload("res://raid/scripts/camera_collision.gd")
const SolidProps = preload("res://raid/scripts/solid_props.gd")
var player_health: Node

func _initialize_world():
	# Item 12 rollout: raid prop remodels follow the item 11 switch (see midstyle_rollout.gd).
	MidstyleRollout.enabled = MidstyleSwap.enabled
	MidstyleRollout2.enabled = MidstyleSwap.enabled
	if OS.get_environment("MIDSTYLE_ROLLOUT2") == "0":
		MidstyleRollout2.enabled = false
	await super._initialize_world()
	# Item 11 style test: mid-stylized prop remodels, render-only (see midstyle_swap.gd).
	if MidstyleSwap.enabled and world_initialized and not startup_cancel_requested:
		MidstyleSwap.apply(self)
	# Item 12 rollout 2: ship + request board remodels (idempotent, render-only).
	if MidstyleRollout2.enabled and world_initialized and not startup_cancel_requested:
		MidstyleRollout2.apply(self)
	# Item 16: working specialist buy menus (Rook, Psy, Tailor, Fishing). Idempotent.
	if world_initialized and not startup_cancel_requested:
		TraderBuyMenus.install(self)
	# Item 13: Dan's local player listings. Idempotent.
	if world_initialized and not startup_cancel_requested:
		DanListings.install(self)
	# Item 13: Atlas recovery. Runs after Dan so it can extend that controller.
	if world_initialized and not startup_cancel_requested:
		AtlasRecovery.install(self)
	# Item 22 PR C: Psy's tier gear shop. Runs after Atlas so it can extend that controller.
	if world_initialized and not startup_cancel_requested:
		GearShop.install(self)
	# Item 13: raid loot. Atlas gains a Salvage tab. Runs after the Psy tier shop.
	if world_initialized and not startup_cancel_requested:
		RaidLoot.install(self)
	# Health/damage: live source for the existing HUD vitals bar; full health on return.
	if world_initialized and not startup_cancel_requested and is_instance_valid(player):
		player_health = SettlementHealth.attach(player)
		var raid_outcome: Dictionary = RaidOutcome.peek()
		set_meta("returned_from_raid", not raid_outcome.is_empty())
		var atlas_note := AtlasRecovery.apply_return(self, raid_outcome)
		GearShop.apply_return(self, raid_outcome)
		var loot_note := RaidLoot.apply_return(self, raid_outcome)
		var note := SettlementHealth.on_return(player_health)
		if not atlas_note.is_empty():
			note = (note + " " + atlas_note).strip_edges() if not note.is_empty() else atlas_note
		if not loot_note.is_empty():
			note = (note + " " + loot_note).strip_edges() if not note.is_empty() else loot_note
		if not note.is_empty(): message(note)
	# Item 21: stuck recovery / input safety net, and view culling for the dense grass.
	if world_initialized and not startup_cancel_requested:
		TownHallRecovery.install(self)
		GrassViewCulling.install(self)
		# Ori Nov 18 playtest: way signs, boarding ring, approach hint, ramp-side pocket beds.
		ShipBoardingWayfinding.install(self)
		# Queue item 2 (Ori playtest2): higher jump, HUD title fade, first-run guidance.
		if is_instance_valid(player): JumpTuning.attach(player)
		HudTitleFade.install(self)
		FirstRunGuide.install(self)
		# TASKS item 5: Artie's P2 art swaps, applied once every startup controller has settled.
		P2Art.install(self)
		# Queue item 4: P1 visual fixes (stairwell, grass edge lips, threshold). Same frame as
		# GrassViewCulling.install, before it splits the grass it trims. SETTLEMENT_P1_VISUAL=off skips.
		if OS.get_environment("SETTLEMENT_P1_VISUAL") != "off": P1VisualFixes.install(self)
		# Queue item 3: third-person camera spring arm + camera-only mirror of visible meshes.
		SolidProps.install(self)
		if is_instance_valid(player): CameraCollision.attach(player, self)

func modal_open(include_cooking:bool=true,include_fishing_trader:bool=true,include_preview_traders:bool=true) -> bool:
	# Hide gameplay HUD (minimap, vitals, hotbar) for the duration of takeoff.
	return is_instance_valid(ship_selection) or is_instance_valid(ship_takeoff) or super.modal_open(include_cooking, include_fishing_trader, include_preview_traders)

func _process(delta):
	if ship_contract.busy or is_instance_valid(ship_takeoff): return
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
	if ship_contract.busy or is_instance_valid(ship_takeoff): return
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
	# cooking_window_focused is the settlement-wide window-focus flag
	# (DisplayServer.window_is_focused, forced true in headless). It is not a
	# leftover cooking-only Deploy gate. An unfocused window must not embark.
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
	call_deferred("_begin_takeoff_cutscene")

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

func _begin_takeoff_cutscene():
	if not ship_contract.busy or not is_inside_tree() or is_queued_for_deletion(): return
	if is_instance_valid(ship_takeoff): return
	ship_takeoff = ShipTakeoff.new()
	ship_takeoff.name = "ShipTakeoffCutscene"
	ship_takeoff.raid_id = ship_selected_raid_id
	ship_takeoff.finished.connect(_on_takeoff_finished)
	add_child(ship_takeoff)
	ship_takeoff.begin(self)

func _on_takeoff_finished(raid_id: String, _skipped: bool):
	if raid_id != "":
		ship_selected_raid_id = raid_id
	call_deferred("_depart_ship_preview")

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
	# TASKS item 8 (PR #4): mid-stylized hideout dressing.
	preload("res://raid/scripts/settlement_visuals_style_test.gd").apply(self)
	# TASKS item 10: reshape the hills that ran through the inn lake.
	if world_activated:
		var lake_fix: Dictionary = preload("res://raid/scripts/inn_lake_mountain_fix.gd").apply(self)
		if not lake_fix.get("ok", false):
			push_warning("Inn lake mountain fix skipped: " + str(lake_fix.get("reason", lake_fix)))
	# Item 11 swap, second pass for the normal (staged) start: the title runs the startup asset
	# gate after _initialize_world, and the gate is what builds TailorAtelier. apply() skips any
	# prop already swapped (MidstyleDressForm / MidstyleCounterStock / MidstyleReceptionDesk), so
	# this only adds what the first pass could not reach; nothing is applied twice.
	if MidstyleSwap.enabled and world_activated and not startup_cancel_requested:
		MidstyleSwap.apply(self)
	# Item 12 rollout 2, second pass for the staged start (RequestBoard signage exists by then).
	if MidstyleRollout2.enabled and world_activated and not startup_cancel_requested:
		MidstyleRollout2.apply(self)
	# Item 16 menus, second pass for the staged start (panels exist after activation too).
	if world_activated and not startup_cancel_requested:
		TraderBuyMenus.install(self)
	# Item 13 listings, second pass for the staged start.
	if world_activated and not startup_cancel_requested:
		DanListings.install(self)
	# Item 13 Atlas recovery, second pass (after Dan, so the controller stays extended).
	if world_activated and not startup_cancel_requested:
		AtlasRecovery.install(self)
	# Item 22 PR C: Psy tier shop, second pass (after Atlas).
	if world_activated and not startup_cancel_requested:
		GearShop.install(self)
	# Item 13 raid loot, second pass (after the Psy tier shop).
	if world_activated and not startup_cancel_requested:
		RaidLoot.install(self)
	# TASKS item 9: far scenery (option B) is on by default in the normal game.
	# FAR_SCENERY_OPTION=off turns it off for tests and benches. Runs after
	# the lake fix so MiddleRidge keeps PR #5's reshape (lake_cut off).
	# Original thin dome ribs are hidden at runtime; settlement.gd is not edited.
	if world_activated:
		var far_opt: Dictionary = preload("res://raid/scripts/far_scenery_options.gd").apply(self)
		if not far_opt.get("skipped", false) and not far_opt.get("ok", false):
			push_warning("Far scenery skipped: " + str(far_opt.get("reason", far_opt)))
		# TASKS item 5 (f): smooth distant hill chunks replace the faceted far rings. DISTANT_HILLS=off / P2_HILLS=off.
		P2Art.install_distant_hills(self)
	# TASKS item 21: pause-menu recovery + Escape/quit/mouse safety net, and grass view
	# culling (the Town Hall "stall" was ~16.5M grass-heavy primitives per frame).
	if world_activated and not startup_cancel_requested:
		TownHallRecovery.install(self)
		GrassViewCulling.install(self)
		# Ori Nov 18 playtest: way signs, boarding ring, approach hint, ramp-side pocket beds.
		ShipBoardingWayfinding.install(self)
		# Queue item 2 (Ori playtest2): higher jump, HUD title fade, first-run guidance.
		if is_instance_valid(player): JumpTuning.attach(player)
		HudTitleFade.install(self)
		FirstRunGuide.install(self)
		# TASKS item 5: Artie's P2 art swaps, applied once every startup controller has settled.
		P2Art.install(self)
		# Queue item 4, second pass for the staged start (idempotent: trims only new grass batches).
		if OS.get_environment("SETTLEMENT_P1_VISUAL") != "off": P1VisualFixes.install(self)
		# Queue item 3: third-person camera spring arm + camera-only mirror of visible meshes.
		SolidProps.install(self)
		if is_instance_valid(player): CameraCollision.attach(player, self)

func save_payload(payload: Dictionary, show_notice := true, writer_override = null) -> bool:
	var ok := super.save_payload(payload, show_notice, writer_override)
	if ok and has_meta("dan_listings"):
		var store = get_meta("dan_listings")
		if store != null and store.has_method("save"):
			if not store.save():
				push_warning("Dan listings sidecar could not be saved: " + str(store.get("last_error")))
	if ok and has_meta("atlas_recovery"):
		var atlas = get_meta("atlas_recovery")
		if atlas != null and atlas.has_method("save"):
			if not atlas.save():
				push_warning("Atlas recovery sidecar could not be saved: " + str(atlas.get("last_error")))
	return ok

func load_game(show_notice := true) -> bool:
	var ok := super.load_game(show_notice)
	if ok:
		DanListings.load_store(self)
		AtlasRecovery.load_store(self)
		GearShop.load_store(self)
		RaidLoot.load_store(self)
	return ok
