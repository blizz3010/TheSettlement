extends Node
const PreviewPanel=preload("res://scripts/trader_preview_panel.gd")
var host
var gear_service=preload("res://scripts/psy_gear_purchase.gd").new()
var gear_transactions=preload("res://scripts/shop_transaction.gd").new(gear_service.quote_candidate)
var panel
var current_id:String=""
var restore_pending:bool=false
var marketplace_enabled:bool=false
var window_focused:bool=true
# Front customer strips in each stand's unchanged local coordinates. The Psy
# conversation target is centered above the clear counter, never an enlarged actor.
const ACCESS={
 "psy":{"path":"MarketExpansion/PsyStand","x":Vector2(-2.2,2.2),"z":Vector2(3.2,5.7),"target":Vector3(0,1.5,2.85)},
 "dan":{"path":"MarketExpansion/DanStand","x":Vector2(-3,3),"z":Vector2(3,5.5),"target":Vector3(0,1.5,2.8)},
 "atlas":{"path":"MarketExpansion/AtlasStand","x":Vector2(-2.5,2.5),"z":Vector2(3.7,6.0),"target":Vector3(0,1.5,3.3)}
}
func setup(world,enable_marketplace:bool=false):
 host=world;name="TraderPreviewController";marketplace_enabled=enable_marketplace
 panel=PreviewPanel.new();host.supplies_panel.get_parent().add_child(panel);panel.closed.connect(close)
 panel.review_requested.connect(review_gear);panel.confirmed.connect(confirm_gear);panel.cancelled.connect(cancel_gear)
 refresh_service_metadata()
func enable_marketplace():
 marketplace_enabled=true;refresh_service_metadata()
func refresh_service_metadata():
 for id in ACCESS:
  if id=="dan" and not marketplace_enabled:continue
  var stand=host.get_node_or_null(ACCESS[id].path)
  if is_instance_valid(stand):
   stand.set_meta("service_status",{"psy":"cosmetic_helmet_trading","dan":"marketplace_preview_only","atlas":"recovery_overview_unavailable"}[id])
   if id=="psy":
    for label in stand.find_children("*","Label3D",true,false):
     if label.text=="PLANNED SERVICE · NOT AVAILABLE":label.text="COSMETIC HELMET · BUY / SELL"
func active()->bool:
 return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(host) and host.is_inside_tree() and not host.is_queued_for_deletion() and host.world_initialized and not host.startup_cancel_requested and (not host.staged_startup or host.world_activated or host.startup_preparing_assets)
func is_open()->bool:return is_instance_valid(panel) and panel.visible
func accessible(id:String)->bool:
 if not active() or not ACCESS.has(id) or (id=="dan" and not marketplace_enabled):return false
 if not window_focused or not host.cooking_window_focused or host.player.seated or host.build_mode or host.moving_stash:return false
 var stand=host.get_node_or_null(ACCESS[id].path)
 if not is_instance_valid(stand):return false
 var p:Vector3=stand.to_local(host.player.global_position);var spec:Dictionary=ACCESS[id]
 if p.x<spec.x.x or p.x>spec.x.y or p.z<spec.z.x or p.z>spec.z.y or absf(p.y)>.6:return false
 var eye:Vector3=host.player.global_position+Vector3(0,1.5,0)
 var target:Vector3=stand.to_global(spec.target)
 if eye.distance_to(target)>2.8:return false
 var query=PhysicsRayQueryParameters3D.create(eye,target);query.exclude=[host.player.get_rid()]
 return host.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func nearest()->String:
 for id in ["psy","dan","atlas"]:
  if accessible(id):return id
 return ""
func prompt_text()->String:
 var id=nearest()
 if id.is_empty():return ""
 return host.key_label("interact")+"  "+{"psy":"Psy · Browse gear","dan":"Dan · Open marketplace preview","atlas":"Atlas · Recovery overview"}[id]
func open(id:String):
 if not accessible(id) or host.modal_open():return
 current_id=id;restore_pending=false
 panel.open_service(id,host.state,host.inventory)
 host.player.enabled=false;host.player.velocity=Vector3.ZERO;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func eligible()->bool:
 return is_open() and accessible(current_id) and not host.modal_open(true,true,false)
func close():
 gear_transactions.cancel()
 restore_pending=restore_pending or is_open()
 current_id=""
 if is_instance_valid(panel):panel.hide()
 restore_controls()
func restore_controls():
 if restore_pending and active() and window_focused and host.cooking_window_focused and not host.modal_open():
  restore_pending=false;host.player.enabled=true;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func consume(event)->bool:
 if not is_open():return false
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_ESCAPE:close()
  get_viewport().set_input_as_handled();return true
 return false
func _process(_delta):
 if is_open() and not eligible():close()
 elif not is_open():restore_controls()
func _notification(what):
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
  window_focused=false;close()
 elif what==NOTIFICATION_APPLICATION_FOCUS_IN:window_focused=true
func _exit_tree():
 close()
 if is_instance_valid(panel):panel.queue_free()

func gear_context()->Dictionary:
 return {"craft":host.craft.data(),"onboarding":host.onboarding.data(),"fishing":host.fishing.data(),"service":current_id,"action":panel.action,"selection":panel.selected_item}
func gear_access()->bool:
 return current_id=="psy" and eligible()
func review_gear(item:String,quantity:int,action:String):
 if not gear_access() or action!=panel.action or item!=panel.selected_item or quantity!=1:return
 var quote=gear_transactions.select("psy",action,item,quantity,host.state,host.inventory,host.request,gear_context())
 panel.render_gear(host.state,host.inventory,quote,gear_service.last_error if not gear_service.last_error.is_empty() else gear_transactions.last_error)
 if not quote.is_empty():panel.cancel_button.grab_focus()
func confirm_gear(writer_override=null)->bool:
 var pending=gear_transactions.pending_quote()
 if pending.is_empty():return false
 var writer=func(candidate):return host.save_payload(preload("res://scripts/save_codec.gd").encode(candidate.plot,candidate.inventory,candidate.request,host.craft,host.onboarding,host.fishing),false,writer_override)
 var candidate=gear_transactions.confirm(pending.token,host.state,host.inventory,host.request,gear_access,writer,gear_context())
 if not candidate.is_empty():
  host.state=candidate.plot;host.inventory=candidate.inventory;host.request=candidate.request
  if host.has_meta("approved_audio_service"):
   var audio=host.get_meta("approved_audio_service")
   if is_instance_valid(audio) and audio.has_method("queue_cue"):audio.queue_cue("confirm_buy")
 panel.render_gear(host.state,host.inventory,{},"Saved. Basic helmet "+("sold." if pending.action=="sell" else "purchased. Equip it in Inventory. No protection bonus.") if not candidate.is_empty() else gear_transactions.last_error)
 if panel.visible:panel.close_button.grab_focus()
 return not candidate.is_empty()
func cancel_gear():
 gear_transactions.cancel()
 if current_id=="psy":panel.render_gear(host.state,host.inventory,{},"Review cancelled. Nothing traded.")
