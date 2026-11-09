extends RefCounted
# Original physical trader sign kit. Existing DejaVu Serif license retained in assets/fonts.
# No service implementation, inventory, interaction, collision or save dependencies.
static func profile(root:Node3D,n:String,points:Array,depth:float,m:Material):
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_smooth_group(-1)
 # Convex sign silhouette, facing local +Z.
 for z in [-depth/2,depth/2]:
  for i in range(1,points.size()-1):
   var order=[0,i+1,i] if z>0 else [0,i,i+1]
   for j in order:st.add_vertex(Vector3(points[j].x,points[j].y,z))
 for i in range(points.size()):
  var a=points[i];var b=points[(i+1)%points.size()]
  for v in [Vector3(a.x,a.y,-depth/2),Vector3(b.x,b.y,depth/2),Vector3(b.x,b.y,-depth/2),Vector3(a.x,a.y,-depth/2),Vector3(a.x,a.y,depth/2),Vector3(b.x,b.y,depth/2)]:st.add_vertex(v)
 st.generate_normals();var node=MeshInstance3D.new();node.name=n;node.mesh=st.commit();node.material_override=m;root.add_child(node);return node
static func text(root:Node3D,n:String,value:String,p:Vector3,pixel:float,m:Material):
 var mesh=TextMesh.new();mesh.font=preload('res://assets/fonts/DejaVuSerif.ttf');mesh.text=value;mesh.font_size=64;mesh.pixel_size=pixel;mesh.depth=.018;mesh.curve_step=1.2
 mesh.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;mesh.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 var node=MeshInstance3D.new();node.name=n;node.mesh=mesh;node.position=p;node.material_override=m;root.add_child(node);return node
static func disc(root:Node3D,n:String,p:Vector3,r:float,m:Material):
 var mesh=CylinderMesh.new();mesh.top_radius=r;mesh.bottom_radius=r;mesh.height=.022;mesh.radial_segments=20
 var node=MeshInstance3D.new();node.name=n;node.mesh=mesh;node.material_override=m;node.rotation.x=PI/2;node.position=p;root.add_child(node);return node
static func arrow(root:Node3D,api,n:String,p:Vector3,signum:float,m:Material):
 api.box(root,n+' shaft',p,Vector3(.38,.055,.035),m)
 var points=[Vector2(-.10,-.12),Vector2(.13,0),Vector2(-.10,.12)]
 var head=profile(root,n+' head',points,.035,m);head.position=p+Vector3(signum*.24,0,0);head.rotation.z=0 if signum>0 else PI
static func apply(root:Node3D,specs:Array,api,materials:Dictionary):
 var rust=api.mat(Color('#8f3928'));var teal=api.mat(Color('#235b59'));var lettering=api.mat(Color('#ecddae'),.25)
 var bronze=materials.bronze;var dark=materials.dark;var wood=materials.wood
 for spec in specs:
  var shop=root.get_node(spec.id+'Stand');var front:float=spec.depth/2-.7
  for child in shop.get_children():
   if child is Label3D and child.text==spec.title:child.free()
  shop.get_node('Sign backing').free()
  var sign=Node3D.new();sign.name='AuthoredPhysicalTraderSign';shop.add_child(sign);sign.position=Vector3(0,3.13,front+.15)
  var half:float=minf(spec.width/2-.5,3.7)
  # The hanging straps physically reach the existing front beam.
  for x in [-half+.28,half-.28]:
   api.box(sign,'Bronze mounting strap',Vector3(x,.39,-.035),Vector3(.11,.55,.10),bronze)
   for y in [.19,.56]:disc(sign,'Mounting rivet',Vector3(x,y,.027),.032,lettering)
  if spec.id=='Psy':
   var shape=[Vector2(-half,-.39),Vector2(half,-.39),Vector2(half,.39),Vector2(half-.28,.50),Vector2(-half+.28,.50),Vector2(-half,.39)]
   profile(sign,'Forged bronze outfitter sign rim',shape,.13,bronze)
   var panel=profile(sign,'Rust enamel inset',shape,.025,rust);panel.position.z=.08;panel.scale=Vector3(.977,.88,1)
   var icon=Node3D.new();icon.name='Original bronze helmet crest';sign.add_child(icon);icon.position=Vector3(-half+1.70,.02,.115)
   var helmet=profile(icon,'Helmet dome relief',[Vector2(-.30,-.24),Vector2(.30,-.24),Vector2(.34,.07),Vector2(.23,.26),Vector2(0,.34),Vector2(-.23,.26),Vector2(-.34,.07)],.045,bronze)
   api.box(icon,'Crest dark visor',Vector3(0,.03,.035),Vector3(.43,.20,.035),dark)
   api.box(icon,'Crest visor brow',Vector3(0,.16,.055),Vector3(.49,.045,.035),lettering)
   for side in [-1,1]:disc(icon,'Crest ear plate',Vector3(side*.34,-.025,.025),.07,bronze)
   text(sign,'Raised outfitter lettering','P S Y',Vector3(.35,.18,.1005),.008,lettering)
   text(sign,'Outfitter role engraving','GEAR & ARMOR',Vector3(.35,-.21,.1005),.0035,lettering)
  elif spec.id=='Atlas':
   var shape=[Vector2(-half+.15,-.46),Vector2(half-.15,-.46),Vector2(half,-.30),Vector2(half,.30),Vector2(half-.15,.46),Vector2(-half+.15,.46),Vector2(-half,.30),Vector2(-half,-.30)]
   profile(sign,'Recovery brass plate surround',shape,.12,bronze)
   var panel=profile(sign,'Teal utility enamel plate',shape,.025,teal);panel.position.z=.075;panel.scale=Vector3(.975,.88,1)
   var icon=Node3D.new();icon.name='Original recovery return crest';sign.add_child(icon);icon.position=Vector3(-half+.65,0,.1075)
   var tag=profile(icon,'Recovery luggage tag',[Vector2(-.24,-.26),Vector2(.24,-.26),Vector2(.24,.17),Vector2(0,.34),Vector2(-.24,.17)],.04,lettering)
   disc(icon,'Tag punched eye',Vector3(0,.21,.03),.035,dark)
   arrow(icon,api,'Returning arrow',Vector3(0,-.06,.0365),-1,teal)
   text(sign,'Raised recovery lettering','A T L A S',Vector3(.40,.17,.0955),.0066,lettering)
   text(sign,'Recovery role engraving','RECOVERY',Vector3(.40,-.22,.0955),.0035,lettering)
   for x in [-half+.16,half-.16]:
    for y in [-.30,.30]:disc(sign,'Plate corner rivet',Vector3(x,y,.0985),.026,lettering)
  else:
   # Three real timber courses, trimmed with bronze rather than a flat UI rectangle.
   for y in [-.30,0,.30]:api.box(sign,'Carved market timber course',Vector3(0,y,0),Vector3(half*2,.282,.15),wood)
   for y in [-.45,.45]:api.box(sign,'Market sign bronze edge',Vector3(0,y,.08),Vector3(half*2+.06,.055,.055),bronze)
   for x in [-half+.16,half-.16]:
    api.box(sign,'Market sign end binding',Vector3(x,0,.095),Vector3(.10,.88,.035),bronze)
    for y in [-.30,.30]:disc(sign,'Timber binding rivet',Vector3(x,y,.124),.028,lettering)
   # Original market-stall maker badge; code-native relief, no external artwork.
   var icon=Node3D.new();icon.name="Dan marketplace maker crest";sign.add_child(icon);icon.position=Vector3(-half+.78,0,.085)
   var outline=[Vector2(-.42,-.24),Vector2(0,-.46),Vector2(.42,-.24),Vector2(.42,.24),Vector2(0,.46),Vector2(-.42,.24)]
   profile(icon,'Bronze maker badge rim',outline,.04,bronze)
   var inset=profile(icon,'Maker badge dark inset',outline,.022,dark);inset.scale=Vector3(.88,.88,1);inset.position.z=.032
   var roof=profile(icon,'Marketplace canopy relief',[Vector2(-.29,.08),Vector2(.29,.08),Vector2(.21,.27),Vector2(-.21,.27)],.025,lettering);roof.position.z=.06
   for x in [-.17,0.0,.17]:api.box(icon,'Canopy carved stripe',Vector3(x,.17,.082),Vector3(.045,.15,.014),bronze)
   for x in [-.23,.23]:api.box(icon,'Market stall upright relief',Vector3(x,-.07,.067),Vector3(.045,.30,.028),bronze)
   api.box(icon,'Market stall counter relief',Vector3(0,-.21,.073),Vector3(.54,.07,.04),lettering)
   text(sign,'Raised market lettering','DAN’S',Vector3(.4,.18,.083),.008,lettering)
   text(sign,'Market role engraving','Marketplace',Vector3(.4,-.21,.083),.0052,lettering)
  # Keep honest nonfunctional notice visible; no new service text is invented.
  sign.set_meta('original_physical_sign',{'role':spec.id,'font':'DejaVu Serif','new_services':false})
  assert(sign.find_children('*','CollisionObject3D',true,false).is_empty())
