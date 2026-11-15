extends SceneTree
## Normal launch flow: project main_scene -> title -> Play -> mockup A character select
## (real character model) -> select + Enter emits the launch into the ship settlement.
## Disposable profile from the runner; the world itself is not activated here
## (test_ship_startup_contract covers the threaded production world).
const MAIN := "res://raid/play_title.tscn"
var failures: Array = []
var checks := 0
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _initialize(): call_deferred("run")

func inherits(script: Script, path: String) -> bool:
	while script != null:
		if script.resource_path == path: return true
		script = script.get_base_script()
	return false

func run():
	check(ProjectSettings.get_setting("application/run/main_scene") == MAIN, "main_scene is the play-flow title")
	var packed = load(MAIN)
	check(packed is PackedScene, "Play-flow title loads")
	var title = packed.instantiate()
	root.add_child(title); current_scene = title
	await process_frame
	check(inherits(title.get_script(), "res://raid/scripts/ship_title_preview.gd"), "Title layers on the ship title")
	check(inherits(title.get_script(), "res://scripts/title_menu.gd"), "Title keeps the shipped main menu")
	check(title.world_path == "res://raid/ship_settlement_preview.tscn", "Play leads into the ship settlement (raids via the spaceship)")
	check(not title.status.visible, "Preview banner hidden on normal launch")
	check(title.menu.visible and is_instance_valid(title.play_button), "Main menu with Play is shown first")
	title.play_button.pressed.emit()
	await process_frame
	var panel = title.character_panel
	check(is_instance_valid(panel), "Play opens character select")
	if not is_instance_valid(panel):
		await finish(title); return
	check(panel.get_script().resource_path == "res://raid/scripts/select_redesign_panel.gd" and panel.variant == "sidebar", "Character select is mockup A (sidebar)")
	check(not title.menu.visible, "Main menu hidden behind select")
	check(inherits(panel.preview.get_script(), "res://raid/scripts/character_model_stage.gd"), "Select stage is the real character model stage (PR #6)")
	check(panel.preview.get_script().resource_path == "res://raid/scripts/select_redesign_stage.gd", "Mockup A plinth stage")
	check(panel.back_requested.is_connected(title._close_characters), "Back returns to main menu")
	check(panel.launch_requested.is_connected(title._launch_character), "Enter launches into the world")
	var create_found := false
	for child in panel.body.get_children():
		if child is Button and str(child.text).contains("Create first character"): create_found = true
	check(create_found, "Fresh profile offers character creation")
	# Two settlers, as a returning player would have.
	var session = panel.session
	var state = session.inspect()
	var r1 = session.create_character("slot_1", {"name":"Settler","cheek":0.0,"hair":"hair_short02_v1","brows":"brow_009_v1","eyes":"eye_brown_v1","hair_tint":"natural"}, {"str":7,"int":7,"dex":7}, [], state.bytes, false)
	session.cancel()
	var r2 = session.create_character("slot_2", {"name":"Wren","cheek":0.6,"hair":"hair_bob01_v1","brows":"brow_001_v1","eyes":"eye_blue_v1","hair_tint":"copper"}, {"str":5,"int":11,"dex":9}, ["methodical","restless"], session.inspect().bytes, false)
	session.cancel()
	check(r1.get("ok", false) and r2.get("ok", false), "Disposable settlers created")
	panel.refresh()
	for i in 3: await process_frame
	check(panel.cards.has("slot_1") and panel.cards.has("slot_2"), "Sidebar lists both settlers")
	panel.cards["slot_2"].pressed.emit()
	await process_frame
	check(panel.selected_slot == "slot_2" and panel.preview_name.text == "Wren", "Clicking a card selects that settler")
	check(panel.slot_label.text.begins_with("Slot 2"), "Info card follows selection")
	check(panel.preview.visible and panel.preview.model_ok, "Real rig shown on the plinth")
	check(not panel.enter_button.disabled, "Enter enabled for a selected settler")
	var launched: Array = []
	panel.launch_requested.disconnect(title._launch_character)
	panel.launch_requested.connect(func(token, legacy, intro): launched.append([token, legacy, intro]))
	panel.enter_button.pressed.emit()
	await process_frame
	check(launched.size() == 1 and int(launched[0][0]) > 0 and launched[0][1] == false, "Enter confirms the selected settler for the settlement launch")
	await finish(title)

func finish(title):
	if is_instance_valid(title.character_panel):
		title.remove_child(title.character_panel); title.character_panel.free(); title.character_panel = null
	title.music.stop(); title.music.stream = null
	title.video.stop(); title.video.stream = null
	await create_timer(0.2).timeout
	title.queue_free(); current_scene = null
	await create_timer(0.2).timeout
	print("PLAY_FLOW_ENTRY_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "scope": "main_scene title, Play, mockup A select with real model, select + Enter launch signal; world activation covered elsewhere"}))
	quit(0 if failures.is_empty() else 1)
