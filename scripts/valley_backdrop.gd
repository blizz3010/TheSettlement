extends Node3D
## Original, deterministic scenery geometry. No collision, gameplay, or save state.
## Reference: valley settlement concepts; these are scenery silhouettes, not a raid map.
const SEED := 20261030
const SEGMENTS := 192
const HAZE := Color("a3bfc0")
var triangle_count := 0
var tree_count := 0
var geometry_signature := 0.0
var terrain_vertices := PackedVector3Array()

var staged_startup := false

func _ready():
	if staged_startup: return
	name = "ValleyBackdrop"
	_build_apron()
	_build_ridge("MiddleRidge", [70.0,100.0,130.0,155.0,180.0,205.0,235.0], [-5.0,3.0,13.0,23.0,14.0,5.0,-10.0], 0.0, 0.06)
	_build_distant_mountains()
	_build_trees()
	set_meta("seed",SEED)
	set_meta("triangle_count",triangle_count)
	set_meta("tree_count",tree_count)

func _material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _surface(label: String, vertices: PackedVector3Array, colors: PackedColorArray) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in vertices.size():
		st.set_color(colors[i])
		st.add_vertex(vertices[i])
		geometry_signature += vertices[i].x*0.013 + vertices[i].y*0.071 + vertices[i].z*0.019
	st.generate_normals()
	var node = MeshInstance3D.new()
	node.name = label
	node.mesh = st.commit()
	node.material_override = _material()
	if label == "MiddleRidge": node.material_override.albedo_color = Color(0.34,0.42,0.36,1.0)
	elif label == "FarRidge": node.material_override.albedo_color = Color(0.55,0.65,0.76,1.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	triangle_count += vertices.size()/3
	terrain_vertices.append_array(vertices)
	return node

func terrain_height(x: float, z: float) -> float:
	var start = Vector3(x,250.0,z)
	var end = Vector3(x,-30.0,z)
	var highest := -30.0
	for i in range(0,terrain_vertices.size(),3):
		var a = terrain_vertices[i]
		var b = terrain_vertices[i+1]
		var c = terrain_vertices[i+2]
		if x < minf(a.x,minf(b.x,c.x)) or x > maxf(a.x,maxf(b.x,c.x)): continue
		if z < minf(a.z,minf(b.z,c.z)) or z > maxf(a.z,maxf(b.z,c.z)): continue
		var hit = Geometry3D.segment_intersects_triangle(start,end,a,b,c)
		if hit is Vector3: highest = maxf(highest,hit.y)
	return highest

func _tri(v: PackedVector3Array, c: PackedColorArray, a: Vector3, b: Vector3, d: Vector3, color: Color):
	v.append_array(PackedVector3Array([a,b,d]))
	c.append_array(PackedColorArray([color,color,color]))

func _build_apron():
	# Pure scenery outside the exact old 90 m ground square; no floor/collision extension.
	var v := PackedVector3Array()
	var c := PackedColorArray()
	for i in SEGMENTS:
		var a = TAU*i/SEGMENTS
		var b = TAU*(i+1)/SEGMENTS
		var da = Vector3(cos(a),0,sin(a))
		var db = Vector3(cos(b),0,sin(b))
		var inner_a = da * (45.0/maxf(absf(da.x),absf(da.z)))
		var inner_b = db * (45.0/maxf(absf(db.x),absf(db.z)))
		inner_a.y = -0.06
		inner_b.y = -0.06
		var outer_a = da*113.0 + Vector3(0,-3.4,0)
		var outer_b = db*113.0 + Vector3(0,-3.4,0)
		var color = Color("3d5747").lerp(Color("687a60"),0.16+0.10*sin(a*9.0))
		_tri(v,c,inner_a,outer_a,inner_b,color)
		_tri(v,c,inner_b,outer_a,outer_b,color)
	_surface("ScenicGroundApron",v,c)

func _ridge_height(angle: float, base: float, phase: float, row: int) -> float:
	if base < 0.0: return base
	# Mixed frequencies produce broad saddles and narrow, broken peaks, not repeated cones.
	var shape = 0.55 + 0.35*sin(angle*3.0+phase) + 0.22*sin(angle*7.0-phase*2.0) + 0.14*sin(angle*17.0+0.8+row*0.23) + 0.07*sin(angle*37.0+phase)
	return base*maxf(shape,0.12)

func _build_ridge(label: String, radii: Array, heights: Array, phase: float, haze: float):
	var rings: Array[PackedVector3Array] = []
	for row in radii.size():
		var ring := PackedVector3Array()
		for i in SEGMENTS:
			var a = TAU*i/SEGMENTS
			var r = float(radii[row]) + (0.0 if row == 0 else 10.0*sin(a*11.0+phase+row*0.73))
			ring.append(Vector3(cos(a)*r,_ridge_height(a,float(heights[row]),phase,row),sin(a)*r))
		rings.append(ring)
	var v := PackedVector3Array()
	var c := PackedColorArray()
	for row in rings.size()-1:
		for i in SEGMENTS:
			var j = (i+1)%SEGMENTS
			var a = rings[row][i]
			var b = rings[row+1][i]
			var d = rings[row][j]
			var e = rings[row+1][j]
			var tint = Color("304940") if row < 2 else Color("4c6067")
			if label == "FarRidge": tint = Color("3f5866")
			var detail = 0.06*sin(float(i)*2.31+row*1.7+phase)
			tint = tint.lightened(detail) if detail >= 0 else tint.darkened(-detail)
			# Subtle cool caps only on the highest distant facets, not every ridge.
			if label == "FarRidge" and minf(b.y,e.y)>90.0: tint = tint.lerp(Color("9babb0"),0.25)
			tint = tint.lerp(HAZE,haze)
			_tri(v,c,a,b,d,tint)
			_tri(v,c,d,b,e,tint.darkened(0.035))
	_surface(label,v,c)

func _multi(label: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color]):
	var multi = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i,transforms[i])
		multi.set_instance_color(i,colors[i])
	var node = MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	node.set_meta("instance_transforms",transforms)
	node.set_meta("instance_colors",colors)
	node.material_override = _material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	triangle_count += mesh.get_faces().size()/3 * transforms.size()

func _build_trees():
	var rng = RandomNumberGenerator.new()
	rng.seed = SEED
	var trunks: Array[Transform3D] = []
	var trunk_colors: Array[Color] = []
	var branches: Array[Transform3D] = []
	var branch_colors: Array[Color] = []
	var crowns: Array[Transform3D] = []
	var crown_colors: Array[Color] = []
	for i in 72:
		var angle = TAU*floorf(float(i)/4.0)/18.0 + rng.randf_range(-0.065,0.065)
		var radius = rng.randf_range(80.0,125.0)
		var height = rng.randf_range(5.0,10.0)
		var origin = Vector3(cos(angle)*radius,0,sin(angle)*radius)
		origin.y = terrain_height(origin.x,origin.z)-0.12
		trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.85,height,0.85)),origin+Vector3(0,height*0.5,0)))
		trunk_colors.append(Color("514f3d").lerp(HAZE,0.15))
		var leaf = Color("284f49") if i%5 else Color("60516b")
		for lobe in 6:
			var a = lobe*TAU/6+rng.randf_range(-0.3,0.3)
			var width = rng.randf_range(2.6,4.0)
			var p = origin+Vector3(cos(a)*2.1,height+rng.randf_range(-2.4,1.2),sin(a)*2.1)
			if lobe%3 == 0:
				var branch_start = origin+Vector3(0,height*0.45,0)
				var branch_end = p-Vector3(0,1.0,0)
				var direction = branch_end-branch_start
				var rotation = Basis(Quaternion(Vector3.UP,direction.normalized()))
				branches.append(Transform3D(rotation.scaled_local(Vector3(0.35,direction.length(),0.35)),(branch_start+branch_end)*0.5))
				branch_colors.append(trunk_colors[-1])
			crowns.append(Transform3D(Basis.IDENTITY.scaled(Vector3(width,rng.randf_range(2.4,4.0),width*0.85)),p))
			crown_colors.append(leaf.lightened(rng.randf_range(0.0,0.10)).lerp(HAZE,0.12))
		tree_count += 1
	var trunk = CylinderMesh.new()
	trunk.top_radius = 0.45
	trunk.bottom_radius = 0.75
	trunk.height = 1.0
	trunk.radial_segments = 7
	var crown = SphereMesh.new()
	crown.radius = 1.0
	crown.height = 2.0
	crown.radial_segments = 12
	crown.rings = 5
	triangle_count += preload("res://scripts/distant_approved_forest.gd").add_to(self,trunks,crowns,trunk,crown)

func _build_distant_mountains():
	# v0.18 scenery only: preserve original apron/middle ridge/tree construction.
	var generator = preload("res://scripts/distant_mountains.gd").new()
	add_child(generator)
	set_meta("far_max_slope",generator.max_slope)
	set_meta("far_steep_faces",generator.steep_faces)
	set_meta("far_min_radius",generator.min_radius)
	set_meta("far_max_height",generator.max_height)
	triangle_count += generator.triangles
	for mountain in generator.get_children():
		mountain.reparent(self)
		var vertices = mountain.mesh.get_faces()
		terrain_vertices.append_array(vertices)
		for v in vertices:
			geometry_signature += v.x*0.013 + v.y*0.071 + v.z*0.019
	generator.free()

# Opt-in loading successor scheduling. Original synchronous APIs above remain unchanged.
func initialize_staged(startup_owner: Node):
	name = "ValleyBackdrop"
	await _build_apron_staged(startup_owner)
	if _cancelled(startup_owner): return
	await _build_ridge_staged("MiddleRidge", [70.0,100.0,130.0,155.0,180.0,205.0,235.0], [-5.0,3.0,13.0,23.0,14.0,5.0,-10.0], 0.0, 0.06,startup_owner)
	if _cancelled(startup_owner): return
	await _build_distant_mountains_staged(startup_owner)
	if _cancelled(startup_owner): return
	await _build_trees_staged(startup_owner)
	if _cancelled(startup_owner): return
	set_meta("seed",SEED)
	set_meta("triangle_count",triangle_count)
	set_meta("tree_count",tree_count)

func _cancelled(startup_owner: Node) -> bool:
	return startup_owner != null and startup_owner.startup_cancel_requested

func _surface_staged(label: String, vertices: PackedVector3Array, colors: PackedColorArray,startup_owner: Node = null) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in vertices.size():
		if startup_owner != null and i % 128 == 0:
			if await startup_owner._startup_checkpoint("valley surface vertices " + label): return null
		st.set_color(colors[i])
		st.add_vertex(vertices[i])
		geometry_signature += vertices[i].x*0.013 + vertices[i].y*0.071 + vertices[i].z*0.019
	if startup_owner != null:
		if await startup_owner._startup_checkpoint("valley normals " + label): return null
	st.generate_normals()
	var node = MeshInstance3D.new()
	node.name = label
	node.mesh = st.commit()
	if startup_owner != null:
		if await startup_owner._startup_checkpoint("valley committed surface " + label):
			node.free()
			return null
	node.material_override = _material()
	if label == "MiddleRidge": node.material_override.albedo_color = Color(0.34,0.42,0.36,1.0)
	elif label == "FarRidge": node.material_override.albedo_color = Color(0.55,0.65,0.76,1.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	triangle_count += vertices.size()/3
	terrain_vertices.append_array(vertices)
	return node

func _build_apron_staged(startup_owner: Node = null):
	# Pure scenery outside the exact old 90 m ground square; no floor/collision extension.
	var v := PackedVector3Array()
	var c := PackedColorArray()
	for i in SEGMENTS:
		if startup_owner != null and i % 32 == 0:
			if await startup_owner._startup_checkpoint("valley apron vertices"): return
		var a = TAU*i/SEGMENTS
		var b = TAU*(i+1)/SEGMENTS
		var da = Vector3(cos(a),0,sin(a))
		var db = Vector3(cos(b),0,sin(b))
		var inner_a = da * (45.0/maxf(absf(da.x),absf(da.z)))
		var inner_b = db * (45.0/maxf(absf(db.x),absf(db.z)))
		inner_a.y = -0.06
		inner_b.y = -0.06
		var outer_a = da*113.0 + Vector3(0,-3.4,0)
		var outer_b = db*113.0 + Vector3(0,-3.4,0)
		var color = Color("3d5747").lerp(Color("687a60"),0.16+0.10*sin(a*9.0))
		_tri(v,c,inner_a,outer_a,inner_b,color)
		_tri(v,c,inner_b,outer_a,outer_b,color)
	await _surface_staged("ScenicGroundApron",v,c,startup_owner)

func _build_ridge_staged(label: String, radii: Array, heights: Array, phase: float, haze: float,startup_owner: Node = null):
	var rings: Array[PackedVector3Array] = []
	for row in radii.size():
		if startup_owner != null:
			if await startup_owner._startup_checkpoint("valley ridge ring"): return
		var ring := PackedVector3Array()
		for i in SEGMENTS:
			var a = TAU*i/SEGMENTS
			var r = float(radii[row]) + (0.0 if row == 0 else 10.0*sin(a*11.0+phase+row*0.73))
			ring.append(Vector3(cos(a)*r,_ridge_height(a,float(heights[row]),phase,row),sin(a)*r))
		rings.append(ring)
	var v := PackedVector3Array()
	var c := PackedColorArray()
	for row in rings.size()-1:
		if startup_owner != null:
			if await startup_owner._startup_checkpoint("valley ridge faces"): return
		for i in SEGMENTS:
			var j = (i+1)%SEGMENTS
			var a = rings[row][i]
			var b = rings[row+1][i]
			var d = rings[row][j]
			var e = rings[row+1][j]
			var tint = Color("304940") if row < 2 else Color("4c6067")
			if label == "FarRidge": tint = Color("3f5866")
			var detail = 0.06*sin(float(i)*2.31+row*1.7+phase)
			tint = tint.lightened(detail) if detail >= 0 else tint.darkened(-detail)
			# Subtle cool caps only on the highest distant facets, not every ridge.
			if label == "FarRidge" and minf(b.y,e.y)>90.0: tint = tint.lerp(Color("9babb0"),0.25)
			tint = tint.lerp(HAZE,haze)
			_tri(v,c,a,b,d,tint)
			_tri(v,c,d,b,e,tint.darkened(0.035))
	await _surface_staged(label,v,c,startup_owner)

func _build_trees_staged(startup_owner: Node = null):
	var rng = RandomNumberGenerator.new()
	rng.seed = SEED
	var trunks: Array[Transform3D] = []
	var trunk_colors: Array[Color] = []
	var branches: Array[Transform3D] = []
	var branch_colors: Array[Color] = []
	var crowns: Array[Transform3D] = []
	var crown_colors: Array[Color] = []
	for i in 72:
		if startup_owner != null:
			if await startup_owner._startup_checkpoint("valley tree grounding"): return
		var angle = TAU*floorf(float(i)/4.0)/18.0 + rng.randf_range(-0.065,0.065)
		var radius = rng.randf_range(80.0,125.0)
		var height = rng.randf_range(5.0,10.0)
		var origin = Vector3(cos(angle)*radius,0,sin(angle)*radius)
		origin.y = terrain_height(origin.x,origin.z)-0.12
		trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.85,height,0.85)),origin+Vector3(0,height*0.5,0)))
		trunk_colors.append(Color("514f3d").lerp(HAZE,0.15))
		var leaf = Color("284f49") if i%5 else Color("60516b")
		for lobe in 6:
			var a = lobe*TAU/6+rng.randf_range(-0.3,0.3)
			var width = rng.randf_range(2.6,4.0)
			var p = origin+Vector3(cos(a)*2.1,height+rng.randf_range(-2.4,1.2),sin(a)*2.1)
			if lobe%3 == 0:
				var branch_start = origin+Vector3(0,height*0.45,0)
				var branch_end = p-Vector3(0,1.0,0)
				var direction = branch_end-branch_start
				var rotation = Basis(Quaternion(Vector3.UP,direction.normalized()))
				branches.append(Transform3D(rotation.scaled_local(Vector3(0.35,direction.length(),0.35)),(branch_start+branch_end)*0.5))
				branch_colors.append(trunk_colors[-1])
			crowns.append(Transform3D(Basis.IDENTITY.scaled(Vector3(width,rng.randf_range(2.4,4.0),width*0.85)),p))
			crown_colors.append(leaf.lightened(rng.randf_range(0.0,0.10)).lerp(HAZE,0.12))
		tree_count += 1
	var trunk = CylinderMesh.new()
	trunk.top_radius = 0.45
	trunk.bottom_radius = 0.75
	trunk.height = 1.0
	trunk.radial_segments = 7
	var crown = SphereMesh.new()
	crown.radius = 1.0
	crown.height = 2.0
	crown.radial_segments = 12
	crown.rings = 5
	if startup_owner != null:
		if await startup_owner._startup_checkpoint("valley approved forest batch"): return
	triangle_count += preload("res://scripts/distant_approved_forest.gd").add_to(self,trunks,crowns,trunk,crown)

func _build_distant_mountains_staged(startup_owner: Node = null):
	# v0.18 scenery only: preserve original apron/middle ridge/tree construction.
	if startup_owner != null:
		if await startup_owner._startup_checkpoint("valley distant mountain generator"): return
	var generator = preload("res://scripts/distant_mountains.gd").new()
	if startup_owner != null: generator.staged_startup = true
	add_child(generator)
	if startup_owner != null:
		await generator.initialize_staged(startup_owner)
		if _cancelled(startup_owner):
			generator.free()
			return
	set_meta("far_max_slope",generator.max_slope)
	set_meta("far_steep_faces",generator.steep_faces)
	set_meta("far_min_radius",generator.min_radius)
	set_meta("far_max_height",generator.max_height)
	triangle_count += generator.triangles
	for mountain in generator.get_children():
		if startup_owner != null:
			if await startup_owner._startup_checkpoint("valley distant mountain transfer"):
				generator.free()
				return
		mountain.reparent(self)
		var vertices = mountain.mesh.get_faces()
		terrain_vertices.append_array(vertices)
		for i in vertices.size():
			if startup_owner != null and i % 256 == 0:
				if await startup_owner._startup_checkpoint("valley mountain signature"):
					generator.free()
					return
			var v = vertices[i]
			geometry_signature += v.x*0.013 + v.y*0.071 + v.z*0.019
	generator.free()
