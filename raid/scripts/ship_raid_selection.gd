extends CanvasLayer
## Allowlisted destinations; confirmation is separate from the boarding input.
signal deploy_requested(raid_id: String)
signal cancelled
var panel: PanelContainer
var deploy_button: Button
var cancel_button: Button
var destination: Label
var description: Label
var selected_raid_id := "relay_ridge"
var raid_buttons: Dictionary = {}
const Catalog = preload("res://raid/scripts/raid_catalog.gd")

func _ready():
	layer = 110
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade = ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.03, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("101f25")
	style.border_color = Color("a78c59")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	_label(column, "SELECT RAID", 26, Color("f3e8d0"))
	_label(column, "%d destinations available" % Catalog.RAIDS.size(), 15, Color("a9bcb8"))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 12)
	scroll.add_child(details)
	for raid_id in Catalog.RAIDS:
		var item = Catalog.RAIDS[raid_id]
		var button = _button(details, item.name + "  ·  " + item.subtitle, func(): select_raid(raid_id))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		raid_buttons[raid_id] = button
	destination = _label(details, "", 23, Color("8ee0bc"))
	description = _label(details, "", 17)
	_label(details, "Development previews: no enemies or persistent loot. Deploy saves your settlement first. Extraction returns the same character at Town Hall.", 16, Color("cfbf9e"))
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	column.add_child(actions)
	cancel_button = _button(actions, "Cancel", func(): cancelled.emit())
	deploy_button = _button(actions, "Deploy", func(): deploy_requested.emit(selected_raid_id))
	select_raid(selected_raid_id)
	get_viewport().size_changed.connect(_layout)
	panel.minimum_size_changed.connect(func(): call_deferred("_layout"))
	_layout()
	call_deferred("_layout")
	# The key that opened the selector can never also confirm travel.
	cancel_button.grab_focus()

func _label(parent: Node, text: String, font_size: int, color: Color = Color("e1e8e3")) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _layout():
	var viewport_size = get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(660, viewport_size.x - 32), minf(560, viewport_size.y - 32))
	panel.position = (viewport_size - panel.size) * 0.5

func select_raid(raid_id: String):
	if not Catalog.contains(raid_id): return
	selected_raid_id = raid_id
	for item_id in raid_buttons:
		raid_buttons[item_id].set_pressed_no_signal(item_id == raid_id)
	destination.text = Catalog.display_name(raid_id) + "  •  Selected"
	description.text = Catalog.RAIDS[raid_id].description
	deploy_button.text = "Deploy to " + Catalog.display_name(raid_id)
