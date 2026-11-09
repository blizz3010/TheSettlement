extends Node3D
# Approved restrained audio successor. Environmental contrast never filters footsteps/UI.
const Terrain = preload("res://scripts/settlement_terrain.gd")
const Layout = preload("res://scripts/plot_layout.gd")
const SURFACES = ["stone", "wood", "metal", "grass", "dirt"]
var player: CharacterBody3D
var fountain: AudioStreamPlayer3D
var wind: AudioStreamPlayer
var birds: Array[AudioStreamPlayer3D] = []
var step: AudioStreamPlayer
var rng := RandomNumberGenerator.new()
var bird_wait := 24.0
var music: AudioStreamPlayer
var stream_water: AudioStreamPlayer3D
var waterfall_voices: Array[AudioStreamPlayer3D] = []
var lowpass: AudioEffectLowPassFilter
var ambient_bus := -1
var music_wait := 80.0
var music_age := 0.0
var interior_blend := 0.0
var current_zone := "natural"
var started := false
var configured := false
var habitat: Array[Node3D] = []
var distance_walked := 0.0
var last_position := Vector3.ZERO
var last_variant := -1
var step_count := 0
var last_surface := ""
var streams := {}
func stream(file: String, looping := false) -> AudioStream:
	var key = file + (":loop" if looping else ":once")
	if streams.has(key): return streams[key]
	var path = "res://assets/audio/"+file
	if path.get_extension().is_empty(): path += ".wav"
	var source = load(path) as AudioStream
	if source == null: return null
	var resource = source.duplicate() as AudioStream
	if resource is AudioStreamWAV:
		resource.loop_mode = AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
		resource.loop_begin = 0
		resource.loop_end = int(resource.get_length()*resource.mix_rate)
	elif resource is AudioStreamOggVorbis:
		resource.loop = looping
		resource.loop_offset = 0.0
	streams[key] = resource
	return resource
func setup(actor: CharacterBody3D):
	if configured: return # Repeated readiness/input must not duplicate voices.
	configured = true
	player = actor
	configure_ambient_bus()
	last_position = player.global_position
	rng.randomize()
	wind = AudioStreamPlayer.new()
	wind.name = "WindRustleBed"; wind.bus = "Ambience"; wind.volume_db = -24
	wind.stream = stream("wind_rustle",true); add_child(wind)
	fountain = emitter("FountainWater",Vector3(0,1.1,0),"fountain",-9,30,true)
	fountain.unit_size = 3.0
	# Attach calls to actual visible songbirds, not invented canopy positions.
	var wildlife = get_parent().get_node_or_null("AmbientWildlife")
	if wildlife != null:
		for animal in wildlife.animals:
			if animal.kind == "bird":
				habitat.append(animal.root)
				birds.append(emitter("HabitatBird",animal.root.global_position,"bird_0",-18,16,false))
	stream_water = emitter("NorthernStreamWater",Vector3.ZERO,"fountain",-19,16,true)
	var valley = get_parent().get_node_or_null("RuinedValley")
	if valley != null:
		for fall in valley.falls:
			# Physical scenic waterfall remains inaudible in town; no fake local roar.
			waterfall_voices.append(emitter("DistantWaterfall",fall.foot,"fountain",-12,48,true))
	music = AudioStreamPlayer.new(); music.name = "IntermittentOriginalMusic"; music.bus = "Music"
	music.stream = stream("settlement_menu_calm"); music.volume_db = -60; add_child(music)
	step = AudioStreamPlayer.new(); step.name = "LocalFootsteps"; step.bus = "SFX"
	step.volume_db = -6; add_child(step)
	var approved = preload("res://scripts/approved_settlement_audio.gd").new()
	add_child(approved); approved.setup(get_parent())
func emitter(title: String, at: Vector3, file: String, gain: float, reach: float, looping: bool) -> AudioStreamPlayer3D:
	var result = AudioStreamPlayer3D.new()
	result.name = title; result.bus = "Ambience"; result.position = at
	result.volume_db = gain; result.max_db = gain; result.max_distance = reach
	result.unit_size = 2.0; result.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	result.stream = stream(file,looping); add_child(result)
	result.set_meta("ambient_loop",looping)
	return result
func _physics_process(delta: float):
	if not is_instance_valid(player): return
	if not world_ready(): return
	if not started:
		started = true; wind.play(); fountain.play(); stream_water.play()
		for voice in waterfall_voices: voice.play()
	advance_ambience(delta)
	var current = player.global_position
	var travelled = Vector2(current.x-last_position.x,current.z-last_position.z).length()
	last_position = current
	advance_steps(travelled,delta,player.is_on_floor(),player.controls_active())
func advance_steps(travelled: float, delta: float, grounded: bool, active: bool):
	# Reject teleport/reset, air, blocked motion and UI input; no key-repeat driven sound.
	if not active or not grounded or travelled < .001 or travelled > .6:
		distance_walked = 0.0
		if is_instance_valid(step): step.stop()
		return
	distance_walked += travelled
	var sprinting = travelled/maxf(delta,.001) > 5.2
	var stride = 2.25 if sprinting else 1.7
	if distance_walked < stride: return
	distance_walked = fmod(distance_walked,stride)
	var hit = support_hit()
	if hit.is_empty(): return
	last_surface = surface_for(hit.collider,hit.position)
	var variant = rng.randi_range(0,2)
	if variant >= last_variant: variant += 1
	last_variant = variant
	step.stream = stream("step_%s_%d" % [last_surface,variant])
	step.pitch_scale = rng.randf_range(.94,1.06)
	step.volume_db = -4 if sprinting else -7
	step.play(); step_count += 1
func support_hit() -> Dictionary:
	var query = PhysicsRayQueryParameters3D.create(player.global_position+Vector3(0,.16,0),player.global_position-Vector3(0,.32,0))
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)
static func surface_for(body: Object, point: Vector3) -> String:
	if body.has_meta("audio_ground_regions"):
		var planar=Vector2(point.x,point.z)
		if body.has_meta('market_paving_polygons'):
			# Exact post-trim authored slab/join/apron footprint, no phantom endpoint caps.
			for polygon in body.get_meta('market_paving_polygons'):
				if Geometry2D.is_point_in_polygon(planar,polygon):return 'stone'
		else:
			for path in body.get_meta('market_paving_paths',[]):
				for i in range(path.size()-1):
					var a=Vector2(path[i].x,path[i].z);var b=Vector2(path[i+1].x,path[i+1].z)
					if planar.distance_to(Geometry2D.get_closest_point_to_segment(planar,a,b))<=2.1:return 'stone'
			for apron in body.get_meta('market_paving_aprons',[]):
				if apron.has_point(planar):return 'stone'
		# Paving is art on this same physical ground, not extra invisible collision.
		if Vector2(point.x,point.z).length() <= 10 or (absf(point.x)<=3.5 and point.z>=-21 and point.z<=-3) or (point.x>=-24 and point.x<=0 and absf(point.z+4)<=2.5): return "stone"
		return "grass"
	return str(body.get_meta("audio_surface","stone"))
func _exit_tree():
	# Release looping playback explicitly when changing scenes or closing the world.
	for voice in [wind,fountain,step,music,stream_water]+birds+waterfall_voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	streams.clear()

func configure_ambient_bus():
	ambient_bus = AudioServer.get_bus_index("Ambience")
	if ambient_bus < 0:
		AudioServer.add_bus(); ambient_bus = AudioServer.bus_count-1
		AudioServer.set_bus_name(ambient_bus,"Ambience")
	AudioServer.set_bus_send(ambient_bus,"SFX")
	# One reusable effect across scene restarts, never stacking additional layers.
	for i in AudioServer.get_bus_effect_count(ambient_bus):
		if AudioServer.get_bus_effect(ambient_bus,i) is AudioEffectLowPassFilter:
			lowpass = AudioServer.get_bus_effect(ambient_bus,i)
	if lowpass == null:
		lowpass = AudioEffectLowPassFilter.new(); AudioServer.add_bus_effect(ambient_bus,lowpass)
	lowpass.cutoff_hz = 18000
	AudioServer.set_bus_volume_db(ambient_bus,0)

func world_ready() -> bool:
	var world = get_parent()
	# Loading successor sets activation only after ready/frame presentation; no media edits.
	if world.has_method("activate_loaded_world") and world.staged_startup:
		return world.world_activated and not world.startup_cancel_requested
	return bool(world.get_meta("world_ready",true))

static func hall_interior(at: Vector3) -> float:
	if at.y < -4 or at.y > 8: return 0.0
	var edge = minf(8.6-absf(at.x),minf(at.z+31.6,-14.0-at.z))
	return smoothstep(-0.4,1.4,edge)

func zone_at(at: Vector3) -> String:
	var pieces = get_parent().get_node_or_null("Pieces")
	# Existing furniture holder may be unnamed; obtain the authoritative scene field.
	if get_parent().get("pieces") != null: pieces = get_parent().get("pieces")
	if pieces != null:
		for piece in pieces.get_children():
			if str(piece.name).begins_with("Workbench") and at.distance_to(piece.global_position)<3.0: return "workshop"
	if Layout.contains_home_position(at,true): return "home"
	if Vector2(at.x,at.z).length()<7: return "fountain"
	if hall_interior(at)>0.0: return "hall"
	if park_contains(at): return "park"
	return "natural"

func park_contains(at: Vector3) -> bool:
	# Selected Hall-route Park A publishes its actual built paving, not a guessed radius.
	# park_hall.gd stores root-local XZ polygons; its current root transform is identity.
	# No park script preload: the audio overlay also works when the park is absent.
	var park = get_parent().get_node_or_null("HallRoutePark")
	if not at.is_finite() or not park is Node3D or park.is_queued_for_deletion(): return false
	var local = park.to_local(at)
	if local.y < -1.0 or local.y > 3.0: return false
	var polygons = park.get_meta("paving_polygons",[])
	if not polygons is Array: return false
	for polygon in polygons:
		if not polygon is PackedVector2Array or polygon.size()<3: continue
		var valid = true
		for point in polygon:
			if not point.is_finite(): valid=false; break
		if valid and Geometry2D.is_point_in_polygon(Vector2(local.x,local.z),polygon): return true
	return false

func advance_ambience(delta: float):
	var at = player.global_position
	current_zone = zone_at(at)
	interior_blend = move_toward(interior_blend,hall_interior(at),maxf(delta,0)*0.65)
	lowpass.cutoff_hz = lerpf(18000,4200,interior_blend)
	AudioServer.set_bus_volume_db(ambient_bus,-7*interior_blend)
	var daylight = 1.0
	var cycle = get_parent().get_node_or_null("DayNightCycle")
	if cycle != null: daylight = cycle.sample(cycle.elapsed_seconds/cycle.cycle_seconds).daylight
	# Quieter night, never a new looping insect bed. Home/workshop keep a calm floor.
	var target = -24.0 - (1.0-daylight)*4.0
	if current_zone in ["home","workshop"]: target -= 3.0
	wind.volume_db = move_toward(wind.volume_db,target,delta*3)
	var x = clampf(at.x,-42.5,42.5)
	stream_water.global_position = Vector3(x,Terrain.stream_water_y(x),Terrain.stream_z(x))
	bird_wait -= delta
	if bird_wait <= 0:
		if not birds.is_empty() and daylight>.45 and not current_zone in ["home","workshop"]:
			var index = rng.randi_range(0,birds.size()-1)
			if is_instance_valid(habitat[index]):
				var bird = birds[index]; bird.global_position = habitat[index].global_position+Vector3.UP*.2
				bird.stream = stream("bird_%d" % rng.randi_range(0,3)); bird.play()
		bird_wait = rng.randf_range(24,48)
	if music.playing:
		music_age += delta
		# Retained quiet, intermittent schedule: original night cue / approved daytime cue.
		var remaining = music.stream.get_length()-music_age
		var envelope = clampf(minf(music_age,remaining)/5.0,0.001,1.0)
		music.volume_db = -25+linear_to_db(envelope)
	else:
		music_wait -= delta
		if music_wait <= 0:
			music.stream = stream("approved_v098/music/settlement_day_loop.ogg") if daylight > .45 else stream("settlement_menu_calm")
			music_age=0; music.volume_db=-60; music.play()
			music_wait=rng.randf_range(110,190)
