extends "res://scripts/player.gd"
## Raid-only player variant used ONLY when worn tiered gear crosses a weight band
## (TASKS item 22, PR B). scripts/player.gd is pinned and untouched; this scales the
## speed handed to its step_motion. With no gear the raid keeps using player.gd itself.
var gear_sprint_mult := 1.0
var gear_walk_mult := 1.0
const SPRINT_THRESHOLD := 5.0  # player.gd passes 7.0 sprinting, 4.2 walking

func step_motion(direction: Vector3, speed: float, jumping: bool, delta: float):
	var mult := gear_sprint_mult if speed > SPRINT_THRESHOLD else gear_walk_mult
	super.step_motion(direction, speed * mult, jumping, delta)
