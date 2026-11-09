extends PanelContainer
signal closed
signal sample_changed
const MenuTheme=preload("res://scripts/shop_theme.gd")
const Model=preload("res://scripts/cooking_test_state.gd")
var session
var action_allowed:Callable
var summary:Label
var details:Label
var feedback:Label
var tray_summary:Label
var recipes_row:GridContainer
var step_button:Button
var cancel_button:Button
var close_button:Button
var reset_button:Button
var content_scroll:ScrollContainer
var help_button:Button
var help_text:Label
var sample_labels:Dictionary={}
var help_request:int=0
var tray_meter:ProgressBar
var readiness:Label
const Icons=preload("res://scripts/cooking_test_icons.gd")
func fit_panel():
	var size=get_viewport().get_visible_rect().size
	var width=minf(860,size.x-24);var height=minf(560,size.y-24)
	offset_left=-width/2;offset_right=width/2;offset_top=-height/2;offset_bottom=height/2
	if is_instance_valid(recipes_row):recipes_row.columns=1 if width<720 else 2
	if is_instance_valid(help_text) and help_text.visible:reveal_help()
func _ready():
	visibility_changed.connect(func():help_request+=1)
	set_anchors_preset(Control.PRESET_CENTER);fit_panel()
	get_viewport().size_changed.connect(fit_panel)
	theme=MenuTheme.make_theme();theme.default_font_size=16
	add_theme_stylebox_override("panel",MenuTheme.frame("182622","a28b60",18))
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",8);add_child(column)
	var header=HBoxContainer.new();column.add_child(header)
	var title=Label.new();title.add_theme_font_override("font",MenuTheme.heading_font());title.text="CAMPFIRE GRIDDLE";title.add_theme_font_size_override("font_size",24);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	help_button=Button.new();help_button.text="About this test";header.add_child(help_button)
	var banner=Label.new();banner.text="COOKING TEST  •  Free samples stay here for this session";banner.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;banner.add_theme_color_override("font_color",Color("c6a975"));column.add_child(banner)
	content_scroll=ScrollContainer.new();content_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;content_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(content_scroll)
	var body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",8);content_scroll.add_child(body)
	summary=Label.new();summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(summary)
	readiness=Label.new();readiness.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(readiness)
	recipes_row=GridContainer.new();recipes_row.columns=2;recipes_row.add_theme_constant_override("h_separation",10);recipes_row.add_theme_constant_override("v_separation",8);body.add_child(recipes_row)
	details=Label.new();details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.custom_minimum_size.y=50;body.add_child(details)
	var actions=HBoxContainer.new();body.add_child(actions)
	step_button=Button.new();step_button.custom_minimum_size.y=38;step_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(step_button)
	cancel_button=Button.new();cancel_button.text="Cancel";cancel_button.tooltip_text="Cancel unfinished preparation without using ingredients.";actions.add_child(cancel_button)
	feedback=Label.new();feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;feedback.custom_minimum_size.y=36;body.add_child(feedback)
	tray_summary=Label.new();body.add_child(tray_summary)
	tray_meter=ProgressBar.new();tray_meter.max_value=Model.TRAY_LIMIT;tray_meter.show_percentage=false;tray_meter.custom_minimum_size.y=8;body.add_child(tray_meter)
	var samples=HBoxContainer.new();samples.add_theme_constant_override("separation",24);body.add_child(samples)
	for id in ["glade_fillet","ember_leaf"]:
		var row=HBoxContainer.new();samples.add_child(row)
		var icon=TextureRect.new();icon.texture=Icons.texture(id);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2(40,40);row.add_child(icon)
		var label=Label.new();row.add_child(label);sample_labels[id]=label
	help_text=Label.new();help_text.text="Samples cannot be eaten, sold or carried. No food benefits, XP or rewards. No real inventory is used. Closing keeps prepared samples but cancels unfinished prep. Reset restocks 4 fish + 4 leaves and clears the 4-sample tray; these are test limits, not player storage. Everything clears when this world/game session ends.";help_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;help_text.add_theme_font_size_override("font_size",14);help_text.hide();body.add_child(help_text)
	help_button.pressed.connect(toggle_help)
	var footer=HBoxContainer.new();column.add_child(footer)
	reset_button=Button.new();reset_button.text="Reset test samples";reset_button.tooltip_text="Restock the free test pantry and clear this station's samples.";footer.add_child(reset_button)
	var gap=Control.new();gap.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(gap)
	close_button=Button.new();close_button.text="Close";close_button.tooltip_text="Esc also closes. Pantry and prepared samples stay for this session.";close_button.custom_minimum_size.x=100;footer.add_child(close_button)
	close_button.pressed.connect(func():closed.emit());fit_panel();hide()
func help_request_live(token:int) -> bool:
	return token==help_request and is_inside_tree() and is_visible_in_tree() and is_instance_valid(help_text) and is_instance_valid(content_scroll) and help_text.visible
func reveal_help():
	help_request+=1
	var token=help_request
	if not help_request_live(token):return
	var tree=get_tree()
	# Captured tree and generation prevent delayed work after hide/remove/reopen.
	await tree.process_frame
	if not help_request_live(token):return
	await tree.process_frame
	if help_request_live(token):content_scroll.ensure_control_visible(help_text)
func _exit_tree():help_request+=1
func toggle_help():
	help_text.visible=not help_text.visible
	if help_text.visible:reveal_help()
	else:content_scroll.scroll_vertical=0
	help_button.grab_focus()
func open(model):
	session=model;help_text.hide();content_scroll.scroll_vertical=0;render();show();close_button.grab_focus()
func wire(button:Button,callback:Callable):
	for connection in button.pressed.get_connections():button.pressed.disconnect(connection.callable)
	button.pressed.connect(callback)
func act(action:String,expected:int,recipe:String=""):
	if not visible or session==null or session.disposed:return
	if not action_allowed.is_valid() or not action_allowed.call():closed.emit();return
	var ok=false
	match action:
		"review":ok=session.review(recipe,expected)
		"advance":ok=session.advance(expected)
		"finish":ok=session.finish(expected)
		"cancel":ok=session.cancel(expected)
		"reset":ok=session.reset_test_samples(expected)
		_:return
	var message=session.last_error if not ok else ("Sample ready on the griddle." if action=="finish" else "Cancelled. Ingredients kept." if action=="cancel" else "Test pantry restocked; tray cleared." if action=="reset" else "Take your time — no timer or score.")
	render(message)
	if not session.pending.is_empty():step_button.grab_focus()
	elif recipes_row.get_child_count()>0:
		var available=false
		for button in recipes_row.get_children():
			if not button.disabled:button.grab_focus();available=true;break
		if not available:reset_button.grab_focus()
	else:close_button.grab_focus()
	sample_changed.emit()
func render(message:String=""):
	if session==null or session.disposed:hide();return
	var rev=session.revision
	summary.text="Pantry    Fish portions: %d    •    Leaf portions: %d"%[session.pantry.test_fish_portion,session.pantry.test_flora_portion]
	for child in recipes_row.get_children():recipes_row.remove_child(child);child.queue_free()
	var full=session.tray_used()>=Model.TRAY_LIMIT
	tray_meter.value=session.tray_used()
	readiness.text="Tray full. Reset test samples to clear it and restock; no real inventory is affected." if full else ("Preparation in progress. Cancel keeps the test ingredients." if not session.pending.is_empty() else "Choose an available recipe. One test portion makes one inspection sample.")
	for id in Model.recipes():
		var recipe=Model.recipes()[id]
		var available=int(session.pantry[recipe.input])
		var reason="Tray full" if full else ("No portions left" if available==0 else ("Preparation in progress" if not session.pending.is_empty() else "%d test portions available"%available))
		var button=Button.new();button.text=recipe.name+"\n"+reason;button.tooltip_text=recipe.detail+"\n"+reason;button.icon=Icons.texture(id);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",56);button.custom_minimum_size.y=76;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.disabled=not session.pending.is_empty() or full or available==0;recipes_row.add_child(button)
		button.pressed.connect(act.bind("review",rev,id))
	var pending=session.pending
	details.text="Choose a recipe, prepare it in two untimed steps, then finish a sample."
	step_button.visible=not pending.is_empty();cancel_button.visible=not pending.is_empty()
	step_button.disabled=full
	step_button.tooltip_text="Reset test samples to clear the full tray, or Cancel to keep ingredients." if full else "Untimed preparation. Ingredients are consumed only when Finish succeeds."
	if not pending.is_empty():
		var fish=pending.recipe=="glade_fillet"
		var steps=["Sear", "Turn", "Finish sample"] if fish else ["Spread", "Toast", "Finish sample"]
		var trail=[]
		for i in range(3):trail.append("["+steps[i]+"]" if i==int(pending.step) else steps[i])
		details.text=("1 fish portion → 1 browned fillet" if fish else "1 leaf portion → 1 toasted leaf sample")+"\n"+"  →  ".join(PackedStringArray(trail))
		step_button.text="%d / 3  ·  %s"%[int(pending.step)+1,steps[int(pending.step)]]
		wire(step_button,act.bind("finish" if int(pending.step)==2 else "advance",rev))
	wire(cancel_button,act.bind("cancel",rev));wire(reset_button,act.bind("reset",rev))
	feedback.text=message
	tray_summary.text="Prepared samples    %d / 4"%session.tray_used()
	sample_labels.glade_fillet.text="Fillet × %d"%session.tray.test_glade_fillet
	sample_labels.ember_leaf.text="Leaves × %d"%session.tray.test_ember_leaf
