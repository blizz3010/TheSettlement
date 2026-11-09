extends Control
signal back_requested
signal creation_requested(appearance:Dictionary, stats:Dictionary, perks:Array)
const Rules=preload("res://scripts/character_profiles/experimental_rules.gd")
const MenuTheme=preload("res://scripts/shop_theme.gd")
const ProfileModel=preload("res://scripts/character_profiles/profile_model.gd")
var rolled:Dictionary={}
var picked:Array=[]
var committed_rolled:Dictionary={}
var committed_picked:Array=[]
var trait_choices:Dictionary={}
var roll_label:Label
var points_label:Label
var rng=RandomNumberGenerator.new()
const Draft=preload("creator_draft.gd")
const Preview=preload("creator_preview.gd")
var source:PackedScene
var slots=[Draft.new()]
var selected=0
var preview
var name_edit:LineEdit
var choices={}
var cheek:HSlider
var creation_error=""
var status:Label
var summary:Label
var confirm:Button
var turn:HSlider
var card_buttons=[]
func label(parent,text:String,size:int=16)->Label:
 var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size);parent.add_child(l);return l
func button(parent,text:String,action:Callable)->Button:
 var b=Button.new();b.text=text;b.pressed.connect(action);parent.add_child(b);return b
func _ready():
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 # Share the same warm text, teal focus and framed controls as shops/Options.
 theme=MenuTheme.make_theme();theme.default_font_size=16
 theme.set_color("font_color","CheckBox",Color("e9dfc8"))
 theme.set_stylebox("focus","CheckBox",theme.get_stylebox("focus","CheckButton"))
 var bg=ColorRect.new();bg.color=Color("1b211f");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
 var margins=MarginContainer.new();margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for edge in ["left","right","top","bottom"]:margins.add_theme_constant_override("margin_"+edge,16)
 add_child(margins);var stack=VBoxContainer.new();stack.add_theme_constant_override("separation",6);margins.add_child(stack)
 label(stack,"SETTLEMENT  /  CHARACTER STUDIO",14)
 var heading=label(stack,"Create character",26);heading.add_theme_font_override("font",MenuTheme.heading_font());heading.add_theme_color_override("font_color",Color("e9dfc8"))
 label(stack,"Experimental creator • Appearance and stats save to this character profile",14)
 var cards=HBoxContainer.new();stack.add_child(cards)
 for i in range(slots.size()):
  slots[i].committed.name="Settler "+str(i+1);slots[i].begin()
  var index=i;card_buttons.append(button(cards,"New character",func():select_slot(index)))
 var body=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",20);stack.add_child(body)
 var scroll=ScrollContainer.new();scroll.custom_minimum_size.x=280;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(scroll)
 var controls=VBoxContainer.new();controls.size_flags_horizontal=Control.SIZE_EXPAND_FILL;controls.add_theme_constant_override("separation",9);scroll.add_child(controls)
 label(controls,"NAME",13);name_edit=LineEdit.new();name_edit.max_length=24;controls.add_child(name_edit);name_edit.text_changed.connect(func(value):slots[selected].draft.name=value;update_preview())
 add_choice(controls,"Hair","hair",["No hair","Short swept","Side bob"],Draft.HAIR)
 add_choice(controls,"Hair color","hair_tint",Draft.HAIR_TINT_LABELS,Draft.HAIR_TINTS)
 add_choice(controls,"Brows","brows",["Soft arch","Defined arch"],Draft.BROWS)
 add_choice(controls,"Eyes","eyes",["Brown","Blue"],Draft.EYES)
 label(controls,"Cheek fullness",16);cheek=HSlider.new();cheek.max_value=1;cheek.step=.05;controls.add_child(cheek);cheek.value_changed.connect(func(v):slots[selected].draft.cheek=v;update_preview())
 var details=label(controls,"One proven face adjustment. More faces, skin palettes and facial-hair styles are not included yet.",14);details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.custom_minimum_size.x=260
 rng.randomize();rolled=ProfileModel.roll(Rules.data(),rng);committed_rolled=rolled.duplicate(true)
 roll_label=label(controls,"",16);button(controls,"Reroll provisional stats",func():rolled=ProfileModel.roll(Rules.data(),rng);update_preview())
 label(controls,"Provisional trait points must total zero",14)
 points_label=label(controls,"",14)
 for id in Rules.COSTS:
  var key=id;var choice=CheckBox.new();choice.text=Rules.LABELS[id]+" (%+d)"%Rules.COSTS[id];controls.add_child(choice);trait_choices[key]=choice
  choice.toggled.connect(func(on):
   if on:picked.append(key)
   else:picked.erase(key)
   update_preview())
 var right=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(right)
 preview=Preview.new();preview.source=source;right.add_child(preview)
 summary=label(right,"",15);summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var rotate=HBoxContainer.new();right.add_child(rotate);label(rotate,"Turn",14);turn=HSlider.new();turn.min_value=-45;turn.max_value=45;turn.step=1;turn.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rotate.add_child(turn);turn.value_changed.connect(func(v):preview.set_turn(v));button(rotate,"Front",func():turn.value=0)
 status=label(stack,"Provisional stats and traits have no gameplay bonuses yet. Existing equipment and dyes are retained.",14);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var footer=HBoxContainer.new();stack.add_child(footer);button(footer,"Reset look",reset_look);button(footer,"Cancel changes",cancel_changes);confirm=button(footer,"Create and continue",confirm_preview)
 button(footer,"Back to title",func():back_requested.emit())
 sync_controls();name_edit.grab_focus()
func add_choice(parent,title:String,key:String,labels:Array,ids:Array):
 label(parent,title,16);var choice=OptionButton.new();parent.add_child(choice)
 for i in range(labels.size()):choice.add_item(labels[i]);choice.set_item_metadata(i,ids[i])
 choice.item_selected.connect(func(index):slots[selected].draft[key]=choice.get_item_metadata(index);update_preview());choices[key]=choice
func sync_controls():
 var d=slots[selected].draft;name_edit.text=d.name;cheek.set_value_no_signal(d.cheek)
 for key in trait_choices:trait_choices[key].set_pressed_no_signal(key in picked)
 for key in choices:
  var c=choices[key]
  for i in range(c.item_count):
   if c.get_item_metadata(i)==d.get(key,"natural"):c.select(i)
 for i in range(card_buttons.size()):card_buttons[i].disabled=i==selected
 update_preview()
func update_preview():
 var balance=0
 for id in picked:balance+=Rules.COSTS[id]
 if is_instance_valid(roll_label):roll_label.text="STR %s   INT %s   DEX %s"%[rolled.get("str",0),rolled.get("int",0),rolled.get("dex",0)]
 if is_instance_valid(points_label):points_label.text="Point balance: %d (required: 0)"%balance
 # Appearance remains live while the independent provisional trait budget is invalid.
 var appearance_ok=slots[selected].valid(slots[selected].draft)
 var rendered=false
 if appearance_ok:rendered=preview.show_draft(slots[selected].draft)
 confirm.disabled=not appearance_ok or balance!=0 or not rendered or not creation_error.is_empty()
 summary.text=slots[selected].draft.name+"  •  Preview "+str(selected+1)
 if not creation_error.is_empty():
  status.text=creation_error
 elif not appearance_ok:
  status.text="Enter a name of 1–24 characters. Your character has not been created."
 elif not rendered:
  status.text="Preview model unavailable. No changes were applied."
 elif balance!=0:
  status.text="Balance trait points to zero before creating your character. You can keep adjusting your look."
 else:
  status.text="Ready to create. Provisional stats and traits have no gameplay bonuses yet. Existing equipment and dyes are retained."

func select_slot(index:int):
 if index<0 or index>=slots.size():return
 slots[selected].cancel();selected=index;slots[selected].begin();sync_controls();status.text="Preview "+str(index+1)+" • Changes remain in this studio session only."
func reset_look():
 if not creation_error.is_empty():return
 slots[selected].reset();sync_controls();status.text="Look reset. Nothing is saved until Create and continue."
func cancel_changes():
 if not creation_error.is_empty():return
 slots[selected].cancel();rolled=committed_rolled.duplicate(true);picked=committed_picked.duplicate();sync_controls();status.text="Unconfirmed appearance, stats and traits discarded. Your game is unchanged."
func report_creation_error(reason:String):
 creation_error="Could not continue: "+reason+". Return to the character list; any completed creation data is retained."
 update_preview()
func confirm_preview():
 update_preview()
 if confirm.disabled or not preview.available() or not slots[selected].commit():return
 committed_rolled=rolled.duplicate(true);committed_picked=picked.duplicate()
 creation_requested.emit(slots[selected].committed.duplicate(true),rolled.duplicate(true),picked.duplicate())
func _exit_tree():
 for state in slots:state.dispose()

func _unhandled_key_input(event):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
  get_viewport().set_input_as_handled();back_requested.emit()
