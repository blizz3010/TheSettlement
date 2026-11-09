extends RefCounted
# Preferences never share the gameplay save. Display confirmation belongs to the menu.
const RESOLUTIONS = [[1280,720],[1440,900],[1920,1080],[2560,1440],[3840,2160]]
const FRAME_CAPS = [0,30,60,90,120,144,165,240]
const SHADOW_META = &"settings_original_shadow_enabled"
const RESERVED = [KEY_ENTER,KEY_KP_ENTER,KEY_TAB,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_ESCAPE,KEY_0,KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_PAGEUP,KEY_PAGEDOWN,KEY_F5,KEY_F9]
var path := "user://settings.json"
var last_error := ""
var migration_notice := ""
func defaults() -> Dictionary:
	return {"version":7,"material_detail_quality":2,"scenery_quality":2,"grass_quality":2,"fps_limit":0,"shadows_enabled":true,"audio_output_device":"Default","display_mode":"windowed","resolution":[1440,900],"vsync":true,"msaa":4,"master":1.0,"music":1.0,"sfx":1.0,"sensitivity":0.002,"invert_y":false,"bindings":{"forward":KEY_W,"backward":KEY_S,"left":KEY_A,"right":KEY_D,"sprint":KEY_SHIFT,"jump":KEY_SPACE,"crouch":KEY_CTRL,"interact":KEY_E,"inventory":KEY_I,"view":KEY_V,"build":KEY_B,"rotate":KEY_R,"map":KEY_M,"quests":KEY_L,"skills":KEY_K}}
func numeric(value:Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
func validate(candidate:Variant) -> String:
	return validate_schema(candidate,7)
func validate_schema(candidate:Variant, version:int) -> String:
	if not candidate is Dictionary: return "Settings must be an object."
	if version not in [2,3,4,5,6,7]: return "Unsupported settings version."
	var base=defaults()
	if version<=6: base.erase("material_detail_quality")
	if version<=5: base.erase("scenery_quality")
	if version<=4: base.erase("grass_quality")
	if version<=3: base.bindings.erase("skills")
	if version==2: base.bindings.erase("quests")
	if candidate.size()!=base.size(): return "Settings fields are incomplete or unsupported."
	for key in base:
		if not candidate.has(key): return "Missing settings field: "+key
	if not numeric(candidate.version) or candidate.version!=version: return "Unsupported settings version."
	if not candidate.display_mode is String or not candidate.display_mode in ["windowed","borderless","fullscreen"]: return "Invalid display mode."
	if not candidate.resolution is Array or candidate.resolution.size()!=2: return "Invalid resolution."
	for dimension in candidate.resolution:
		if not numeric(dimension) or dimension!=int(dimension): return "Invalid resolution."
	var recognized=false
	for dimensions in RESOLUTIONS:
		if candidate.resolution[0]==dimensions[0] and candidate.resolution[1]==dimensions[1]: recognized=true
	if DisplayServer.get_name()!="headless":
		var native=DisplayServer.screen_get_size()
		if candidate.resolution[0]==native.x and candidate.resolution[1]==native.y: recognized=true
	if not recognized: return "Unsupported resolution."
	if not candidate.vsync is bool or not candidate.invert_y is bool: return "Invalid toggle."
	if not numeric(candidate.msaa) or candidate.msaa!=int(candidate.msaa) or not int(candidate.msaa) in [0,2,4,8]: return "Invalid antialiasing level."
	if not numeric(candidate.fps_limit) or candidate.fps_limit!=int(candidate.fps_limit) or not int(candidate.fps_limit) in FRAME_CAPS: return "Invalid frame limit."
	if version>=5:
		if not numeric(candidate.grass_quality) or candidate.grass_quality!=int(candidate.grass_quality) or not int(candidate.grass_quality) in [0,1,2,3]: return "Invalid grass quality."
	if version>=6:
		if not numeric(candidate.scenery_quality) or candidate.scenery_quality!=int(candidate.scenery_quality) or not int(candidate.scenery_quality) in [0,1,2,3]: return "Invalid distant scenery quality."
	if version>=7:
		if not numeric(candidate.material_detail_quality) or candidate.material_detail_quality!=int(candidate.material_detail_quality) or not int(candidate.material_detail_quality) in [0,1,2,3]: return "Invalid material detail quality."
	if not candidate.shadows_enabled is bool: return "Invalid shadow toggle."
	if not candidate.audio_output_device is String or candidate.audio_output_device.is_empty() or candidate.audio_output_device.length()>1024: return "Invalid audio output device."
	for key in ["master","music","sfx"]:
		if not numeric(candidate[key]) or candidate[key]<0 or candidate[key]>1: return "Volume must be between 0 and 100%."
	if not numeric(candidate.sensitivity) or candidate.sensitivity<0.0005 or candidate.sensitivity>0.006: return "Invalid mouse sensitivity."
	if not candidate.bindings is Dictionary or candidate.bindings.size()!=base.bindings.size(): return "Invalid key bindings."
	var used=[]
	for action in base.bindings:
		if not candidate.bindings.has(action): return "Missing key binding: "+action
		var code=candidate.bindings[action]
		if not numeric(code) or code!=int(code) or code<=0 or code>KEY_SPECIAL+0xFFFF: return "Invalid key binding."
		if int(code) in RESERVED: return "That key is reserved for menus, building slots or saves."
		if int(code) in used: return "Each action needs a different key."
		used.append(int(code))
	return ""
func load_settings() -> Dictionary:
	last_error=""
	migration_notice=""
	if not FileAccess.file_exists(path): return defaults()
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK:
		last_error="Settings file is invalid; defaults loaded."
		return defaults()
	var candidate = upgrade_settings(parser.data)
	var error=validate(candidate)
	if not error.is_empty():
		last_error="Settings file is invalid; defaults loaded. "+error
		return defaults()
	var loaded=candidate.duplicate(true)
	loaded.version=int(loaded.version)
	loaded.msaa=int(loaded.msaa)
	loaded.fps_limit=int(loaded.fps_limit)
	loaded.grass_quality=int(loaded.grass_quality)
	loaded.scenery_quality=int(loaded.scenery_quality)
	loaded.material_detail_quality=int(loaded.material_detail_quality)
	loaded.resolution=[int(loaded.resolution[0]),int(loaded.resolution[1])]
	for action in loaded.bindings: loaded.bindings[action]=int(loaded.bindings[action])
	if parser.data.version!=7:
		# Atomic migration: failure leaves the complete old file untouched; the
		# validated additive mapping remains usable in memory and retries next load.
		if not save_settings(loaded): migration_notice=last_error
		else: migration_notice=binding_notice(loaded)
	else: migration_notice=binding_notice(loaded)
	return loaded
func backup_legacy_settings(version:int) -> bool:
	var backup=path+".v%d.pre-v7.bak"%version
	var original=FileAccess.get_file_as_bytes(path)
	if FileAccess.file_exists(backup):
		if FileAccess.get_file_as_bytes(backup)==original:return true
		last_error="Existing settings backup differs. Preserve both files and resolve the conflict before upgrading."
		return false
	if DirAccess.dir_exists_absolute(backup):
		last_error="Settings backup path is a folder. Previous settings were preserved."
		return false
	var file=FileAccess.open(backup+".tmp",FileAccess.WRITE)
	if file==null:
		last_error="Could not back up old settings. Previous settings were preserved."
		return false
	file.store_buffer(original);file.flush()
	var error=file.get_error();file.close()
	if error!=OK or FileAccess.get_file_as_bytes(backup+".tmp")!=original or DirAccess.rename_absolute(ProjectSettings.globalize_path(backup+".tmp"),ProjectSettings.globalize_path(backup))!=OK:
		last_error="Could not finish settings backup. Previous settings were preserved."
		return false
	if FileAccess.get_file_as_bytes(backup)!=original:
		last_error="Settings backup verification failed. Previous settings were preserved."
		return false
	return true
func quest_binding_notice(settings:Dictionary) -> String:
	if settings.bindings.quests==KEY_L:return ""
	for action in settings.bindings:
		if action!="quests" and settings.bindings[action]==KEY_L:
			return "L is assigned to %s. Quest journal uses %s. Change this in Controls." % [action.capitalize(),OS.get_keycode_string(settings.bindings.quests)]
	return "Quest journal uses %s. Change this in Controls." % OS.get_keycode_string(settings.bindings.quests)
func preserve_legacy_before_write() -> bool:
	# Gate EVERY write, including Options Apply / Keep after a load-time failure,
	# and callers using a new backend instance. The disk contract is authoritative.
	if not FileAccess.file_exists(path):return true
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK:return true
	var legacy=parser.data
	if not legacy is Dictionary or not numeric(legacy.get("version")) or (legacy.version!=1 and legacy.version!=2 and legacy.version!=3 and legacy.version!=4 and legacy.version!=5 and legacy.version!=6):return true
	var validated=upgrade_v1(legacy)
	if not validate_schema(validated,int(validated.version)).is_empty():return true
	return backup_legacy_settings(int(legacy.version))
func save_settings(candidate:Dictionary) -> bool:
	last_error=validate(candidate)
	if not last_error.is_empty(): return false
	if not preserve_legacy_before_write():return false
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:
		last_error="Could not write settings. Previous settings were preserved."
		return false
	var serialized=JSON.stringify(candidate)
	file.store_string(serialized)
	file.flush()
	var error=file.get_error()
	file.close()
	if error!=OK or FileAccess.get_file_as_string(path+".tmp")!=serialized:
		last_error="Settings write was incomplete. Previous settings were preserved."
		return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))!=OK:
		last_error="Could not replace settings. Previous settings were preserved."
		return false
	migration_notice=binding_notice(candidate)
	return true
func apply(settings:Dictionary, player:Node, viewport:Viewport) -> bool:
	last_error=validate(settings)
	if not last_error.is_empty(): return false
	Engine.max_fps=int(settings.fps_limit)
	apply_grass_quality(viewport,int(settings.grass_quality))
	apply_scenery_quality(viewport,int(settings.scenery_quality))
	apply_material_detail_quality(viewport,int(settings.material_detail_quality))
	apply_audio_output(settings.audio_output_device)
	if is_instance_valid(viewport): apply_scene_shadows(viewport,settings.shadows_enabled)
	for action in settings.bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var key=InputEventKey.new()
		key.physical_keycode=int(settings.bindings[action])
		InputMap.action_add_event(action,key)
	if is_instance_valid(player):
		player.set("mouse_sensitivity",float(settings.sensitivity))
		player.set("invert_y",settings.invert_y)
	for bus in ["Master","Music","SFX"]:
		var index=AudioServer.get_bus_index(bus)
		if index<0:
			AudioServer.add_bus()
			index=AudioServer.bus_count-1
			AudioServer.set_bus_name(index,bus)
			AudioServer.set_bus_send(index,"Master")
		var volume=float(settings[bus.to_lower()])
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(volume,0.0001)))
		AudioServer.set_bus_mute(index,volume==0)
	if is_instance_valid(viewport):
		viewport.msaa_3d={0:Viewport.MSAA_DISABLED,2:Viewport.MSAA_2X,4:Viewport.MSAA_4X,8:Viewport.MSAA_8X}[int(settings.msaa)]
	if DisplayServer.get_name()!="headless":
		var wanted_vsync=DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED
		if DisplayServer.window_get_vsync_mode()!=wanted_vsync: DisplayServer.window_set_vsync_mode(wanted_vsync)
		var size=Vector2i(int(settings.resolution[0]),int(settings.resolution[1]))
		var mode=DisplayServer.WINDOW_MODE_WINDOWED
		if settings.display_mode=="borderless": mode=DisplayServer.WINDOW_MODE_FULLSCREEN
		elif settings.display_mode=="fullscreen": mode=DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		# Do not cycle the display for sound, controls or antialiasing changes.
		# Use Window properties so Godot's viewport/stretch state follows native changes.
		var window=viewport.get_window()
		if window.mode!=mode:
			window.mode=Window.MODE_WINDOWED
			window.borderless=false
			window.size=size
			if mode!=Window.MODE_WINDOWED:window.mode=mode
		elif mode==Window.MODE_WINDOWED:
			window.borderless=false
			if window.size!=size:window.size=size
	return true

# v051 preferences remain valid; never reset unrelated custom keys or display/audio.
# Strict validation still rejects missing/unknown fields other than this one addition.
func upgrade_legacy_bindings(candidate: Variant) -> Variant:
	if not candidate is Dictionary or not candidate.get("bindings") is Dictionary: return candidate
	if candidate.bindings.has("crouch") and candidate.bindings.has("map"): return candidate
	var upgraded = candidate.duplicate(true)
	var keys = [KEY_CTRL, KEY_C, KEY_ALT, KEY_Z, KEY_X, KEY_Q, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K, KEY_L]
	var used = []
	for value in upgraded.bindings.values():
		if numeric(value): used.append(int(value))
	for key in keys:
		if not upgraded.bindings.has("crouch") and not key in used:
			upgraded.bindings.crouch = key
			break
	used.clear()
	for value in upgraded.bindings.values():
		if numeric(value):used.append(int(value))
	for key in [KEY_M,KEY_N,KEY_J,KEY_K,KEY_L,KEY_P,KEY_O,KEY_U,KEY_Q,KEY_F,KEY_G,KEY_H,KEY_Z,KEY_X,KEY_C,KEY_Y,KEY_T,KEY_A,KEY_S,KEY_D,KEY_W,KEY_E,KEY_R,KEY_I,KEY_V,KEY_B]:
		if not upgraded.bindings.has("map") and not key in used:
			upgraded.bindings.map=key
			break
	return upgraded

# Only known v1 shape is migrated; malformed/new-version partial files remain invalid.
func upgrade_v1(candidate: Variant) -> Variant:
	if not candidate is Dictionary or not numeric(candidate.get("version")) or candidate.version!=1: return candidate
	var upgraded=upgrade_legacy_bindings(candidate)
	var legacy_keys=defaults().keys()
	for added in ["fps_limit","shadows_enabled","audio_output_device","grass_quality","scenery_quality","material_detail_quality"]: legacy_keys.erase(added)
	if upgraded.size()!=legacy_keys.size(): return upgraded
	for key in legacy_keys:
		if not upgraded.has(key): return upgraded
	upgraded=upgraded.duplicate(true)
	upgraded.version=2
	upgraded.fps_limit=0
	upgraded.shadows_enabled=true
	upgraded.audio_output_device="Default"
	return upgraded

func upgrade_quests(candidate: Variant) -> Variant:
	var old=upgrade_v1(candidate)
	if not old is Dictionary or not numeric(old.get("version")) or old.version!=2:return old
	# Validate the exact old contract before adding anything, not the new schema.
	if not validate_schema(old,2).is_empty():return old
	var upgraded=old.duplicate(true)
	var used=[]
	for value in upgraded.bindings.values():used.append(int(value))
	for code in [KEY_L,KEY_J,KEY_P,KEY_O,KEY_U,KEY_N,KEY_H,KEY_G,KEY_F,KEY_T,KEY_Y,KEY_Z,KEY_X,KEY_C,KEY_Q]:
		if not code in used and not code in RESERVED:
			upgraded.bindings.quests=code
			upgraded.version=3
			return upgraded
	return old

func output_devices() -> PackedStringArray:
	var result=PackedStringArray(["Default"])
	for device in AudioServer.get_output_device_list():
		if not device.is_empty() and not device in result: result.append(device)
	return result

func resolve_output_device(preferred: String, available: PackedStringArray) -> String:
	return preferred if preferred in available else "Default"

func apply_audio_output(preferred: String) -> void:
	var effective=resolve_output_device(preferred,output_devices())
	if AudioServer.output_device!=effective: AudioServer.output_device=effective

func apply_scene_shadows(node: Node, enabled: bool) -> void:
	if node is Light3D:
		# Keep deliberately shadowless fill/lantern lights shadowless when restored.
		if not node.has_meta(SHADOW_META): node.set_meta(SHADOW_META,node.shadow_enabled)
		node.shadow_enabled=enabled and bool(node.get_meta(SHADOW_META))
	for child in node.get_children(): apply_scene_shadows(child,enabled)

# Additive v4: never steal K from an existing custom action.
func upgrade_skills(candidate: Variant) -> Variant:
	var old=upgrade_quests(candidate)
	if not old is Dictionary or not numeric(old.get("version")) or old.version!=3:return old
	if not validate_schema(old,3).is_empty():return old
	var upgraded=old.duplicate(true)
	var used=[]
	for value in upgraded.bindings.values():used.append(int(value))
	for code in [KEY_K,KEY_J,KEY_P,KEY_O,KEY_U,KEY_N,KEY_H,KEY_G,KEY_F,KEY_T,KEY_Y,KEY_Z,KEY_X,KEY_C,KEY_Q,KEY_F1,KEY_F2]:
		if not code in used and not code in RESERVED:
			upgraded.bindings.skills=code
			upgraded.version=4
			return upgraded
	return old
func skills_binding_notice(settings:Dictionary) -> String:
	if settings.bindings.skills==KEY_K:return ""
	return "K remains assigned to your existing action. Skills uses %s; remap in Controls." % OS.get_keycode_string(settings.bindings.skills) if KEY_K in settings.bindings.values() else "Skills uses %s; remap in Controls." % OS.get_keycode_string(settings.bindings.skills)
func binding_notice(settings:Dictionary) -> String:
	return "\n".join(PackedStringArray([quest_binding_notice(settings),skills_binding_notice(settings)] )).strip_edges()

# Additive v5: preserve every existing validated preference, including custom keys.
func upgrade_grass(candidate: Variant) -> Variant:
	var old=upgrade_skills(candidate)
	if not old is Dictionary or not numeric(old.get("version")) or old.version!=4:return old
	if not validate_schema(old,4).is_empty():return old
	var upgraded=old.duplicate(true)
	upgraded.version=5
	upgraded.grass_quality=2
	return upgraded

# Controllers created after Apply must initialize themselves from the live tier,
# including a display preview that has not been saved yet. No schema change.
func current_grass_quality(context: Node) -> int:
	if is_instance_valid(context) and context.is_inside_tree():
		var tree=context.get_tree()
		if tree.has_meta("settings_grass_quality"):
			return int(tree.get_meta("settings_grass_quality"))
	return int(load_settings().grass_quality)

# Only registered grass controllers receive this; terrain and gameplay saves do not.
func apply_grass_quality(context: Node, quality: int) -> void:
	if not is_instance_valid(context) or not context.is_inside_tree():return
	context.get_tree().set_meta("settings_grass_quality",quality)
	for controller in context.get_tree().get_nodes_in_group("plaza_grass_quality"):
		if is_instance_valid(controller) and controller.has_method("set_quality"):
			controller.call("set_quality",quality)

# Additive v6: keep distant landscapes independent from plaza grass and shadows.
func upgrade_scenery(candidate: Variant) -> Variant:
	var old=upgrade_grass(candidate)
	if not old is Dictionary or not numeric(old.get("version")) or old.version!=5:return old
	if not validate_schema(old,5).is_empty():return old
	var upgraded=old.duplicate(true)
	upgraded.version=6
	upgraded.scenery_quality=2
	return upgraded

func current_scenery_quality(context: Node) -> int:
	if is_instance_valid(context) and context.is_inside_tree():
		var tree=context.get_tree()
		if tree.has_meta("settings_scenery_quality"):
			return int(tree.get_meta("settings_scenery_quality"))
	return int(load_settings().scenery_quality)

func apply_scenery_quality(context: Node, quality: int) -> void:
	if not is_instance_valid(context) or not context.is_inside_tree():return
	context.get_tree().set_meta("settings_scenery_quality",quality)
	for controller in context.get_tree().get_nodes_in_group("distant_scenery_quality"):
		if is_instance_valid(controller) and controller.has_method("set_quality"):
			controller.call("set_quality",quality)

# Additive v7: fine trader materials are independent from grass and distant scenery.
func upgrade_settings(candidate: Variant) -> Variant:
	var old=upgrade_scenery(candidate)
	if not old is Dictionary or not numeric(old.get("version")) or old.version!=6:return old
	if not validate_schema(old,6).is_empty():return old
	var upgraded=old.duplicate(true)
	upgraded.version=7
	upgraded.material_detail_quality=2
	return upgraded

func current_material_detail_quality(context: Node) -> int:
	if is_instance_valid(context) and context.is_inside_tree():
		var tree=context.get_tree()
		if tree.has_meta("settings_material_detail_quality"):
			return int(tree.get_meta("settings_material_detail_quality"))
	return int(load_settings().material_detail_quality)

func apply_material_detail_quality(context: Node, quality: int) -> void:
	if not is_instance_valid(context) or not context.is_inside_tree():return
	context.get_tree().set_meta("settings_material_detail_quality",quality)
	for controller in context.get_tree().get_nodes_in_group("material_detail_quality"):
		if is_instance_valid(controller) and controller.has_method("set_quality"):
			controller.call("set_quality",quality)
