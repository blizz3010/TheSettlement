extends RefCounted
# Explicit title-menu login policy, never a save-loader or scene-transition hook.
const SPAWN_XZ=Vector2(0,-17.2)
const FLOOR_PATH=NodePath('TownHallCollision/Level floor')
static func prepare(world:Node3D,place:bool)->Dictionary:
 if not world.world_initialized or world.world_activated or world.startup_cancel_requested or not world.startup_preparing_assets:
  return {'ok':false,'reason':'Town Hall login requires inactive prepared world'}
 var player=world.player
 if not is_instance_valid(player) or player.enabled or not is_instance_valid(player.body_shape) or player.standing_shape==null:
  return {'ok':false,'reason':'Player is not ready for safe login placement'}
 var floor_node=world.get_node_or_null(FLOOR_PATH)
 if not floor_node is StaticBody3D:return {'ok':false,'reason':'Town Hall floor is unavailable'}
 var space=world.get_world_3d().direct_space_state
 var ray=PhysicsRayQueryParameters3D.create(Vector3(SPAWN_XZ.x,2,SPAWN_XZ.y),Vector3(SPAWN_XZ.x,-1,SPAWN_XZ.y),player.collision_mask,[player.get_rid()])
 var hit=space.intersect_ray(ray)
 if hit.is_empty() or hit.collider!=floor_node or hit.normal.y<.99 or absf(hit.position.y-.24)>.002:
  return {'ok':false,'reason':'Town Hall login floor failed support validation'}
 var position=Vector3(SPAWN_XZ.x,hit.position.y+.03,SPAWN_XZ.y)
 var shape=PhysicsShapeQueryParameters3D.new();shape.shape=player.standing_shape
 shape.transform=Transform3D(Basis.IDENTITY,position+Vector3(0,.9,0))
 shape.collision_mask=player.collision_mask;shape.exclude=[player.get_rid()];shape.margin=.005
 if not space.intersect_shape(shape,1).is_empty():
  return {'ok':false,'reason':'Town Hall login space is blocked. No player entry or save change occurred.'}
 if not place and not player.global_position.is_equal_approx(position):
  return {'ok':false,'reason':'Town Hall login position changed before scenery finished'}
 if place:
  player.global_position=position;player.rotation=Vector3.ZERO;player.velocity=Vector3.ZERO
  player.pitch=-.04;player.camera.rotation=Vector3(player.pitch,0,0)
  player.reset_physics_interpolation()
 return {'ok':true,'position':position,'floor':str(FLOOR_PATH),'capsule_clear':true,'saved_progress_modified':false}
