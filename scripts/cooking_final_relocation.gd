extends RefCounted
# Final startup step only: relocate the existing station as a single subtree.
# Initial cooking/park baselines must finish before this helper is called.
const TARGET=Vector2(-4.4,3.8)
const YAW=PI/2
const KEY='cooking_final_relocation'
static func fail(reason:String)->Dictionary:return {'ok':false,'reason':reason}
static func apply(world:Node3D)->Dictionary:
 if not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion() or world.startup_cancel_requested:return fail('Cooking relocation cancelled')
 var controller=world.cooking_test
 if not is_instance_valid(controller) or not is_instance_valid(controller.station):return fail('Cooking station is unavailable')
 var station:Node3D=controller.station
 var shop=world.get_node_or_null('WestTraderFrontage')
 if not is_instance_valid(shop) or shop.position.distance_to(Vector3(-7,0,2))>.001 or absf(shop.rotation.y-PI/2)>.001:return fail('Cooking shop identity changed')
 if is_instance_valid(station.panel) and station.panel.visible:return fail('Close cooking before relocation')
 if world.has_meta(KEY):
  var old=world.get_meta(KEY)
  if not old is Dictionary or old.get('station_id')!=station.get_instance_id() or station.global_transform!=old.get('target'):return fail('Cooking relocation state changed')
  return {'ok':true,'reused':true,'position':station.global_position}
 if Vector2(station.global_position.x,station.global_position.z).distance_to(Vector2(-11.2,6.7))>.001:return fail('Unexpected original cooking position')
 if not is_instance_valid(station.own_collider):return fail('Cooking collider missing')
 var excluded:Array[RID]=[station.own_collider.get_rid()]
 if world.player is CollisionObject3D:excluded.append(world.player.get_rid())
 var space=world.get_world_3d().direct_space_state;var heights=[];var basis=Basis(Vector3.UP,YAW)
 for local in [Vector3.ZERO,Vector3(-.49,0,-.49),Vector3(.49,0,-.49),Vector3(-.49,0,.49),Vector3(.49,0,.49),Vector3(0,0,1.25)]:
  var xz=Vector3(TARGET.x,0,TARGET.y)+basis*local
  var ray=PhysicsRayQueryParameters3D.create(xz+Vector3.UP*5,xz-Vector3.UP*5);ray.exclude=excluded
  var hit=space.intersect_ray(ray)
  if hit.is_empty() or hit.normal.y<.97:return fail('Cooking target has no level support')
  heights.append(hit.position.y)
 if heights.max()-heights.min()>.06:return fail('Cooking target support is uneven')
 var origin=Vector3(TARGET.x,heights.max(),TARGET.y)
 # Entire canopy plus standing access must fit, not only the small collider.
 for row in [[Vector3(0,1.35,0),Vector3(1.02,2.58,1.02)],[Vector3(0,.98,1.25),Vector3(.80,1.80,.80)]]:
  var shape=BoxShape3D.new();shape.size=row[1]
  var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.exclude=excluded;query.transform=Transform3D(basis,origin+basis*row[0]);query.margin=.015
  if not space.intersect_shape(query,16).is_empty():return fail('Cooking target or approach is obstructed')
 var before=station.global_transform;var target=Transform3D(basis,origin)
 station.global_transform=target
 world.set_meta(KEY,{'station_id':station.get_instance_id(),'original':before,'target':target})
 return {'ok':true,'reused':false,'position':origin,'approach':origin+basis*Vector3(0,0,1.25),'old_position':before.origin}
