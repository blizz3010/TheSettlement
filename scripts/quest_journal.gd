extends PanelContainer
# Presentation only. No quest commands, transactions or persistent state.
signal closed
const JournalProjection=preload("res://scripts/quest_journal_projection.gd")
var body:VBoxContainer
var scroll:ScrollContainer
var close_button:Button
var binding_note:Label
var displayed_entries:Array=[]
const FILTERS = ["All", "Active", "Available at board", "Completed"]
var selected_filter := "All"
var filter_buttons: Dictionary = {}
var entry_summary: Label
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	theme=preload("res://scripts/options_theme.gd").make_theme()
	add_theme_stylebox_override("panel",preload("res://scripts/options_theme.gd").frame("171c1cf8","b29462",18))
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);add_child(column)
	var header=HBoxContainer.new();column.add_child(header)
	var title=Label.new();title.add_theme_font_override("font",preload("res://assets/fonts/DejaVuSerif.ttf"));title.text="SETTLEMENT  /  QUEST JOURNAL";title.add_theme_font_size_override("font_size",26);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	close_button=Button.new();close_button.text="Close";close_button.custom_minimum_size=Vector2(90,36);header.add_child(close_button);close_button.pressed.connect(func():closed.emit())
	binding_note=Label.new();binding_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(binding_note)
	var filters=HFlowContainer.new();filters.add_theme_constant_override("h_separation",8);column.add_child(filters)
	for filter_name in FILTERS:
		var control=Button.new();control.toggle_mode=true;control.custom_minimum_size.y=36;filters.add_child(control);filter_buttons[filter_name]=control
		control.pressed.connect(func(): select_filter(filter_name))
	entry_summary=Label.new();entry_summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(entry_summary)
	scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",12);scroll.add_child(body)
	var footer=Label.new();footer.text="Journal only — visit the board or trader to act. The world continues while this menu is open.";footer.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(footer)
	hide()
func line(parent:Node,text:String,size:int,color:Color):
	var label=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",size);label.add_theme_color_override("font_color",color);parent.add_child(label)
func render(request,onboarding,inventory,key:String,notice:String="",fishing=null,plot=null):
	displayed_entries=JournalProjection.entries(request,onboarding,inventory,fishing,plot)
	binding_note.text="%s / Esc closes  •  Read-only progress"%key
	if not notice.is_empty():binding_note.text+="\n"+notice
	selected_filter="All"
	rebuild_entries()
	show();close_button.grab_focus()

func select_filter(value:String):
	if value not in FILTERS:return
	selected_filter=value
	rebuild_entries()

func rebuild_entries():
	for child in body.get_children():body.remove_child(child);child.queue_free()
	var visible_count=0
	for filter_name in FILTERS:
		var count=displayed_entries.size() if filter_name=="All" else displayed_entries.filter(func(entry):return entry.status==filter_name).size()
		var control:Button=filter_buttons[filter_name]
		control.text=("Available" if filter_name=="Available at board" else filter_name)+" (%d)"%count
		control.set_pressed_no_signal(filter_name==selected_filter)
		control.tooltip_text="Show %s journal entries. Read-only; no quest action is performed."%filter_name.to_lower()
	for group in ["Active","Available at board","Completed"]:
		if selected_filter!="All" and group!=selected_filter:continue
		var rows=displayed_entries.filter(func(entry):return entry.status==group)
		if rows.is_empty():continue
		line(body,group.to_upper(),18,Color("c6a975"))
		for entry in rows:
			visible_count+=1
			var card=PanelContainer.new();card.add_theme_stylebox_override("panel",preload("res://scripts/options_theme.gd").frame("232d29","526252",12));body.add_child(card)
			var column=VBoxContainer.new();column.add_theme_constant_override("separation",5);card.add_child(column)
			line(column,entry.title,22,Color("efe7d4"))
			line(column,entry.objective,18,Color("e0e5de"))
			line(column,"Where: "+entry.where,16,Color("b3c5b8"))
			if not entry.reward.is_empty():line(column,"Reward: "+entry.reward,16,Color("d9bf87"))
			line(column,entry.note,15,Color("aebbb1"))
	entry_summary.text="%d of %d journal entries"%[visible_count,displayed_entries.size()]
	if visible_count==0:line(body,"No entries in this category yet. Choose All to see your current journal.",18,Color("aebbb1"))
	scroll.scroll_vertical=0
