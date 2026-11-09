extends RefCounted
# Original editable reception dressing, derived from the approved lobby/study vocabulary.
# H02 successor moves desk dressing with the compact reception; east wall planting stays.
# Render-only dressing: no new interaction, quest or service.
static func material(color:String,metal=0.0):
 var m=StandardMaterial3D.new();m.albedo_color=Color(color);m.roughness=.78;m.metallic=metal;return m
static func box(r:Node3D,n:String,p:Vector3,size:Vector3,m:Material):
 var v=MeshInstance3D.new();v.name=n;v.position=p;var b=BoxMesh.new();b.size=size;v.mesh=b;v.material_override=m;r.add_child(v);return v
static func tri(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3):
 var points=[a,c,b] if is_equal_approx(a.z,b.z) and is_equal_approx(a.z,c.z) and (b-a).cross(c-a).z>0 else [a,b,c]
 for p in points:st.add_vertex(p)
static func add_to(scene:Node3D):
 var assembly=Node3D.new();assembly.name='HallReceptionAssemblyV098';scene.add_child(assembly)
 var desk=Node3D.new();desk.name='DeskDressing';assembly.add_child(desk)
 var width=preload('res://scripts/hall_reception_v098.gd').WIDTH_SCALE
 desk.position=Vector3(-5*width,0,-3);desk.scale=Vector3(width,1,1)
 var r=desk
 var bronze=material('#8a7047',.58);var rust=material('#874c35');var paper=material('#c7b78c');var ink=material('#40534c');var green=material('#536b3d');green.cull_mode=BaseMaterial3D.CULL_DISABLED
 var dark=material('#45382b');var violet=material('#866a91');violet.cull_mode=BaseMaterial3D.CULL_DISABLED
 # Existing reception front is z=-18.40. Dress the surface, never the customer floor.
 for x in [3.2,4.1,5.9,6.8]:
  box(r,'Reception bronze panel binding',Vector3(x,.81,-18.405),Vector3(.045,.94,.018),bronze)
  for y in [.4,1.21]:box(r,'Panel square bronze peg',Vector3(x,y,-18.389),Vector3(.073,.055,.022),bronze)
 for y in [.34,1.29]:box(r,'Reception dressed edge',Vector3(5,y,-18.405),Vector3(3.8,.035,.018),bronze)
 # An original leaf crest on a shaped rust textile hanging, within the desk envelope.
 var cloth=SurfaceTool.new();cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
 tri(cloth,Vector3(4.65,1.34,-18.375),Vector3(4.65,.48,-18.375),Vector3(5,.31,-18.375))
 tri(cloth,Vector3(4.65,1.34,-18.375),Vector3(5,.31,-18.375),Vector3(5.35,.48,-18.375))
 tri(cloth,Vector3(4.65,1.34,-18.375),Vector3(5.35,.48,-18.375),Vector3(5.35,1.34,-18.375))
 var crest=SurfaceTool.new();crest.begin(Mesh.PRIMITIVE_TRIANGLES)
 box(r,'Banner bronze suspension',Vector3(5,1.335,-18.36),Vector3(.78,.035,.035),bronze)
 box(r,'Leaf stem',Vector3(5,.86,-18.355),Vector3(.018,.57,.012),paper)
 for k in range(3):
  var y=.65+k*.16
  for side in [-1,1]:tri(crest,Vector3(5,y,-18.35),Vector3(5+side*.19,y+.18,-18.35),Vector3(5+side*.055,y+.025,-18.35))
 # A paper folio, bound ledgers and a shallow sorting tray on the existing top (1.40m).
 for i in range(3):
  box(r,'Bound reception ledger',Vector3(6.35,1.425+i*.065,-19.1),Vector3(.54,.055,.36),rust if i%2==0 else ink)
  box(r,'Ledger page block',Vector3(6.35,1.425+i*.065,-18.914),Vector3(.47,.035,.012),paper)
  for x in [6.17,6.52]:box(r,'Ledger spine binding',Vector3(x,1.425+i*.065,-18.902),Vector3(.025,.045,.014),bronze)
 box(r,'Open folio base',Vector3(5.55,1.414,-19.05),Vector3(.66,.024,.44),dark)
 for x in [5.38,5.72]:box(r,'Open folio page',Vector3(x,1.434,-19.05),Vector3(.31,.016,.40),paper)
 for j in range(5):
  box(r,'Folio ruled notation',Vector3(5.70,1.444,-19.19+j*.055),Vector3(.22-j%2*.045,.003,.008),ink)
 for j in range(3):box(r,'Folio botanical sample',Vector3(5.36+j*.045,1.444,-19.14+j*.08),Vector3(.095,.004,.027),green)
 var planting=Node3D.new();planting.name='HallWelcomeDetail';scene.add_child(planting);r=planting
 # Elevated east-wall planting trough, attached to existing wall; nothing on circulation floor.
 box(r,'Wall mounted timber trough',Vector3(8.45,2.65,-19.05),Vector3(.28,.22,2.15),dark)
 for z in [-19.9,-18.2]:
  box(r,'Trough bronze mounting band',Vector3(8.29,2.65,z),Vector3(.028,.27,.09),bronze)
  box(r,'Upper beam hanging strap',Vector3(8.52,3.0,z),Vector3(.035,.68,.065),bronze)
 var leaves=SurfaceTool.new();leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
 var flowers=SurfaceTool.new();flowers.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(12):
  var z=-19.96+i*.165;var length=.30+(i%4)*.13
  box(r,'Fine hanging vine',Vector3(8.24,2.79-length*.5,z),Vector3(.008,length,.008),green)
  for j in range(5):
   var center=Vector3(8.28-.11*sin(j*.55),2.79-length*j/4.0,z+.04*sin(j+i))
   for side in [-1,1]:
    var tip=center+Vector3(-.055,-.08,side*.12)
    tri(leaves,center,center+Vector3(-.055,.035,side*.065),tip)
    tri(leaves,center,tip,center+Vector3(.005,-.04,side*.06))
   if i%3==1 and j>2:
    for k in range(5):
     var a=k*TAU/5;var b=a+.8
     tri(flowers,center+Vector3(-.03,0,0),center+Vector3(-.04,cos(a)*.04,sin(a)*.04),center+Vector3(-.04,cos(b)*.04,sin(b)*.04))
 for entry in [[cloth,rust,'Reception rust hanging'],[crest,paper,'Original leaf crest'],[leaves,green,'Trailing reception greenery'],[flowers,violet,'Small violet accents']]:
  entry[0].generate_normals();var mesh=MeshInstance3D.new();mesh.name=entry[2];mesh.mesh=entry[0].commit();mesh.material_override=entry[1];(desk if entry[2] in ['Reception rust hanging','Original leaf crest'] else planting).add_child(mesh)
 var triangles=0
 for m in r.find_children('*','MeshInstance3D',true,false):triangles+=m.mesh.get_faces().size()/3
 r.set_meta('detail_budget',{'triangles':triangles,'lights':0,'colliders':0})
 preload('res://scripts/hideout_terrace.gd').batch_static_visuals(planting)
 preload('res://scripts/hideout_terrace.gd').batch_static_visuals(desk)
