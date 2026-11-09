extends RefCounted
static var material_cache={}
static func material(color:Color)->StandardMaterial3D:
 if material_cache.has(color):return material_cache[color]
 var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.8;material_cache[color]=m;return m
static func box(parent:Node3D,label:String,at:Vector3,size:Vector3,color:Color):
 var n=MeshInstance3D.new();n.name=label;var m=BoxMesh.new();m.size=size;n.mesh=m;n.material_override=material(color);n.position=at;parent.add_child(n)
static func segment(parent:Node3D,label:String,a:Vector3,b:Vector3,radius:float,color:Color):
 var n=MeshInstance3D.new();n.name=label;var m=CylinderMesh.new();m.height=a.distance_to(b);m.top_radius=radius*.65;m.bottom_radius=radius;m.radial_segments=8;n.mesh=m;n.material_override=material(color)
 var axis=(b-a).normalized();var side=axis.cross(Vector3.FORWARD).normalized()
 if side.length()<.01:side=Vector3.RIGHT
 n.transform=Transform3D(Basis(side,axis,side.cross(axis)),(a+b)*.5);parent.add_child(n)
