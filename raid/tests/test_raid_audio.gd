extends SceneTree
## Cue dispatch/import/lifecycle checks only; no audible mix or native-input claim.
const STEP:=1.0/60.0
var checks:=0
var failures:Array=[]
var events:Array=[]
var scene
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func count(cue:String)->int:return events.count(cue)
func valve_count()->int:
	return count("valve_turn_stop_1")+count("valve_turn_stop_2")+count("valve_turn_stop_3")
func valve_voices()->Array:
	return scene.raid_audio.voices.filter(func(voice):return voice.get_meta("raid_group","")=="valve")
func verify_valve_service():
	var service=scene.raid_audio
	service.stop_all();events.clear()
	for number in [1,2,3,1,1,2,3]:
		var previous=valve_voices()[0] if not valve_voices().is_empty() else null
		var at=Vector3(number,2.0,3.0)
		check(service.play_valve(number,at),"Valve service: accepted cosmetic variant "+str(number))
		check(events.back()=="valve_turn_stop_"+str(number) and valve_voices().size()==1,"Valve service: fixed variant and one active valve voice")
		var voice=valve_voices()[0]
		check(voice is AudioStreamPlayer3D and voice.global_position==at and is_equal_approx(voice.volume_db,-18.0) and voice.bus=="SFX","Valve service: positional SFX at conservative -18 dB")
		if previous!=null:check(previous.is_queued_for_deletion() and not previous.playing and previous.stream==null,"Valve service: replaced voice stops and releases stream")
	var event_count=events.size()
	check(not service.play_valve(0,Vector3.ZERO) and not service.play_valve(4,Vector3.ZERO) and not service.play_valve(1,Vector3.INF) and events.size()==event_count and valve_voices().size()==1,"Valve service: invalid variant/position is silent without stopping valid voice")
	service.play("valve_turn_stop_2",Vector3.ZERO,"other")
	check(valve_voices().size()==1 and service.voices.size()==1,"Valve service: direct cue cannot bypass one-voice group")
	service.play("key_unlock")
	service.stop_group("valve")
	check(valve_voices().is_empty() and service.voices.size()==1,"Valve service: stopping valve preserves unrelated feedback")
	service.suspend();event_count=events.size()
	check(not service.play_valve(1,Vector3.ZERO) and events.size()==event_count and service.voices.is_empty(),"Valve service: suspension stops voices and blocks new playback")
	service.resume();check(service.play_valve(3,Vector3.ZERO),"Valve service: resume accepts a fresh deliberate action")
	valve_voices()[0].finished.emit()
	check(valve_voices().is_empty(),"Valve service: finished one-shot disposes its voice")
	service.stop_all();events.clear()
func target(kind:String,id:String="")->Dictionary:
	for item in scene.targets:
		if item.kind==kind and (id.is_empty() or item.poi.id==id):return item
	return {}
func click(text:String):
	for item in scene.modal.find_children("*","Button",true,false):
		if item.text==text:item.pressed.emit();return
	check(false,"Audio test button exists: "+text)
func change(entry:LineEdit,value:String):
	scene.raid_audio.last_played.clear()
	entry.text=value;entry.text_changed.emit(value)
func place(at:Vector2):
	scene.player.position=Vector3(at.x,scene.generator.height_at(at)+0.08,at.y);scene.player.velocity=Vector3.ZERO
	for i in 30:
		scene.player.step_motion(Vector3.ZERO,4.2,false,STEP);await physics_frame
func run():
	var cue_names=["key_unlock","keycard_accepted","access_denied","keypad_press","heavy_door_open","relay_switch_click","puzzle_solved","beacon_activation","beacon_countdown_pulse","beacon_cancel","beacon_complete","valve_turn_stop_1","valve_turn_stop_2","valve_turn_stop_3"]
	for cue in cue_names:
		var stream=load("res://raid/audio/"+cue+".wav")
		check(stream is AudioStreamWAV and stream.format==AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate==44100 and not stream.stereo and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"Lossless mono PCM16 nonlooping asset: "+cue)
	var provenance=JSON.parse_string(FileAccess.get_file_as_string("res://raid/audio/SOURCE-PROVENANCE.json"))
	check(provenance.files.size()==cue_names.size(),"All fourteen original WAVs have provenance records")
	for record in provenance.files:
		check(FileAccess.get_sha256("res://raid/audio/"+record.file)==record.sha256,"Original source bytes match provenance: "+record.file)
	for map_id in ["relay_ridge","cinder_basin"]:
		events.clear()
		scene=load("res://raid/"+map_id+".tscn").instantiate();root.add_child(scene)
		var deadline=Time.get_ticks_msec()+60000
		while not scene.is_raid_ready() and Time.get_ticks_msec()<deadline:await process_frame
		check(scene.is_raid_ready(),map_id+": real scene ready with audio")
		if not scene.is_raid_ready():scene.free();continue
		scene.set_physics_process(false);scene.player.set_physics_process(false)
		scene.raid_audio.cue_played.connect(func(cue):events.append(cue))
		check(scene.raid_audio.streams.size()==13 and not scene.raid_audio.streams.has("heavy_door_open"),map_id+": thirteen available cues; unsynchronised door motion reserved")
		var bus=AudioServer.get_bus_index("SFX")
		var previous_volume=AudioServer.get_bus_volume_db(bus);var previous_mute=AudioServer.is_bus_mute(bus)
		AudioServer.set_bus_volume_db(bus,-7.5);AudioServer.set_bus_mute(bus,true)
		if map_id=="cinder_basin":verify_valve_service()
		for lock_type in ["key","keycard"]:
			var poi=scene.generator.pois.filter(func(p):return p.lock==lock_type)[0]
			var door=target("door",poi.id)
			scene.raid_audio.last_played.clear();var denied=count("access_denied")
			scene._interact(door);scene._interact(door)
			check(count("access_denied")==denied+1,map_id+": missing "+lock_type+" denied once under rapid repeat")
			scene.raid_state.collect(poi)
			var cue="key_unlock" if lock_type=="key" else "keycard_accepted";var before=count(cue)
			scene._interact(door);scene._interact(door)
			check(count(cue)==before+1,map_id+": "+lock_type+" success sound only on locked-to-unlocked transition")
		var code_poi=scene.generator.pois.filter(func(p):return p.lock=="code")[0]
		scene._code_panel(code_poi);var entry=scene.modal.find_children("*","LineEdit",true,false)[0]
		var before=count("keypad_press");change(entry,"1")
		check(count("keypad_press")==before+1,map_id+": accepted digit gets one cue")
		change(entry,"");change(entry,"x");check(count("keypad_press")==before+1,map_id+": deletion and nondigit are silent")
		change(entry,"1234");check(count("keypad_press")==before+2,map_id+": paste is one cue rather than four overlapping voices")
		entry.text="%04d"%((int(scene.raid_state.code_for(code_poi.id))+1)%10000)
		scene.raid_audio.last_played.clear();var denied=count("access_denied");click("Unlock");click("Unlock")
		check(count("access_denied")==denied+1 and scene.modal.visible,map_id+": rejected code dispatch bounded feedback and stays open")
		entry.text=scene.raid_state.code_for(code_poi.id);click("Unlock")
		check(not scene.modal.visible and scene.raid_state.unlocked.get(code_poi.id,false),map_id+": correct code opens without spurious card cue")
		var sequence=[2,1,3] if map_id=="relay_ridge" else [3,1,2]
		for number in sequence:
			for item in scene.targets:
				if item.kind=="switch" and item.number==number:scene._interact(item)
		scene._interact(target("switch"));scene._interact(target("switch"))
		if map_id=="relay_ridge":
			check(count("puzzle_solved")==1 and count("relay_switch_click")==5 and valve_count()==0,map_id+": solved cue only at transition; Relay keeps electrical clicks")
		else:
			check(count("puzzle_solved")==1 and count("relay_switch_click")==0 and valve_count()==5,map_id+": solved cue only at transition; Cinder uses mechanical valves")
			check(count("valve_turn_stop_1")==3 and count("valve_turn_stop_2")==1 and count("valve_turn_stop_3")==1 and valve_voices().size()==1,map_id+": stable per-valve variants and rapid input cannot stack mechanical voices")
			# The puzzle changes immediately even while prior audio is active or muted.
			var saved_stream=scene.raid_audio.streams["valve_turn_stop_3"]
			scene.raid_audio.streams.erase("valve_turn_stop_3");scene.raid_state.switch_step=0
			for item in scene.targets:
				if item.kind=="switch" and item.number==3:scene._interact(item)
			check(scene.raid_state.switch_step==1 and count("puzzle_solved")==1,map_id+": missing audio does not block authoritative puzzle input")
			scene.raid_audio.streams["valve_turn_stop_3"]=saved_stream
			scene.raid_state.switch_step=3
		await place(scene.settings.EXTRACTS[0]);var beacon=target("extract")
		scene._interact(beacon);scene._begin_extraction(beacon);scene._begin_extraction(beacon)
		check(count("beacon_activation")==1,map_id+": duplicate extraction start stays silent")
		scene._physics_process(1.1);check(count("beacon_countdown_pulse")==0,map_id+": activation has room before countdown pulses")
		scene._physics_process(1.0);check(count("beacon_countdown_pulse")==1,map_id+": authoritative second crossing emits pulse")
		scene._physics_process(2.5);check(count("beacon_countdown_pulse")==2,map_id+": long frame emits one pulse, not missed-second burst")
		scene._interact(beacon);scene._cancel_extraction("Repeated cancel")
		check(count("beacon_cancel")==1 and scene.raid_state.extraction_id.is_empty(),map_id+": explicit cancellation sounds once")
		check(scene.raid_audio.voices.all(func(voice):return voice.get_meta("raid_group","")!="extraction"),map_id+": cancellation stops active extraction voices")
		scene._interact(beacon);scene._begin_extraction(beacon)
		var event_count=events.size();scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(events.size()==event_count and scene.raid_audio.suspended and scene.raid_audio.voices.is_empty(),map_id+": focus loss stops all audio without cancel chirp")
		scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);scene._close_modal()
		check(not scene.raid_audio.suspended and scene.raid_state.extraction_id.is_empty(),map_id+": focus return does not restart countdown")
		scene._interact(beacon);scene._begin_extraction(beacon)
		var pulses=count("beacon_countdown_pulse");var cancels=count("beacon_cancel")
		scene._physics_process(8.0);scene._physics_process(1.0)
		check(count("beacon_complete")==1 and count("beacon_countdown_pulse")==pulses and count("beacon_cancel")==cancels,map_id+": completion once, no last pulse or phantom cancel")
		for i in 30:scene.raid_audio.play("relay_switch_click")
		check(scene.raid_audio.voices.size()<=scene.raid_audio.MAX_VOICES,map_id+": rapid feedback voice count remains bounded")
		check(AudioServer.is_bus_mute(bus) and is_equal_approx(AudioServer.get_bus_volume_db(bus),-7.5),map_id+": saved SFX volume/mute not changed by playback")
		scene.return_requested.connect(func():pass);scene._request_return()
		check(scene.raid_audio.voices.is_empty(),map_id+": return stops every voice")
		AudioServer.set_bus_volume_db(bus,previous_volume);AudioServer.set_bus_mute(bus,previous_mute)
		scene.free();await preload("res://raid/tests/audio_shutdown.gd").drain(self)
	print("RAID_AUDIO_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"maps":2,"imported_cues":14,"wired_cues":13,"valve_voice_limit":1,"valve_gain_db":-18,"audible_acceptance":false,"native_input":false,"rendered":false}))
	quit(0 if failures.is_empty() else 1)
