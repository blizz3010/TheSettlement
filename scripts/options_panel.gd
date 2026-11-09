extends PanelContainer
signal closed
signal quit_requested
const Settings = preload("res://scripts/game_settings.gd")
# Help names only implemented controls and registered scene owners. Numeric tiers,
# migration, Apply/Cancel and display confirmation retain their existing contract.
const FIELD_HELP = {
 "display_mode": "Windowed uses the selected window size. Borderless and fullscreen use the current monitor. Apply previews display changes for 15 seconds; Keep saves them, otherwise they revert.",
 "resolution": "Window size in pixels, used only in windowed mode. Borderless and fullscreen use the monitor's native resolution. Apply requires Keep to save display changes.",
 "vsync": "Synchronizes frame presentation with your display to reduce tearing. It may limit the frame rate below the selected frame cap. Driver behavior can vary.",
 "msaa": "Smooths the edges of 3D geometry. Higher sample counts use more graphics resources; this does not increase texture detail or UI resolution.",
 "fps_limit": "Caps rendered frames per second. Unlimited removes this cap; V-Sync, hardware and scene load may still limit the actual rate.",
 "shadows_enabled": "Turns scene-light shadows off or restores each light's original shadow setting. Deliberately shadowless fill lights stay shadowless; object visibility and collision do not change.",
 "grass_quality": "Changes registered plaza, settlement-ground and north-riverbank grass density and viewing distance. It does not change distant trees, garden layouts, routes or collision. High is the default.",
 "scenery_quality": "Changes the registered distant-valley forest, north woodland and added north trees: density and viewing distance. Terrain, lake, near gardens and retained original trees stay in place. High is the default.",
 "material_detail_quality": "Changes registered shop and route surface detail, plus optional close shop and ship geometry. Low keeps signs, staff, stock silhouettes, ship hull, engines, gear and interactions. Structural inn, Hall and home details stay visible at every tier. High is the default; this is not a global texture-resolution setting.",
 "audio_output_device": "Routes game audio to a device without changing your system default. Apply saves the preference. If the device is unavailable, game audio uses System default and retains the preferred device.",
 "master": "Overall game volume. Zero mutes all game audio; Music and SFX remain independently adjustable.",
 "music": "Music-bus volume, also affected by Master volume. Zero mutes music.",
 "sfx": "World and interaction sound-bus volume, also affected by Master volume. Zero mutes those sounds.",
 "sensitivity": "Sets how quickly mouse movement turns the view. Lower values turn more slowly. Changes take effect after Apply.",
 "invert_y": "Reverses vertical mouse-look direction. Changes take effect after Apply."
}
const BINDING_HELP = {
 "forward": "Move forward.", "backward": "Move backward.", "left": "Move left.", "right": "Move right.",
 "sprint": "Hold to sprint.", "jump": "Jump.", "crouch": "Hold to crouch.", "interact": "Interact with the focused service or object.",
 "inventory": "Open or close inventory.", "view": "Switch camera view.", "build": "Open or close the building-piece selector.",
 "rotate": "Rotate the selected building piece.", "map": "Open or close the map.", "quests": "Open or close the quest journal.", "skills": "Open or close the skills overview."
}
const ACTION_HELP = {
 "Refresh output devices": "Rescan audio devices. Unsaved output changes are not previewed; the committed preference is used, with System default as its fallback.",
 "Keep": "Save the previewed display and all other draft settings. If saving fails, the previous settings are restored.",
 "Revert": "Restore all committed settings and discard this display preview.",
 "Cancel Quit": "Stay in the game without saving or quitting.",
 "Save and Quit": "Save game progress, then quit. A failed game save leaves the game open. Unapplied option edits are not saved.",
 "Back to Menu": "Discard unapplied options and return to the title menu. An unconfirmed display preview is reverted.",
 "Back to Game": "Discard unapplied options and return to the game. An unconfirmed display preview is reverted.",
 "Apply": "Save and apply this draft. Display changes require Keep within 15 seconds.",
 "Cancel": "Discard unapplied changes and revert an unconfirmed display preview. Stay in Options.",
 "Restore Defaults": "Select default values in the draft. Nothing is saved until Apply; Cancel restores your current settings.",
 "Quit": "Ask whether to save progress and quit. An unconfirmed display preview is reverted first."
}
var backend = Settings.new()
var current: Dictionary
var draft: Dictionary
var previous: Dictionary = {}
var player
var tabs: TabContainer
var fields = {}
var value_labels = {}
var binding_buttons = {}
var status: Label
var confirm_row: VBoxContainer
var confirmation: Label
var remaining := 0.0
var display_deadline := 0
var capture_action := ""
var quit_pending := false
var quit_row: HBoxContainer
var save_callback: Callable
var title_context := false
var back_button: Button
var audio_note: Label
var audio_rescan: Button
const WORLD_KEYS = ["grass_quality", "scenery_quality", "material_detail_quality"]
const SHORT_HELP = {
 "display_mode": "Choose a window or use the whole monitor. Display changes have a 15-second safety preview.",
 "resolution": "Window size. Fullscreen and borderless use your monitor’s native resolution.",
 "vsync": "Reduce screen tearing. This can limit your frame rate.",
 "msaa": "Smooth object edges. Higher levels need more graphics power.",
 "fps_limit": "Limit frame rate to balance smoothness and power use.",
 "shadows_enabled": "Enable scene shadows. This is independent of the world preset.",
 "grass_quality": "Adjust grass density and how far away it appears.",
 "scenery_quality": "Adjust distant trees and woodland density and viewing distance.",
 "material_detail_quality": "Adjust surface detail and small decorative objects. Essential structures remain visible.",
 "world_preset": "Set grass, distant scenery and material detail together. Display and image settings stay unchanged."
}
var world_preset: OptionButton
var focused_help: Label
var detail_help: Label
var detail_panel: ScrollContainer
var detail_toggle: Button


func setup(actor, saver: Callable, from_title := false):
	title_context=from_title
	player = actor
	save_callback = saver
	current = backend.load_settings()
	backend.apply(current,player,get_viewport())
	draft = current.duplicate(true)
	build_ui()
	hide()

func build_ui():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=preload("res://scripts/options_theme.gd").make_theme()
	var style = preload("res://scripts/options_theme.gd").frame("171c1c","b29462",18)
	add_theme_stylebox_override("panel",style)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",10);add_child(column)
	var heading=Label.new();heading.text="SETTLEMENT  /  OPTIONS";heading.add_theme_font_size_override("font_size",26);heading.add_theme_font_override("font",preload("res://assets/fonts/DejaVuSerif.ttf"));column.add_child(heading)
	tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(tabs)
	var graphics=tab("Graphics");graphics.add_theme_constant_override("separation",8)
	var columns=HBoxContainer.new();columns.add_theme_constant_override("separation",32);graphics.add_child(columns)
	var display=VBoxContainer.new();display.size_flags_horizontal=Control.SIZE_EXPAND_FILL;display.size_flags_stretch_ratio=1;display.add_theme_constant_override("separation",6);columns.add_child(display)
	var world=VBoxContainer.new();world.size_flags_horizontal=Control.SIZE_EXPAND_FILL;world.size_flags_stretch_ratio=1;world.add_theme_constant_override("separation",6);columns.add_child(world)
	section(display,"DISPLAY", "Screen and image settings")
	choice(display,"Display mode","display_mode",["windowed","borderless","fullscreen"])
	var resolutions=["1280 × 720","1440 × 900","1920 × 1080","2560 × 1440"]
	if DisplayServer.get_name()!="headless":
		var native=DisplayServer.screen_get_size();var label="%d × %d"%[native.x,native.y]
		if not label in resolutions: resolutions.append(label)
	choice(display,"Windowed resolution","resolution",resolutions)
	check(display,"V-Sync","vsync")
	choice(display,"Anti-aliasing (MSAA)","msaa",["Off","2×","4×","8×"])
	choice(display,"Frame limit","fps_limit",["Unlimited","30 FPS","60 FPS","90 FPS","120 FPS","144 FPS","165 FPS","240 FPS"])
	check(display,"Scene shadows","shadows_enabled")
	section(world,"WORLD QUALITY", "Balance world detail and performance")
	world_preset=OptionButton.new();world_preset.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row(world,"World preset").add_child(world_preset)
	for title in ["Low","Medium","High","Ultra","Custom"]:world_preset.add_item(title)
	world_preset.set_item_disabled(4,true)
	set_field_help(world_preset,"world_preset")
	world_preset.item_selected.connect(select_world_preset)
	choice(world,"Grass quality","grass_quality",["Low","Medium","High","Ultra"])
	choice(world,"Distant scenery","scenery_quality",["Low","Medium","High","Ultra"])
	choice(world,"Material detail","material_detail_quality",["Low","Medium","High","Ultra"])
	focused_help=Label.new();focused_help.custom_minimum_size.y=44;focused_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;graphics.add_child(focused_help)
	detail_toggle=button(graphics,"Detailed help",func(): detail_panel.visible=not detail_panel.visible;detail_toggle.text="Hide detailed help" if detail_panel.visible else "Detailed help")
	detail_toggle.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	detail_panel=ScrollContainer.new();detail_panel.custom_minimum_size.y=72;graphics.add_child(detail_panel)
	detail_help=Label.new();detail_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail_help.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_panel.add_child(detail_help);detail_panel.hide()
	show_field_help("world_preset")
	var sound=tab("Sound")
	section(sound,"AUDIO MIX", "Set music and world sounds independently.")
	var output=OptionButton.new();output.fit_to_longest_item=false;output.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;row(sound,"Audio output device").add_child(output);fields["audio_output_device"]=output;set_field_help(output,"audio_output_device")
	output.item_selected.connect(func(index): draft.audio_output_device=output.get_item_metadata(index);update_audio_note())
	audio_rescan=button(sound,"Refresh output devices",refresh_audio_devices)
	audio_note=Label.new();audio_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;sound.add_child(audio_note)
	for key in ["master","music","sfx"]: slider(sound,key.capitalize()+" volume",key,0,1,0.05)
	var controls=tab("Controls")
	section(controls,"LOOK & KEY BINDINGS", "Select an action, then press its new key.")
	slider(controls,"Mouse sensitivity","sensitivity",0.0005,0.006,0.0001)
	check(controls,"Invert vertical look","invert_y")
	for action in current.bindings:
		var row=HBoxContainer.new();controls.add_child(row)
		var label=Label.new();label.text="Crouch (hold)" if action=="crouch" else ("Quest journal" if action=="quests" else ("Skills overview" if action=="skills" else action.capitalize().replace("_"," ")));label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
		var button=Button.new();button.custom_minimum_size.x=160;row.add_child(button);binding_buttons[action]=button
		button.tooltip_text=BINDING_HELP.get(action,action.capitalize().replace("_"," "))+" Select, then press a unique keyboard key. Esc cancels; reserved menu, building and save keys cannot be assigned. Apply saves changes."
		button.pressed.connect(func(): capture_action=action;status.text="Press a key for "+action+" (Esc cancels).")
	var fixed=Label.new();fixed.text="Fixed: Esc menu/back • 1–6 quickslots outside build • 1–0 building pieces • Page Up/Down floor • F5 save • F9 load • Mouse buttons place/remove";fixed.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;controls.add_child(fixed)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
	confirm_row=VBoxContainer.new();column.add_child(confirm_row)
	confirmation=Label.new();confirmation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;confirmation.size_flags_horizontal=Control.SIZE_EXPAND_FILL;confirm_row.add_child(confirmation)
	button(confirm_row,"Keep",keep_display);button(confirm_row,"Revert",revert_display);confirm_row.hide()
	quit_row=HBoxContainer.new();column.add_child(quit_row)
	button(quit_row,"Cancel Quit",cancel_quit);button(quit_row,"Save and Quit",confirm_quit);quit_row.hide()
	var actions=HFlowContainer.new();column.add_child(actions)
	back_button=button(actions,"Back to Menu" if title_context else "Back to Game",cancel_and_close);button(actions,"Apply",apply_draft);button(actions,"Cancel",cancel_changes);button(actions,"Restore Defaults",restore_defaults)
	if not title_context:button(actions,"Quit",request_quit)
	sync_fields()
func section(parent:Node, title:String, detail:String):
	var heading=Label.new();heading.text=title;heading.add_theme_font_size_override("font_size",18);heading.add_theme_color_override("font_color",Color("c6a975"));parent.add_child(heading)
	var note=Label.new();note.text=detail;note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.add_theme_color_override("font_color",Color("aebbb1"));parent.add_child(note)
func tab(title: String) -> VBoxContainer:
	var scroll=ScrollContainer.new();scroll.name=title;tabs.add_child(scroll)
	var body=VBoxContainer.new();body.add_theme_constant_override("separation",12);body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(body)
	return body
func button(parent: Node,title: String,callback: Callable):
	var control=Button.new();control.text=title;control.tooltip_text=ACTION_HELP.get(title,"");control.custom_minimum_size.y=36;parent.add_child(control);control.pressed.connect(callback);return control
func row(parent: Node,title: String) -> HBoxContainer:
	var result=HBoxContainer.new();result.add_theme_constant_override("separation",12);parent.add_child(result)
	var label=Label.new();label.text=title;label.custom_minimum_size.x=190;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;result.add_child(label);return result
func set_field_help(control:Control,key:String):
	control.tooltip_text=FIELD_HELP.get(key,SHORT_HELP.get(key,""))
	control.focus_entered.connect(func(): show_field_help(key))
	control.mouse_entered.connect(func(): show_field_help(key))
func choice(parent,title,key,values):
	var control=OptionButton.new();control.size_flags_horizontal=Control.SIZE_EXPAND_FILL;control.custom_minimum_size.x=170;row(parent,title).add_child(control)
	for value in values: control.add_item(value)
	fields[key]=control;set_field_help(control,key)
	control.item_selected.connect(func(index):
		if key=="resolution":
			var parts=control.get_item_text(index).split(" × ");draft[key]=[int(parts[0]),int(parts[1])]
		elif key=="msaa": draft[key]=[0,2,4,8][index]
		elif key=="fps_limit": draft[key]=Settings.FRAME_CAPS[index]
		elif key in WORLD_KEYS: draft[key]=index;sync_world_preset()
		else: draft[key]=values[index])
func check(parent,title,key):
	var control=CheckButton.new();control.size_flags_horizontal=Control.SIZE_SHRINK_END;control.custom_minimum_size.x=60;row(parent,title).add_child(control);fields[key]=control;set_field_help(control,key)
	control.toggled.connect(func(value): draft[key]=value)
func slider(parent,title,key,low,high,step):
	var container=row(parent,title)
	var control=HSlider.new();control.min_value=low;control.max_value=high;control.step=step;control.custom_minimum_size.x=150;control.size_flags_horizontal=Control.SIZE_EXPAND_FILL;container.add_child(control);fields[key]=control;set_field_help(control,key)
	value_labels[key]=[container.get_child(0),title]
	control.value_changed.connect(func(value): draft[key]=value;update_value_labels())
func sync_fields():
	for key in fields:
		var control=fields[key]
		if control is CheckButton: control.set_pressed_no_signal(draft[key])
		elif control is HSlider: control.set_value_no_signal(draft[key])
		elif key=="msaa": control.select([0,2,4,8].find(int(draft[key])))
		elif key=="fps_limit": control.select(Settings.FRAME_CAPS.find(int(draft[key])))
		elif key in ["grass_quality","scenery_quality","material_detail_quality"]: control.select(int(draft[key]))
		elif key=="audio_output_device": refresh_audio_devices()
		elif key=="display_mode": control.select(["windowed","borderless","fullscreen"].find(draft[key]))
		else:
			var label="%d × %d"%[draft.resolution[0],draft.resolution[1]]
			var index=-1
			for i in control.item_count:
				if control.get_item_text(i)==label:index=i
			if index<0:control.add_item(label);index=control.item_count-1
			control.select(index)
	sync_world_preset()
	update_value_labels()
	for action in binding_buttons: binding_buttons[action].text=OS.get_keycode_string(int(draft.bindings[action]))
func open():
	draft=current.duplicate(true);capture_action="";quit_pending=false;quit_row.hide();status.text=backend.migration_notice;sync_fields();show();back_button.grab_focus()
func _input(event):
	if not visible:return
	if event is InputEventKey and event.pressed and not event.echo:
		if not capture_action.is_empty():
			get_viewport().set_input_as_handled()
			if event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_ESCAPE:capture_action="";status.text="Binding cancelled.";return
			var candidate=draft.duplicate(true);candidate.bindings[capture_action]=event.physical_keycode if event.physical_keycode else event.keycode
			var error=backend.validate(candidate)
			if error.is_empty():draft=candidate;capture_action="";status.text="";sync_fields()
			else:status.text=error
		elif event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_ESCAPE:
			for control in fields.values()+[world_preset]:
				if control is OptionButton and control.get_popup().visible:return
			get_viewport().set_input_as_handled()
			if remaining>0:revert_display()
			elif quit_pending:cancel_quit()
			else:cancel_and_close()
func apply_draft():
	if remaining>0:return
	capture_action="";cancel_quit()
	var error=backend.validate(draft)
	if not error.is_empty():status.text=error;return
	if draft.display_mode!=current.display_mode or draft.resolution!=current.resolution:
		previous=current.duplicate(true);backend.apply(draft,player,get_viewport());remaining=15.0;display_deadline=Time.get_ticks_msec()+15000;confirm_row.show();set_fields_enabled(false);confirm_row.get_child(2).grab_focus();return
	commit_settings()
func commit_settings():
	if not backend.save_settings(draft):status.text=backend.last_error;backend.apply(current,player,get_viewport());return
	current=draft.duplicate(true);backend.apply(current,player,get_viewport());status.text="Settings applied.";update_audio_note()
func keep_display():
	if remaining<=0:return
	# Input may arrive before the next process tick after a stall.
	if Time.get_ticks_msec()>=display_deadline:
		revert_display()
		return
	remaining=0;confirm_row.hide();set_fields_enabled(true);commit_settings();previous={};restore_action_focus()
func revert_display():
	remaining=0;confirm_row.hide();set_fields_enabled(true);backend.apply(current,player,get_viewport());draft=current.duplicate(true);previous={};sync_fields();status.text="Display changes reverted.";restore_action_focus()
func _process(_delta):
	if remaining>0:
		remaining=maxf(0.0,(display_deadline-Time.get_ticks_msec())/1000.0);confirmation.text="Keep display settings? Reverting in %d s"%ceili(remaining)
		if remaining<=0:revert_display()
func cancel_changes():
	if remaining>0:revert_display()
	draft=current.duplicate(true);capture_action="";cancel_quit();sync_fields();status.text="Changes cancelled."
func restore_defaults():
	if remaining>0:revert_display()
	draft=backend.defaults();capture_action="";cancel_quit();sync_fields();status.text="Defaults selected. Apply to save."
func cancel_and_close():
	cancel_changes();hide();closed.emit()
func request_quit():
	if title_context:return
	if remaining>0:revert_display()
	capture_action="";quit_pending=true;set_fields_enabled(false);quit_row.show();quit_row.get_child(0).grab_focus()
	status.text="Save your progress and quit the game?"
func cancel_quit():
	quit_pending=false;quit_row.hide();set_fields_enabled(true);status.text="";restore_action_focus()
func restore_action_focus():
	if not visible or not is_instance_valid(back_button):return
	var owner=get_viewport().gui_get_focus_owner()
	if owner==null or not owner.is_visible_in_tree():back_button.grab_focus()
func confirm_quit():
	if not quit_pending:return
	if not save_callback.call():status.text="Save failed. The game remains open. Retry Save and Quit or cancel.";return
	quit_requested.emit()

func set_fields_enabled(value: bool):
	world_preset.disabled=not value
	for control in fields.values():
		if control is HSlider: control.editable=value
		else: control.disabled=not value
	for control in binding_buttons.values():control.disabled=not value
	if is_instance_valid(audio_rescan):audio_rescan.disabled=not value

func update_value_labels():
	for key in value_labels:
		var item=value_labels[key]
		item[0].text=item[1]+("  %.4f"%draft[key] if key=="sensitivity" else "  %d%%"%roundi(draft[key]*100))

func refresh_audio_devices():
	var control: OptionButton=fields.audio_output_device
	control.clear()
	var devices=backend.output_devices()
	for device in devices:
		control.add_item("System default" if device=="Default" else device)
		control.set_item_metadata(control.item_count-1,device)
	var selected=devices.find(draft.audio_output_device)
	if selected<0:
		control.add_item(draft.audio_output_device+" (unavailable — using default)")
		selected=control.item_count-1
		control.set_item_metadata(selected,draft.audio_output_device)
	control.select(selected)
	# Reconcile committed preference only: rescanning never previews unsaved edits.
	if remaining<=0: backend.apply_audio_output(current.audio_output_device)
	update_audio_note()

func update_audio_note():
	if not is_instance_valid(audio_note):return
	if not draft.audio_output_device in backend.output_devices():
		audio_note.text="Preferred device unavailable. System default is used; your preferred device is retained. Refresh after reconnecting."
	else:
		audio_note.text="Game audio only. Choose an output and Apply; this does not change your system default."

func sync_world_preset():
	var tier=int(draft.grass_quality)
	world_preset.select(tier if draft.scenery_quality==tier and draft.material_detail_quality==tier else 4)

func select_world_preset(index:int):
	if index<0 or index>3 or world_preset.disabled:return
	for key in WORLD_KEYS:draft[key]=index
	sync_fields()

func show_field_help(key:String):
	if not is_instance_valid(focused_help) or not key in SHORT_HELP:return
	focused_help.text=SHORT_HELP[key]
	detail_help.text=FIELD_HELP.get(key,SHORT_HELP[key])
