extends RefCounted
const BuildPieceMaterials = preload("res://scripts/build_piece_materials.gd")
# Original short timber/bronze deck railing. All visible solids have exact box collision.
# Ends remain 0.12m inside the tile so perpendicular pieces never overlap at corners.
static func parts() -> Array:
	return [
		{"position":Vector3(-0.83,0.50,0),"size":Vector3(0.10,1.0,0.10),"bronze":true},
		{"position":Vector3(0.83,0.50,0),"size":Vector3(0.10,1.0,0.10),"bronze":true},
		{"position":Vector3(0,0.95,0),"size":Vector3(1.76,0.10,0.10),"bronze":false},
		{"position":Vector3(0,0.13,0),"size":Vector3(1.66,0.10,0.08),"bronze":true},
		{"position":Vector3(0,0.51,0),"size":Vector3(1.6,0.64,0.07),"bronze":false}]
static func assembly(solid := false, cell := Vector2i.ZERO, side := 0) -> Node3D:
	var root=Node3D.new()
	for part in parts():
		var mesh=MeshInstance3D.new();var box=BoxMesh.new();box.size=part.size;mesh.mesh=box
		mesh.position=part.position
		BuildPieceMaterials.apply_box(mesh, part.bronze, 0)
		root.add_child(mesh)
		if solid:
			var body=StaticBody3D.new();var shape=CollisionShape3D.new();var boxshape=BoxShape3D.new();boxshape.size=part.size;shape.shape=boxshape
			body.position=part.position;body.add_child(shape);root.add_child(body)
			body.set_meta("build_cell",cell);body.set_meta("build_railing",{"cell":cell,"rotation":side})
	return root
