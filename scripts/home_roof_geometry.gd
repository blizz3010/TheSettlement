extends RefCounted
## First-kit terminal covers. Local X/Z envelope remains strictly inside one tile.
## Existing flat roof is deliberately NOT replaced by this geometry.
const Materials = preload("res://scripts/build_piece_materials.gd")
static func parts(kind: String) -> Array:
	var result: Array = []
	var rise = 0.88 if kind == "pitched_roof" else 0.30
	var slope = atan(rise/1.80)
	var length = sqrt(1.80*1.80+rise*rise)
	# Rust canvas over a timber half-pitch frame; the shallower awning has a soft sag.
	for i in range(8):
		var t = (i+0.5)/8.0
		var sag = sin(t*PI)*0.055 if kind == "canvas_awning" else 0.0
		result.append({"position":Vector3(0,0.13+rise*t-sag,-0.90+1.80*t),"size":Vector3(1.80,0.035,length/8.0+0.008),"angle":-slope,"surface":"canvas"})
	for x in [-0.94,0.94]:
		result.append({"position":Vector3(x,0.10+rise/2,0),"size":Vector3(0.08,0.10,length),"angle":-slope,"surface":"timber"})
	for z in [-0.90,0.90]:
		var y = 0.10+(rise if z>0 else 0.0)
		result.append({"position":Vector3(0,y,z),"size":Vector3(1.96,0.10,0.10),"angle":0.0,"surface":"timber"})
		for x in [-0.93,0.93]:
			result.append({"position":Vector3(x,y+0.005,z),"size":Vector3(0.10,0.115,0.115),"angle":0.0,"surface":"metal"})
	return result
static func assembly(kind: String) -> Node3D:
	var root = Node3D.new()
	root.name = "PitchedRoofHalf" if kind == "pitched_roof" else "CanvasAwning"
	for part in parts(kind):
		var node = MeshInstance3D.new()
		var mesh = BoxMesh.new(); mesh.size = part.size
		node.mesh = mesh; node.position = part.position; node.rotation.x = part.angle
		if part.surface == "canvas":
			var material = StandardMaterial3D.new()
			material.albedo_color = Color("ad623e")
			material.roughness = 0.94
			node.material_override = material
		else: Materials.apply_box(node,part.surface == "metal",2 if part.size.z > part.size.x else 0)
		root.add_child(node)
	return root
static func envelope(kind: String, side: int) -> AABB:
	var result = AABB()
	var started = false
	var basis = Basis(Vector3.UP,-side*PI/2)
	for part in parts(kind):
		var transform = Transform3D(basis*Basis(Vector3.RIGHT,part.angle),basis*part.position)
		var bounds = transform*AABB(-part.size/2,part.size)
		result = result.merge(bounds) if started else bounds
		started = true
	return result
