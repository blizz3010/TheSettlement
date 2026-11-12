extends "res://raid/scripts/raid_world.gd"
## Cinder Basin uses the tested raid lifecycle with its own world and landmarks.
const CinderConfig=preload("res://raid/scripts/cinder_config.gd")
func _default_settings()->Resource:return CinderConfig.new()
func _create_generator(config:Resource):return preload("res://raid/scripts/cinder_generator.gd").new(config)
func _create_state(seed_number:int):return preload("res://raid/scripts/cinder_state.gd").new(seed_number)
func _build_foliage(parent:Node3D)->Dictionary:return preload("res://raid/scripts/cinder_foliage.gd").new().build(parent,generator)
func _map_name()->String:return "Cinder Basin"
func _saltflat_props()->bool:return true
func _wild_region()->String:return "Salt flats / basalt approaches"
func _region_detail(poi:Dictionary)->String:
	if poi.id!="obsidian":return ""
	return preload("res://raid/scripts/archive_wayfinding.gd").location_hint(get_node("obsidian").to_local(player.global_position))
func _extract_names()->Array:return ["Siltway Lift Extract","Caldera Rim Extract"]
func _pause_description()->String:return "Cross pale salt flats and black basalt outcrops. Explore six abandoned desert sites, two high-quality caches, service key / archive card / calibration-code doors and the Echo Cistern valve puzzle. Geology and dry vegetation use independent repeatable seed streams."
func _locked_hint(poi:Dictionary)->String:return {"key":"the glasskiln service key","keycard":"the Obsidian Archive clearance card","puzzle":"the cistern service log and solve the three-valve sequence"}[poi.lock]
func _switch_feedback(solved:bool)->String:return "Reservoir archive released. The cistern partition can now open." if solved else "Valve sequence: %d / 3"%raid_state.switch_step
func _switch_prompt(number:int)->String:return "Turn cistern valve %d"%number
func _switch_sound(target:Dictionary):raid_audio.play_valve(target.number,target.node.global_position)
func _setup_environment():
	var world=WorldEnvironment.new();var env=Environment.new();world.environment=env
	env.background_mode=Environment.BG_SKY
	var sky=Sky.new();var material=ProceduralSkyMaterial.new()
	material.sky_top_color=Color("5d7189");material.sky_horizon_color=Color("d7ba92");material.ground_horizon_color=Color("c0a07a");material.ground_bottom_color=Color("65534e");sky.sky_material=material;env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("d3bea4");env.ambient_light_energy=0.72;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.fog_enabled=true;env.fog_light_color=Color("ceb18c");env.fog_density=0.0022;add_child(world)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-34,48,0);sun.light_color=Color("ffdab0");sun.light_energy=1.6;sun.shadow_enabled=true;sun.directional_shadow_max_distance=110;add_child(sun)
func _room(root:Node3D,poi:Dictionary,width:float,depth:float,roof:bool=true):
	var back=5.0-depth;var centre=5.0-depth*0.5;var wall=poi.theme.darkened(0.43)
	_box(root,Vector3(0,-0.12,centre),Vector3(width,0.24,depth),Color("8f8270"))
	_box(root,Vector3(-width*0.5,1.9,centre),Vector3(0.3,3.8,depth),wall)
	_box(root,Vector3(width*0.5,1.9,centre),Vector3(0.3,3.8,depth),wall)
	_box(root,Vector3(0,1.9,back),Vector3(width,3.8,0.3),wall)
	if poi.lock!="" or poi.id=="sump":
		var side_width=(width-2.6)*0.5;var side_x=1.3+side_width*0.5
		for x in [-side_x,side_x]:_box(root,Vector3(x,1.9,5),Vector3(side_width,3.8,0.3),wall)
		_box(root,Vector3(0,3.3,5),Vector3(2.6,1.0,0.3),wall)
	if roof:_box(root,Vector3(0,3.9,centre),Vector3(width+0.6,0.22,depth+0.6),Color("4d4545"))
	if poi.lock!="":
		var door_z=-1.0 if poi.lock=="puzzle" else 5.0
		if poi.lock=="puzzle":
			for x in [-3.65,3.65]:_box(root,Vector3(x,1.9,-1),Vector3(4.7,3.8,0.3),wall)
			_box(root,Vector3(0,3.3,-1),Vector3(2.6,1.0,0.3),wall)
		var door=_box(root,Vector3(0,1.35,door_z),Vector3(2.5,2.7,0.24),poi.theme)
		door_nodes[poi.id]=door;_target("door",door,poi)
		if poi.lock!="puzzle":_label(root,poi.lock.to_upper()+" ACCESS",Vector3(0,2.9,5.3),poi.theme,18)
		_build_field_supplies(root,poi)
		_label(root,"FIELD SUPPLIES",Vector3(-9,1.6,7),Color("f0dcae"),19)
	var cache_z=-3.0 if poi.lock=="puzzle" else -1.0
	var cache=_build_cache(root,Vector3(0,0.5,cache_z));_target("cache",cache,poi)
func _tank(root:Node3D,at:Vector3,height:float,radius:float,color:Color):
	_cylinder(root,at+Vector3.UP*height*0.5,height,radius,color)
	var body=StaticBody3D.new();body.position=at;root.add_child(body)
	var shape=CollisionShape3D.new();var cylinder=CylinderShape3D.new();cylinder.height=height;cylinder.radius=radius;shape.shape=cylinder;shape.position.y=height*0.5;body.add_child(shape)
func _build_poi(poi:Dictionary):
	var root=Node3D.new();root.name=poi.id;root.position=Vector3(poi.at.x,generator.height_at(poi.at),poi.at.y);add_child(root)
	_label(root,poi.name.to_upper(),Vector3(0,14,0) if poi.id=="obsidian" else Vector3(0,6,7),poi.theme,40)
	match poi.id:
		"caravan":
			_room(root,poi,10,9,false)
			# Open front caravan canopy, two wheeled cargo cabins and a wind pennant.
			var awning=_box(root,Vector3(0,4.4,0.5),Vector3(12,0.14,12),Color("cfa46b"),false);awning.rotation_degrees.z=7
			for x in [-13,13]:
				_box(root,Vector3(x,1.65,-4),Vector3(4.5,2.7,8),Color("987752"))
				for z in [-6,-2]:_cylinder(root,Vector3(x,0.35,z),0.7,0.8,Color("38353a"))
			_cylinder(root,Vector3(8,5,5),10,0.07,Color("c7bfa8"));_box(root,Vector3(9.2,9,5),Vector3(2.4,0.8,0.08),Color("d48e55"),false)
		"glasskiln":
			preload("res://raid/scripts/glasskiln_campus.gd").new().build(self,root,poi)
		"helion":
			_room(root,poi,10,8)
			preload("res://raid/scripts/cinder_landmarks.gd").new().build_helion(self,root)
		"obsidian":
			preload("res://raid/scripts/obsidian_archive.gd").new().build(self,root,poi)
		"sump":
			_room(root,poi,10,10,false)
			for x in [-12,12]:
				_tank(root,Vector3(x,0,-5),4.8,3.0,Color("687568"))
				_cylinder(root,Vector3(x,4.9,-5),0.12,2.6,Color("526f6d"))
				_box(root,Vector3(x,1,0),Vector3(3,2,3),Color("8c6d52"))
			# Elevated service pipe leaves the front door and supplies approaches clear.
			_box(root,Vector3(0,5.6,-6),Vector3(25,0.65,0.65),Color("8a7964"),false)
		"cistern":
			_room(root,poi,12,12)
			_tank(root,Vector3(0,4,-3),7,4.2,Color("597b7c"))
			_cylinder(root,Vector3(0,11.2,-3),0.4,4.7,Color("a0c2bc"))
			for i in 3:
				var post=_build_puzzle_control(root,Vector3(-4+i*4,0.9,9),true);_target("switch",post,poi,{"number":i+1})
				_label(root,["PRIME / 1","RETURN / 2","STEAM / 3"][i],Vector3(-4+i*4,2.3,9),Color.WHITE,17)
