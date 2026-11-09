extends Node
const Station=preload("res://scripts/cooking_station_v095.gd")
const Placement=preload("res://scripts/cooking_test_placement.gd")
var host
var station
var clearance:Dictionary={}
var disposing=false
var focus_suspended=false
var install_requested=false
var placement_attempted=false
func setup(world):
 name="CookingTestController";host=world
func begin_after_activation(world):
 if disposing or is_queued_for_deletion() or not is_inside_tree():return
 setup(world)
 if not active_world():return
 if install_requested or placement_attempted:return
 install_requested=true
 var tree=get_tree()
 for _barrier in range(2):
  await tree.physics_frame
  if disposing or is_queued_for_deletion() or not is_inside_tree() or not active_world():return
 install(world)
func install(world):
 if disposing or is_queued_for_deletion() or not is_inside_tree():return
 setup(world)
 if not active_world():return
 placement_attempted=true
 if is_instance_valid(station):return
 clearance=Placement.inspect(world)
 if not clearance.get("ok",false):return
 station=Station.new();station.host_world=host;station.position=clearance.position;station.host_bound=true;station.host_access=host_allows;add_child(station)
 var body=StaticBody3D.new();body.name="CookingTestCollider";station.add_child(body)
 var col=CollisionShape3D.new();col.shape=CylinderShape3D.new();col.shape.radius=.45;col.shape.height=.75;col.position.y=.375;body.add_child(col)
 station.own_collider=body
 station.opened.connect(on_opened);station.closed.connect(on_closed)
func active_world()->bool:
 return not disposing and is_instance_valid(host) and host.is_inside_tree() and not host.is_queued_for_deletion() and is_instance_valid(host.player) and host.player.is_inside_tree() and not host.player.is_queued_for_deletion() and host.world_initialized and not host.startup_cancel_requested and (not host.staged_startup or host.world_activated or host.startup_preparing_assets)
func host_allows()->bool:
 return active_world() and not focus_suspended and host.cooking_window_focused and not host.modal_open(false) and not host.build_mode and not host.moving_stash and not host.player.seated
func is_open()->bool:
 return is_instance_valid(station) and is_instance_valid(station.panel) and station.panel.visible
func accessible()->bool:
 return is_instance_valid(station) and host_allows() and host.player.enabled and station.can_open(host.player)
func vendor_accessible()->bool:
 return is_instance_valid(station) and host_allows() and host.player.enabled and station.can_open(host.player,'vendor')
func open_vendor()->bool:
 if not vendor_accessible():return false
 return station.try_open_vendor(host.player)
func open()->bool:
 if not accessible():return false
 return station.try_open(host.player)
func release_actions():
 for action in ["forward","backward","left","right","sprint","jump","crouch","interact"]:Input.action_release(action)
func on_opened():
 release_actions();host.player.velocity=Vector3.ZERO;host.player.enabled=false
 host.ghost.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func restore_controls():
 if not active_world() or focus_suspended or not host.cooking_window_focused or host.modal_open(false):return
 host.player.enabled=true;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func on_closed():
 release_actions()
 var focused=get_viewport().gui_get_focus_owner() if is_inside_tree() else null
 if is_instance_valid(focused) and is_instance_valid(station) and station.is_ancestor_of(focused):focused.release_focus()
 restore_controls()
func close():
 if is_instance_valid(station):station.close_panel()
func consume(event:InputEvent)->bool:
 if not is_open():return false
 if event is InputEventKey and event.pressed and not event.echo and (event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_ESCAPE):close()
 get_viewport().set_input_as_handled();return true
func _notification(what):
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_open():
  focus_suspended=true;close();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 elif what==NOTIFICATION_APPLICATION_FOCUS_IN and focus_suspended:
  focus_suspended=false;restore_controls()
func _exit_tree():
 disposing=true
 if is_instance_valid(station):
  station.close_panel();station.queue_free()
 if is_instance_valid(host):host.call_deferred("_restore_cooking_detach",get_instance_id(),focus_suspended)
 host=null
