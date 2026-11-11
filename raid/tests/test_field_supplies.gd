extends SceneTree
## Imported geometry and real ray/physics/gameplay checks. No rendered/native-input claim.
const Supplies=preload("res://raid/scripts/field_supplies.gd")
const EXPECTED={
	"key":{"size":Vector3(0.18,0.014,0.042),"tris":296,"file":"maintenance_key"},
	"keycard":{"size":Vector3(0.12,0.0095,0.08),"tris":168,"file":"access_card"},
	"code":{"size":Vector3(0.22,0.0257,0.3005),"tris":280,"file":"clipboard"},
	"puzzle":{"size":Vector3(0.26,0.0296,0.19),"tris":200,"file":"maintenance_logbook"},
	"stand":{"size":Vector3(1.4,0.8,1.0),"tris":564,"file":"supply_stand"},
}
var checks:=0
var failures:Array=[]
var imports:Array=[]
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
func surface_height(art:Node3D,x:float,z:float)->float:
	var highest:=-INF
	for mesh in art.find_children("*","MeshInstance3D",true,false):
		var transform=art.global_transform.affine_inverse()*mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			var arrays=mesh.mesh.surface_get_arrays(surface)
			var vertices=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
			for index in range(0,indices.size(),3):
				var hit=Geometry3D.ray_intersects_triangle(Vector3(x,2,z),Vector3.DOWN,transform*vertices[indices[index]],transform*vertices[indices[index+1]],transform*vertices[indices[index+2]])
				if hit!=null:highest=maxf(highest,hit.y)
	return highest
func verify_imports():
	for saltflat in [false,true]:
		for kind in EXPECTED:
			var body=Node3D.new();root.add_child(body)
			var art=Supplies.attach_stand(body,saltflat) if kind=="stand" else Supplies.attach_pickup(body,kind,saltflat)
			var aabb=bounds(art);var expected=EXPECTED[kind]
			var label=kind+" "+str(saltflat)
			check(aabb.size.is_equal_approx(expected.size),"Actual imported size "+label)
			check(absf(aabb.position.y)<0.000001,"Bottom-centred Y-up import "+label)
			check(absf(aabb.get_center().x)<0.000001 and absf(aabb.get_center().z)<0.0003,"Centred X/Z import "+label)
			check(triangles(art)==expected.tris,"Imported full-resolution triangle count "+label)
			check(art.basis.is_equal_approx(Basis.IDENTITY),"Identity scale and orientation "+label)
			if kind=="stand":
				for point in [Vector2.ZERO,Vector2(-0.3,-0.2),Vector2(0.3,0.2)]:
					check(is_equal_approx(surface_height(art,point.x,point.y),0.792),"Actual deck triangles at 0.792 m "+label+str(point))
			for type in ["CollisionObject3D","CollisionShape3D","Light3D","Camera3D","AnimationPlayer"]:
				check(art.find_children("*",type,true,false).is_empty(),"No embedded "+type+" "+label)
			for node in [art]+art.find_children("*","Node",true,false):check(node.get_script()==null,"No imported script "+str(node.name))
			for mesh in art.find_children("*","MeshInstance3D",true,false):
				check(mesh.transform.is_equal_approx(Transform3D.IDENTITY),"Applied mesh transform "+str(mesh.name))
				for surface in mesh.mesh.get_surface_count():
					var material=mesh.get_active_material(surface) as StandardMaterial3D
					check(material!=null and material.resource_name.ends_with("SaltFlat" if saltflat else "Woodland"),"Correct palette "+label)
					check(material.albedo_texture==null and material.normal_texture==null,"Self-contained flat material "+label)
			var config=ConfigFile.new()
			var path="res://raid/assets/field_supplies/"+expected.file+("_saltflat" if saltflat else "_woodland")+".glb.import"
			check(config.load(path)==OK,"Import metadata present "+label)
			check(config.get_value("params","nodes/use_name_suffixes",true)==false and config.get_value("params","nodes/use_node_type_suffixes",true)==false,"Suffix conversion disabled "+label)
			check(config.get_value("params","import_script/path","missing")=="","No import script "+label)
			imports.append({"kind":kind,"saltflat":saltflat,"size":str(aabb.size),"min":str(aabb.position),"triangles":triangles(art)})
			body.free()
func state_snapshot(state)->Dictionary:
	return {"held":state.held.duplicate(true),"notes":state.notes.duplicate(true),"clues":state.clues.duplicate(true),"unlocked":state.unlocked.duplicate(true),"searched":state.searched.duplicate(true),"switch_step":state.switch_step}
func visible_text(parent:Node)->String:
	var result=""
	for node in parent.find_children("*","Label",true,false):result+=node.text+"\n"
	return result
func verify_map(path:String,saltflat:bool):
	var scene=load(path).instantiate();root.add_child(scene)
	var deadline=Time.get_ticks_msec()+60000
	while not scene.is_raid_ready() and Time.get_ticks_msec()<deadline:await process_frame
	check(scene.is_raid_ready(),"Scene readiness "+path)
	if not scene.is_raid_ready():scene.free();return
	scene.set_physics_process(false);scene.player.set_physics_process(false)
	var targets=scene.targets.filter(func(t):return t.kind=="clue")
	check(targets.size()==4,"Exactly four unchanged clue targets "+path)
	var oracle=scene._create_state(scene.settings.map_seed)
	var seen:Dictionary={}
	for target in targets:
		var body=target.node;var kind:String=target.poi.lock;seen[kind]=true
		var art=body.get_node("FieldSupplyArt");var stand=body.get_parent().get_node("FieldSupplyStand");var stand_art=stand.get_node("SupplyStandArt")
		var label=target.poi.id
		check(body.position.is_equal_approx(Vector3(-9,0.9,7)),"Original pickup target centre "+label)
		check(body.get_child(0).shape.size.is_equal_approx(Vector3(0.7,0.12,0.5)),"Original generous pickup collider "+label)
		check(stand.position.is_equal_approx(Vector3(-9,0.43,7)) and stand.get_child(0).shape.size.is_equal_approx(Vector3(1.4,0.8,1.0)),"Original stand collision envelope "+label)
		check(body.get_children().size()==2 and stand.get_children().size()==2,"Only one visual tree and original shape per body "+label)
		check(body.get_meta("supply_kind")==kind,"Pickup matches original credential semantics "+label)
		check(bounds(art).size.is_equal_approx(EXPECTED[kind].size),"Correct credential mesh in actual map "+label)
		check(is_equal_approx(art.global_position.y-stand_art.global_position.y,0.792),"Pickup sits on inset 0.792 m deck "+label)
		check(is_equal_approx(stand_art.position.y,-0.4) and stand_art.basis.is_equal_approx(Basis.IDENTITY),"Stand aligned to original ground/envelope "+label)
		check(body.visible and art.is_visible_in_tree() and not body.get_meta("collected",false),"Fresh pickup present "+label)
		var fields=body.get_parent().find_children("*","Label3D",false,false).filter(func(n):return n.text=="FIELD SUPPLIES")
		check(fields.size()==1,"Original field-supplies world label remains "+label)
		# Test the front approach against the actual world collision, then point at
		# both the old generous target centre and the small model on the deck.
		scene.player.global_position=body.global_position+Vector3(0,-0.82,2.0);scene.player.velocity=Vector3.ZERO
		for frame in 30:
			scene.player.step_motion(Vector3.ZERO,4.2,false,1.0/60.0);await physics_frame
		check(scene.player.is_on_floor(),"Standing approach has real terrain support "+label)
		var probe=PhysicsShapeQueryParameters3D.new();probe.shape=scene.player.standing_shape
		probe.transform=Transform3D(Basis.IDENTITY,scene.player.global_position+Vector3(0,0.92,0));probe.exclude=[scene.player.get_rid()]
		check(scene.get_world_3d().direct_space_state.intersect_shape(probe,1).is_empty(),"Clear front standing volume "+label)
		scene.player.camera.look_at(body.global_position)
		check(scene._nearest_target().get("node")==body,"Original target reachable with actual camera ray "+label)
		scene.player.camera.look_at(art.global_position+Vector3.UP*bounds(art).size.y*0.5)
		check(scene._nearest_target().get("node")==body,"Looking at small pickup selects generous collider "+label)
		# Existing lifecycle guards must prevent both collection and hiding.
		scene.returning=true;scene._interact(target);scene.returning=false
		check(body.visible and state_snapshot(scene.raid_state)==state_snapshot(oracle),"Returning guard leaves supply untouched "+label)
		scene.ready_for_play=false;scene._interact(target);scene.ready_for_play=true
		check(body.visible and state_snapshot(scene.raid_state)==state_snapshot(oracle),"Readiness guard leaves supply untouched "+label)
		scene.raid_state.extracted_at="test";scene._interact(target);scene.raid_state.extracted_at=""
		check(body.visible and state_snapshot(scene.raid_state)==state_snapshot(oracle),"Extracted guard leaves supply untouched "+label)
		var expected_message=oracle.collect(target.poi)
		scene._interact(scene._nearest_target())
		check(state_snapshot(scene.raid_state)==state_snapshot(oracle),"Collect preserves all credential, code and puzzle state semantics "+label)
		check(scene.toast.text==expected_message,"Exact original generated collection message "+label)
		check(not body.visible and not art.is_visible_in_tree() and body.get_meta("collected",false),"Acquired pickup vanishes immediately "+label)
		check(scene._nearest_target().get("node")!=body,"Consumed target cannot be selected again "+label)
		await physics_frame;await physics_frame
		check(body.get_child(0).disabled,"Consumed pickup collision disabled safely "+label)
		check(stand.visible and stand_art.is_visible_in_tree() and not stand.get_child(0).disabled,"Stand remains visible and solid "+label)
		var snapshot=state_snapshot(scene.raid_state);scene.toast.text="repeat sentinel"
		for repeat in 3:scene._interact(target)
		check(state_snapshot(scene.raid_state)==snapshot and scene.toast.text=="repeat sentinel","Stale/repeated interaction is idempotent "+label)
		if kind=="code":check(scene.raid_state.notes[target.poi.id]==scene.raid_state.code_for(target.poi.id),"Code comes from current seed, never baked asset text")
		for other in targets:
			if other.node!=body and not other.node.get_meta("collected",false):check(other.node.visible,"Independent uncollected supply remains present "+other.poi.id)
	check(seen.size()==4,"All four credential kinds used once "+path)
	scene._field_notes();var text=visible_text(scene.modal)
	for id in oracle.held:check(text.contains(id.replace("_"," ")),"Acquired key/card retained in field notes "+id)
	for id in oracle.notes:check(text.contains(oracle.notes[id]),"Generated code retained after visual removal "+id)
	for id in oracle.clues:check(text.contains(oracle.clues[id]),"Exact puzzle clue retained after visual removal "+id)
	scene._close_modal();scene.free();await preload("res://raid/tests/audio_shutdown.gd").drain(self)
	# Fresh raid instances must restore each pickup and discard previous kit.
	var fresh=load(path).instantiate();root.add_child(fresh)
	deadline=Time.get_ticks_msec()+60000
	while not fresh.is_raid_ready() and Time.get_ticks_msec()<deadline:await process_frame
	check(fresh.is_raid_ready(),"Fresh raid ready "+path)
	check(fresh.raid_state.held.is_empty() and fresh.raid_state.notes.is_empty() and fresh.raid_state.clues.is_empty(),"Fresh raid resets credentials and notes "+path)
	for item in fresh.targets.filter(func(t):return t.kind=="clue"):
		check(item.node.visible and not item.node.get_meta("collected",false) and not item.node.get_child(0).disabled,"Fresh raid restores pickup "+item.poi.id)
	fresh.free();await preload("res://raid/tests/audio_shutdown.gd").drain(self)
func run():
	verify_imports()
	await verify_map("res://raid/relay_ridge.tscn",false)
	await verify_map("res://raid/cinder_basin.tscn",true)
	print("FIELD_SUPPLIES_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"imports":imports,"rendered":false,"native_input":false}))
	quit(0 if failures.is_empty() else 1)
