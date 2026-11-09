extends RefCounted
## Optional, independent visual studies. Explicit calls only; no automatic wiring.
## No inventory, interaction, persistence, physics, lights, audio or wind additions.
const VINE_SPECS = [
 {'shop':'AtlasStand','anchor':Vector3(3.34,3.55,3.48)},
 {'shop':'DanStand','anchor':Vector3(-4.86,3.48,3.00)}
]
const BENCH_LOCAL=Vector3(1.12,-.045,.12)
static func _root(scene:Node3D,label:String)->Node3D:
 var root=Node3D.new();root.name=label;scene.add_child(root)
 root.set_meta('visual_only',true);root.set_meta('review_status','unaccepted_static_study')
 return root
static func _surface()->SurfaceTool:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);return st
static func _triangle(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,tint:Color):
 for p in [a,b,c]:st.set_color(tint);st.add_vertex(p)
static func _box(st:SurfaceTool,p:Vector3,size:Vector3,tint:Color,basis:Basis=Basis.IDENTITY):
 var mesh=BoxMesh.new();mesh.size=size
 for v in mesh.get_faces():st.set_color(tint);st.add_vertex(p+basis*v)
static func _finish(root:Node3D,label:String,st:SurfaceTool)->MeshInstance3D:
 st.generate_normals();var mesh=MeshInstance3D.new();mesh.name=label;mesh.mesh=st.commit()
 var mat=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=.92;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 mesh.material_override=mat;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(mesh);return mesh
static func _budget(root:Node3D,max_triangles:int):
 var triangles=0
 for mesh in root.find_children('*','MeshInstance3D',true,false):triangles+=mesh.mesh.get_faces().size()/3
 root.set_meta('budget',{'triangles':triangles,'meshes':root.find_children('*','MeshInstance3D',true,false).size(),'colliders':0,'lights':0,'audio':0})
 assert(triangles<=max_triangles)
 assert(root.find_children('*','CollisionObject3D',true,false).is_empty())

static func add_facade_vines(scene:Node3D)->Node3D:
 if scene.has_node('Optional034FacadeVines'):return scene.get_node('Optional034FacadeVines')
 var root=_root(scene,'Optional034FacadeVines')
 for spec in VINE_SPECS:
  var shop=scene.get_node('MarketExpansion/'+spec.shop)
  var holder=Node3D.new();holder.name=spec.shop+'Corner';root.add_child(holder);holder.global_transform=shop.global_transform
  var st=_surface();var a:Vector3=spec.anchor
  # A tiny suspended trough makes attachment explicit; no floating strands.
  _box(st,a+Vector3(0,.035,-.04),Vector3(.18,.10,.16),Color('#66583f'))
  for lane in range(2):
   var x=a.x+(lane-.5)*.07;var length=.68+lane*.22
   _box(st,Vector3(x,a.y-length*.5,a.z),Vector3(.008,length,.008),Color('#536744'))
   for leaf in range(7):
    var p=Vector3(x,a.y-.05-leaf*length/7,a.z+.018)
    var side=1.0 if leaf%2==0 else -1.0
    var tip=p+Vector3(side*.075,-.065,.018)
    _triangle(st,p,p+Vector3(side*.04,.025,.025),tip,Color('#61784b'))
    _triangle(st,p,tip,p+Vector3(side*.045,-.04,-.006),Color('#506b42'))
  _finish(holder,'RestrainedCornerCluster',st)
 _budget(root,140);return root

static func add_lived_in_props(scene:Node3D)->Node3D:
 if scene.has_node('Optional035BenchDetail'):return scene.get_node('Optional035BenchDetail')
 var root=_root(scene,'Optional035BenchDetail')
 var bench=scene.get_node('HallGardenBenchEast')
 var holder=Node3D.new();holder.name='EastGardenBenchSide';root.add_child(holder);holder.global_transform=bench.global_transform
 var st=_surface();var p=BENCH_LOCAL
 # One folded cloth and a small empty cup beside, not on the seat or exits.
 _box(st,p+Vector3(0,.018,0),Vector3(.30,.036,.24),Color('#667467'))
 _box(st,p+Vector3(-.035,.065,-.015),Vector3(.23,.058,.19),Color('#8d947a'))
 _box(st,p+Vector3(-.035,.098,-.015),Vector3(.225,.014,.185),Color('#697461'))
 # Original hollow 10-sided ceramic cup: explicit rim and dark interior, no loot ID.
 var cup=p+Vector3(.065,.108,.015);var radius=.045
 for i in range(10):
  var a=TAU*i/10;var b=TAU*(i+1)/10
  var x=Vector3(cos(a)*radius,0,sin(a)*radius);var y=Vector3(cos(b)*radius,0,sin(b)*radius)
  _triangle(st,cup+x,cup+y,cup+y+Vector3.UP*.09,Color('#aa987b'))
  _triangle(st,cup+x,cup+y+Vector3.UP*.09,cup+x+Vector3.UP*.09,Color('#aa987b'))
  _triangle(st,cup+Vector3.UP*.015,cup+y*.78+Vector3.UP*.015,cup+x*.78+Vector3.UP*.015,Color('#403e35'))
 _finish(holder,'FoldedClothAndEmptyCup',st)
 _budget(root,70);return root

static func add_ruin_clues(scene:Node3D)->Node3D:
 if scene.has_node('Optional038RuinClues'):return scene.get_node('Optional038RuinClues')
 var ruins=scene.get_node('RuinedValley');assert(not ruins.supports.is_empty())
 var root=_root(scene,'Optional038RuinClues')
 var support:Dictionary=ruins.supports[0]
 var p:Vector3=support.center+Vector3(-5.5,0,-.2);p.y=support.level
 var st=_surface();var yaw=Basis(Vector3.UP,.17)
 # A fallen weathered lintel and its two displaced mounting stones imply age only.
 _box(st,p+Vector3(0,.17,0),Vector3(3.0,.34,.38),Color('#6d6857'),yaw)
 _box(st,p+Vector3(-1.9,.12,.55),Vector3(.55,.24,.48),Color('#8c9588'),Basis(Vector3.UP,-.2))
 _box(st,p+Vector3(1.65,.15,-.55),Vector3(.50,.30,.48),Color('#959b8e'),Basis(Vector3.UP,.35))
 _finish(root,'FallenLintelAndMountingStones',st)
 root.set_meta('story','Unlabelled collapse; no named history, loot, quest or raid')
 _budget(root,36);return root
