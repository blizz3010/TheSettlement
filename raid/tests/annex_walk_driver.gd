extends RefCounted
const STEP=1.0/60.0
static func walk(scene,points:Array,speed:float=2.4)->Dictionary:
	var root:Node3D=scene.get_node("bunker")
	var distance=0.0;var min_head=INF;var head_at=Vector3.ZERO;var head_collider=""
	for index in points.size():
		var point:Vector3=points[index]
		var goal:Vector3=root.to_global(point)
		var budget=int(ceil(scene.player.global_position.distance_to(goal)/speed*150))+180
		var reached=false;var still=0
		for frame in budget:
			var delta=Vector2(goal.x-scene.player.global_position.x,goal.z-scene.player.global_position.z)
			if delta.length()<.12 and absf(goal.y-scene.player.global_position.y)<.24:reached=true;break
			var before:Vector3=scene.player.global_position
			var dir=delta.normalized();scene.player.step_motion(Vector3(dir.x,0,dir.y),speed,false,STEP)
			await scene.get_tree().physics_frame
			distance+=before.distance_to(scene.player.global_position)
			var q=PhysicsRayQueryParameters3D.create(scene.player.global_position+Vector3.UP*1.8,scene.player.global_position+Vector3.UP*12,1,[scene.player.get_rid()])
			var hit=scene.get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				var head=hit.position.y-scene.player.global_position.y
				if head<min_head:min_head=head;head_at=root.to_local(scene.player.global_position);head_collider=str(hit.collider.get_path())
			still=still+1 if before.distance_to(scene.player.global_position)<.0008 else 0
			if still>90:break
		if not reached:
			var contacts:Array=[]
			for i in scene.player.get_slide_collision_count():contacts.append(str(scene.player.get_slide_collision(i).get_collider().get_path()))
			return {"ok":false,"index":index,"goal":point,"at":root.to_local(scene.player.global_position),"contacts":contacts,"metres":distance}
	scene.player.velocity=Vector3.ZERO
	return {"ok":true,"metres":distance,"min_head":min_head,"head_at":head_at,"head_collider":head_collider}
static func points(name:String)->Array:
	var all=JSON.parse_string(FileAccess.get_file_as_string("res://raid/tests/annex_routes.json"))
	var result:Array=[]
	for p in all[name]:result.append(Vector3(p.x,p.z,-p.y))
	return result
static func use(scene,kind:String)->bool:
	var target=scene.targets.filter(func(t):return t.poi.id=="bunker" and t.kind==kind)[0]
	scene.player.camera.look_at(target.node.global_position)
	var selected=scene._nearest_target()
	if selected.is_empty() or selected.node!=target.node:return false
	scene._interact(selected);return true

static func visit(scene)->Dictionary:
	var r=await walk(scene,[Vector3(-1,0,15),Vector3(-1,0,14.2)])
	if not r.ok:return r
	r=await walk(scene,points("main_to_stair1_up"))
	if not r.ok:return r
	var upper=points("upper_loop")
	r=await walk(scene,upper.slice(0,8))
	if not r.ok:return r
	# First reach the locked gate without collecting the card. Verify both the
	# interaction denial and real capsule blocking, then walk over to the card.
	r=await walk(scene,[Vector3(12.95,4.2,-4.6)])
	if not r.ok:return r
	if not use(scene,"door") or scene.raid_state.unlocked.get("bunker",false):return {"ok":false,"stage":"missing-card denial"}
	for frame in 90:scene.player.step_motion(Vector3(0,0,-1),2.4,false,STEP);await scene.get_tree().physics_frame
	var gate_contact=false
	for index in scene.player.get_slide_collision_count():
		if scene.player.get_slide_collision(index).get_collider()==scene.door_nodes.bunker:gate_contact=true
	if scene.get_node("bunker").to_local(scene.player.global_position).z< -5.5 or not gate_contact:return {"ok":false,"stage":"locked gate bypass","at":scene.get_node("bunker").to_local(scene.player.global_position),"gate_contact":gate_contact}
	r=await walk(scene,[Vector3(12.95,4.2,-4.5),Vector3(13.7,4.2,-4.4)])
	if not r.ok:return r
	if not use(scene,"clue") or not scene.raid_state.held.has("bunker_card"):return {"ok":false,"stage":"card ray target"}
	r=await walk(scene,[Vector3(12.95,4.2,-4.6)])
	if not r.ok:return r
	if not use(scene,"door"):return {"ok":false,"stage":"secure ray target"}
	await scene.get_tree().physics_frame;await scene.get_tree().physics_frame
	r=await walk(scene,[Vector3(12.95,4.2,-6.6)])
	if not r.ok:return r
	if not use(scene,"cache"):return {"ok":false,"stage":"cache ray target"}
	var roll=scene.raid_state.searched.get("bunker",-1)
	if not use(scene,"cache") or scene.raid_state.searched.get("bunker",-1)!=roll or scene.toast.text!="Already searched this raid.":return {"ok":false,"stage":"repeat cache"}
	r=await walk(scene,[Vector3(12.95,4.2,-4.6),Vector3(12,4.2,-1.4),Vector3(9,4.2,-1.4)])
	if not r.ok:return r
	r=await walk(scene,points("exterior_stair_down"))
	if not r.ok:return r
	r=await walk(scene,[Vector3(17,0,6.7),Vector3(17,0,14),Vector3(-1,0,14)])
	if not r.ok:return r
	var annex=scene.get_node("bunker")
	var forecourt=Vector2(annex.position.x,annex.position.z+24)
	return await walk(scene,[Vector3(-1,0,15),Vector3(0,scene.generator.height_at(forecourt)-annex.position.y,24)])
