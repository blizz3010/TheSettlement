extends RefCounted
const STEP=1.0/60.0
static func walk(scene,points:Array)->Dictionary:
	var root:Node3D=scene.get_node("obsidian")
	for point in points:
		var goal:Vector3=root.to_global(point)
		var budget=int(ceil(scene.player.global_position.distance_to(goal)/2.4*150))+180
		var reached=false;var still=0
		for frame in budget:
			var delta=Vector2(goal.x-scene.player.global_position.x,goal.z-scene.player.global_position.z)
			if delta.length()<.12 and absf(goal.y-scene.player.global_position.y)<.24:reached=true;break
			var before:Vector3=scene.player.global_position
			var dir=delta.normalized();scene.player.step_motion(Vector3(dir.x,0,dir.y),2.4,false,STEP)
			await scene.get_tree().physics_frame
			still=still+1 if before.distance_to(scene.player.global_position)<.0008 else 0
			if still>90:break
		if not reached:
			var contacts:Array=[]
			for i in scene.player.get_slide_collision_count():contacts.append(str(scene.player.get_slide_collision(i).get_collider().get_path()))
			return {"ok":false,"goal":point,"at":root.to_local(scene.player.global_position),"contacts":contacts}
	scene.player.velocity=Vector3.ZERO
	return {"ok":true}
static func points(name:String)->Array:
	var all=JSON.parse_string(FileAccess.get_file_as_string("res://raid/tests/obsidian_routes.json"))
	var result:Array=[]
	for p in all[name]:result.append(Vector3(p.x,p.z,-p.y))
	return result
static func use(scene,kind:String)->bool:
	var target=scene.targets.filter(func(t):return t.poi.id=="obsidian" and t.kind==kind)[0]
	scene.player.camera.look_at(target.node.global_position)
	var selected=scene._nearest_target()
	if selected.is_empty() or selected.node!=target.node:return false
	scene._interact(selected);return true
static func visit(scene)->Dictionary:
	var r=await walk(scene,[Vector3(-9,0,21)])
	if not r.ok:return r
	if not use(scene,"clue"):return {"ok":false,"stage":"card ray target"}
	r=await walk(scene,[Vector3(0,0,20),Vector3(0,0,17)])
	if not r.ok:return r
	r=await walk(scene,points("main_to_stairB_up"))
	if not r.ok:return r
	r=await walk(scene,[Vector3(10.8,8.5,-6.19),Vector3(13,8.5,-6.19),Vector3(13,8.5,-7.6),Vector3(8,8.5,-7.6),Vector3(0,8.5,-7.4)])
	if not r.ok:return r
	if not use(scene,"door"):return {"ok":false,"stage":"vault ray target"}
	await scene.get_tree().physics_frame;await scene.get_tree().physics_frame
	r=await walk(scene,[Vector3(0,8.5,-8.7)])
	if not r.ok:return r
	if not use(scene,"cache"):return {"ok":false,"stage":"cache ray target"}
	var value=scene.raid_state.searched.get("obsidian",-1)
	if not use(scene,"cache") or scene.raid_state.searched.get("obsidian",-1)!=value or scene.toast.text!="Already searched this raid.":return {"ok":false,"stage":"repeat cache"}
	r=await walk(scene,[Vector3(0,8.5,-7.4),Vector3(8,8.5,-7.6),Vector3(13,8.5,-7.6),Vector3(13,8.5,-6.19),Vector3(10.8,8.5,-6.19),Vector3(10.8,8.5,-4)])
	if not r.ok:return r
	var reverse=points("main_to_stairB_up");reverse.reverse()
	r=await walk(scene,reverse)
	if not r.ok:return r
	return await walk(scene,[Vector3(0,0,24)])
