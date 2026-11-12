extends Control
## Isolated launch screen. Replacing VIDEO_PATH swaps the provisional background.
const VIDEO_PATH = "res://assets/video/settlement_menu_placeholder.ogv"
const LOADING_VIDEO_PATH = "res://assets/video/settlement_loading_intro.ogv"
const WORLD_PATH = "res://main.tscn"
const Options = preload("res://scripts/options_panel.gd")
const MUSIC_PATH = "res://assets/audio/menu_first_snow.ogg"
var music: AudioStreamPlayer
var video: VideoStreamPlayer
var menu: PanelContainer
var options
var play_button: Button
var settings_button: Button
var status: Label
var starting := false
const CharacterSession=preload("res://scripts/character_profiles/title_session.gd")
const CharacterSelection=preload("res://scripts/character_profiles/selection_panel.gd")
const CharacterRules=preload("res://scripts/character_profiles/experimental_rules.gd")
var characters=CharacterSession.new()
var character_panel
var character_token:int=0
var legacy_launch=true
var intro_pending=false
var replaying_intro := false
var replay_button: Button
var replay_layer: CanvasLayer

func _ready():
	get_tree().auto_accept_quit = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var backdrop = ColorRect.new()
	backdrop.color = Color("080e13")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	video = VideoStreamPlayer.new()
	video.expand = true
	video.loop = true
	video.finished.connect(func():
		if replaying_intro: _end_intro_replay()
		elif starting: _intro_finished()
	)
	video.volume = 0.0
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(video)
	_start_video()
	var shade = ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.18)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	menu = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("101b24e8")
	style.border_color = Color("a78c59")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	menu.add_theme_stylebox_override("panel", style)
	add_child(menu)
	var scroll = ScrollContainer.new()
	menu.add_child(scroll)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	var title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "SETTLEMENT\nPROTOTYPE"
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	var subtitle = Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.text = "First playable · Working title"
	subtitle.add_theme_color_override("font_color", Color("d2c3a8"))
	column.add_child(subtitle)
	play_button = _button(column, "Play", _play)
	settings_button = _button(column, "Settings", _settings)
	_button(column, "Quit", func(): get_tree().quit())
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.hide()
	column.add_child(status)
	options = Options.new()
	add_child(options)
	options.setup(null, Callable(), true)
	_start_music()
	options.closed.connect(_settings_closed)
	resized.connect(_layout)
	_layout()
	play_button.grab_focus()

func _button(parent: Node, label: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = label
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 20)
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func _layout():
	if not is_instance_valid(video): return
	# Fit the full original frame, retaining the watermark and composition.
	var ratio = 16.0 / 9.0
	var fitted = Vector2(size.x, size.x / ratio)
	if fitted.y > size.y: fitted = Vector2(size.y * ratio, size.y)
	video.size = fitted
	video.position = (size - fitted) * 0.5
	var margin = clampf(size.x * 0.045, 12.0, 64.0)
	# Keep the default card compact, but grow when status is visible so a
	# load-error reason is not clipped at the 360px cap.
	var card_w = minf(360.0, size.x - margin * 2.0)
	var card_h = 360.0
	if is_instance_valid(status) and status.visible and not str(status.text).strip_edges().is_empty():
		status.custom_minimum_size = Vector2(maxf(0.0, card_w - 48.0), 0.0)
		card_h = 520.0
	menu.size = Vector2(card_w, minf(card_h, size.y - 24.0))
	menu.position = (size - menu.size) * 0.5
	if is_instance_valid(replay_layer):
		var replay_back = replay_layer.get_node_or_null("ReplayBack")
		if replay_back: replay_back.position = Vector2(maxf(12, size.x / 2 - 140), maxf(12, size.y - 70))
	if is_instance_valid(loading_layer):
		var footer=loading_layer.get_node_or_null("LoadingFooter")
		if footer:
			footer.custom_minimum_size.x=maxf(1,minf(400,size.x-24))
			footer.position=Vector2(maxf(12,size.x/2-200),maxf(12,size.y-130))
		var poster=loading_layer.get_node_or_null("StillPoster")
		if poster: poster.position=(size-poster.size)*0.5

func _replay_intro():
	if starting or replaying_intro or is_instance_valid(character_panel): return
	var clip = load(LOADING_VIDEO_PATH) if ResourceLoader.exists(LOADING_VIDEO_PATH) else null
	if clip == null:
		status.text = "Intro video is unavailable. You can still play."
		status.show()
		return
	replaying_intro = true
	menu.hide()
	if is_instance_valid(music): music.stop()
	replay_layer = CanvasLayer.new()
	replay_layer.layer = 100
	add_child(replay_layer)
	var background = ColorRect.new()
	background.color = Color("080e13")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	replay_layer.add_child(background)
	video.stop()
	video.reparent(replay_layer)
	video.stream = clip
	video.loop = false
	video.show()
	var back = Button.new()
	back.name = "ReplayBack"
	back.text = "Back to menu"
	back.custom_minimum_size = Vector2(280, 44)
	back.pressed.connect(_end_intro_replay)
	replay_layer.add_child(back)
	_layout()
	back.grab_focus()
	video.play()

func _end_intro_replay():
	if not replaying_intro: return
	replaying_intro = false
	video.stop()
	video.reparent(self)
	move_child(video, 1)
	if is_instance_valid(replay_layer):
		remove_child(replay_layer)
		replay_layer.queue_free()
	replay_layer = null
	video.show()
	_start_video()
	_start_music()
	menu.show()
	replay_button.grab_focus()

func _unhandled_input(event: InputEvent):
	if replaying_intro and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_end_intro_replay()

func _start_video():
	video.loop = true
	if ResourceLoader.exists(VIDEO_PATH):
		video.stream = load(VIDEO_PATH)
		video.play()

func _settings():
	if starting or replaying_intro or is_instance_valid(character_panel): return
	menu.hide()
	options.open()

func _settings_closed():
	menu.show()
	settings_button.grab_focus()

# Isolated successor: title keeps its approved backdrop; Play uses the selected concept clip.
var world_path := WORLD_PATH
var loading_layer: CanvasLayer
var loading_label: Label
var still_mode := false
var startup_resources: Array = []
var startup_world: Node
var launch_count := 0
var loading_generation := 0
var transition_events: Array = []
func _play():
	if starting or replaying_intro or is_instance_valid(character_panel): return
	characters.rules=CharacterRules.data()
	character_panel=CharacterSelection.new();character_panel.session=characters
	character_panel.back_requested.connect(_close_characters)
	character_panel.launch_requested.connect(_launch_character)
	menu.hide();add_child(character_panel)

func _close_characters():
	if is_instance_valid(character_panel):remove_child(character_panel);character_panel.queue_free()
	character_panel=null;menu.show();play_button.grab_focus()

func _launch_character(token:int,legacy:bool,needs_intro:bool):
	if starting:return
	character_token=token;legacy_launch=legacy;intro_pending=needs_intro
	_close_characters()
	_launch_world()

func _intro_finished():
	if not starting:return
	if intro_pending and not _record_intro():return
	_skip_video(true)

func _record_intro()->bool:
	var result=characters.complete_intro(character_token)
	if not result.ok:
		loading_label.text="Intro progress could not be saved: "+result.reason+". Return to menu and try again."
		return false
	intro_pending=false;return true

func _launch_world():
	if starting: return
	starting = true
	launch_count += 1
	loading_generation += 1
	var generation = loading_generation
	var deadline = Time.get_ticks_msec()+300000
	play_button.disabled = true
	settings_button.disabled = true
	menu.hide()
	_show_loading()
	# Stop menu audio before world audio starts; respect existing bus settings.
	_stop_music()
	transition_events.append("presentation_visible")
	await get_tree().process_frame
	if generation != loading_generation: return
	if Time.get_ticks_msec()>deadline:
		_loading_failed("Loading timed out. You can retry; no gameplay was started.")
		return
	if not ResourceLoader.exists(world_path):
		_loading_failed("Could not open settlement. Please retry.")
		return
	var request = ResourceLoader.load_threaded_request(world_path,"PackedScene")
	if request != OK:
		_loading_failed("Could not begin loading. Please retry.")
		return
	var progress = []
	while true:
		if generation != loading_generation: return
		if Time.get_ticks_msec()>deadline:
			_loading_failed("Loading timed out. You can retry; no gameplay was started.")
			return
		var state = ResourceLoader.load_threaded_get_status(world_path,progress)
		if state == ResourceLoader.THREAD_LOAD_LOADED: break
		if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading_failed("Could not load settlement. Please retry.")
			return
		loading_label.text = "Loading resources…" # Not total world progress.
		await get_tree().process_frame
	var packed = ResourceLoader.load_threaded_get(world_path)
	if not packed is PackedScene:
		_loading_failed("Settlement scene is unavailable. Please retry.")
		return
	startup_resources = [packed]
	# These dynamically loaded authored scenes are not dependencies of main.tscn.
	# Retain references until the world owns them, rather than decoding on the UI thread.
	for asset_name in ["town_hall","west_trader","fountain","fountain_apron","home_storage_chest"]:
		var asset_path = "res://assets/kit/"+asset_name+".glb"
		if not ResourceLoader.exists(asset_path):
			if asset_name in ["town_hall","home_storage_chest"]:
				_loading_failed("A required world asset is unavailable. Please retry.")
				return
			continue
		if ResourceLoader.load_threaded_request(asset_path,"PackedScene") != OK:
			_loading_failed("Could not prepare world assets. Please retry.")
			return
		while true:
			if generation != loading_generation: return
			if Time.get_ticks_msec()>deadline:
				_loading_failed("Loading timed out. You can retry; no gameplay was started.")
				return
			var asset_state=ResourceLoader.load_threaded_get_status(asset_path)
			if asset_state == ResourceLoader.THREAD_LOAD_LOADED: break
			if asset_state != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_loading_failed("Could not prepare world assets. Please retry.")
				return
			await get_tree().process_frame
		startup_resources.append(ResourceLoader.load_threaded_get(asset_path))
	startup_world = packed.instantiate()
	if not _world_supports_startup(startup_world):
		if is_instance_valid(startup_world): startup_world.queue_free()
		startup_world = null
		_loading_failed("Settlement startup is unavailable. Please retry.")
		return
	if legacy_launch and (not startup_world.has_method("bind_legacy_continue") or not startup_world.bind_legacy_continue()):
		startup_world.queue_free();startup_world=null
		_loading_failed("Existing-save continuation is unavailable. No new game was started.")
		return
	if not legacy_launch and not characters.bind_world(startup_world,character_token):
		startup_world.queue_free();startup_world=null
		_loading_failed("Character selection or save changed. Return to character selection.")
		return
	if not startup_world.has_method("request_town_hall_login") or not startup_world.request_town_hall_login():
		startup_world.queue_free();startup_world=null
		_loading_failed("Could not prepare the Town Hall login. No gameplay was started.")
		return
	startup_world.staged_startup = true
	startup_world.process_mode = Node.PROCESS_MODE_DISABLED
	startup_world.loading_stage.connect(func(_stage,_ms):
		if generation == loading_generation and starting and is_instance_valid(loading_label): loading_label.text=str(_stage) if str(_stage).begins_with("Preparing scenery:") or str(_stage).begins_with("Finalizing") else "Preparing settlement…"
	)
	transition_events.append("world_initializing")
	get_tree().root.add_child(startup_world)
	while is_instance_valid(startup_world) and not startup_world.world_initialized:
		await get_tree().process_frame
		if generation != loading_generation: return
		if Time.get_ticks_msec()>deadline:
			_loading_failed("Loading timed out. You can retry; no gameplay was started.")
			return
	if not is_instance_valid(startup_world):
		_loading_failed("Settlement startup was interrupted. Please retry.")
		return
	loading_label.text = "Preparing landscaping…"
	var asset_gate = startup_world.startup_asset_gate
	var assets_result = await asset_gate.prepare(startup_world)
	if generation != loading_generation: return
	if not assets_result.get("ok",false):
		_loading_failed("Could not finish loading scenery: "+str(assets_result.get("reason","Unknown error"))+". No gameplay was started.")
		return
	transition_events.append("assets_ready")
	transition_events.append("world_ready")
	while intro_pending:
		if Time.get_ticks_msec()>deadline:
			_loading_failed("Intro did not finish. Return to menu and retry; no gameplay was started.")
			return
		if not is_instance_valid(startup_world) or startup_world.is_queued_for_deletion() or startup_world.startup_cancel_requested:
			_loading_failed("Character world was cancelled while waiting for intro. Return to selection.")
			return
		await get_tree().process_frame
		if generation != loading_generation:return
	if not is_instance_valid(startup_world) or startup_world.is_queued_for_deletion() or startup_world.startup_cancel_requested:
		_loading_failed("Character world is unavailable. Return to selection.")
		return
	# The world owns its physics/render readiness barrier, not the clip duration.
	video.stop()
	video.stream = null
	get_tree().current_scene = startup_world
	startup_world.activate_loaded_world()
	transition_events.append("gameplay_activated")
	queue_free()

func _world_supports_startup(node: Node) -> bool:
	if node == null: return false
	if not node.has_signal("gameplay_ready") or not node.has_signal("loading_stage"): return false
	if not node.has_method("prepare_startup_assets") or not node.has_method("activate_loaded_world") or not node.has_method("request_startup_cancel"): return false
	var properties = {}
	for property in node.get_property_list(): properties[property.name] = true
	return properties.has("staged_startup") and properties.has("world_initialized") and properties.has("startup_cancel_requested")

func _exit_tree():
	_stop_music()
	characters.cancel()
	loading_generation += 1
	if is_instance_valid(startup_world) and startup_world != get_tree().current_scene:
		startup_world.request_startup_cancel()

func cancel_loading():
	if not starting: return
	characters.cancel()
	intro_pending=false
	loading_generation += 1
	if is_instance_valid(startup_world): startup_world.request_startup_cancel()
	startup_world = null
	_loading_failed("Loading cancelled. You can retry.")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST and starting: get_tree().quit()

func _show_loading():
	loading_layer = CanvasLayer.new()
	loading_layer.layer = 100
	add_child(loading_layer)
	var background = ColorRect.new()
	background.color = Color("080e13")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_layer.add_child(background)
	video.reparent(loading_layer)
	# User-selected Gemini concept video; silent derivative, not gameplay footage.
	video.stop()
	video.stream = load(LOADING_VIDEO_PATH) if ResourceLoader.exists(LOADING_VIDEO_PATH) else null
	video.loop = false
	video.stop()
	if video.stream != null: video.play()
	var footer = VBoxContainer.new()
	footer.name = "LoadingFooter"
	footer.position = Vector2(maxf(12,size.x/2-200),maxf(12,size.y-130))
	footer.custom_minimum_size = Vector2(maxf(1,minf(400,size.x-24)),100)
	loading_layer.add_child(footer)
	loading_label = Label.new()
	loading_label.text = "Preparing settlement…"
	loading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(loading_label)
	var back = Button.new()
	back.text = "Back to menu"
	back.pressed.connect(cancel_loading)
	footer.add_child(back)
	back.grab_focus()
	# A missing optional clip must not leave a fresh character waiting forever.
	if video.stream == null: _intro_finished()
	elif not intro_pending: _skip_video()

func _skip_video(retain_end := false):
	still_mode = true
	# Hold only the raw video texture, never a viewport capture containing UI.
	# Godot stop() preserves the current frame while ending decode/playback.
	var texture = video.get_video_texture()
	var hold_frame = texture != null and texture.get_width() > 0 and (retain_end or video.stream_position > 0.04)
	video.stop()
	if hold_frame:
		video.show()
		transition_events.append("video_frame_held")
		return
	video.hide()
	if not is_instance_valid(loading_layer): return
	if loading_layer.has_node("StillPoster"): return
	var poster = TextureRect.new()
	poster.name = "StillPoster"
	poster.texture = load("res://assets/ui/settlement_crest.png")
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	poster.position = Vector2(size.x/2-100,size.y/2-100)
	poster.size = Vector2(200,200)
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_layer.add_child(poster)

func _loading_failed(message: String):
	if is_instance_valid(startup_world) and startup_world != get_tree().current_scene:
		startup_world.request_startup_cancel()
	startup_world=null
	get_tree().auto_accept_quit = true
	startup_resources.clear()
	transition_events.append("failed")
	video.reparent(self)
	move_child(video,1)
	loading_layer.queue_free()
	loading_layer = null
	starting = false
	play_button.disabled = false
	settings_button.disabled = false
	menu.show()
	status.text = message
	status.show()
	video.show()
	_start_video()
	_start_music()
	_layout()
	play_button.grab_focus()

func _stop_music():
	# Godot 4.6.3's Ogg playback is not always released if the player is
	# only stopped or queue_freed. Drop the stream and free the node here.
	if not is_instance_valid(music):
		music = null
		return
	music.stop()
	music.stream = null
	music.free()
	music = null

func _start_music():
	if not ResourceLoader.exists(MUSIC_PATH): return
	if not is_instance_valid(music):
		music = AudioStreamPlayer.new()
		music.name = "MenuMusic"
		add_child(music)
	var track = load(MUSIC_PATH)
	if track is AudioStreamOggVorbis:
		track.loop = true
		track.loop_offset = 0.0
	music.stream = track
	music.bus = "Music"
	music.volume_db = -12.0
	# Playing an Ogg stream in the headless audio driver leaves
	# AudioStreamPlaybackOggVorbis / OggPacketSequence in ObjectDB at exit.
	# Windowed runs still play; headless tests only need the player to exist.
	if DisplayServer.get_name() != "headless":
		music.play()
