extends "res://scripts/shop_panel.gd"
# Shared shop shell; service panels never mutate inventory or progression.
const Catalog=preload("res://scripts/tailor_catalog.gd")
const SWATCHES={"Indigo":"455478","Linen":"c8b998","Moss":"63764b","Terracotta":"a3634d","Slate":"66727c","Plum":"785b78"}
signal action_requested(action:String,instance_id:String,rgba:Array)
var claim:Button
var dye_items:OptionButton
var color:ColorPickerButton
var commit:Button
var channels:OptionButton
var item_ids:Array[String]=[]
var preview
var shown_inventory
var shown_onboarding
var starter_details:Label
var starter_more:Button
var guidance_expanded:bool=false
var service_box:VBoxContainer
var dye_box:HBoxContainer
var craft_box:VBoxContainer
var patterns:OptionButton
var recipe_details:Label
var craft_review:Button
var craft_confirm:Button
var craft_cancel:Button
var trade_modes:HBoxContainer
var service_mode="shop"
var craft_quote:Dictionary={}
var _filters:Control
func _ready():
 super._ready()
 name="TailorClothingPanel"
 configure({"shop_id":"tailor","title":"TAILOR & DYES","emblem":"✥","role":"Clothing · Patterns · Personal color","tabs":["shop","craft","dye"],"help":"Browse clothing and patterns, or open Dye for an owned garment."})
 var column=get_child(0)
 var card=HBoxContainer.new();card.add_theme_constant_override("separation",12);column.add_child(card);column.move_child(card,2)
 starter_details=Label.new();starter_details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;starter_details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_child(starter_details)
 claim=Button.new();claim.text="Claim starter outfit";claim.custom_minimum_size.x=180;claim.pressed.connect(func():action_requested.emit("claim","",[]));card.add_child(claim)
 starter_more=Button.new();starter_more.text="Details";starter_more.pressed.connect(func():guidance_expanded=not guidance_expanded;_refresh_guidance());card.add_child(starter_more)
 trade_modes=HBoxContainer.new();categories.get_parent().add_child(trade_modes)
 for mode in ["buy","sell"]:
  var button=Button.new();button.text=mode.capitalize();button.toggle_mode=true;button.set_meta("trade_mode",mode);button.custom_minimum_size.x=65;button.pressed.connect(_trade_mode.bind(mode));trade_modes.add_child(button)
 _filters=categories.get_parent()
 service_box=VBoxContainer.new();service_box.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(service_box);column.move_child(service_box,5)
 craft_box=VBoxContainer.new();craft_box.add_theme_constant_override("separation",14);service_box.add_child(craft_box)
 patterns=OptionButton.new()
 for id in Catalog.PATTERNS:patterns.add_item(Catalog.NAMES[Catalog.PATTERNS[id].output])
 patterns.item_selected.connect(func(_i):refresh_recipe());craft_box.add_child(patterns)
 recipe_details=Label.new();recipe_details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;recipe_details.size_flags_vertical=Control.SIZE_EXPAND_FILL;craft_box.add_child(recipe_details)
 craft_review=Button.new();craft_review.text="Review garment craft";craft_review.pressed.connect(func():review_requested.emit(Catalog.PATTERNS.keys()[patterns.selected],1,"craft"));craft_box.add_child(craft_review)
 craft_confirm=Button.new();craft_confirm.text="Confirm craft";craft_confirm.pressed.connect(func():confirmed.emit());craft_box.add_child(craft_confirm)
 craft_cancel=Button.new();craft_cancel.text="Cancel craft review";craft_cancel.pressed.connect(func():cancelled.emit());craft_box.add_child(craft_cancel)
 dye_box=HBoxContainer.new();dye_box.add_theme_constant_override("separation",20);service_box.add_child(dye_box)
 preview=preload("res://scripts/clothing_preview.gd").new();dye_box.add_child(preview)
 var controls=VBoxContainer.new();controls.size_flags_horizontal=Control.SIZE_EXPAND_FILL;controls.add_theme_constant_override("separation",6);dye_box.add_child(controls)
 var help=Label.new();help.text="Choose a garment and fabric color. Preview is free.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;controls.add_child(help)
 dye_items=OptionButton.new();dye_items.item_selected.connect(func(_i):select_current_fabric());controls.add_child(dye_items)
 channels=OptionButton.new();channels.add_item("Fabric");channels.disabled=true;channels.tooltip_text="Fabric is the only supported dye channel.";controls.add_child(channels)
 var swatches=HFlowContainer.new();controls.add_child(swatches)
 for swatch in SWATCHES:
  var button=Button.new();button.text=swatch;button.modulate=Color(SWATCHES[swatch]).lightened(.25);button.pressed.connect(func():color.color=Color(SWATCHES[swatch]);refresh_preview());swatches.add_child(button)
 color=ColorPickerButton.new();color.edit_alpha=false;color.custom_minimum_size.y=38;color.color_changed.connect(func(_c):refresh_preview());color.tooltip_text="Custom fabric color. Preview is free.";controls.add_child(color)
 commit=Button.new();commit.pressed.connect(func():
  if not commit.disabled and dye_items.selected>=0 and dye_items.selected<item_ids.size():
   var c=color.color;action_requested.emit("dye",item_ids[dye_items.selected],[c.r,c.g,c.b,1.0]));controls.add_child(commit)
 var discard=Button.new();discard.text="Discard color preview";discard.pressed.connect(select_current_fabric);controls.add_child(discard)
 var note_=Label.new();note_.text="One free dye per eligible slot. Boots cannot be dyed.\nPaid redye is unavailable.";note_.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;controls.add_child(note_)
 close_button.text="Close"
 action="buy";_show_mode();hide()
func _trade_mode(value:String):
 if not quote.is_empty() or not craft_quote.is_empty():return
 action=value;selected_item="";quantity.value=1
 if shown_inventory!=null:render(shown_inventory,shown_onboarding,"",_plot)
func _change_tab(value:String):
 if not quote.is_empty() or not craft_quote.is_empty():return
 service_mode=value
 if service_mode=="shop":action="buy"
 _show_mode()
 if shown_inventory!=null:render(shown_inventory,shown_onboarding,"",_plot)
func _show_mode():
 if not is_instance_valid(service_box):return
 for id in tab_buttons:tab_buttons[id].button_pressed=id==service_mode
 var trading=service_mode=="shop"
 trade_modes.visible=trading;_filters.visible=trading;body.visible=trading;summary.visible=trading
 for button in trade_modes.get_children():
  button.button_pressed=button.get_meta("trade_mode")==action
  button.disabled=not quote.is_empty() or not craft_quote.is_empty()
 service_box.visible=not trading;craft_box.visible=service_mode=="craft";dye_box.visible=service_mode=="dye"
func render(inventory,onboarding,status:String="",plot=null,pending:Dictionary={}):
 shown_inventory=inventory;shown_onboarding=onboarding
 if plot==null:plot=preload("res://scripts/plot_state.gd").new()
 craft_quote=pending.duplicate(true) if pending.get("action")=="craft" else {}
 render_state(plot,inventory,Catalog.rows(inventory,action),pending if craft_quote.is_empty() else {},status)
 _refresh_guidance()
 claim.disabled=not onboarding.clothing_step in ["talk_dan","claim_pending"] or not pending.is_empty() or inventory.capacity("carried")-inventory.used("carried")<4
 var selected=""
 if dye_items.selected>=0 and dye_items.selected<item_ids.size():selected=item_ids[dye_items.selected]
 dye_items.clear();item_ids.clear()
 for id in inventory.equipment_owned:
  var entry=inventory.equipment_owned[id];var definition=inventory.equipment_definitions()[entry.definition_id]
  if definition.category in ["jacket","gloves","pants"] and entry.location in ["carried","equipped"]:
   item_ids.append(id);dye_items.add_item(definition.display_name+" · "+id+ (" · allowance used" if inventory.dye_free_used[definition.category] else " · free dye"))
 if item_ids.is_empty():dye_items.add_item("No eligible carried or equipped garments");dye_items.disabled=true
 else:dye_items.disabled=false;dye_items.select(maxi(0,item_ids.find(selected)))
 select_current_fabric();refresh_recipe();_show_mode()
 for button in tab_buttons.values():button.disabled=not pending.is_empty()
 # Feedback sits inside the trade summary, so duplicate it in service details only.
 if service_mode=="craft" and not status.is_empty():recipe_details.text+="\n\n"+status
 elif service_mode=="dye" and not status.is_empty():starter_details.text+="\n"+status
func refresh_recipe():
 if shown_inventory==null:return
 var id=Catalog.PATTERNS.keys()[patterns.selected];var recipe=Catalog.PATTERNS[id]
 var linen=shown_inventory.amount("carried","cloth_linen");var thread=shown_inventory.amount("carried","thread_spool")
 var learned=shown_inventory.knows_recipe(id)
 recipe_details.text="Output: 1 "+Catalog.NAMES[recipe.output]+"\n\nLinen cloth: %d / %d · Missing %d\nThread spool: %d / 1 · Missing %d\n\n"%[linen,recipe.cloth,maxi(0,recipe.cloth-linen),thread,maxi(0,1-thread)]
 recipe_details.text+=("Pattern learned." if learned else "Learn this pattern in Shop → Patterns first.")+"\nIngredients are consumed only after the complete garment and inventory save succeeds. Preview and cancel are free."
 craft_review.disabled=not learned or linen<recipe.cloth or thread<1
 craft_review.visible=craft_quote.is_empty();craft_confirm.visible=not craft_quote.is_empty();craft_cancel.visible=not craft_quote.is_empty();patterns.disabled=not craft_quote.is_empty()
 if not craft_quote.is_empty():recipe_details.text+="\n\nReview: consume %d linen cloth + 1 thread spool; receive 1 %s.\nAfter: %d credits · Carried %d / %d."%[recipe.cloth,Catalog.NAMES[recipe.output],craft_quote.balance_after,craft_quote.carried_after,craft_quote.capacity]
func select_current_fabric():
 if shown_inventory!=null and dye_items.selected>=0 and dye_items.selected<item_ids.size():
  var entry=shown_inventory.equipment_owned[item_ids[dye_items.selected]];var slot=shown_inventory.equipment_definitions()[entry.definition_id].category
  var rgba=entry.dyes.get("fabric",shown_inventory.DEFAULT_FABRICS[slot]);color.color=Color(rgba[0],rgba[1],rgba[2],rgba[3])
 refresh_preview()
func refresh_preview():
 if shown_inventory==null:return
 var id:String=item_ids[dye_items.selected] if dye_items.selected>=0 and dye_items.selected<item_ids.size() else ""
 preview.show_draft(shown_inventory,id,color.color)
 var spent=false;var changed=false
 if not id.is_empty():
  var entry=shown_inventory.equipment_owned[id];var slot=shown_inventory.equipment_definitions()[entry.definition_id].category
  spent=shown_inventory.dye_free_used[slot]
  var old=entry.dyes.get("fabric",shown_inventory.DEFAULT_FABRICS[slot]);changed=not Color(old[0],old[1],old[2],old[3]).is_equal_approx(color.color)
 commit.disabled=id.is_empty() or spent or not changed or not shown_onboarding.clothing_step in ["dye_active","complete"]
 commit.text="Paid redye unavailable" if spent else ("Commit fabric dye · free slot allowance" if changed else "Choose a different color to dye")

func _refresh_guidance():
 if shown_inventory==null:return
 var guidance=preload("res://scripts/clothing_guidance.gd")
 starter_details.text=guidance.text(shown_inventory,shown_onboarding) if guidance_expanded else guidance.concise(shown_inventory,shown_onboarding)
 starter_more.text="Less" if guidance_expanded else "Details"
