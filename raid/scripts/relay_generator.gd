extends RefCounted
const Config = preload("res://raid/scripts/relay_config.gd")
var config: Resource
var noise := FastNoiseLite.new()
var forest := FastNoiseLite.new()
var pois: Array
var routes: Array
var pads: Array
func _init(settings: Resource = null):
	config = settings if settings != null else Config.new()
	assert(config.valid(), "Invalid Relay Ridge settings")
	noise.seed=config.map_seed
	noise.frequency=0.012
	noise.fractal_octaves=3
	forest.seed=config.map_seed+137
	forest.frequency=0.027
	pois=config.pois()
	routes=config.routes()
	pads=pois.duplicate(true)
	pads.append({"id":"spawn","at":config.SPAWN,"radius":10.0})
	for i in config.EXTRACTS.size(): pads.append({"id":"extract%d"%i,"at":config.EXTRACTS[i],"radius":10.0})
func base_height(p:Vector2)->float:
	var ridge=9.0*exp(-pow((p.x-10.0)/69.0,2.0)-pow((p.y+18.0)/110.0,2.0))
	var rim=pow(clampf((maxf(absf(p.x),absf(p.y))-139.0)/48.0,0.0,1.0),1.6)*27.0
	return 4.0+ridge+noise.get_noise_2d(p.x,p.y)*config.terrain_amplitude+rim
func height_at(p:Vector2)->float:
	var result=base_height(p)
	for pad in pads:
		var distance=p.distance_to(pad.at)
		var weight=1.0-smoothstep(pad.radius,pad.radius+19.0,distance)
		result=lerpf(result,base_height(pad.at),weight)
	return result
func slope_at(p:Vector2)->float:
	return Vector2(height_at(p+Vector2(1,0))-height_at(p-Vector2(1,0)),height_at(p+Vector2(0,1))-height_at(p-Vector2(0,1))).length()/2.0

func triangle_grade_at(p:Vector2)->float:
	# Exact gradient of the same two triangles used by build_terrain, not the
	# smooth height sampler. Check the whole slope, including across the trail.
	var cell=config.CELL
	var corner=Vector2(floorf(p.x/cell)*cell,floorf(p.y/cell)*cell)
	var local=p-corner
	var a=height_at(corner)
	var b=height_at(corner+Vector2(cell,0))
	var c=height_at(corner+Vector2(0,cell))
	if local.x+local.y<=cell:return Vector2(b-a,c-a).length()/cell
	var d=height_at(corner+Vector2(cell,cell))
	return Vector2(d-c,d-b).length()/cell

func validate_travel_layout()->Dictionary:
	# Bounded preflight for the authored trail corridor. This is not a promise
	# that arbitrary off-trail terrain or every designer configuration is safe.
	var max_grade=0.0
	var worst_point=Vector2.ZERO
	var worst_route=-1
	var samples=0
	for route_index in routes.size():
		var route:Array=routes[route_index]
		for index in range(route.size()-1):
			var start:Vector2=route[index]
			var end:Vector2=route[index+1]
			var direction=(end-start).normalized()
			var side=Vector2(-direction.y,direction.x)
			var steps=maxi(1,ceili(start.distance_to(end)/0.5))
			for step in range(steps+1):
				var centre=start.lerp(end,float(step)/steps)
				for offset in [-0.6,0.0,0.6]:
					var point=centre+side*offset
					var grade=triangle_grade_at(point)
					samples+=1
					if not is_finite(grade):return {"ok":false,"reason":"Trail terrain is not finite.","samples":samples}
					if grade>max_grade:max_grade=grade;worst_point=point;worst_route=route_index
	return {"ok":max_grade<=0.7,"max_triangle_grade":max_grade,"grade_limit":0.7,
		"samples":samples,"worst_route":worst_route,"worst_point":worst_point,
		"reason":"" if max_grade<=0.7 else "Trail terrain is too steep for this preview. Lower terrain amplitude or choose another seed."}
func route_distance(p:Vector2)->float:
	var best=INF
	for route in routes:
		for i in range(route.size()-1):
			best=minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,route[i],route[i+1])))
	return best
func reserved(p:Vector2,margin:float=0.0)->bool:
	if maxf(absf(p.x),absf(p.y))>config.PLAY_HALF-margin:return true
	if route_distance(p)<4.0+margin:return true
	for pad in pads:
		if p.distance_to(pad.at)<pad.radius+2.0+margin:return true
	return false
func ground_color(p:Vector2)->Color:
	var shade=clampf((forest.get_noise_2d(p.x,p.y)+1.0)*0.5,0.0,1.0)
	var grass=Color("3d5946").lerp(Color("71835b"),shade)
	var trail=1.0-smoothstep(2.3,4.4,route_distance(p))
	var slope=smoothstep(0.42,0.83,slope_at(p))
	for pad in pads:trail=maxf(trail,(1.0-smoothstep(pad.radius-3.0,pad.radius+2.0,p.distance_to(pad.at)))*0.7)
	return grass.lerp(Color("88816b"),maxf(slope,trail))
func placements(kind:String)->Array:
	var density:float=config.get(kind+"_density")
	var spacing:float={"tree":6.0,"grass":2.6,"shrub":5.0,"rock":7.0}[kind]
	var salt:int={"tree":1103,"grass":2207,"shrub":3301,"rock":4409}[kind]
	var rng=RandomNumberGenerator.new();rng.seed=config.map_seed+salt
	var result:Array=[]
	var count=int(config.PLAY_HALF*2.0/spacing)
	for z in count:
		for x in count:
			# Consume exactly the same random sequence regardless of density/filtering.
			var p=Vector2(-config.PLAY_HALF+(x+0.5)*spacing,-config.PLAY_HALF+(z+0.5)*spacing)+Vector2(rng.randf_range(-0.3,0.3),rng.randf_range(-0.3,0.3))*spacing
			var roll=rng.randf();var yaw=rng.randf()*TAU;var size=rng.randf_range(0.8,1.25)
			var moisture=clampf(0.6+forest.get_noise_2d(p.x,p.y)*0.8,0.18,1.0)
			var margin=2.0 if kind=="tree" else 0.8 if kind=="rock" else 0.0
			if roll>density*(moisture if kind in ["tree","shrub"] else 1.0) or reserved(p,margin) or slope_at(p)>0.48:continue
			result.append({"position":Vector3(p.x,height_at(p),p.y),"yaw":yaw,"scale":size})
	return result
func build_terrain(parent:Node3D)->Dictionary:
	var terrain=Node3D.new();terrain.name="SeededTerrain";parent.add_child(terrain)
	var material=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.roughness=1.0
	var triangles=0
	var steps=int(config.CHUNK/config.CELL)
	for cz in range(-6,6):
		for cx in range(-6,6):
			var vertices=PackedVector3Array();var normals=PackedVector3Array();var colors=PackedColorArray();var indices=PackedInt32Array()
			for z in range(steps+1):
				for x in range(steps+1):
					var p=Vector2(cx*config.CHUNK+x*config.CELL,cz*config.CHUNK+z*config.CELL)
					vertices.append(Vector3(p.x,height_at(p),p.y))
					normals.append(Vector3(height_at(p-Vector2(1,0))-height_at(p+Vector2(1,0)),2.0,height_at(p-Vector2(0,1))-height_at(p+Vector2(0,1))).normalized())
					colors.append(ground_color(p))
			for z in steps:
				for x in steps:
					var a=z*(steps+1)+x;var b=a+1;var c=a+steps+1;var d=c+1
					indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
			var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
			var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var instance=MeshInstance3D.new();instance.mesh=mesh;instance.material_override=material;instance.name="Terrain_%d_%d"%[cx,cz];terrain.add_child(instance)
			var body=StaticBody3D.new();body.set_meta("audio_surface","soil");var collision=CollisionShape3D.new();collision.shape=mesh.create_trimesh_shape();body.add_child(collision);terrain.add_child(body)
			triangles+=indices.size()/3
	return {"chunks":terrain.get_child_count()/2,"triangles":triangles}
