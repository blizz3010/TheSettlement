extends PanelContainer
signal action_requested(action: String)
signal closed
var summary: Label
var feedback: Label
var review_button: Button
var confirm_button: Button
var cancel_button: Button
var claim_button: Button
var retry_button: Button
var close_button: Button
func _ready():
	set_anchors_preset(Control.PRESET_CENTER);offset_left=-265;offset_right=265;offset_top=-220;offset_bottom=220
	var style=StyleBoxFlat.new();style.bg_color=Color("182a29");style.border_color=Color("b89b61");style.set_border_width_all(2)
	for edge in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:style.set_content_margin(edge,18)
	add_theme_stylebox_override("panel",style)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);add_child(column)
	var title=Label.new();title.text="WORKBENCH / Warm lantern";title.add_theme_font_size_override("font_size",22);column.add_child(title)
	summary=Label.new();summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;summary.custom_minimum_size=Vector2(490,130);column.add_child(summary)
	feedback=Label.new();feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;feedback.custom_minimum_size.y=45;column.add_child(feedback)
	review_button=button(column,"Review recipe","review");confirm_button=button(column,"Confirm craft","start");cancel_button=button(column,"Cancel selection","cancel");claim_button=button(column,"Claim 1 lantern kit","claim");retry_button=button(column,"Retry paused save","retry")
	close_button=Button.new();close_button.text="Return to settlement";close_button.pressed.connect(func():closed.emit());column.add_child(close_button);hide()
func button(parent:Node, title:String, action:String) -> Button:
	var b=Button.new();b.text=title;b.custom_minimum_size.y=34;b.pressed.connect(func():action_requested.emit(action));parent.add_child(b);return b
func render(craft, inventory, pending:bool, paused:bool, status := ""):
	var data=craft.data();var phase=String(data.get("status",data.get("phase","idle")));var seconds=int(data.get("remaining",data.get("remaining_seconds",0)))
	summary.text="Prototype recipe: 1 Timber + 1 Metal scrap from carried inventory.\n10 active-play seconds • No offline progress.\nOutput: 1 lantern kit, placeable on supported ground/upper floors.\nCarried: %d/8 • Timber %d • Metal %d\n%s" % [inventory.used("carried"),inventory.amount("carried","timber"),inventory.amount("carried","metal"),"Ready to claim" if phase=="ready" else ("Working: %d seconds remaining" % seconds if phase=="working" else "Choose Review, then confirm.")]
	feedback.text=status
	review_button.visible=phase=="idle" and not pending;review_button.disabled=inventory.amount("carried","timber")<1 or inventory.amount("carried","metal")<1
	confirm_button.visible=pending and phase=="idle";cancel_button.visible=pending and phase=="idle"
	claim_button.visible=phase=="ready";claim_button.disabled=inventory.used("carried")>=8
	retry_button.visible=paused and phase=="working"
