extends RefCounted
## Original procedural dressing. Room, door, credentials and cache remain owned
## by cinder_world. All low additions stay outside the existing playable room.
func box(w, p:Node3D, name:String, at:Vector3, size:Vector3, color:Color, solid:bool=false)->Node3D:
	var n:Node3D=w._box(p,at,size,color,solid);n.name=name;return n
func ring(w,p:Node3D,name:String,y:float,height:float,bottom:float,top:float,color:Color)->MeshInstance3D:
	var n:MeshInstance3D=w._cylinder(p,Vector3(0,y,-0.5),height,bottom,color)
	n.name=name;n.mesh.top_radius=top;n.mesh.radial_segments=10;return n
func build_helion(w,root:Node3D):
	var art=Node3D.new();art.name="HelionLandmark";root.add_child(art)
	var stone=Color("afa48d");var frame=Color("736950");var bronze=Color("a18b56")
	# Foot and shaft begin above the unchanged roof, not in the cache room.
	box(w,art,"ReceiverFoot",Vector3(0,4.25,-0.5),Vector3(2.1,0.45,2.1),stone)
	w._tank(art,Vector3(0,4.4,-0.5),12.2,0.68,stone)
	for y in [6.7,9.7,12.7,15.7]:ring(w,art,"ShaftJoint",y,0.08,0.7,0.7,frame)
	ring(w,art,"CrownLowerFacet",17.1,1.0,0.72,1.65,bronze)
	ring(w,art,"CrownReceiver",18.0,0.8,1.65,1.65,Color("796d50"))
	ring(w,art,"CrownUpperFacet",18.8,0.8,1.65,1.12,bronze)
	ring(w,art,"CrownCap",19.23,0.06,1.12,1.12,frame)
	for x in [-13.0,13.0]:
		for z in [-8.0,1.0]:
			var pedestal=Node3D.new();pedestal.name="MirrorPedestal_%s_%s"%[int(x),int(z)];pedestal.position=Vector3(x,0,z);art.add_child(pedestal)
			box(w,pedestal,"Plinth",Vector3(0,0.18,0),Vector3(1.4,0.36,1.4),stone,true)
			w._tank(pedestal,Vector3(0,0.36,0),1.8,0.25,frame)
			for y in [0.5,1.1,1.9]:w._cylinder(pedestal,Vector3(0,y,0),0.16,0.38,bronze)
			box(w,pedestal,"Axle",Vector3(0,2.2,0),Vector3(1.3,0.22,0.3),frame)
			# Telescoping cradle links the axle to the tilted backplate, without
			# adding ground collision or exposing a support through the mirror face.
			box(w,pedestal,"MirrorCradle",Vector3(0,2.65,0),Vector3(0.3,0.85,0.3),bronze)
			var hinge:MeshInstance3D=w._cylinder(pedestal,Vector3(0,3.0,0),0.8,0.18,frame)
			hinge.name="TiltHinge";hinge.rotation_degrees.z=90
			var panel=Node3D.new();panel.name="SegmentedMirror";panel.position=Vector3(0,3.15,0);panel.rotation_degrees=Vector3(-34,0,-12 if x<0 else 12);pedestal.add_child(panel)
			box(w,panel,"Backplate",Vector3.ZERO,Vector3(5.2,0.16,5.2),frame)
			for u in [-1.29,1.29]:
				for v in [-1.29,1.29]:
					var tile=box(w,panel,"ReflectorTile",Vector3(u,0.105,v),Vector3(2.46,0.06,2.46),Color("b8cbd0") if u==v else Color("a9c1ca"))
					var mesh:MeshInstance3D=tile.get_child(0);mesh.material_override.metallic=0.72;mesh.material_override.roughness=0.24
			for edge in [-2.55,2.55]:
				box(w,panel,"OuterFrame",Vector3(edge,0.14,0),Vector3(0.12,0.2,5.2),bronze)
				box(w,panel,"OuterFrame",Vector3(0,0.14,edge),Vector3(5.2,0.2,0.12),bronze)
			box(w,panel,"CrossFrame",Vector3(0,0.15,0),Vector3(0.09,0.12,5.0),frame)
			box(w,panel,"CrossFrame",Vector3(0,0.15,0),Vector3(5.0,0.12,0.09),frame)
	# Original 10 x 8 control room retained; trim never narrows the 2.6 m opening.
	facade(w,art,5.0,stone,bronze,false)
	box(w,art,"ControlRoofFascia",Vector3(0,4.03,1),Vector3(10.66,0.2,8.66),stone)
	panel_reader(w,art,false)
func build_obsidian(w,root:Node3D):
	var art=Node3D.new();art.name="ObsidianLandmark";root.add_child(art)
	var basalt=Color("37373b");var concrete=Color("77746e");var blue=Color("567b96")
	# 1.65 m first riser and no stairs/ladders: not an authored climb route.
	# Inner edge stays x=6.2, outside the unchanged 12 m room and its walls.
	for side in [-1.0,1.0]:
		for tier in 4:
			var width=5.8-tier*1.25;var depth=13.0-tier*1.5
			var center=Vector3(side*(6.2+width*0.5),0.825+tier*1.65,-3.0)
			box(w,art,"BasaltWingTier",center,Vector3(width,1.65,depth),basalt.lightened(tier*0.025),true)
			# Thin courses and staggered joints add weathered masonry without textures.
			box(w,art,"WingCourse",center+Vector3(0,0.78,0),Vector3(width+0.02,0.07,depth+0.02),Color("56544f"))
			for part in 3:
				box(w,art,"WingJoint",center+Vector3((part-1)*width/3,0,depth*0.5+0.012),Vector3(0.035,1.48,0.018),Color("24272b"))
	# Compact upper mass supported by the existing roof; no new enterable floor.
	box(w,art,"UpperFacility",Vector3(0,5.65,-1),Vector3(11.2,3.25,10.8),concrete)
	box(w,art,"BlueParapet",Vector3(0,7.38,-1),Vector3(11.6,0.3,11.2),blue)
	box(w,art,"InsetRoof",Vector3(0,7.54,-1),Vector3(10.9,0.06,10.5),Color("938e80"))
	facade(w,art,6.0,concrete,blue,true)
	for x in [-3.5,3.5]:
		window(w,art,Vector3(x,5.75,4.43),blue)
		for y in [4.3,6.9]:box(w,art,"WeatherCourse",Vector3(x,y,4.42),Vector3(3.7,0.035,0.025),Color("545650"))
	for x in [-4.8,-1.8,1.8,4.8]:
		box(w,art,"UpperPanelJoint",Vector3(x,5.7,4.42),Vector3(0.035,3.1,0.025),Color("55544f"))
		box(w,art,"RainMark",Vector3(x+0.18,6.95,4.44),Vector3(0.09,0.45,0.02),Color("686962"))
	panel_reader(w,art,true)
func facade(w,art:Node3D,half_width:float,stone:Color,trim:Color,archive:bool):
	for side in [-1.0,1.0]:
		box(w,art,"FrontFacing",Vector3(side*(half_width+1.45)*0.5,1.9,5.17),Vector3(half_width-1.45,3.8,0.035),stone)
		box(w,art,"DoorJamb",Vector3(side*1.4,1.4,5.22),Vector3(0.16,2.8,0.16),trim)
		window(w,art,Vector3(side*(half_width-1.3),2.65,5.22),trim)
		for y in [0.65,1.9,3.65]:box(w,art,"FacingCourse",Vector3(side*(half_width+1.6)*0.5,y,5.2),Vector3(half_width-1.6,0.035,0.025),stone.darkened(0.24))
	box(w,art,"DoorLintel",Vector3(0,2.8,5.22),Vector3(2.96,0.15,0.16),trim)
	if archive:box(w,art,"LowerBlueFascia",Vector3(0,3.95,-1),Vector3(12.66,0.22,12.66),trim)
func window(w,art:Node3D,at:Vector3,trim:Color):
	box(w,art,"WindowFrame",at,Vector3(1.55,0.8,0.1),trim)
	box(w,art,"WindowGlass",at+Vector3(0,0,0.06),Vector3(1.28,0.54,0.04),Color("252f36"))
	box(w,art,"WindowMullion",at+Vector3(0,0,0.09),Vector3(0.06,0.54,0.04),trim)
func panel_reader(w,art:Node3D,card:bool):
	var at=Vector3(2.0,1.55,5.28)
	box(w,art,"CardReader" if card else "CalibrationPanel",at,Vector3(0.48,0.78,0.16),Color("454c50"))
	box(w,art,"StatusLamp",at+Vector3(0,0.23,0.09),Vector3(0.27,0.08,0.035),Color("84bbc6"))
	if card:
		box(w,art,"CardSlot",at+Vector3(0,-0.06,0.1),Vector3(0.35,0.055,0.04),Color("151b21"))
		box(w,art,"CardPictogram",at+Vector3(0,-0.23,0.1),Vector3(0.19,0.12,0.025),Color("bfd0d3"))
	else:
		for x in 3:
			for y in 3:box(w,art,"CalibrationKey",at+Vector3((x-1)*0.1,0.05-y*0.12,0.1),Vector3(0.065,0.07,0.025),Color("bfbba7"))
