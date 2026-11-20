extends Node
## PR B: Artie's lamp glass (SS_LampGlass, flat warm #ffc174) ships lit (emission energy 0.65). This node
## follows the existing cosmetic DayNightCycle (read only, no clock or lighting edits): the glass runs at
## DAY_ENERGY in full daylight and NIGHT_ENERGY at night, and the dusk OmniLights the kits registered fade
## in as daylight drops (hidden, so free, by day). Updated a few times a second, not every frame.
const NAME := "P2BLampCycle"
const DAY_ENERGY := 0.2
const NIGHT_ENERGY := 1.6
const INTERVAL := 0.25
var materials: Array = []
var lights: Array = []    # [OmniLight3D, night energy]
var cycle: Node
var daylight := -1.0
var since := 0.0

static func attach(world: Node3D, mats: Array, lts: Array) -> Dictionary:
	var n = world.get_node_or_null(NAME)
	if n == null:
		n = load("res://raid/scripts/p2b_lamp_cycle.gd").new()
		n.name = NAME
		world.add_child(n)
	n.materials = mats
	n.lights = lts
	n.cycle = world.get_node_or_null("DayNightCycle")
	n.refresh(true)
	return {"ok": true, "materials": mats.size(), "lights": lts.size(), "cycle": n.cycle != null, "daylight": n.daylight}

func current_daylight() -> float:
	if cycle == null or not is_instance_valid(cycle):
		return 1.0
	var s: Dictionary = cycle.sample(float(cycle.elapsed_seconds) / maxf(float(cycle.cycle_seconds), 1.0))
	return float(s.daylight)

func refresh(force := false) -> void:
	var d := current_daylight()
	if not force and absf(d - daylight) < 0.002:
		return
	daylight = d
	var night := 1.0 - d
	for m in materials:
		if is_instance_valid(m):
			(m as BaseMaterial3D).emission_energy_multiplier = lerpf(NIGHT_ENERGY, DAY_ENERGY, d)
	for pair in lights:
		var l := pair[0] as Light3D
		if not is_instance_valid(l): continue
		l.light_energy = float(pair[1]) * night
		l.visible = night > 0.03

func _process(delta: float) -> void:
	since += delta
	if since < INTERVAL: return
	since = 0.0
	refresh()
