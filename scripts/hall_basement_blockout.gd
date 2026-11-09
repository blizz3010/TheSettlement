extends RefCounted
# Circulation blockout only. Two existing shapes replaced, outside coverage unchanged.
const Layout=preload("res://scripts/hall_shared_stair_layout.gd")
const HOLE=Layout.HOLE
static func pieces(rect:Rect2)->Array:
 return [Rect2(rect.position,Vector2(HOLE.position.x-rect.position.x,rect.size.y)),Rect2(Vector2(HOLE.end.x,rect.position.y),Vector2(rect.end.x-HOLE.end.x,rect.size.y)),Rect2(Vector2(HOLE.position.x,rect.position.y),Vector2(HOLE.size.x,HOLE.position.y-rect.position.y)),Rect2(Vector2(HOLE.position.x,HOLE.end.y),Vector2(HOLE.size.x,rect.end.y-HOLE.end.y))]
static func replace_shape(col:CollisionShape3D,rect:Rect2,journal:Array):
 var body=col.get_parent();var before={'body_path':str(body.get_path()),'center':body.position,'size':col.shape.size,'metadata':{}};var after=[]
 for key in body.get_meta_list():before.metadata[str(key)]=body.get_meta(key)
 var height=col.shape.size.y
 for patch in pieces(rect):
  var center=Vector3(patch.get_center().x,body.position.y,patch.get_center().y)
  var shape=BoxShape3D.new();shape.size=Vector3(patch.size.x,height,patch.size.y)
  var c=CollisionShape3D.new();c.shape=shape;c.position=center-body.position;body.add_child(c)
  after.append({'center':center,'size':shape.size})
 col.free();journal.append({'before':before,'after':after})
static func box(root:Node3D,n:String,p:Vector3,size:Vector3,color:Color,solid=true):
 var holder=Node3D.new();holder.name=n;holder.position=p;root.add_child(holder)
 if solid:
  var body=StaticBody3D.new();body.set_meta('audio_surface','stone');holder.add_child(body)
  var c=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=size;c.shape=shape;body.add_child(c)
 var mesh=MeshInstance3D.new();var cube=BoxMesh.new();cube.size=size;mesh.mesh=cube
 var mat=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.9;mesh.material_override=mat;holder.add_child(mesh);return holder
static func guard(root:Node3D,n:String,x:float,z1:float,z2:float,y1:float,y2:float):
 var body=StaticBody3D.new();body.name=n;body.set_meta('audio_surface','wood');body.set_meta('stair_guard',true);root.add_child(body)
 var pts=PackedVector3Array()
 for e in [0,1]:
  var z=z1 if e==0 else z2;var y=y1 if e==0 else y2
  for xx in [x-.04,x+.04]:
   pts.append(Vector3(xx,y,z));pts.append(Vector3(xx,y+1.1,z))
 var c=CollisionShape3D.new();var shape=ConvexPolygonShape3D.new();shape.points=pts;c.shape=shape;body.add_child(c)
 var mesh=MeshInstance3D.new();var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for face in [[0,1,5],[0,5,4],[2,6,7],[2,7,3],[1,3,7],[1,7,5]]:
  for i in face:st.add_vertex(pts[i])
 st.generate_normals();mesh.mesh=st.commit();var m=StandardMaterial3D.new();m.albedo_color=Color('#65533e');m.cull_mode=BaseMaterial3D.CULL_DISABLED;mesh.material_override=m;body.add_child(mesh)
static func stair_support(root:Node3D,x:float,z1:float,z2:float,y1:float,y2:float):
 # Two real edge stringers, never a full-height invisible basement wedge.
 # The top profile sits within/below each descending tread. Clip below the room floor.
 var outline=[Vector2(z1,y1-.17),Vector2(z2,y2-.17),Vector2(z2,y2-.37),Vector2(z1,y1-.37)]
 var clipped=[]
 for i in range(outline.size()):
  var a:Vector2=outline[i];var b:Vector2=outline[(i+1)%outline.size()]
  var ia=a.y>=Layout.BASEMENT_Y;var ib=b.y>=Layout.BASEMENT_Y
  if ia:clipped.append(a)
  if ia!=ib:clipped.append(a.lerp(b,(Layout.BASEMENT_Y-a.y)/(b.y-a.y)))
 var area=0.0
 for i in range(clipped.size()):area+=clipped[i].cross(clipped[(i+1)%clipped.size()])
 if area<0:clipped.reverse()
 assert(clipped.size()>=3)
 for offset in [-.745,.745]:
  var body=StaticBody3D.new();body.name=('Descending east' if x==Layout.DOWN_EAST_X else 'Descending west')+(' stringer west' if offset<0 else ' stringer east');body.set_meta('audio_surface','wood');body.set_meta('slim_stair_stringer',true);root.add_child(body)
  var pts=PackedVector3Array()
  for p in clipped:
   for edge in [-.06,.06]:pts.append(Vector3(x+offset+edge,p.y,p.x))
  var col=CollisionShape3D.new();var shape=ConvexPolygonShape3D.new();shape.points=pts;col.shape=shape;body.add_child(col)
  var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for i in range(1,clipped.size()-1):
   for index in [0,i*2,(i+1)*2,1,(i+1)*2+1,i*2+1]:st.add_vertex(pts[index])
  for i in range(clipped.size()):
   var a=i*2;var b=((i+1)%clipped.size())*2
   for index in [a,a+1,b,b,a+1,b+1]:st.add_vertex(pts[index])
  st.generate_normals();var visual=MeshInstance3D.new();visual.mesh=st.commit();var m=StandardMaterial3D.new();m.albedo_color=Color('#66533e');m.cull_mode=BaseMaterial3D.CULL_DISABLED;visual.material_override=m;body.add_child(visual)
static func preflight(scene:Node3D)->Dictionary:
 if scene.has_node('HallBasementBlockout'):
  push_error('Basement opening already exists; no replacement writes');return {}
 var targets=[];var terrain_count=0;var hall_count=0
 for c in scene.find_children('*','CollisionShape3D',true,false):
  if not c.shape is BoxShape3D or not c.shape.size in [Vector3(108,.6,108),Vector3(18,.24,18)]:continue
  var body=c.get_parent()
  if not body is StaticBody3D or c.transform!=Transform3D.IDENTITY:
   push_error('Original floor collision owner/transform differs; no replacement writes');return {}
  if c.shape.size.x==108:
   if body.get_parent()!=scene or body.transform!=Transform3D(Basis.IDENTITY,Vector3(0,-.35,0)):
    push_error('Expected original terrain transform; no replacement writes');return {}
   terrain_count+=1
  else:
   if body.get_parent()!=scene.get_node_or_null('TownHallCollision') or body.name!='Level floor' or body.transform!=Transform3D(Basis.IDENTITY,Vector3(0,.12,-23)):
    push_error('Expected original Hall floor owner/transform; no replacement writes');return {}
   hall_count+=1
  targets.append(c)
 var ground=[]
 for m in scene.get_children():
  if m is MeshInstance3D and m.mesh is BoxMesh and m.mesh.size==Vector3(108,.6,108):
   if m.transform!=Transform3D(Basis.IDENTITY,Vector3(0,-.35,0)):
    push_error('Expected original terrain visual transform; no replacement writes');return {}
   ground.append(m)
 if terrain_count!=1 or hall_count!=1 or ground.size()!=1:
  push_error('Exactly two original floor shapes and one terrain visual required; no replacement writes');return {}
 return {'targets':targets,'ground':ground[0]}
static func commit_opening(scene:Node3D,checked:Dictionary)->Node3D:
 # No awaits after validated mesh commit: physical/terrain opening changes atomically in this turn.
 var root=Node3D.new();root.name='HallBasementBlockout';scene.add_child(root)
 var journal=[]
 for c in checked.targets:replace_shape(c,Rect2(-54,-54,108,108) if c.shape.size.x==108 else Rect2(-9,-32,18,18),journal)
 root.set_meta('replacement_journal',journal)
 var m=checked.ground
 for patch in pieces(Rect2(-54,-54,108,108)):
  var visual=MeshInstance3D.new();var cube=BoxMesh.new();cube.size=Vector3(patch.size.x,.6,patch.size.y);visual.mesh=cube;visual.position=Vector3(patch.get_center().x,-.35,patch.get_center().y);visual.material_override=m.material_override;root.add_child(visual)
 m.free()
 return root
static func add_to(scene:Node3D)->bool:
 var checked=preflight(scene)
 if checked.is_empty():return false
 if not preload('res://scripts/hall_floor_opening.gd').cut(scene,HOLE):return false
 var root=commit_opening(scene,checked)
 var stone=Color('#756f61');var wood=Color('#66533e')
 box(root,'Basement floor',Vector3(0,-3.62,-23),Vector3(17.2,.24,17.2),stone)
 for x in [-8.5,8.5]:box(root,'Basement side wall',Vector3(x,-2.1,-23),Vector3(.2,2.8,17.2),stone)
 for z in [-31.5,-14.5]:box(root,'Basement end wall',Vector3(0,-2.1,z),Vector3(17,2.8,.2),stone)
 for patch in pieces(Rect2(-8.6,-31.6,17.2,17.2)):
  box(root,'Basement ceiling outside stairwell',Vector3(patch.get_center().x,-.725,patch.get_center().y),Vector3(patch.size.x,.15,patch.size.y),stone)
 # One common ground landing: west goes upstairs, adjacent east descends.
 for i in range(Layout.STEPS):
  var z=Layout.START_Z-Layout.GOING*(i+.5);var top=Layout.GROUND_Y-Layout.RISE*(i+1)
  box(root,'Descending east tread %02d'%i,Vector3(Layout.DOWN_EAST_X,top-.085,z),Vector3(1.65,.17,Layout.GOING),wood)
  var z2=Layout.TURN_Z+Layout.GOING*(i+.5);var top2=Layout.TURN_Y-Layout.RISE*(i+1)
  box(root,'Descending west tread %02d'%i,Vector3(Layout.DOWN_WEST_X,top2-.085,z2),Vector3(1.65,.17,Layout.GOING),wood)
 box(root,'Turning landing',Layout.TURN_CENTER,Layout.TURN_SIZE,wood)
 stair_support(root,Layout.DOWN_EAST_X,Layout.START_Z,Layout.TURN_Z,Layout.GROUND_Y,Layout.TURN_Y)
 stair_support(root,Layout.DOWN_WEST_X,Layout.TURN_Z,Layout.START_Z,Layout.TURN_Y,Layout.BASEMENT_Y)
 for data in Layout.SLOPING_GUARDS:guard(root,'Stair continuous side barrier',data[0],data[1],data[2],data[3],data[4])
 for x in [HOLE.position.x,HOLE.end.x]:box(root,'Ground opening side guard',Vector3(x,.79,HOLE.get_center().y),Vector3(.1,1.1,HOLE.size.y),wood)
 box(root,'Ground opening north guard',Vector3(HOLE.get_center().x,.79,HOLE.position.y),Vector3(HOLE.size.x,1.1,.1),wood)
 # Both intended stair mouths stay open. All exposed turning-landing edges are guarded.
 box(root,'Turning north safety barrier',Vector3(-6.45,-1.08,-21.78),Vector3(3.5,1.1,.08),wood)
 for x in [-8.15,-4.75]:box(root,'Turning side safety barrier',Vector3(x,-1.08,-21.055),Vector3(.08,1.1,1.45),wood)
 # Deliberately plain, no added lighting or game services in this geometry gate.
 return true

# Opt-in loading successor scheduling. Original synchronous APIs above remain unchanged.
static func add_to_staged(scene:Node3D,startup_owner:Node)->bool:
 var checked=preflight(scene)
 if checked.is_empty():return false
 var cut_ok=false
 if startup_owner!=null:cut_ok=await preload('res://scripts/hall_floor_opening.gd').cut_staged(scene,HOLE,startup_owner)
 else:cut_ok=preload('res://scripts/hall_floor_opening.gd').cut(scene,HOLE)
 if not cut_ok:return false
 var root=commit_opening(scene,checked)
 var stone=Color('#756f61');var wood=Color('#66533e')
 box(root,'Basement floor',Vector3(0,-3.62,-23),Vector3(17.2,.24,17.2),stone)
 for x in [-8.5,8.5]:box(root,'Basement side wall',Vector3(x,-2.1,-23),Vector3(.2,2.8,17.2),stone)
 for z in [-31.5,-14.5]:box(root,'Basement end wall',Vector3(0,-2.1,z),Vector3(17,2.8,.2),stone)
 for patch in pieces(Rect2(-8.6,-31.6,17.2,17.2)):
  box(root,'Basement ceiling outside stairwell',Vector3(patch.get_center().x,-.725,patch.get_center().y),Vector3(patch.size.x,.15,patch.size.y),stone)
 # One common ground landing: west goes upstairs, adjacent east descends.
 for i in range(Layout.STEPS):
  var z=Layout.START_Z-Layout.GOING*(i+.5);var top=Layout.GROUND_Y-Layout.RISE*(i+1)
  box(root,'Descending east tread %02d'%i,Vector3(Layout.DOWN_EAST_X,top-.085,z),Vector3(1.65,.17,Layout.GOING),wood)
  var z2=Layout.TURN_Z+Layout.GOING*(i+.5);var top2=Layout.TURN_Y-Layout.RISE*(i+1)
  box(root,'Descending west tread %02d'%i,Vector3(Layout.DOWN_WEST_X,top2-.085,z2),Vector3(1.65,.17,Layout.GOING),wood)
 box(root,'Turning landing',Layout.TURN_CENTER,Layout.TURN_SIZE,wood)
 stair_support(root,Layout.DOWN_EAST_X,Layout.START_Z,Layout.TURN_Z,Layout.GROUND_Y,Layout.TURN_Y)
 stair_support(root,Layout.DOWN_WEST_X,Layout.TURN_Z,Layout.START_Z,Layout.TURN_Y,Layout.BASEMENT_Y)
 for data in Layout.SLOPING_GUARDS:guard(root,'Stair continuous side barrier',data[0],data[1],data[2],data[3],data[4])
 for x in [HOLE.position.x,HOLE.end.x]:box(root,'Ground opening side guard',Vector3(x,.79,HOLE.get_center().y),Vector3(.1,1.1,HOLE.size.y),wood)
 box(root,'Ground opening north guard',Vector3(HOLE.get_center().x,.79,HOLE.position.y),Vector3(HOLE.size.x,1.1,.1),wood)
 # Both intended stair mouths stay open. All exposed turning-landing edges are guarded.
 box(root,'Turning north safety barrier',Vector3(-6.45,-1.08,-21.78),Vector3(3.5,1.1,.08),wood)
 for x in [-8.15,-4.75]:box(root,'Turning side safety barrier',Vector3(x,-1.08,-21.055),Vector3(.08,1.1,1.45),wood)
 # Deliberately plain, no added lighting or game services in this geometry gate.
 return true
