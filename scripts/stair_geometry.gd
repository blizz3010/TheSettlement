extends RefCounted
const BuildPieceMaterials = preload("res://scripts/build_piece_materials.gd")
# Original code-native timber stair kit. Every visible solid has the same box collision.
const RISE = 3.18
const RUN = 4.0
const WIDTH = 1.46
const COUNT = 18
static func step_height(index: int) -> float:
	# Low entrance tread: ground + foundation + tread is at most 0.315m, below 0.32m step-up.
	return 0.005+float(index)*(RISE-0.005)/float(COUNT-1)
static func parts() -> Array:
	var result: Array = []
	for i in range(COUNT):
		var height = step_height(i)
		result.append({"position":Vector3(0,height/2,1-(i+0.5)*RUN/COUNT),"size":Vector3(WIDTH,height,RUN/COUNT),"rotation":0.0,"bronze":false})
	for side in [-1,1]:
		for i in [0,4,8,12,COUNT]:
			var y = float(i)*RISE/COUNT
			var bottom = step_height(i-1) if i>0 else 0.0
			var top = y+0.96
			result.append({"position":Vector3(side*0.68,(bottom+top)/2.0,clampf(1-float(i)*RUN/COUNT,-2.94,0.94)),"size":Vector3(0.10,top-bottom,0.10),"rotation":0.0,"bronze":true})
		result.append({"position":Vector3(side*0.68,RISE/2+0.94,-1),"size":Vector3(0.10,0.10,sqrt(3.88*3.88+RISE*RISE)),"rotation":atan2(RISE,3.88),"bronze":false})
	return result
static func assembly(solid := false, cell := Vector2i.ZERO) -> Node3D:
	var root=Node3D.new()
	for part in parts():
		var mesh=MeshInstance3D.new();var box=BoxMesh.new();box.size=part.size;mesh.mesh=box
		mesh.position=part.position;mesh.rotation.x=part.rotation
		BuildPieceMaterials.apply_box(mesh, part.bronze, 2 if part.rotation != 0.0 else 0)
		root.add_child(mesh)
		if solid:
			var body=StaticBody3D.new();var shape=CollisionShape3D.new();var boxshape=BoxShape3D.new();boxshape.size=part.size;shape.shape=boxshape
			body.position=part.position;body.rotation.x=part.rotation;body.add_child(shape);root.add_child(body)
			body.set_meta("audio_surface","metal" if part.bronze else "wood");body.set_meta("build_cell",cell);body.set_meta("build_stairs",true)
	return root
