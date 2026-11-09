extends "res://scripts/shop_panel.gd"
const PreviewCatalog=preload("res://scripts/trader_preview_catalog.gd")
var service_id:String="psy"
var preview_actions:HBoxContainer
func _ready():
 super._ready()
 name="TraderPreviewPanel"
 preview_actions=HBoxContainer.new();preview_actions.add_theme_constant_override("separation",8)
 summary.add_child(preview_actions)
 for label in ["Buy now · coming soon","Bid · coming soon","Post listing · coming soon"]:
  var button=Button.new();button.text=label;button.disabled=true;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;preview_actions.add_child(button)
 tab_changed.connect(_preview_tab)
func open_service(id:String,plot,inventory):
 if id=="psy":
  service_id=id;action="buy";selected_item="";search.text="";configure(preload("res://scripts/psy_gear_catalog.gd").definition());render_gear(plot,inventory);show();close_button.grab_focus();return
 service_id=id;action=str(PreviewCatalog.definition(id).get("tabs",["overview"])[0]);selected_item="";search.text=""
 configure(PreviewCatalog.definition(id))
 render_state(plot,inventory,PreviewCatalog.rows(id,action),{},"Preview only. No items or credits will change.")
 show();close_button.grab_focus()
func _preview_tab(_tab:String):
 if service_id=="psy":render_gear(_plot,_inventory);return
 render_state(_plot,_inventory,PreviewCatalog.rows(service_id,action),{},"Preview only. No items or credits will change.")
func _update_summary():
 super._update_summary()
 # No review/confirmation entry point exists for these deliberately unavailable services.
 if is_instance_valid(summary):
  summary.get_child(0).visible=service_id=="psy"
  if service_id!="psy":review_button.hide();confirmation.hide()
 if is_instance_valid(preview_actions):preview_actions.visible=service_id=="dan"

func render_gear(plot,inventory,pending:Dictionary={},message:String=""):
 render_state(plot,inventory,preload("res://scripts/psy_gear_catalog.gd").rows(inventory,action),pending,message)
