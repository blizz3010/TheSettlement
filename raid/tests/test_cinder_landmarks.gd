extends SceneTree
## Focused procedural bounds/clearance contract; not rendered art acceptance.
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func run():
	var scene=load("res://raid/cinder_basin.tscn").instantiate();root.add_child(scene)
	var deadline=Time.get_ticks_msec()+60000
	while not scene.is_raid_ready() and Time.get_ticks_msec()<deadline:await process_frame
	check(scene.is_raid_ready(),"Cinder ready with landmark dressing")
	if not scene.is_raid_ready():scene.free();quit(1);return
	scene.player.set_physics_process(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for id in ["helion"]:
		var poi:Node3D=scene.get_node(id)
		var art:Node3D=poi.get_node("HelionLandmark" if id=="helion" else "ObsidianLandmark")
		var limit=AABB(Vector3(-16.5,0,-11.5),Vector3(33,19.5,17)) if id=="helion" else AABB(Vector3(-12.02,0,-9.52),Vector3(24.04,7.6,15.02))
		# 1 mm tolerance covers global-to-local floating-point cancellation only.
		var bounds_ok=true;var room_clear=true;var entrance_clear=true;var meshes=0
		var room=AABB(Vector3(-4.8,0.1,-2.8),Vector3(9.6,2.5,7.6))
		var entrance=AABB(Vector3(-1.29,0.08,4.7),Vector3(2.58,2.6,1.1))
		for mesh in art.find_children("*","MeshInstance3D",true,false):
			var local:Transform3D=poi.global_transform.affine_inverse()*mesh.global_transform
			var b:AABB=local*mesh.get_aabb()
			bounds_ok=bounds_ok and limit.grow(0.001).encloses(b)
			room_clear=room_clear and not room.intersects(b)
			entrance_clear=entrance_clear and not entrance.intersects(b)
			meshes+=1
		check(bounds_ok,id+" all transformed mesh bounds within reserved envelope")
		check(room_clear,id+" all new art excludes standing room volume")
		check(entrance_clear,id+" 2.58 m entrance art clearance preserved")
		check(meshes<220,id+" bounded procedural mesh count")
		var physical_ok=true
		for shape in art.find_children("*","CollisionShape3D",true,false):
			var local:Transform3D=poi.global_transform.affine_inverse()*shape.global_transform
			var s:Vector3=shape.shape.size if shape.shape is BoxShape3D else Vector3(shape.shape.radius*2,shape.shape.height,shape.shape.radius*2)
			var b:AABB=local*AABB(-s*0.5,s)
			physical_ok=physical_ok and limit.grow(0.001).encloses(b) and not room.intersects(b) and not entrance.intersects(b)
		check(physical_ok,id+" collision bounds preserve room and entrance")
		# Fascia side faces must sit beyond the original roof side faces, not
		# coincide while their vertical intervals overlap (visible z-fighting).
		var fascia:MeshInstance3D=art.get_node("ControlRoofFascia" if id=="helion" else "LowerBlueFascia").get_child(0)
		var fascia_bounds:AABB=(poi.global_transform.affine_inverse()*fascia.global_transform)*fascia.get_aabb()
		var roof_size=Vector3(10.6,0.22,8.6) if id=="helion" else Vector3(12.6,0.22,12.6)
		var roof_center=Vector3(0,3.9,1) if id=="helion" else Vector3(0,3.9,-1)
		var roof_bounds=AABB(roof_center-roof_size*0.5,roof_size)
		check(fascia_bounds.position.x<roof_bounds.position.x-0.025 and fascia_bounds.end.x>roof_bounds.end.x+0.025 and fascia_bounds.position.z<roof_bounds.position.z-0.025 and fascia_bounds.end.z>roof_bounds.end.z+0.025,id+" fascia side faces clear original roof by at least 25 mm")
		for kind in ["door","clue","cache"]:
			var expected={"door":Vector3(0,1.35,5),"clue":Vector3(-9,0.9,7),"cache":Vector3(0,0.5,-1)}[kind]
			var targets=scene.targets.filter(func(t):return t.kind==kind and t.poi.id==id)
			check(targets.size()==1 and poi.to_local(targets[0].node.global_position).is_equal_approx(expected),id+" unchanged "+kind+" target")
		# Dense standing-capsule queries cover forecourt/supplies/door approaches.
		var clear=true
		for segment in [[Vector2(0,20),Vector2(-9,9)],[Vector2(-9,9),Vector2(0,7.4)],[Vector2(0,7.4),Vector2(0,5.8)]]:
			var a:Vector2=segment[0];var b:Vector2=segment[1]
			for step in range(ceili(a.distance_to(b)*4)+1):
				var p=a.move_toward(b,step*0.25)
				var query=PhysicsShapeQueryParameters3D.new();query.shape=scene.player.standing_shape;query.transform=Transform3D(Basis.IDENTITY,poi.global_position+Vector3(p.x,1.02,p.y));query.exclude=[scene.player.get_rid()]
				clear=clear and scene.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
		check(clear,id+" dense standing-capsule approach clearance")
		print("LANDMARK_MESH_COUNT ",id," ",meshes)
	var helion=scene.get_node("helion/HelionLandmark")
	check(helion.find_children("SegmentedMirror*","Node3D",true,false).size()==4,"four original-position mirror assemblies")
	var pedestals=helion.find_children("MirrorPedestal*","Node3D",true,false)
	check(pedestals.size()==4,"four uniquely named pedestal support assemblies")
	for pedestal in pedestals:
		var axle:MeshInstance3D=pedestal.get_node("Axle").get_child(0)
		var cradle:MeshInstance3D=pedestal.get_node("MirrorCradle").get_child(0)
		var hinge:MeshInstance3D=pedestal.get_node("TiltHinge")
		var back:MeshInstance3D=pedestal.get_node("SegmentedMirror/Backplate").get_child(0)
		var inverse:Transform3D=pedestal.global_transform.affine_inverse()
		var a:AABB=(inverse*axle.global_transform)*axle.get_aabb()
		var c:AABB=(inverse*cradle.global_transform)*cradle.get_aabb()
		var h:AABB=(inverse*hinge.global_transform)*hinge.get_aabb()
		check(a.intersects(c) and c.intersects(h),"mirror axle/cradle/hinge bounds overlap")
		# This point is inside the horizontal hinge cylinder (radial distance
		# .10 < .18), and must also lie inside the actual rotated backplate.
		# Testing in backplate space avoids a false positive from tilted AABBs.
		var contact:Vector3=back.to_local(pedestal.to_global(Vector3(0,3.1,0)))
		check(back.mesh.get_aabb().has_point(contact),"hinge physically intersects tilted mirror backplate")
	check(helion.find_children("ReflectorTile*","Node3D",true,false).size()==16,"four separated reflector tiles per mirror")
	check(helion.get_node("CrownUpperFacet").mesh.top_radius<helion.get_node("CrownUpperFacet").mesh.bottom_radius,"tapered faceted receiver crown")
	var archive=scene.get_node("obsidian/ObsidianLandmark")
	check(scene.get_node("obsidian").get_meta("archive_version")=="2.1","imported full-scale archive replaces former room")
	check(archive.find_children("Site_*","MeshInstance3D",true,false).is_empty(),"presentation site meshes excluded")
	check(archive.find_children("Door_Vault","MeshInstance3D",true,false).is_empty(),"open imported vault leaf replaced by closed game door")
	for kind in ["door","clue","cache"]:
		var expected={"door":Vector3(0,9.75,-8),"clue":Vector3(-9,0.9,19),"cache":Vector3(0,9,-10.5)}[kind]
		var targets=scene.targets.filter(func(t):return t.kind==kind and t.poi.id=="obsidian")
		check(targets.size()==1 and scene.get_node("obsidian").to_local(targets[0].node.global_position).is_equal_approx(expected),"one correctly placed archive "+kind)
	print("CINDER_LANDMARK_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"rendered":false}))
	scene.free();await preload("res://raid/tests/audio_shutdown.gd").drain(self);quit(0 if failures.is_empty() else 1)
