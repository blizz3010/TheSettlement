extends SceneTree
## Reproduce delayed GUI signals across cancel/replacement in both real maps.
## Synthetic signals and headless geometry are not native input/rendered proof.
var checks:=0
var failures:Array=[]
var scene
var returns:=0
var cues:Array=[]

func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func button(text:String)->Button:
	for item in scene.modal.find_children("*","Button",true,false):
		if item.text==text:return item
	return null
func entry()->LineEdit:
	return scene.modal.find_children("*","LineEdit",true,false)[0]
func place(at:Vector2):
	scene.player.position=Vector3(at.x,scene.generator.height_at(at)+0.08,at.y)
	scene.player.velocity=Vector3.ZERO
	for i in 30:
		scene.player.step_motion(Vector3.ZERO,4.2,false,1.0/60.0)
		await physics_frame
func reset_lock(poi:Dictionary):
	scene.raid_state.unlocked.erase(poi.id)
func test_map(path:String):
	scene=load(path).instantiate();root.add_child(scene)
	var deadline=Time.get_ticks_msec()+60000
	while not scene.is_raid_ready() and Time.get_ticks_msec()<deadline:await process_frame
	var prefix=scene._map_name()+": "
	check(scene.is_raid_ready(),prefix+"real map ready")
	if not scene.is_raid_ready():scene.free();return
	scene.set_physics_process(false);scene.player.set_physics_process(false)
	cues.clear();scene.raid_audio.cue_played.connect(func(cue):cues.append(cue))
	var poi:Dictionary=scene.generator.pois.filter(func(p):return p.lock=="code")[0]
	var code=scene.raid_state.code_for(poi.id)
	scene._code_panel(poi);entry().text=code
	var old_unlock=button("Unlock")
	button("Cancel").pressed.emit();old_unlock.pressed.emit()
	check(not scene.raid_state.unlocked.has(poi.id),prefix+"cancelled code button cannot unlock")
	reset_lock(poi)
	scene._code_panel(poi);var old_entry=entry();old_entry.text=code
	scene._close_modal();old_entry.text_submitted.emit(code)
	check(not scene.raid_state.unlocked.has(poi.id),prefix+"cancelled text submission cannot unlock")
	reset_lock(poi)
	scene._code_panel(poi);old_entry=entry();old_entry.text=code
	scene._field_notes();old_entry.text_submitted.emit(code)
	check(not scene.raid_state.unlocked.has(poi.id) and scene.modal.visible,prefix+"replaced text submission cannot unlock or close notes")
	reset_lock(poi)
	scene._code_panel(poi);old_entry=entry();scene._close_modal()
	cues.clear();scene.raid_audio.last_played.clear();old_entry.text_changed.emit("1")
	check(not cues.has("keypad_press"),prefix+"cancelled text edits cannot play keypad cue")
	scene._code_panel(poi);old_entry=entry();scene._field_notes()
	cues.clear();scene.raid_audio.last_played.clear();old_entry.text_changed.emit("1")
	check(not cues.has("keypad_press"),prefix+"replaced text edits cannot play keypad cue")
	scene._field_notes();var old_close=button("Close")
	scene._code_panel(poi);old_close.pressed.emit()
	check(scene.modal.visible and scene.modal_content.get_child(0).text==poi.get("panel_name","Relay security panel"),prefix+"old close cannot dismiss replacement panel")
	scene._code_panel(poi);entry().text=code;old_unlock=button("Unlock")
	scene._field_notes();old_unlock.pressed.emit()
	check(not scene.raid_state.unlocked.has(poi.id),prefix+"replaced code panel cannot unlock")
	check(scene.modal.visible and scene.modal_content.get_child(0).text=="Field notes / raid-only kit",prefix+"replaced code panel cannot close newer notes")
	reset_lock(poi)
	# Normal live actions, including failed attempts and repeated opening, still work.
	for attempt in 2:
		scene._code_panel(poi);entry().text="x";button("Unlock").pressed.emit()
		check(scene.modal.visible and not scene.raid_state.unlocked.has(poi.id),prefix+"live wrong code stays open %d"%attempt)
		entry().text=code
		if attempt==0:entry().text_submitted.emit(code)
		else:button("Unlock").pressed.emit()
		check(scene.raid_state.unlocked.has(poi.id) and not scene.modal.visible and scene.player.enabled,prefix+"live correct code succeeds %d"%attempt)
		reset_lock(poi)
	var extract:Dictionary=scene.targets.filter(func(t):return t.kind=="extract")[0]
	await place(Vector2(extract.node.position.x,extract.node.position.z))
	check(scene._extraction_eligible(extract),prefix+"grounded at actual beacon")
	scene._extraction_panel(extract);var old_start=button("Start 8-second extraction")
	button("Keep exploring").pressed.emit();old_start.pressed.emit()
	check(scene.raid_state.extraction_id.is_empty(),prefix+"cancelled extraction cannot start later")
	scene._cancel_extraction()
	scene._extraction_panel(extract);old_start=button("Start 8-second extraction")
	scene._field_notes();old_start.pressed.emit()
	check(scene.raid_state.extraction_id.is_empty() and scene.modal.visible,prefix+"replaced extraction cannot start or dismiss notes")
	scene._cancel_extraction()
	scene._extraction_panel(extract);button("Start 8-second extraction").pressed.emit()
	check(scene.raid_state.extraction_id==extract.poi.id and scene.player.enabled,prefix+"live extraction starts normally")
	scene._cancel_extraction();scene._close_modal()
	var extracts=scene.targets.filter(func(t):return t.kind=="extract")
	if scene.map_panel.has_method("_extraction_markers"):
		var markers:Array=scene.map_panel._extraction_markers()
		check(markers.size()==extracts.size(),prefix+"map includes both real beacons")
		for target in extracts:
			var matching=markers.filter(func(m):return m.id==target.poi.id)
			check(matching.size()==1 and matching[0].position.is_equal_approx(Vector2(target.node.position.x,target.node.position.z)),prefix+"map marker matches actual beacon "+target.poi.id)
		var original:Vector3=extract.node.position;extract.node.position.x+=1.0
		var moved:Array=scene.map_panel._extraction_markers().filter(func(m):return m.id==extract.poi.id)
		check(moved.size()==1 and moved[0].position.is_equal_approx(Vector2(original.x+1.0,original.z)),prefix+"map follows generated beacon rather than config offset")
		extract.node.position=original
	else:check(false,prefix+"map has no actual-beacon marker source; uses offset route endpoints")
	# Last case because the unfixed implementation incorrectly starts return.
	scene.return_requested.connect(func():returns+=1)
	var previous_returns=returns
	scene._exit_panel("Leave preview?");var old_return=button("Return to settlement")
	button("Keep exploring").pressed.emit();old_return.pressed.emit()
	check(returns==previous_returns and not scene.returning and scene.ready_for_play,prefix+"cancelled leave cannot return later")
	if not scene.returning:
		scene._exit_panel("Leave preview?");button("Return to settlement").pressed.emit();old_return.pressed.emit()
		check(returns==previous_returns+1 and scene.returning,prefix+"live return emits exactly once")
	scene.free();await preload("res://raid/tests/audio_shutdown.gd").drain(self)
func run():
	for path in ["res://raid/relay_ridge.tscn","res://raid/cinder_basin.tscn"]:await test_map(path)
	print("RAID_UI_LIFECYCLE_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"rendered":false,"native_input":false,"save_io":false}))
	quit(0 if failures.is_empty() else 1)
