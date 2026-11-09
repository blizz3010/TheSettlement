extends SubViewportContainer
# Original procedural garment geometry on a neutral static mannequin.
# Provisional fit visualization only: no character skeleton/skin/animation claim.
var fabrics:Dictionary={}
var garments:Dictionary={}
var stage:Node3D
var neutral_head:MeshInstance3D
var neutral_material:StandardMaterial3D
var selected_head:Node3D
var selected_appearance:Dictionary={}
var appearance_result:Dictionary={}
func make_material(color:Color)->StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.9;return m
func part(parent:Node3D,title:String,p:Vector3,size:Vector3,mat:Material)->MeshInstance3D:
	var node=MeshInstance3D.new();node.name=title;var mesh=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.position=p;node.material_override=mat;parent.add_child(node);return node
func limb(parent:Node3D,title:String,a:Vector3,b:Vector3,radius:float,mat:Material)->MeshInstance3D:
	var node=MeshInstance3D.new();node.name=title
	var mesh=CylinderMesh.new();mesh.top_radius=radius*.85;mesh.bottom_radius=radius;mesh.height=a.distance_to(b);mesh.radial_segments=12
	node.mesh=mesh;node.position=(a+b)/2;node.material_override=mat;parent.add_child(node)
	var direction=(b-a).normalized();var x=Vector3.UP.cross(direction).normalized()
	if x.length_squared()<.1:x=Vector3.RIGHT
	node.basis=Basis(x,direction,x.cross(direction).normalized())
	return node
func _ready():
	custom_minimum_size=Vector2(270,320);size_flags_vertical=Control.SIZE_SHRINK_CENTER;stretch=true
	var viewport=SubViewport.new();viewport.size=Vector2i(540,640);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.own_world_3d=true;add_child(viewport)
	stage=Node3D.new();stage.name="NeutralMannequinClothingDraft";viewport.add_child(stage)
	var world=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("182321");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("d9e4df");env.ambient_light_energy=.65;world.environment=env;stage.add_child(world)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-25,0);light.light_energy=1.8;stage.add_child(light)
	var camera=Camera3D.new();camera.position=Vector3(2.0,1.7,3.4);stage.add_child(camera);camera.look_at(Vector3(0,.95,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.35;camera.current=true
	var neutral=make_material(Color("7b817e"));neutral_material=neutral;var dark=make_material(Color("252a28"));var metal=make_material(Color("7c796b"));metal.metallic=.65
	var torso=part(stage,"Neutral torso",Vector3(0,1.3,0),Vector3(.39,.52,.20),neutral)
	var head=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=.105;sphere.height=.27;head.mesh=sphere;head.position=Vector3(0,1.8,0);head.material_override=neutral;stage.add_child(head);neutral_head=head
	limb(stage,"Neck",Vector3(0,1.55,0),Vector3(0,1.69,0),.065,neutral)
	for side in [-1,1]:
		limb(stage,"Neutral arm",Vector3(side*.23,1.5,0),Vector3(side*.46,.93,0),.065,neutral)
		limb(stage,"Neutral leg",Vector3(side*.105,.97,0),Vector3(side*.12,.16,0),.075,neutral)
	for slot in ["jacket","pants","gloves","boots","helmet"]:
		var holder=Node3D.new();holder.name=slot.capitalize()+"Garment";stage.add_child(holder);garments[slot]=holder
		fabrics[slot]=make_material(Color(.29,.31,.23))
	var jacket=garments.jacket
	part(jacket,"Fabric jacket body",Vector3(0,1.3,0),Vector3(.46,.55,.27),fabrics.jacket)
	part(jacket,"Fixed zipper",Vector3(0,1.30,.142),Vector3(.012,.49,.012),metal)
	for side in [-1,1]:
		limb(jacket,"Fabric sleeve",Vector3(side*.23,1.5,0),Vector3(side*.44,1.0,0),.085,fabrics.jacket)
		limb(jacket,"Fabric cuff",Vector3(side*.44,1.02,0),Vector3(side*.46,.97,0),.084,fabrics.jacket)
		var collar=part(jacket,"Fabric pointed collar",Vector3(side*.065,1.56,.10),Vector3(.12,.10,.04),fabrics.jacket);collar.rotation.z=side*.35
		part(jacket,"Fabric chest patch pocket",Vector3(side*.12,1.38,.147),Vector3(.13,.14,.018),fabrics.jacket)
		part(jacket,"Fixed pocket snap",Vector3(side*.12,1.43,.16),Vector3(.013,.013,.009),metal)
	var pants=garments.pants
	part(pants,"Fabric waistband",Vector3(0,.98,0),Vector3(.40,.14,.25),fabrics.pants)
	part(pants,"Fixed belt buckle",Vector3(0,1.02,.133),Vector3(.035,.028,.012),metal)
	for side in [-1,1]:
		limb(pants,"Fabric trouser leg",Vector3(side*.105,.96,0),Vector3(side*.12,.17,0),.105,fabrics.pants)
		part(pants,"Fabric cargo pocket",Vector3(side*.205,.70,.015),Vector3(.025,.18,.15),fabrics.pants)
		part(garments.boots,"Fixed dark boot shaft",Vector3(side*.12,.20,0),Vector3(.16,.22,.17),dark)
		part(garments.boots,"Fixed dark boot toe",Vector3(side*.12,.075,.07),Vector3(.18,.14,.29),dark)
		part(garments.boots,"Fixed sole",Vector3(side*.12,.018,.07),Vector3(.19,.036,.30),dark)
		var glove=garments.gloves
		part(glove,"Fabric glove palm",Vector3(side*.48,.91,.0),Vector3(.09,.12,.06),fabrics.gloves)
		part(glove,"Fixed dark glove grip",Vector3(side*.48,.91,.034),Vector3(.065,.08,.012),dark)
		for finger in range(4):
			part(glove,"Fabric glove finger",Vector3(side*.48+(finger-1.5)*.021,.83,0),Vector3(.018,.065,.04),fabrics.gloves)
		part(glove,"Fabric glove thumb",Vector3(side*.54,.90,.01),Vector3(.035,.07,.04),fabrics.gloves)
	# Reuse the counter display asset, normalized for this static inventory preview.
	var helmet=load("res://assets/market_detail/psy_visor_helmet.glb").instantiate()
	garments.helmet.add_child(helmet)
	var bounds=AABB();var first=true
	for node in helmet.find_children("*","MeshInstance3D",true,false):
		var box=helmet.global_transform.affine_inverse()*node.global_transform*node.get_aabb()
		bounds=box if first else bounds.merge(box);first=false
	if not first and bounds.size.x>0:
		var factor=.31/bounds.size.x
		helmet.scale=Vector3.ONE*factor
		helmet.position=Vector3(0,1.86,0)-(bounds.position+bounds.size*.5)*factor
	garments.helmet.hide()
	torso.visible=true
func show_draft(inventory,instance_id:String,draft:Color):
	if fabrics.is_empty():return
	for slot in garments:garments[slot].visible=false
	var chosen={}
	for id in inventory.equipment_owned:
		var entry=inventory.equipment_owned[id];var definition=inventory.equipment_definitions()[entry.definition_id]
		var slot:String=definition.category
		if not garments.has(slot) or not entry.location in ["carried","equipped"]:continue
		if not chosen.has(slot) or id==instance_id or (chosen[slot]!=instance_id and entry.location=="equipped"):chosen[slot]=id
	for slot in chosen:
		var id:String=chosen[slot];var entry=inventory.equipment_owned[id]
		garments[slot].visible=true
		var rgba=entry.dyes.get("fabric",inventory.DEFAULT_FABRICS.get(slot,[.09,.10,.09,1.0]))
		fabrics[slot].albedo_color=Color(rgba[0],rgba[1],rgba[2],rgba[3])
		if id==instance_id and slot in ["jacket","pants","gloves"]:fabrics[slot].albedo_color=draft

# Inventory view shows ONLY actually equipped garments, never owned/carried drafts.
func show_equipped(context:Dictionary):
	if fabrics.is_empty():return
	for slot in garments:
		garments[slot].visible=false
		var id:String=context.get("slots",{}).get(slot,"")
		if id.is_empty() or not context.get("owned",{}).has(id):continue
		var entry:Dictionary=context.owned[id]
		var definition:Dictionary=context.definitions[entry.definition_id]
		if entry.location!="equipped" or definition.category!=slot:continue
		garments[slot].visible=true
		var rgba=entry.dyes.get("fabric",preload("res://scripts/inventory_state.gd").DEFAULT_FABRICS.get(slot,[.09,.10,.09,1.0]))
		fabrics[slot].albedo_color=Color(rgba[0],rgba[1],rgba[2],rgba[3])

func show_appearance(value:Dictionary)->bool:
	if value==selected_appearance and (value.is_empty() or is_instance_valid(selected_head)):return true
	if value.is_empty():
		if is_instance_valid(selected_head):selected_head.free()
		selected_head=null;selected_appearance={};neutral_head.show();neutral_material.albedo_color=Color("7b817e");appearance_result={"ok":true,"legacy_neutral":true};return true
	var built=preload("res://scripts/inventory_character_head.gd").prepare(value)
	appearance_result=built.duplicate();appearance_result.erase("root")
	if not built.get("ok",false):
		if is_instance_valid(selected_head):selected_head.free()
		selected_head=null;selected_appearance={};neutral_head.show();neutral_material.albedo_color=Color("7b817e")
		return false
	if is_instance_valid(selected_head):selected_head.free()
	selected_head=built.root;stage.add_child(selected_head);neutral_head.hide();neutral_material.albedo_color=built.skin;selected_appearance=value.duplicate(true)
	return true
