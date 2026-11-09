extends Node3D
## Original scenic-only isolated study. Requires existing ValleyBackdrop terrain sampler.
var vertices := PackedVector3Array()
var colors := PackedColorArray()
var triangles := 0
var supports: Array[Dictionary] = []
var falls: Array[Dictionary] = []
var backdrop: Node3D

static func add_to(scene: Node3D) -> Node3D:
 if scene.has_node('RuinedValley'): return scene.get_node('RuinedValley')
 var terrain = scene.get_node_or_null('ValleyBackdrop')
 assert(terrain != null and terrain.has_method('terrain_height'))
 var study = load('res://scripts/ruined_valley.gd').new()
 study.name = 'RuinedValley'
 study.backdrop = terrain
 scene.add_child(study)
 study.build()
 return study

func tri(a: Vector3,b: Vector3,c: Vector3,tint: Color):
 vertices.append_array(PackedVector3Array([a,b,c]))
 colors.append_array(PackedColorArray([tint,tint,tint]))

func quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,tint:Color):
 tri(a,b,c,tint);tri(a,c,d,tint)

func flush(label:String,shader:Shader = null):
 if vertices.is_empty():return
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in vertices.size():
  st.set_color(colors[i]);st.add_vertex(vertices[i])
 st.generate_normals()
 var node=MeshInstance3D.new();node.name=label;node.mesh=st.commit()
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 if shader:
  var mat=ShaderMaterial.new();mat.shader=shader;node.material_override=mat
 else:
  var mat=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true
  mat.roughness=1.0;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
  node.material_override=mat
 add_child(node);triangles+=vertices.size()/3;vertices.clear();colors.clear()

func shelf(center:Vector3,radius:float,rise:float)->float:
 var feet: Array[Vector3]=[]
 var top: Array[Vector3]=[]
 var level=-100.0
 for i in 12:
  var a=TAU*i/12.0
  var r=radius*(1.0+0.09*sin(i*2.3))
  var p=center+Vector3(cos(a)*r,0,sin(a)*r)
  p.y=backdrop.terrain_height(p.x,p.z)-0.35
  feet.append(p);level=maxf(level,p.y)
 level+=rise
 for i in 12:
  var p=feet[i];var d=Vector3(p.x-center.x,0,p.z-center.z)*0.67
  top.append(Vector3(center.x+d.x,level,center.z+d.z))
 for i in 12:
  var j=(i+1)%12
  quad(feet[i],feet[j],top[j],top[i],Color('63706b').darkened(0.035*(i%3)))
  tri(Vector3(center.x,level,center.z),top[i],top[j],Color('65766b'))
 supports.append({'center':center,'feet':feet,'top':top,'level':level})
 return level

func wall(origin:Vector3,width:float,height:float,angle:float,variant:int):
 # Closed extruded irregular crest. Authored missing sections are separate wall fragments.
 var profile=[Vector2(-0.5,0),Vector2(0.5,0),Vector2(0.5,0.56),Vector2(0.26,0.66),Vector2(0.15,0.91),Vector2(-0.03,0.79),Vector2(-0.19,1.0),Vector2(-0.5,0.71)]
 var front: Array[Vector3]=[];var back: Array[Vector3]=[]
 for p in profile:
  var v=Vector3(p.x*width,p.y*height,0)
  front.append(origin+(v+Vector3(0,0,0.25)).rotated(Vector3.UP,angle))
  back.append(origin+(v-Vector3(0,0,0.25)).rotated(Vector3.UP,angle))
 var tint=Color('a0a69b').darkened(0.055*(variant%3))
 # Polygon triangulation handles broken nonconvex top safely.
 var poly=PackedVector2Array(profile);var indices=Geometry2D.triangulate_polygon(poly)
 for i in range(0,indices.size(),3):
  tri(front[indices[i]],front[indices[i+1]],front[indices[i+2]],tint)
  tri(back[indices[i+2]],back[indices[i+1]],back[indices[i]],tint.darkened(0.08))
 for i in profile.size():
  var j=(i+1)%profile.size();quad(front[i],back[i],back[j],front[j],tint.darkened(0.12))

func hamlet(center:Vector3,level:float,secondary:bool):
 var offsets=[Vector2(-7,-3),Vector2(1,-5),Vector2(6,2)] if not secondary else [Vector2(-4,0),Vector2(4,3)]
 for i in offsets.size():
  var p=center+Vector3(offsets[i].x,0,offsets[i].y);p.y=level-0.05
  var angle=0.17+i*0.61
  wall(p,4.8,3.6+i*0.65,angle,i)
  wall(p+Vector3(-1.7,0,1.4).rotated(Vector3.UP,angle),2.6,2.8,angle+PI/2,i+1)
  wall(p+Vector3(1.9,0,1.1).rotated(Vector3.UP,angle),1.4,1.6,angle+PI/2,i+2)
 # An isolated taller broken gable gives each cluster an unequal silhouette, not an active tower.
 wall(Vector3(center.x-3,level-0.05,center.z-8),3.1,6.1 if not secondary else 4.7,-0.4,2)

func edge_point(polygon:Array,center:Vector3,direction:Vector3)->Vector3:
 var start=Vector2(center.x,center.z);var end=start+Vector2(direction.x,direction.z)*100.0
 for i in polygon.size():
  var a:Vector3=polygon[i];var b:Vector3=polygon[(i+1)%polygon.size()]
  var hit=Geometry2D.segment_intersects_segment(start,end,Vector2(a.x,a.z),Vector2(b.x,b.z))
  if hit is Vector2:
   var t=Vector2(a.x,a.z).distance_to(hit)/Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))
   return Vector3(hit.x,lerpf(a.y,b.y,t),hit.y)
 assert(false,'No support-edge intersection');return center

func waterfall(center:Vector3,top_y:float):
 var toward=Vector3(-center.x,0,-center.z).normalized()
 var across=toward.cross(Vector3.UP)
 var lip=edge_point(supports[0].top,center,toward)+toward*0.10+Vector3.UP*0.03
 var foot=edge_point(supports[0].feet,center,toward)+toward*0.12+Vector3.UP*0.40
 # Water follows slanted face; source and basin are explicit contiguous geometry.
 var source=lip-toward*4.5
 quad(source-across*1.8,source+across*1.8,lip+across*1.4,lip-across*1.4,Color.WHITE)
 var landing=foot+toward*2.0
 for i in 12:
  var t0=i/12.0;var t1=(i+1)/12.0
  var a=lip.lerp(foot,t0)+toward*(sin(t0*PI)*0.4)
  var b=lip.lerp(foot,t1)+toward*(sin(t1*PI)*0.4)
  quad(a-across*1.4,a+across*1.4,b+across*1.7,b-across*1.7,Color.WHITE)
 quad(foot-across*1.7,foot+across*1.7,landing+across*2.5,landing-across*2.5,Color.WHITE)
 falls.append({'lip':lip,'foot':foot,'source':source})
 flush('CliffFedWater',preload('res://assets/materials/distant_waterfall.gdshader'))

func build():
 var main=Vector3(145,0,-95);var second=Vector3(-150,0,125)
 var main_y=shelf(main,25.0,13.0)
 var second_y=shelf(second,21.0,7.0)
 flush('ScenicRockShoulders')
 hamlet(main,main_y,false);hamlet(second,second_y,true)
 flush('AbandonedRooflessHamlets')
 waterfall(main,main_y)
 set_meta('triangle_count',triangles)
 set_meta('scenic_only',true)

# Optional loading-successor coroutines; original synchronous methods above are unchanged.
static func add_to_staged(scene: Node3D) -> Node3D:
 if scene.has_node('RuinedValley'): return scene.get_node('RuinedValley')
 var terrain = scene.get_node_or_null('ValleyBackdrop')
 assert(terrain != null and terrain.has_method('terrain_height'))
 var study = load('res://scripts/ruined_valley.gd').new()
 study.name = 'RuinedValley'
 study.backdrop = terrain
 scene.add_child(study)
 await study.build_staged(scene)
 if scene.startup_cancel_requested:return null
 return study

func flush_staged(scene:Node3D,label:String,shader:Shader = null):
 if vertices.is_empty():return
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in vertices.size():
  if i%96==0 and await scene._startup_checkpoint("ruined valley surface vertices %d"%i):return
  st.set_color(colors[i]);st.add_vertex(vertices[i])
 if await scene._startup_checkpoint("ruined valley generate normals"):return
 st.generate_normals()
 if await scene._startup_checkpoint("ruined valley mesh commit"):return
 var node=MeshInstance3D.new();node.name=label;node.mesh=st.commit()
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 if shader:
  var mat=ShaderMaterial.new();mat.shader=shader;node.material_override=mat
 else:
  var mat=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true
  mat.roughness=1.0;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
  node.material_override=mat
 add_child(node);triangles+=vertices.size()/3;vertices.clear();colors.clear()
 if await scene._startup_checkpoint("ruined valley surface committed"):return

func shelf_staged(scene:Node3D,center:Vector3,radius:float,rise:float)->float:
 var feet: Array[Vector3]=[]
 var top: Array[Vector3]=[]
 var level=-100.0
 for i in 12:
  if await scene._startup_checkpoint("ruined valley shelf sample %d"%i):return 0.0
  var a=TAU*i/12.0
  var r=radius*(1.0+0.09*sin(i*2.3))
  var p=center+Vector3(cos(a)*r,0,sin(a)*r)
  p.y=backdrop.terrain_height(p.x,p.z)-0.35
  feet.append(p);level=maxf(level,p.y)
 level+=rise
 for i in 12:
  if await scene._startup_checkpoint("ruined valley shelf sample %d"%i):return 0.0
  var p=feet[i];var d=Vector3(p.x-center.x,0,p.z-center.z)*0.67
  top.append(Vector3(center.x+d.x,level,center.z+d.z))
 for i in 12:
  if await scene._startup_checkpoint("ruined valley shelf sample %d"%i):return 0.0
  var j=(i+1)%12
  quad(feet[i],feet[j],top[j],top[i],Color('63706b').darkened(0.035*(i%3)))
  tri(Vector3(center.x,level,center.z),top[i],top[j],Color('65766b'))
 supports.append({'center':center,'feet':feet,'top':top,'level':level})
 return level

func hamlet_staged(scene:Node3D,center:Vector3,level:float,secondary:bool):
 var offsets=[Vector2(-7,-3),Vector2(1,-5),Vector2(6,2)] if not secondary else [Vector2(-4,0),Vector2(4,3)]
 for i in offsets.size():
  if await scene._startup_checkpoint("ruined valley hamlet %d"%i):return
  var p=center+Vector3(offsets[i].x,0,offsets[i].y);p.y=level-0.05
  var angle=0.17+i*0.61
  wall(p,4.8,3.6+i*0.65,angle,i)
  wall(p+Vector3(-1.7,0,1.4).rotated(Vector3.UP,angle),2.6,2.8,angle+PI/2,i+1)
  wall(p+Vector3(1.9,0,1.1).rotated(Vector3.UP,angle),1.4,1.6,angle+PI/2,i+2)
 # An isolated taller broken gable gives each cluster an unequal silhouette, not an active tower.
 wall(Vector3(center.x-3,level-0.05,center.z-8),3.1,6.1 if not secondary else 4.7,-0.4,2)

func waterfall_staged(scene:Node3D,center:Vector3,top_y:float):
 var toward=Vector3(-center.x,0,-center.z).normalized()
 var across=toward.cross(Vector3.UP)
 var lip=edge_point(supports[0].top,center,toward)+toward*0.10+Vector3.UP*0.03
 var foot=edge_point(supports[0].feet,center,toward)+toward*0.12+Vector3.UP*0.40
 # Water follows slanted face; source and basin are explicit contiguous geometry.
 var source=lip-toward*4.5
 quad(source-across*1.8,source+across*1.8,lip+across*1.4,lip-across*1.4,Color.WHITE)
 var landing=foot+toward*2.0
 for i in 12:
  if await scene._startup_checkpoint("ruined valley waterfall %d"%i):return
  var t0=i/12.0;var t1=(i+1)/12.0
  var a=lip.lerp(foot,t0)+toward*(sin(t0*PI)*0.4)
  var b=lip.lerp(foot,t1)+toward*(sin(t1*PI)*0.4)
  quad(a-across*1.4,a+across*1.4,b+across*1.7,b-across*1.7,Color.WHITE)
 quad(foot-across*1.7,foot+across*1.7,landing+across*2.5,landing-across*2.5,Color.WHITE)
 falls.append({'lip':lip,'foot':foot,'source':source})
 await flush_staged(scene,'CliffFedWater',preload('res://assets/materials/distant_waterfall.gdshader'))

func build_staged(scene:Node3D):
 var main=Vector3(145,0,-95);var second=Vector3(-150,0,125)
 var main_y=await shelf_staged(scene,main,25.0,13.0)
 if scene.startup_cancel_requested:return
 var second_y=await shelf_staged(scene,second,21.0,7.0)
 if scene.startup_cancel_requested:return
 await flush_staged(scene,'ScenicRockShoulders')
 if scene.startup_cancel_requested:return
 await hamlet_staged(scene,main,main_y,false)
 if scene.startup_cancel_requested:return
 await hamlet_staged(scene,second,second_y,true)
 if scene.startup_cancel_requested:return
 await flush_staged(scene,'AbandonedRooflessHamlets')
 if scene.startup_cancel_requested:return
 await waterfall_staged(scene,main,main_y)
 if scene.startup_cancel_requested:return
 set_meta('triangle_count',triangles)
 set_meta('scenic_only',true)
