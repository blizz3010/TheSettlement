extends Node
## TASKS item 13: loot cues, one file per sound (raid/audio/loot). Kept separate from
## raid_audio.gd so its cue contract is unchanged. SFX bus, never edits bus volume.
signal cue_played(cue: String)
const CUES := {"loot_cache_open": -16.0, "loot_pickup": -16.0, "loot_drop": -16.0}
const MAX_VOICES := 4
var streams: Dictionary = {}
var voices: Array = []

func _ready() -> void:
	for cue in CUES:
		var path := "res://raid/audio/loot/%s.wav" % cue
		var stream = load(path) if ResourceLoader.exists(path) else null
		if stream is AudioStreamWAV: streams[cue] = stream
		else: push_warning("Raid loot audio unavailable: " + cue)

func play(cue: String, position: Vector3 = Vector3.INF) -> bool:
	if not streams.has(cue) or AudioServer.get_bus_index("SFX") < 0: return false
	voices = voices.filter(func(v): return is_instance_valid(v) and not v.is_queued_for_deletion())
	while voices.size() >= MAX_VOICES: _dispose(voices[0])
	var voice = AudioStreamPlayer3D.new() if position.is_finite() else AudioStreamPlayer.new()
	voice.bus = "SFX"; voice.stream = streams[cue]; voice.volume_db = CUES[cue]
	if voice is AudioStreamPlayer3D:
		voice.max_distance = 28.0; voice.unit_size = 3.0
	add_child(voice)
	if voice is AudioStreamPlayer3D: voice.global_position = position
	voices.append(voice)
	voice.finished.connect(func(): _dispose(voice))
	voice.play(); cue_played.emit(cue)
	return true

func _dispose(voice: Node) -> void:
	voices.erase(voice)
	if is_instance_valid(voice):
		voice.stop(); voice.stream = null; voice.queue_free()

func _exit_tree() -> void:
	for v in voices.duplicate(): _dispose(v)
	streams.clear()
