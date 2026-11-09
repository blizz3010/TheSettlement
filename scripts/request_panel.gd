extends PanelContainer
signal action_requested(action: String)
signal closed
var body:VBoxContainer
var details: Label
var action_button: Button
var feedback_label: Label
var current_action := "accept"
func _ready():
	name = "StarterRequestPanel"
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -280
	offset_right = 280
	offset_top = -245
	offset_bottom = 245
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(560,490)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("182a29")
	style.border_color = Color("b89b61")
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel",style)
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	var column = VBoxContainer.new();body=column;column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",14)
	scroll.add_child(column)
	var heading = Label.new()
	heading.text = "REQUEST BOARD • Scroll for all requests"
	heading.add_theme_font_size_override("font_size",22)
	column.add_child(heading)
	details = Label.new()
	details.custom_minimum_size.x = 510
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(details)
	feedback_label = Label.new()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.custom_minimum_size = Vector2(510,42)
	column.add_child(feedback_label)
	action_button = Button.new()
	action_button.custom_minimum_size.y = 44
	action_button.pressed.connect(func(): action_requested.emit(current_action))
	column.add_child(action_button)
	var close = Button.new()
	close.text = "Return to settlement"
	close.custom_minimum_size.y = 40
	close.pressed.connect(func(): closed.emit())
	column.add_child(close)
	hide()
func render(request, inventory, feedback := ""):
	details.text = "COURTYARD REPAIRS • One-time starter request • local prototype\nHelp stock the courtyard repair supplies.\nTimber: 2 required / %d carried\nMetal scrap: 1 required / %d carried\nReward: 25 settlement credits, once.\nOnly carried materials are consumed.\nHome Stash and Lockbox stay untouched.\nPrototype amounts; no daily reset or shared progress." % [inventory.amount("carried","timber"),inventory.amount("carried","metal")]
	current_action = "accept" if request.status == "not_started" else "deliver"
	action_button.disabled = request.status == "completed" or (request.status == "active" and not request.ready_to_deliver(inventory))
	action_button.text = "Accept request • no materials spent" if request.status == "not_started" else ("Completed • reward received" if request.status == "completed" else "Deliver 2 Timber + 1 Metal scrap • receive 25 credits")
	feedback_label.text = feedback if not feedback.is_empty() else ("Completed and saved. This request does not repeat." if request.status == "completed" else ("Accepted. Bring the listed materials in carried inventory." if request.status == "active" else "Review the materials and reward, then accept."))
