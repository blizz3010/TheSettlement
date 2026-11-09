extends RefCounted
const Layout=preload("res://scripts/plot_layout.gd")
static func mat(c:Color,metal=0.0)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=c;m.roughness=.82;m.metallic=metal;return m
static func box(root:Node3D,n:String,c:Vector3,size:Vector3,m:Material,solid=true,surface="stone"):
 var node=Node3D.new();node.name=n;node.position=c;root.add_child(node)
 var mesh=MeshInstance3D.new();var shape=BoxMesh.new();shape.size=size;mesh.mesh=shape;mesh.material_override=m;node.add_child(mesh)
 if solid:
  var body=StaticBody3D.new();body.set_meta('audio_surface',surface);node.add_child(body)
  var col=CollisionShape3D.new();var b=BoxShape3D.new();b.size=size;col.shape=b;body.add_child(col)
 return node
static func rail(root:Node3D,n:String,a:Vector3,b:Vector3,bronze:Material):
 # Actual continuous1.1m safety barrier plus visible posts/rails; sloped with stairs.
 var body=StaticBody3D.new();body.name=n;root.add_child(body);var pts=PackedVector3Array()
 var normal=Vector3(b.z-a.z,0,a.x-b.x).normalized()*.045
 for p in [a,b]:
  for side in [-1,1]:pts.append(p+normal*side);pts.append(p+normal*side+Vector3(0,1.1,0))
 var col=CollisionShape3D.new();var shape=ConvexPolygonShape3D.new();shape.points=pts;col.shape=shape;body.add_child(col)
 var count=maxi(1,ceili(a.distance_to(b)/1.2))
 for i in range(count+1):
  var foot=a.lerp(b,float(i)/count)
  box(root,'Bronze post',foot+Vector3(0,.55,0),Vector3(.09,1.1,.09),bronze,false)
  box(root,'Bronze joint cap',foot+Vector3(0,1.08,0),Vector3(.14,.08,.14),bronze,false)
 for h in [.35,1.05]:
  var aa=a+Vector3(0,h,0);var bb=b+Vector3(0,h,0)
  var beam=box(root,'Bronze rail',(aa+bb)/2,Vector3(.07,.07,aa.distance_to(bb)),bronze,false);beam.look_at_from_position((aa+bb)/2,bb,Vector3.UP)
static func build(scene:Node3D):
 var root=Node3D.new();root.name='RaisedHideoutTerrace';scene.add_child(root)
 var stone=mat(Color(.36,.32,.24));var cap=mat(Color(.48,.43,.32));var turf=mat(Color(.27,.33,.19));var bronze=mat(Color(.28,.16,.07),.65)
 box(root,'Retaining terrace',Vector3(-24,1.475,15),Vector3(16,3.05,16),stone)
 # Empty authored turf reserve, not a house or seeded build piece.
 box(root,'Empty build turf',Vector3(-24,3.012,15),Vector3(12,.024,12),turf,false)
 # Stone caps aroundoutsidebuildreserve; no colliders inside reserve besides support slab.
 for spec in [[Vector3(-31,3.015,15),Vector3(2,.03,16)],[Vector3(-17,3.015,15),Vector3(2,.03,16)],[Vector3(-24,3.015,8),Vector3(12,.03,2)],[Vector3(-24,3.015,22),Vector3(12,.03,2)]]:box(root,'Perimeter paving',spec[0],spec[1],cap,false)
 # Instanced retaining blocks retain originaleditable lowcost geometry.
 var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;var cube=BoxMesh.new();cube.size=Vector3(.94,.45,.11);mm.mesh=cube;var transforms=[]
 for row in range(6):
  for i in range(16):
   var q=i+.5+(0.25 if row%2 else 0);var y=.23+row*.49
   for side in [-1,1]:
    transforms.append(Transform3D(Basis.IDENTITY,Vector3(-32+q,y,15+side*8.015)))
    transforms.append(Transform3D(Basis(Vector3.UP,PI/2),Vector3(-24+side*8.015,y,7+q)))
 # Continue the same stone courses over all three exposed stash-porch faces.
 for row in range(6):
  var y=.23+row*.49
  for i in range(3):
   for z in [17.985,22.015]:transforms.append(Transform3D(Basis.IDENTITY,Vector3(-15.5+i,y,z)))
  for i in range(4):transforms.append(Transform3D(Basis(Vector3.UP,PI/2),Vector3(-12.985,y,18.5+i)))
 mm.instance_count=transforms.size()
 for i in range(transforms.size()):mm.set_instance_transform(i,transforms[i])
 var stones=MultiMeshInstance3D.new();stones.name='Retaining stone courses';stones.multimesh=mm;stones.material_override=cap;root.add_child(stones)
 #18actualrisers, two9-riserflights,1.6m midpoint landing. Ascendwest.
 var bottom=-8.28
 for i in range(9):
  var top=(i+1)/6.0;box(root,'Lower step%02d'%i,Vector3(bottom-.34*(i+.5),top/2,15),Vector3(.34,top,3.2),cap)
 box(root,'Mid landing',Vector3(-12.14,.75,15),Vector3(1.6,1.5,3.2),cap)
 for i in range(9):
  var top=1.5+(i+1)/6.0;box(root,'Upper step%02d'%i,Vector3(-12.94-.34*(i+.5),top/2,15),Vector3(.34,top,3.2),cap)
 # Separate externalporch; stashneveroccupiesbuildcells or mainwalkstrip.
 box(root,'Stash porch',Vector3(-14.5,1.5,20),Vector3(3,3,4),stone)
 box(root,'Porch capstone',Vector3(-14.5,3.015,20),Vector3(3.12,.03,4.12),cap,false)
 for z in [7.02,22.98]:box(root,'Retaining edge coping',Vector3(-24,2.91,z),Vector3(16.12,.18,.22),cap,false)
 box(root,'Retaining west coping',Vector3(-32,2.91,15),Vector3(.22,.18,16.12),cap,false)
 for z in [13.4,16.6]:
  rail(root,'Stair lower guard',Vector3(-8.28,0,z),Vector3(-11.34,1.5,z),bronze)
  rail(root,'Landing guard',Vector3(-11.34,1.5,z),Vector3(-12.94,1.5,z),bronze)
  rail(root,'Stair upper guard',Vector3(-12.94,1.5,z),Vector3(-16,3,z),bronze)
 for pair in [[Vector3(-32,3,7),Vector3(-32,3,23)],[Vector3(-32,3,7),Vector3(-16,3,7)],[Vector3(-32,3,23),Vector3(-16,3,23)],[Vector3(-16,3,7),Vector3(-16,3,13.4)],[Vector3(-16,3,16.6),Vector3(-16,3,18)],[Vector3(-16,3,22),Vector3(-16,3,23)],[Vector3(-16,3,18),Vector3(-13,3,18)],[Vector3(-13,3,18),Vector3(-13,3,22)],[Vector3(-13,3,22),Vector3(-16,3,22)]]:rail(root,'Terrace edge guard',pair[0],pair[1],bronze)
 # Ground approachsouthofwesttrader/requestboard.
 var route_stone=scene.courtyard_material('paving',Color(.46,.44,.38,1))
 var approach_slabs=[]
 var points=[Vector3(-5,.015,7),Vector3(-7,.015,10),Vector3(-8.28,.015,15)]
 for i in range(points.size()-1):
  var a=points[i];var b=points[i+1]
  if i==0:
   var path=box(root,'Approach path',(a+b)/2,Vector3(2.6,.08,a.distance_to(b)+.25),route_stone);path.look_at_from_position((a+b)/2,b,Vector3.UP)
   approach_slabs.append(path)
  else:
   # Flush L-turn into FULL east stair mouth: x=-8.28,z=13.4..16.6.
   # Existing last slab only; no additional floor, step, guard or collider.
   var path=box(root,'Approach path',Vector3(-6.98,.015,13.3),Vector3(2.6,.08,6.6),route_stone)
   approach_slabs.append(path)
   path.set_meta('v052_stair_alignment',{'old_start':a,'old_end':b,'stair_edge_x':-8.28,'stair_z_min':13.4,'stair_z_max':16.6})
 preload("res://scripts/paving_edges.gd").join_hideout(root,approach_slabs,route_stone)
 add_base_planting(root)
 preload("res://scripts/home_finish_v094.gd").apply(scene,root)
 batch_static_visuals(root)
 scene.set_meta('hideout_terrace',{'origin':Layout.ORIGIN,'stash':Layout.STASH,'empty_default':true,'quest_move_enabled':false})
static func reservations()->Array[AABB]:
 return [AABB(Vector3(-32.5,-1,6.5),Vector3(17,12,17)),AABB(Vector3(-16.5,-1,12.8),Vector3(9,12,4.4)),AABB(Vector3(-16.5,-1,17.5),Vector3(4,12,5)),AABB(Vector3(-10,-1,6),Vector3(7,12,11))]
static func conflicts(bounds:AABB)->bool:
 for r in reservations():
  if bounds.intersects(r):return true
 return false
static func reconcile(scene:Node3D,holder_name:String):
 var holder=scene.get_node(holder_name);var changes=[]
 for batch in holder.get_children():
  var ts:Array=batch.get_meta('source_transforms');var mm=batch.multimesh
  for i in range(ts.size()):
   var old:Transform3D=ts[i]
   if not conflicts(old*mm.mesh.get_aabb()):continue
   var t=old
   if holder_name=='NaturalBorder':
    var angle=3.55+changes.size()*.055;t.origin=Vector3(cos(angle)*39,0,sin(angle)*39)
   else:
    # Rehome lowplants into oldplot'soutergarden, outsidelegacy westpaving/serviceapproach.
    t.origin=Vector3(-22+(changes.size()%8)*.8,old.origin.y,1.2+floori(changes.size()/8)*.7)
   assert(not conflicts(t*mm.mesh.get_aabb()),'Relocated flora must clear newterrace')
   mm.set_instance_transform(i,t);ts[i]=t
   changes.append({'batch':str(batch.name),'index':i,'from':[old.origin.x,old.origin.y,old.origin.z],'to':[t.origin.x,t.origin.y,t.origin.z]})
  batch.set_meta('source_transforms',ts)
 scene.set_meta('terrace_'+holder_name+'_relocations',changes)

static func batch_static_visuals(root:Node3D):
 var groups={}
 for mesh in root.find_children('*','MeshInstance3D',true,false):
  if not mesh.mesh is BoxMesh:continue
  var material=mesh.material_override;var key=material.get_instance_id()
  if not groups.has(key):groups[key]={'material':material,'transforms':[]}
  var t=root.global_transform.affine_inverse()*mesh.global_transform
  t.basis=t.basis.scaled_local(mesh.mesh.size)
  groups[key].transforms.append(t);mesh.free()
 for group in groups.values():
  var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;var cube=BoxMesh.new();cube.size=Vector3.ONE;mm.mesh=cube;mm.instance_count=group.transforms.size()
  for i in range(mm.instance_count):mm.set_instance_transform(i,group.transforms[i])
  var batch=MultiMeshInstance3D.new();batch.name='Terrace material batch';batch.multimesh=mm;batch.material_override=group.material;root.add_child(batch)

static func add_base_planting(root:Node3D):
 # Small no-collision clusters outside stairs, porch approach and build reserve.
 var clusters=[Vector3(-19,-.05,23.7),Vector3(-24,-.05,23.7),Vector3(-29,-.05,23.7),Vector3(-12.2,-.05,20),Vector3(-16.7,-.05,6.2),Vector3(-21,-.05,6.2),Vector3(-5.5,-.05,14.8)]
 for kind in ['ground_shrub_a','ground_flowers_purple','ground_flowers_yellow']:
  var source=load('res://assets/groundcover/'+kind+'.glb').instantiate()
  var mesh=source.find_children('*','MeshInstance3D',true,false)[0].mesh
  var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=clusters.size()
  var transforms=[]
  for i in range(clusters.size()):
   var p=clusters[i]
   if kind=='ground_flowers_purple':p+=Vector3(.32,0,.34)
   elif kind=='ground_flowers_yellow':p+=Vector3(-.32,0,.4)
   var t=Transform3D(Basis(Vector3.UP,i*.91),p);transforms.append(t);mm.set_instance_transform(i,t)
  var batch=MultiMeshInstance3D.new();batch.name='Base planting '+kind;batch.multimesh=mm;batch.set_meta('source_transforms',transforms);batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(batch);source.free()
