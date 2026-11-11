extends RefCounted
## Visual feedback only. Original bodies, labels, puzzle state and audio own all
## gameplay. Imported parts never add collision or throttle an interaction.
const VALVE=preload("res://raid/assets/puzzle_controls/valve_echo_cistern.glb")
const RELAY=preload("res://raid/assets/puzzle_controls/relay_lever_weather_station.glb")
const VALVE_TURN_DEGREES:=90.0
const RELAY_REST_DEGREES:=-40.0
const RELAY_THROW_DEGREES:=40.0

static func attach(body:Node3D,valve:bool)->Node3D:
	var art=(VALVE if valve else RELAY).instantiate()
	art.name="PuzzleControlArt";art.position.y=-0.9;body.add_child(art)
	art.set_meta("valve",valve)
	if not valve:
		art.find_child("Relay_Lever",true,false).rotation_degrees.x=RELAY_REST_DEGREES
		# Duplicate the lamp material, not the whole housing or shared GLB. A press
		# must not brighten the two other relays or recolor their steel parts.
		var indicator=art.find_child("Relay_Indicator",true,false) as MeshInstance3D
		var material=indicator.get_active_material(0).duplicate() as StandardMaterial3D
		indicator.set_surface_override_material(0,material)
		art.set_meta("indicator_material",material)
		art.set_meta("indicator_energy",material.emission_energy_multiplier)
	return art

static func activate(body:Node3D):
	var art=body.get_node_or_null("PuzzleControlArt")
	if art==null:return
	# Restart from the visible pose on fast repeated input. No queued motions,
	# stale completion callbacks, busy flags or changes to sequence evaluation.
	var previous=art.get_meta("motion") as Tween if art.has_meta("motion") else null
	if previous!=null and previous.is_valid():previous.kill()
	var motion=art.create_tween()
	art.set_meta("motion",motion)
	if art.get_meta("valve",false):
		var wheel=art.find_child("Valve_Wheel",true,false) as Node3D
		wheel.rotation_degrees.z=fposmod(wheel.rotation_degrees.z,360.0)
		var goal=wheel.rotation_degrees.z+VALVE_TURN_DEGREES
		motion.tween_property(wheel,"rotation_degrees:z",goal,0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		var lever=art.find_child("Relay_Lever",true,false) as Node3D
		var lamp=art.get_meta("indicator_material") as StandardMaterial3D
		var energy:float=art.get_meta("indicator_energy")
		lamp.emission_energy_multiplier=energy*1.7
		motion.tween_property(lever,"rotation_degrees:x",RELAY_THROW_DEGREES,0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		motion.tween_interval(0.06)
		motion.tween_property(lever,"rotation_degrees:x",RELAY_REST_DEGREES,0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		motion.parallel().tween_property(lamp,"emission_energy_multiplier",energy,0.2)
