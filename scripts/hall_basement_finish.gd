extends RefCounted
const LAYER=4096
const Layout=preload("res://scripts/hall_shared_stair_layout.gd")
static func plain(c:Color,metal=0.0):
 var m=StandardMaterial3D.new();m.albedo_color=c;m.roughness=.76;m.metallic=metal;return m
static func stone(c:Color):
 var m=ShaderMaterial.new();m.shader=preload('res://assets/materials/courtyard_surface.gdshader');m.set_shader_parameter('tint',c);m.set_shader_parameter('roughness',.83);m.set_shader_parameter('variation',.22);m.set_shader_parameter('grain_scale',16.0);m.set_shader_parameter('bump_strength',.025);return m
static func box(r:Node3D,n:String,p:Vector3,size:Vector3,m:Material):
 var v=MeshInstance3D.new();v.name=n;v.position=p;var b=BoxMesh.new();b.size=size;v.mesh=b;v.material_override=m;v.layers=LAYER;r.add_child(v);return v
static func beam(r:Node3D,a:Vector3,b:Vector3,width:float,m:Material):
 var v=box(r,'Continuous timber rail',(a+b)*.5,Vector3(width,a.distance_to(b),width),m);v.basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()));return v
static func rail(r:Node3D,a:Vector3,b:Vector3,m:Material,bronze:Material):
 beam(r,a+Vector3.UP*1.04,b+Vector3.UP*1.04,.10,m)
 beam(r,a+Vector3.UP*.22,b+Vector3.UP*.22,.055,m)
 var count=ceili(a.distance_to(b)/.70)
 for i in range(count+1):
  var p=a.lerp(b,float(i)/count)
  box(r,'Rail upright',p+Vector3.UP*.55,Vector3(.065,1.1,.065),m)
  box(r,'Rail bronze socket',p+Vector3.UP*.10,Vector3(.085,.17,.085),bronze)
static func add_to(scene:Node3D):
 var old=scene.get_node('HallBasementBlockout');var r=Node3D.new();r.name='HallBasementFinish';scene.add_child(r)
 var floor=stone(Color('#a19479'));var wall=stone(Color('#91846d'));var limestone=stone(Color('#b4a68a'))
 var timber=plain(Color('#554333'));var bronze=plain(Color('#8a714d'),.63);var dark=plain(Color('#4b4a3f'))
 var glow=plain(Color('#e6bb75'));glow.emission_enabled=true;glow.emission=Color('#ffc984');glow.emission_energy_multiplier=1.0
 # Refinish only basement blockout visuals, never their collision parents or transforms.
 for m in old.find_children('*','MeshInstance3D',true,false):
  m.layers=LAYER
  if m.mesh is BoxMesh:
   var size=m.mesh.size;var at=m.global_position
   if m.get_parent()==old and is_equal_approx(size.y,.6):continue # Direct split-terrain children keep original material at any new hole width.
   m.material_override=wall
   if at.y< -3.5:m.material_override=floor
   if is_equal_approx(size.y,.15):
    # Raise visible ceiling infill inside the validated collision envelope; beams finish at-.80.
    var cube=BoxMesh.new();cube.size=Vector3(size.x,.05,size.z);m.mesh=cube;m.position.y+=.05;m.material_override=timber
   elif is_equal_approx(size.y,1.1):
    m.visible=false
    var a=at-Vector3(0,.55,0);var b=a
    if size.x>size.z:a.x-=size.x*.5;b.x+=size.x*.5
    else:a.z-=size.z*.5;b.z+=size.z*.5
    rail(r,a,b,timber,bronze)
   elif is_equal_approx(size.y,.17):m.material_override=timber
  else:
   # Hide only guard proxy faces; retain actual narrow timber stringer visuals.
   m.material_override=wall
   var parent=m.get_parent()
   if parent is StaticBody3D and parent.get_meta('stair_guard',false):m.visible=false
   elif parent is StaticBody3D and parent.get_meta('slim_stair_stringer',false):m.material_override=timber
 # Four sloping guard runs share the exact candidate collision endpoints.
 for a in Layout.SLOPING_GUARDS:rail(r,Vector3(a[0],a[3],a[1]),Vector3(a[0],a[4],a[2]),timber,bronze)
 # Floor stone joints lie flush; no step-height or footstep-surface changes.
 for x in range(-8,9):box(r,'Limestone floor joint',Vector3(x,-3.498,-23),Vector3(.012,.002,16.8),dark)
 for z in range(-31,-14):box(r,'Limestone cross joint',Vector3(0,-3.498,z),Vector3(16.8,.002,.012),dark)
 # Wall frame rhythm stays in the existing solid wall thickness, outside all clear lanes.
 for x in [-8.38,8.38]:
  for z in [-30.6,-26.8,-23,-19.2,-15.4]:
   box(r,'Wall timber pilaster',Vector3(x,-2.15,z),Vector3(.08,2.7,.16),timber)
   for y in [-3.28,-1.0]:box(r,'Bronze wall shoe',Vector3(x,y,z),Vector3(.09,.22,.22),bronze)
  for y in [-3.34,-1.02]:box(r,'Wall limestone course',Vector3(x,y,-23),Vector3(.045,.08,16.8),limestone)
 for z in [-31.38,-14.62]:
  for x in [-7.5,-3.7,0,3.7,7.5]:box(r,'End wall timber pilaster',Vector3(x,-2.15,z),Vector3(.16,2.7,.08),timber)
 # Beams remain within ceiling collision thickness, with the original2.70m visual clearance.
 for z in [-30,-26,-22,-18,-15]:
  # Avoid the open stairwell; never create a crossbeam above the rising stairs.
  var spans=[Vector2(-8.4,8.4)]
  if z+.08>Layout.HOLE.position.y and z-.08<Layout.HOLE.end.y:spans=[Vector2(-8.4,Layout.HOLE.position.x),Vector2(Layout.HOLE.end.x,8.4)]
  for span in spans:
   box(r,'Ceiling crossbeam',Vector3((span.x+span.y)*.5,-.75,z),Vector3(span.y-span.x,.10,.16),timber)
   for x in [-3.3,0,3.3,7.9]:
    if x-.125>=span.x and x+.125<=span.y:box(r,'Ceiling bronze joint',Vector3(x,-.775,z),Vector3(.25,.05,.22),bronze)
 # Four flush amber ceiling practicals; local lamps affect only this layer, never upstairs/world geometry.
 for x in [-4,4]:
  for z in [-18.5,-29.4]:
   box(r,'Flush practical bronze frame',Vector3(x,-.76,z),Vector3(.68,.08,.22),bronze)
   box(r,'Flush amber practical diffuser',Vector3(x,-.802,z),Vector3(.56,.008,.13),glow)
   var light=OmniLight3D.new();light.name='Basement bounded amber';light.position=Vector3(x,-1.05,z);light.light_color=Color('#ffd6a0');light.light_energy=1.25;light.omni_range=8;light.omni_attenuation=1.3;light.shadow_enabled=false;light.light_cull_mask=LAYER;r.add_child(light)
 # One small wall practical makes the turning landing legible without spilling into the Hall.
 box(r,'Landing bronze lamp back',Vector3(-8.335,-.75,Layout.TURN_CENTER.z),Vector3(.09,.55,.24),bronze)
 box(r,'Landing amber diffuser',Vector3(-8.279,-.75,Layout.TURN_CENTER.z),Vector3(.018,.40,.14),glow)
 var light=OmniLight3D.new();light.name='Landing bounded amber';light.position=Vector3(-7.7,-.55,Layout.TURN_CENTER.z);light.light_color=Color('#ffd6a0');light.light_energy=.85;light.omni_range=4.5;light.shadow_enabled=false;light.light_cull_mask=LAYER;r.add_child(light)
 # Terrain replacement visual is not a basement surface; restore its original rendering layer.
 for m in old.get_children():
  if m is MeshInstance3D and m.mesh is BoxMesh and is_equal_approx(m.mesh.size.y,.6):m.layers=1
 preload('res://scripts/hideout_terrace.gd').batch_static_visuals(r)
 for v in r.find_children('*','GeometryInstance3D',true,false):v.layers=LAYER
 r.set_meta('lighting_budget',{'lights':5,'shadow_lights':0,'cull_mask':LAYER,'world_lighting_changed':false})
