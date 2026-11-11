extends SceneTree
## Real production movement through the campus, without jumps or teleporting
## between waypoints. Headless geometry/interaction coverage, not visual QA.
const STEP=1.0/60.0
var scene
var origin:Vector3
var checks=0
var failures:Array=[]
var walked=0.0
var top_height=0.0
var visits:Array=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func place(at:Vector2):
	scene.player.position=origin+Vector3(at.x,0.08,at.y);scene.player.velocity=Vector3.ZERO
	for frame in 30:
		scene.player.step_motion(Vector3.ZERO,4.2,false,STEP);await physics_frame
func walk(to:Vector2,label:String)->bool:
	var goal=Vector2(origin.x,origin.z)+to
	var start=Vector2(scene.player.position.x,scene.player.position.z)
	var budget=ceili((start.distance_to(goal)/4.2+3)*120)
	for frame in budget:
		var at=Vector2(scene.player.position.x,scene.player.position.z)
		if at.distance_to(goal)<0.12:
			scene.player.velocity=Vector3.ZERO
			visits.append({"label":label,"local":scene.player.position-origin})
			return true
		var direction=(goal-at).normalized();var before:Vector3=scene.player.position
		scene.player.step_motion(Vector3(direction.x,0,direction.y),4.2,false,STEP);await physics_frame
		walked+=Vector2(before.x,before.z).distance_to(Vector2(scene.player.position.x,scene.player.position.z))
		top_height=maxf(top_height,scene.player.position.y-origin.y)
		if scene.player.position.y<origin.y-0.5 or before.distance_to(scene.player.position)>0.5:
			check(false,label+": unexpected relocation/fall");return false
	print("CAMPUS_BLOCKED ",label," local=",scene.player.position-origin," target=",to)
	return false
func route(points:Array,label:String):
	await place(points[0]);var ok=true
	for index in range(1,points.size()):
		if not await walk(points[index],label+"/%d"%index):ok=false;break
	check(ok,label)
func run():
	scene=load("res://raid/cinder_basin.tscn").instantiate();root.add_child(scene)
	var deadline=Time.get_ticks_msec()+60000
	while not scene.is_raid_ready() and Time.get_ticks_msec()<deadline:await process_frame
	check(scene.is_raid_ready(),"Cinder campus reaches readiness")
	if not scene.is_raid_ready():scene.free();quit(1);return
	scene.player.set_physics_process(false)
	var campus=scene.get_node("glasskiln");origin=campus.global_position
	for name in ["FurnaceHall","ControlHouse","Warehouse","Workshop","PowerShed","WestStair","EastStair"]:
		check(campus.has_node(name),"Distinct named structure: "+name)
	var poi=scene.generator.pois.filter(func(p):return p.id=="glasskiln")[0]
	check(poi.loot==[2,3] and poi.lock=="key","Larger campus keeps the original loot band and key lock")
	check(scene.targets.filter(func(t):return t.kind=="cache" and t.poi.id=="glasskiln").size()==1,"Larger campus has exactly one reward cache")
	# Main courtyard, workshop exterior, each open building and ground flanks.
	await route([Vector2(0,25),Vector2(0,6),Vector2(0,-14),Vector2(0,-24),Vector2(0,-39)],"Yard through furnace hall north exit")
	await route([Vector2(-32,-27),Vector2(-11,-27),Vector2(-11,-23),Vector2(11,-23),Vector2(11,-27),Vector2(17,-27)],"Furnace hall side entrances and clear aisle around tanks")
	await route([Vector2(-21,-2),Vector2(-21,-11),Vector2(-21,-20)],"Control house through rooms")
	await route([Vector2(22,3),Vector2(22,-11),Vector2(22,-22)],"Warehouse through loading bays")
	await route([Vector2(24,-22),Vector2(24,-29),Vector2(24,-35)],"Power shed through equipment aisle")
	await route([Vector2(0,25),Vector2(-30,20),Vector2(-30,14),Vector2(-21,12.4)],"Workshop supplies and locked entrance remain reachable")
	# Climb either end, visit all three raised gallery branches, descend the other.
	for reverse in [false,true]:
		var sign_value=-1.0 if reverse else 1.0
		await place(Vector2(sign_value*12,5))
		var ok=await walk(Vector2(sign_value*12,-11),"Stair ascent")
		check(ok and absf(scene.player.position.y-origin.y-4.2)<0.12,"Independent stair reaches upper deck reverse="+str(reverse))
		for point in [Vector2(sign_value*17,-11),Vector2(0,-11),Vector2(0,-18.5),Vector2(-10,-18.5),Vector2(10,-18.5),Vector2(0,-18.5),Vector2(0,-11),Vector2(-sign_value*17,-11),Vector2(-sign_value*12,-11)]:
			ok=await walk(point,"Upper gallery "+str(point)) and ok
			check(absf(scene.player.position.y-origin.y-4.2)<0.15,"Continuous 4.2 m upper floor "+str(point)+" reverse="+str(reverse))
		ok=await walk(Vector2(-sign_value*12,5),"Other stair descent") and ok
		check(ok and absf(scene.player.position.y-origin.y)<0.15,"Entire upper loop exits grounded reverse="+str(reverse))
	# Physical rail stops a grounded player at the northern balcony edge.
	await place(Vector2(12,5));var reached=await walk(Vector2(12,-11),"Rail test stair")
	reached=await walk(Vector2(0,-11),"Rail test bridge") and reached
	reached=await walk(Vector2(0,-18.5),"Rail test hall gallery") and reached
	for frame in 100:
		scene.player.step_motion(Vector3(0,0,-1),4.2,false,STEP);await physics_frame
	check(reached and scene.player.position.z-origin.z>-20 and absf(scene.player.position.y-origin.y-4.2)<0.15,"Upper rail blocks walking off the hall gallery")
	# Exercise both edges at both gallery tips, not just the deck centreline.
	for side in [-1.0,1.0]:
		for direction in [-1.0,1.0]:
			await place(Vector2(side*12,5))
			var tip_reached=await walk(Vector2(side*12,-11),"Gallery edge stair")
			tip_reached=await walk(Vector2(side*17.5,-11),"Gallery tip approach") and tip_reached
			for frame in 100:
				scene.player.step_motion(Vector3(0,0,direction),4.2,false,STEP);await physics_frame
			var local:Vector3=scene.player.position-origin
			check(tip_reached and local.z>-12.5 and local.z< -9.5 and absf(local.y-4.2)<0.15,"Gallery tip edge blocks a standing player side=%s direction=%s"%[side,direction])
	print("GLASSKILN_CAMPUS_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"walked_metres":walked,"maximum_local_foot_height":top_height,"waypoints":visits,"rendered":false,"native_input":false,"windows":false}))
	scene.free();await preload("res://raid/tests/audio_shutdown.gd").drain(self);quit(0 if failures.is_empty() else 1)
