extends Node3D
signal return_requested
const Config=preload("res://raid/scripts/relay_config.gd")
const Generator=preload("res://raid/scripts/relay_generator.gd")
const State=preload("res://raid/scripts/raid_state.gd")
const Props=preload("res://raid/scripts/raid_props.gd")
const Cargo=preload("res://raid/scripts/cargo_scenery.gd")
const FieldSupplies=preload("res://raid/scripts/field_supplies.gd")
const PuzzleControls=preload("res://raid/scripts/puzzle_controls.gd")
@export var settings:Resource
var generator
var raid_state
var player:CharacterBody3D
var ready_for_play:=false
var preparation_physics_ticks:=0
var build_result:Dictionary={}
var targets:Array=[]
var door_nodes:Dictionary={}
var status:Label
var navigation:Label
var hint:Label
var toast:Label
var modal:PanelContainer
var modal_content:VBoxContainer
var modal_generation:=0
var map_panel:Control
var note_time:=0.0
var active_target:Dictionary={}
var extraction_target:Dictionary={}
var extraction_status:Label
var extraction_progress:ProgressBar
var returning:=false
var generation_failure:=""
var raid_audio
var extraction_pulse_second:=0
const EXTRACTION_RADIUS:=4.0
func is_raid_ready()->bool:return ready_for_play
func get_raid_failure()->String:return generation_failure
# Overridable map adapters keep the first map as the default. Lifecycle, input,
# extraction, readiness and settlement boundaries are shared by every biome.
func _default_settings()->Resource:return Config.new()
func _create_generator(config:Resource):return Generator.new(config)
func _create_state(seed_number:int):return State.new(seed_number)
func _build_foliage(parent:Node3D)->Dictionary:return preload("res://raid/scripts/relay_foliage.gd").new().build(parent,generator)
func _map_name()->String:return "Relay Ridge"
func _saltflat_props()->bool:return false
func _wild_region()->String:return "Woodland approaches"
func _region_detail(_poi:Dictionary)->String:return ""
func _extract_names()->Array:return ["North Gully Extract","East Service Extract"]
func _pause_description()->String:return "Explore six POIs, two high-quality loot sites, key / keycard / code doors and a relay-sequence archive. Terrain and foliage use a repeatable seed."
func _locked_hint(poi:Dictionary)->String:return {"key":"the maintenance key","keycard":"the research keycard","puzzle":"the weather log and solve the nearby relay sequence"}[poi.lock]
func _switch_feedback(solved:bool)->String:return "Hidden archive released. The station door can now open." if solved else "Relay sequence: %d / 3"%raid_state.switch_step
func _switch_prompt(number:int)->String:return "Activate relay switch %s"%number
func _switch_sound(target:Dictionary):_sound("relay_switch_click",target.node.global_position)
func _ready():
	# Observe this tick's production player motion before deciding extraction.
	# Otherwise a final-tick jump/zone exit can lose to the results modal.
	process_physics_priority=1
	if settings==null:settings=_default_settings()
	if not settings.valid():_fail_generation("Invalid raid settings. Restore the default settings and try again.");return
	generator=_create_generator(settings);raid_state=_create_state(settings.map_seed)
	build_result["travel_layout"]=generator.validate_travel_layout()
	if not build_result.travel_layout.ok:_fail_generation(build_result.travel_layout.reason);return
	_setup_environment()
	build_result["terrain"]=generator.build_terrain(self)
	var foliage=Node3D.new();foliage.name="SeededFoliage";add_child(foliage)
	build_result["foliage"]=_build_foliage(foliage)
	if not build_result.foliage.get("ok",false):_fail_generation(build_result.foliage.reason);return
	for poi in generator.pois:_build_poi(poi)
	_build_edges_and_extracts()
	player=preload("res://scripts/player.gd").new();player.name="RaidPlayer";player.enabled=false;add_child(player)
	var start:Vector2=settings.SPAWN;player.position=Vector3(start.x,generator.height_at(start)+0.06,start.y);player.rotation.y=0.25
	var game_settings=preload("res://scripts/game_settings.gd").new();game_settings.apply(game_settings.load_settings(),player,get_viewport())
	raid_audio=preload("res://raid/scripts/raid_audio.gd").new();raid_audio.name="RaidAudio";add_child(raid_audio)
	_build_ui()
	# Node-bound one-shot callbacks disappear when a loading raid is freed.
	# A suspended _ready coroutine retains its Variant stack on cancellation in
	# Godot 4.6.3. Keep the same two-physics-tick collision barrier without it.
	preparation_physics_ticks=2
	get_tree().physics_frame.connect(_prepare_after_physics_tick,CONNECT_ONE_SHOT)

func _prepare_after_physics_tick():
	preparation_physics_ticks-=1
	if preparation_physics_ticks>0:
		get_tree().physics_frame.connect(_prepare_after_physics_tick,CONNECT_ONE_SHOT)
		return
	_complete_preparation()

func _complete_preparation():
	var ray=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*2,player.global_position-Vector3.UP*2);ray.exclude=[player.get_rid()]
	var ground=get_world_3d().direct_space_state.intersect_ray(ray)
	if ground.is_empty():_fail_generation("Landing collision unavailable.");return
	player.position.y=ground.position.y+0.04
	var probe=PhysicsShapeQueryParameters3D.new();probe.shape=player.standing_shape;probe.transform=Transform3D(Basis.IDENTITY,player.global_position+Vector3(0,0.92,0));probe.exclude=[player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(probe,1).is_empty():_fail_generation("Landing area obstructed.");return
	ready_for_play=true;player.enabled=true;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	build_result["ready"]=true
	print(_map_name().to_upper().replace(" ","_")+"_READY ",JSON.stringify(build_result))
	_notify(_map_name()+" development preview. Find landmarks, explore locked rooms, then reach an extraction beacon.",10.0)

func _fail_generation(reason:String):
	generation_failure=reason
	build_result["ready"]=false
	build_result["failure"]=reason
	if is_instance_valid(player):player.enabled=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var layer=CanvasLayer.new();layer.layer=110;add_child(layer)
	var cover=ColorRect.new();cover.color=Color("101b24");cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(cover)
	var column=VBoxContainer.new();column.position=Vector2(32,32);column.custom_minimum_size.x=540;cover.add_child(column)
	var label=Label.new();label.text=_map_name()+" could not open\n\n"+reason+"\n\nNo raid rewards or losses were saved.";label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(label)
	var button=Button.new();button.text="Return / Exit preview";button.custom_minimum_size.y=44;button.pressed.connect(_request_return);column.add_child(button);button.grab_focus()
	print(_map_name().to_upper().replace(" ","_")+"_REFUSED ",JSON.stringify(build_result))
func _setup_environment():
	var world=WorldEnvironment.new();var env=Environment.new();world.environment=env
	env.background_mode=Environment.BG_SKY
	var sky=Sky.new();var sky_material=ProceduralSkyMaterial.new();sky_material.sky_top_color=Color("314f67");sky_material.sky_horizon_color=Color("b4c4b3");sky_material.ground_horizon_color=Color("a2b6a6");sky_material.ground_bottom_color=Color("263b39");sky.sky_material=sky_material;env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("a2b8c5");env.ambient_light_energy=0.7;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.fog_enabled=true;env.fog_light_color=Color("93acaa");env.fog_density=0.0027;add_child(world)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-42,-25,0);sun.light_color=Color("ffe1b3");sun.light_energy=1.5;sun.shadow_enabled=true;sun.directional_shadow_max_distance=110;add_child(sun)
func _mat(color:Color,metal:float=0.0)->StandardMaterial3D:
	var result=StandardMaterial3D.new();result.albedo_color=color;result.roughness=0.85;result.metallic=metal;return result
func _box(parent:Node3D,pos:Vector3,size:Vector3,color:Color,collision:bool=true)->Node3D:
	var root=StaticBody3D.new() if collision else Node3D.new();root.position=pos;parent.add_child(root)
	var art=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=size;art.mesh=mesh;art.material_override=_mat(color);root.add_child(art)
	if collision:
		var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size;shape.shape=box;root.add_child(shape)
	return root
func _cylinder(parent:Node3D,pos:Vector3,height:float,radius:float,color:Color):
	var art=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.height=height;mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.radial_segments=12;art.mesh=mesh;art.position=pos;art.material_override=_mat(color,0.25);parent.add_child(art);return art
func _label(parent:Node3D,text:String,pos:Vector3,color:Color=Color.WHITE,size:int=30):
	var label=Label3D.new();label.text=text;label.position=pos;label.font_size=size;label.pixel_size=0.012;label.modulate=color;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.visibility_range_end=54;parent.add_child(label)
func _target(kind:String,node:Node3D,poi:Dictionary,extra:Dictionary={}):
	var data={"kind":kind,"node":node,"poi":poi};data.merge(extra);targets.append(data)
func _build_poi(poi:Dictionary):
	var root=Node3D.new();root.name=poi.id;root.position=Vector3(poi.at.x,generator.height_at(poi.at),poi.at.y);add_child(root)
	if poi.id=="bunker":
		preload("res://raid/scripts/research_annex.gd").new().build(self,root,poi)
		return
	_label(root,poi.name.to_upper(),Vector3(0,5.7,7),poi.theme,40)
	var wall=poi.theme.darkened(0.38)
	# Reusable traversable room with an actual clear doorway, not a solid box.
	_box(root,Vector3(0,-0.12,0),Vector3(12,0.24,10),Color("737d74"))
	_box(root,Vector3(-6,1.9,0),Vector3(0.3,3.8,10),wall)
	_box(root,Vector3(6,1.9,0),Vector3(0.3,3.8,10),wall)
	_box(root,Vector3(0,1.9,-5),Vector3(12,3.8,0.3),wall)
	_box(root,Vector3(-3.65,1.9,5),Vector3(4.7,3.8,0.3),wall)
	_box(root,Vector3(3.65,1.9,5),Vector3(4.7,3.8,0.3),wall)
	_box(root,Vector3(0,3.3,5),Vector3(2.6,1.0,0.3),wall)
	_box(root,Vector3(0,3.9,0),Vector3(12.7,0.25,10.7),Color("374d51"))
	_box(root,Vector3(0,3.35,5.3),Vector3(2.4,0.12,0.1),poi.theme,false)
	if poi.lock!="":
		var door_z=-1.0 if poi.lock=="puzzle" else 5.0
		if poi.lock=="puzzle":
			_box(root,Vector3(-3.65,1.9,-1),Vector3(4.7,3.8,0.3),wall)
			_box(root,Vector3(3.65,1.9,-1),Vector3(4.7,3.8,0.3),wall)
			_box(root,Vector3(0,3.3,-1),Vector3(2.6,1.0,0.3),wall)
		var door=_box(root,Vector3(0,1.35,door_z),Vector3(2.5,2.7,0.24),wall if poi.lock=="puzzle" else poi.theme)
		door_nodes[poi.id]=door;_target("door",door,poi)
		if poi.lock!="puzzle":_label(root,poi.lock.to_upper()+" ACCESS",Vector3(0,2.9,5.3),poi.theme,18)
		_build_field_supplies(root,poi)
		_label(root,"FIELD SUPPLIES",Vector3(-9,1.6,7),Color("d7ddc0"),19)
	var cache_z=-3.0 if poi.lock=="puzzle" else -1.0
	var cache=_build_cache(root,Vector3(0,0.5,cache_z))
	_target("cache",cache,poi)
	match poi.id:
		"relay":
			preload("res://raid/scripts/relay_landmark.gd").new().build(root)
		"bunker":
			for x in [-8,8]:_box(root,Vector3(x,2,-1),Vector3(2,4,12),Color("596f75"))
			_cylinder(root,Vector3(9,2.5,-8),5,1.3,Color("779da3"))
			_cylinder(root,Vector3(-9,2.5,-8),5,1.3,Color("779da3"))
		"substation":
			for x in [-9.0,9.0]:
				_box(root,Vector3(x,1.5,-4),Vector3(2.0,3.0,3.0),Color("728481"))
				for z in [-5,-3]:_cylinder(root,Vector3(x,3.4,z),1.2,0.3,Color("cbbd86"))
		"yard":
			# Same five solid envelopes. Only the primitive art is replaced.
			for i in 5:
				var cargo=_prop_body(root,Vector3(-12+(i%2)*23,1.2,-9+(i/2)*7),Vector3(3.5,2.4,5))
				Cargo.attach(cargo,"container_dented" if i%2 else "container_intact",false)
		"camp":
			for x in [-10,10]:_box(root,Vector3(x,1.1,-5),Vector3(4,2.2,5),Color("889270"))
			_cylinder(root,Vector3(9,5,5),10,0.06,Color("c3c8af"))
		"weather":
			_cylinder(root,Vector3(0,8,-1),8,0.14,Color("c8cec4"))
			var sphere=MeshInstance3D.new();var sm=SphereMesh.new();sm.radius=2.3;sm.height=4.6;sphere.mesh=sm;sphere.position=Vector3(0,13,-1);sphere.material_override=_mat(Color("bcc8bf"));root.add_child(sphere)
			for i in 3:
				var switch_node=_build_puzzle_control(root,Vector3(-4+i*4,0.9,9),false);_target("switch",switch_node,poi,{"number":i+1})
				_label(root,["NORTH / 1","WEST / 2","EAST / 3"][i],Vector3(-4+i*4,2.2,9),Color.WHITE,17)
func _build_field_supplies(parent:Node3D,poi:Dictionary):
	# The original, generous interaction box and solid stand collision stay put.
	# One credential-specific object avoids showing misleading extra pickups.
	var item=_prop_body(parent,Vector3(-9,0.9,7),Vector3(0.7,0.12,0.5))
	item.name="FieldSupplyPickup"
	var stand=_prop_body(parent,Vector3(-9,0.43,7),Vector3(1.4,0.8,1.0))
	stand.name="FieldSupplyStand"
	FieldSupplies.attach_stand(stand,_saltflat_props())
	FieldSupplies.attach_pickup(item,poi.lock,_saltflat_props())
	_target("clue",item,poi)
func _build_puzzle_control(parent:Node3D,pos:Vector3,valve:bool)->StaticBody3D:
	var body=_prop_body(parent,pos,Vector3(0.6,1.8,0.6))
	PuzzleControls.attach(body,valve)
	return body
func _prop_body(parent:Node3D,pos:Vector3,size:Vector3)->StaticBody3D:
	var body=StaticBody3D.new();body.position=pos;parent.add_child(body)
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape)
	return body
func _build_cache(parent:Node3D,pos:Vector3)->StaticBody3D:
	var body=_prop_body(parent,pos,Vector3(1.5,1,1))
	Props.attach_cache(body,_saltflat_props())
	return body
func _build_edges_and_extracts():
	# Physical border stays beyond routes, screened by rising terrain and fog.
	for x in [-151,151]:_box(self,Vector3(x,24,0),Vector3(1,70,304),Color(0,0,0,0)).get_child(0).hide()
	for z in [-151,151]:_box(self,Vector3(0,24,z),Vector3(304,70,1),Color(0,0,0,0)).get_child(0).hide()
	for i in settings.EXTRACTS.size():
		var p:Vector2=settings.EXTRACTS[i]+Vector2(2,0);var y=generator.height_at(p)
		var beacon=_prop_body(self,Vector3(p.x,y+1,p.y),Vector3(1.2,2,1.2))
		Props.attach_beacon(beacon,_saltflat_props())
		_target("extract",beacon,{"id":"extract%d"%i,"name":_extract_names()[i]})
		_cylinder(self,Vector3(p.x,y+4,p.y),6,0.08,Color("8ce3bd"))
		_label(self,_extract_names()[i].to_upper(),Vector3(p.x,y+5,p.y),Color("8ce3bd"),30)
		# Follow the actual terrain rather than floating a flat zone through a slope.
		for segment in 32:
			var angle=TAU*segment/32.0
			var edge=p+Vector2(cos(angle),sin(angle))*EXTRACTION_RADIUS
			_box(self,Vector3(edge.x,generator.height_at(edge)+0.04,edge.y),Vector3(0.28,0.06,0.28),Color("8ce3bd"),false)
func _build_ui():
	var layer=CanvasLayer.new();add_child(layer)
	var ui=Control.new();ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(ui)
	status=Label.new();status.position=Vector2(24,18);status.add_theme_font_size_override("font_size",21);ui.add_child(status)
	navigation=Label.new();navigation.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);navigation.position=Vector2(24,-43);navigation.size=Vector2(1100,28);navigation.add_theme_font_size_override("font_size",16);navigation.add_theme_color_override("font_color",Color("f4d28a"));navigation.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(navigation)
	hint=Label.new();hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);hint.position=Vector2(-430,-95);hint.size=Vector2(860,60);hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.add_theme_font_size_override("font_size",20);ui.add_child(hint)
	toast=Label.new();toast.position=Vector2(24,95);toast.size=Vector2(800,90);toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;toast.add_theme_color_override("font_color",Color("eddbac"));ui.add_child(toast)
	extraction_status=Label.new();extraction_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);extraction_status.position=Vector2(-270,155);extraction_status.size=Vector2(540,56);extraction_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;extraction_status.hide();ui.add_child(extraction_status)
	extraction_progress=ProgressBar.new();extraction_progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);extraction_progress.position=Vector2(-180,212);extraction_progress.size=Vector2(360,16);extraction_progress.max_value=State.EXTRACTION_DURATION;extraction_progress.show_percentage=false;extraction_progress.hide();ui.add_child(extraction_progress)
	var reticle=Label.new();reticle.text="+";reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER);reticle.position=Vector2(-4,-10);reticle.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(reticle)
	modal=PanelContainer.new();modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER);modal.position=Vector2(-280,-220);modal.size=Vector2(560,440);ui.add_child(modal)
	var margin=MarginContainer.new();for key in ["margin_left","margin_right","margin_top","margin_bottom"]:margin.add_theme_constant_override(key,24)
	modal.add_child(margin);modal_content=VBoxContainer.new();modal_content.add_theme_constant_override("separation",14);margin.add_child(modal_content);modal.hide()
	map_panel=preload("res://raid/scripts/raid_map.gd").new();map_panel.generator=generator;map_panel.map_title=_map_name();map_panel.player=player;map_panel.raid_state=raid_state;map_panel.extraction_targets=targets.filter(func(target):return target.kind=="extract");map_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);map_panel.position=Vector2(-360,-330);map_panel.size=Vector2(720,660);ui.add_child(map_panel);map_panel.hide()
func _key(action:String)->String:
	var events=InputMap.action_get_events(action)
	return events[0].as_text().replace(" (Physical)","") if not events.is_empty() else action
func _process(delta):
	if not ready_for_play:return
	note_time-=delta
	if note_time<=0:toast.text=""
	if player.position.y < -5 or maxf(absf(player.position.x),absf(player.position.z))>155:
		player.position=Vector3(settings.SPAWN.x,generator.height_at(settings.SPAWN)+0.1,settings.SPAWN.y);player.velocity=Vector3.ZERO
	var region=_wild_region()
	for poi in generator.pois:
		if Vector2(player.position.x,player.position.z).distance_to(poi.at)<poi.radius+12:
			region=poi.name+"  |  Loot quality %d-%d"%[poi.loot[0],poi.loot[1]]
			var detail=_region_detail(poi)
			if not detail.is_empty():region+="  |  "+detail
			break
	status.text=_map_name().to_upper()+"   /   DEVELOPMENT PREVIEW\n"+region+"\n"+_key("map")+" Map   •   Tab Field notes   •   Esc Pause   •   Visited %d/6   •   Caches %d/6"%[raid_state.visited.size(),raid_state.searched.size()]
	navigation.text=map_panel.navigation_text()
	navigation.visible=not modal.visible and not map_panel.visible
	if modal.visible or map_panel.visible:hint.text="";map_panel.queue_redraw();return
	active_target=_nearest_target()
	hint.text=""
	if not active_target.is_empty():
		var prompts={"door":"Open %s door"%active_target.poi.get("lock",""),"clue":"Read / collect field supplies","cache":"Inspect prototype loot cache","extract":"Extract and return","switch":_switch_prompt(active_target.get("number",0))}
		hint.text=_key("interact")+"  "+prompts[active_target.kind]
		if active_target.kind=="cache" and raid_state.searched.has(active_target.poi.id):hint.text="Cache searched this raid"
		if active_target.kind=="extract" and not raid_state.extraction_id.is_empty():hint.text=_key("interact")+"  Cancel extraction"

func _physics_process(delta:float):
	if not ready_for_play or returning or not raid_state.extracted_at.is_empty():return
	if player.enabled and not modal.visible and not map_panel.visible:
		raid_state.advance_active_time(delta)
		var at=Vector2(player.position.x,player.position.z)
		for poi in generator.pois:
			if at.distance_to(poi.at)<=poi.radius+6.0 and raid_state.visit(poi.id):
				_notify("Discovered "+poi.name+". Field notes track your route.")
	if raid_state.extraction_id.is_empty():return
	if not _extraction_eligible(extraction_target) or not player.enabled or modal.visible or map_panel.visible:
		_cancel_extraction("Extraction cancelled. Stay grounded inside the beacon markers for 8 seconds.")
		return
	if raid_state.advance_extraction(delta,true):
		Props.beacon_state(extraction_target.node,"complete")
		extraction_target={}
		extraction_status.hide();extraction_progress.hide()
		_extraction_complete()
	else:
		var second=int(floor(raid_state.extraction_seconds))
		if second>extraction_pulse_second:
			extraction_pulse_second=second
			# Activation lasts 1.6 seconds. Start pulses after it; never catch up
			# with a burst of missed pulses, and completion wins over a last pulse.
			if second>=2:_sound("beacon_countdown_pulse",Vector3.INF,"extraction")
		Props.beacon_state(extraction_target.node,"active",raid_state.extraction_seconds)
		extraction_status.text=extraction_target.poi.name+"\nExtraction in %.1f s · Stay inside the markers"%maxf(0.0,State.EXTRACTION_DURATION-raid_state.extraction_seconds)
		extraction_progress.value=raid_state.extraction_seconds

func _extraction_eligible(target:Dictionary)->bool:
	if target.is_empty() or target.get("kind","")!="extract" or not is_instance_valid(target.get("node")):return false
	var beacon:Vector3=target.node.global_position
	return player.is_on_floor() and Vector2(player.position.x,player.position.z).distance_to(Vector2(beacon.x,beacon.z))<=EXTRACTION_RADIUS and absf(player.position.y-(beacon.y-1.0))<=1.0

func _cancel_extraction(reason:String=""):
	var cancelled=raid_state.cancel_extraction()
	if not extraction_target.is_empty() and is_instance_valid(extraction_target.get("node")):Props.beacon_state(extraction_target.node,"idle")
	extraction_target={}
	extraction_pulse_second=0
	if is_instance_valid(raid_audio):
		raid_audio.stop_group("extraction")
		if cancelled and not reason.is_empty():_sound("beacon_cancel")
	if is_instance_valid(extraction_status):extraction_status.hide();extraction_progress.hide()
	if cancelled and not reason.is_empty():_notify(reason)

func _begin_extraction(target:Dictionary):
	if returning or not raid_state.extracted_at.is_empty():return
	# Recheck the live position when the confirmation button is activated.
	if not _extraction_eligible(target):
		_close_modal();_notify("Move onto the ground inside this beacon's markers, then try again.");return
	if not raid_state.start_extraction(target.poi.id):return
	extraction_pulse_second=0
	extraction_target=target
	Props.beacon_state(target.node,"active")
	_sound("beacon_activation",Vector3.INF,"extraction")
	_close_modal()
	extraction_status.text=target.poi.name+"\nExtraction in 8.0 s · Stay inside the markers"
	extraction_progress.value=0
	extraction_status.show();extraction_progress.show()
	_notify("Extraction requested. Leaving the zone, jumping, opening a menu or losing focus cancels it.",5)

func _extraction_panel(target:Dictionary):
	_start_modal("Request extraction?")
	_text(target.poi.name+"\nStay grounded inside the green markers for 8 seconds. You can move and look around. Leaving the zone, opening a menu or losing focus cancels the countdown.")
	_text("Results are a raid-only summary. No items, rewards or progression transfer to the settlement.")
	_button("Start 8-second extraction",func():_begin_extraction(target)).grab_focus()
	_button("Keep exploring",_close_modal)

func _summary_text()->String:
	var snapshot:Dictionary=raid_state.summary()
	var seconds=int(snapshot.active_seconds)
	var lines="Active exploration %d:%02d · Visited %d/6 · Caches %d/6\n"%[seconds/60,seconds%60,snapshot.visited.size(),snapshot.searched.size()]
	for poi in generator.pois:
		var progress="Not visited"
		if raid_state.visited.has(poi.id):progress="Visited · Cache not searched"
		if raid_state.searched.has(poi.id):progress="Sample quality %d"%raid_state.searched[poi.id]
		lines+="\n"+poi.name+": "+progress
	return lines

func _extraction_complete():
	_start_modal("Extraction complete")
	_sound("beacon_complete")
	_scroll_text(_summary_text())
	_text("Preview results only. Keys and sample rolls reset on return. No settlement rewards or losses.")
	_button("Return to settlement",_request_return).grab_focus()
func _nearest_target()->Dictionary:
	var best={};var distance=3.3
	for target in targets:
		if not is_instance_valid(target.node) or not target.node.visible:continue
		var point:Vector3=target.node.global_position
		var offset=point-player.camera.global_position
		if offset.length()>distance or -player.camera.global_basis.z.dot(offset.normalized())<0.68:continue
		var ray=PhysicsRayQueryParameters3D.create(player.camera.global_position,point);ray.exclude=[player.get_rid()]
		var hit=get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider!=target.node:continue
		best=target;distance=offset.length()
	return best
func _unhandled_input(event):
	if not ready_for_play:return
	if not raid_state.extracted_at.is_empty():return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_ESCAPE:
			if modal.visible or map_panel.visible:_close_modal()
			else:_pause_menu()
			get_viewport().set_input_as_handled();return
		if event.is_action_pressed("map"):
			if map_panel.visible:_close_modal()
			elif not modal.visible:
				_cancel_extraction("Extraction cancelled while opening the map.")
				map_panel.close_key=_key("map");map_panel.show();map_panel.grab_focus();player.enabled=false;player.velocity=Vector3.ZERO;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;map_panel.queue_redraw()
			get_viewport().set_input_as_handled();return
		if event.physical_keycode==KEY_TAB and not modal.visible and not map_panel.visible:_field_notes();get_viewport().set_input_as_handled();return
		if event.is_action_pressed("interact") and not modal.visible and not map_panel.visible and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
			var target=_nearest_target()
			if not target.is_empty():_interact(target)
			get_viewport().set_input_as_handled();return
	if event is InputEventMouseButton and event.pressed and not modal.visible and not map_panel.visible:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func _interact(target:Dictionary):
	if returning or not ready_for_play or not raid_state.extracted_at.is_empty():return
	var poi:Dictionary=target.poi
	match target.kind:
		"clue":
			if target.node.get_meta("collected",false):return
			_notify(raid_state.collect(poi),12)
			FieldSupplies.collect(target.node)
		"door":
			if poi.lock=="code":_code_panel(poi)
			else:
				var was_unlocked=raid_state.unlocked.get(poi.id,false)
				if raid_state.try_unlock(poi):
					if not was_unlocked and poi.lock in ["key","keycard"]:_sound("key_unlock" if poi.lock=="key" else "keycard_accepted",target.node.global_position)
					_open_door(poi.id)
				else:
					_sound("access_denied");_notify("Locked. Find "+_locked_hint(poi)+" in this POI.")
		"switch":
			var was_solved=raid_state.switch_step>=raid_state.PUZZLE_ORDER.size()
			_switch_sound(target)
			var solved=raid_state.flip_switch(target.number)
			PuzzleControls.activate(target.node)
			if solved and not was_solved:_sound("puzzle_solved",target.node.global_position)
			_notify(_switch_feedback(solved))
		"cache":
			var result=raid_state.search_cache(poi)
			if result.ok:Props.open_cache(target.node)
			_notify("Prototype roll: quality %d (%d-%d band). No settlement inventory changed."%[result.quality,poi.loot[0],poi.loot[1]] if result.ok else result.reason,9)
		"extract":
			if not raid_state.extraction_id.is_empty():_cancel_extraction("Extraction cancelled. Interact with a beacon to start again.")
			else:_extraction_panel(target)
func _open_door(id:String):
	var door:Node3D=door_nodes[id];door.hide()
	for child in door.get_children():
		if child is CollisionShape3D:child.set_deferred("disabled",true)
	_notify("Door unlocked.")
func _sound(cue:String,position:Vector3=Vector3.INF,group:String="feedback"):
	if is_instance_valid(raid_audio):raid_audio.play(cue,position,group)
func _notify(text:String,seconds:float=6.0):toast.text=text;note_time=seconds
func _start_modal(title:String):
	# Invalidate callbacks belonging to an earlier view before replacing its nodes.
	modal_generation+=1
	_cancel_extraction("Extraction cancelled while opening a menu.")
	for child in modal_content.get_children():modal_content.remove_child(child);child.queue_free()
	var heading=Label.new();heading.text=title;heading.add_theme_font_size_override("font_size",25);modal_content.add_child(heading)
	modal.show();map_panel.hide();player.enabled=false;player.velocity=Vector3.ZERO;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func _text(text:String):
	var label=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size=Vector2(490,0);modal_content.add_child(label);return label
func _scroll_text(text:String):
	var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(490,220);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;modal_content.add_child(scroll)
	var label=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.custom_minimum_size.x=466;scroll.add_child(label)
	return scroll
func _modal_callback_current(generation:int)->bool:
	return generation==modal_generation and ready_for_play and not returning and is_instance_valid(modal) and modal.visible
func _button(text:String,callback:Callable):
	var generation=modal_generation
	var button=Button.new();button.text=text;button.custom_minimum_size=Vector2(0,42)
	button.pressed.connect(func():
		if _modal_callback_current(generation):callback.call())
	modal_content.add_child(button);return button
func _close_modal():
	if returning or not raid_state.extracted_at.is_empty():return
	modal_generation+=1
	modal.hide();map_panel.hide();player.enabled=true;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func _code_panel(poi:Dictionary):
	_start_modal(poi.get("panel_name","Relay security panel"))
	var generation=modal_generation
	_text("Enter the four-digit door code. The maintenance note is somewhere within this POI.")
	var entry=LineEdit.new();entry.placeholder_text="4-digit code";entry.max_length=4;modal_content.add_child(entry)
	var previous={"text":""}
	entry.text_changed.connect(func(value:String):
		if not _modal_callback_current(generation):return
		# One cue per digit edit/paste, none for backspace or navigation. Keep
		# validation unchanged; non-digit input is rejected at submission.
		if value!=previous.text and value.length()>=str(previous.text).length() and not value.is_empty():
			var digits_only=true
			for character in value:
				if character<"0" or character>"9":digits_only=false
			if digits_only:_sound("keypad_press")
		previous.text=value)
	var feedback=_text("")
	var submit=func():
		# Text submission is a separate signal and must obey the same view lifetime.
		if not _modal_callback_current(generation):return
		if entry.text.length()==4 and entry.text.is_valid_int() and raid_state.try_unlock(poi,entry.text):_open_door(poi.id);_close_modal()
		else:_sound("access_denied");feedback.text="Code rejected. Check the maintenance note."
	_button("Unlock",submit);entry.text_submitted.connect(func(_value):submit.call());_button("Cancel",_close_modal);entry.grab_focus()
func _field_notes():
	_start_modal("Field notes / raid-only kit")
	var lines=""
	for id in raid_state.held:lines+=id.replace("_"," ")+"\n"
	for id in raid_state.notes:lines+=id.capitalize()+" code: "+raid_state.notes[id]+"\n"
	for id in raid_state.clues:lines+=raid_state.clues[id]+"\n"
	if lines.is_empty():lines="No keys, cards or codes found yet. Search field supplies within each POI."
	_scroll_text(lines+"\n\n"+_summary_text());_text("Loot quality rolls are samples only. Find an extraction beacon on the map when you are ready to leave. No item transfer, combat, loss or progression yet.")
	_button("Close",_close_modal).grab_focus()
func _pause_menu():
	_start_modal(_map_name()+" preview paused")
	_text(_pause_description())
	_button("Resume",_close_modal).grab_focus();_button("Return from preview",func():_exit_panel("Leave preview?"))
func _exit_panel(title:String):
	_start_modal(title);_text("The preview ends here. Keys, door states and sample loot rolls reset. Settlement items and progress are unchanged by this raid.")
	_button("Return to settlement",_request_return).grab_focus();_button("Keep exploring",_close_modal)
func _request_return():
	if returning or (not ready_for_play and generation_failure.is_empty()):return
	returning=true
	if raid_state!=null:_cancel_extraction()
	if is_instance_valid(raid_audio):raid_audio.stop_all()
	ready_for_play=false
	if is_instance_valid(player):player.enabled=false
	if return_requested.get_connections().is_empty():get_tree().quit()
	else:return_requested.emit()
func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_IN and is_instance_valid(raid_audio):raid_audio.resume()
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and ready_for_play and is_instance_valid(modal):
		if is_instance_valid(raid_audio):raid_audio.suspend()
		if not modal.visible and not map_panel.visible:_pause_menu()
		player.enabled=false
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
