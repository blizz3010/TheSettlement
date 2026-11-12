extends Node
## Raid-local feedback only. Never changes saved bus volume/mute or settlement audio.
signal cue_played(cue:String)
const MAX_VOICES:=8
const VALVE_CUES:=["valve_turn_stop_1","valve_turn_stop_2","valve_turn_stop_3"]
const VALVE_GROUP:="valve"
const CUES={
	"key_unlock":-14.0,"keycard_accepted":-14.0,"access_denied":-14.0,
	"keypad_press":-14.0,"relay_switch_click":-14.0,"puzzle_solved":-14.0,
	"beacon_activation":-14.0,"beacon_countdown_pulse":-18.0,
	"beacon_cancel":-14.0,"beacon_complete":-14.0,
	"valve_turn_stop_1":-18.0,"valve_turn_stop_2":-18.0,"valve_turn_stop_3":-18.0,
}
var streams:Dictionary={}
var voices:Array=[]
var suspended:=false
var last_played:Dictionary={}
func _ready():
	for cue in CUES:
		var stream=load("res://raid/audio/"+cue+".wav")
		if stream is AudioStreamWAV:streams[cue]=stream
		else:push_warning("Raid audio unavailable: "+cue)
func play_valve(number:int,position:Vector3)->bool:
	# Stable cosmetic assignment, independent of procedural RNG and puzzle state.
	if number<1 or number>VALVE_CUES.size() or not position.is_finite():return false
	return play(VALVE_CUES[number-1],position,VALVE_GROUP)
func play(cue:String,position:Vector3=Vector3.INF,group:String="feedback")->bool:
	if suspended or not streams.has(cue) or AudioServer.get_bus_index("SFX")<0:return false
	# Bound rapid repeated denial/key feedback without changing gameplay state.
	var now=Time.get_ticks_msec()
	if cue in ["access_denied","keypad_press"] and now-int(last_played.get(cue,-1000))<80:return false
	last_played[cue]=now
	# Valve clips last over a second. New actions replace the old mechanical
	# voice, even across valves; never delay or suppress authoritative inputs.
	if cue in VALVE_CUES:
		group=VALVE_GROUP
		stop_group(VALVE_GROUP)
	voices=voices.filter(func(voice):return is_instance_valid(voice) and not voice.is_queued_for_deletion())
	while voices.size()>=MAX_VOICES:_dispose(voices[0])
	var voice=AudioStreamPlayer3D.new() if position.is_finite() else AudioStreamPlayer.new()
	voice.bus="SFX";voice.stream=streams[cue];voice.volume_db=CUES[cue];voice.set_meta("raid_group",group)
	if voice is AudioStreamPlayer3D:
		voice.max_distance=28.0;voice.unit_size=3.0;voice.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(voice)
	if voice is AudioStreamPlayer3D:voice.global_position=position
	voices.append(voice)
	voice.finished.connect(func():_dispose(voice))
	voice.play();cue_played.emit(cue)
	return true
func _dispose(voice:Node):
	voices.erase(voice)
	if is_instance_valid(voice):
		voice.stop()
		voice.stream=null
		voice.queue_free()
func stop_group(group:String):
	for voice in voices.duplicate():
		if is_instance_valid(voice) and voice.get_meta("raid_group","")==group:_dispose(voice)
func stop_all():
	for voice in voices.duplicate():_dispose(voice)
func suspend():
	suspended=true;stop_all()
func resume():suspended=false
func _exit_tree():
	suspended=true
	stop_all()
	streams.clear()
