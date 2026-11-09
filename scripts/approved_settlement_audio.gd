extends Node3D
# Approved source audio; scene-local, read-only presentation. No save or gameplay writes.
const ROOT = "res://assets/audio/approved_v098/"
const UI = ["button_click","cancel","confirm_buy","fish_bite","item_pickup","menu_close","menu_open","splash"]
const WORK = ["griddle_sizzle","hammering","loom_sewing","coin_counting"]
const PRIORITY = {"button_click":0,"menu_close":1,"menu_open":2,"cancel":3,"item_pickup":4,"confirm_buy":4,"fish_bite":5}
const Lake = preload("res://scripts/inn_lake_v088.gd")
var host: Node
var cache := {}
var ui_voices: Array[AudioStreamPlayer] = []
var ui_index := 0
var pending := ""
var flush_scheduled := false
var focused := true
var disposing := false
var configured := false
var environment_voices := {}
var work_voices := {}
var spatial_oneshots: Array[AudioStreamPlayer3D] = []
var scan_wait := 0.0
var cue_counts := {} # Bounded counters aid event regression tests without recording user data.
var last_cue_msec := {}
var bound_controls := {}
var bound_panels := {}
var work_owners := {}

static func service_for(node: Node) -> Node:
	var current = node
	while is_instance_valid(current):
		if current.has_meta("approved_audio_service"):
			var service = current.get_meta("approved_audio_service")
			if is_instance_valid(service): return service
		current = current.get_parent()
	return null
static func emit_for(node: Node, cue: String) -> void:
	var service = service_for(node)
	if service != null: service.queue_cue(cue)
static func emit_at(node: Node, cue: String, at: Vector3) -> void:
	var service = service_for(node)
	if service != null: service.play_at(cue,at)

func setup(world: Node) -> void:
	if configured: return
	configured = true; host = world; name = "ApprovedSettlementAudio"
	host.set_meta("approved_audio_service",self)
	# Normally created by Settings / existing environmental audio. Standalone
	# hosts create missing buses only; never reset a saved gain, mute or effect.
	for bus in ["SFX","Music","Ambience"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index = AudioServer.bus_count-1
			AudioServer.set_bus_name(index,bus)
			AudioServer.set_bus_send(index,"SFX" if bus=="Ambience" else "Master")
	for _i in range(4):
		var voice = AudioStreamPlayer.new()
		voice.bus = "SFX"; voice.volume_db = -14.0
		add_child(voice); ui_voices.append(voice)
	for _i in range(3):
		var voice = AudioStreamPlayer3D.new()
		voice.bus = "SFX"; voice.volume_db = -12.0; voice.max_db = -12.0
		voice.max_distance = 18.0; voice.unit_size = 2.0
		add_child(voice); spatial_oneshots.append(voice)
	bind_subtree(host)
	get_tree().node_added.connect(on_node_added)

func active() -> bool:
	if disposing or not focused or not is_inside_tree() or not is_instance_valid(host) or host.is_queued_for_deletion(): return false
	if not host.get("world_initialized") or host.get("startup_cancel_requested"): return false
	if host.get("staged_startup") and not host.get("world_activated"): return false
	return true

func stream(relative: String, looping := false) -> AudioStream:
	var key = relative + (":loop" if looping else ":once")
	if cache.has(key): return cache[key]
	var source = load(ROOT+relative) as AudioStream
	if source == null: return null
	var resource = source.duplicate() as AudioStream
	if resource is AudioStreamOggVorbis:
		resource.loop = looping; resource.loop_offset = 0.0
	elif resource is AudioStreamWAV:
		resource.loop_mode = AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
		resource.loop_begin = 0; resource.loop_end = int(resource.get_length()*resource.mix_rate)
	cache[key] = resource
	return resource

func queue_cue(cue: String) -> void:
	if not active() or not PRIORITY.has(cue): return
	if pending.is_empty() or PRIORITY[cue] >= PRIORITY[pending]: pending = cue
	if not flush_scheduled:
		flush_scheduled = true
		flush_cue.call_deferred()

func flush_cue() -> void:
	flush_scheduled = false
	var cue = pending; pending = ""
	if cue.is_empty() or not active() or ui_voices.is_empty(): return
	var now = Time.get_ticks_msec()
	# Short repeat protection, not a long UI cooldown that hides deliberate actions.
	if now-int(last_cue_msec.get(cue,-1000)) < 45: return
	last_cue_msec[cue] = now
	var voice = ui_voices[ui_index]; ui_index = (ui_index+1)%ui_voices.size()
	voice.stream = stream("ui/"+cue+".wav")
	voice.play()
	cue_counts[cue] = int(cue_counts.get(cue,0))+1

func play_at(cue: String, at: Vector3) -> void:
	if not active() or cue != "splash" or not at.is_finite(): return
	for voice in spatial_oneshots:
		if not voice.playing:
			voice.global_position = at; voice.stream = stream("ui/splash.wav"); voice.play()
			cue_counts[cue] = int(cue_counts.get(cue,0))+1
			return

func on_node_added(node: Node) -> void:
	if is_instance_valid(host) and host.is_ancestor_of(node): bind_by_id.call_deferred(node.get_instance_id())
func bind_by_id(id: int) -> void:
	if is_instance_id_valid(id): bind_node(instance_from_id(id))
func bind_subtree(node: Node) -> void:
	bind_node(node)
	for child in node.get_children(): bind_subtree(child)
func bind_node(node: Node) -> void:
	if disposing or not is_instance_valid(node) or node.is_queued_for_deletion() or not is_instance_valid(host) or not host.is_ancestor_of(node): return
	var id = node.get_instance_id()
	if node is BaseButton and not bound_controls.has(id):
		bound_controls[id] = weakref(node)
		node.pressed.connect(on_button_pressed.bind(node))
		node.tree_exiting.connect(func():bound_controls.erase(id))
	if node is Control and node.has_signal("closed") and not bound_panels.has(id):
		bound_panels[id] = node.visible
		node.visibility_changed.connect(on_panel_visibility.bind(node))
		node.tree_exiting.connect(func():bound_panels.erase(id))
		if node.has_signal("cancelled"): node.connect("cancelled",func():queue_cue("cancel"))

func on_button_pressed(button: BaseButton) -> void:
	# Confirmation and visibility callbacks run first; deferred arbitration keeps
	# one meaningful cue rather than button+open+confirm stacked in the same action.
	if is_instance_valid(button) and not button.disabled and button.is_visible_in_tree(): queue_cue("button_click")
func on_panel_visibility(panel: Control) -> void:
	if not is_instance_valid(panel): return
	var id = panel.get_instance_id()
	var before = bool(bound_panels.get(id,panel.visible))
	bound_panels[id] = panel.visible
	if before != panel.visible: queue_cue("menu_open" if panel.visible else "menu_close")

func make_emitter(relative: String, at: Vector3, gain: float, reach: float, looping := true) -> AudioStreamPlayer3D:
	var voice = AudioStreamPlayer3D.new()
	voice.bus = "Ambience"; voice.volume_db = gain; voice.max_db = gain
	voice.max_distance = reach; voice.unit_size = 2.0
	voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voice.stream = stream(relative,looping)
	add_child(voice); voice.global_position = at
	return voice

# Ongoing work requires an actual activity owner/state. No callers manufacture
# hammering, weaving, coin counting or cooking merely because a shop exists.
func set_work_active(kind: String, owner: Node3D, running: bool) -> bool:
	if not kind in WORK: return false
	if not running:
		if work_voices.has(kind): work_voices[kind].stop()
		work_owners.erase(kind); return true
	if not active() or not is_instance_valid(owner) or not host.is_ancestor_of(owner) or not owner.is_inside_tree() or owner.is_queued_for_deletion(): return false
	if not owner.has_meta("audio_work_active") or owner.get_meta("audio_work_active") != kind: return false
	if not work_voices.has(kind):
		work_voices[kind] = make_emitter("work/"+kind+".ogg",owner.global_position,-21.0,9.0)
	work_owners[kind] = weakref(owner)
	var voice: AudioStreamPlayer3D = work_voices[kind]
	voice.global_position = owner.global_position
	if not voice.playing: voice.play()
	return true

func sync_environment() -> void:
	var player = host.get("player")
	if not is_instance_valid(player) or not player is Node3D: return
	var lake_root = host.get_node_or_null("InnLakesideV088")
	var inn = host.get_node_or_null("SettlementInnExpansion/Inn")
	if is_instance_valid(lake_root) and lake_root.has_node("BroadExteriorLake"):
		var at: Vector3 = player.global_position
		# Actual published ellipse. Closest boundary sample, never the camera itself.
		var closest = Vector3.ZERO; var best = INF
		for i in range(192):
			var angle = TAU*float(i)/192.0
			var candidate = Vector3(Lake.CENTER.x+Lake.RADII.x*cos(angle),Lake.WATER_Y,Lake.CENTER.y+Lake.RADII.y*sin(angle))
			var distance = at.distance_squared_to(candidate)
			if distance < best: best = distance; closest = candidate
		sync_ambient("lake","ambience/lake_water_lapping.ogg",closest,-17.0,22.0)
	else: stop_environment("lake")
	if is_instance_valid(inn):
		sync_ambient("inn","ambience/inn_crowd_muffled.ogg",inn.to_global(Vector3(0,1.3,0)),-22.0,16.0)
	else: stop_environment("inn")

func sync_ambient(key: String, relative: String, at: Vector3, gain: float, reach: float) -> void:
	if not environment_voices.has(key):
		environment_voices[key] = make_emitter(relative,at,gain,reach)
	var voice: AudioStreamPlayer3D = environment_voices[key]
	voice.global_position = at
	if not voice.playing: voice.play()
func stop_environment(key: String) -> void:
	if environment_voices.has(key): environment_voices[key].stop()

func _process(delta: float) -> void:
	if not active():
		pending = ""
		for voice in environment_voices.values()+work_voices.values(): voice.stop()
		return
	for kind in work_owners.keys():
		var owner = work_owners[kind].get_ref()
		if not is_instance_valid(owner) or not owner.is_inside_tree() or owner.is_queued_for_deletion() or owner.get_meta("audio_work_active","") != kind:
			set_work_active(kind,null,false)
		else: work_voices[kind].global_position = owner.global_position
	scan_wait -= delta
	if scan_wait <= 0:
		scan_wait = .5; sync_environment()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false; stop_all()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: focused = true
func stop_all() -> void:
	pending = ""
	for voice in ui_voices+spatial_oneshots+environment_voices.values()+work_voices.values():
		if is_instance_valid(voice): voice.stop()
	# Require a new genuine activity signal after suspension.
	work_owners.clear()
func _exit_tree() -> void:
	disposing = true; stop_all()
	for voice in ui_voices+spatial_oneshots+environment_voices.values()+work_voices.values():
		if is_instance_valid(voice): voice.stream = null
	if is_instance_valid(host) and host.get_meta("approved_audio_service",null) == self: host.remove_meta("approved_audio_service")
	if get_tree().node_added.is_connected(on_node_added): get_tree().node_added.disconnect(on_node_added)
	cache.clear(); bound_controls.clear(); bound_panels.clear()
