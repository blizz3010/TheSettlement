extends RefCounted
## Visual-only imported props. Existing target bodies keep their collision and
## centre positions so ray targeting, extraction height and routes stay stable.
const CACHE_WOODLAND=preload("res://raid/assets/props/loot_cache_woodland.glb")
const CACHE_SALTFLAT=preload("res://raid/assets/props/loot_cache_saltflat.glb")
const BEACON_WOODLAND=preload("res://raid/assets/props/extraction_beacon_woodland.glb")
const BEACON_SALTFLAT=preload("res://raid/assets/props/extraction_beacon_saltflat.glb")

static func attach_cache(body:Node3D,saltflat:bool)->Node3D:
	var art=(CACHE_SALTFLAT if saltflat else CACHE_WOODLAND).instantiate()
	art.name="CacheArt";art.position.y=-0.5;body.add_child(art)
	return art

static func attach_beacon(body:Node3D,saltflat:bool)->Node3D:
	var art=(BEACON_SALTFLAT if saltflat else BEACON_WOODLAND).instantiate()
	art.name="BeaconArt";art.position.y=-1.0;body.add_child(art)
	# Per-instance material copies prevent one beacon from pulsing another one.
	var glow=art.find_child("Beacon_Light_Glow",true,false) as MeshInstance3D
	var materials:Array=[]
	for index in glow.mesh.get_surface_count():
		var original=glow.get_active_material(index) as StandardMaterial3D
		if original!=null and original.emission_enabled:
			var material=original.duplicate() as StandardMaterial3D
			glow.set_surface_override_material(index,material)
			materials.append({"material":material,"energy":material.emission_energy_multiplier})
	art.set_meta("glow_materials",materials)
	return art

static func open_cache(body:Node3D):
	var art=body.get_node_or_null("CacheArt")
	if art==null or art.get_meta("opened",false):return
	var lid=art.find_child("Cache_Lid",true,false) as Node3D
	if lid==null:return
	art.set_meta("opened",true)
	# The hasp is a child of the supplied hinge and travels with the lid.
	art.create_tween().tween_property(lid,"rotation_degrees:x",-70.0,0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

static func beacon_state(body:Node3D,state:String,seconds:float=0.0):
	var art=body.get_node_or_null("BeaconArt")
	if art==null:return
	art.set_meta("signal_state",state)
	var multiplier=1.0
	if state=="active":multiplier=1.15+0.35*(0.5+0.5*sin(seconds*TAU))
	elif state=="complete":multiplier=1.6
	for slot in art.get_meta("glow_materials",[]):
		slot.material.emission_energy_multiplier=slot.energy*multiplier
