extends SceneTree
## Independent closed-vault and interaction checks on the generated candidate.
## Headless physics/raycast checks, not native input or rendered acceptance.
const STEP:=1.0/60.0
var scene
var origin:Vector3
var checks:=0
var failures:Array=[]
var events:Array=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func target(kind:String)->Dictionary:
	var found=scene.targets.filter(func(t):return t.kind==kind and t.poi.id=="obsidian")
	check(found.size()==1,"Exactly one Obsidian "+kind+" target")
	return found[0] if found.size()==1 else {}
func place(local:Vector3):
	scene.player.update_crouch(false)
	scene.player.position=origin+local;scene.player.velocity=Vector3.ZERO
	for i in 30:scene.player.step_motion(Vector3.ZERO,2.4,false,STEP);await physics_frame
func aim(item:Dictionary)->bool:
	scene.player.camera.look_at(item.node.global_position)
	var selected=scene._nearest_target()
	return not selected.is_empty() and selected.node==item.node
func walk(goal:Vector3,frames:int=400,jumping:bool=false)->bool:
	for i in frames:
		var local:Vector3=scene.player.position-origin
		var horizontal:=Vector2(goal.x-local.x,goal.z-local.z)
		if horizontal.length()<.12 and absf(local.y-goal.y)<.20:return true
		var toward:=horizontal.normalized()
		scene.player.step_motion(Vector3(toward.x,0,toward.y),2.4,jumping,STEP);await physics_frame
	return false
func sweep(start:Vector3,motion:Vector3,label:String):
	var transform:=Transform3D(Basis.IDENTITY,origin+start)
	var hit:=KinematicCollision3D.new()
	var blocked:bool=scene.player.test_move(transform,motion,hit)
	check(blocked,label)
	events.append({"label":label,"blocked":blocked,"collider":str(hit.get_collider().get_path()) if blocked and hit.get_collider()!=null else ""})
func run():
	scene=load("res://raid/cinder_basin.tscn").instantiate();root.add_child(scene)
	var deadline=Time.get_ticks_msec()+60000
	while not scene.is_raid_ready() and Time.get_ticks_msec()<deadline:await process_frame
	check(scene.is_raid_ready(),"Generated Cinder reaches readiness")
	if not scene.is_raid_ready():scene.free();quit(1);return
	scene.player.set_physics_process(false);origin=scene.get_node("obsidian").global_position
	var poi:Dictionary=scene.generator.pois.filter(func(p):return p.id=="obsidian")[0]
	check(poi.lock=="keycard" and poi.loot==[4,5] and poi.at==Vector2(-69,-80) and poi.radius==23,"Original Obsidian identity/map/lock/loot/radius retained")
	var door=target("door");var cache=target("cache");var card=target("clue")
	if door.is_empty() or cache.is_empty() or card.is_empty():scene.free();quit(1);return
	check(not scene.raid_state.unlocked.get("obsidian",false) and not scene.raid_state.held.has("obsidian_card"),"Starts locked without credential")
	await place(Vector3(0,8.58,-6))
	check(aim(door),"Closed vault door is selectable through actual raycast")
	scene._interact(door)
	check(not scene.raid_state.unlocked.get("obsidian",false) and door.node.visible,"No-card interaction preserves lock and visible barrier")
	check(not aim(cache),"Cache cannot be targeted through closed vault wall/door")
	scene._interact(cache)
	check(not scene.raid_state.searched.has("obsidian"),"State independently rejects direct locked-cache search")
	for stance in ["stand","crouch","jump"]:
		await place(Vector3(0,8.58,-6))
		if stance=="crouch":scene.player.update_crouch(true)
		var reached=await walk(Vector3(0,8.5,-9.2),250,stance=="jump")
		check(not reached and scene.player.position.z-origin.z>-8,"Closed vault prevents "+stance+" entry")
		events.append({"stance":stance,"final":str(scene.player.position-origin)})
	await place(Vector3(0,8.58,-6));scene.player.update_crouch(false)
	for side in [-1.0,1.0]:
		for z in [-9.0,-11.0,-13.0]:
			for foot in [8.55,9.3,10.1]:sweep(Vector3(side*5,foot,z),Vector3(-side*2.5,0,0),"Vault side wall/window closed side=%s z=%s foot=%s"%[side,z,foot])
	for x in [-3.0,-1.0,1.0,3.0]:
		for foot in [8.55,9.3,10.1]:sweep(Vector3(x,foot,-15.5),Vector3(0,0,3),"Vault rear wall/window closed x=%s foot=%s"%[x,foot])
	for x in [-3.0,-1.0,1.0,3.0]:
		sweep(Vector3(x,5.5,-11),Vector3(0,3.5,0),"Vault floor blocks lower-floor entry x=%s"%x)
		sweep(Vector3(x,13.7,-11),Vector3(0,-5.2,0),"Vault roof blocks top entry x=%s"%x)
	# Physical target selection and actual handlers, not direct state mutation.
	var card_local:Vector3=card.node.global_position-origin
	await place(Vector3(card_local.x,0.08,card_local.z+2))
	check(aim(card),"Uncollected keycard is reachable and selectable outside")
	if aim(card):scene._interact(card)
	check(scene.raid_state.held.has("obsidian_card"),"Card collected through actual interaction")
	await place(Vector3(0,8.58,-6))
	check(aim(door),"Vault unlock target remains selectable after card")
	if aim(door):scene._interact(door)
	await physics_frame;await physics_frame
	check(scene.raid_state.unlocked.get("obsidian",false) and not door.node.visible,"Card opens exactly the registered vault barrier")
	var disabled:=true;var shape_count:=0
	for child in door.node.get_children():
		if child is CollisionShape3D:shape_count+=1;disabled=disabled and child.disabled
	check(shape_count>0 and disabled,"All direct vault-door colliders disabled after unlock")
	var inside=await walk(Vector3(0,8.5,-9.2),400)
	check(inside,"Production controller walks through opened door into vault")
	check(aim(cache),"Cache is selectable from inside vault with actual raycast")
	if aim(cache):scene._interact(cache)
	check(scene.raid_state.searched.has("obsidian"),"Cache pays its original one roll through actual handler")
	var roll=scene.raid_state.searched.get("obsidian",-1)
	check(roll>=4 and roll<=5,"Roll stays within original quality band")
	if aim(cache):scene._interact(cache)
	check(scene.raid_state.searched.get("obsidian",-2)==roll and scene.toast.text=="Already searched this raid.","Repeat use cannot reroll")
	check(await walk(Vector3(0,8.5,-6),400),"Player can leave the unlocked vault")
	print("OBSIDIAN_INDEPENDENT_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"events":events,"windows":false,"native_input":false,"rendered":false}))
	scene.free();await preload("res://raid/tests/audio_shutdown.gd").drain(self);quit(0 if failures.is_empty() else 1)
