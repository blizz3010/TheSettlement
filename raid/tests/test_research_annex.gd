extends SceneTree
const Driver=preload("res://raid/tests/annex_walk_driver.gd")
var failures:Array=[]
var checks=0
var results:Array=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func run():
	var scene=load("res://raid/relay_ridge.tscn").instantiate();root.add_child(scene)
	var deadline=Time.get_ticks_msec()+60000
	while not scene.is_raid_ready() and Time.get_ticks_msec()<deadline:await process_frame
	check(scene.is_raid_ready(),"Relay ready")
	if not scene.is_raid_ready():quit(1);return
	scene.player.set_physics_process(false);scene.set_physics_process(false)
	var annex=scene.get_node("bunker")
	var poi=scene.generator.pois.filter(func(p):return p.id=="bunker")[0]
	check(not scene.raid_state.try_unlock(poi) and not scene.raid_state.search_cache(poi).ok,"missing card denies door/cache")
	var space=scene.get_world_3d().direct_space_state
	for x in [12.5,12.95,13.35]:
		var q=PhysicsShapeQueryParameters3D.new();q.shape=scene.player.standing_shape
		q.transform=Transform3D(Basis.IDENTITY,annex.to_global(Vector3(x,5.11,-4.8)));q.motion=Vector3(0,0,-2)
		q.exclude=[scene.player.get_rid()]
		check(space.cast_motion(q)[0]<.5,"locked secure opening blocks capsule x="+str(x))
	# Explicitly probe each exterior secure-room glass pane. Collision retains
	# transparent surfaces; these checks do not claim exhaustive combat exploits.
	for segment in [[Vector3(12,5.9,-12.5),Vector3(12,5.9,-11.2)],[Vector3(16.6,5.9,-8.8),Vector3(15,5.9,-8.8)]]:
		var ray=PhysicsRayQueryParameters3D.create(annex.to_global(segment[0]),annex.to_global(segment[1]),1,[scene.player.get_rid()])
		var hit=space.intersect_ray(ray)
		check(not hit.is_empty() and String(hit.collider.get_path()).contains("Mod_Upper_Shell"),"secure window remains physical "+str(segment[0]))
		var q=PhysicsShapeQueryParameters3D.new();q.shape=scene.player.standing_shape
		q.transform=Transform3D(Basis.IDENTITY,annex.to_global(Vector3(segment[0].x,5.11,segment[0].z)))
		q.motion=segment[1]-segment[0];q.exclude=[scene.player.get_rid()]
		check(space.cast_motion(q)[0]<.8,"secure window capsule sweep blocked "+str(segment[0]))
	var forecourt=Vector2(annex.position.x,annex.position.z+24)
	scene.player.global_position=Vector3(forecourt.x,scene.generator.height_at(forecourt)+.08,forecourt.y);scene.player.velocity=Vector3.ZERO
	for frame in 30:scene.player.step_motion(Vector3.ZERO,2.4,false,1.0/60);await physics_frame
	var visit=await Driver.visit(scene)
	check(visit.ok,"continuous forecourt/denial/card/secure cache/exterior return: "+str(visit))
	check(scene.raid_state.unlocked.get("bunker",false) and scene.raid_state.searched.get("bunker",0) in [4,5],"original card state and reward band")
	check(not scene.raid_state.search_cache(poi).ok,"repeat cache cannot reroll")
	print("ANNEX_VISIT ",JSON.stringify(visit))
	var routes=JSON.parse_string(FileAccess.get_file_as_string("res://raid/tests/annex_routes.json"))
	# Independent initial setup only. Every subsequent point uses unchanged
	# production step_motion with real map collision, no jumps or position nudges.
	for speed in [2.4,4.2,7.0]:
		for label in routes:
			var points=Driver.points(label)
			scene.player.global_position=annex.to_global(points[0]+Vector3(0,.08,0));scene.player.velocity=Vector3.ZERO
			for frame in 30:scene.player.step_motion(Vector3.ZERO,speed,false,1.0/60);await physics_frame
			var result=await Driver.walk(scene,points,speed)
			check(result.ok,label+" speed="+str(speed)+": "+str(result))
			results.append({"route":label,"speed":speed,"result":result})
			print("ANNEX_ROUTE ",label," ",speed," ",JSON.stringify(result))
	print("RESEARCH_ANNEX_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"routes":results,"production_controller":true,"windows":false}))
	scene.free();await preload("res://raid/tests/audio_shutdown.gd").drain(self);quit(0 if failures.is_empty() else 1)
