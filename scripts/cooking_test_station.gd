extends Node3D
signal opened
signal closed
const State=preload("res://scripts/cooking_test_state.gd")
const CookingPanel=preload("res://scripts/cooking_test_panel.gd")
var session=State.new()
var panel
var actor:Node3D
var tray_visual:Node3D
var blocked_by_other_modal:bool=false
var host_bound:bool=false
var host_access:Callable
var own_collider:StaticBody3D
func _ready():
	name="CampfireGriddle_TEST"
	build_visual()
	var canvas=CanvasLayer.new();add_child(canvas)
	panel=CookingPanel.new();canvas.add_child(panel)
	panel.action_allowed=func():return can_open(actor)
	panel.closed.connect(close_panel);panel.sample_changed.connect(refresh_samples)
	refresh_samples()
func material(color:Color) -> StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.9;return m
func part(mesh:Mesh,pos:Vector3,size:Vector3,color:Color,parent:Node3D=null) -> MeshInstance3D:
	var item=MeshInstance3D.new();item.mesh=mesh;item.position=pos;item.scale=size;item.material_override=material(color);(self if parent==null else parent).add_child(item);return item
func build_visual():
	# Same .9m footprint and existing session/collider; visuals only.
	var iron=Color("303638");var bronze=Color("8e714a");var wood=Color("73543b")
	var rim=CylinderMesh.new();rim.top_radius=.44;rim.bottom_radius=.42;rim.height=.10;rim.radial_segments=24
	part(rim,Vector3(0,.71,0),Vector3.ONE,iron)
	var cooktop=CylinderMesh.new();cooktop.top_radius=.385;cooktop.bottom_radius=.385;cooktop.height=.012;cooktop.radial_segments=24
	part(cooktop,Vector3(0,.767,0),Vector3.ONE,Color("192221"))
	for x in [-.29,.29]:
		for z in [-.29,.29]:
			part(BoxMesh.new(),Vector3(x,.34,z),Vector3(.075,.68,.075),iron)
			part(BoxMesh.new(),Vector3(x,.035,z),Vector3(.11,.07,.11),bronze)
	for z in [-.29,.29]:part(BoxMesh.new(),Vector3(0,.17,z),Vector3(.64,.055,.055),iron)
	part(BoxMesh.new(),Vector3(0,.17,0),Vector3(.60,.035,.53),wood)
	var box=CylinderMesh.new();box.top_radius=.30;box.bottom_radius=.24;box.height=.22;box.radial_segments=16
	part(box,Vector3(0,.55,0),Vector3.ONE,iron)
	for x in [-.14,0,.14]:
		var logmesh=CylinderMesh.new();logmesh.top_radius=.055;logmesh.bottom_radius=.055;logmesh.height=.40;logmesh.radial_segments=8
		var logpart=part(logmesh,Vector3(x,.245,0),Vector3.ONE,wood);logpart.rotation.x=PI/2
	part(BoxMesh.new(),Vector3(0,.57,.335),Vector3(.40,.15,.025),bronze)
	var sign=Label3D.new();sign.name="AttachedGriddlePlaque";sign.text="GRIDDLE";sign.position=Vector3(0,.57,.350);sign.font_size=28;sign.pixel_size=.0013;sign.modulate=Color("f0dfb6");sign.outline_size=2;add_child(sign)
	# Attached preparation detail stays within the existing .9m station footprint.
	part(BoxMesh.new(),Vector3(0,.43,-.335),Vector3(.48,.025,.025),bronze)
	for x in [-.16,.16]:
		part(BoxMesh.new(),Vector3(x,.35,-.355),Vector3(.018,.15,.018),wood)
		part(BoxMesh.new(),Vector3(x,.265,-.355),Vector3(.065,.045,.012),iron)
	part(BoxMesh.new(),Vector3(.19,.20,.09),Vector3(.17,.025,.24),Color("c5b99a"))
	# Compact shelter: supports remain inside the already blocked griddle cylinder.
	for x in [-.29,.29]:
		part(BoxMesh.new(),Vector3(x,1.51,-.29),Vector3(.055,1.64,.055),wood)
	part(BoxMesh.new(),Vector3(0,2.30,-.29),Vector3(.68,.14,.07),bronze)
	part(BoxMesh.new(),Vector3(0,2.39,0),Vector3(.98,.08,.96),wood)
	# Shallow canvas shelter above the unchanged timber frame. No new obstruction
	# below the existing 2.35 m canopy underside or outside its .98 x .96 footprint.
	var pitch=atan2(.16,.46)
	var panel_length=sqrt(.46*.46+.16*.16)
	for side in [-1,1]:
		var canvas=part(BoxMesh.new(),Vector3(side*.23,2.47,0),Vector3(panel_length,.025,.90),Color("c8b58e"))
		canvas.name="CanvasRoofLeft" if side<0 else "CanvasRoofRight"
		canvas.rotation.z=-side*pitch
	var ridge=part(BoxMesh.new(),Vector3(0,2.555,0),Vector3(.035,.025,.92),bronze)
	ridge.name="ShelterRidgeBinding"
	part(BoxMesh.new(),Vector3(0,2.31,.43),Vector3(.86,.14,.035),bronze)
	var cook_label=Label3D.new();cook_label.name="CookingCanopyLabel";cook_label.text="COOK";cook_label.position=Vector3(0,2.31,.452);cook_label.font_size=40;cook_label.pixel_size=.0022;cook_label.modulate=Color("f5e8c8");cook_label.outline_size=2;add_child(cook_label)
	# Small shelf is below the cooktop and inside the same cylinder footprint.
	part(BoxMesh.new(),Vector3(0,.43,-.25),Vector3(.48,.035,.20),wood)
	tray_visual=Node3D.new();tray_visual.position=Vector3(0,.78,0);add_child(tray_visual)
func refresh_samples():
	for child in tray_visual.get_children():tray_visual.remove_child(child);child.queue_free()
	if session.disposed:return
	var index=0
	for output in ["test_glade_fillet","test_ember_leaf"]:
		for _sample in range(int(session.tray[output])):
			var plate=Node3D.new();tray_visual.add_child(plate);plate.position=Vector3((index%2-.5)*.34,0,((index>>1)-.5)*.30)
			if output=="test_glade_fillet":
				part(SphereMesh.new(),Vector3.ZERO,Vector3(.27,.045,.14),Color("c88954"),plate)
				for stripe in [-1,0,1]:part(BoxMesh.new(),Vector3(stripe*.055,.025,0),Vector3(.015,.009,.10),Color("754a31"),plate)
			else:
				for leaf in [-1,0,1]:
					var blade=part(SphereMesh.new(),Vector3(leaf*.06,.012,0),Vector3(.09,.025,.22),Color("a5a052"),plate);blade.rotation.y=leaf*.35
				part(BoxMesh.new(),Vector3(0,.028,0),Vector3(.008,.008,.23),Color("6e602e"),plate)
			index+=1
func can_open(who:Node3D) -> bool:
	if session.disposed or blocked_by_other_modal or not is_instance_valid(who) or not is_inside_tree():return false
	if host_bound and not host_access.is_valid():return false
	if host_access.is_valid() and not host_access.call():return false
	if not who.is_inside_tree() or who.is_queued_for_deletion():return false
	if who.global_position.distance_to(global_position)>1.8:return false
	var from=who.global_position+Vector3(0,1.2,0);var target=global_position+Vector3(0,.75,0)
	var query=PhysicsRayQueryParameters3D.create(from,target)
	var excluded:Array[RID]=[]
	if who is CollisionObject3D:excluded.append(who.get_rid())
	if is_instance_valid(own_collider):excluded.append(own_collider.get_rid())
	query.exclude=excluded
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func try_open(who:Node3D) -> bool:
	if panel.visible or not can_open(who):return false
	actor=who;panel.open(session);opened.emit();return true
func close_panel():
	if not is_instance_valid(panel) or not panel.visible:return
	if not session.disposed:session.cancel(session.revision)
	panel.hide();actor=null;closed.emit()
func _process(_delta:float):
	if is_instance_valid(panel) and panel.visible and not can_open(actor):close_panel()
func _unhandled_input(event:InputEvent):
	if is_instance_valid(panel) and panel.visible and event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_ESCAPE or event.keycode==KEY_ESCAPE):
		close_panel();get_viewport().set_input_as_handled()
func _exit_tree():
	# Retained references cannot mutate this ended world session.
	session.dispose();actor=null
