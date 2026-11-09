extends RefCounted
# Original editable reference-led visual overlay. No collision, water/audio, save or gameplay changes.
static func mat(color:Color,metal=0.0)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=color;m.metallic=metal;m.roughness=.72;return m
static func box(root:Node3D,n:String,p:Vector3,size:Vector3,m:Material):
 var node=MeshInstance3D.new();node.name=n;var mesh=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.position=p;node.material_override=m;root.add_child(node);return node
static func leaf(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3):
 # Double-sided foliage material; simple folded, deliberately low leaves.
 var ordered=[a,c,b] if (b-a).cross(c-a).y>0 else [a,b,c]
 for p in ordered:st.add_vertex(p)
static func add_to(scene:Node3D):
 var root=Node3D.new();root.name='FountainConstructionDetail';scene.add_child(root)
 var dark=mat(Color('#343c32'))
 var bronze=ShaderMaterial.new();bronze.shader=preload('res://assets/materials/courtyard_surface.gdshader')
 bronze.set_shader_parameter('tint',Color(.32,.265,.19));bronze.set_shader_parameter('metallic',.64);bronze.set_shader_parameter('roughness',.61);bronze.set_shader_parameter('variation',.24);bronze.set_shader_parameter('grain_scale',24.0);bronze.set_shader_parameter('bump_strength',.018);bronze.set_shader_parameter('patina',.30)
 var stone=ShaderMaterial.new();stone.shader=bronze.shader
 stone.set_shader_parameter('tint',Color(.43,.412,.375));stone.set_shader_parameter('roughness',.83);stone.set_shader_parameter('variation',.25);stone.set_shader_parameter('grain_scale',16.0);stone.set_shader_parameter('bump_strength',.032)
 var green=mat(Color('#596e45'));green.cull_mode=BaseMaterial3D.CULL_DISABLED
 var violet=mat(Color('#8a668d'));violet.cull_mode=BaseMaterial3D.CULL_DISABLED
 # Four small dressed spillway throats align to existing water ribbons; water itself is untouched.
 for i in range(4):
  # Blender +Y exports as Godot -Z.
  var a=-(i*3+.25)*TAU/12;var mount=Node3D.new();mount.name='Dressed spillway throat';root.add_child(mount);mount.rotation.y=-a+PI/2
  box(mount,'Spillway dark recess',Vector3(0,1.015,1.369),Vector3(.19,.13,.016),dark)
  for x in [-.118,.118]:box(mount,'Spillway stone cheek',Vector3(x,1.025,1.31),Vector3(.06,.20,.17),stone)
  box(mount,'Spillway bronze lintel',Vector3(0,1.105,1.365),Vector3(.29,.035,.075),bronze)
  box(mount,'Spillway projecting lower lip',Vector3(0,.947,1.36),Vector3(.24,.025,.10),bronze)
 # Tiny maintenance plates seated into the existing middle stone course, below the coping.
 for i in range(4):
  var a=(i+.5)*TAU/4;var plate=Node3D.new();plate.name='Masonry repair binding';root.add_child(plate);plate.rotation.y=-a+PI/2
  box(plate,'Seated bronze binding',Vector3(0,.33,2.813),Vector3(.17,.145,.012),bronze)
  for x in [-.055,.055]:box(plate,'Binding square pin',Vector3(x,.33,2.824),Vector3(.025,.025,.014),dark)
 # Three low integrated masonry pockets. All leaves stay over the existing basin rim.
 var foliage=SurfaceTool.new();foliage.begin(Mesh.PRIMITIVE_TRIANGLES);foliage.set_smooth_group(-1)
 var blooms=SurfaceTool.new();blooms.begin(Mesh.PRIMITIVE_TRIANGLES);blooms.set_smooth_group(-1)
 var angles=[.25*PI,.86*PI,1.48*PI]
 for k in range(3):
  var a:float=angles[k];var radial=Vector3(cos(a),0,sin(a));var tangent=Vector3(-sin(a),0,cos(a));var center=radial*2.645+Vector3.UP*.707
  var pocket=Node3D.new();pocket.name='Low rim masonry planting pocket';root.add_child(pocket);pocket.position=center;pocket.rotation.y=-a+PI/2
  var width=.53-k*.045
  box(pocket,'Inset pocket soil',Vector3(0,.009,0),Vector3(width-.055,.018,.25),dark)
  for side in [-1,1]:
   box(pocket,'Pocket low limestone long edge',Vector3(0,.0125,side*.14),Vector3(width,.035,.035),stone)
   box(pocket,'Pocket limestone end',Vector3(side*(width/2-.0175),.0125,0),Vector3(.035,.035,.25),stone)
  for j in range(5+k):
   var seed=center+tangent*((j%3-1)*.10)+radial*((j%2-.5)*.08)+Vector3.UP*.020
   for n in range(5):
    var angle=n*TAU/5+j*.8;var d=tangent*cos(angle)+radial*sin(angle);var across=Vector3(-d.z,0,d.x)
    var mid=seed+d*.075+Vector3.UP*(.13+(j%2)*.035);var tip=seed+d*.16+Vector3.UP*.08
    leaf(foliage,seed,mid-across*.027,mid+across*.027);leaf(foliage,mid-across*.027,tip,mid+across*.027)
   if j%2==0:
    var flower=seed+Vector3.UP*(.19+(j%3)*.018)
    for axis in [tangent,radial]:
     leaf(foliage,seed-axis*.004,flower-axis*.004,flower+axis*.004)
     leaf(foliage,seed-axis*.004,flower+axis*.004,seed+axis*.004)
    for n in range(5):
     var a0=n*TAU/5;var d0=tangent*cos(a0)+radial*sin(a0);var d1=tangent*cos(a0+.75)+radial*sin(a0+.75)
     leaf(blooms,flower,flower+d0*.043+Vector3.UP*.015,flower+d1*.043+Vector3.UP*.015)
 for data in [[foliage,green,'Low folded rim herbs'],[blooms,violet,'Restrained violet rim flowers']]:
  data[0].generate_normals();var mesh=MeshInstance3D.new();mesh.name=data[2];mesh.mesh=data[0].commit();mesh.material_override=data[1];root.add_child(mesh)
 var triangles=0;var max_radius=0.0;var max_y=0.0
 for mesh in root.find_children('*','MeshInstance3D',true,false):
  triangles+=mesh.mesh.get_faces().size()/3
  var transform=root.global_transform.affine_inverse()*mesh.global_transform
  for p in mesh.mesh.get_faces():
   var v=transform*p;max_radius=maxf(max_radius,Vector2(v.x,v.z).length());max_y=maxf(max_y,v.y)
 root.set_meta('detail_budget',{'triangles':triangles,'max_radius':max_radius,'max_height':max_y,'new_lights':0,'new_collisions':0})
 assert(max_radius<=2.90 and max_y<=1.16,'Details must remain inside existing basin envelope')
 preload('res://scripts/hideout_terrace.gd').batch_static_visuals(root)
