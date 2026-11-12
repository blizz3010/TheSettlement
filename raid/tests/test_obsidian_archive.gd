extends SceneTree
const Driver=preload("res://raid/tests/obsidian_walk_driver.gd")
var failures:Array=[]
var checks=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func run():
	var scene=load("res://raid/cinder_basin.tscn").instantiate();root.add_child(scene)
	var deadline=Time.get_ticks_msec()+60000
	while not scene.is_raid_ready() and Time.get_ticks_msec()<deadline:await process_frame
	check(scene.is_raid_ready(),"Cinder ready")
	if not scene.is_raid_ready():quit(1);return
	scene.player.set_physics_process(false);scene.set_physics_process(false)
	var archive=scene.get_node("obsidian")
	scene.player.global_position=archive.to_global(Vector3(0,.08,24));scene.player.velocity=Vector3.ZERO
	for frame in 30:scene.player.step_motion(Vector3.ZERO,2.4,false,1.0/60);await physics_frame
	var poi=scene.generator.pois.filter(func(p):return p.id=="obsidian")[0]
	check(not scene.raid_state.try_unlock(poi) and not scene.raid_state.search_cache(poi).ok,"missing card denies vault/cache")
	var visit=await Driver.visit(scene)
	check(visit.ok,"continuous forecourt/card/upper vault/cache/return: "+str(visit))
	check(scene.raid_state.unlocked.get("obsidian",false) and scene.raid_state.searched.get("obsidian",0) in [4,5],"matching card and original reward band")
	check(not scene.raid_state.search_cache(poi).ok,"repeat cache cannot reroll")
	if "--visit-only" in OS.get_cmdline_user_args():
		print("VISIT_ONLY ",JSON.stringify(visit));scene.free();await preload("res://raid/tests/audio_shutdown.gd").drain(self);quit(0 if failures.is_empty() else 1);return
	var routes=JSON.parse_string(FileAccess.get_file_as_string("res://raid/tests/obsidian_routes.json"))
	# Each route has independent positioning only at its initial point. Every
	# segment uses the actual production character and integrated world collision.
	for radius in [.32,.35]:
		scene.player.body_shape.shape.radius=radius
		for label in routes:
			for reverse in [false,true]:
				var points=Driver.points(label)
				if reverse:points.reverse()
				scene.player.global_position=archive.to_global(points[0]+Vector3(0,.08,0));scene.player.velocity=Vector3.ZERO
				for frame in 30:scene.player.step_motion(Vector3.ZERO,2.4,false,1.0/60);await physics_frame
				var result=await Driver.walk(scene,points)
				check(result.ok,label+" radius="+str(radius)+" reverse="+str(reverse)+": "+str(result))
				print("ARCHIVE_ROUTE ",label," ",radius," ",reverse," ",JSON.stringify(result))
	print("OBSIDIAN_ARCHIVE_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"production_controller":true,"windows":false}))
	scene.free();await preload("res://raid/tests/audio_shutdown.gd").drain(self);quit(0 if failures.is_empty() else 1)
