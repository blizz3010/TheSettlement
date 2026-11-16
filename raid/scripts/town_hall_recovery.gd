extends Node
## TASKS item 21 (Ori's playtest blocker): stuck-recovery and input safety net for the
## settlement. Installed by ship_settlement_preview.gd; settlement.gd, player.gd and
## options_panel.gd are pinned (tools/pinned-r8-runtime.json), so everything here is additive:
##  * Pause menu (Esc -> Options) gets "Return to Town Hall entrance": closes every overlay,
##    stands the player up, and places them just inside the hall doorway facing out.
##  * Escape always does something: Escape closes the full map first (it never falls through
##    to Options), and three Escape presses within 2 s force-close every overlay, release
##    stuck movement keys and open the pause menu, even if a panel's state is inconsistent.
##  * Quit always works: the quit prompt gets "Quit without saving", and a second window-close
##    request while the quit prompt is up saves if it can and quits.
##  * A movement key pressed and released within one slow frame still moves the player.
##  * Mouse look is capped per frame while frames are slow (see LOOK_CAP_RAD).
##  * Mouse capture: whenever no overlay is open and the window is focused, the player is
##    re-enabled and the mouse recaptured after a short grace period.
const NODE_NAME := "TownHallRecovery"
## Just inside the Town Hall doorway (front wall z = -14.2, opening x = -2.1..2.1), facing out.
const ENTRANCE := Vector3(0.0, 0.0, -15.4)
const ENTRANCE_YAW := PI
## Login spawn (scripts/login_spawn.gd), used if the doorway is blocked.
const FALLBACK := Vector3(0.0, 0.0, -17.2)
const ESCAPE_WINDOW_MS := 2000
const ESCAPE_PANIC_COUNT := 3
const RECAPTURE_GRACE_S := 0.5
const CLOSE_REPEAT_MS := 20000
## Mouse look on slow frames: player.gd (pinned) applies every motion event at once, so on a
## multi-second frame the queued nudges of a player waiting for the view land together and pin
## the camera at the -1.25 pitch clamp (the floor). When the last frame took longer than
## SLOW_FRAME_MS, the look applied per frame is capped at LOOK_CAP_RAD; normal frame rates are
## untouched.
const SLOW_FRAME_MS := 100
const LOOK_CAP_RAD := 0.35
## Movement keys on slow frames: player.gd polls Input.is_action_pressed in _physics_process.
## When a press and its release are flushed in the same frame (any hold shorter than a
## multi-second frame), the physics steps never see the key down and the player does not move.
## Such a press is kept down for that frame's physics steps and released afterwards.
const LATCH_ACTIONS := ["forward", "backward", "left", "right"]
const RETURN_LABEL := "Return to Town Hall entrance"
const QUIT_NOW_LABEL := "Quit without saving"

var world: Node
var return_button: Button
var quit_now_button: Button
var escape_times: Array[int] = []
var uncaptured_since_ms := -1
var uncaptured_frames := 0
var last_close_request_ms := -CLOSE_REPEAT_MS
var recaptures := 0
var last_frame_ms := 0
var last_tick_ms := -1
var look_budget_px := Vector2.INF
var look_capped := 0
var press_frame := {}
var latched := {}
var latches := 0
var panics := 0
var last_return: Dictionary = {}
## Tests replace this so a quit does not end the test run.
var quit_handler: Callable
var quits := 0

static func install(host: Node) -> Node:
	if host == null or not is_instance_valid(host): return null
	var existing := host.get_node_or_null(NODE_NAME)
	if existing != null:
		existing.call("inject_buttons")
		return existing
	if OS.get_environment("SETTLEMENT_TOWN_HALL_RECOVERY") == "off": return null
	var node = load("res://raid/scripts/town_hall_recovery.gd").new()
	node.name = NODE_NAME
	node.world = host
	host.add_child(node)
	return node

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if world == null: world = get_parent()
	inject_buttons()

func _options():
	return world.get("options_panel") if world != null else null

## Adds the pause-menu button next to "Back to Game" and a no-save quit to the quit prompt.
func inject_buttons() -> void:
	var options = _options()
	if options == null or not is_instance_valid(options): return
	if options.get("title_context") == true: return
	if not is_instance_valid(return_button):
		var back = options.get("back_button")
		if back is Button and is_instance_valid(back) and back.get_parent() != null:
			return_button = Button.new()
			return_button.name = "ReturnToTownHallEntrance"
			return_button.text = RETURN_LABEL
			return_button.tooltip_text = "Stuck? Closes every menu and puts you just inside the Town Hall doorway, facing the plaza."
			return_button.custom_minimum_size.y = 36
			back.get_parent().add_child(return_button)
			back.get_parent().move_child(return_button, back.get_index() + 1)
			return_button.pressed.connect(func(): return_to_entrance("pause_menu"))
	if not is_instance_valid(quit_now_button):
		var quit_row = options.get("quit_row")
		if quit_row is Control and is_instance_valid(quit_row):
			quit_now_button = Button.new()
			quit_now_button.name = "QuitWithoutSaving"
			quit_now_button.text = QUIT_NOW_LABEL
			quit_now_button.tooltip_text = "Closes the game immediately. Progress since your last save is lost."
			quit_now_button.custom_minimum_size.y = 36
			quit_row.add_child(quit_now_button)
			quit_now_button.pressed.connect(quit_now)

func _world_live() -> bool:
	if world == null or not is_instance_valid(world) or not world.is_inside_tree(): return false
	if world.get("world_initialized") != true or world.get("startup_cancel_requested") == true: return false
	if world.get("staged_startup") == true and world.get("world_activated") != true: return false
	if not is_instance_valid(world.get("player")): return false
	var contract = world.get("ship_contract")
	if contract != null and contract.get("busy") == true: return false
	if is_instance_valid(world.get("ship_takeoff")): return false
	return true

func _is_escape(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE)

func _cap_look(event: InputEventMouseMotion) -> void:
	if last_frame_ms <= SLOW_FRAME_MS: return
	var p = world.get("player") if world != null else null
	if not is_instance_valid(p): return
	var sens: float = maxf(float(p.get("mouse_sensitivity")), 0.0001)
	if look_budget_px == Vector2.INF: look_budget_px = Vector2.ONE * (LOOK_CAP_RAD / sens)
	var r := event.relative
	var capped := Vector2(clampf(r.x, -look_budget_px.x, look_budget_px.x), clampf(r.y, -look_budget_px.y, look_budget_px.y))
	look_budget_px = Vector2(maxf(look_budget_px.x - absf(capped.x), 0.0), maxf(look_budget_px.y - absf(capped.y), 0.0))
	if capped != r:
		look_capped += 1
		# The same event object continues to player.gd's _unhandled_input.
		event.relative = capped

func _latch_movement(event: InputEventKey) -> void:
	if not _world_live(): return
	var frame := Engine.get_process_frames()
	for action in LATCH_ACTIONS:
		if not InputMap.has_action(action) or not event.is_action(action): continue
		if event.pressed:
			press_frame[action] = frame
		elif press_frame.get(action, -1) == frame and not Input.is_action_pressed(action):
			Input.action_press(action)
			latched[action] = frame
			latches += 1

func _release_latched() -> void:
	for action in latched.keys():
		Input.action_release(action)
	latched.clear()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _world_live(): _cap_look(event)
		return
	if event is InputEventKey and not event.echo:
		_latch_movement(event)
	if not _is_escape(event) or not _world_live(): return
	var options = _options()
	# A key-binding capture in Options owns Escape (it cancels the capture).
	if options != null and options.visible and not str(options.get("capture_action")).is_empty(): return
	var now := Time.get_ticks_msec()
	escape_times.append(now)
	while not escape_times.is_empty() and now - escape_times[0] > ESCAPE_WINDOW_MS: escape_times.pop_front()
	if escape_times.size() >= ESCAPE_PANIC_COUNT:
		escape_times.clear()
		force_unstick("escape")
		get_viewport().set_input_as_handled()
		return
	# Ori's input item 4: Escape closes the full map and never falls through to Options.
	var hud = world.get("settlement_hud")
	if is_instance_valid(hud) and hud.full.visible and not world.get("moving_stash"):
		world.close_map()
		get_viewport().set_input_as_handled()

func _close_all_overlays() -> void:
	var w = world
	if w.has_method("cancel_fishing"): w.cancel_fishing("")
	if w.get("moving_stash") == true and w.has_method("cancel_stash_move"): w.cancel_stash_move()
	if is_instance_valid(w.get("ship_selection")) and w.has_method("_close_ship_selection"): w._close_ship_selection(false)
	for controller in ["trader_previews", "fishing_trader", "cooking_test"]:
		var c = w.get(controller)
		if is_instance_valid(c) and c.has_method("close"): c.close()
	var hud = w.get("settlement_hud")
	if is_instance_valid(hud) and hud.full.visible: w.close_map()
	if is_instance_valid(w.get("skills_panel")) and w.skills_panel.visible: w.close_skills()
	if is_instance_valid(w.get("quest_journal")) and w.quest_journal.visible: w.close_quests()
	if is_instance_valid(w.get("build_wheel")) and w.build_wheel.visible: w.close_build_wheel()
	if w.get("build_mode") == true and w.has_method("cancel_home_build"): w.cancel_home_build()
	if w.inventory_panel.visible: w.close_inventory()
	if w.dialog.visible: w.close_dialog()
	if is_instance_valid(w.get("clothing_panel")) and w.clothing_panel.visible: w.close_clothing()
	if w.request_panel.visible: w.close_request_board()
	if w.supplies_panel.visible: w.close_supplies()
	if is_instance_valid(w.get("workbench_panel")) and w.workbench_panel.visible: w.close_workbench()
	# Anything a panel left behind: hide the visible panels the predicate still reports.
	for panel_name in ["skills_panel", "quest_journal", "clothing_panel", "workbench_panel", "build_wheel", "inventory_panel", "dialog", "request_panel", "supplies_panel"]:
		var panel = w.get(panel_name)
		if is_instance_valid(panel) and panel is CanvasItem and panel.visible: panel.hide()
	if is_instance_valid(hud) and hud.full.visible: hud.full.hide()
	w.set("map_restore_pending", false)
	for action in ["forward", "backward", "left", "right", "sprint", "jump", "crouch", "interact"]:
		if InputMap.has_action(action): Input.action_release(action)

## Escape x3: close everything that could be holding input, then show the pause menu.
func force_unstick(reason: String) -> Dictionary:
	if not _world_live(): return {"ok": false, "reason": "world not live"}
	panics += 1
	var options = _options()
	if options != null and options.visible:
		if options.get("remaining") != null and float(options.remaining) > 0.0: options.revert_display()
		options.cancel_and_close()
	_close_all_overlays()
	var p = world.player
	p.velocity = Vector3.ZERO
	p.enabled = true
	if world.has_method("open_options"): world.open_options()
	var opened: bool = options != null and options.visible
	if not opened:
		# Options refused (a modal still reports open): restore direct control instead.
		p.enabled = true
		if world.get("cooking_window_focused") != false: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("TOWN_HALL_RECOVERY unstick reason=%s options_open=%s modal=%s" % [reason, opened, world.modal_open()])
	return {"ok": true, "options_open": opened, "modal_open": world.modal_open()}

func _force_stand(p: Node) -> void:
	if p.get("seated") == true:
		if not p.try_stand_from_seat():
			# Recovery wins over seat-exit validation: the doorway placement below is checked.
			p.seated = false
			p.seated_exits.clear()
			p.body_shape.shape = p.standing_shape.duplicate()
			p.body_shape.position.y = p.STANDING_HEIGHT * 0.5
			p.avatar.mesh.height = p.STANDING_HEIGHT - 0.1
			p.avatar.mesh.radius = 0.3
			p.avatar.position.y = p.STANDING_HEIGHT * 0.5
	if p.get("crouched") == true:
		p.crouched = false
		p.body_shape.shape.height = p.STANDING_HEIGHT
		p.body_shape.position.y = p.STANDING_HEIGHT * 0.5
		p.avatar.mesh.height = p.STANDING_HEIGHT - 0.1
		p.avatar.position.y = p.STANDING_HEIGHT * 0.5

func _clear_foot(xz: Vector3) -> Variant:
	var p = world.player
	var space = world.get_world_3d().direct_space_state
	var ray = PhysicsRayQueryParameters3D.create(Vector3(xz.x, 2.0, xz.z), Vector3(xz.x, -1.0, xz.z), p.collision_mask, [p.get_rid()])
	var hit = space.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < 0.95: return null
	var foot: Vector3 = hit.position + Vector3.UP * 0.03
	var q = PhysicsShapeQueryParameters3D.new()
	q.shape = p.standing_shape
	q.transform = Transform3D(Basis.IDENTITY, foot + Vector3.UP * (p.STANDING_HEIGHT * 0.5 + 0.005))
	q.collision_mask = p.collision_mask
	q.exclude = [p.get_rid()]
	q.margin = 0.005
	if not space.intersect_shape(q, 1).is_empty(): return null
	return foot

## Pause-menu "Return to Town Hall entrance".
func return_to_entrance(reason := "api") -> Dictionary:
	if not _world_live():
		last_return = {"ok": false, "reason": "world not live"}
		return last_return
	var options = _options()
	if options != null and options.visible:
		if options.get("remaining") != null and float(options.remaining) > 0.0: options.revert_display()
		options.hide()
	_close_all_overlays()
	var p = world.player
	_force_stand(p)
	var foot = _clear_foot(ENTRANCE)
	var used := "entrance"
	if foot == null:
		foot = _clear_foot(FALLBACK)
		used = "login_spawn"
	if foot == null:
		last_return = {"ok": false, "reason": "Town Hall entrance and login spawn are both blocked"}
		if options != null and not options.visible: world.open_options()
		return last_return
	p.global_position = foot
	p.rotation = Vector3(0.0, ENTRANCE_YAW, 0.0)
	p.velocity = Vector3.ZERO
	p.pitch = -0.04
	p.camera.rotation = Vector3(p.pitch, 0.0, 0.0)
	p.step_view_offset = 0.0
	p.last_motion_position = Vector3.INF
	if p.has_method("update_eye_height"):
		p.visual_eye_height = p.STANDING_EYE
		p.update_eye_height(0)
	if p.has_method("update_camera_view"): p.update_camera_view()
	p.reset_physics_interpolation()
	if options != null: options.cancel_changes()
	if options != null and options.has_signal("closed"): options.closed.emit()
	p.enabled = true
	if world.get("cooking_window_focused") != false: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if world.has_method("message"): world.message("Back at the Town Hall entrance. The plaza is straight ahead.")
	last_return = {"ok": true, "used": used, "position": foot, "reason": reason}
	print("TOWN_HALL_RECOVERY return used=%s position=%s reason=%s" % [used, str(foot), reason])
	return last_return

func _do_quit() -> void:
	quits += 1
	if quit_handler.is_valid(): quit_handler.call()
	else: get_tree().quit()

func quit_now() -> void:
	print("TOWN_HALL_RECOVERY quit_now")
	_do_quit()

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST or world == null or not is_instance_valid(world): return
	var options = _options()
	var now := Time.get_ticks_msec()
	# The baseline opens Options with the quit prompt on the first request. A second request
	# while that prompt is still up means the player really wants out: save if possible, quit.
	if options != null and options.visible and options.get("quit_pending") == true and now - last_close_request_ms < CLOSE_REPEAT_MS:
		var saved := false
		if world.has_method("save_game") and world.get("world_initialized") == true:
			saved = world.save_game(false)
		print("TOWN_HALL_RECOVERY second close request: saved=%s, quitting" % saved)
		_do_quit()
		return
	last_close_request_ms = now

## Mouse capture safety net: no overlay open + focused window => player control restored.
func _process(_delta: float) -> void:
	var now_ms := Time.get_ticks_msec()
	if last_tick_ms >= 0: last_frame_ms = now_ms - last_tick_ms
	last_tick_ms = now_ms
	look_budget_px = Vector2.INF
	# Physics for this frame has run with any latched key down; let it go now.
	if not latched.is_empty(): _release_latched()
	if not _world_live():
		uncaptured_since_ms = -1
		return
	if not is_instance_valid(return_button) or not is_instance_valid(quit_now_button): inject_buttons()
	var p = world.player
	var headless := DisplayServer.get_name() == "headless"
	# Headless has no mouse capture to restore; only player control is checked there.
	var needs: bool = not p.enabled or (not headless and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	var blocked: bool = world.modal_open() or world.get("cooking_window_focused") == false or is_instance_valid(world.get("ship_selection"))
	if not headless and not DisplayServer.window_is_focused(): blocked = true
	if not needs or blocked:
		uncaptured_since_ms = -1
		return
	# Wall-clock grace (frames can be very slow on software renderers), and at least two
	# frames, so same-frame close/open sequences in the baseline are never interrupted.
	if uncaptured_since_ms < 0:
		uncaptured_since_ms = Time.get_ticks_msec(); uncaptured_frames = 0
		return
	uncaptured_frames += 1
	if Time.get_ticks_msec() - uncaptured_since_ms < int(RECAPTURE_GRACE_S * 1000.0) or uncaptured_frames < 2: return
	uncaptured_since_ms = -1
	recaptures += 1
	p.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
