extends SceneTree
var checks=0
var failures:Array=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():
	var zip=ZIPReader.new()
	check(zip.open("res://AUTHORING/ResearchAnnex/source/research_annex_final_b_models.zip")==OK,"original model archive readable")
	var bytes=zip.read_file("research_annex_assembled.glb");zip.close()
	var doc=GLTFDocument.new();var state=GLTFState.new();state.handle_binary_image=GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED
	check(doc.append_from_buffer(bytes,"",state)==OK,"original GLB parses via Godot")
	var source=doc.generate_scene(state)
	var runtime=load("res://raid/assets/research_annex/research_annex_runtime.scn").instantiate()
	root.add_child(source);root.add_child(runtime)
	var meshes=runtime.find_children("*","MeshInstance3D",true,false)
	check(meshes.size()==27,"all 27 source mesh objects retained")
	var triangles=0;var materials:Dictionary={};var textures=0
	for a in source.find_children("*","MeshInstance3D",true,false):
		var b=runtime.find_child(a.name,true,false)
		check(b!=null,"retained source mesh "+a.name)
		if b==null:continue
		check(a.transform==b.transform,"exact node transform "+a.name)
		check(a.mesh.get_surface_count()==b.mesh.get_surface_count(),"surface count "+a.name)
		for i in a.mesh.get_surface_count():
			check(a.mesh.surface_get_arrays(i)==b.mesh.surface_get_arrays(i),"exact geometry arrays "+a.name+"/"+str(i))
			triangles+=b.mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX].size()/3
			var original=a.get_active_material(i);var saved=b.get_active_material(i)
			if materials.has(original.resource_name):continue
			materials[original.resource_name]=true
			check(original.get_class()==saved.get_class(),"material class "+original.resource_name)
			for property in original.get_property_list():
				var key:String=property.name
				if property.usage & PROPERTY_USAGE_STORAGE==0 or key in ["resource_path","resource_scene_unique_id"]:continue
				var va=original.get(key);var vb=saved.get(key)
				if va is Texture2D:
					textures+=1
					check(vb is Texture2D and va.get_image().get_data()==vb.get_image().get_data(),"exact decoded texture bytes "+original.resource_name+"/"+key)
				else:check(va==vb,"material property "+original.resource_name+"/"+key)
	# The actual delivered GLB has 284 coping triangles, not the report's 288.
	# Exact source/runtime array equality above proves this is not import loss.
	check(triangles==15406,"actual delivered GLB 15406 triangles retained before gameplay door removal")
	check(materials.size()==14 and textures>=44,"all 14 materials and textured channels retained")
	check(ResourceLoader.get_dependencies("res://raid/assets/research_annex/research_annex_runtime.scn").is_empty(),"native scene has no external/cache dependencies")
	for node in [runtime]+runtime.find_children("*","Node",true,false):check(node.get_script()==null,"asset carries no scripts "+node.name)
	for type in ["CollisionObject3D","AnimationPlayer","Camera3D","Light3D"]:check(runtime.find_children("*",type,true,false).is_empty(),"no accidental imported "+type)
	print("RESEARCH_ANNEX_ASSET_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"triangles":triangles,"materials":materials.size(),"texture_slots":textures,"rendered":false}))
	source.free();runtime.free();quit(0 if failures.is_empty() else 1)
