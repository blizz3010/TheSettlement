extends Control
signal back_requested
signal launch_requested(token:int, legacy:bool, needs_intro:bool)
const MenuTheme=preload("res://scripts/shop_theme.gd")
const Creator=preload("res://scripts/character_preview/creation_panel.gd")
const Fresh=preload("res://scripts/character_profiles/new_gameplay.gd")
const Store=preload("res://scripts/character_profiles/profile_store.gd")
const Rules=preload("res://scripts/character_profiles/experimental_rules.gd")
const Model=preload("res://scripts/character_profiles/profile_model.gd")
const Codec=preload("res://scripts/save_codec.gd")
const Stage=preload("res://scripts/character_profiles/selection_stage.gd")
const Backdrop=preload("res://scripts/character_profiles/selection_backdrop.gd")
const INK=Color("e9dfc8")
const MUTED=Color("a5bcb1")
const COPPER=Color("c6a975")
var session
var body:VBoxContainer
var status:Label
var creator
var selection_root:MarginContainer
var current_index:PackedByteArray
var requested_slot=""
var adopting=false
var busy=false
var cards:Dictionary={}
var profiles:Dictionary={}
var selected_slot=""
var preview
var preview_name:Label
var preview_stats:Label
var preview_note:Label
var enter_button:Button
var back_button:Button
var columns:HBoxContainer
var left_panel:PanelContainer
var preview_panel:PanelContainer
var preview_holder:VBoxContainer
var rotate_controls:HBoxContainer

func box(fill:Color,border:Color,width:int=1)->StyleBoxFlat:
 var s=MenuTheme.frame(fill.to_html(),border.to_html(),16);s.set_border_width_all(width)
 s.content_margin_left=20;s.content_margin_right=20;s.content_margin_top=16;s.content_margin_bottom=16
 return s
func text(parent:Node,value:String,font_size:int=18,color:Color=INK)->Label:
 var l=Label.new();l.text=value;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color)
 parent.add_child(l);return l
func styled_button(parent:Node,value:String,action:Callable,primary:bool=false)->Button:
 var b=Button.new();b.text=value;b.custom_minimum_size.y=48
 b.add_theme_font_size_override("font_size",18)
 if primary:
  # Warm primary action is distinct; ordinary controls inherit the shared theme.
  for state in ["font_color","font_hover_color","font_pressed_color"]:b.add_theme_color_override(state,Color("15201d"))
  b.add_theme_stylebox_override("normal",box(Color("c6a975"),Color("e9dfc8")))
  b.add_theme_stylebox_override("hover",box(Color("dcc69b"),Color("e9dfc8")))
  b.add_theme_stylebox_override("pressed",box(Color("a28b60"),Color("bfe0d8"),2))
 b.pressed.connect(action);parent.add_child(b);return b
func _ready():
 theme=MenuTheme.make_theme()
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var bg=Backdrop.new();bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
 selection_root=MarginContainer.new();selection_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:selection_root.add_theme_constant_override("margin_"+side,28)
 add_child(selection_root)
 var main=VBoxContainer.new();main.add_theme_constant_override("separation",16);selection_root.add_child(main)
 var heading=text(main,"SETTLEMENT  /  SELECT CHARACTER",24,COPPER);heading.add_theme_font_override("font",MenuTheme.heading_font())
 text(main,"Choose your settler. Your characters keep separate progress.",16,MUTED)
 columns=HBoxContainer.new();columns.add_theme_constant_override("separation",24);columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;main.add_child(columns)
 left_panel=PanelContainer.new();left_panel.add_theme_stylebox_override("panel",box(Color("10231ee8"),Color("3f5b50")));columns.add_child(left_panel)
 var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;left_panel.add_child(scroll)
 body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",14);scroll.add_child(body)
 preview_panel=PanelContainer.new();preview_panel.add_theme_stylebox_override("panel",box(Color("132521a0"),Color("4d6758")));preview_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(preview_panel)
 preview_holder=VBoxContainer.new();preview_holder.add_theme_constant_override("separation",6);preview_panel.add_child(preview_holder)
 preview_name=text(preview_holder,"YOUR SETTLER",30);preview_name.add_theme_font_override("font",MenuTheme.heading_font())
 preview_stats=text(preview_holder,"",18,COPPER)
 preview=Stage.new();preview_holder.add_child(preview)
 var rotate=HBoxContainer.new();rotate_controls=rotate;rotate.alignment=BoxContainer.ALIGNMENT_CENTER;preview_holder.add_child(rotate)
 styled_button(rotate,"‹ Rotate",func():preview.set_angle(preview.angle-30))
 styled_button(rotate,"Rotate ›",func():preview.set_angle(preview.angle+30))
 preview_note=text(preview_holder,"Select a character to preview their saved appearance.",14,MUTED)
 var footer=HBoxContainer.new();footer.add_theme_constant_override("separation",16);main.add_child(footer)
 back_button=styled_button(footer,"‹  BACK",_back)
 var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(spacer)
 enter_button=styled_button(footer,"ENTER SETTLEMENT  ›",func():if not selected_slot.is_empty():choose(selected_slot),true)
 enter_button.disabled=true
 resized.connect(layout);layout();refresh()
func layout():
 if not is_instance_valid(left_panel):return
 left_panel.custom_minimum_size.x=clampf(size.x*.36,250,520)
 for side in ["left","right"]:selection_root.add_theme_constant_override("margin_"+side,16 if size.x<900 else 28)
 columns.add_theme_constant_override("separation",12 if size.x<900 else 24)
func label(value:String):return text(body,value)
func button(value:String,action:Callable):return styled_button(body,value,action)
func refresh():
 for child in body.get_children():body.remove_child(child);child.queue_free()
 cards.clear();profiles.clear();enter_button.disabled=true
 label("CHARACTERS")
 var state=session.inspect();status=text(body,"",15,COPPER)
 if state.screen=="blocked":status.text=state.reason;clear_preview()
 elif state.screen=="legacy_decision":
  clear_preview()
  label("Your existing settlement save was found. Continue unchanged, or copy it into character slot 1. The original and its backups are retained.")
  button("Continue existing save",continue_legacy)
  button("Adopt a copy as character 1…",func():open_creator("slot_1",true,state.bytes))
 elif state.screen=="create":
  clear_preview();label("Your story starts here.")
  button("+  Create first character",func():open_creator("slot_1",false,state.bytes))
 else:
  current_index=state.bytes
  for profile in state.catalogue.profiles:
   var slot:String=profile.slot;profiles[slot]=profile.duplicate(true)
   var card=button("",func():select_preview(slot));card.custom_minimum_size.y=130
   card.alignment=HORIZONTAL_ALIGNMENT_LEFT
   card.add_theme_font_size_override("font_size",23)
   cards[slot]=card
  for slot in ["slot_1","slot_2"]:
   if not profiles.has(slot):
    var empty_slot=slot;button("+  Create second character",func():open_creator(empty_slot,false,state.bytes))
  text(body,"Saved appearance • Equipped clothing\nStats are rolled values; gameplay bonuses are not active yet.",14,MUTED)
  if not profiles.has(selected_slot):selected_slot=str(profiles.keys()[0])
  select_preview(selected_slot)
 if not cards.is_empty():cards[selected_slot].grab_focus()
 else:back_button.grab_focus()
func clear_preview():
 selected_slot="";preview.hide();rotate_controls.hide();preview_name.text="YOUR NEXT CHAPTER";preview_stats.text=""
 preview_note.text="Create or select a character to see their saved appearance."
func select_preview(slot:String):
 if busy or not profiles.has(slot):return
 selected_slot=slot
 var profile:Dictionary=profiles[slot]
 preview_name.text=profile.appearance.name
 preview_stats.text="STR  %d      INT  %d      DEX  %d"%[profile.stats.str,profile.stats.int,profile.stats.dex]
 for key in cards:
  var p:Dictionary=profiles[key];var active=key==slot
  cards[key].text=("●  " if active else "○  ")+p.appearance.name+"\n\nSTR %d    INT %d    DEX %d"%[p.stats.str,p.stats.int,p.stats.dex]
  cards[key].add_theme_stylebox_override("normal",theme.get_stylebox("pressed" if active else "normal","Button"))
 var path=Model.save_path(slot)
 var decoded:Dictionary={}
 if FileAccess.file_exists(path):
  var parser=JSON.new()
  if parser.parse(FileAccess.get_file_as_string(path))==OK and parser.data is Dictionary:decoded=Codec.decode(parser.data)
 if decoded.is_empty():
  preview.hide();rotate_controls.hide();enter_button.disabled=true;status.text="This character's save is unavailable. No files have been changed.";preview_note.text="Preview unavailable.";return
 status.text="";enter_button.disabled=false;preview.show();rotate_controls.show()
 if preview.present(profile.appearance,decoded.inventory):
  preview_note.text="Saved face and equipped clothing • Provisional character model"
 else:
  preview.hide();rotate_controls.hide();preview_note.text="Appearance preview unavailable. Your saved character is unchanged."
func _back():
 if busy:return
 session.cancel();back_requested.emit()
func choose(slot:String):
 if busy:return
 if not Store.bytes_current(current_index):
  refresh();status.text="Your character list changed. Review the refreshed selection before entering.";return
 var result=session.select_character(slot)
 if not result.ok:status.text=result.reason;return
 busy=true;launch_requested.emit(result.generation,false,result.route.screen=="intro_then_loading")
func open_creator(slot:String,adopt:bool,index:PackedByteArray):
 if busy or is_instance_valid(creator):return
 requested_slot=slot;adopting=adopt;current_index=index.duplicate()
 var packed=load("res://models/Appearance-Proof.glb") as PackedScene
 if packed==null:status.text="Appearance preview unavailable; nothing saved.";return
 creator=Creator.new();creator.source=packed
 creator.back_requested.connect(close_creator)
 creator.creation_requested.connect(confirm_creation)
 add_child(creator);selection_root.hide()
 if adopting:creator.confirm.text="Adopt copy and continue"
func close_creator():
 if busy:return
 if is_instance_valid(creator):remove_child(creator);creator.queue_free()
 creator=null;selection_root.show();refresh()
func confirm_creation(appearance:Dictionary,stats:Dictionary,perks:Array):
 if busy or not is_instance_valid(creator):return
 busy=true;creator.confirm.disabled=true
 var result=session.create_character(requested_slot,appearance,stats,perks,current_index,adopting)
 if not result.ok:
  busy=false;creator.report_creation_error(result.reason);return
 launch_requested.emit(result.generation,false,result.route.screen=="intro_then_loading")
func _unhandled_key_input(event):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and not is_instance_valid(creator) and not busy:
  get_viewport().set_input_as_handled();session.cancel();back_requested.emit()

func continue_legacy():
 if busy:return
 if not FileAccess.file_exists(Store.LEGACY) or not Fresh.valid(FileAccess.get_file_as_bytes(Store.LEGACY)):
  status.text="Existing save is missing or invalid. Preserve it before continuing; no new game was started.";return
 busy=true;session.cancel();launch_requested.emit(0,true,false)
