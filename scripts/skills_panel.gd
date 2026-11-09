extends PanelContainer
signal closed
const Overview=preload("res://scripts/skills_overview.gd")
var body:VBoxContainer
var scroll:ScrollContainer
var close_button:Button
var binding_note:Label
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	theme=preload("res://scripts/options_theme.gd").make_theme()
	add_theme_stylebox_override("panel",preload("res://scripts/options_theme.gd").frame("171c1cf8","b29462",18))
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",10);add_child(column)
	var header=HBoxContainer.new();column.add_child(header)
	var title=Label.new();title.text="SETTLEMENT  /  SKILLS";title.add_theme_font_size_override("font_size",26);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	close_button=Button.new();close_button.text="Close";close_button.custom_minimum_size=Vector2(90,36);header.add_child(close_button);close_button.pressed.connect(func():closed.emit())
	binding_note=Label.new();binding_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(binding_note)
	var intro=Label.new();intro.text="Overview only. Skill XP, levels, perks and practice credit are not implemented.";intro.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(intro)
	scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",12);scroll.add_child(body)
	for group in Overview.groups():
		var heading=Label.new();heading.text=group.title;heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;heading.add_theme_font_size_override("font_size",20);heading.add_theme_color_override("font_color",Color("c6a975"));body.add_child(heading)
		for row in group.rows:
			var card=PanelContainer.new();card.add_theme_stylebox_override("panel",preload("res://scripts/options_theme.gd").frame("232d29","526252",10));body.add_child(card)
			var label=Label.new();label.text=row[0]+"\n"+row[1];label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",18);card.add_child(label)
	var footer=Label.new();footer.text="No actions or rewards here. Quest objectives are in the separate quest journal. The world continues while this menu is open.";footer.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(footer)
	hide()
func render(key:String,notice:String=""):
	binding_note.text="%s / Esc closes  •  Read-only overview"%key
	if not notice.is_empty():binding_note.text+="\n"+notice
	scroll.scroll_vertical=0
	show();close_button.grab_focus()
