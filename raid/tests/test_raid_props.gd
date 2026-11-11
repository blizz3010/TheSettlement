extends SceneTree
const Props=preload("res://raid/scripts/raid_props.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func bounds(art:Node3D)->AABB:
	var box:=AABB();var first=true
	for mesh in art.find_children("*","MeshInstance3D",true,false):
		var transformed=art.global_transform.affine_inverse()*mesh.global_transform*mesh.mesh.get_aabb()
		box=transformed if first else box.merge(transformed);first=false
	return box
func triangles(art:Node3D)->int:
	var count=0
	for mesh in art.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var arrays=mesh.mesh.surface_get_arrays(surface)
			count+=arrays[Mesh.ARRAY_INDEX].size()/3
	return count
func glow(art:Node3D):return art.get_meta("glow_materials")[0].material
func verify_models():
	for saltflat in [false,true]:
		var holder=Node3D.new();root.add_child(holder)
		var cache=Props.attach_cache(holder,saltflat)
		check(bounds(cache).size.is_equal_approx(Vector3(1.5,1,1)),"Imported cache dimensions "+str(saltflat))
		check(is_zero_approx(bounds(cache).position.y),"Cache ground origin "+str(saltflat))
		check(triangles(cache)==708,"Imported cache triangle count "+str(saltflat))
		var lid=cache.find_child("Cache_Lid",true,false)
		check(lid.position.is_equal_approx(Vector3(0,0.85,-0.484)),"Rear seam hinge "+str(saltflat))
		check(lid.has_node("Cache_Latch"),"Latch parent follows hinge "+str(saltflat))
		check(cache.find_children("*","CollisionObject3D",true,false).is_empty(),"No hidden cache collision")
		var beacon=Props.attach_beacon(holder,saltflat)
		check(bounds(beacon).size.is_equal_approx(Vector3(1.07,2,1.08)),"Imported beacon dimensions "+str(saltflat))
		check(is_zero_approx(bounds(beacon).position.y),"Beacon ground origin "+str(saltflat))
		check(triangles(beacon)==1214,"Imported beacon triangle count "+str(saltflat))
		check(beacon.find_child("Beacon_Panel",true,false)!=null,"Separate beacon panel")
		check(beacon.get_meta("glow_materials").size()>0 and glow(beacon).emission_enabled,"Imported emissive material")
		check(beacon.find_children("*","CollisionObject3D",true,false).is_empty(),"No hidden beacon collision")
		holder.free()
func verify_map(path:String,saltflat:bool):
	var scene=load(path).instantiate();root.add_child(scene)
	var deadline=Time.get_ticks_msec()+60000
	while not scene.is_raid_ready() and Time.get_ticks_msec()<deadline:await process_frame
	check(scene.is_raid_ready(),"Map with imported props ready "+path)
	if not scene.is_raid_ready():scene.free();return
	scene.set_physics_process(false);scene.player.set_physics_process(false)
	var caches=scene.targets.filter(func(t):return t.kind=="cache")
	var extracts=scene.targets.filter(func(t):return t.kind=="extract")
	check(caches.size()==6 and extracts.size()==2,"Original target counts "+path)
	for target in caches:
		var body=target.node;var art=body.get_node("CacheArt")
		if saltflat and target.poi.id=="obsidian":
			check(scene.get_node("obsidian").to_local(body.global_position).is_equal_approx(Vector3(0,9,-10.5)),"Archive cache target in upper vault POI-local frame")
		else:
			check(body.position.is_equal_approx(Vector3(0,0.5,-3 if target.poi.lock=="puzzle" else -1)),"Cache target centre preserved "+target.poi.id)
		check(body.get_child(0) is CollisionShape3D and body.get_child(0).shape.size==Vector3(1.5,1,1),"Cache collider preserved "+target.poi.id)
		check(art.position==Vector3(0,-0.5,0) and art.scale==Vector3.ONE,"Cache exact-scale grounding "+target.poi.id)
		var lid=art.find_child("Cache_Lid",true,false)
		check(is_zero_approx(lid.rotation_degrees.x) and not art.get_meta("opened",false),"Fresh cache closed "+target.poi.id)
		var material=art.find_child("Cache_Body",true,false).get_active_material(0)
		check(material.resource_name.ends_with("SaltFlat" if saltflat else "Woodland"),"Correct biome materials "+target.poi.id)
		if target.poi.lock!="":
			scene._interact(target)
			check(not art.get_meta("opened",false) and not scene.raid_state.searched.has(target.poi.id),"Denied search leaves lid closed "+target.poi.id)
		scene.raid_state.unlocked[target.poi.id]=true;scene._interact(target)
		check(art.get_meta("opened",false) and scene.raid_state.searched.has(target.poi.id),"Successful search opens visual "+target.poi.id)
		var roll=scene.raid_state.searched[target.poi.id];scene._interact(target)
		check(scene.raid_state.searched[target.poi.id]==roll,"Repeated search cannot reroll "+target.poi.id)
	await create_timer(0.4).timeout
	for target in caches:
		check(is_equal_approx(target.node.get_node("CacheArt").find_child("Cache_Lid",true,false).rotation_degrees.x,-70.0),"Lid reaches supplied hinge angle "+target.poi.id)
	for i in extracts.size():
		var body=extracts[i].node;var art=body.get_node("BeaconArt")
		var p:Vector2=scene.settings.EXTRACTS[i]+Vector2(2,0)
		check(body.position.is_equal_approx(Vector3(p.x,scene.generator.height_at(p)+1,p.y)),"Beacon target centre unchanged")
		check(body.get_child(0).shape.size==Vector3(1.2,2,1.2),"Beacon collision footprint preserved")
		check(art.position==Vector3(0,-1,0) and art.scale==Vector3.ONE,"Beacon exact-scale grounding")
		check(glow(art).resource_name.ends_with("SaltFlat" if saltflat else "Woodland"),"Correct beacon biome material")
	var first=extracts[0].node.get_node("BeaconArt");var second=extracts[1].node.get_node("BeaconArt")
	check(glow(first)!=glow(second),"Per-beacon glow instances")
	var original_energy=glow(second).emission_energy_multiplier
	Props.beacon_state(extracts[0].node,"active",0.25)
	check(glow(first).emission_energy_multiplier>original_energy and glow(second).emission_energy_multiplier==original_energy,"Pulse affects only active beacon")
	Props.beacon_state(extracts[0].node,"idle")
	check(glow(first).emission_energy_multiplier==original_energy,"Cancel restores idle energy")
	var start:Vector2=scene.settings.EXTRACTS[0]
	scene.player.position=Vector3(start.x,scene.generator.height_at(start)+0.08,start.y);scene.player.velocity=Vector3.ZERO
	for i in 30:
		scene.player.step_motion(Vector3.ZERO,4.2,false,1.0/60.0);await physics_frame
	scene._begin_extraction(extracts[0])
	check(first.get_meta("signal_state")=="active" and scene.raid_state.extraction_id=="extract0","Gameplay activation drives glow")
	scene._cancel_extraction()
	check(first.get_meta("signal_state")=="idle" and glow(first).emission_energy_multiplier==original_energy,"Gameplay cancellation restores glow")
	scene._begin_extraction(extracts[0]);scene._physics_process(8.01)
	check(scene.raid_state.extracted_at=="extract0" and first.get_meta("signal_state")=="complete","Completion signal survives results modal cancellation")
	check(glow(second).emission_energy_multiplier==original_energy,"Completion leaves other beacon unchanged")
	scene.free();await preload("res://raid/tests/audio_shutdown.gd").drain(self)
func run():
	verify_models()
	await verify_map("res://raid/relay_ridge.tscn",false)
	await verify_map("res://raid/cinder_basin.tscn",true)
	print("RAID_PROPS_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"rendered":false}))
	quit(0 if failures.is_empty() else 1)
