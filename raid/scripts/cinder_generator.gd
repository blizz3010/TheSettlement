extends "res://raid/scripts/relay_generator.gd"
## Reuse exact mesh/collision, exclusion, deterministic streams and travel guard.
## Change the landform and ecology, not the tested terrain/collision contract.
const CinderConfig=preload("res://raid/scripts/cinder_config.gd")
func _init(settings:Resource=null):
	super(settings if settings!=null else CinderConfig.new())
	noise.frequency=0.009
	noise.fractal_octaves=3
	forest.frequency=0.021
func base_height(p:Vector2)->float:
	var basin=-2.6*exp(-pow(p.x/105.0,2.0)-pow(p.y/92.0,2.0))
	var escarpment=4.3*exp(-pow((p.x+100.0)/65.0,2.0)-pow((p.y+80.0)/65.0,2.0))
	var dunes=0.7*sin(p.x*0.032+p.y*0.016)*cos(p.y*0.019)
	var rim=pow(clampf((maxf(absf(p.x),absf(p.y))-139.0)/48.0,0.0,1.0),1.7)*30.0
	return 6.0+basin+escarpment+dunes+noise.get_noise_2d(p.x,p.y)*config.terrain_amplitude+rim
func ground_color(p:Vector2)->Color:
	var mineral=clampf(0.5+forest.get_noise_2d(p.x,p.y)*0.65,0.0,1.0)
	var salt=1.0-smoothstep(32.0,96.0,Vector2(p.x*0.85,p.y*1.15).length())
	var ash=Color("977452").lerp(Color("c8a576"),mineral)
	var ground=ash.lerp(Color("d8d4b6"),salt*0.88)
	var basalt=smoothstep(0.24,0.65,slope_at(p))
	ground=ground.lerp(Color("49464a"),basalt*0.85)
	var trail=1.0-smoothstep(2.4,4.5,route_distance(p))
	for pad in pads:trail=maxf(trail,(1.0-smoothstep(pad.radius-3.0,pad.radius+2.0,p.distance_to(pad.at)))*0.55)
	return ground.lerp(Color("a89172"),trail*0.78)
func placements(kind:String)->Array:
	var candidates:Array=super.placements(kind)
	# The heart of the basin is sparse, open salt; tall plants gather at the rim.
	return candidates.filter(func(item):
		var p=Vector2(item.position.x,item.position.z)
		if kind=="tree":return p.length()>74.0
		if kind=="grass":return p.length()>58.0
		return true)
