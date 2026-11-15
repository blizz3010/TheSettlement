extends SceneTree
## Item 12 rollout contract: with midstyle_rollout.gd on, the remodelled relay lever, loot caches
## and cargo keep the originals' node names, pivots, outer bounds, motion and gameplay bodies.
## With it off (the default) every attach still returns the original GLB. Also checks the normal
## game start reaches the ship settlement that switches both swaps on.
const Rollout=preload("res://raid/scripts/midstyle_rollout.gd")
const Controls=preload("res://raid/scripts/puzzle_controls.gd")
const Props=preload("res://raid/scripts/raid_props.gd")
const Cargo=preload("res://raid/scripts/cargo_scenery.gd")
var checks:=0
var failures:Array=[]
var report:={}
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func bounds(art:Node3D)->AABB:
	var box:=AABB();var first=true
	for mesh in art.find_children("*","MeshInstance3D",true,false):
		var value=art.global_transform.affine_inverse()*mesh.global_transform*mesh.mesh.get_aabb()
		box=value if first else box.merge(value);first=false
	return box
func vertex_bounds(art:Node3D,mesh:MeshInstance3D)->AABB:
	var to_art=art.global_transform.affine_inverse()*mesh.global_transform;var box:=AABB();var first=true
	for s in mesh.mesh.get_surface_count():
		for v in mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var p=to_art*v
			if first:box=AABB(p,Vector3.ZERO);first=false
			else:box=box.expand(p)
	return box
func triangles(art:Node3D)->int:
	var total:=0
	for mesh in art.find_children("*","MeshInstance3D",true,false):
		for s in mesh.mesh.get_surface_count():total+=mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size()/3
	return total
func surfaces(art:Node3D)->int:
	var total:=0
	for mesh in art.find_children("*","MeshInstance3D",true,false):total+=mesh.mesh.get_surface_count()
	return total
func clean(art:Node3D,label:String):
	for type in ["CollisionObject3D","CollisionShape3D","Light3D","AnimationPlayer","Camera3D"]:
		check(art.find_children("*",type,true,false).is_empty(),"No embedded "+type+" "+label)
	for node in art.find_children("*","Node",true,false):check(node.get_script()==null,"No imported script "+label)
	check(art.scene_file_path.begins_with(Rollout.DIR),"Remodel instanced "+label+" ("+art.scene_file_path+")")
func near(a:Vector3,b:Vector3,tol:=0.002)->bool:return (a-b).abs().x<=tol and (a-b).abs().y<=tol and (a-b).abs().z<=tol

func verify_off():
	Rollout.enabled=false
	var holder=Node3D.new();root.add_child(holder)
	check(Controls.attach(holder,false).scene_file_path.ends_with("relay_lever_weather_station.glb"),"Off: original relay GLB")
	check(Props.attach_cache(holder,true).scene_file_path.ends_with("loot_cache_saltflat.glb"),"Off: original cache GLB")
	check(Cargo.attach(holder,"stack_pallet",false).scene_file_path.ends_with("cargo_stack_pallet_olive.glb"),"Off: original cargo GLB")
	holder.free()

func verify_relay():
	var original=preload("res://raid/assets/puzzle_controls/relay_lever_weather_station.glb").instantiate()
	var pivot=original.find_child("Relay_Lever",true,false).position;original.free()
	var holder=Node3D.new();root.add_child(holder)
	var art=Controls.attach(holder,false);clean(art,"relay")
	var housing=art.find_child("Relay_Housing",true,false) as MeshInstance3D
	var lever=art.find_child("Relay_Lever",true,false) as MeshInstance3D
	var lamp=art.find_child("Relay_Indicator",true,false) as MeshInstance3D
	check(housing!=null and lever!=null and lamp!=null,"Relay node names kept")
	if housing==null or lever==null or lamp==null:holder.free();return
	check(near(housing.mesh.get_aabb().size,Vector3(0.6,1.8,0.6)),"Housing fills the 0.6 x 1.8 x 0.6 collision envelope "+str(housing.mesh.get_aabb()))
	check(near(lever.position,pivot,0.0005),"Lever pivot matches the original "+str(lever.position))
	check(is_equal_approx(lever.rotation_degrees.x,-40.0),"Lever rest pose")
	check(lamp.mesh.get_surface_count()==1 and lamp.get_active_material(0).resource_name=="Relay_Indicator_Amber","Lamp keeps its single named material")
	var lamp_material=art.get_meta("indicator_material") as StandardMaterial3D
	check(lamp_material!=null and lamp_material.emission_enabled,"Lamp is emissive and duplicated per relay")
	var sweep:=[]
	for degrees in [-40.0,-20.0,0.0,20.0,40.0]:
		lever.rotation_degrees.x=degrees
		var v=vertex_bounds(art,lever)
		check(v.end.z<0.62 and v.size.x<0.601 and v.end.y<1.801,"Lever vertices stay in front clearance at "+str(degrees))
		sweep.append({"deg":degrees,"end_z":snappedf(v.end.z,0.001)})
	lever.rotation_degrees.x=-40.0
	var body=StaticBody3D.new();root.add_child(body);var art2=Controls.attach(body,false)
	var energy:float=art2.get_meta("indicator_energy")
	Controls.activate(body)
	await create_timer(1.0).timeout
	for i in 2:await process_frame
	check(is_equal_approx(art2.find_child("Relay_Lever",true,false).rotation_degrees.x,-40.0),"Momentary lever returns to rest")
	check(is_equal_approx(art2.get_meta("indicator_material").emission_energy_multiplier,energy),"Lamp returns to idle energy")
	report["relay"]={"triangles":triangles(art),"surfaces":surfaces(art),"bounds":str(bounds(art)),"sweep":sweep}
	body.free();holder.free()

func verify_caches():
	for saltflat in [false,true]:
		var holder=Node3D.new();root.add_child(holder)
		var body=StaticBody3D.new();holder.add_child(body)
		var art=Props.attach_cache(body,saltflat);var label="cache "+str(saltflat);clean(art,label)
		var b=bounds(art)
		check(near(b.size,Vector3(1.5,1,1),0.03) and absf(b.position.y)<0.002,"Cache keeps the 1.5 x 1 x 1 footprint "+label+" "+str(b))
		var lid=art.find_child("Cache_Lid",true,false)
		check(lid!=null and lid.position.is_equal_approx(Vector3(0,0.85,-0.484)),"Rear seam hinge "+label)
		check(lid!=null and lid.has_node("Cache_Latch"),"Latch rides on the lid "+label)
		var mats:={}
		for mesh in art.find_children("*","MeshInstance3D",true,false):
			for s in mesh.mesh.get_surface_count():mats[mesh.get_active_material(s).resource_name]=true
		check(mats.keys().all(func(n):return n.ends_with("SaltFlat" if saltflat else "Woodland")),"Palette "+label)
		Props.open_cache(body)
		# Wait on time, not frames: the 0.32 s tween can outlast 30 uncapped headless frames.
		await create_timer(0.6).timeout
		for i in 2:await process_frame
		if lid!=null:check(is_equal_approx(lid.rotation_degrees.x,-70.0),"Lid opens about the hinge "+label)
		report[label]={"triangles":triangles(art),"surfaces":surfaces(art),"bounds":str(b)}
		holder.free()

func verify_cargo():
	for sand in [false,true]:
		for kind in Cargo.MODELS:
			var holder=Node3D.new();root.add_child(holder)
			var art=Cargo.attach(holder,kind,sand);var label=kind+" "+str(sand);clean(art,label)
			var b=bounds(art)
			check(near(b.size,Cargo.SIZES[kind],0.005),"Size matches the original "+label+" "+str(b.size))
			check(absf(b.position.y)<0.002 and absf(b.get_center().x)<0.005 and absf(b.get_center().z)<0.005,"Ground-centred "+label)
			check(art.position.is_equal_approx(Vector3(0,-Cargo.SIZES[kind].y*0.5,0)),"Bottom offset kept "+label)
			var meshes=art.find_children("*","MeshInstance3D",true,false)
			check(meshes.size()==1,"Single mesh "+label)
			report[label]={"triangles":triangles(art),"surfaces":surfaces(art)}
			holder.free()

func verify_map(path:String,expect:Dictionary):
	var scene=load(path).instantiate();root.add_child(scene)
	var deadline=Time.get_ticks_msec()+60000
	while not scene.is_raid_ready() and Time.get_ticks_msec()<deadline:await process_frame
	check(scene.is_raid_ready(),"Map ready "+path)
	if not scene.is_raid_ready():scene.free();return
	scene.set_physics_process(false);scene.player.set_physics_process(false)
	for art_name in expect:
		var arts=scene.find_children(art_name,"Node3D",true,false)
		var swapped=arts.filter(func(a):return a.scene_file_path.begins_with(Rollout.DIR))
		check(arts.size()==expect[art_name] and swapped.size()==arts.size(),"All "+art_name+" swapped in "+path+" ("+str(swapped.size())+"/"+str(arts.size())+")")
	var counts={}
	for target in scene.targets:counts[target.kind]=counts.get(target.kind,0)+1
	check(counts=={"cache":6,"door":4,"clue":4,"switch":3,"extract":2},"Interaction targets unchanged "+path)
	scene.free();await preload("res://raid/tests/audio_shutdown.gd").drain(self)

## Normal game start (project main_scene since #9): play_title -> ship settlement, whose
## _initialize_world turns on midstyle_swap (item 11) and midstyle_rollout (item 12) for raids.
func verify_live_flow():
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://raid/play_title.tscn","Normal start is play_title.tscn")
	check(FileAccess.get_file_as_string("res://raid/play_title.tscn").contains('path="res://raid/scripts/play_title.gd"'),"play_title.tscn runs play_title.gd")
	var title_script:Script=load("res://raid/scripts/play_title.gd")
	check(title_script.get_base_script().resource_path=="res://raid/scripts/ship_title_preview.gd","play_title builds on ship_title_preview")
	check(title_script.get_base_script().source_code.contains('world_path = "res://raid/ship_settlement_preview.tscn"'),"Normal start loads the ship settlement")
	var src:String=load("res://raid/scripts/ship_settlement_preview.gd").source_code
	check(preload("res://raid/scripts/midstyle_swap.gd").enabled,"Item 11 swap on by default")
	check(src.contains("MidstyleRollout.enabled = MidstyleSwap.enabled") and src.contains("MidstyleSwap.apply(self)"),"Ship settlement enables both swaps")
	check(not Rollout.enabled,"Rollout off until a ship settlement initialises")

func run():
	verify_live_flow()
	verify_off()
	Rollout.enabled=true
	await verify_relay()
	await verify_caches()
	verify_cargo()
	await verify_map("res://raid/relay_ridge.tscn",{"PuzzleControlArt":3,"CacheArt":6,"CargoArt":5})
	await verify_map("res://raid/cinder_basin.tscn",{"CacheArt":6,"CargoArt":6})
	Rollout.enabled=false
	print("MIDSTYLE_ROLLOUT_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"report":report,"rendered":false}))
	quit(0 if failures.is_empty() else 1)
