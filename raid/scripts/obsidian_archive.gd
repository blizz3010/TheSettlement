extends RefCounted
## Imported public archive, with one raid-owned secure vault. No state/config edits.
const MODEL=preload("res://raid/assets/obsidian/obsidian_archive_v21.glb")
const DOOR_POSITION=Vector3(0,9.75,-8)
const CACHE_POSITION=Vector3(0,9,-10.5)
const SUPPLY_OFFSET=Vector3(0,0,12)

func build(world:Node3D,root:Node3D,poi:Dictionary):
	var art=MODEL.instantiate();art.name="ObsidianLandmark";root.add_child(art)
	_prepare(art)
	root.set_meta("archive_version","2.1")
	# Ordinary doors are visibly absent, not invisible closed colliders. The
	# imported vault leaf was partly open; replace it with a genuine shut gate.
	var door=world._box(root,DOOR_POSITION,Vector3(1.6,2.5,0.24),Color("567b96"))
	door.name="SecureVaultDoor"
	world.door_nodes[poi.id]=door;world._target("door",door,poi)
	var supplies=Node3D.new();supplies.name="ArchiveFieldSupplies";supplies.position=SUPPLY_OFFSET;root.add_child(supplies)
	world._build_field_supplies(supplies,poi)
	world._label(supplies,"FIELD SUPPLIES",Vector3(-9,1.6,7),Color("f0dcae"),19)
	var cache=world._build_cache(root,CACHE_POSITION);cache.name="SecureVaultCache";world._target("cache",cache,poi)
	world._label(root,"PUBLIC ARCHIVE / VAULT ON LEVEL 3",Vector3(0,3.25,16.1),poi.theme,24)
	world._label(root,"LEVEL 3 / KEYCARD VAULT",Vector3(0,11.4,-7.7),poi.theme,20)
	preload("res://raid/scripts/archive_wayfinding.gd").new().build(world,root)

func _prepare(node:Node):
	for child in node.get_children():
		var label=String(child.name)
		# Presentation ground/rocks and figures are not game-world geometry.
		if label=="Reader_Main" or label.begins_with("Site_") or label.begins_with("Figure") or (label.begins_with("Door_") and not label.ends_with("_Frame")):
			node.remove_child(child);child.free();continue
		if child is MeshInstance3D and child.mesh:
			var body=StaticBody3D.new();body.name="ArchiveCollision"
			var shape=CollisionShape3D.new();shape.shape=child.mesh.create_trimesh_shape()
			body.add_child(shape);child.add_child(body)
		_prepare(child)
