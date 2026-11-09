extends Node
const Visual=preload('res://scripts/fishing_trader_visuals.gd')
const SupplyPanel=preload('res://scripts/fishing_supply_panel.gd')
const Transaction=preload('res://scripts/fishing_supply_transaction.gd')
const Codec=preload('res://scripts/save_codec.gd')
var host
var scenery
var panel
var transaction=Transaction.new()
var token=0
var requested=false
var restore_pending=false
var result={}
func setup(world):
 host=world;name='FishingSuppliesController'
 panel=SupplyPanel.new();host.supplies_panel.get_parent().add_child(panel)
 panel.selected.connect(select_item);panel.confirmed.connect(confirm_purchase)
 panel.cancelled.connect(cancel);panel.closed.connect(close)
func active()->bool:
 return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(host) and not host.is_queued_for_deletion() and host.is_inside_tree() and host.world_initialized and (not host.staged_startup or host.world_activated or host.startup_preparing_assets) and not host.startup_cancel_requested
func is_open()->bool:return is_instance_valid(panel) and panel.visible
func begin_after_activation(world):
 if requested or world!=host or not active():return
 requested=true
 # Service availability must not depend on unrelated decorative garden success.
 # World construction/reconciliation is complete; allow inherited collision to synchronize.
 var frame_tree=get_tree()
 await frame_tree.physics_frame
 if not active():return
 await frame_tree.physics_frame
 if not active():return
 # Bind the one previously surveyed tree. Never search or move scenery on failure.
 var tree=host.get_node_or_null('NaturalBorder/border_tree_b')
 if not tree is MultiMeshInstance3D or tree.multimesh==null or tree.multimesh.instance_count<=9:spawn_result({'ok':false,'reason':'Surveyed tree unavailable'});return
 var tx=tree.global_transform*tree.multimesh.get_instance_transform(9)
 if tx.origin.distance_to(Vector3(17.80153,.97989,-38.04084))>.001:spawn_result({'ok':false,'reason':'Surveyed tree moved'});return
 var p=tx.origin+Vector3(-1,0,-.9)
 var query=PhysicsRayQueryParameters3D.create(p+Vector3.UP*5,p-Vector3.UP*5);query.exclude=[host.player.get_rid()]
 var hit=host.get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty():spawn_result({'ok':false,'reason':'Bank support missing'});return
 scenery=Visual.new();host.add_child(scenery)
 scenery.setup(host,{'tree_path':NodePath('NaturalBorder/border_tree_b'),'tree_index':9,'tree_transform':tx,'tree_mesh':tree.multimesh.mesh,'feet':hit.position})
 result=scenery.install();scenery.result=result
 if not result.get('ok',false):scenery.free();scenery=null
 spawn_result(result)
func spawn_result(value:Dictionary):
 result=value
 var context={}
 for key in ['cooking_test','park_layered_visuals','park_west_visuals','four_area_gardens']:
  var node=host.get(key) if is_instance_valid(host) else null
  context[key]=node.get('result') if is_instance_valid(node) else {'missing':true}
 print('FISHING_TRADER_SPAWN ',JSON.stringify({'result':result,'decorative_prerequisites':context}))
 if not result.get('ok',false) and active():host.message('Fishing supplies could not load: '+str(result.get('reason','unknown'))+'. Please report this message.')
func accessible()->bool:
 if not active() or not host.cooking_window_focused or not is_instance_valid(scenery) or not scenery.result.get('ok',false):return false
 if not is_instance_valid(scenery.actor) or scenery.actor.is_queued_for_deletion() or host.player.seated or host.build_mode or host.moving_stash:return false
 # The free cast stance always keeps its existing action, even before accepting First catch.
 var p=host.player.global_position
 if Vector2(p.x,p.z).distance_to(Vector2(host.FISHING_SPOT.x,host.FISHING_SPOT.z))<=.9:return false
 var target=scenery.actor.global_position+Vector3(0,1.2,0)
 var eye=p+Vector3(0,1.3,0)
 if eye.distance_to(target)>2.0:return false
 var q=PhysicsRayQueryParameters3D.create(eye,target);q.exclude=[host.player.get_rid()]
 return host.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
func open():
 if not accessible() or host.modal_open():return
 restore_pending=false
 transaction.cancel();token=0;panel.render(host.state,host.inventory,'');panel.show()
 host.player.enabled=false;host.player.velocity=Vector3.ZERO
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;panel.close_button.grab_focus()
func eligible()->bool:
 return is_open() and accessible() and not host.modal_open(true,false)
func select_item(item:String):
 if not eligible():close();return
 token=transaction.select(item,host.state,host.inventory)
 refresh(transaction.last_error)
 if token!=0:panel.cancel_button.grab_focus()
func refresh(message:String=''):
 panel.render(host.state,host.inventory,str(transaction.pending.get('item','')),message)
func cancel():
 transaction.cancel();token=0
 if is_open():refresh('Selection cancelled. Nothing bought.')
func write_purchase(plot,inventory)->bool:
 return host.save_payload(Codec.encode(plot,inventory,host.request,host.craft,host.onboarding,host.fishing),false)
func confirm_purchase():
 if not eligible():close();return
 var next=transaction.confirm(token,host.state,host.inventory,eligible,write_purchase);token=0
 if next.is_empty():refresh(transaction.last_error);return
 host.state=next.plot;host.inventory=next.inventory
 preload("res://scripts/approved_settlement_audio.gd").emit_for(host,"confirm_buy")
 refresh('Pole saved. Open Inventory, assign the pole to quick access and select that slot before casting.')
 panel.close_button.grab_focus()
func close():
 restore_pending=restore_pending or is_open()
 transaction.cancel();token=0
 if is_instance_valid(panel):panel.hide()
 restore_controls()
func restore_controls():
 if restore_pending and active() and host.cooking_window_focused and not host.modal_open():
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
func _exit_tree():
 var owned_controls=is_open() or restore_pending
 transaction.cancel()
 if is_instance_valid(panel):panel.hide()
 if owned_controls and is_instance_valid(host) and not host.is_queued_for_deletion():host.call_deferred("_restore_fishing_trader_detach",get_instance_id())
 if is_instance_valid(panel):panel.queue_free()
 if is_instance_valid(scenery):
  if is_instance_valid(scenery.actor):scenery.actor.set_activation_enabled(false)
  scenery.queue_free()
