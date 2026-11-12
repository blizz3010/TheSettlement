extends RefCounted
## Original procedural art only. Existing room/collision/targets remain authoritative.
## Upper works are deliberately inaccessible: no ladder, stairs or decorative collider.
var batches:Dictionary={}
var materials:Dictionary={}
var counts:Dictionary={}

func build(parent:Node3D)->Node3D:
	batches.clear();materials.clear();counts.clear()
	var root=Node3D.new();root.name="RelayLandmark";parent.add_child(root)
	for entry in [["steel","777b68"],["rust","715142"],["dark","303b38"],["wood","626d60"],["pale","929681"],["lamp","ffc478"],["glass","8c784d"]]:
		var mat=StandardMaterial3D.new();mat.albedo_color=Color(entry[1]);mat.roughness=0.92
		if entry[0] in ["steel","dark"]:mat.metallic=0.45
		if entry[0]=="lamp":mat.emission_enabled=true;mat.emission=Color("ffb54e");mat.emission_energy_multiplier=1.6
		materials[entry[0]]=mat
	# Roof-mounted frame stays wholly above the original occupied room.
	var levels=[4.08,7.1,10.2,13.3,16.4,19.5,22.6,25.7]
	for corner in 4:
		var a=_corner(corner,levels[0]);var b=_corner(corner,levels[-1])
		_beam("Lattice","steel",a,b,0.26)
		_box("Lattice","rust",a+Vector3(0,0.12,0),Vector3(0.65,0.24,0.65))
	for level in levels.size():
		for side in 4:
			var a=_corner(side,levels[level]);var b=_corner((side+1)%4,levels[level])
			_beam("Lattice","steel",a,b,0.19)
			_box("Lattice","rust",a,Vector3(0.39,0.35,0.39))
			if level<levels.size()-1:
				_beam("Lattice","steel",a,_corner((side+1)%4,levels[level+1]),0.13)
				_beam("Lattice","steel",b,_corner(side,levels[level+1]),0.13)
	_box("Platform","dark",Vector3(0,25.85,-0.8),Vector3(4.9,0.28,4.9))
	for side in 4:
		var a=_corner(side,25.7)*Vector3(1.3,1,1)+Vector3(0,0,0.24)
		var b=_corner((side+1)%4,25.7)*Vector3(1.3,1,1)+Vector3(0,0,0.24)
		for step in 3:
			var p=a.lerp(b,step/2.0);_beam("Platform","steel",p,p+Vector3(0,1.55,0),0.09)
		for height in [0.7,1.5]:_beam("Platform","steel",a+Vector3(0,height,0),b+Vector3(0,height,0),0.08)
	for side in [-1.0,1.0]:
		var mast=Vector3(side*1.75,26,-0.8)
		_beam("Equipment","dark",mast,mast+Vector3(0,3.6,0),0.14)
		_dish(mast+Vector3(side*0.42,2.3,0),side)
		_box("Equipment","dark",mast+Vector3(0,3.65,0),Vector3(0.3,0.16,0.3))
		_box("Equipment","lamp",mast+Vector3(0,3.9,0),Vector3(0.17,0.36,0.17))
	_box("Equipment","steel",Vector3(0,26.6,-0.8),Vector3(0.9,1.25,0.7))
	for x in [-0.26,0.0,0.26]:_beam("Equipment","dark",Vector3(x,26.2,-0.43),Vector3(x,27,-0.43),0.04)
	# Twin suspended service cables terminate at the roof junction, never across a path.
	for offset in [0.0,0.16]:
		var points=[Vector3(1.9+offset,28,-1),Vector3(2.65+offset,23,-1),Vector3(2.9+offset,15,-1),Vector3(3.55+offset,8,-1),Vector3(4.4+offset,5.2,-1)]
		for i in points.size()-1:_beam("Cables","dark",points[i],points[i+1],0.045)
	_box("Hut","dark",Vector3(4.5,4.8,-1),Vector3(0.8,1.3,0.7))
	_box("Hut","pale",Vector3(4.5,5.5,-1),Vector3(1.05,0.15,0.95))
	# Weathered vertical cladding stays outside the original walls and clear of the door.
	for i in 25:
		var x=-5.85+i*0.4875
		if absf(x)>1.5:
			_box("Hut","wood" if i%3 else "pale",Vector3(x,1.88,5.18),Vector3(0.075,3.6,0.07))
		_box("Hut","wood" if i%3 else "pale",Vector3(x,1.88,-5.18),Vector3(0.075,3.6,0.07))
	for side in [-1.0,1.0]:
		for i in 21:
			_box("Hut","wood" if i%4 else "rust",Vector3(side*6.18,1.88,-4.85+i*0.485),Vector3(0.07,3.6,0.075))
		# Sloped roof cap above, not replacing, the original ceiling collision.
		_box("Roof","dark",Vector3(side*3.2,4.65,0),Vector3(6.6,0.13,10.7),Basis(Vector3.BACK,side*-0.19))
		for z in 16:
			_beam("Roof","steel",Vector3(0,5.3,-5.2+z*0.69),Vector3(side*6.4,4.08,-5.2+z*0.69),0.055)
		_window(Vector3(side*3.8,2.1,5.25))
	for side in [-1.0,1.0]:
		var gable=SurfaceTool.new();gable.begin(Mesh.PRIMITIVE_TRIANGLES)
		var vertices=[Vector3(-6.4,4.02,side*5.18),Vector3(6.4,4.02,side*5.18),Vector3(0,5.3,side*5.18)]
		for index in ([0,1,2] if side>0 else [2,1,0]):gable.add_vertex(vertices[index])
		gable.generate_normals();_part("Roof","wood",gable.commit(),Transform3D.IDENTITY)
	_beam("Roof","steel",Vector3(0,5.3,-5.38),Vector3(0,5.3,5.38),0.16)
	_box("Hut","dark",Vector3(0,3.54,5.33),Vector3(0.55,0.33,0.3))
	_box("Hut","lamp",Vector3(0,3.48,5.51),Vector3(0.32,0.2,0.08))
	for x in [-1.35,1.35]:_box("Hut","steel",Vector3(x,1.4,5.2),Vector3(0.08,2.8,0.1))
	for key in batches:
		var parts=String(key).split("/")
		var group=root.get_node_or_null(NodePath(parts[0]))
		if group==null:group=Node3D.new();group.name=parts[0];root.add_child(group)
		var art=MeshInstance3D.new();art.name=parts[1];art.mesh=batches[key].commit();art.material_override=materials[parts[1]];group.add_child(art)
	root.set_meta("parts",counts.duplicate());root.set_meta("visual_only",true)
	return root

func _corner(index:int,y:float)->Vector3:
	var half=lerpf(3.0,1.8,(y-4.08)/(25.7-4.08))
	return Vector3([-1,1,1,-1][index]*half,y,[-1,-1,1,1][index]*half-0.8)
func _part(group:String,material:String,mesh:Mesh,transform:Transform3D):
	var key=group+"/"+material
	if not batches.has(key):
		var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);batches[key]=surface
	batches[key].append_from(mesh,0,transform);counts[group]=counts.get(group,0)+1
func _box(group:String,material:String,pos:Vector3,size:Vector3,basis:Basis=Basis.IDENTITY):
	var mesh=BoxMesh.new();mesh.size=size;_part(group,material,mesh,Transform3D(basis,pos))
func _beam(group:String,material:String,a:Vector3,b:Vector3,width:float):
	var axis=(b-a).normalized();var helper=Vector3.RIGHT if absf(axis.dot(Vector3.UP))>0.95 else Vector3.UP
	var x=axis.cross(helper).normalized();var z=x.cross(axis).normalized()
	_box(group,material,(a+b)*0.5,Vector3(width,a.distance_to(b),width),Basis(x,axis,z))
func _window(pos:Vector3):
	_box("Hut","dark",pos,Vector3(1.2,1.35,0.12))
	_box("Hut","glass",pos+Vector3(0,0,0.07),Vector3(0.94,1.08,0.03))
	_box("Hut","steel",pos+Vector3(0,0,0.1),Vector3(0.065,1.16,0.05))
	_box("Hut","steel",pos+Vector3(0,0,0.1),Vector3(1.02,0.065,0.05))
func _dish(pos:Vector3,side:float):
	# Shallow parabolic bowl: front faces sideways, opposing dishes avoid duplicate silhouettes.
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 5:
		for segment in 24:
			var corners=[]
			for pair in [[ring,segment],[ring+1,segment],[ring+1,segment+1],[ring,segment+1]]:
				var r=pair[0]/5.0*1.04;var angle=pair[1]/24.0*TAU
				corners.append(Vector3(side*r*r*0.23,cos(angle)*r,sin(angle)*r))
			for index in ([0,1,2,0,2,3] if side>0 else [2,1,0,3,2,0]):surface.add_vertex(corners[index])
	surface.generate_normals();var mesh=surface.commit()
	# Both sides remain visible with a dull metal shell.
	materials.steel.cull_mode=BaseMaterial3D.CULL_DISABLED
	_part("Dishes","steel",mesh,Transform3D(Basis.IDENTITY,pos))
	_beam("Dishes","dark",pos-Vector3(side*0.4,0,0),pos+Vector3(side*0.7,0,0),0.09)
	for angle in [0.0,TAU/3.0,TAU*2.0/3.0]:_beam("Dishes","dark",pos+Vector3(side*0.23,cos(angle),sin(angle)),pos+Vector3(side*0.7,0,0),0.035)
