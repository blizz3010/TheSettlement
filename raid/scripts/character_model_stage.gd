extends "res://scripts/character_profiles/selection_stage.gd"
## Item 15b fix: the select-screen preview shows the REAL character model.
##
## Root cause of the broken model: the pinned stage inherits the inventory's
## provisional procedural box mannequin (clothing_preview.gd, ~2.0 m tall) and
## grafts a slice of the creator rig's head onto it (inventory_character_head.gd:
## raw vertices above y=1.30 of the 1.55 m skinned Appearance-Proof rig, rescaled
## by a hand-tuned FIT x1.2 +0.12 m). Two bodies with different proportions and
## origins meet at a cylinder neck: the head sits ~6 cm in front of the neck, the
## cut ring floats on the neck stub, and the box body is tinted with the rig's
## technical-neutral albedo so it reads as flat white blocks.
##
## This stage instead instances the whole Appearance-Proof rig (skeleton + skin
## intact, rest pose, meter scale, unscaled) and applies the saved appearance the
## same way the creator preview does. Equipped garments keep the shipped
## procedural design and per-slot fabric materials but are rebuilt along the
## rig's own bone landmarks, so they sit on this body instead of the mannequin.
## Pinned files are untouched; this is opt-in via the select-panel adapter.
const SOURCE="res://models/Appearance-Proof.glb"
const AppearanceDraft=preload("res://scripts/character_preview/creator_draft.gd")
const HAIR_NAMES=["hair_short02_v1","hair_bob01_v1"]
const BROW_NAMES=["brow_009_v1","brow_001_v1"]
const EYE_NAMES=["eye_brown_v1","eye_blue_v1"]
const FRAME_DISTANCE=3.8
var rig:Node3D
var skeleton:Skeleton3D
var rig_meshes:Dictionary={}
var landmarks:Dictionary={}
var model_bounds:=AABB()
var model_ok:=false

func _ready():
	super._ready()
	# Retire the provisional mannequin body; keep the garment holders.
	for node in stage.get_children():
		if node is MeshInstance3D:node.hide()
	_load_rig()
	if model_ok:
		_rebuild_garments()
		_add_fill_light()
	set_angle(angle)

func _load_rig():
	var packed=load(SOURCE) as PackedScene
	if packed==null:return
	var raw=packed.instantiate()
	if not raw is Node3D:
		if raw!=null:raw.free()
		return
	rig=raw;rig.name="SelectedCharacterModel";stage.add_child(rig)
	skeleton=rig.find_child("Skeleton3D",true,false) as Skeleton3D
	for mesh in rig.find_children("*","MeshInstance3D",true,false):rig_meshes[str(mesh.name)]=mesh
	for name in ["ProofBody"]+HAIR_NAMES+BROW_NAMES+EYE_NAMES:
		if not rig_meshes.has(name):return
	if skeleton==null or rig_meshes.ProofBody.find_blend_shape_by_name("probe_cheek_volume_v1")<0:return
	for bone in ["pelvis","spine_03","neck_01","head","upperarm_l","lowerarm_l","hand_l","upperarm_r","lowerarm_r","hand_r","thigh_l","calf_l","foot_l","ball_l","thigh_r","calf_r","foot_r","ball_r"]:
		var index=skeleton.find_bone(bone)
		if index<0:return
		landmarks[bone]=skeleton.get_bone_global_rest(index).origin
	var body:MeshInstance3D=rig_meshes.ProofBody
	model_bounds=body.get_aabb()
	model_ok=true

func _add_fill_light():
	var fill=DirectionalLight3D.new();fill.name="SelectFill"
	fill.rotation_degrees=Vector3(-5,150,0);fill.light_color=Color("9fb9c5");fill.light_energy=.35
	stage.add_child(fill)

func _clear(holder:Node3D):
	for child in holder.get_children():holder.remove_child(child);child.queue_free()

func _rebuild_garments():
	var L=landmarks
	var dark=make_material(Color("252a28"));var metal=make_material(Color("7c796b"));metal.metallic=.65
	var hip_y=L.pelvis.y;var shoulder_y=L.upperarm_l.y;var neck_y=L.neck_01.y
	var torso_top=lerpf(shoulder_y,neck_y,.45)
	var torso_bottom=hip_y-.03
	var torso_mid=(torso_top+torso_bottom)*.5
	var torso_w=absf(L.upperarm_l.x)*2.0+.04
	var torso_d=.24
	var torso_z=.03
	# Jacket: body, zipper, collar, chest pockets, two-segment sleeves following the arm bones.
	var jacket:Node3D=garments.jacket;_clear(jacket)
	part(jacket,"Fabric jacket body",Vector3(0,torso_mid,torso_z),Vector3(torso_w,torso_top-torso_bottom,torso_d),fabrics.jacket)
	part(jacket,"Fixed zipper",Vector3(0,torso_mid,torso_z+torso_d*.5+.004),Vector3(.010,(torso_top-torso_bottom)*.9,.010),metal)
	for side in ["l","r"]:
		var s=1.0 if side=="l" else -1.0
		var shoulder:Vector3=L["upperarm_"+side];var elbow:Vector3=L["lowerarm_"+side];var wrist:Vector3=L["hand_"+side]
		limb(jacket,"Fabric sleeve",shoulder+Vector3(-s*.01,.02,0),elbow,.058,fabrics.jacket)
		limb(jacket,"Fabric sleeve lower",elbow,wrist.lerp(elbow,.12),.050,fabrics.jacket)
		var collar=part(jacket,"Fabric pointed collar",Vector3(s*.05,torso_top-.005,torso_z+.075),Vector3(.09,.08,.03),fabrics.jacket);collar.rotation.z=s*.35
		part(jacket,"Fabric chest patch pocket",Vector3(s*.075,torso_top-.11,torso_z+torso_d*.5+.006),Vector3(.09,.10,.012),fabrics.jacket)
		part(jacket,"Fixed pocket snap",Vector3(s*.075,torso_top-.07,torso_z+torso_d*.5+.014),Vector3(.011,.011,.007),metal)
	# Pants: waistband, buckle, two-segment legs following hip -> knee -> ankle, cargo pockets.
	var pants:Node3D=garments.pants;_clear(pants)
	part(pants,"Fabric waistband",Vector3(0,hip_y+.02,torso_z),Vector3(torso_w-.03,.09,torso_d-.02),fabrics.pants)
	part(pants,"Fixed belt buckle",Vector3(0,hip_y+.035,torso_z+(torso_d-.02)*.5+.004),Vector3(.03,.024,.010),metal)
	var boots:Node3D=garments.boots;_clear(boots)
	var gloves:Node3D=garments.gloves;_clear(gloves)
	for side in ["l","r"]:
		var s=1.0 if side=="l" else -1.0
		var hip:Vector3=L["thigh_"+side];var knee:Vector3=L["calf_"+side];var ankle:Vector3=L["foot_"+side];var ball:Vector3=L["ball_"+side]
		limb(pants,"Fabric trouser leg",hip+Vector3(0,.04,0),knee,.088,fabrics.pants)
		limb(pants,"Fabric trouser leg lower",knee,ankle+Vector3(0,.06,0),.072,fabrics.pants)
		var thigh_mid=hip.lerp(knee,.45)
		part(pants,"Fabric cargo pocket",thigh_mid+Vector3(s*.085,0,.01),Vector3(.02,.13,.11),fabrics.pants)
		# Boots: shaft round the ankle, toe box along foot -> ball, sole.
		var forward=Vector3(ball.x-ankle.x,0,ball.z-ankle.z)
		var yaw=atan2(forward.x,forward.z)
		var toe_centre=Vector3((ankle.x+ball.x)*.5,.055,(ankle.z+ball.z)*.5+.01)
		part(boots,"Fixed dark boot shaft",Vector3(ankle.x,ankle.y+.06,ankle.z),Vector3(.13,.17,.14),dark)
		var toe=part(boots,"Fixed dark boot toe",toe_centre,Vector3(.12,.11,forward.length()+.11),dark);toe.rotation.y=yaw
		var sole=part(boots,"Fixed sole",Vector3(toe_centre.x,.012,toe_centre.z),Vector3(.13,.024,forward.length()+.13),dark);sole.rotation.y=yaw
		# Gloves: oriented along the forearm at the wrist.
		var wrist:Vector3=L["hand_"+side];var elbow:Vector3=L["lowerarm_"+side]
		var dir=(wrist-elbow).normalized()
		var glove=Node3D.new();glove.name="Glove "+side;gloves.add_child(glove)
		var x=Vector3.UP.cross(dir).normalized()
		if x.length_squared()<.1:x=Vector3.RIGHT
		glove.basis=Basis(x,dir,x.cross(dir).normalized());glove.position=wrist+dir*.05
		part(glove,"Fabric glove palm",Vector3.ZERO,Vector3(.085,.10,.04),fabrics.gloves)
		part(glove,"Fixed dark glove grip",Vector3(0,0,.022),Vector3(.06,.07,.008),dark)
		for finger in range(4):part(glove,"Fabric glove finger",Vector3((finger-1.5)*.019,.075,0),Vector3(.016,.055,.03),fabrics.gloves)
		part(glove,"Fabric glove thumb",Vector3(-s*.05,.01,.012),Vector3(.03,.055,.03),fabrics.gloves)
	# Helmet: refit the shipped visor-helmet asset to this head (head bone + hair envelope).
	var helmet_holder:Node3D=garments.helmet
	var head_bounds:AABB=rig_meshes.hair_short02_v1.get_aabb().merge(_head_box())
	for helmet in helmet_holder.get_children():
		var bounds=AABB();var first=true
		helmet.scale=Vector3.ONE;helmet.position=Vector3.ZERO
		for node in helmet.find_children("*","MeshInstance3D",true,false):
			var box=_relative(node,helmet)*node.get_aabb()
			bounds=box if first else bounds.merge(box);first=false
		if first or bounds.size.x<=0:continue
		var factor=(head_bounds.size.x+.05)/bounds.size.x
		helmet.scale=Vector3.ONE*factor
		var target=Vector3(0,head_bounds.end.y-head_bounds.size.y*.30,head_bounds.get_center().z)
		helmet.position=target-(bounds.position+bounds.size*.5)*factor

func _relative(node:Node3D,root:Node3D)->Transform3D:
	var t=node.transform;var parent=node.get_parent()
	while parent!=root and parent is Node3D:t=parent.transform*t;parent=parent.get_parent()
	return t

func _head_box()->AABB:
	var head:Vector3=landmarks.head
	return AABB(head+Vector3(-.085,-.10,-.09),Vector3(.17,.25,.24))

func set_angle(degrees:float):
	angle=clampf(degrees,-90,90)
	if not is_instance_valid(camera):return
	if not model_ok:
		super.set_angle(degrees);return
	var height=model_bounds.end.y
	var centre_y=height*.5
	var a=deg_to_rad(angle)
	camera.position=Vector3(sin(a)*FRAME_DISTANCE,centre_y+.22,cos(a)*FRAME_DISTANCE)
	camera.look_at(Vector3(0,centre_y,0))
	camera.size=height*1.18
	redraw_preview()

func show_appearance(value:Dictionary)->bool:
	if not model_ok:return super.show_appearance(value)
	if value.is_empty():
		value=AppearanceDraft.new().committed.duplicate(true)
	var validator=AppearanceDraft.new()
	if not validator.valid(value) or value.name!=value.name.strip_edges():
		appearance_result={"ok":false,"reason":"Invalid selected appearance"};return false
	var body:MeshInstance3D=rig_meshes.ProofBody
	body.set_blend_shape_value(body.find_blend_shape_by_name("probe_cheek_volume_v1"),float(value.cheek))
	for name in HAIR_NAMES:
		var mesh:MeshInstance3D=rig_meshes[name]
		mesh.visible=name==value.hair
		for surface in mesh.mesh.get_surface_count():
			var key="original_hair_material_%d"%surface
			if not mesh.has_meta(key):mesh.set_meta(key,mesh.get_active_material(surface))
			var original=mesh.get_meta(key) as StandardMaterial3D
			if original!=null:mesh.set_surface_override_material(surface,AppearanceDraft.tinted_material(original,value))
	for name in BROW_NAMES:rig_meshes[name].visible=name==value.brows
	for name in EYE_NAMES:rig_meshes[name].visible=name==value.eyes
	selected_appearance=value.duplicate(true)
	appearance_result={"ok":true,"scope":"Full Appearance-Proof rig (skinned, rest pose) with refit procedural garments"}
	redraw_preview()
	return true
