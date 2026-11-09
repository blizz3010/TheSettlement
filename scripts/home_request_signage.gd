extends RefCounted
# Visual-only mounted signage; no interactions, collision, progression or save writes.
const Kit=preload('res://scripts/market_signage.gd')
const Api=preload('res://scripts/market_expansion.gd')
static func hide_caption(label:Label3D):
 label.set_meta('hide_service_caption',true)
 label.visible=false
static func plaque(parent:Node3D,node_name:String,title:String,width:float,height:float,wood:Material,bronze:Material,ink:Material)->Node3D:
 var sign=Node3D.new();sign.name=node_name;parent.add_child(sign)
 for y in [-height/4,height/4]:
  Api.box(sign,'Timber sign course',Vector3(0,y,0),Vector3(width,height/2-.012,.10),wood)
 for y in [-height/2,height/2]:
  Api.box(sign,'Bronze edge',Vector3(0,y,.045),Vector3(width+.025,.035,.035),bronze)
 for x in [-width/2+.065,width/2-.065]:
  Api.box(sign,'End binding',Vector3(x,0,.057),Vector3(.05,height,.025),bronze)
  for y in [-height*.32,height*.32]:Kit.disc(sign,'Mounting rivet',Vector3(x,y,.078),.016,ink)
 # Text backface overlaps timber front by 1mm, matching market kit contact treatment.
 Kit.text(sign,'Raised lettering',title,Vector3(0,0,.058),.0030 if title=='REQUESTS' else .0031,ink)
 return sign
static func add_to(scene:Node3D):
 if scene.has_node('HomeRequestSignage'):return
 # Validate all new dependencies before adding markers/art or hiding old captions.
 var board=scene.get_node_or_null('RequestBoard')
 if board==null or board.has_node('PhysicalRequestBoardSign'):
  push_error('Request board facing requires one intact original board');return
 var backing:MeshInstance3D=null
 for child in board.get_children():
  if child is MeshInstance3D and child.mesh is BoxMesh and child.mesh.size==Vector3(1.8,1.5,.15) and child.position==Vector3(0,1.35,0):
   if backing!=null:
    push_error('Ambiguous original RequestBoard panel; no signage writes');return
   backing=child
 if backing==null or backing.material_override==null:
  push_error('Original RequestBoard panel/material missing; no signage writes');return
 var holder=Node3D.new();holder.name='HomeRequestSignage';scene.add_child(holder)
 var wood=preload('res://scripts/market_wall_finish.gd').wood()
 var bronze=Api.mat(Color('#9b7944'),.55);var ink=Api.mat(Color('#ecddae'),.25)
 for label in scene.wayfinding_labels:
  if label.text in ['YOUR HIDEOUT','HOME STASH','REQUEST BOARD\nStarter request']:hide_caption(label)
 # Front-facing plaque, attached to existing retaining face. It stays north of stairs.
 var home=plaque(holder,'YourHomePhysicalSign','Your Home',1.85,.48,wood,bronze,ink)
 home.position=Vector3(-15.91,2.38,10.40);home.rotation.y=PI/2
 # Existing board anchor/yaw, collider and interaction remain untouched.
 var board_art=Node3D.new();board_art.name='PhysicalRequestBoardSign';board.add_child(board_art)
 # Cover the original support fronts with one continuous, flush-backed facing.
 # Only the physical board art changes; original panel collider/supports stay exact.
 Api.box(board_art,'Request board facing',Vector3(0,1.35,.095),Vector3(1.8,1.5,.040),backing.material_override)
 var header=plaque(board_art,'RequestHeader','REQUESTS',1.65,.38,wood,bronze,ink)
 header.position=Vector3(0,1.83,.125)
 var paper=Api.mat(Color('#d6c398'));var faded=Api.mat(Color('#8b7b5e'));var wax=Api.mat(Color('#884733'))
 for i in range(3):
  var note=Node3D.new();note.name='Pinned notice '+str(i+1);board_art.add_child(note)
  note.position=Vector3(-.51+i*.51,1.18,.125);note.rotation.z=[.04,-.035,.025][i]
  Api.box(note,'Parchment sheet',Vector3.ZERO,Vector3(.42,.62,.018),paper)
  for line in range(4):
   Api.box(note,'Notice ink line',Vector3(-.025,.15-line*.075,.012),Vector3(.27 if line<3 else .17,.012,.008),faded)
  Kit.disc(note,'Notice bronze pin',Vector3(0,.265,.022),.018,bronze)
  Kit.disc(note,'Notice wax seal',Vector3(.10,-.20,.024),.042,wax)
 holder.set_meta('visual_only',true)
 board_art.set_meta('recurring_requests_implemented',false)
