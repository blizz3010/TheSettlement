extends SceneTree
const Meshes=preload("res://raid/scripts/vegetation_meshes.gd")
const Foliage=preload("res://raid/scripts/biome_foliage.gd")
var checks=0
var failures=[]
var summaries={}
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func run():
	var library=Meshes.new();var fingerprints={};var geometry_export={}
	library._tube(Vector3.ZERO,Vector3.UP,0.5,0.4,Color.WHITE,6)
	var outward=true
	for index in range(0,library.vertices.size(),3):
		var center=(library.vertices[index]+library.vertices[index+1]+library.vertices[index+2])/3.0
		var normal=library.normals[index]
		if absf(normal.y)<0.99:outward=outward and Vector3(center.x,0,center.z).dot(normal)>0
	check(outward,"tapered branches have outward-facing surface normals")
	for species in Meshes.SPECIES:
		var mesh=library.build(species);var arrays=mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		var valid=true;var mesh_points=[]
		for index in vertices.size():
			valid=valid and vertices[index].is_finite() and normals[index].is_finite() and absf(normals[index].length()-1.0)<0.001
			mesh_points.append([vertices[index].x,vertices[index].y,vertices[index].z,colors[index].r,colors[index].g,colors[index].b,colors[index].a])
		check(mesh.get_surface_count()==1 and vertices.size()>0 and vertices.size()%3==0 and vertices.size()<=12000,species+": bounded single-surface triangle mesh")
		check(valid and vertices.size()==normals.size() and vertices.size()==colors.size(),species+": finite vertices and unit normals")
		check(absf(mesh.get_aabb().position.y)<0.001 and absf(mesh.get_aabb().size.y-Meshes.SPECIES[species].height)<0.001,species+": grounded at explicit nominal height")
		check(mesh.get_aabb().size.x>0.05 and mesh.get_aabb().size.z>0.05,species+": full three-dimensional geometry")
		var fingerprint=hash(vertices)
		check(fingerprint==hash(library.build(species).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]),species+": mesh is repeatable")
		check(not fingerprints.has(fingerprint),species+": distinct vertex geometry from every other species")
		fingerprints[fingerprint]=species;geometry_export[species]=mesh_points
	for biome in ["relay","cinder"]:
		var config=load("res://raid/"+biome+"_settings.tres").duplicate()
		var generator=load("res://raid/scripts/"+biome+"_generator.gd").new(config)
		var host=Node3D.new();root.add_child(host)
		var summary=Foliage.new().build(host,generator,biome);summaries[biome]=summary
		var expected=Foliage.RELAY if biome=="relay" else Foliage.CINDER
		check(summary.ok and summary.appearance_version==1,biome+": build succeeds with independent appearance version")
		check(summary.batches<=700 and summary.submitted_triangles<5000000,biome+": bounded default batching and geometry, not measured FPS")
		var counted={};var collider_count=0;var valid_bounds=true;var valid_transforms=true;var valid_rendering=true;var colliders_match=true
		var previous_trees=[];var allowed_by_species={};var items_by_layer={};var submitted_counts={};var material_reference:Material=null
		for kind in Foliage.LAYERS:
			var items:Array=generator.placements(kind);items_by_layer[kind]={}
			check(summary[kind]==items.size(),biome+": original "+kind+" count preserved")
			for item in items:
				var species=Foliage.species_for(biome,kind,item,config.map_seed)
				items_by_layer[kind][item.position]=item
				if not allowed_by_species.has(species):allowed_by_species[species]={}
				allowed_by_species[species][item.position]=Transform3D(Basis(Vector3.UP,item.yaw).scaled(Vector3.ONE*item.scale),item.position)
				if kind=="tree":previous_trees.append(species)
				counted[species]=counted.get(species,0)+1
			check(expected[kind].all(func(name):return summary.species.get(name,0)>0),biome+": every intended "+kind+" species appears at default seed")
		for child in host.get_children():
			if child is MultiMeshInstance3D:
				var mm:MultiMesh=child.multimesh;var bounds=mm.mesh.get_aabb();var species:String=child.get_meta("species");var layer:String=child.get_meta("layer")
				var data:Array=child.get_meta("source_transforms");var allowed:Dictionary=allowed_by_species[species]
				submitted_counts[species]=submitted_counts.get(species,0)+mm.instance_count
				if material_reference==null:material_reference=child.material_override
				valid_rendering=valid_rendering and child.material_override is ShaderMaterial and child.material_override==material_reference and child.visibility_range_end>0
				valid_rendering=valid_rendering and not child.material_override.shader.code.contains("ALPHA")
				if data.size()!=mm.instance_count:valid_transforms=false;continue
				if layer=="grass":valid_rendering=valid_rendering and child.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				for index in mm.instance_count:
					# Headless Dummy renderer returns identity for GPU instance readback.
					# Validate the exact transforms passed to MultiMesh, not unrendered pixels.
					var transform:Transform3D=data[index]
					valid_bounds=valid_bounds and mm.custom_aabb.encloses(transform*bounds)
					# Verify recorded submission data against untouched generator placements.
					valid_transforms=valid_transforms and data.size()==mm.instance_count and allowed.has(data[index].origin) and allowed[data[index].origin].is_equal_approx(data[index])
					valid_transforms=allowed.erase(data[index].origin) and valid_transforms
			elif child is StaticBody3D:
				collider_count+=1
				var layer=child.get_meta("foliage_layer")
				if not items_by_layer[layer].has(child.position):colliders_match=false;continue
				var item:Dictionary=items_by_layer[layer][child.position]
				items_by_layer[layer].erase(child.position)
				var cylinder:CylinderShape3D=child.get_child(0).shape
				var height=((2.8 if layer=="tree" else 1.15) if biome=="relay" else (4.8 if layer=="tree" else 1.35))*item.scale
				var radius=((0.43 if layer=="tree" else 0.7) if biome=="relay" else (0.95 if layer=="tree" else 1.05))*item.scale
				colliders_match=colliders_match and is_equal_approx(cylinder.height,height) and is_equal_approx(cylinder.radius,radius) and is_equal_approx(child.get_child(0).position.y,height/2.0)
		check(counted==summary.species,biome+": exactly one species per original placement")
		check(submitted_counts==summary.species and allowed_by_species.values().all(func(items):return items.is_empty()),biome+": submitted placement multiset has no duplicates or omissions")
		check(items_by_layer.tree.is_empty() and items_by_layer.rock.is_empty(),biome+": collider placement multiset has no duplicates or omissions")
		check(valid_bounds,biome+": every submitted instance inside explicit culling AABB")
		check(valid_transforms,biome+": submitted positions, yaw and scale preserved without extra transforms")
		check(valid_rendering,biome+": declared shared opaque shader, culling and grass shadow policy")
		check(collider_count==summary.tree+summary.rock and colliders_match,biome+": exact original physical envelopes, no new undergrowth collision")
		config.grass_density=0.0
		var reduced=load("res://raid/scripts/"+biome+"_generator.gd").new(config);var current_trees=[]
		for item in reduced.placements("tree"):current_trees.append(Foliage.species_for(biome,"tree",item,config.map_seed))
		check(previous_trees==current_trees,biome+": grass density never changes tree species")
		for kind in Foliage.LAYERS:config.set(kind+"_density",0.0)
		var empty=Node3D.new();root.add_child(empty)
		var empty_result=Foliage.new().build(empty,load("res://raid/scripts/"+biome+"_generator.gd").new(config),biome)
		check(empty_result.ok and empty_result.batches==0 and empty_result.species.is_empty() and empty.get_child_count()==0,biome+": zero density creates no visual or physical leftovers")
		host.free();empty.free()
	var export_path=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--geometry-output="):export_path=argument.trim_prefix("--geometry-output=")
	if not export_path.is_empty():
		var file=FileAccess.open(export_path,FileAccess.WRITE)
		if file:file.store_string(JSON.stringify(geometry_export))
	print("BIOME_VEGETATION_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"maps":summaries,"rendered_acceptance":false,"performance_acceptance":false}))
	await process_frame;quit(0 if failures.is_empty() else 1)
