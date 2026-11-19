extends Node
## Queue item 2b (Ori, playtest2): the HUD title "S E T T L E M E N T / FIRST PLAYABLE" stayed on
## screen in every mode. settlement.gd (pinned) builds it as an unnamed Label under hud_root; this
## node fades it out HOLD_S seconds after gameplay starts, or as soon as the player steps out of
## the Town Hall, whichever comes first. Wall-clock time, so slow software frames do not stretch it.
const NAME := "HudTitleFade"
const TITLE_PREFIX := "S E T T L E M E N T"
const HOLD_S := 6.0
const FADE_S := 1.2
## Town Hall interior footprint (x, z), as used by the item 21 stall work.
const HALL_X := Vector2(-8.8, 8.8)
const HALL_Z := Vector2(-31.8, -14.2)
var world: Node
var title: Label
var started_ms := -1
var fade_started_ms := -1
var reason := ""
var done := false

static func install(w: Node) -> Node:
	if not is_instance_valid(w): return null
	var existing = w.get_node_or_null(NAME)
	if existing != null: return existing
	var label := find_title(w)
	if label == null: return null
	var n = load("res://raid/scripts/hud_title_fade.gd").new()
	n.name = NAME
	n.world = w
	n.title = label
	w.add_child(n)
	return n

static func find_title(w: Node) -> Label:
	var root = w.get("hud_root")
	if not is_instance_valid(root): return null
	for c in root.get_children():
		if c is Label and str(c.text).begins_with(TITLE_PREFIX): return c
	return null

static func in_hall(pos: Vector3) -> bool:
	return pos.x > HALL_X.x and pos.x < HALL_X.y and pos.z > HALL_Z.x and pos.z < HALL_Z.y

func begin_fade(why: String) -> void:
	if fade_started_ms >= 0 or done: return
	fade_started_ms = Time.get_ticks_msec()
	reason = why

func _process(_delta: float) -> void:
	if done or not is_instance_valid(title): return
	if world.get("world_activated") != true: return
	var now := Time.get_ticks_msec()
	if started_ms < 0: started_ms = now
	var p = world.get("player")
	if fade_started_ms < 0:
		if is_instance_valid(p) and not in_hall(p.global_position): begin_fade("left_town_hall")
		elif now - started_ms >= int(HOLD_S * 1000.0): begin_fade("timer")
		return
	var t := clampf(float(now - fade_started_ms) / (FADE_S * 1000.0), 0.0, 1.0)
	title.modulate.a = 1.0 - t
	if t >= 1.0:
		title.visible = false
		done = true
