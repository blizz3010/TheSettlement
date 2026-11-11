extends SceneTree
## Imported-node, transform, motion, state, targeting and collision checks.
## Headless coverage does not verify rendered appearance or native input.
const Controls=preload("res://raid/scripts/puzzle_controls.gd")
var checks:=0
var failures:Array=[]
var imported:Array=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func box(art:Node3D)->AABB:
	var result:=AABB();var first=true
	for mesh in art.find_children("*","MeshInstance3D",true,false):
		var value=art.global_transform.affine_inverse()*mesh.global_transform*mesh.mesh.get_aabb()
		result=value if first else result.merge(value);first=false
	return result
func triangles(art:Node3D)->int:
	var total:=0
	for mesh in art.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():total+=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()/3
	return total
func vertex_box(art:Node3D)->AABB:
	var result:=AABB();var first=true
	for mesh in art.find_children("*","MeshInstance3D",true,false):
		var transform=art.global_transform.affine_inverse()*mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point=transform*vertex
				result=AABB(point,Vector3.ZERO) if first else result.expand(point);first=false
	return result
func verify_imports():
	for valve in [true,false]:
		var holder=Node3D.new();root.add_child(holder)
		var art=Controls.attach(holder,valve)
		var moving=art.find_child("Valve_Wheel" if valve else "Relay_Lever",true,false) as MeshInstance3D
		check(moving!=null,"Moving part keeps exact name and MeshInstance3D type")
		check(art.find_children("*","VehicleWheel3D",true,false).is_empty(),"No automatic VehicleWheel3D replacement")
		check(art.find_children("*","CollisionObject3D",true,false).is_empty(),"GLB adds no collision bodies")
		check(art.find_children("*","CollisionShape3D",true,false).is_empty(),"GLB adds no collision shapes")
		check(art.find_children("*","Light3D",true,false).is_empty(),"No embedded light changes the map lighting")
		check(art.find_children("*","AnimationPlayer",true,false).is_empty(),"No embedded animations run")
		check(moving.position.is_equal_approx(Vector3(0,1.45,0.36) if valve else Vector3(0,1.2,0.4)),"Imported axle/hinge location")
		check(moving.scale.is_equal_approx(Vector3.ONE),"Moving part unit scale")
		check(triangles(art)==(1500 if valve else 1014),"Imported full-resolution triangle count")
		check(art.position.is_equal_approx(Vector3(0,-0.9,0)) and art.scale==Vector3.ONE,"Exact size and ground offset")
		var fixed=art.find_child("Valve_Pedestal" if valve else "Relay_Housing",true,false) as MeshInstance3D
		check(fixed.transform.is_equal_approx(Transform3D.IDENTITY),"Stationary part has applied transforms")
		check(fixed.mesh.get_aabb().size.is_equal_approx(Vector3(0.6,1.8,0.6)),"Housing matches original collision envelope")
		var config=ConfigFile.new()
		var path="valve_echo_cistern" if valve else "relay_lever_weather_station"
		check(config.load("res://raid/assets/puzzle_controls/"+path+".glb.import")==OK,"Import settings readable")
		check(config.get_value("params","nodes/use_name_suffixes",true)==false and config.get_value("params","nodes/use_node_type_suffixes",true)==false,"Both reserved-name suffix options disabled")
		var poses=[0,33,45,90,180] if valve else [-40,-20,0,20,40]
		var pose_bounds:Array=[]
		for degrees in poses:
			moving.rotation_degrees=Vector3(0,0,degrees) if valve else Vector3(degrees,0,0)
			var bounds=box(art)
			var vertices=vertex_box(art)
			pose_bounds.append({"angle":degrees,"conservative_aabb_position":str(bounds.position),"conservative_aabb_size":str(bounds.size),"actual_vertex_position":str(vertices.position),"actual_vertex_size":str(vertices.size)})
			check(fixed.transform.is_equal_approx(Transform3D.IDENTITY),"Motion never rotates housing "+str(degrees))
			check(moving.position.is_equal_approx(Vector3(0,1.45,0.36) if valve else Vector3(0,1.2,0.4)),"Motion keeps pivot fixed "+str(degrees))
			check(absf(bounds.position.y)<0.00001,"Control remains grounded "+str(degrees))
			if valve:
				var wheel_bounds=art.global_transform.affine_inverse()*moving.global_transform*moving.mesh.get_aabb()
				check(wheel_bounds.position.z-fixed.mesh.get_aabb().end.z>0.0059,"Wheel stays clear of pedestal "+str(degrees))
				check(vertices.size.x<=0.9001 and vertices.end.y<=1.9001,"Actual wheel vertices stay inside 0.90 m diameter despite rotated AABB inflation")
			else:check(bounds.end.z<0.62 and bounds.size.x<0.601 and bounds.end.y<1.801,"Lever sweep within front clearance "+str(degrees))
		if not valve:
			var lamp=art.find_child("Relay_Indicator",true,false) as MeshInstance3D
			var material=lamp.get_active_material(0) as StandardMaterial3D
			check(lamp!=null and material.emission_enabled and is_equal_approx(material.emission_energy_multiplier,6.0),"Separate amber lamp imports with energy 6")
			check(lamp.mesh.get_surface_count()==1 and material.resource_name=="Relay_Indicator_Amber","Lamp has its own single material")
			for mesh in [fixed,moving]:
				for surface in mesh.mesh.get_surface_count():check(not mesh.get_active_material(surface).emission_enabled,"Housing/lever do not share lamp emission")
		imported.append({"asset":path,"triangles":triangles(art),"poses":pose_bounds})
		holder.free()
func verify_map(path:String,valve:bool):
	var scene=load(path).instantiate();root.add_child(scene)
	var deadline=Time.get_ticks_msec()+60000
	while not scene.is_raid_ready() and Time.get_ticks_msec()<deadline:await process_frame
	check(scene.is_raid_ready(),"Control scene ready: "+path)
	if not scene.is_raid_ready():scene.free();return
	scene.set_physics_process(false);scene.player.set_physics_process(false)
	var targets=scene.targets.filter(func(t):return t.kind=="switch")
	check(targets.size()==3,"Exactly three original puzzle targets")
	var transforms:Array=[]
	for i in targets.size():
		var body=targets[i].node;var art=body.get_node("PuzzleControlArt")
		check(body.position.is_equal_approx(Vector3(-4+i*4,0.9,9)),"Original control centre preserved")
		check(body.get_child(0) is CollisionShape3D and body.get_child(0).shape.size.is_equal_approx(Vector3(0.6,1.8,0.6)),"Original body collision dimensions preserved")
		check(body.get_children().size()==2,"One collision shape and one visual tree only")
		check(targets[i].number==i+1,"Original switch numbering preserved")
		check(art.global_position.is_equal_approx(body.global_position-Vector3(0,0.9,0)),"Control ground matches old pedestal ground")
		var moving=art.find_child("Valve_Wheel" if valve else "Relay_Lever",true,false)
		check(is_equal_approx(moving.rotation_degrees.z,0.0) if valve else is_equal_approx(moving.rotation_degrees.x,-40.0),"Fresh control initial pose")
		transforms.append(body.transform)
		scene.player.global_position=body.global_position+Vector3(0,-0.82,2.0);scene.player.velocity=Vector3.ZERO
		scene.player.camera.look_at(body.global_position)
		await physics_frame
		check(scene._nearest_target().get("node")==body,"Actual camera/raycast selects the original control body")
		var probe=PhysicsShapeQueryParameters3D.new();probe.shape=scene.player.standing_shape;probe.transform=Transform3D(Basis.IDENTITY,body.global_position+Vector3(0,0.04,1.5));probe.exclude=[scene.player.get_rid()]
		check(scene.get_world_3d().direct_space_state.intersect_shape(probe,1).is_empty(),"Front standing approach remains clear")
	var first=targets[0].node.get_node("PuzzleControlArt");var second=targets[1].node.get_node("PuzzleControlArt")
	if not valve:
		check(first.get_meta("indicator_material")!=second.get_meta("indicator_material"),"Per-instance independent lamp materials")
		var original=second.get_meta("indicator_material").emission_energy_multiplier
		Controls.activate(targets[0].node)
		check(first.get_meta("indicator_material").emission_energy_multiplier>original and second.get_meta("indicator_material").emission_energy_multiplier==original,"Only pressed lamp pulses")
		var throw=first.get_meta("motion") as Tween
		throw.pause();throw.custom_step(0.15)
		check(is_equal_approx(first.find_child("Relay_Lever",true,false).rotation_degrees.x,40.0),"Lever reaches positive 40-degree throw")
		throw.custom_step(0.3)
		check(is_equal_approx(first.find_child("Relay_Lever",true,false).rotation_degrees.x,-40.0) and is_equal_approx(first.get_meta("indicator_material").emission_energy_multiplier,original),"Momentary lever and lamp return to idle")
	else:
		Controls.activate(targets[0].node)
		await create_timer(0.42).timeout
		check(is_equal_approx(first.find_child("Valve_Wheel",true,false).rotation_degrees.z,90.0),"Valve rotates 90 degrees about local Z")
		check(is_zero_approx(second.find_child("Valve_Wheel",true,false).rotation_degrees.z),"Valve motion affects only pressed control")
	# Interrupt a visibly non-rest pose as well as testing same-frame spam below.
	var part=first.find_child("Valve_Wheel" if valve else "Relay_Lever",true,false)
	var initial:Vector3=part.rotation_degrees
	Controls.activate(targets[0].node)
	var interrupted=first.get_meta("motion") as Tween
	interrupted.pause();interrupted.custom_step(0.08)
	var midway:Vector3=part.rotation_degrees
	check(not midway.is_equal_approx(initial),"Control visibly moves before mid-motion interruption")
	Controls.activate(targets[0].node)
	check(not interrupted.is_valid(),"Mid-motion interruption kills the old tween")
	check(part.rotation_degrees.is_equal_approx(midway),"Restart preserves the current visible pose without a snap")
	await create_timer(0.5).timeout
	check(is_equal_approx(part.rotation_degrees.z,midway.z+90.0) if valve else is_equal_approx(part.rotation_degrees.x,-40.0),"Interrupted motion settles at the new target")
	check(scene.raid_state.switch_step==0,"Direct visual activation cannot solve a puzzle")
	var state=scene._create_state(scene.settings.map_seed)
	# Includes wrong attempts, immediate repeats, restart-on-first and the final
	# correct sequence. The existing independent state object is the oracle.
	var sequence=[1,1,2,2,3,2,1,3] if not valve else [1,2,3,3,2,3,1,2]
	var door=scene.targets.filter(func(t):return t.kind=="door" and t.poi.lock=="puzzle")[0]
	scene._interact(door)
	check(not scene.raid_state.unlocked.get(door.poi.id,false) and door.node.visible,"Unsolved partition remains locked")
	for number in sequence:
		var target=targets[number-1]
		var target_art=target.node.get_node("PuzzleControlArt")
		var old=target_art.get_meta("motion") as Tween if target_art.has_meta("motion") else null
		state.flip_switch(number);scene._interact(target)
		check(scene.raid_state.switch_step==state.switch_step,"Immediate/repeated gameplay sequence matches unchanged state machine")
		if old!=null:check(not old.is_valid(),"Repeated control input kills obsolete tween")
	check(scene.raid_state.switch_step==3,"Correct map-specific sequence solves")
	check(door.node.visible and not scene.raid_state.unlocked.get(door.poi.id,false),"Solving still requires original separate door interaction")
	scene._interact(door);await physics_frame
	check(not door.node.visible and scene.raid_state.unlocked.get(door.poi.id,false),"Original door unlock flow remains")
	for number in [1,1,3,2,1]:scene._interact(targets[number-1])
	check(scene.raid_state.switch_step==3,"Post-solve input cannot reset or lock puzzle")
	await create_timer(0.5).timeout
	for i in targets.size():
		var body=targets[i].node;var art=body.get_node("PuzzleControlArt")
		check(body.transform.is_equal_approx(transforms[i]) and not body.get_child(0).disabled,"Animation never moves/disables original collider")
		check(not art.get_meta("motion").is_running(),"Repeated input settles without queued animation")
		if not valve:check(is_equal_approx(art.find_child("Relay_Lever",true,false).rotation_degrees.x,-40.0) and is_equal_approx(art.get_meta("indicator_material").emission_energy_multiplier,6.0),"Repeated relay input restores rest pose/emission")
	var before=scene.raid_state.switch_step
	scene.returning=true;scene._interact(targets[0]);check(scene.raid_state.switch_step==before and not first.get_meta("motion").is_running(),"Returning guard still blocks new control actions")
	scene.returning=false;scene._interact(targets[0]);scene.free()
	await preload("res://raid/tests/audio_shutdown.gd").drain(self)
	check(state!=null,"Scene can be freed safely during an active control tween")
	var fresh_holder=Node3D.new();root.add_child(fresh_holder)
	var fresh=Controls.attach(fresh_holder,valve);var fresh_part=fresh.find_child("Valve_Wheel" if valve else "Relay_Lever",true,false)
	check(is_zero_approx(fresh_part.rotation_degrees.z) if valve else is_equal_approx(fresh_part.rotation_degrees.x,-40.0),"Fresh instance does not retain previous motion")
	check(scene==null or not is_instance_valid(scene),"No retained scene after teardown")
	fresh_holder.free()
func run():
	verify_imports()
	await verify_map("res://raid/relay_ridge.tscn",false)
	await verify_map("res://raid/cinder_basin.tscn",true)
	print("PUZZLE_CONTROLS_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"imports":imported,"rendered":false}))
	quit(0 if failures.is_empty() else 1)
