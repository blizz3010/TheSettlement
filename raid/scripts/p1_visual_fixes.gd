extends RefCounted
## Queue item 4: P1 visual fixes (visual-pass 18/20/38 stairwell; 39/45/206/221 grass edges and the
## Town Hall threshold; lake edge). Render-only overrides; the pinned scripts are not edited.
## Installed from ship_settlement_preview.gd in the same frame as GrassViewCulling.install, before
## that splits the grass batches (the lip trims blade instances in the original batches).
const Stairwell = preload("res://raid/scripts/hall_stairwell_finish.gd")
const Lips = preload("res://raid/scripts/grass_edge_lips.gd")
const Threshold = preload("res://raid/scripts/hall_threshold_finish.gd")
const META := "p1_visual_fixes"

static func install(world: Node3D) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var r := {"stairwell": Stairwell.install(world), "threshold": Threshold.install(world), "lips": Lips.install(world)}
	_defer_lips(world)
	r["install_ms"] = snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.1)
	world.set_meta(META, r)
	return r

## The inn and the garden controllers install after activation and screen visible scenery for
## overlap (scripts/inn_site_install.gd, market_edge_gardens.gd, ... pinned). The lips are baked
## against the finished layout, so the lip node stays hidden until the world is activated and every
## startup controller (a child with `attempted`) has finished, then shows.
static func controllers_settled(world: Node3D) -> bool:
	if world.get("world_activated") != true:
		return false
	for c in world.get_children():
		if not "attempted" in c:
			continue
		if not bool(c.get("attempted")):
			return false
		if "result" in c and c.get("result") is Dictionary and (c.get("result") as Dictionary).is_empty():
			return false
	return true

static func _defer_lips(world: Node3D) -> void:
	var node := world.get_node_or_null("GrassEdgeLips") as Node3D
	if node == null or not world.is_inside_tree():
		return
	node.visible = false
	var tree := world.get_tree()
	var state := {"cb": Callable(), "settled_frames": 0, "activated_ms": -1}
	state.cb = func() -> void:
		if not is_instance_valid(world) or not is_instance_valid(node):
			tree.process_frame.disconnect(state.cb)
			return
		if world.get("world_activated") == true and state.activated_ms < 0:
			state.activated_ms = Time.get_ticks_msec()
		var settled := controllers_settled(world)
		state.settled_frames = state.settled_frames + 1 if settled else 0
		var timed_out: bool = state.activated_ms >= 0 and Time.get_ticks_msec() - state.activated_ms > 900000
		if state.settled_frames >= 3 or timed_out:
			node.visible = true
			node.set_meta("revealed_after_inn", settled)
			tree.process_frame.disconnect(state.cb)
	tree.process_frame.connect(state.cb)
