extends Node3D
# Temporary prop only: no collider, inventory tool, economic value, or scenery edits.
var rod:MeshInstance3D
var line:MeshInstance3D
var bobber:MeshInstance3D
func _ready():
	rod=segment(Color("735338"),.025);add_child(rod)
	line=segment(Color("d6d9bf"),.006);add_child(line)
	bobber=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=.055;sphere.height=.11;bobber.mesh=sphere
	var material=StandardMaterial3D.new();material.albedo_color=Color("e2ac54");material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;bobber.material_override=material;add_child(bobber)
func segment(color:Color,radius:float)->MeshInstance3D:
	var node=MeshInstance3D.new();var cylinder=CylinderMesh.new();cylinder.top_radius=radius*.65;cylinder.bottom_radius=radius;cylinder.height=1;node.mesh=cylinder
	var material=StandardMaterial3D.new();material.albedo_color=color;node.material_override=material;return node
func place_segment(node:MeshInstance3D,a:Vector3,b:Vector3):
	var axis=(b-a).normalized();var side=axis.cross(Vector3.FORWARD).normalized()
	if side.length()<.01:side=Vector3.RIGHT
	node.global_transform=Transform3D(Basis(side,axis,side.cross(axis)),(a+b)*.5)
	node.scale.y=a.distance_to(b)
func update_prop(player,target:Vector3,phase:String,elapsed:float):
	var hand=player.global_position+Vector3(.28,1.08,-.15)
	var lift=.25*sin(minf(elapsed/.7,1.0)*PI) if phase=="casting" else 0.0
	var tip=hand+Vector3(-.12,.6+lift,-1.5)
	var water=target+Vector3(0,.06,0)
	place_segment(rod,hand,tip);place_segment(line,tip,water);bobber.global_position=water
	bobber.visible=phase!="casting"
