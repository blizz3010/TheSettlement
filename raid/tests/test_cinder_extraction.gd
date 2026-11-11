extends SceneTree
## Real raid scene + production motion, isolated profile; no rendered/native proof.
const State=preload("res://raid/scripts/cinder_state.gd")
const STEP:=1.0/60.0
var checks:=0
var failures:Array=[]
var scene
var returns:=0

func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)

func _initialize():call_deferred("run")

func button(text:String):
	for item in scene.modal.find_children("*","Button",true,false):
		if item.text==text:item.pressed.emit();return
	check(false,"Button exists: "+text)

func extract(index:int)->Dictionary:
	for target in scene.targets:
		if target.kind=="extract" and target.poi.id=="extract%d"%index:return target
	return {}

func place(at:Vector2):
	scene.player.position=Vector3(at.x,scene.generator.height_at(at)+0.08,at.y)
	scene.player.velocity=Vector3.ZERO
	for i in 30:
		scene.player.step_motion(Vector3.ZERO,4.2,false,STEP)
		await physics_frame

func tick(frames:int):
	for i in frames:
		scene.player.step_motion(Vector3.ZERO,4.2,false,STEP)
		scene._physics_process(STEP)
		await physics_frame

func begin(index:int):
	scene._interact(extract(index))
	button("Start 8-second extraction")

func press(action:String):
	var event=InputEventKey.new();event.pressed=true
	var binding=InputMap.action_get_events(action)[0]
	event.physical_keycode=binding.physical_keycode;event.keycode=binding.keycode
	scene._unhandled_input(event)

func state_tests():
	var state=State.new(123)
	check(state.visit("caravan") and not state.visit("caravan"),"Discovery records once")
	check(not state.visit(""),"Empty discovery rejected")
	state.advance_active_time(15.0);state.advance_active_time(-1);state.advance_active_time(NAN)
	check(is_equal_approx(state.active_seconds,15.0),"Only finite positive active time counts")
	check(not state.start_extraction(""),"Empty extraction rejected")
	check(state.start_extraction("north"),"Extraction starts once")
	check(not state.start_extraction("east"),"Repeat/different start cannot replace active request")
	check(not state.advance_extraction(3.0,true) and state.extraction_seconds==3.0,"Partial countdown stays active")
	state.advance_extraction(NAN,true);state.advance_extraction(-2,true)
	check(state.extraction_seconds==3.0,"Invalid deltas cannot advance countdown")
	check(not state.advance_extraction(5.0,false) and state.extraction_id.is_empty() and state.extraction_seconds==0.0,"Eligibility loss cancels before completion")
	check(not state.cancel_extraction(),"Repeated cancellation is harmless")
	check(state.start_extraction("east"),"Fresh request after cancellation")
	check(not state.advance_extraction(7.99,true),"Cannot finish before eight seconds")
	check(state.advance_extraction(0.02,true) and state.extracted_at=="east","Eight seconds completes")
	check(not state.advance_extraction(8.0,true) and not state.start_extraction("north"),"Completed extraction cannot trigger again")
	state.advance_active_time(10);check(state.active_seconds==15.0,"Completion freezes active time")
	check(not state.visit("yard"),"Completion freezes discovery")
	state.searched["caravan"]=2
	var snapshot=state.summary();snapshot.searched["caravan"]=5;snapshot.visited.clear()
	check(state.searched.caravan==2 and state.visited.has("caravan"),"Result snapshot cannot mutate raid ledger")
	check(snapshot.preview_only and snapshot.seed==123,"Results explicitly disposable and seeded")
	var fresh=State.new(123)
	check(fresh.extracted_at.is_empty() and fresh.visited.is_empty() and fresh.active_seconds==0.0,"New raid resets all session progress")

func run():
	state_tests()
	scene=load("res://raid/cinder_basin.tscn").instantiate();root.add_child(scene)
	var deadline=Time.get_ticks_msec()+60000
	while not scene.is_raid_ready() and Time.get_ticks_msec()<deadline:await process_frame
	check(scene.is_raid_ready(),"Real generated scene ready")
	if not scene.is_raid_ready():scene.free();quit(1);return
	scene.set_physics_process(false);scene.player.set_physics_process(false)
	await place(scene.settings.EXTRACTS[0])
	check(scene._extraction_eligible(extract(0)),"North trail endpoint inside grounded extraction zone")
	scene._interact(extract(0));check(scene.modal.visible and scene.raid_state.extraction_id.is_empty(),"Beacon requires confirmation")
	button("Keep exploring");check(not scene.modal.visible and scene.player.enabled,"Confirmation cancel restores play without countdown")
	begin(0);check(scene.raid_state.extraction_id=="extract0" and scene.player.enabled and not scene.modal.visible,"Start keeps movement enabled")
	await tick(120)
	var partial=scene.raid_state.extraction_seconds
	check(absf(partial-2.0)<0.02 and scene.extraction_progress.visible,"Real scene counts physics seconds and displays progress")
	scene._begin_extraction(extract(0))
	check(scene.raid_state.extraction_seconds==partial,"Duplicate confirmation does not restart countdown")
	scene._interact(extract(0));check(scene.raid_state.extraction_id.is_empty() and not scene.extraction_progress.visible,"Interact cancels ongoing extraction")
	begin(0);scene.player.position.x+=10
	await tick(1)
	check(scene.raid_state.extraction_id.is_empty() and scene.raid_state.extracted_at.is_empty(),"Leaving physical zone cancels without extraction")
	await place(scene.settings.EXTRACTS[0])
	scene._interact(extract(0));scene.player.position.x+=10;button("Start 8-second extraction")
	check(scene.raid_state.extraction_id.is_empty() and not scene.modal.visible,"Stale confirmation rechecks live position")
	await place(scene.settings.EXTRACTS[0]);begin(0)
	scene.player.step_motion(Vector3.ZERO,4.2,true,STEP);scene._physics_process(STEP)
	check(not scene.player.is_on_floor() and scene.raid_state.extraction_id.is_empty(),"Jumping cancels countdown")
	await place(scene.settings.EXTRACTS[0]);begin(0);press("map")
	check(scene.map_panel.visible and scene.raid_state.extraction_id.is_empty() and not scene.player.enabled,"Map immediately cancels and disables movement")
	var paused_time=scene.raid_state.active_seconds;await tick(5)
	check(scene.raid_state.active_seconds==paused_time,"Map does not count active exploration time")
	scene._close_modal();begin(0);scene._field_notes()
	check(scene.modal.visible and scene.raid_state.extraction_id.is_empty(),"Field notes cancel countdown")
	scene._close_modal();begin(0);scene._pause_menu()
	check(scene.raid_state.extraction_id.is_empty(),"Pause cancels countdown")
	scene._close_modal();begin(0);scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(scene.modal.visible and not scene.player.enabled and scene.raid_state.extraction_id.is_empty(),"Focus loss pauses and cancels countdown")
	scene._close_modal()
	# Real region detection, cache state and map share the same disposable ledger.
	await place(scene.generator.pois[0].at+Vector2(0,8));await tick(1)
	check(scene.raid_state.visited.has("caravan"),"Entering POI records discovery")
	check(scene.map_panel.raid_state==scene.raid_state,"Map uses live discovery/cache ledger")
	for poi in scene.generator.pois:
		scene.raid_state.visit(poi.id);scene.raid_state.collect(poi);scene.raid_state.unlocked[poi.id]=true;scene.raid_state.search_cache(poi)
	# Programmatic bounds/layout assertions, not a rendered art or keyboard pass.
	for viewport_size in [Vector2i(1280,720),Vector2i(1440,900)]:
		root.size=viewport_size;root.content_scale_size=viewport_size
		check(root.get_visible_rect().size==Vector2(viewport_size),"Logical viewport matches bounds fixture %s"%viewport_size)
		for i in 2:
			scene._field_notes();await process_frame;await process_frame
			check(Rect2(Vector2.ZERO,Vector2(viewport_size)).encloses(scene.modal.get_global_rect()),"Full field notes fit viewport %s repeat %d"%[viewport_size,i])
			check(scene.modal.find_children("*","ScrollContainer",true,false).size()==1,"Field notes scroll overflow instead of expanding screen")
			scene._close_modal()
	await place(scene.settings.EXTRACTS[1]);check(scene._extraction_eligible(extract(1)),"East trail endpoint inside grounded extraction zone")
	begin(1);await tick(479)
	check(scene.raid_state.extracted_at.is_empty() and not scene.modal.visible,"Real scene cannot finish before eight seconds")
	await tick(2)
	check(scene.raid_state.extracted_at=="extract1" and scene.modal.visible and not scene.player.enabled,"Eight-second extraction opens results and disables movement")
	check(not scene.extraction_status.visible and not scene.extraction_progress.visible,"Completion removes countdown UI")
	check(scene._summary_text().contains("Visited 6/6") and scene._summary_text().contains("Caches 6/6"),"Result includes complete discovery/cache ledger")
	for viewport_size in [Vector2i(1280,720),Vector2i(1440,900)]:
		root.size=viewport_size;root.content_scale_size=viewport_size;await process_frame;await process_frame
		check(root.get_visible_rect().size==Vector2(viewport_size),"Result logical viewport matches bounds fixture %s"%viewport_size)
		check(Rect2(Vector2.ZERO,Vector2(viewport_size)).encloses(scene.modal.get_global_rect()),"Extraction results fit viewport %s"%viewport_size)
	var final_time=scene.raid_state.active_seconds
	scene._close_modal();press("map");scene._interact(extract(0));await tick(5)
	check(scene.modal.visible and not scene.player.enabled and scene.raid_state.active_seconds==final_time,"Completed result cannot reopen gameplay or advance session")
	scene.return_requested.connect(func():returns+=1)
	button("Return to settlement");scene._request_return()
	check(returns==1 and not scene.ready_for_play and not scene.player.enabled,"Repeated return emits exactly once")
	print("CINDER_EXTRACTION_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"rendered":false,"native_input":false,"save_io":false,"duration_seconds":State.EXTRACTION_DURATION,"summary":scene.raid_state.summary()}))
	scene.free();await preload("res://raid/tests/audio_shutdown.gd").drain(self);quit(0 if failures.is_empty() else 1)
