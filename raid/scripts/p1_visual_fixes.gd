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

## The inn installs a few frames later and screens visible scenery for overlap with its approach
## treads (scripts/inn_site_install.gd, pinned). The stair-foot lips are baked against those treads,
## so the lip node stays hidden until the inn has attempted its install, then shows (max 45 s).
static func _defer_lips(world: Node3D) -> void:
	var node := world.get_node_or_null("GrassEdgeLips") as Node3D
	if node == null or not world.is_inside_tree():
		return
	node.visible = false
	var started := Time.get_ticks_msec()
	var tree := world.get_tree()
	var state := {"cb": Callable()}
	state.cb = func() -> void:
		var inn = world.get("inn_site")
		var done: bool = inn == null or not is_instance_valid(inn) or bool(inn.get("attempted"))
		if done or Time.get_ticks_msec() - started > 45000:
			if is_instance_valid(node):
				node.visible = true
				node.set_meta("revealed_after_inn", done)
			tree.process_frame.disconnect(state.cb)
	tree.process_frame.connect(state.cb)
