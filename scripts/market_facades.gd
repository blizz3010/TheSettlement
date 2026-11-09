extends RefCounted
# Original authored procedural facade pass; pure visuals inside existing stand envelopes.
static func cloth(root:Node3D,n:String,width:float,back:float,front:float,back_y:float,front_y:float,sag:float,m:Material):
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var nx=16;var nz=6
 for ix in range(nx):
  for iz in range(nz):
   var quad=[]
   for ij in [Vector2(ix,iz),Vector2(ix+1,iz),Vector2(ix+1,iz+1),Vector2(ix,iz+1)]:
    var u=ij.x/nx;var v=ij.y/nz
    quad.append(Vector3((u-.5)*width,lerpf(back_y,front_y,v)-sin(u*PI)*sin(v*PI)*sag,lerpf(back,front,v)))
   for k in [0,2,1,0,3,2]:st.add_vertex(quad[k])
 st.generate_normals();var mesh=MeshInstance3D.new();mesh.name=n;mesh.mesh=st.commit();mesh.material_override=m;root.add_child(mesh)
 return mesh
static func beam(api,root,n,a:Vector3,b:Vector3,width:float,m):
 var p=(a+b)/2;var obj=api.box(root,n,p,Vector3(width,width,a.distance_to(b)),m);obj.basis=Basis.looking_at(b-a,Vector3.UP)
static func apply(shop:Node3D,spec:Dictionary,api,materials:Dictionary):
 var w:float=spec.width;var d:float=spec.depth;var front=d/2-.7;var back=-d/2+.3
 var wood=materials.wood;var bronze=materials.bronze;var stone=materials.stone;var cream=materials.cream;var dark=materials.dark
 # Replace the generic canopy visual, retaining original physical roof/headroom.
 shop.get_node('Role canvas awning').free()
 var old_roof=shop.get_node('Roof')
 for child in old_roof.get_children():
  if child is MeshInstance3D:child.free()
 # Layered low stone footing, timber counter slats, thin bronze joinery and knee braces.
 for x in [-w/2+.25,w/2-.25]:
  api.box(shop,'Dressed stone pier',Vector3(x,.25,front),Vector3(.46,.35,.46),stone)
  for z in [back,front]:
   for y in [.45,3.45]:api.box(shop,'Bronze collar',Vector3(x,y,z),Vector3(.26,.12,.26),bronze)
  beam(api,shop,'Diagonal timber knee',Vector3(x,2.8,front),Vector3(x-signf(x)*.72,3.65,front),.13,wood)
 for i in range(int(w/.35)-3):
  var x=-w/2+.65+i*.35
  api.box(shop,'Counter timber slat',Vector3(x,.62,front-.16),Vector3(.27,.88,.035),wood)
 api.box(shop,'Counter bronze kick rail',Vector3(0,.2,front-.13),Vector3(w-1.1,.09,.08),bronze)
 if spec.id=='Psy':
  var red=api.mat(Color('#9c4330'));red.cull_mode=BaseMaterial3D.CULL_DISABLED
  cloth(shop,'Rust red outfitter roof',w-.12,back-.2,front+.45,4.45,3.7,.24,red)
  # Raised rear beam and four roof ribs make the lean-to gear canopy distinct.
  api.box(shop,'Outfitter high rear beam',Vector3(0,4.4,back),Vector3(w,.15,.18),bronze)
  for x in [-w/2+.2,-1.3,1.3,w/2-.2]:beam(api,shop,'Gear canopy bronze rib',Vector3(x,4.45,back-.2),Vector3(x,3.7,front+.45),.075,bronze)
  api.box(shop,'Rust valance',Vector3(0,3.59,front+.44),Vector3(w-.1,.24,.06),red)
 elif spec.id=='Atlas':
  var teal=api.mat(Color('#317c79'));teal.cull_mode=BaseMaterial3D.CULL_DISABLED
  api.box(shop,'Utility roof',Vector3(0,4.06,-.75),Vector3(w,.20,d-1.5),dark)
  api.box(shop,'Upper locker bay cap',Vector3(0,4.35,back+.7),Vector3(w-.7,.36,1.6),teal)
  cloth(shop,'Teal recovery utility canopy',w-.1,front-2,front+.4,3.95,3.55,.10,teal)
  for x in [-w/2+.3,w/2-.3]:
   beam(api,shop,'Utility canopy bronze strut',Vector3(x,2.65,front-.4),Vector3(x,3.55,front+.4),.10,bronze)
  for x in [-2,-.65,.7,2.05]:
   api.box(shop,'Teal return locker header',Vector3(x,2.73,back+.87),Vector3(1.0,.19,.04),teal)
   api.box(shop,'Locker identification plate',Vector3(x,1.85,back+.87),Vector3(.44,.2,.025),cream)
   api.label(shop,'RETURN',Vector3(x,1.85,back+.895),13)
  api.box(shop,'Handover bench inset',Vector3(1.5,1.3,front-.63),Vector3(1.5,.12,.6),teal)
 else:
  var rust=api.mat(Color('#b47e43'));rust.cull_mode=BaseMaterial3D.CULL_DISABLED
  var rise=1.1;var half=w/2;var angle=atan2(rise,half)
  for side in [-1,1]:
   var roof=api.box(shop,'Pitched market roof',Vector3(side*w/4,4.05+rise/2,-.5),Vector3(sqrt(half*half+rise*rise),.14,d-1),wood);roof.rotation.z=-side*angle
   beam(api,shop,'Gable bronze edge',Vector3(side*half,4.05,front-.2),Vector3(0,5.15,front-.2),.12,bronze)
  api.box(shop,'Market ridge',Vector3(0,5.16,-.5),Vector3(.16,.16,d-.8),bronze)
  cloth(shop,'Ochre market cloth awning',w-.12,front-1.5,front+.45,3.95,3.48,.28,rust)
  for x in [-w/2+.3,0,w/2-.3]:beam(api,shop,'Market cloth stay',Vector3(x,3.95,front-1.5),Vector3(x,3.48,front+.45),.065,bronze)
  # Open framed notice-board and deeper visible cubby dividers are marketplace cues.
  for x in [-3.4,3.4]:
   for y in [.95,1.65,2.35]:api.box(shop,'Cubby open face',Vector3(x,y-.18,back+1.0),Vector3(.85,.30,.035),dark)
   api.box(shop,'Cubby upright',Vector3(x,1.45,back+1.03),Vector3(.08,2,.08),bronze)
  for x in [-1.25,0,1.25]:
   for y in [1.65,2.35]:
    for j in range(3):api.box(shop,'Listing ink rule',Vector3(x,y+.12-j*.1,back+.407),Vector3(.63,.025,.008),dark)

 # Keep the nonfunctional-service plaque in front of new timber slats.
 api.box(shop,'Planned service plaque',Vector3(0,.64,front-.11),Vector3(3.5,.28,.035),dark)
 for child in shop.get_children():
  if child is Label3D and child.text.begins_with('PLANNED SERVICE'):child.position.z=front-.085
 # Record exact pre-batch visual envelopes (customer apron deliberately extends in front).
 var bounds=AABB();var first=true;var mesh_count=0;var triangles=0
 for mesh in shop.find_children('*','MeshInstance3D',true,false):
  if mesh.get_parent().name=='Customer stone apron':continue
  var local=shop.global_transform.affine_inverse()*mesh.global_transform
  var b=local*mesh.mesh.get_aabb()
  assert(b.position.x>=-w/2-.16 and b.end.x<=w/2+.16,'Facade exceeds width '+str(mesh.get_path())+' '+str(b))
  assert(b.position.z>=-d/2-.16 and b.end.z<=d/2+.16,'Facade exceeds depth '+str(mesh.get_path())+' '+str(b))
  bounds=b if first else bounds.merge(b);first=false;mesh_count+=1;triangles+=mesh.mesh.get_faces().size()/3
 shop.set_meta('authored_facade',{'bounds':bounds,'meshes_before_batch':mesh_count,'triangles':triangles,'role':spec.id,'physical_envelope_unchanged':true})
