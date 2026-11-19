extends RefCounted
## TASKS queue item 2 (d): first E press at the plaza traders.
## Root cause: the pinned controller's customer strips start in front of where the
## counter collision stops the player (Psy strip z >= 3.2, counter stop z ~3.02;
## Atlas z >= 3.7, stop ~3.52), and the 2.8 m eye-to-counter cap drops the prompt
## beyond ~2.5 m and at Dan's corners. A press there is ignored because no service
## is in range, not because the key is lost. This widens each strip to the counter
## face and allows a longer reach, keeping the pinned gates (focus, seat, build,
## height, line of sight). Used by raid_loot_controller_ext.accessible().
const REACH := {
	"psy": {"x": Vector2(-2.7, 2.7), "z": Vector2(2.85, 6.4)},
	"dan": {"x": Vector2(-3.3, 3.3), "z": Vector2(2.85, 6.2)},
	"atlas": {"x": Vector2(-2.9, 2.9), "z": Vector2(3.35, 6.6)},
}
const MAX_REACH := 3.6
const MAX_HEIGHT := 0.6

## Same gates as the pinned accessible(), with REACH strips and MAX_REACH.
static func reachable(ctrl, id: String) -> bool:
	if ctrl == null or not ctrl.active() or not ctrl.ACCESS.has(id) or not REACH.has(id): return false
	if id == "dan" and not ctrl.marketplace_enabled: return false
	var host = ctrl.host
	if not ctrl.window_focused or not host.cooking_window_focused or host.player.seated or host.build_mode or host.moving_stash: return false
	var stand = host.get_node_or_null(ctrl.ACCESS[id].path)
	if not is_instance_valid(stand): return false
	return in_reach(stand, id, host.player.global_position, host.player.get_rid(), host.get_world_3d())

## Geometry-only check, exposed for tests and probes.
static func in_reach(stand: Node3D, id: String, pos: Vector3, exclude: RID, world3d: World3D) -> bool:
	var spec: Dictionary = REACH[id]
	var p: Vector3 = stand.to_local(pos)
	if p.x < spec.x.x or p.x > spec.x.y or p.z < spec.z.x or p.z > spec.z.y or absf(p.y) > MAX_HEIGHT: return false
	var eye: Vector3 = pos + Vector3(0, 1.5, 0)
	var target: Vector3 = stand.to_global(preload("res://scripts/trader_preview_controller.gd").ACCESS[id].target)
	if eye.distance_to(target) > MAX_REACH: return false
	var query := PhysicsRayQueryParameters3D.create(eye, target)
	query.exclude = [exclude]
	return world3d.direct_space_state.intersect_ray(query).is_empty()
