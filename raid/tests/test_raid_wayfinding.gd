extends SceneTree
const Map=preload("res://raid/scripts/raid_map.gd")
const Archive=preload("res://raid/scripts/archive_wayfinding.gd")
var checks:=0
var failures:Array=[]
var scene
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func click(map,point:Vector2,button:int=MOUSE_BUTTON_LEFT):
	var event=InputEventMouseButton.new();event.button_index=button;event.pressed=true;event.position=point;map._gui_input(event)
func key(code:int)->InputEventKey:
	var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;return event
func state_snapshot()->String:
	return JSON.stringify([scene.raid_state.held,scene.raid_state.notes,scene.raid_state.clues,scene.raid_state.unlocked,scene.raid_state.searched,scene.raid_state.visited,scene.raid_state.extraction_id,scene.raid_state.extracted_at])
func open_map():
	root.push_input(key(KEY_M))
	var release=key(KEY_M);release.pressed=false;root.push_input(release)
	await process_frame
func test_map(path:String):
	scene=load(path).instantiate();root.add_child(scene)
	var deadline=Time.get_ticks_msec()+60000
	while not scene.is_raid_ready() and Time.get_ticks_msec()<deadline:await process_frame
	var prefix=scene._map_name()+": "
	check(scene.is_raid_ready(),prefix+"map ready")
	if not scene.is_raid_ready():scene.free();return
	scene.set_physics_process(false);scene.player.set_physics_process(false)
	var map=scene.map_panel
	check(map.waypoint_id.is_empty(),prefix+"new raid starts unpinned")
	var initial=state_snapshot()
	await open_map()
	check(map.visible and map.has_focus() and not scene.player.enabled,prefix+"map has keyboard focus and pauses movement")
	root.push_input(key(KEY_RIGHT))
	check(map.waypoint_id=="poi:"+scene.generator.pois[0].id,prefix+"viewport dispatch cycles focused map")
	var released_right=key(KEY_RIGHT);released_right.pressed=false;root.push_input(released_right)
	var destinations=map._destinations()
	check(destinations.size()==8,prefix+"six POIs and two real beacons")
	for destination in destinations:
		click(map,map._map_point(destination.map_position))
		check(map.selected_destination().id==destination.id,prefix+"click pins "+destination.name)
		if destination.kind=="approach":
			var poi=scene.generator.pois.filter(func(p):return "poi:"+p.id==destination.id)[0]
			check(destination.position!=poi.at,prefix+"pin is outside room centre "+poi.id)
			var on_trail=false
			for route in scene.generator.routes:
				for point in route:
					if point.distance_to(destination.position)<.01:on_trail=true
			check(on_trail,prefix+"approach is verified trail node "+poi.id)
		else:
			var target=scene.targets.filter(func(t):return t.kind=="extract" and "extract:"+t.poi.id==destination.id)[0]
			check(destination.position.is_equal_approx(Vector2(target.node.position.x,target.node.position.z)),prefix+"pin matches beacon "+destination.name)
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=map.get_global_transform_with_canvas()*map._map_point(destinations[0].map_position)
	var motion=InputEventMouseMotion.new();motion.position=event.position;root.push_input(motion,true)
	await process_frame
	root.push_input(event,true);event=event.duplicate();event.pressed=false;root.push_input(event,true)
	check(map.waypoint_id==destinations[0].id,prefix+"viewport mouse dispatch pins site")
	var saved=map.waypoint_id
	click(map,Vector2(5,5))
	check(map.waypoint_id==saved,prefix+"empty click does not replace pin")
	click(map,Vector2.ZERO,MOUSE_BUTTON_RIGHT)
	check(map.waypoint_id.is_empty(),prefix+"right click clears")
	map._gui_input(key(KEY_RIGHT))
	check(map.waypoint_id==destinations[0].id,prefix+"keyboard starts at first destination")
	map._gui_input(key(KEY_LEFT))
	check(map.waypoint_id==destinations[-1].id,prefix+"keyboard wraps backwards")
	map._gui_input(key(KEY_RIGHT))
	check(map.waypoint_id==destinations[0].id,prefix+"keyboard wraps forwards")
	var repeat=key(KEY_RIGHT);repeat.echo=true;map._gui_input(repeat)
	check(map.waypoint_id==destinations[0].id,prefix+"repeated key does not cycle")
	map._gui_input(key(KEY_DELETE));check(map.waypoint_id.is_empty(),prefix+"Delete clears")
	# Map binding wins over pin controls if the player remaps Map to an arrow.
	var bindings=InputMap.action_get_events("map")
	InputMap.action_erase_events("map");InputMap.action_add_event("map",key(KEY_RIGHT))
	map._gui_input(key(KEY_RIGHT));check(map.waypoint_id.is_empty(),prefix+"rebound Map key not consumed by pin cycling")
	root.push_input(key(KEY_RIGHT));root.push_input(released_right);check(not map.visible and scene.player.enabled,prefix+"rebound key closes map")
	InputMap.action_erase_events("map")
	for binding in bindings:InputMap.action_add_event("map",binding)
	click(map,map._map_point(destinations[1].map_position));map._gui_input(key(KEY_LEFT))
	check(map.waypoint_id.is_empty(),prefix+"stale hidden click/key ignored")
	await open_map();click(map,map._map_point(destinations[2].map_position));saved=map.waypoint_id
	root.push_input(key(KEY_ESCAPE));var released_escape=key(KEY_ESCAPE);released_escape.pressed=false;root.push_input(released_escape);scene._process(0)
	check(not map.visible and scene.player.enabled and scene.navigation.visible,prefix+"Escape closes map and restores HUD")
	await open_map();check(map.waypoint_id==saved,prefix+"same-raid pin survives reopen")
	scene._field_notes();map._gui_input(key(KEY_DELETE))
	check(map.waypoint_id==saved and scene.modal.visible,prefix+"replaced map cannot clear pin")
	scene._process(0);check(not scene.navigation.visible,prefix+"navigation hidden under modal")
	scene._close_modal();await open_map()
	scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not scene.player.enabled and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,prefix+"focus loss keeps map paused")
	scene._close_modal()
	check(initial==state_snapshot(),prefix+"pinning never collects visits keys rewards or extraction")
	# Both direction text and the drawn heading use the actual player yaw.
	for yaw_and_direction in [[0.0,"N"],[-PI/2,"E"],[PI,"S"],[PI/2,"W"]]:
		scene.player.rotation.y=yaw_and_direction[0]
		check(map.navigation_text().begins_with("Facing "+yaw_and_direction[1]),prefix+"yaw compass "+yaw_and_direction[1])
	map.waypoint_id=destinations[0].id
	var goal:Vector2=destinations[0].position
	scene.player.position=Vector3(goal.x,scene.generator.height_at(goal),goal.y+10)
	check(map.navigation_text().contains("N  10 m direct"),prefix+"distance and bearing use public approach")
	scene.player.position.z=goal.y
	check(map.navigation_text().contains("approach nearby") and not map.navigation_text().contains("extract"),prefix+"nearby approach is not extraction completion")
	var beacon=scene.targets.filter(func(t):return t.kind=="extract")[0]
	map.waypoint_id="extract:"+beacon.poi.id
	scene.player.position=beacon.node.position
	check(map.navigation_text().contains("Approach and interact") and scene.raid_state.extracted_at.is_empty(),prefix+"beacon arrival still requires normal interaction")
	var before:Vector3=beacon.node.position;beacon.node.position.x+=10
	check(map.navigation_text().contains("E  10 m direct"),prefix+"selected pin follows moved beacon")
	beacon.node.position=before
	map.waypoint_id="poi:not-a-site"
	check(map.selected_destination().is_empty() and not map.navigation_text().contains("direct"),prefix+"invalid pin fails closed")
	# Measure text and panel bounds at the existing supported logical viewport sizes.
	for dimensions in [Vector2i(1280,720),Vector2i(1440,900)]:
		root.size=dimensions;root.content_scale_size=dimensions;await process_frame;await process_frame
		await open_map()
		check(root.get_visible_rect().size==Vector2(dimensions),prefix+"logical viewport matches fixture "+str(dimensions))
		check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(map.get_global_rect()),prefix+"map panel fits "+str(dimensions))
		scene._close_modal()
		for destination in destinations:
			map.waypoint_id=destination.id;scene._process(0)
			var width=scene.navigation.get_theme_font("font").get_string_size(scene.navigation.text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
			check(width<=dimensions.x-48,prefix+"HUD text fits "+str(dimensions)+" "+destination.name)
	if path.contains("cinder"):await test_archive()
	scene.free();await preload("res://raid/tests/audio_shutdown.gd").drain(self)
func test_archive():
	var archive=scene.get_node("obsidian")
	var signs=archive.get_node("ArchiveWayfinding")
	check(signs.find_children("*","CollisionObject3D",true,false).is_empty(),"archive paint/signs never alter collision")
	var arrows=signs.get_children().filter(func(n):return String(n.name).begins_with("FloorArrow"))
	check(arrows.size()==9,"nine archive decision arrows")
	for arrow in arrows:
		var at:Vector3=arrow.global_position
		var query=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.3,at-Vector3.UP*.3);query.exclude=[scene.player.get_rid()]
		var hit=scene.get_world_3d().direct_space_state.intersect_ray(query)
		print("PAINT_FLOOR ",arrow.position," ",{} if hit.is_empty() else {"height":hit.position.y-archive.global_position.y,"body":str(hit.collider.get_path())})
		check(not hit.is_empty() and at.y>hit.position.y and at.y-hit.position.y<.08,"paint above real floor: "+str(arrow.position))
		var capsule=PhysicsShapeQueryParameters3D.new();capsule.shape=scene.player.standing_shape;capsule.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*.98);capsule.exclude=[scene.player.get_rid()]
		check(scene.get_world_3d().direct_space_state.intersect_shape(capsule,1).is_empty(),"paint leads through clear standing area: "+str(arrow.position))
	var labels=signs.find_children("*","Label3D",true,false)
	check(labels.size()==7,"seven local archive signs")
	for label in labels:check(not label.no_depth_test and label.visibility_range_end==18,"local sign respects walls and viewing range")
	for at_and_hint in [[Vector3(0,.05,5),"Level 1"],[Vector3(0,4.55,5),"Level 2"],[Vector3(0,8.55,-7),"Level 3"],[Vector3(12.4,2.0,-3),"Stairs"],[Vector3(0,0,24),""],[Vector3(18.8,4.6,-9),""]]:
		var expected:String=at_and_hint[1];var actual=Archive.location_hint(at_and_hint[0])
		check(actual.is_empty() if expected.is_empty() else actual.begins_with(expected),"local archive floor hint "+str(at_and_hint[0]))
	var poi=scene.generator.pois.filter(func(p):return p.id=="obsidian")[0]
	scene.player.global_position=archive.to_global(Vector3(0,8.55,-7));scene._process(0)
	check(scene._region_detail(poi).begins_with("Level 3") and scene.status.text.contains("Level 3"),"archive HUD uses local floor height")
	check(not scene.raid_state.try_unlock(poi) and not scene.raid_state.search_cache(poi).ok,"wayfinding preserves locked vault/cache")
func run():
	for direction in [[Vector2.UP,"N"],[Vector2(1,-1),"NE"],[Vector2.RIGHT,"E"],[Vector2(1,1),"SE"],[Vector2.DOWN,"S"],[Vector2(-1,1),"SW"],[Vector2.LEFT,"W"],[Vector2(-1,-1),"NW"],[Vector2.ZERO,"HERE"]]:
		check(Map.compass(direction[0])==direction[1],"compass octant "+direction[1])
	for path in ["res://raid/relay_ridge.tscn","res://raid/cinder_basin.tscn"]:await test_map(path)
	print("RAID_WAYFINDING_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"rendered":false,"native_input":false,"save_io":false}))
	quit(0 if failures.is_empty() else 1)
