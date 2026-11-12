extends RefCounted
## Authored, player-scale industrial blockout inspired by the supplied concept.
## All positions are local to the existing Glasskiln POI. No economy/state changes.
const WALL=Color("77716a")
const RUST=Color("98664b")
const DARK=Color("46464a")
const DECK=4.2
var world:Node3D

func build(owner:Node3D,root:Node3D,poi:Dictionary):
	world=owner
	root.set_meta("campus_version",1)
	root.set_meta("campus_buildings",["FurnaceHall","ControlHouse","Warehouse","Workshop","PowerShed"])
	# The workshop retains the existing key, single cache and loot band.
	var workshop=Node3D.new();workshop.name="Workshop";workshop.position=Vector3(-21,0,5);root.add_child(workshop)
	world._room(workshop,poi,10,10)
	world._label(workshop,"MAINTENANCE / LOCKED CACHE",Vector3(0,4.6,5.3),poi.theme,20)
	var hall=_shell(root,"FurnaceHall",Vector2(0,-27),Vector2(26,20),9.2,true)
	var control=_shell(root,"ControlHouse",Vector2(-21,-11),Vector2(12,14),7.6,true)
	var warehouse=_shell(root,"Warehouse",Vector2(22,-11),Vector2(14,20),7.6,true)
	var power=_shell(root,"PowerShed",Vector2(24,-29),Vector2(10,10),4.2,false)
	world._label(hall,"TWIN FURNACE HALL",Vector3(0,7.9,10.3),Color("e1b27d"),25)
	world._label(control,"CONTROL",Vector3(0,3.7,7.3),Color("b8c5ba"),20)
	world._label(warehouse,"LOADING / STORAGE",Vector3(0,6.3,10.3),Color("d8bb8b"),23)
	world._label(power,"POWER",Vector3(0,3.6,6.3),Color("e0c885"),19)
	# Two furnace bodies are readable inside and from the exterior stacks.
	for x in [-6.0,6.0]:
		world._tank(hall,Vector3(x,0,-1),7.9,2.5,RUST)
		world._tank(hall,Vector3(x,7.9,-1),10.2,0.82,DARK)
		for y in [1.1,4.0,7.2]:world._cylinder(hall,Vector3(x,y,-1),0.18,2.62,Color("b18a63"))
		world._box(hall,Vector3(x,1.0,1.45),Vector3(1.65,2,0.22),DARK,false)
		world._box(hall,Vector3(x,1.0,1.58),Vector3(0.9,0.65,0.06),Color("bd7850"),false)
	# Equipment sits against room walls, leaving the through-routes open.
	for x in [-4.5,4.5]:world._box(control,Vector3(x,0.7,2.2),Vector3(1.4,1.4,2.6),Color("59716c"))
	for z in [-5,1,6]:
		var large=world._prop_body(warehouse,Vector3(4.8,1.1,z),Vector3(2.2,2.2,2.8))
		var pallet=world._prop_body(warehouse,Vector3(-4.8,0.75,z),Vector3(1.6,1.5,2.3))
		world.Cargo.attach(large,"stack_large",true)
		world.Cargo.attach(pallet,"stack_pallet",true)
	for x in [-3,3]:world._box(power,Vector3(x,1.3,-1),Vector3(2.0,2.6,4),Color("53605d"))
	# Upper service route links hall and control/warehouse galleries. Both ends
	# have independent 2.6 m stairs; no jumping, ladders or one-way drop required.
	_deck(root,Vector3(0,DECK,-11),Vector2(33,3))
	_deck(root,Vector3(0,DECK,-14.5),Vector2(3,5))
	_deck(root,Vector3(0,DECK,-18.5),Vector2(24,3))
	_deck(root,Vector3(-16.5,DECK,-11),Vector2(3,3))
	_deck(root,Vector3(16.5,DECK,-11),Vector2(3,3))
	for x in [-12.0,12.0]:_stairs(root,x)
	# Guardrails have simple full-height collision, visual open bars, and gaps
	# only at the stair landings and the hall branch.
	_rail(root,Vector3(0,DECK,-9.5),20.7,false)
	for x in [-7.5,7.5]:_rail(root,Vector3(x,DECK,-12.5),12.0,false)
	for x in [-1.5,1.5]:_rail(root,Vector3(x,DECK,-14.5),4.0,true)
	_rail(root,Vector3(0,DECK,-20),24.0,false)
	for x in [-7.0,7.0]:_rail(root,Vector3(x,DECK,-17),10.0,false)
	for x in [-12,12]:_rail(root,Vector3(x,DECK,-18.5),3.0,true)
	for x in [-18,18]:_rail(root,Vector3(x,DECK,-11),3.0,true)
	for x in [-15.65,15.65]:
		_rail(root,Vector3(x,DECK,-9.5),4.7,false)
		_rail(root,Vector3(x,DECK,-12.5),4.7,false)
	for x in [-8,8]:world._box(root,Vector3(x,2.0,-11),Vector3(0.28,4,0.28),RUST)
	# Overhead pipework links the power shed and the hall without blocking a
	# standing player's ground or upper route.
	_pipe(root,Vector3(0,7.7,-13.5),Vector3(25,7.7,-13.5),0.22)
	_pipe(root,Vector3(25,7.7,-13.5),Vector3(25,7.7,-28),0.22)
	for x in [-6,6]:_pipe(root,Vector3(x,6.9,-24),Vector3(x,6.9,-13.5),0.18)
	# Staggered cargo islands break the open yard sightline while keeping a
	# central approach and broad flanking lanes. No extra loot rolls are added.
	for island in [Vector3(-5.8,0.8,7.5),Vector3(5.8,1.15,3.5),Vector3(5.8,0.6,14.5)]:
		world._box(root,island,Vector3(3.0,island.y*2,2.6),Color("9c7e57"))
		world._box(root,island+Vector3(0,island.y+0.08,0),Vector3(3.1,0.16,2.7),Color("554e48"),false)
	for x in [-4.5,4.5]:world._box(root,Vector3(x,0.015,20),Vector3(0.12,0.03,6),Color("c6aa6e"),false)
	world._label(root,"GLASSKILN LOADING YARD",Vector3(0,3.2,20),poi.theme,27)

func _shell(root:Node3D,name:String,centre:Vector2,size:Vector2,height:float,side_doors:bool)->Node3D:
	var room=Node3D.new();room.name=name;room.position=Vector3(centre.x,0,centre.y);root.add_child(room)
	world._box(room,Vector3(0,-0.12,0),Vector3(size.x,0.24,size.y),Color("938675"))
	for z in [-size.y*0.5,size.y*0.5]:_wall(room,Vector3(0,0,z),size.x,height,4.0,false)
	for x in [-size.x*0.5,size.x*0.5]:_wall(room,Vector3(x,0,0),size.y,height,3.6 if side_doors else 0.0,true)
	world._box(room,Vector3(0,height+0.12,0),Vector3(size.x+0.6,0.24,size.y+0.6),DARK)
	for z in [-size.y*0.5,size.y*0.5]:world._box(room,Vector3(0,height-0.25,z),Vector3(size.x+0.4,0.22,0.5),RUST,false)
	return room

func _wall(root:Node3D,at:Vector3,length:float,height:float,opening:float,turn:bool):
	# A tall central opening supports a ground door and the elevated gallery.
	var jamb=(length-opening)*0.5
	for sign_value in [-1,1]:
		var centre=sign_value*(opening+jamb)*0.5
		var position=at+Vector3(0,height*0.5,centre) if turn else at+Vector3(centre,height*0.5,0)
		world._box(root,position,Vector3(0.3,height,jamb) if turn else Vector3(jamb,height,0.3),WALL)
	if opening>0:
		var clearance=minf(7.0,height-0.55)
		world._box(root,at+Vector3(0,(height+clearance)*0.5,0),Vector3(0.3,height-clearance,opening) if turn else Vector3(opening,height-clearance,0.3),WALL)

func _deck(root:Node3D,at:Vector3,size:Vector2):
	world._box(root,at-Vector3(0,0.12,0),Vector3(size.x,0.24,size.y),RUST)
	for z in [-size.y*0.5+0.15,size.y*0.5-0.15]:world._box(root,at+Vector3(0,0.015,z),Vector3(size.x,0.03,0.10),Color("ccb57c"),false)

func _rail(root:Node3D,at:Vector3,length:float,turn:bool):
	var barrier=StaticBody3D.new();barrier.position=at;root.add_child(barrier)
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(0.12,1.1,length) if turn else Vector3(length,1.1,0.12);shape.shape=box;shape.position.y=0.55;barrier.add_child(shape)
	for y in [0.5,1.05]:world._box(barrier,Vector3(0,y,0),Vector3(0.1,0.08,length) if turn else Vector3(length,0.08,0.1),RUST,false)
	var posts=maxi(1,ceili(length/2.0))
	for i in range(posts+1):
		var offset=-length*0.5+length*float(i)/posts
		world._box(barrier,Vector3(0,0.55,offset) if turn else Vector3(offset,0.55,0),Vector3(0.10,1.1,0.10),RUST,false)

func _stairs(root:Node3D,x:float):
	var stairs=Node3D.new();stairs.name="WestStair" if x<0 else "EastStair";root.add_child(stairs)
	# 20 real 21 cm treads, below the unchanged production step-up limit.
	for i in 20:
		var top=(i+1)*0.21;var z=3.0-(i+0.5)*0.625
		world._box(stairs,Vector3(x,top*0.5,z),Vector3(2.6,top,0.625),RUST)
	for side in [-1,1]:
		var rail=Node3D.new();rail.position=Vector3(x+side*1.3,DECK*0.5,-3.25);rail.rotation.x=atan2(DECK,12.5);stairs.add_child(rail)
		_rail(rail,Vector3.ZERO,sqrt(12.5*12.5+DECK*DECK),true)

func _pipe(root:Node3D,start:Vector3,end:Vector3,radius:float):
	var pipe=world._cylinder(root,(start+end)*0.5,start.distance_to(end),radius,RUST)
	pipe.quaternion=Quaternion(Vector3.UP,(end-start).normalized())
