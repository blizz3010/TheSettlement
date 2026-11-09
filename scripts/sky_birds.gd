extends Node3D
## Distinct decorative flight silhouettes. Existing hopping birds/squirrels untouched.
const BIRD_COUNT := 5
const SHELL = preload('res://scripts/dome_surface.gd')
var elapsed := 0.0
var birds:Array[Dictionary]=[]

static func routes()->Array:
 return [
  {'radius':21.0,'height':24.0,'period':39.0,'phase':0.3,'inside':true,'scale':0.85},
  {'radius':24.0,'height':22.5,'period':47.0,'phase':3.4,'inside':true,'scale':0.75},
  {'radius':77.0,'height':33.0,'period':91.0,'phase':1.4,'inside':false,'scale':1.3},
  {'radius':88.0,'height':38.0,'period':109.0,'phase':3.7,'inside':false,'scale':1.5},
  {'radius':94.0,'height':30.0,'period':123.0,'phase':5.4,'inside':false,'scale':1.35}
 ]

static func sample(spec:Dictionary,seconds:float)->Dictionary:
 var a=seconds*TAU/spec.period+spec.phase
 var p=Vector3(cos(a)*spec.radius,spec.height+sin(a*2.0)*1.2,sin(a)*spec.radius)
 var tangent=Vector3(-sin(a)*spec.radius,cos(a*2.0)*2.4,cos(a)*spec.radius).normalized()
 # Smooth flutter bursts with genuinely motionless-wing glide intervals.
 var burst=fposmod(seconds+spec.phase*3.0,12.0)
 var envelope=smoothstep(0.0,0.5,burst)*(1.0-smoothstep(2.4,3.0,burst))
 var wing_angle=0.10+sin(seconds*TAU*2.6+spec.phase)*0.52*envelope
 return {'position':p,'tangent':tangent,'wing':wing_angle,'gliding':burst>=3.0,'bank':-0.12}

static func add_to(scene:Node3D)->Node3D:
 if scene.has_node('SkyBirds'):return scene.get_node('SkyBirds')
 var root=load('res://scripts/sky_birds.gd').new();root.name='SkyBirds';scene.add_child(root)
 root.build();return root

static func polygon(points:Array,material:Material)->MeshInstance3D:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var outline=PackedVector2Array()
 var vertical=true
 for point in points:
  if absf(point.x)>0.001:vertical=false
 for point in points:outline.append(Vector2(point.z,point.y) if vertical else Vector2(point.x,point.z))
 var indices=Geometry2D.triangulate_polygon(outline)
 assert(indices.size()==(points.size()-2)*3,'Bird silhouette triangulation failed')
 for index in indices:st.add_vertex(points[index])
 st.generate_normals()
 var instance=MeshInstance3D.new();instance.mesh=st.commit();instance.material_override=material
 instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return instance

func build()->void:
 var mat=StandardMaterial3D.new();mat.albedo_color=Color('384746');mat.roughness=1.0;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 for spec in routes():
  var bird=Node3D.new();bird.name='InsideBird' if spec.inside else 'OutsideBird';add_child(bird)
  bird.scale=Vector3.ONE*spec.scale
  # Tapered body/head/beak and forked tail; pointed swept wings, not flying balls.
  bird.add_child(polygon([Vector3(0,0,-.48),Vector3(.09,0,-.22),Vector3(.085,0,.23),Vector3(.17,0,.48),Vector3(0,0,.37),Vector3(-.17,0,.48),Vector3(-.085,0,.23),Vector3(-.09,0,-.22)],mat))
  bird.add_child(polygon([Vector3(0,0,-.43),Vector3(0,.10,-.18),Vector3(0,.07,.23),Vector3(0,0,.42),Vector3(0,-.06,.1)],mat))
  var wings=[]
  for side in [-1,1]:
   var wing=Node3D.new();wing.name='Wing';bird.add_child(wing)
   wing.add_child(polygon([Vector3(0,0,-.18),Vector3(side*.36,0,-.22),Vector3(side*.82,0,.05),Vector3(side*1.05,0,.34),Vector3(side*.60,0,.26),Vector3(side*.20,0,.12),Vector3(0,0,.17)],mat))
   wings.append(wing)
  birds.append({'root':bird,'wings':wings,'spec':spec})
 advance(0.0)

func advance(delta:float)->void:
 if not is_finite(delta) or delta<0.0:return
 elapsed+=delta
 for item in birds:
  var state=sample(item.spec,elapsed)
  item.root.position=state.position
  item.root.basis=Basis.looking_at(state.tangent,Vector3.UP).rotated(state.tangent,state.bank).scaled(Vector3.ONE*item.spec.scale)
  item.wings[0].rotation.z=state.wing
  item.wings[1].rotation.z=-state.wing

func _process(delta:float)->void:advance(delta)
