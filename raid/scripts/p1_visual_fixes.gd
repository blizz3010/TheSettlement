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
	r["install_ms"] = snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.1)
	world.set_meta(META, r)
	return r
