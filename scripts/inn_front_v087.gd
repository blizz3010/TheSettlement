extends RefCounted
const Art=preload('res://scripts/inn_architecture.gd')
const Beam=preload('res://scripts/inn_structure.gd')
static func solid(parent:Node3D,label:String,p:Vector3,s:Vector3,m:Material):
 var mesh=Art.box(parent,label,p,s,m);var body=StaticBody3D.new();body.name=label+'Collision';body.position=p
 var shape=CollisionShape3D.new();var b=BoxShape3D.new();b.size=s;shape.shape=b;body.add_child(shape);parent.add_child(body);return mesh
static func glow()->StandardMaterial3D:
 var m=Art.material('e6ac58');m.emission_enabled=true;m.emission=Color('#ffc174');m.emission_energy_multiplier=.65;return m
static func lantern(parent:Node3D,p:Vector3):
 var n=Node3D.new();n.name='WarmWallLantern';n.position=p;parent.add_child(n)
 var dark=Art.material('493721');var warm=glow()
 Art.box(n,'Bracket',Vector3(0,.23,.12),Vector3(.08,.55,.08),dark)
 Art.box(n,'Glass',Vector3.ZERO,Vector3(.20,.34,.18),warm)
 for x in [-.12,.12]:Art.box(n,'Frame',Vector3(x,0,0),Vector3(.035,.42,.23),dark)
 for y in [-.22,.22]:Art.box(n,'Cap',Vector3(0,y,0),Vector3(.29,.05,.25),dark)
 var light=OmniLight3D.new();light.position.z=-.2;light.light_color=Color('#ffd193');light.light_energy=.65;light.omni_range=3.5;light.shadow_enabled=false;n.add_child(light)
static func gable(parent:Node3D,x:float,y:float,z:float,w:float,h:float,depth:float):
 var roof=Art.material('38413b');roof.cull_mode=BaseMaterial3D.CULL_DISABLED
 var wood=Art.material('634126');var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var a=Vector3(x-w,y,z);var b=Vector3(x,y+h,z);var c=Vector3(x+w,y,z)
 var back=Vector3(0,0,depth)
 for tri in [[a,b,a+back],[a+back,b,b+back],[b,c,b+back],[b+back,c,c+back]]:
  var normal=(tri[1]-tri[0]).cross(tri[2]-tri[0]).normalized()
  for p in tri:st.set_normal(normal);st.add_vertex(p)
 var mesh=MeshInstance3D.new();mesh.name='TimberPorchGable';mesh.mesh=st.commit();mesh.material_override=roof;parent.add_child(mesh)
 Beam.beam(parent,'GableLeft',a,b,.16,.16,wood);Beam.beam(parent,'GableRight',b,c,.16,.16,wood);Beam.beam(parent,'GableTie',a,c,.14,.14,wood)
 Art.box(parent,'GableKingPost',Vector3(x,y+h*.5,z),Vector3(.12,h,.12),wood)
static func window(parent:Node3D,x:float,y:float,z:float,w:float,h:float):
 var wood=Art.material('503a25');var gold=glow()
 Art.box(parent,'WarmGlazedPanel',Vector3(x,y,z),Vector3(w,h,.035),gold)
 for dx in [-w*.5,w*.5]:Art.box(parent,'WindowSide',Vector3(x+dx,y,z-.035),Vector3(.07,h+.12,.07),wood)
 for dy in [-h*.5,h*.5]:Art.box(parent,'WindowSill',Vector3(x,y+dy,z-.035),Vector3(w+.12,.07,.07),wood)
 var n=ceili(w/.38)
 for i in range(n):
  var xx=x-w*.5+(i+.5)*w/n
  Art.box(parent,'WindowMullion',Vector3(xx,y,z-.06),Vector3(.035,h,.035),wood)
  for j in range(3):
   var yy=y-h*.5+(j+.5)*h/3
   var d=minf(w/n*.4,h/3*.4)
   Beam.beam(parent,'LatticeA',Vector3(xx-d,yy-d,z-.08),Vector3(xx+d,yy+d,z-.08),.018,.018,wood)
   Beam.beam(parent,'LatticeB',Vector3(xx-d,yy+d,z-.08),Vector3(xx+d,yy-d,z-.08),.018,.018,wood)
static func plant(parent:Node3D,p:Vector3,width:float):
 var obj=load('res://assets/quaternius/Flower_3_Group.gltf').instantiate() as Node3D
 var b=AABB();var first=true
 for n in obj.find_children('*','MeshInstance3D',true,false):
  var bb=n.transform*n.mesh.get_aabb();b=bb if first else b.merge(bb);first=false
 var s=width/maxf(b.size.x,b.size.z);obj.scale=Vector3.ONE*s;obj.position=p-Vector3(0,b.position.y*s,0);parent.add_child(obj)
# V96-01: clip every chimney body/course to the south roof slope. The closed
# underside sits 15 mm inside the 45 mm roof shell, never below its timber lining.
# No roof opening, covering plane, double-sided material or collision is added.
static func chimney_piece(parent:Node3D,label:String,p:Vector3,size:Vector3,m:Material):
 var low=p-size*.5;var high=p+size*.5
 var polygon:Array[Vector2]=[Vector2(low.z,low.y),Vector2(high.z,low.y),Vector2(high.z,high.y),Vector2(low.z,high.y)]
 var clipped:Array[Vector2]=[]
 for i in polygon.size():
  var a=polygon[i];var b=polygon[(i+1)%polygon.size()]
  var da=a.y+(1.8/6.5)*a.x-8.185;var db=b.y+(1.8/6.5)*b.x-8.185
  if da>=0:clipped.append(a)
  if (da>=0)!=(db>=0):clipped.append(a.lerp(b,da/(da-db)))
 if clipped.size()<3:return
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var center=Vector3.ZERO
 for v in clipped:center+=Vector3(p.x,v.y,v.x)/clipped.size()
 var faces=[]
 for x in [low.x,high.x]:
  for i in range(1,clipped.size()-1):faces.append([Vector3(x,clipped[0].y,clipped[0].x),Vector3(x,clipped[i].y,clipped[i].x),Vector3(x,clipped[i+1].y,clipped[i+1].x)])
 for i in clipped.size():
  var a=clipped[i];var b=clipped[(i+1)%clipped.size()]
  var q=[Vector3(low.x,a.y,a.x),Vector3(high.x,a.y,a.x),Vector3(high.x,b.y,b.x),Vector3(low.x,b.y,b.x)]
  faces.append([q[0],q[1],q[2]]);faces.append([q[0],q[2],q[3]])
 for tri in faces:
  var normal=-(tri[1]-tri[0]).cross(tri[2]-tri[0]).normalized()
  if normal.dot((tri[0]+tri[1]+tri[2])/3.0-center)<0:
   var swap=tri[1];tri[1]=tri[2];tri[2]=swap;normal=-normal
  for v in tri:st.set_normal(normal);st.add_vertex(v)
 var mesh=MeshInstance3D.new();mesh.name=label;mesh.mesh=st.commit();mesh.material_override=m;parent.add_child(mesh)
static func apply_to_inn(inn:Node3D)->Dictionary:
 if inn.has_meta('inn_front_v087'):return inn.get_meta('inn_front_v087')
 var wall=inn.get_node_or_null('ExteriorWalls/SideWall1') as MeshInstance3D
 var body=inn.get_node_or_null('ExplicitArchitectureCollision/ExteriorWalls_SideWall1') as StaticBody3D
 if wall==null or body==null or not wall.mesh is BoxMesh:return {'ok':false,'reason':'Expected original east wall not found'}
 if not wall.mesh.size.is_equal_approx(Vector3(.20,6.4,11.8)) or not wall.position.is_equal_approx(Vector3(7.8,3.2,0)):return {'ok':false,'reason':'Original east wall shape changed'}
 var shape=body.get_child(0) as CollisionShape3D
 if shape==null or not shape.shape is BoxShape3D or shape.shape.size!=wall.mesh.size:return {'ok':false,'reason':'East wall collision does not match visual'}
 var root=Node3D.new();root.name='ApprovedInnFrontV087';inn.add_child(root)
 var cream=Art.material('c6bba1');var wood=Art.material('594936');var bronze=Art.material('938064');var burgundy=Art.material('732e3e');var gold=Art.material('e4c379')
 # Separate east-side entrance z[1.375,2.625], 2.6m tall, opening onto retained terrace.
 solid(root,'EastWallNorth',Vector3(7.8,3.2,(-5.9+1.375)*.5),Vector3(.20,6.4,7.275),cream)
 solid(root,'EastWallSouth',Vector3(7.8,3.2,(2.625+5.9)*.5),Vector3(.20,6.4,3.275),cream)
 solid(root,'SideDoorLintel',Vector3(7.8,4.5,2),Vector3(.20,3.8,1.25),cream)
 # Cosmetic jambs stay OUTSIDE the clear opening.
 for z in [1.30,2.70]:Art.box(root,'SideDoorJamb',Vector3(7.93,1.3,z),Vector3(.16,2.6,.10),wood)
 Art.box(root,'SideDoorHeader',Vector3(7.93,2.7,2),Vector3(.20,.16,1.6),wood)
 var side=Node3D.new();side.name='SideEntryLantern';side.position=Vector3(7.98,2.1,3.1);side.rotation.y=-PI/2;root.add_child(side);lantern(side,Vector3.ZERO)
 # Existing main doorway remains clear x[-1.2,1.2]. Porch is overhead only.
 gable(root,0,3.28,-8.2,2.65,1.35,2.6)
 for x in [-2.45,2.45]:solid(root,'PorchPost',Vector3(x,1.6,-8.0),Vector3(.18,3.2,.18),wood)
 Art.box(root,'MainEntranceNameboard',Vector3(0,3.22,-8.31),Vector3(2.4,.44,.08),wood)
 var title=Label3D.new();title.text='INN';title.font_size=70;title.pixel_size=.006;title.modulate=Color('#f1d397');title.position=Vector3(0,3.23,-8.37);title.rotation.y=PI;root.add_child(title)
 for x in [-1.55,1.55]:lantern(root,Vector3(x,2.35,-6.15))
 for x in [-5.75,-1.925,1.925,5.75]:
  window(root,x,4.8,-6.04,3.3,1.30)
  Art.box(root,'UpperFlowerBox',Vector3(x,3.98,-6.2),Vector3(2.7,.28,.48),wood)
  for dx in [-1,-.5,0,.5,1]:plant(root,Vector3(x+dx,4.13,-6.2),.45)
 for x in [-5.3,-3.1,3.1,5.3]:window(root,x,1.65,-6.04,1.35,1.65)
 Art.box(root,'HeraldBanner',Vector3(0,4.95,-6.28),Vector3(1.4,2.05,.04),burgundy)
 for x in [-.66,.66]:Art.box(root,'BannerBorder',Vector3(x,4.95,-6.31),Vector3(.025,2,.015),gold)
 var emblem=Label3D.new();emblem.text='INN';emblem.font_size=76;emblem.pixel_size=.006;emblem.modulate=Color('#f0cf83');emblem.position=Vector3(0,5.15,-6.34);emblem.rotation.y=PI;root.add_child(emblem)
 gable(root,0,6.45,-6.65,2.7,1.7,3.2)
 for x in [-7.25,7.25]:lantern(root,Vector3(x,5.65,-6.17))
 # Carry the same architecture around the side rather than leaving a blank wall.
 var side_face=Node3D.new();side_face.name='CoherentEastFacade';side_face.position.x=7.8;side_face.rotation.y=-PI/2;root.add_child(side_face)
 for z in [-3.9,-.9,2.1,4.7]:
  window(side_face,z,4.8,-.13,1.55,1.3)
  Art.box(side_face,'SideFlowerBox',Vector3(z,3.98,-.3),Vector3(1.75,.26,.45),wood)
  for dx in [-.6,0,.6]:plant(side_face,Vector3(z+dx,4.12,-.3),.42)
 for z in [-3.9,-1.3,4.6]:window(side_face,z,1.65,-.13,1.35,1.65)
 for y in [3.2,6.3]:Art.box(side_face,'SideFrameBand',Vector3(0,y,-.15),Vector3(11.8,.16,.16),wood)
 for z in [-5.65,-2.5,.5,3.5,5.65]:Art.box(side_face,'SideTimberUpright',Vector3(z,3.25,-.15),Vector3(.14,6.3,.14),wood)
 Art.box(side_face,'SmallEntryAwning',Vector3(2,2.9,-.4),Vector3(1.85,.12,.75),wood)
 # Chimney and subtle roof courses give the original simple roof a finished silhouette.
 var stone=Art.material('7b7868')
 chimney_piece(root,'StoneChimney',Vector3(-5.9,7.4,1.8),Vector3(.85,2,.8),stone)
 Art.box(root,'ChimneyCap',Vector3(-5.9,8.45,1.8),Vector3(1.02,.16,.96),wood)
 for y in [6.65,7.0,7.35,7.7,8.05]:chimney_piece(root,'ChimneyCourse'+str(y),Vector3(-5.9,y,1.8),Vector3(.88,.025,.83),bronze)
 # Publish only after exact mesh/collider guard checks above.
 wall.visible=false;body.collision_layer=0;body.collision_mask=0
 preload('res://scripts/inn_guest_finish_v094.gd').apply_front(root)
 var result={'ok':true,'main_door_width':2.4,'side_door_width':1.25,'side_door_height':2.6,'main_entrance_local':Vector3(0,0,-5.9),'side_entrance_local':Vector3(7.8,0,2),'lake_or_balcony_changes':false,'save_changes':false}
 inn.set_meta('inn_front_v087',result);return result
static func apply(world:Node3D)->Dictionary:
 var inn=world.get_node_or_null('SettlementInnExpansion/Inn') as Node3D
 if inn==null:return {'ok':false,'reason':'Inn has not been installed'}
 return apply_to_inn(inn)
