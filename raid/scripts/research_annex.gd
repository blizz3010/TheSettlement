extends RefCounted
## User-supplied final_b architecture. Existing raid keycard/cache state is unchanged.
const MODEL=preload("res://raid/assets/research_annex/research_annex_runtime.scn")
const DOOR_POSITION=Vector3(12.95,5.35,-5.7)
const CACHE_POSITION=Vector3(13,4.7,-8.2)
const CARD_POSITION=Vector3(14.8,5.197,-4.4)

func build(world:Node3D,root:Node3D,poi:Dictionary):
	# Separate apron from the coplanar terrain without an unwalkable foundation.
	root.position.y+=0.04
	var art=MODEL.instantiate();art.name="ResearchAnnexLandmark";root.add_child(art)
	var leaf=art.find_child("Door_Secure",true,false)
	assert(leaf is MeshInstance3D)
	var door=StaticBody3D.new();door.name="SecureResearchDoor";door.position=DOOR_POSITION;root.add_child(door)
	leaf.reparent(door)
	# The source leaf is posed 80 degrees open for presentation. Close its hinge
	# before generating collision so the actual keycard gate cannot be bypassed.
	leaf.rotation=Vector3.ZERO
	var shape=CollisionShape3D.new();shape.shape=leaf.mesh.create_trimesh_shape();shape.transform=leaf.transform;door.add_child(shape)
	_prepare(art)
	world.door_nodes[poi.id]=door;world._target("door",door,poi)
	# The supplied upper corridor already contains a solid 0.92 m pedestal.
	# Reuse it rather than overlapping it with the generic outdoor supply stand.
	var card=world._prop_body(root,CARD_POSITION,Vector3(0.7,0.12,0.5));card.name="AnnexKeycardPickup"
	world.FieldSupplies.attach_pickup(card,poi.lock,false)
	world._target("clue",card,poi)
	world._label(root,"FIELD SUPPLIES",Vector3(14.8,6,-4.4),Color("d7ddc0"),17)
	var cache=world._build_cache(root,CACHE_POSITION);cache.name="SecureResearchCache";world._target("cache",cache,poi)
	world._label(root,"RESEARCH ANNEX / PUBLIC ENTRY",Vector3(-1,3.1,14),poi.theme,27)
	world._label(root,"UPPER FLOOR / KEYCARD RESEARCH",Vector3(12.95,6.9,-5.4),poi.theme,18)
	root.set_meta("annex_version","final_b")
	root.set_meta("ordinary_doors_removed",7)

func _prepare(node:Node):
	for child in node.get_children():
		var label=String(child.name)
		# Open ordinary routes have no closed invisible panels. Frames and all glass
		# remain physical. Markers are reference coordinates, not extra game loot.
		if label.begins_with("Door_") and not label.ends_with("_Frame"):
			node.remove_child(child);child.free();continue
		if child is MeshInstance3D and child.mesh:
			var body=StaticBody3D.new();body.name="AnnexCollision"
			var shape=CollisionShape3D.new();shape.shape=child.mesh.create_trimesh_shape()
			body.add_child(shape);child.add_child(body)
		_prepare(child)
