extends RefCounted
const CENTER=Vector3(22,0,-16)
const SOURCE="res://assets/source/launchpad_ship/"
static func body(parent:Node3D,label:String,surface:String)->StaticBody3D:
 var b=StaticBody3D.new();b.name=label;b.set_meta('audio_surface',surface);parent.add_child(b);return b
static func shape(b:StaticBody3D,s:Shape3D,pos=Vector3.ZERO):
 var c=CollisionShape3D.new();c.shape=s;c.position=pos;b.add_child(c)
static func box(parent:Node3D,label:String,pos:Vector3,size:Vector3,surface:String):
 var b=body(parent,label,surface);b.position=pos;var s=BoxShape3D.new();s.size=size;shape(b,s);return b
static func convex(parent:Node3D,label:String,points:PackedVector3Array,surface:String):
 var b=body(parent,label,surface);var s=ConvexPolygonShape3D.new();s.points=points;shape(b,s);return b
static func segment(parent:Node3D,label:String,a:Vector3,b:Vector3,width:float,height:float,surface:String):
 var c=box(parent,label,(a+b)/2,Vector3(width,height,a.distance_to(b)),surface)
 c.basis=Basis.looking_at(b-a,Vector3.UP)
 return c
static func add_to(scene:Node3D):
 var root=Node3D.new();root.name='LaunchpadShip';root.position=CENTER;scene.add_child(root)
 var art=load('res://assets/kit/launchpad_ship.glb').instantiate();art.name='Art';root.add_child(art)
 var coll=Node3D.new();coll.name='Collision';root.add_child(coll)
 var pad=CylinderShape3D.new();pad.radius=7.90;pad.height=1.28;shape(body(coll,'PadDeck','stone'),pad,Vector3(0,.64,0))
 var data=JSON.parse_string(FileAccess.get_file_as_string(SOURCE+'collision_geometry.json'))
 for item in data.original_mesh_convexes:
  var pts=PackedVector3Array()
  for p in item.points:pts.append(Vector3(p[0],p[1],p[2]))
  convex(coll,item.name,pts,item.surface)
 for i in range(32):
  if i in [23,24]:continue
  var a=TAU*i/32;var b=TAU*(i+1)/32
  segment(coll,'EdgeRail%02d'%i,Vector3(cos(a)*7.65,1.80,-sin(a)*7.65),Vector3(cos(b)*7.65,1.80,-sin(b)*7.65),.09,1.1,'metal')
 for x in [-1.56,1.56]:
  var pts=PackedVector3Array()
  for xx in [x-.04,x+.04]:
   for zz in [7.4,13.8]:
    var y=1.28 if zz==7.4 else .025
    pts.append(Vector3(xx,y,zz));pts.append(Vector3(xx,y+1.1,zz))
  convex(coll,'RampRail',pts,'metal')
 box(coll,'ApproachStub',Vector3(0,-.015,16.3),Vector3(3.2,.08,5),'stone')
 # South-east connector bypasses current shop, preserves future expanded hall.
 var points=[Vector3(5.2,.025,7.8),Vector3(11,.025,10),Vector3(22,.025,10),Vector3(22,.025,2.8)]
 var path_root=Node3D.new();path_root.name='LaunchpadApproach';scene.add_child(path_root)
 var mat=StandardMaterial3D.new();mat.albedo_color=Color(.46,.44,.38);mat.roughness=1
 for i in range(points.size()-1):
  var width=2.2 if i==0 else 3.2
  var b=segment(path_root,'StoneConnector%d'%i,points[i]-Vector3(0,.04,0),points[i+1]-Vector3(0,.04,0),width,.08,'stone')
  var mesh=MeshInstance3D.new();var cube=BoxMesh.new();cube.size=b.get_child(0).shape.size;mesh.mesh=cube;mesh.material_override=mat;b.add_child(mesh)
 preload('res://scripts/ship_pad_finish_v094.gd').apply(root)
 preload('res://scripts/ship_construction_v096.gd').apply(root)
 # DayNightCycle is created after build_world. Asset preparation owns installation.
 root.set_meta('ship_route_lighting_v097',{'ok':false,'pending':true,'reason':'Waiting for asset preparation'})
 root.set_meta('collision_bodies',coll.get_child_count())
 return root
static func reconcile_border(scene:Node3D):
 var holder=scene.get_node('NaturalBorder');var changes=[]
 for batch in holder.get_children():
  var mm=batch.multimesh;var ts=batch.get_meta('source_transforms')
  for i in range(mm.instance_count):
   var t=ts[i];var bounds=t*mm.mesh.get_aabb()
   var nearest=Vector2(clampf(CENTER.x,bounds.position.x,bounds.end.x),clampf(CENTER.z,bounds.position.z,bounds.end.z))
   var pad_overlap=nearest.distance_to(Vector2(CENTER.x,CENTER.z))<8.45
   var ramp_overlap=bounds.intersects(AABB(Vector3(19.9,-1,-9),Vector3(4.2,10,20.7)))
   var path_overlap=bounds.intersects(AABB(Vector3(10,-1,8.2),Vector3(13.8,10,3.6)))
   if not (pad_overlap or ramp_overlap or path_overlap):continue
   var old=t.origin
   var angle=.10+changes.size()*.12
   t.origin=Vector3(cos(angle)*39.0,0,sin(angle)*39.0)
   mm.set_instance_transform(i,t);ts[i]=t
   changes.append({'batch':str(batch.name),'index':i,'from':[old.x,old.y,old.z],'to':[t.origin.x,t.origin.y,t.origin.z],'reason':'actual transformed foliage bounds intersect pad/ramp/approach reserve'})
  batch.set_meta('source_transforms',ts)
 holder.set_meta('launchpad_relocations',changes)
 scene.set_meta('launchpad_foliage_changes',changes)
