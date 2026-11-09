extends RefCounted
# Detached architectural study. No world installation, service, economy or save hooks.
const FLOOR_HEIGHT=3.2
const SIZE=Vector2(16,12)
static func material(hex:String,roughness:float=.88)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=Color(hex);m.roughness=roughness;return m
static func group(parent:Node3D,label:String)->Node3D:
 var n=Node3D.new();n.name=label;parent.add_child(n);return n
static func box(parent:Node3D,label:String,at:Vector3,size:Vector3,mat:Material)->MeshInstance3D:
 var n=MeshInstance3D.new();n.name=label;n.position=at;var mesh=BoxMesh.new();mesh.size=size;n.mesh=mesh;n.material_override=mat;parent.add_child(n);return n
static func doorway(parent:Node3D,label:String,x:float,z:float,width:float,base:float,mat:Material):
 # Segmented partition with a real .95 m clear opening, not painted-on door.
 var side=(width-.95)/2
 box(parent,label+'Left',Vector3(x-(.95+side)/2,base+1.5,z),Vector3(side,3,.14),mat)
 box(parent,label+'Right',Vector3(x+(.95+side)/2,base+1.5,z),Vector3(side,3,.14),mat)
 box(parent,label+'Lintel',Vector3(x,base+2.625,z),Vector3(.95,.75,.14),mat)
static func table(parent:Node3D,label:String,at:Vector3,size:Vector2,wood:Material,metal:Material):
 box(parent,label+'Top',at+Vector3(0,.76,0),Vector3(size.x,.10,size.y),wood)
 for x in [-1,1]:
  for z in [-1,1]:box(parent,label+'Leg'+str(x)+str(z),at+Vector3(x*(size.x*.5-.16),.35,z*(size.y*.5-.16)),Vector3(.11,.70,.11),metal)
static func stool(parent:Node3D,label:String,at:Vector3,wood:Material,metal:Material):
 box(parent,label+'Seat',at+Vector3(0,.47,0),Vector3(.40,.08,.40),wood)
 for x in [-1,1]:
  for z in [-1,1]:box(parent,label+'Leg'+str(x)+str(z),at+Vector3(x*.14,.22,z*.14),Vector3(.065,.44,.065),metal)
static func create()->Node3D:
 var root=Node3D.new();root.name='InnArchitectureStudy'
 root.set_meta('status','Standalone architectural proposal; no live site, playable collision, lodging or minigame service')
 var stone=material('867f68');var wood=material('594936');var cream=material('c6bba1');var roofmat=material('47554f');var bronze=material('938064',.58);var cloth=material('859079');var glass=material('547c78',.35)
 var foundation=group(root,'FoundationAndVeranda')
 box(foundation,'RaisedStoneBase',Vector3(0,-.34,0),Vector3(16,.44,12),stone)
 box(foundation,'GroundFloorDeck',Vector3(0,-.06,0),Vector3(15.8,.12,11.8),wood)
 box(foundation,'EntryVeranda',Vector3(0,-.08,-7.1),Vector3(12,.16,2.2),wood)
 for x in [-5.7,5.7]:box(foundation,'VerandaPost'+str(x),Vector3(x,1.5,-8),Vector3(.20,3,.20),wood)
 box(foundation,'VerandaCanopy',Vector3(0,3.05,-7.1),Vector3(12.5,.15,2.5),roofmat)
 var exterior=group(root,'ExteriorWalls')
 # Front entrance clear width2.4 /height2.6. Upper front windows are inset panels.
 for x in [-4.6,4.6]:box(exterior,'EntryWing'+str(x),Vector3(x,1.55,-5.9),Vector3(6.8,3.1,.20),cream)
 box(exterior,'EntryLintel',Vector3(0,2.85,-5.9),Vector3(2.4,.5,.20),wood)
 for side in [-1,1]:
  box(exterior,'SideWall'+str(side),Vector3(side*7.8,3.2,0),Vector3(.20,6.4,11.8),cream)
 box(exterior,'RearWall',Vector3(0,3.2,5.9),Vector3(15.8,6.4,.20),cream)
 # Upper front bays: solid sill/header and narrow piers leave real glazed openings.
 box(exterior,'UpperFrontSill',Vector3(0,3.65,-5.9),Vector3(15.8,.9,.20),cream)
 box(exterior,'UpperFrontHeader',Vector3(0,5.95,-5.9),Vector3(15.8,.9,.20),cream)
 for x in [-7.65,-3.85,0,3.85,7.65]:box(exterior,'UpperPier'+str(x),Vector3(x,4.8,-5.9),Vector3(.30,1.4,.20),wood)
 for x in [-5.75,-1.925,1.925,5.75]:
  box(exterior,'UpperGlazing'+str(x),Vector3(x,4.8,-5.9),Vector3(3.45,1.35,.04),glass)
  box(exterior,'WindowMullion'+str(x),Vector3(x,4.8,-6.025),Vector3(.07,1.4,.08),wood)
 for x in [-7.8,0,7.8]:
  for z in [-6,6]:
   if x==0 and z==-6:
    box(exterior,'EntryUpperCenterPost',Vector3(0,4.55,-6),Vector3(.24,3.7,.24),wood)
   else:box(exterior,'FramePost'+str(x)+str(z),Vector3(x,3.2,z),Vector3(.24,6.4,.24),wood)
 for y in [.15,3.2,6.3]:
  for z in [-6,6]:
   if y==.15 and z==-6:
    for x in [-4.6,4.6]:box(exterior,'SplitEntryBaseBeam'+str(x),Vector3(x,y,z),Vector3(6.8,.20,.16),wood)
   else:box(exterior,'FrameBeam'+str(y)+str(z),Vector3(0,y,z),Vector3(16,.20,.16),wood)
 var ground=group(root,'GroundGatheringAndBar')
 # Bar is against west wall; arrival aisle x[-1.4,1.4],z[-5.8,.5] remains furniture-free.
 box(ground,'BarFront',Vector3(-4.8,.52,2.1),Vector3(4.5,1.04,.16),wood)
 box(ground,'BarWorktop',Vector3(-4.8,1.08,2.1),Vector3(4.7,.12,.70),bronze)
 for y in [.65,1.55,2.40]:box(ground,'BackBarShelf'+str(y),Vector3(-5,y,5.48),Vector3(4.7,.10,.48),wood)
 for x in [-6.6,-5,-3.4]:stool(ground,'BarStool'+str(x),Vector3(x,0,1.05),wood,bronze)
 # Two communal tables with freestanding stools; no interaction prompts implied.
 for x in [-4.7,2.7]:
  table(ground,'GatheringTable'+str(x),Vector3(x,0,-2.4),Vector2(2.5,1.1),wood,bronze)
  for z in [-3.35,-1.45]:
   for dx in [-.75,.75]:stool(ground,'GatheringSeat'+str(x)+str(z)+str(dx),Vector3(x+dx,0,z),wood,bronze)
 # Flexible activity area; blank table, no roulette/cards/currency/game rules.
 table(ground,'FutureActivityTable',Vector3(2.2,0,3.8),Vector2(2.5,1.6),cloth,wood)
 for x in [.5,3.9]:stool(ground,'ActivitySeat'+str(x),Vector3(x,0,3.8),wood,bronze)
 var stairs=group(root,'InternalStair')
 # Two10-riser flights: .16m rise/.32m tread,1.4m clear nominal width.
 # First flight ascends+Z, second ascends-Z; shared1.4m middle landing.
 for i in range(10):
  var y=(i+1)*.16
  box(stairs,'LowerTread%02d'%i,Vector3(4.9,y*.5,-4.5+(i+.5)*.32),Vector3(1.4,y,.32),wood)
  var upper=1.6+(i+1)*.16
  box(stairs,'UpperTread%02d'%i,Vector3(6.7,(upper+1.6)*.5,-1.3-(i+.5)*.32),Vector3(1.4,upper-1.6,.32),wood)
 box(stairs,'MiddleLanding',Vector3(5.8,1.52,-.6),Vector3(3.2,.16,1.4),wood)
 for x in [4.1,5.7,7.5]:
  for i in range(6):
   var z=-4.5+i*.64;var y=.16+(i*2)*.16 if x<6 else 3.2-(i*2)*.16
   box(stairs,'Baluster'+str(x)+str(i),Vector3(x,y+.48,z),Vector3(.07,.96,.07),bronze)
 var upper=group(root,'UpperRoomsAndLanding')
 # Stairwell opening x4..7.6,z-4.8..0.2; upper arrival is at north end.
 box(upper,'MainUpperFloor',Vector3(-1.9,3.14,0),Vector3(12,.12,11.6),wood)
 box(upper,'SouthLanding',Vector3(5.8,3.14,3),Vector3(3.6,.12,5.6),wood)
 box(upper,'NorthArrivalLanding',Vector3(5.8,3.14,-5.15),Vector3(3.6,.12,1.3),wood)
 # West corridor joins north arrival via clear north transverse passage.
 box(upper,'RoomDividerWest',Vector3(-2.7,4.7,3.4),Vector3(.14,3,4.6),cream)
 box(upper,'RoomDividerNorth',Vector3(-2.7,4.7,-2.85),Vector3(.14,3,3.5),cream)
 box(upper,'RoomEastWallNorth',Vector3(2.3,4.7,-2.85),Vector3(.14,3,3.5),cream)
 box(upper,'RoomEastWallSouth',Vector3(2.3,4.7,3.4),Vector3(.14,3,4.6),cream)
 for z in [-1.1,1.1]:
  doorway(upper,'RoomDoorWest'+str(z),-5.2,z,5,3.2,cream)
  doorway(upper,'RoomDoorEast'+str(z),-.2,z,5,3.2,cream)
 for x in [-5.2,-.2]:
  for z in [-3.0,3.7]:
   box(upper,'BedFrame'+str(x)+str(z),Vector3(x,3.48,z),Vector3(1.5,.40,2.2),wood)
   box(upper,'BedCover'+str(x)+str(z),Vector3(x,3.72,z),Vector3(1.42,.12,2.12),cloth)
   box(upper,'BedPillow'+str(x)+str(z),Vector3(x,3.82,z+.65),Vector3(1.15,.14,.38),cream)
 # Guard the stairwell edge; leave north arrival and corridor access open.
 for z in [-4.4,-3.4,-2.4,-1.4,-.4]:box(upper,'WellPost'+str(z),Vector3(3.88,3.72,z),Vector3(.08,1.04,.08),bronze)
 box(upper,'WellRail',Vector3(3.88,4.22,-2.4),Vector3(.09,.09,4.8),wood)
 var roof=group(root,'RoofRemovableForCutaway')
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var a=Vector3(-8.5,6.4,-6.5);var b=Vector3(8.5,6.4,-6.5);var c=Vector3(-8.5,6.4,6.5);var d=Vector3(8.5,6.4,6.5);var l=Vector3(-8.5,8.2,0);var r=Vector3(8.5,8.2,0)
 for tri in [[a,l,b],[b,l,r],[l,c,r],[r,c,d],[a,c,l],[b,r,d]]:
  var normal=(tri[1]-tri[0]).cross(tri[2]-tri[0]).normalized()
  for p in [tri[2],tri[1],tri[0]]:st.set_normal(normal);st.add_vertex(p)
 var mesh=MeshInstance3D.new();mesh.name='PitchedRoof';mesh.mesh=st.commit();mesh.material_override=roofmat;roof.add_child(mesh)
 box(roof,'RidgeCap',Vector3(0,8.22,0),Vector3(17,.12,.14),bronze)
 preload('res://scripts/inn_interior_v094.gd').apply(root)
 preload('res://scripts/inn_guest_finish_v094.gd').apply_interior(root)
 var finish_result=preload('res://scripts/inn_room_rear_finish_v096.gd').apply(root)
 if not finish_result.get('ok',false):
  push_error('INN_ARCHITECTURE_FINISH_REFUSED '+str(finish_result))
  root.free();return null
 root.set_meta('layout',{'shell_xz':SIZE,'upper_floor_y':3.2,'stair_risers':20,'riser':.16,'tread':.32,'rooms':4,'no_collision_or_service':true})
 return root
