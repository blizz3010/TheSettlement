extends Node3D
## Original distant scenery STUDY. No collision, state, lighting or scene integration.
const SEGMENTS := 384
const ROWS := 12
var triangles := 0
var max_slope := 0.0
var steep_faces := 0
var min_radius := INF
var max_height := 0.0
var slopes: Array[float] = []
var material: StandardMaterial3D
var staged_startup := false

func _ready():
	if staged_startup: return
	material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	# Opaque, double-sided avoids introducing a rendering hole at the wrapped seam.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_build("OuterFoothills", 180.0, 300.0, 490.0, 80.0, 0.15, Color("586b70"), Color("89999d"))
	_build("DistantAlpineRange", 370.0, 570.0, 850.0, 199.0, 1.73, Color("8c9ca8"), Color("bac4c8"))
func _height(a: float, t: float, height: float, phase: float) -> float:
	# Several unequal mountain groups separated by two wide low saddles.
	var group = 0.61 + 0.23*sin(a*3.0+phase) + 0.12*sin(a*5.0-phase)
	# Angular broken crest: unequal linear slopes, not rounded cosine mounds.
	var u = a/TAU*32.0 + phase
	var cell = floorf(u)
	var f = u-cell
	var h0 = 0.62 + 0.34*(0.5+0.5*sin(fposmod(cell,32.0)*TAU*11.0/32.0))
	var h1 = 0.62 + 0.34*(0.5+0.5*sin(fposmod(cell+1.0,32.0)*TAU*11.0/32.0))
	var teeth = lerpf(h0,h1,f)
	teeth += 0.035*(1.0-absf(fposmod(a/TAU*79.0+phase,1.0)*2.0-1.0))
	var gap = 1.0 - 0.70*pow(maxf(0.0,cos(a-0.1-phase*0.2)),12.0)
	gap *= 1.0 - 0.50*pow(maxf(0.0,cos(a-3.4)),18.0)
	var profile = pow(maxf(0.0,1.0-absf(t*2.0-1.0)),1.25)
	# Buttresses weaken toward feet and summit instead of cutting vertical grooves.
	var buttress = 1.0 + 0.10*sin(a*27.0+phase+t*3.0)*sin(t*PI)
	return -8.0 + height*group*teeth*gap*profile*buttress
func _build(label: String, inner: float, crest: float, outer: float, height: float, phase: float, low: Color, high: Color):
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for row in ROWS+1:
		var t = float(row)/ROWS
		var r = lerpf(inner,crest,t*2.0) if t <= 0.5 else lerpf(crest,outer,(t-0.5)*2.0)
		for i in SEGMENTS+1:
			var a = TAU*float(i)/SEGMENTS
			var radius = r + 12.0*sin(a*7.0+phase)*sin(t*PI)
			var y = _height(a,t,height,phase)
			var p = Vector3(cos(a)*radius,y,sin(a)*radius)
			vertices.append(p)
			min_radius = minf(min_radius,radius)
			max_height = maxf(max_height,y)
			var c = low.lerp(high,clampf(y/height,0.0,1.0)*0.55)
			# Restrained slanted rock layers, no tiling bitmap or high-frequency speckle.
			var strata = sin(y*0.16 + a*9.0 + sin(a*13.0)*1.2)
			c = c.lightened(0.045*maxf(strata,0.0)).darkened(0.035*maxf(-strata,0.0))
			# Sparse uneven pale rock/snow on only the high distant group, not white stripes.
			if label == "DistantAlpineRange":
				var snow = smoothstep(0.43,0.68,y/height + 0.035*sin(a*31.0))
				c = c.lerp(Color("d0d2cd"),snow*0.75)
			colors.append(c)
	for row in ROWS:
		for i in SEGMENTS:
			var a = row*(SEGMENTS+1)+i
			indices.append_array(PackedInt32Array([a,a+1,a+SEGMENTS+1,a+1,a+SEGMENTS+2,a+SEGMENTS+1]))
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0,indices.size(),3):
		var a = indices[i]; var b = indices[i+1]; var c = indices[i+2]
		var n = (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
		assert(n.y > 0.0, "Inverted or degenerate mountain triangle")
		var slope = rad_to_deg(acos(clampf(n.normalized().y,0.0,1.0)))
		slopes.append(slope)
		max_slope = maxf(max_slope,slope)
		if slope > 70.0: steep_faces += 1
		for j in [a,b,c]: normals[j] += n
	for i in normals.size(): normals[i] = normals[i].normalized()
	# Explicitly weld seam normals; positions are duplicated to keep indexed construction simple.
	for row in ROWS+1:
		var a = row*(SEGMENTS+1); var b = a+SEGMENTS
		var n = (normals[a]+normals[b]).normalized()
		normals[a] = n; normals[b] = n
	# Split normals at triangle boundaries: visible rocky facets rather than plastic hills.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in range(0,indices.size(),3):
		var a = indices[face]; var b = indices[face+1]; var c = indices[face+2]
		var n = (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).normalized()
		for j in [a,b,c]:
			st.set_normal(n)
			st.set_color(colors[j])
			st.add_vertex(vertices[j])
	var mesh = st.commit()
	var node = MeshInstance3D.new()
	node.name = label; node.mesh = mesh; node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	triangles += indices.size()/3

# Opt-in loading successor scheduling. Original synchronous APIs above remain unchanged.
func initialize_staged(startup_owner: Node):
	material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	# Opaque, double-sided avoids introducing a rendering hole at the wrapped seam.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	await _build_staged("OuterFoothills", 180.0, 300.0, 490.0, 80.0, 0.15, Color("586b70"), Color("89999d"),startup_owner)
	if startup_owner != null and startup_owner.startup_cancel_requested:return
	await _build_staged("DistantAlpineRange", 370.0, 570.0, 850.0, 199.0, 1.73, Color("8c9ca8"), Color("bac4c8"),startup_owner)

func _build_staged(label: String, inner: float, crest: float, outer: float, height: float, phase: float, low: Color, high: Color,startup_owner: Node = null):
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for row in ROWS+1:
		var t = float(row)/ROWS
		var r = lerpf(inner,crest,t*2.0) if t <= 0.5 else lerpf(crest,outer,(t-0.5)*2.0)
		for i in SEGMENTS+1:
			if startup_owner != null and i % 64 == 0:
				if await startup_owner._startup_checkpoint("mountain sample vertices " + label):return
			var a = TAU*float(i)/SEGMENTS
			var radius = r + 12.0*sin(a*7.0+phase)*sin(t*PI)
			var y = _height(a,t,height,phase)
			var p = Vector3(cos(a)*radius,y,sin(a)*radius)
			vertices.append(p)
			min_radius = minf(min_radius,radius)
			max_height = maxf(max_height,y)
			var c = low.lerp(high,clampf(y/height,0.0,1.0)*0.55)
			# Restrained slanted rock layers, no tiling bitmap or high-frequency speckle.
			var strata = sin(y*0.16 + a*9.0 + sin(a*13.0)*1.2)
			c = c.lightened(0.045*maxf(strata,0.0)).darkened(0.035*maxf(-strata,0.0))
			# Sparse uneven pale rock/snow on only the high distant group, not white stripes.
			if label == "DistantAlpineRange":
				var snow = smoothstep(0.43,0.68,y/height + 0.035*sin(a*31.0))
				c = c.lerp(Color("d0d2cd"),snow*0.75)
			colors.append(c)
	for row in ROWS:
		if startup_owner != null:
			if await startup_owner._startup_checkpoint("mountain indices " + label):return
		for i in SEGMENTS:
			var a = row*(SEGMENTS+1)+i
			indices.append_array(PackedInt32Array([a,a+1,a+SEGMENTS+1,a+1,a+SEGMENTS+2,a+SEGMENTS+1]))
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0,indices.size(),3):
		if startup_owner != null and i % 192 == 0:
			if await startup_owner._startup_checkpoint("mountain normals " + label):return
		var a = indices[i]; var b = indices[i+1]; var c = indices[i+2]
		var n = (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
		assert(n.y > 0.0, "Inverted or degenerate mountain triangle")
		var slope = rad_to_deg(acos(clampf(n.normalized().y,0.0,1.0)))
		slopes.append(slope)
		max_slope = maxf(max_slope,slope)
		if slope > 70.0: steep_faces += 1
		for j in [a,b,c]: normals[j] += n
	for i in normals.size(): normals[i] = normals[i].normalized()
	# Explicitly weld seam normals; positions are duplicated to keep indexed construction simple.
	for row in ROWS+1:
		var a = row*(SEGMENTS+1); var b = a+SEGMENTS
		var n = (normals[a]+normals[b]).normalized()
		normals[a] = n; normals[b] = n
	# Split normals at triangle boundaries: visible rocky facets rather than plastic hills.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in range(0,indices.size(),3):
		if startup_owner != null and face % 192 == 0:
			if await startup_owner._startup_checkpoint("mountain faceted surface " + label):return
		var a = indices[face]; var b = indices[face+1]; var c = indices[face+2]
		var n = (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).normalized()
		for j in [a,b,c]:
			st.set_normal(n)
			st.set_color(colors[j])
			st.add_vertex(vertices[j])
	if startup_owner != null:
		if await startup_owner._startup_checkpoint("mountain mesh commit " + label):return
	var mesh = st.commit()
	var node = MeshInstance3D.new()
	node.name = label; node.mesh = mesh; node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	triangles += indices.size()/3
