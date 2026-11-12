extends SceneTree
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func run():
	var scene=load("res://raid/relay_ridge.tscn").instantiate();root.add_child(scene)
	var deadline=Time.get_ticks_msec()+60000
	while not scene.is_raid_ready() and Time.get_ticks_msec()<deadline:await process_frame
	check(scene.is_raid_ready(),"real generated scene reaches collision/spawn readiness")
	if not scene.is_raid_ready():scene.free();quit(1);return
	scene.player.enabled=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	check(scene.build_result.terrain.triangles==73728,"expected bounded terrain size")
	var world=scene.get_world_3d()
	var max_error=0.0;var all_supported=true;var samples=0
	for route in scene.generator.routes:
		for i in range(route.size()-1):
			var a:Vector2=route[i];var b:Vector2=route[i+1]
			for step in range(0,ceili(a.distance_to(b)),3):
				var p=a.move_toward(b,step);var y=scene.generator.height_at(p)
				var query=PhysicsRayQueryParameters3D.create(Vector3(p.x,y+1.0,p.y),Vector3(p.x,y-1.0,p.y));query.exclude=[scene.player.get_rid()]
				var hit=world.direct_space_state.intersect_ray(query)
				if hit.is_empty():all_supported=false
				else:max_error=maxf(max_error,absf(hit.position.y-y))
				samples+=1
	check(all_supported and max_error<0.15,"route collision matches terrain sampling")
	# Real character sweeps along paths at standing height. Ground excluded by raising 8cm.
	var blocked=[]
	for route in scene.generator.routes:
		for i in range(route.size()-1):
			var a:Vector2=route[i];var b:Vector2=route[i+1]
			for step in range(0,ceili(a.distance_to(b)),3):
				var p=a.move_toward(b,step);var y=scene.generator.height_at(p)
				var query=PhysicsShapeQueryParameters3D.new();query.shape=scene.player.standing_shape;query.transform=Transform3D(Basis.IDENTITY,Vector3(p.x,y+1.0,p.y));query.exclude=[scene.player.get_rid()]
				var hit=world.direct_space_state.intersect_shape(query,1)
				if not hit.is_empty():blocked.append({"at":p,"body":str(hit[0].collider.get_path())})
	check(blocked.is_empty(),"standing capsule clear along main routes")
	for poi in scene.generator.pois:
		if poi.lock=="":continue
		var door=scene.door_nodes[poi.id];var pos:Vector3=door.global_position
		var query=PhysicsRayQueryParameters3D.create(pos+Vector3(0,0,1),pos-Vector3(0,0,1));query.exclude=[scene.player.get_rid()]
		var before=world.direct_space_state.intersect_ray(query)
		check(not before.is_empty() and before.collider==door,"closed door physically blocks "+poi.id)
		scene._open_door(poi.id)
		await physics_frame;await physics_frame
		check(world.direct_space_state.intersect_ray(query).is_empty(),"opened door collision removed "+poi.id)
	# UI repetition and controls work in scene, rather than testing a string-only model.
	for i in 3:
		scene._field_notes();check(scene.modal.visible and not scene.player.enabled,"field notes pause controls")
		scene._close_modal();check(not scene.modal.visible and scene.player.enabled,"modal closes and restores controls")
	var code_poi=scene.generator.pois.filter(func(p):return p.id=="relay")[0]
	scene._code_panel(code_poi);check(scene.modal.visible,"code panel opens")
	var entries=scene.modal.find_children("*","LineEdit",true,false);check(entries.size()==1 and entries[0].max_length==4,"four-digit entry exists")
	scene._close_modal()
	scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(scene.modal.visible and not scene.player.enabled,"focus loss pauses and releases input")
	scene._close_modal()
	# Move the actual player through a 30m outside route using production motion.
	var start=Vector2(-120,100);var end=Vector2(-120,70)
	scene.player.position=Vector3(start.x,scene.generator.height_at(start)+0.08,start.y)
	scene.player.velocity=Vector3.ZERO;scene.player.enabled=false;scene.player.set_physics_process(false)
	for i in 600:
		scene.player.step_motion(Vector3(0,0,-1) if Vector2(scene.player.position.x,scene.player.position.z).distance_to(end)>0.5 else Vector3.ZERO,4.2,false,1.0/60.0)
		await physics_frame
	check(Vector2(scene.player.position.x,scene.player.position.z).distance_to(end)<1.0,"production character traverses 30m seeded trail")
	check(absf(scene.player.position.y-scene.generator.height_at(Vector2(scene.player.position.x,scene.player.position.z)))<0.2,"walking player remains on generated ground")
	print("RELAY_SCENE_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"route_samples":samples,"max_ground_error":max_error,"blocked":blocked,"walk_final":scene.player.position,"walk_goal":end}))
	scene.free();await process_frame;quit(0 if failures.is_empty() else 1)
