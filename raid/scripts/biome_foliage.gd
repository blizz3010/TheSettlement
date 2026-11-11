extends RefCounted
## Appearance has a separate version and position hash; placement RNG never changes.
const Meshes=preload("res://raid/scripts/vegetation_meshes.gd")
const APPEARANCE_VERSION=1
const LAYERS=["tree","grass","shrub","rock"]
const RELAY={"tree":["ridgeback_pine","lanternleaf_oak","silverbark_birch"],"grass":["ridge_meadow_grass","glowfern"],"shrub":["amberberry_thicket"],"rock":["ridge_stone"]}
const CINDER={"tree":["cinder_juniper","salt_yucca"],"grass":["salt_samphire_mat"],"shrub":["glassplume_shrub","bonebrush","ember_agave"],"rock":["basalt_rock"]}
static func species_for(biome:String,kind:String,item:Dictionary,seed_value:int)->String:
	var species:Array=(RELAY if biome=="relay" else CINDER)[kind]
	# Stable integer arithmetic, independent of iteration/density, no global RNG.
	var code=posmod(roundi(item.position.x*100)*73856093+roundi(item.position.z*100)*19349663+seed_value*83492791,100)
	if biome=="relay" and kind=="grass":return species[0 if code<78 else 1]
	if biome=="relay" and kind=="tree":return species[0 if code<38 else 1 if code<72 else 2]
	if biome=="cinder" and kind=="tree":return species[0 if code<65 else 1]
	return species[code%species.size()]
func build(parent:Node3D,generator,biome:String)->Dictionary:
	assert(biome in ["relay","cinder"])
	var counts={"ok":true,"biome":"woodland" if biome=="relay" else "salt_and_basalt","appearance_version":APPEARANCE_VERSION,"species":{},"batches":0,"mesh_triangles":{},"submitted_triangles":0}
	var library=Meshes.new();var material=Meshes.material();var meshes={}
	for kind in LAYERS:
		var placements:Array=generator.placements(kind);counts[kind]=placements.size();var groups={}
		for item in placements:
			var species=species_for(biome,kind,item,generator.config.map_seed)
			counts.species[species]=counts.species.get(species,0)+1
			if not meshes.has(species):
				meshes[species]=library.build(species)
				counts.mesh_triangles[species]=meshes[species].surface_get_array_len(0)/3
			var chunk=Vector2i(floori(item.position.x/32.0),floori(item.position.z/32.0))
			var key="%s_%d_%d"%[species,chunk.x,chunk.y]
			if not groups.has(key):groups[key]={"species":species,"items":[]}
			groups[key].items.append(item)
		for key in groups:
			var group:Dictionary=groups[key];var mesh:ArrayMesh=meshes[group.species];var bounds=mesh.get_aabb()
			var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=group.items.size()
			var aabb=AABB();var first=true;var recorded=[]
			for index in group.items.size():
				var item:Dictionary=group.items[index]
				var transform=Transform3D(Basis(Vector3.UP,item.yaw).scaled(Vector3.ONE*item.scale),item.position)
				mm.set_instance_transform(index,transform);recorded.append(transform)
				var item_bounds=transform*bounds;aabb=item_bounds if first else aabb.merge(item_bounds);first=false
			mm.custom_aabb=aabb.grow(0.5)
			var batch=MultiMeshInstance3D.new();batch.name=key;batch.multimesh=mm;batch.material_override=material
			batch.visibility_range_end=75.0 if kind=="grass" else 140.0 if kind=="shrub" else 245.0
			if kind=="grass":batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.set_meta("source_transforms",recorded);batch.set_meta("species",group.species);batch.set_meta("layer",kind)
			parent.add_child(batch);counts.batches+=1;counts.submitted_triangles+=counts.mesh_triangles[group.species]*group.items.size()
		if kind in ["tree","rock"]:
			for item in placements:
				# Keep the previous trunk/rock collision envelope exactly, so art cannot
				# silently alter tested route physics. Crowns/undergrowth are decoration.
				var body=StaticBody3D.new();body.position=item.position
				body.set_meta("audio_surface","wood" if kind=="tree" else "stone");body.set_meta("foliage_layer",kind)
				var cylinder=CylinderShape3D.new()
				cylinder.height=((2.8 if kind=="tree" else 1.15) if biome=="relay" else (4.8 if kind=="tree" else 1.35))*item.scale
				cylinder.radius=((0.43 if kind=="tree" else 0.7) if biome=="relay" else (0.95 if kind=="tree" else 1.05))*item.scale
				var shape=CollisionShape3D.new();shape.shape=cylinder;shape.position.y=cylinder.height/2.0
				body.add_child(shape);parent.add_child(body)
	return counts
