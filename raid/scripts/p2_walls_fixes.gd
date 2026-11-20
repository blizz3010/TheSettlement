extends RefCounted
## TASKS item 5, PR B: the P2 items left after PR A (#36), render-side at runtime, no pinned edits.
##   walls     - retaining_walls_install.gd   Artie's stone kit on the hideout terrace (Option A) + ship pad
##   hillside  - inn_hillside_finish.gd       patchy inn-hill turf and blades, the dead-end path stub finished
##   trees     - scenery_tone_fixes.gd        the lime plaza CommonTree crowns toned to a natural green
##   planet    - scenery_tone_fixes.gd        the valley body smaller and washed out by day
##   inn_door  - inn_door_install.gd          Artie's front + side door leaves (open on approach)
##   undercroft- inn_undercroft_install.gd    bays, pile dressing, landing and props under the inn balconies
##   hall      - townhall_ceiling_install.gd  trusses, coffered liner, chandeliers + pendants in the nave
##   lamps     - p2b_lamp_cycle.gd            lamp-glass emission and dusk lights follow DayNightCycle
## Installed from ship_settlement_preview.gd right after P2Art.install in both startup passes. Like P2 it
## waits until every startup controller has settled (and P2 art has swapped), so the inn / garden /
## foliage planners ran against exactly the scene they were written for. Runs once; world meta "p2b".
## P2B=off skips everything (P2_ART=off too); P2B_<ITEM>=off skips one item.
const Walls = preload("res://raid/scripts/retaining_walls_install.gd")
const Hillside = preload("res://raid/scripts/inn_hillside_finish.gd")
const Tone = preload("res://raid/scripts/scenery_tone_fixes.gd")
const InnDoor = preload("res://raid/scripts/inn_door_install.gd")
const Undercroft = preload("res://raid/scripts/inn_undercroft_install.gd")
const HallCeiling = preload("res://raid/scripts/townhall_ceiling_install.gd")
const LampCycle = preload("res://raid/scripts/p2b_lamp_cycle.gd")
const ITEMS := ["walls", "hillside", "trees", "planet", "inn_door", "undercroft", "hall", "lamps"]
const META := "p2b"
const TIMEOUT_MS := 900000

static func enabled(item := "") -> bool:
	if OS.get_environment("P2B") == "off" or OS.get_environment("P2_ART") == "off":
		return false
	return item == "" or OS.get_environment("P2B_" + item.to_upper()) != "off"

static func install(world: Node3D) -> void:
	if not enabled() or not is_instance_valid(world) or not world.is_inside_tree():
		return
	if world.has_meta(META) or world.has_meta("p2b_pending"):
		return
	world.set_meta("p2b_pending", true)
	var tree := world.get_tree()
	var state := {"cb": Callable(), "settled": 0, "activated_ms": -1}
	state.cb = func() -> void:
		if not is_instance_valid(world):
			tree.process_frame.disconnect(state.cb)
			return
		if world.get("world_activated") == true and state.activated_ms < 0:
			state.activated_ms = Time.get_ticks_msec()
		var settled := controllers_settled(world)
		state.settled = state.settled + 1 if settled else 0
		var timed_out: bool = state.activated_ms >= 0 and Time.get_ticks_msec() - state.activated_ms > TIMEOUT_MS
		if state.settled >= 3 or timed_out:
			tree.process_frame.disconnect(state.cb)
			var r := apply(world)
			r["after_settle"] = settled
			world.remove_meta("p2b_pending")
			world.set_meta(META, r)
	tree.process_frame.connect(state.cb)

static func controllers_settled(world: Node3D) -> bool:
	if world.get("world_activated") != true:
		return false
	if not world.has_meta("p2_art"):   # P2 art swaps first (same deferral), so its trees exist
		return false
	for c in world.get_children():
		if not "attempted" in c:
			continue
		if not bool(c.get("attempted")):
			return false
		if "result" in c and c.get("result") is Dictionary and (c.get("result") as Dictionary).is_empty():
			return false
	return true

static func apply(world: Node3D) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var out := {"ok": true}
	var lamps: Array = []   # [material, day energy, night energy] / lights registered by the kits
	var lights: Array = []
	for item in ITEMS:
		if not enabled(item):
			out[item] = {"ok": true, "skipped": true}
			continue
		var t1 := Time.get_ticks_usec()
		var r: Dictionary
		match item:
			"walls": r = Walls.apply(world)
			"hillside": r = Hillside.apply(world)
			"trees": r = Tone.plaza_trees(world)
			"planet": r = Tone.planet(world)
			"inn_door": r = InnDoor.apply(world, lamps, lights)
			"undercroft": r = Undercroft.apply(world, lamps, lights)
			"hall": r = HallCeiling.apply(world, lamps, lights)
			"lamps": r = LampCycle.attach(world, lamps, lights)
		r["ms"] = snappedf((Time.get_ticks_usec() - t1) / 1000.0, 0.1)
		out[item] = r
		if not r.get("ok", false):
			out.ok = false
	out["install_ms"] = snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.1)
	return out
