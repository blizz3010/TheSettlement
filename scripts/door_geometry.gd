extends RefCounted
# Original small prototype leaf: timber panel with bronze straps, paired with existing frame.
const HINGE = Vector3(-0.5,0,0.18) # Surface-mounted inward: leaf clears its fixed jambs throughout swing.
const CENTER = Vector3(0.5,1.37,0)
const SIZE = Vector3(0.98,2.68,0.16)
static func pose(opened: bool) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,-PI/2 if opened else 0.0),HINGE)
static func material(color: String, metal := false) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color=Color(color);m.roughness=0.72;m.metallic=0.65 if metal else 0.0
	return m
static func block(parent: Node3D, pos: Vector3, size: Vector3, mat: Material):
	var n=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=size;n.mesh=mesh
	n.position=pos;n.material_override=mat;parent.add_child(n)
static func visual() -> Node3D:
	var root=Node3D.new()
	var timber=material("765239");var bronze=material("695441",true)
	for i in range(5): block(root,Vector3(0.108+i*0.196,1.37,0),Vector3(0.188,2.68,0.12),timber)
	for y in [0.34,2.40]: block(root,Vector3(0.5,y,0),Vector3(0.98,0.14,0.15),bronze)
	for z in [-0.072,0.072]: block(root,Vector3(0.85,1.30,z),Vector3(0.08,0.22,0.014),bronze)
	return root

static func assembly(opened: bool) -> Node3D:
	var root=Node3D.new()
	var leaf=visual();leaf.name="Leaf";leaf.transform=pose(opened);root.add_child(leaf)
	# Narrow inset jambs provide actual side-wall clearance while retaining the existing frame.
	for x in [-0.635,0.635]: block(root,Vector3(x,1.37,0),Vector3(0.27,2.68,0.18),material("695441",true))
	return root
