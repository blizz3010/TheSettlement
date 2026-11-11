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
	check(scene.is_raid_ready(),"Generated Relay map ready")
	if not scene.is_raid_ready():scene.free();quit(1);return
	scene.player.enabled=false;scene.player.set_physics_process(false)
	var poi_root=scene.get_node("relay");var art=poi_root.get_node("RelayLandmark")
	for group in ["Lattice","Platform","Equipment","Dishes","Cables","Hut","Roof"]:
		check(art.has_node(group) and art.get_node(group).get_child_count()>0,"Batched authored group "+group)
	check(art.find_children("*","CollisionObject3D",true,false).is_empty(),"Landmark cannot obstruct ground approaches or occupied room")
	check(art.find_children("*","CollisionShape3D",true,false).is_empty(),"Upper visual works do not imply climb collision")
	var meshes=art.find_children("*","MeshInstance3D",true,false)
	check(meshes.size()<=24,"Material batching bounds additional mesh instances")
	var valid=true;var max_y=0.0;var min_y=100.0
	for mesh in meshes:
		var bounds=mesh.mesh.get_aabb();valid=valid and bounds.size.is_finite() and bounds.size.length()>0
		max_y=maxf(max_y,bounds.end.y);min_y=minf(min_y,bounds.position.y)
	check(valid and max_y>29 and max_y<31 and min_y>=0,"Finite grounded hut and recognizable tall silhouette")
	var roof_slope_ok=true;var ridge_vertices=0;var eave_vertices=0
	for vertex in art.get_node("Roof/dark").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if absf(vertex.x)<0.2:
			ridge_vertices+=1;roof_slope_ok=roof_slope_ok and vertex.y>5.15 and vertex.y<5.45
		if absf(vertex.x)>6.3:
			eave_vertices+=1;roof_slope_ok=roof_slope_ok and vertex.y>3.9 and vertex.y<4.2
	check(roof_slope_ok and ridge_vertices>0 and eave_vertices>0,"Both transformed roof caps descend from ridge to eaves")
	check(art.get_meta("parts").Lattice==128,"Four legs, seven full X-braced bays and eight ring levels")
	check(art.get_meta("parts").Dishes==10,"Two dish bowls with supports/feed horns")
	var poi=scene.generator.pois.filter(func(p):return p.id=="relay")[0]
	check(poi.lock=="code" and poi.loot==[4,5],"Code lock and high-tier cache retained")
	for kind in ["door","clue","cache"]:
		var targets=scene.targets.filter(func(t):return t.kind==kind and t.poi.id=="relay")
		check(targets.size()==1,"Exactly one original "+kind+" interaction")
		var expected={"door":Vector3(0,1.35,5),"clue":Vector3(-9,0.9,7),"cache":Vector3(0,0.5,-1)}[kind]
		check(targets[0].node.position.is_equal_approx(expected),"Original "+kind+" position retained")
	# Visual cladding must not project into the clear front aperture below its lintel.
	var aperture_clear=true
	for mesh in art.get_node("Hut").get_children():
		for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			if absf(vertex.x)<1.26 and vertex.y<2.75 and vertex.z>4.8 and vertex.z<5.7:aperture_clear=false
	check(aperture_clear,"Decorative cladding leaves the door aperture visibly clear")
	# Deterministic regeneration independent of natural placement RNG.
	var holder=Node3D.new();root.add_child(holder)
	var again=preload("res://raid/scripts/relay_landmark.gd").new().build(holder)
	var same=true
	for mesh in meshes:
		var peer=again.get_node(art.get_path_to(mesh))
		same=same and mesh.mesh.surface_get_arrays(0)==peer.mesh.surface_get_arrays(0)
	check(same,"Identical procedural rebuild")
	holder.free()
	print("RELAY_LANDMARK_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"mesh_instances":meshes.size(),"rendered":false}))
	scene.free();await preload("res://raid/tests/audio_shutdown.gd").drain(self);quit(0 if failures.is_empty() else 1)
