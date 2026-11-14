extends "res://raid/scripts/character_model_stage.gd"
## Item 15 MOCKUP stage: the real character rig on a lit plinth at dusk.
## - Relaxed contrapposto idle pose set on the skeleton (skinning untouched:
##   only bone poses change, rest/bind stay as authored).
## - Garments are rebuilt from the POSED bone landmarks so they follow the pose.
## - The character turns on the plinth; the camera and set stay still.
const KIT="res://assets/kit/"
var pose_applied:=false
var camera_target:=Vector3(0,.88,0)
var screen_offset:=0.0 ## camera h_offset; positive puts the figure left of centre
var turntable:Array=[]

func _load_rig():
	super._load_rig()
	if not model_ok:return
	_apply_relaxed_pose()
	for bone in landmarks.keys():
		landmarks[bone]=skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin

func _aim(bone:String,child:String,target:Vector3):
	var b=skeleton.find_bone(bone);var c=skeleton.find_bone(child)
	var g:Transform3D=skeleton.get_bone_global_pose(b)
	var d:Vector3=skeleton.get_bone_global_pose(c).origin-g.origin
	if d.length()<.001:return
	var q=Quaternion(d.normalized(),target.normalized())
	skeleton.set_bone_global_pose(b,Transform3D(Basis(q)*g.basis,g.origin))

func _turn(bone:String,axis:Vector3,degrees:float):
	var b=skeleton.find_bone(bone)
	var g:Transform3D=skeleton.get_bone_global_pose(b)
	skeleton.set_bone_global_pose(b,Transform3D(Basis(axis.normalized(),deg_to_rad(degrees))*g.basis,g.origin))

func _apply_relaxed_pose():
	# Weight on the right leg: hips tilt, shoulders counter-tilt, left knee eases.
	_turn("pelvis",Vector3.FORWARD,-2.5)
	_turn("spine_02",Vector3.FORWARD,2.0)
	_turn("spine_03",Vector3.FORWARD,1.5)
	_turn("spine_03",Vector3.UP,-6.0)
	_turn("neck_01",Vector3.FORWARD,-1.5)
	_turn("head",Vector3.UP,8.0)
	_turn("head",Vector3.RIGHT,4.0)
	# Arms down from the A-pose, elbows softly bent.
	_aim("upperarm_l","lowerarm_l",Vector3(.16,-1,-.02))
	_aim("lowerarm_l","hand_l",Vector3(.10,-1,.22))
	_aim("upperarm_r","lowerarm_r",Vector3(-.14,-1,.02))
	_aim("lowerarm_r","hand_r",Vector3(-.06,-1,.30))
	# Legs: right leg plumb under the hip, left knee relaxed and foot slightly out.
	var rh:Vector3=skeleton.get_bone_global_pose(skeleton.find_bone("thigh_r")).origin
	_aim("thigh_r","calf_r",Vector3(-.02,-1,0))
	_aim("calf_r","foot_r",Vector3(-.01,-1,-.03))
	_aim("thigh_l","calf_l",Vector3(.10,-1,.10))
	_aim("calf_l","foot_l",Vector3(.06,-1,-.10))
	# Re-seat on the plinth: lowest foot joint back to its rest height.
	var rest_foot=skeleton.get_bone_global_rest(skeleton.find_bone("foot_r")).origin.y
	var low=minf(skeleton.get_bone_global_pose(skeleton.find_bone("foot_r")).origin.y,skeleton.get_bone_global_pose(skeleton.find_bone("foot_l")).origin.y)
	rig.position.y+=rest_foot-low
	pose_applied=true

func _ready():
	super._ready()
	if not model_ok:return
	_refit_for_pose()
	render_view.transparent_bg=false
	render_view.msaa_3d=Viewport.MSAA_4X
	_build_set()
	turntable=[rig]
	for slot in garments:turntable.append(garments[slot])
	if rig.position.y!=0.0:
		for slot in garments:garments[slot].position.y=rig.position.y
	set_angle(-18)

func _refit_for_pose():
	# Arms hang beside the torso in this pose, so the torso pieces must sit inside
	# them; the helmet follows the posed head (it was fitted at the rest head).
	for slot in ["jacket","pants"]:
		for n in garments[slot].get_children():
			if str(n.name).begins_with("Fabric jacket body") or str(n.name).begins_with("Fabric waistband") or str(n.name).begins_with("Fabric seat"):
				n.scale.x=.80
			elif str(n.name).begins_with("Fabric chest patch") or str(n.name).begins_with("Fabric pointed collar") or str(n.name).begins_with("Fabric cargo"):
				n.position.x*=.82
	# Gloves: refit to the posed hand itself (CPU-skinned hand + finger vertices).
	var hands=_skinned_hand_bounds()
	if hands.size()==2:
		for c in garments.gloves.get_children():garments.gloves.remove_child(c);c.queue_free()
		var dark=make_material(Color("252a28"))
		for side in hands:
			var box:AABB=hands[side]
			var g=Node3D.new();g.name="Glove "+side;g.position.y=rig.position.y;garments.gloves.add_child(g)
			part(g,"Fabric glove mitt",box.get_center(),box.size+Vector3(.022,.02,.022),fabrics.gloves)
			part(g,"Fabric glove cuff",Vector3(box.get_center().x,box.end.y+.012,box.get_center().z),Vector3(box.size.x+.04,.05,box.size.z+.04),fabrics.gloves)
			var s=1.0 if side=="l" else -1.0
			part(g,"Fixed dark glove grip",box.get_center()+Vector3(-s*(box.size.x*.5+.012),0,0),Vector3(.006,box.size.y*.6,box.size.z*.7),dark)
	var rest_head=skeleton.get_bone_global_rest(skeleton.find_bone("head")).origin
	for h in garments.helmet.get_children():h.position+=landmarks.head-rest_head

func _skinned_hand_bounds()->Dictionary:
	var body:MeshInstance3D=rig_meshes.ProofBody
	var arrays=body.mesh.surface_get_arrays(0)
	var v:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones=arrays[Mesh.ARRAY_BONES];var w=arrays[Mesh.ARRAY_WEIGHTS]
	if bones==null or w==null or v.is_empty():return {}
	var per=bones.size()/v.size();var skin:Skin=body.skin
	var mats=[];var side_of=[]
	for i in skin.get_bind_count():
		var bi=skin.get_bind_bone(i)
		if bi<0:bi=skeleton.find_bone(skin.get_bind_name(i))
		mats.append(skeleton.get_bone_global_pose(bi)*skin.get_bind_pose(i))
		var n=skeleton.get_bone_name(bi)
		side_of.append(n.right(1) if (n.begins_with("hand_") or n.begins_with("index") or n.begins_with("middle") or n.begins_with("ring") or n.begins_with("pinky") or n.begins_with("thumb")) else "")
	var out={}
	for i in v.size():
		var best=0;var bw=-1.0
		for k in per:
			if w[i*per+k]>bw:bw=w[i*per+k];best=bones[i*per+k]
		var side:String=side_of[best]
		if side.is_empty():continue
		var p=Vector3.ZERO
		for k in per:
			var ww=w[i*per+k]
			if ww>0:p+=mats[bones[i*per+k]]*v[i]*ww
		out[side]=AABB(p,Vector3.ZERO) if not out.has(side) else out[side].expand(p)
	return out

func _mat(c:Color,rough:=.85)->StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_color=c;m.roughness=rough;return m

func _place(path:String,pos:Vector3,yaw:=0.0,s:=1.0)->Node3D:
	var packed=load(KIT+path) as PackedScene
	if packed==null:return null
	var n=packed.instantiate() as Node3D;stage.add_child(n)
	n.position=pos;n.rotation.y=deg_to_rad(yaw);n.scale=Vector3.ONE*s
	return n

func _build_set():
	for node in stage.get_children():
		if node is WorldEnvironment:
			var e:Environment=node.environment
			var sky=Sky.new();var sm=ProceduralSkyMaterial.new()
			sm.sky_top_color=Color("0b1517");sm.sky_horizon_color=Color("34413c");sm.ground_horizon_color=Color("34413c");sm.ground_bottom_color=Color("151b19")
			sm.sky_curve=.12;sm.sun_angle_max=0.0
			sky.sky_material=sm;e.sky=sky;e.background_mode=Environment.BG_SKY
			e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("8fa7a0");e.ambient_light_energy=.40
			e.tonemap_mode=Environment.TONE_MAPPER_FILMIC;e.tonemap_exposure=.92
			e.fog_enabled=true;e.fog_light_color=Color("34413c");e.fog_density=.06;e.fog_sky_affect=.0
		if node is DirectionalLight3D and node.name!="SelectFill":
			# Warm key, low and to camera-left, soft shadows.
			node.light_color=Color("ffd9a8");node.light_energy=1.05;node.rotation_degrees=Vector3(-34,-38,0)
			node.shadow_enabled=true;node.shadow_blur=2.0
		if node is DirectionalLight3D and node.name=="SelectFill":
			node.light_color=Color("7fd3c8");node.light_energy=.9;node.rotation_degrees=Vector3(-12,160,0) # teal rim from behind
	# Ground + plinth.
	var ground=MeshInstance3D.new();var gm=PlaneMesh.new();gm.size=Vector2(160,160);ground.mesh=gm
	ground.material_override=_mat(Color("141a18"),1.0);stage.add_child(ground)
	var plinth=MeshInstance3D.new();var pm=CylinderMesh.new();pm.top_radius=.62;pm.bottom_radius=.68;pm.height=.10;pm.radial_segments=48
	plinth.mesh=pm;plinth.position.y=-.05+.0;plinth.material_override=_mat(Color("3e3d36"),.95);stage.add_child(plinth)
	var rim=MeshInstance3D.new();var tm=TorusMesh.new();tm.inner_radius=.615;tm.outer_radius=.64;tm.rings=64;rim.mesh=tm
	var rimmat=_mat(Color("c6a975"),.35);rimmat.metallic=.8;rimmat.emission_enabled=true;rimmat.emission=Color("c6a975");rimmat.emission_energy_multiplier=.5
	rim.material_override=rimmat;rim.position.y=.0;stage.add_child(rim)
	# Raise everything by the plinth top so the figure stands on it.
	for n in [plinth,rim]:n.position.y+=0.0
	# Set dressing from the shipped kit, pushed back into the fog.
	var l1=_place("lantern.glb",Vector3(-1.9,0,-2.6),20,.8)
	var l2=_place("lantern.glb",Vector3(2.1,0,-3.2),-30,.8)
	for l in [l1,l2]:
		if l==null:continue
		var o=OmniLight3D.new();o.light_color=Color("ffb866");o.light_energy=.9;o.omni_range=2.6;o.position=l.position+Vector3(0,.6,0);stage.add_child(o)
	_place("border_tree_a.glb",Vector3(-4.6,0,-6.5),0,1.0)
	_place("border_tree_b.glb",Vector3(3.8,0,-7.5),40,1.1)
	_place("border_tree_a.glb",Vector3(-1.2,0,-14.0),80,1.2)
	_place("reference_low_shrub_a.glb",Vector3(-1.3,0,-1.9),0,.45)
	_place("reference_low_shrub_b.glb",Vector3(1.5,0,-2.3),60,.45)
	_place("plaza_bench.glb",Vector3(-3.4,0,-4.6),35,.9)

func set_angle(degrees:float):
	angle=clampf(degrees,-180,180)
	if not is_instance_valid(camera):return
	if not model_ok:
		super.set_angle(degrees);return
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=24
	camera.position=Vector3(0,1.15,6.0);camera.look_at(camera_target);camera.h_offset=screen_offset
	for n in turntable:n.rotation.y=deg_to_rad(angle)
	redraw_preview()
