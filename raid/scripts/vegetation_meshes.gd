extends RefCounted
## Original, low-poly concept interpretations. No image-to-model conversion or imports.
## One opaque vertex-colored surface per species. Alpha encodes emission, not opacity.
const SPECIES = {
	"ridgeback_pine": {"height":18.0, "label":"Ridgeback Pine"},
	"lanternleaf_oak": {"height":12.0, "label":"Lanternleaf Oak"},
	"silverbark_birch": {"height":10.0, "label":"Silverbark Birch"},
	"amberberry_thicket": {"height":1.5, "label":"Amberberry Thicket"},
	"ridge_meadow_grass": {"height":0.8, "label":"Ridge Meadow Grass"},
	"glowfern": {"height":0.5, "label":"Glowfern"},
	"cinder_juniper": {"height":4.8, "label":"Cinder Juniper"},
	"salt_yucca": {"height":3.6, "label":"Salt Yucca"},
	"glassplume_shrub": {"height":1.65, "label":"Glassplume Shrub"},
	"bonebrush": {"height":1.15, "label":"Bonebrush"},
	"ember_agave": {"height":0.95, "label":"Ember Agave"},
	"salt_samphire_mat": {"height":0.36, "label":"Salt Samphire Mat"},
	"ridge_stone": {"height":1.4, "label":"Mossy Ridge Stone"},
	"basalt_rock": {"height":1.35, "label":"Basalt Rock"},
}
var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()

static func material()->ShaderMaterial:
	var shader=Shader.new()
	shader.code="""shader_type spatial;
render_mode cull_disabled;
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.94;
	EMISSION = COLOR.rgb * COLOR.a * 0.55;
}
"""
	var result=ShaderMaterial.new();result.shader=shader;return result

func build(species:String)->ArrayMesh:
	assert(SPECIES.has(species), "Unknown vegetation species")
	vertices.clear();normals.clear();colors.clear()
	match species:
		"ridgeback_pine": _pine()
		"lanternleaf_oak": _oak()
		"silverbark_birch": _birch()
		"amberberry_thicket": _thicket()
		"ridge_meadow_grass": _grass()
		"glowfern": _fern()
		"cinder_juniper": _juniper()
		"salt_yucca": _yucca()
		"glassplume_shrub": _brush(true)
		"bonebrush": _brush(false)
		"ember_agave": _agave()
		"salt_samphire_mat": _samphire()
		"ridge_stone", "basalt_rock": _rock(species=="ridge_stone")
	var low=INF;var high=-INF
	for vertex in vertices:low=minf(low,vertex.y);high=maxf(high,vertex.y)
	var scale_factor:float=SPECIES[species].height/(high-low)
	for index in vertices.size():vertices[index]=(vertices[index]-Vector3.UP*low)*scale_factor
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.resource_name=species
	return mesh

func _color(hex:String,glow:float=0.0)->Color:
	var color=Color(hex);color.a=glow;return color
func _tri(a:Vector3,b:Vector3,c:Vector3,color:Color):
	var normal=(b-a).cross(c-a).normalized()
	if normal.length_squared()<0.5:return
	vertices.append_array(PackedVector3Array([a,b,c]))
	normals.append_array(PackedVector3Array([normal,normal,normal]))
	colors.append_array(PackedColorArray([color,color,color]))
func _tube(start:Vector3,end:Vector3,radius:float,tip:float,color:Color,sides:int=6):
	var direction=(end-start).normalized()
	var tangent=direction.cross(Vector3.FORWARD if absf(direction.z)<0.9 else Vector3.RIGHT).normalized()
	var bitangent=direction.cross(tangent).normalized()
	for index in sides:
		var angle=float(index)*TAU/sides;var next=float(index+1)*TAU/sides
		var radial=tangent*cos(angle)+bitangent*sin(angle);var radial_next=tangent*cos(next)+bitangent*sin(next)
		var a=start+radial*radius;var b=start+radial_next*radius
		var c=end+radial*tip;var d=end+radial_next*tip
		_tri(a,b,c,color);_tri(b,d,c,color)
		_tri(start,b,a,color);_tri(end,c,d,color)
func _crown(center:Vector3,size:Vector3,color:Color,sides:int=8,rings:int=4):
	for ring in rings:
		var a=PI*float(ring)/rings;var b=PI*float(ring+1)/rings
		for side in sides:
			var p=TAU*float(side)/sides;var q=TAU*float(side+1)/sides
			var v0=center+Vector3(sin(a)*cos(p),cos(a),sin(a)*sin(p))*size
			var v1=center+Vector3(sin(b)*cos(p),cos(b),sin(b)*sin(p))*size
			var v2=center+Vector3(sin(a)*cos(q),cos(a),sin(a)*sin(q))*size
			var v3=center+Vector3(sin(b)*cos(q),cos(b),sin(b)*sin(q))*size
			_tri(v0,v2,v1,color);_tri(v1,v2,v3,color)
func _blade(base:Vector3,mid:Vector3,tip:Vector3,width:float,color:Color):
	var side=(tip-base).cross(Vector3.UP).normalized()*width
	if side.length_squared()<0.000001:side=Vector3.RIGHT*width
	var ridge=mid+Vector3.UP*width*0.24
	_tri(base,mid-side,ridge,color);_tri(base,ridge,mid+side,color)
	_tri(ridge,mid-side,tip,color);_tri(mid+side,ridge,tip,color)
func _radial(index:int,count:int)->Vector3:return Vector3(cos(float(index)*TAU/count),0,sin(float(index)*TAU/count))

func _pine():
	_tube(Vector3.ZERO,Vector3(0,17.7,0),0.4,0.06,_color("645340"),8)
	for tier in 9:
		var y=3.8+tier*1.45;var radius=2.6-tier*0.25
		var leaf=_color("214f46" if tier%2==0 else "326557")
		_tube(Vector3(0,y,0),Vector3(0,y+2.8,0),radius,0.025,leaf,10)
		for limb in 5:
			var direction=_radial(limb,5).rotated(Vector3.UP,tier*0.5)
			_tube(Vector3(0,y+0.2,0),direction*radius*0.96+Vector3.UP*(y-0.25),0.065,0.018,_color("544b3c"),4)
func _oak():
	_tube(Vector3.ZERO,Vector3(0.15,5.8,0),0.43,0.23,_color("66533e"),8)
	for limb in 7:
		var direction=_radial(limb,7)
		var end=direction*(2.1 if limb%2 else 1.65)+Vector3.UP*(7.1+float(limb%3)*0.8)
		_tube(Vector3(0,3.4+limb*0.24,0),end,0.19,0.055,_color("6e5a40"),6)
		_crown(end+Vector3.UP,Vector3(1.75,2.0,1.6),_color("708346" if limb%2 else "57733d"))
		for berry in 3:
			var point=end+direction*(1.0+berry*0.18)+Vector3.UP*(0.15+berry*0.6)
			_crown(point,Vector3.ONE*0.095,_color("f1bb48",1.0),5,3)
	_crown(Vector3(0,9.5,0),Vector3(2.1,2.5,1.9),_color("7c8a44"))
func _birch():
	for trunk in 2:
		var offset=Vector3(trunk*0.18,0,trunk*0.12)
		var end=Vector3(-0.28+trunk*0.7,9.5-trunk*0.8,0.1)
		_tube(offset,end,0.15-trunk*0.03,0.025,_color("d9d9be"),7)
		for mark in 9:
			var centre=offset.lerp(end,float(mark+1)/12.0)
			_tube(centre,centre+Vector3.UP*0.08,0.13-trunk*0.03,0.12-trunk*0.03,_color("606763"),6)
	for limb in 7:
		var direction=_radial(limb,7);var y=5.1+limb*0.48
		var tip=direction*(1.25+float(limb%2)*0.25)+Vector3.UP*y
		_tube(Vector3(0,y-1.0,0),tip,0.075,0.018,_color("d2d2b9"),5)
		_crown(tip,Vector3(0.9,1.4,0.8),_color("a3ad68" if limb%2 else "81985c"),7,4)
		for drop in 3:
			var root=tip+_radial(drop,3)*0.5
			_blade(root,root+direction*0.12-Vector3.UP*0.8,root+direction*0.18-Vector3.UP*1.9,0.18,_color("8eaa65"))
func _thicket():
	for limb in 7:
		var direction=_radial(limb,7);var end=direction*0.42+Vector3.UP*(0.65+float(limb%3)*0.15)
		_tube(Vector3(0,0.05,0),end,0.04,0.012,_color("6c5840"),5)
		_crown(end,Vector3(0.42,0.48,0.4),_color("647d3f" if limb%2 else "4c703d"),7,3)
		for berry in 3:
			_crown(end+direction*0.34+_radial(berry,3)*0.08+Vector3.UP*(berry*0.14-0.1),Vector3.ONE*0.04,_color("edb54a",0.8),5,3)
func _grass():
	for index in 12:
		var direction=_radial(index,12);var height=0.38+float(index%4)*0.12
		_blade(direction*0.07,direction*0.17+Vector3.UP*height*0.8,direction*0.36+Vector3.UP*height,0.035,_color("547e6e" if index%2 else "6b9583"))
	for index in 4:
		var direction=_radial(index,4);var tip=direction*0.19+Vector3.UP*(0.7+index*0.035)
		_tube(direction*0.04,tip,0.008,0.005,_color("a8ac77"),3)
		_crown(tip,Vector3(0.025,0.11,0.025),_color("d3c796"),4,3)
func _fern():
	for index in 7:
		var direction=_radial(index,7);var height=0.28+float(index%3)*0.07
		var root=Vector3(0,0.08,0);var mid=direction*0.3+Vector3.UP*height
		_tube(root,mid,0.012,0.004,_color("5db7a0",0.16),4)
		for leaf in range(1,5):
			var t=float(leaf)/5.0;var centre=root.lerp(mid,t)
			var tangent=direction.cross(Vector3.UP)
			for side in [-1,1]:
				var tip=centre+(tangent*side*0.14+direction*0.12)*(1.15-t*0.5)
				_blade(centre,(centre+tip)*0.5+Vector3.UP*0.025,tip,0.04,_color("2d7b67",0.12))
		_blade(mid-direction*0.08,mid+direction*0.09,mid+direction*0.22-Vector3.UP*0.03,0.055,_color("3b9d84",0.22))
func _juniper():
	var a=Vector3(0.12,1.3,0.06);var b=Vector3(-0.25,2.5,0);var c=Vector3(0.18,3.7,0.1)
	_tube(Vector3.ZERO,a,0.45,0.33,_color("494840"),8);_tube(a,b,0.33,0.25,_color("595443"),7);_tube(b,c,0.25,0.09,_color("494840"),6)
	for limb in 5:
		var direction=_radial(limb,5);var end=direction*(1.0+float(limb%2)*0.2)+Vector3.UP*(2.9+limb*0.23)
		_tube(b,end,0.14,0.035,_color("716b50"),5)
		_crown(end+Vector3.UP*0.25,Vector3(0.8,0.52,0.68),_color("929775" if limb%2 else "7a825d"),7,3)
	_crown(c,Vector3(0.7,0.65,0.6),_color("9c9f79"),7,3)
func _yucca():
	_tube(Vector3.ZERO,Vector3(0,2.0,0),0.43,0.28,_color("857253"),8)
	for ring in 6:
		for index in 7:
			var direction=_radial(index,7).rotated(Vector3.UP,ring*0.35);var base=Vector3.UP*(0.25+ring*0.27)
			_blade(base+direction*0.32,base+direction*0.43-Vector3.UP*0.07,base+direction*0.38-Vector3.UP*0.23,0.12,_color("a18b62"))
	for index in 13:
		var direction=_radial(index,13);var height=0.6+float(index%4)*0.28
		_blade(Vector3(0,1.8,0),direction*0.55+Vector3.UP*2.15,direction*(1.1-height*0.25)+Vector3.UP*(2.0+height),0.12,_color("9aab8e" if index%2 else "788d76"))
func _brush(crystal:bool):
	var bark=_color("a59e80" if crystal else "c8c8b4")
	for index in 7:
		var direction=_radial(index,7);var end=direction*0.48+Vector3.UP*(0.8+float(index%3)*0.2)
		_tube(Vector3(0,0.04,0),end,0.04,0.012,bark,5)
		for branch in 3:
			var base=end*0.7;var tip=end+_radial(branch,3)*0.2+Vector3.UP*(branch*0.08)
			_tube(base,tip,0.023,0.008,bark,4)
			if crystal:
				_tube(tip-Vector3.UP*0.09,tip+Vector3.UP*0.12,0.085,0.0,_color("c3e3e3",0.22),5)
			else:_crown(tip,Vector3(0.045,0.085,0.045),_color("e4e1cc"),5,3)
func _agave():
	for index in 15:
		var direction=_radial(index,15);var height=0.3+float(index%4)*0.17;var root=Vector3(0,0.05,0)
		var mid=direction*(0.28+height*0.07)+Vector3.UP*height*0.4
		var tip=direction*(0.73-height*0.4)+Vector3.UP*height
		_blade(root,mid,tip,0.16,_color("859582" if index%2 else "6c857a"))
		_tube(tip,tip+(tip-mid).normalized()*0.12,0.025,0.0,_color("b56742"),4)
func _samphire():
	for index in 11:
		var direction=_radial(index,11);var root=direction*0.04+Vector3.UP*0.05
		var mid=direction*0.22+Vector3.UP*(0.1+float(index%3)*0.035)
		var tip=direction*0.36+Vector3.UP*(0.2+float(index%3)*0.03)
		_tube(root,mid,0.035,0.034,_color("8b9371"),5)
		_tube(mid,tip,0.034,0.02,_color("b5746d"),5)
		_crown(tip,Vector3.ONE*0.026,_color("c67e77"),5,3)
func _rock(moss:bool):
	_crown(Vector3(0,0.68,0),Vector3(0.83,0.7,0.76),_color("73776a" if moss else "615950"),7,3)
	_crown(Vector3(0.38,0.36,0.18),Vector3(0.48,0.38,0.52),_color("77815f" if moss else "807365"),6,3)
