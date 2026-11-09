extends RefCounted
# Original editable code-native furniture. Each visible solid has matching collision.
const Finish = preload("res://scripts/build_piece_materials.gd")
static func parts(kind: String) -> Array:
	if kind == "bed": return preload("res://scripts/bed_geometry.gd").parts()
	if kind == "workbench":
		var result=[{"position":Vector3(0,0.81,0.40),"size":Vector3(1.1,0.08,0.55),"bronze":false,"axis":0}]
		for x in [-0.46,0.46]:
			for z in [0.20,0.60]: result.append({"position":Vector3(x,0.385,z),"size":Vector3(0.08,0.77,0.08),"bronze":true,"axis":1})
		result.append({"position":Vector3(0,0.25,0.40),"size":Vector3(0.98,0.05,0.42),"bronze":false,"axis":0})
		return result
	var result=[{"position":Vector3(0.45,0.04,0.45),"size":Vector3(0.25,0.08,0.25),"bronze":true,"axis":1},
		{"position":Vector3(0.45,0.38,0.45),"size":Vector3(0.07,0.60,0.07),"bronze":true,"axis":1},
		{"position":Vector3(0.45,0.88,0.45),"size":Vector3(0.25,0.06,0.25),"bronze":true,"axis":0},
		{"position":Vector3(0.45,0.64,0.45),"size":Vector3(0.25,0.05,0.25),"bronze":true,"axis":0}]
	for x in [0.35,0.55]:
		for z in [0.35,0.55]: result.append({"position":Vector3(x,0.76,z),"size":Vector3(0.025,0.22,0.025),"bronze":true,"axis":1})
	result.append({"position":Vector3(0.45,0.755,0.45),"size":Vector3(0.13,0.15,0.13),"bronze":false,"axis":1,"glow":true})
	return result
static func assembly(kind: String, collision := false, record := {}) -> Node3D:
	var root=Node3D.new();root.name="Workbench" if kind=="workbench" else "Bed" if kind=="bed" else "Lantern"
	if kind=="bed":
		var model=load("res://assets/starter_bed.glb").instantiate();model.rotation.y=PI/2;root.add_child(model)
	for part in parts(kind):
		var node=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=part.size;node.mesh=mesh;node.position=part.position
		if kind != "bed": Finish.apply_box(node,part.bronze,part.axis)
		if part.get("glow",false):
			var mat=StandardMaterial3D.new();mat.albedo_color=Color("e6b16d");mat.emission_enabled=record.get("on",true);mat.emission=Color("ffc984");mat.emission_energy_multiplier=1.2;node.material_override=mat
		if kind != "bed": root.add_child(node)
		else: node.free()
		if collision:
			var body=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=part.size;shape.shape=box;body.add_child(shape);body.position=part.position
			body.set_meta("build_furniture",{"kind":kind,"cell":record.cell,"rotation":record.rotation,"level":record.get("level",0)})
			body.set_meta("build_cell",record.cell);body.set_meta("build_level",record.get("level",0));root.add_child(body)
	if kind=="lantern" and collision:
		var light=OmniLight3D.new();light.position=Vector3(0.45,0.755,0.45);light.light_color=Color("ffd5a0");light.light_energy=1.1;light.omni_range=3.5;light.shadow_enabled=false;light.visible=record.get("on",true);root.add_child(light)
	return root
