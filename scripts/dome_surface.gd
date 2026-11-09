extends Node3D
const Envelope=preload("res://scripts/settlement_envelope.gd")
## Visual shell only. Exact legacy rib ellipsoid; does not replace ribs or boundary.
const HORIZONTAL_RADIUS := Envelope.HORIZONTAL_RADIUS
const VERTICAL_RADIUS := Envelope.VERTICAL_RADIUS
const CENTER_Y := Envelope.CENTER_Y
const SEGMENTS := 96
const RINGS := 32
var surface_material:ShaderMaterial
var sun:DirectionalLight3D

static func shell_point(azimuth:float, elevation:float)->Vector3:
 return Vector3(cos(azimuth)*cos(elevation)*HORIZONTAL_RADIUS, CENTER_Y+sin(elevation)*VERTICAL_RADIUS, sin(azimuth)*cos(elevation)*HORIZONTAL_RADIUS)

static func ellipsoid_value(p:Vector3)->float:
 return (p.x*p.x+p.z*p.z)/(HORIZONTAL_RADIUS*HORIZONTAL_RADIUS)+pow((p.y-CENTER_Y)/VERTICAL_RADIUS,2.0)

static func add_to(scene:Node3D)->Node3D:
 if scene.has_node('DomeSurface'):return scene.get_node('DomeSurface')
 var root=load('res://scripts/dome_surface.gd').new()
 root.name='DomeSurface'
 for child in scene.get_children():
  if child is DirectionalLight3D:root.sun=child;break
 scene.add_child(root)
 root.build()
 return root

func build()->void:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for ring in range(RINGS):
  var e0=float(ring)*PI/2.0/RINGS;var e1=float(ring+1)*PI/2.0/RINGS
  for segment in range(SEGMENTS):
   var a0=float(segment)*TAU/SEGMENTS;var a1=float(segment+1)*TAU/SEGMENTS
   var p=shell_point(a0,e0);var q=shell_point(a1,e0)
   var u=shell_point(a0,e1);var v=shell_point(a1,e1)
   var points=[p,q,u] if ring==RINGS-1 else [p,q,u,q,v,u]
   for point in points:
    st.set_normal(Vector3(point.x/(HORIZONTAL_RADIUS*HORIZONTAL_RADIUS),(point.y-CENTER_Y)/(VERTICAL_RADIUS*VERTICAL_RADIUS),point.z/(HORIZONTAL_RADIUS*HORIZONTAL_RADIUS)).normalized())
    st.add_vertex(point)
 var instance=MeshInstance3D.new();instance.name='TransparentEllipsoid'
 instance.mesh=st.commit();instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 surface_material=ShaderMaterial.new();surface_material.shader=load('res://assets/materials/dome_sheen.gdshader')
 instance.material_override=surface_material
 add_child(instance)
 update_daylight()

func update_daylight()->void:
 if surface_material==null:return
 # Compatible with staged day/night without changing or owning that controller.
 var amount=clampf(sun.light_energy/0.78,0.0,1.0) if is_instance_valid(sun) else 1.0
 surface_material.set_shader_parameter('daylight',amount)

func _process(_delta:float)->void:update_daylight()
