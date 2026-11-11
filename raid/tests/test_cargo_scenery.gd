extends SceneTree
## Actual imported scenes, collision rays, and production movement. No rendered QA.
const Cargo=preload("res://raid/scripts/cargo_scenery.gd")
const TRIS={"container_intact":4020,"container_dented":4020,"stack_large":2976,"stack_pallet":1444}
const STEP=1.0/60.0
var checks:=0
var failures:Array=[]
var imports:Array=[]
var route_results:Array=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func bounds(art:Node3D)->AABB:
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
func verify_imports():
	for sand in [false,true]:
		for kind in Cargo.MODELS:
			var holder=Node3D.new();root.add_child(holder)
			var art=Cargo.attach(holder,kind,sand);var aabb=bounds(art)
			var label=kind+" "+str(sand)
			check(aabb.size.is_equal_approx(Cargo.SIZES[kind]),"Actual imported size "+label)
			check(is_zero_approx(aabb.position.y),"Ground-centred Y-up "+label)
			check(absf(aabb.get_center().x)<0.000001 and absf(aabb.get_center().z)<0.000001,"Centred XZ "+label)
			check(triangles(art)==TRIS[kind],"Full-resolution triangles "+label)
			check(art.basis.is_equal_approx(Basis.IDENTITY),"No scale or orientation correction "+label)
			check(art.position.is_equal_approx(Vector3(0,-Cargo.SIZES[kind].y*0.5,0)),"Bottom offset from existing body centre "+label)
			for type in ["CollisionObject3D","CollisionShape3D","Light3D","Camera3D","AnimationPlayer"]:
				check(art.find_children("*",type,true,false).is_empty(),"No embedded "+type+" "+label)
			for node in [art]+art.find_children("*","Node",true,false):check(node.get_script()==null,"No imported script "+str(node.name))
			var meshes=art.find_children("*","MeshInstance3D",true,false)
			check(meshes.size()==1,"Single mesh "+label)
			for mesh in meshes:
				check(mesh.transform.is_equal_approx(Transform3D.IDENTITY),"Applied mesh transform "+label)
				check(mesh.mesh.get_surface_count()==(4 if kind.begins_with("container") else 7),"Material surface count "+label)
				for surface in mesh.mesh.get_surface_count():
					var material=mesh.get_active_material(surface) as StandardMaterial3D
					check(material!=null and material.resource_name.ends_with("Sand" if sand else "Olive"),"Palette "+label)
					check(material.albedo_texture==null and material.normal_texture==null,"Self-contained material "+label)
					check(material.cull_mode==BaseMaterial3D.CULL_DISABLED,"Expected two-sided material "+label)
			var config=ConfigFile.new();var path="res://raid/assets/cargo/cargo_"+kind+("_sand" if sand else "_olive")+".glb.import"
			check(config.load(path)==OK,"Import descriptor "+label)
			check(not config.get_value("params","nodes/use_name_suffixes",true) and not config.get_value("params","nodes/use_node_type_suffixes",true),"Both suffix conversions disabled "+label)
			check(config.get_value("params","import_script/path","missing")=="","No supplied import script "+label)
			imports.append({"kind":kind,"sand":sand,"size":str(aabb.size),"min":str(aabb.position),"triangles":triangles(art),"surfaces":meshes[0].mesh.get_surface_count()})
			holder.free()
func ray(scene,from:Vector3,to:Vector3)->Dictionary:
	var query=PhysicsRayQueryParameters3D.create(from,to);query.exclude=[scene.player.get_rid()]
	return scene.get_world_3d().direct_space_state.intersect_ray(query)
func verify_body(scene,body:Node3D,at:Vector3,size:Vector3,kind:String,sand:bool,label:String):
	check(body is StaticBody3D and body.position.is_equal_approx(at),"Unchanged body centre "+label)
	check(body.basis.is_equal_approx(Basis.IDENTITY),"Unchanged body basis "+label)
	var shapes=body.find_children("*","CollisionShape3D",true,false)
	check(shapes.size()==1 and shapes[0].shape is BoxShape3D and shapes[0].shape.size.is_equal_approx(size),"Exact original single solid collider "+label)
	check(shapes[0].transform.is_equal_approx(Transform3D.IDENTITY) and not shapes[0].disabled,"Unchanged enabled collider transform "+label)
	var art=body.get_node("CargoArt")
	check(art.get_meta("cargo_kind")==kind and art.get_meta("sand_variant")==sand,"Correct placed variant "+label)
	check(art.scale.is_equal_approx(Vector3.ONE) and art.rotation.is_equal_approx(Vector3.ZERO),"Exact-scale unrotated placement "+label)
	var aabb=bounds(art)
	check(aabb.size.is_equal_approx(size),"Art envelope matches solid box "+label)
	check(is_zero_approx((body.transform*art.transform*aabb).position.y),"Grounded at original local floor "+label)
	check(scene.targets.filter(func(t):return t.node==body).is_empty(),"Cargo is scenery, not an extra pickup or door "+label)
	for axis in [Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
		var extent=size.x*0.5 if axis.x else size.z*0.5
		var hit=ray(scene,body.global_position+axis*(extent+0.15),body.global_position)
		check(not hit.is_empty() and hit.collider==body,"Physics ray hits retained solid side "+label+str(axis))
		if not hit.is_empty():check(hit.position.distance_to(body.global_position+axis*extent)<0.0001,"Exact original boundary "+label+str(axis))
func walk_route(scene,origin:Vector3,points:Array,label:String):
	var player=scene.player
	player.position=origin+Vector3(points[0].x,0.06,points[0].y);player.velocity=Vector3.ZERO
	for frame in 30:player.step_motion(Vector3.ZERO,4.2,false,STEP);await physics_frame
	var ok=true;var distance=0.0
	for index in range(1,points.size()):
		var goal=Vector2(origin.x,origin.z)+points[index]
		var reached=false;var budget=ceili(Vector2(player.position.x,player.position.z).distance_to(goal)/4.2*120+240)
		for frame in budget:
			var current=Vector2(player.position.x,player.position.z)
			if current.distance_to(goal)<0.12:reached=true;break
			var direction=(goal-current).normalized();var before:Vector3=player.position
			player.step_motion(Vector3(direction.x,0,direction.y),4.2,false,STEP);await physics_frame
			distance+=Vector2(before.x,before.z).distance_to(Vector2(player.position.x,player.position.z))
			if absf(player.position.y-origin.y)>0.3 or before.distance_to(player.position)>0.5:break
		if not reached:ok=false;break
	check(ok,label);route_results.append({"label":label,"pass":ok,"walked_metres":distance})
func verify_map(path:String,sand:bool):
	var scene=load(path).instantiate();root.add_child(scene)
	var deadline=Time.get_ticks_msec()+60000
	while not scene.is_raid_ready() and Time.get_ticks_msec()<deadline:await process_frame
	check(scene.is_raid_ready(),"World ready "+path)
	if not scene.is_raid_ready():scene.free();return
	scene.set_physics_process(false);scene.player.set_physics_process(false)
	await physics_frame
	var arts=scene.find_children("CargoArt","Node3D",true,false)
	check(arts.size()==(6 if sand else 5),"Only intended cargo replacements "+path)
	var counts={}
	for target in scene.targets:counts[target.kind]=counts.get(target.kind,0)+1
	check(counts=={"cache":6,"door":4,"clue":4,"switch":3,"extract":2},"Original interaction target counts "+path)
	if sand:
		var warehouse=scene.get_node("glasskiln/Warehouse")
		for z in [-5,1,6]:
			for kind in ["stack_large","stack_pallet"]:
				var at=Vector3(4.8,1.1,z) if kind=="stack_large" else Vector3(-4.8,0.75,z)
				var matches=arts.filter(func(art):return art.get_parent().get_parent()==warehouse and art.get_parent().position.is_equal_approx(at))
				check(matches.size()==1,"Warehouse cargo position "+str(at))
				if matches.size()==1:verify_body(scene,matches[0].get_parent(),at,Cargo.SIZES[kind],kind,true,"warehouse "+str(at))
		for x in [-2.7,2.7]:await walk_route(scene,warehouse.global_position,[Vector2(x,8.5),Vector2(x,-8.5),Vector2(0,-8.5),Vector2(0,8.5)],"Warehouse standing aisle "+str(x))
	else:
		var yard=scene.get_node("yard")
		for i in 5:
			var at=Vector3(-12+(i%2)*23,1.2,-9+(i/2)*7)
			var matches=arts.filter(func(art):return art.get_parent().get_parent()==yard and art.get_parent().position.is_equal_approx(at))
			check(matches.size()==1,"Salvage container position "+str(i))
			if matches.size()==1:verify_body(scene,matches[0].get_parent(),at,Vector3(3.5,2.4,5),"container_dented" if i%2 else "container_intact",false,"yard "+str(i))
		for x in [-8.0,7.8]:await walk_route(scene,yard.global_position,[Vector2(x,9),Vector2(x,-13)],"Salvage inner flanking lane "+str(x))
		for z in [-5.5,1.5]:await walk_route(scene,yard.global_position,[Vector2(-16,z),Vector2(-8,z)],"Salvage 2 m inter-container gap "+str(z))
	scene.free();await preload("res://raid/tests/audio_shutdown.gd").drain(self)
func run():
	verify_imports()
	await verify_map("res://raid/relay_ridge.tscn",false)
	await verify_map("res://raid/cinder_basin.tscn",true)
	print("CARGO_SCENERY_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"imports":imports,"routes":route_results,"rendered":false,"native_input":false,"windows":false}))
	quit(0 if failures.is_empty() else 1)
