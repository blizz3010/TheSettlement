extends RefCounted
# CPU scene readiness. A submitted render frame is not a GPU completion fence.
const CONTROLLERS = ['cooking_test','park_layered_visuals','park_west_visuals','four_area_gardens','cooking_nook_visuals','fishing_trader','inn_site','path_shoulder_gardens','market_edge_gardens','hall_east_spur_gardens','plaza_island_landscape']
var collision_modes:Dictionary = {}
var drawn := false

func track_collision(node:Node):
	# Static placement queries need registered bodies, not running gameplay.
	# Keep the character and dynamic bodies disabled throughout this phase.
	if node is StaticBody3D and not collision_modes.has(node):
		collision_modes[node] = node.disable_mode
		node.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE

func restore_collision_modes():
	for node in collision_modes:
		if is_instance_valid(node): node.disable_mode = collision_modes[node]
	collision_modes.clear()

func valid(world)->bool:
	return is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() and not world.startup_cancel_requested

func prepare(world, timeout_msec:int = 180000)->Dictionary:
	if not valid(world) or not world.world_initialized or world.world_activated:
		return {'ok':false,'reason':'World is not ready for asset preparation'}
	world.startup_preparing_assets = true
	world.player.enabled = false
	world.player.velocity = Vector3.ZERO
	var ship_result:Dictionary = preload("res://scripts/ship_construction_v096.gd").readiness(world)
	if not ship_result.get("ok",false):return {"ok":false,"reason":"Ship construction: "+str(ship_result.get("reason","Required construction unavailable"))}
	# Ship geometry is created before DayNightCycle; install its dependent lights only now.
	var lighting_result:Dictionary = preload("res://scripts/ship_route_lighting_v097.gd").apply(world.get_node("LaunchpadShip"))
	if not lighting_result.get("ok",false):return {"ok":false,"reason":"Ship route lighting: "+str(lighting_result.get("reason","Required lighting unavailable"))}
	var tree = world.get_tree()
	for node in world.find_children('*','StaticBody3D',true,false): track_collision(node)
	await tree.physics_frame
	await tree.physics_frame
	if not valid(world): return {'ok':false,'reason':'Loading cancelled'}
	if world.has_method("prepare_town_hall_login"):
		var spawn_result:Dictionary = world.prepare_town_hall_login()
		if not spawn_result.get("ok",false):return spawn_result
	var began = Time.get_ticks_msec()
	# Complete each dependency before starting later scenery. A failed early
	# controller must not allow dependent installers to mutate the world.
	var completed:Array = []
	for key in CONTROLLERS:
		if not valid(world):return {'ok':false,'reason':'Loading cancelled','completed':completed}
		var next_controller = world.get(key)
		if not is_instance_valid(next_controller):return {'ok':false,'reason':'Missing asset controller: '+key,'completed':completed}
		next_controller.begin_after_activation(world)
		while valid(world):
			if Time.get_ticks_msec()-began > timeout_msec:
				return {'ok':false,'reason':'Asset preparation timed out: '+key,'completed':completed}
			world._quiesce_startup_children()
			world.loading_stage.emit('Preparing scenery: '+key.replace('_',' '),0.0)
			var controller = world.get(key)
			if not is_instance_valid(controller):return {'ok':false,'reason':'Asset controller disappeared: '+key}
			var state:Dictionary = {}
			if key == 'cooking_test':
				if controller.placement_attempted:state = controller.clearance
			else:
				state = controller.result
				if key in ['park_layered_visuals','park_west_visuals'] and not controller.attempted:state = {}
			if not state.is_empty():
				if not state.get('ok',false):
					if key == 'plaza_island_landscape' and state.get('pending',false):
						return {'ok':false,'reason':'Your saved position overlaps new scenery. Go back and use the previous build to move onto a clear path, save, then retry. Your saved position has not been changed.','completed':completed,'controller':key,'saved_position':world.player.global_position}
					return {'ok':false,'reason':key+': '+str(state.get('reason','Asset preparation failed')),'completed':completed}
				completed.append(key)
				break
			await tree.process_frame
		if not valid(world):return {'ok':false,'reason':'Loading cancelled','completed':completed}
	world._quiesce_startup_children()
	world.loading_stage.emit('Preparing cooking station…',0.0)
	var cooking_result:Dictionary = preload("res://scripts/cooking_final_relocation.gd").apply(world)
	if not cooking_result.get('ok',false):
		return {'ok':false,'reason':'Cooking station relocation: '+str(cooking_result.get('reason','Unknown failure')),'completed':completed}
	completed.append('cooking_final_relocation')
	world.loading_stage.emit('Preparing final gardens…',0.0)
	var gardens_result:Dictionary = preload("res://scripts/landscape_finish_v085.gd").apply(world)
	if not gardens_result.get('ok',false):
		return {'ok':false,'reason':'Final gardens: '+str(gardens_result.get('reason','Unknown failure')),'completed':completed}
	completed.append('landscape_finish_v085')
	world.loading_stage.emit('Preparing Tailor & Dyes…',0.0)
	var tailor_result:Dictionary=preload("res://scripts/tailor_atelier.gd").finish(world)
	if not tailor_result.get("ok",false):return {"ok":false,"reason":"Tailor: "+str(tailor_result.get("reason","Preparation failed")),"completed":completed}
	if is_instance_valid(world.trader_previews):world.trader_previews.enable_marketplace()
	completed.append('tailor_atelier')
	if not valid(world):return {'ok':false,'reason':'Loading cancelled before shoreline tree grounding','completed':completed}
	world.loading_stage.emit('Grounding shoreline trees…',0.0)
	var lake_join_result:Dictionary = preload("res://scripts/lake_joins_v096.gd").apply(world)
	if not lake_join_result.get('ok',false):return {'ok':false,'reason':'Shoreline trees: '+str(lake_join_result.get('reason','Preparation failed')),'completed':completed}
	completed.append('lake_joins_v096')
	if not valid(world):return {'ok':false,'reason':'Loading cancelled before final bank finish','completed':completed}
	var bank_finish_result:Dictionary = preload("res://scripts/local_bank_finish_v096.gd").apply(world)
	if not bank_finish_result.get('ok',false):return {'ok':false,'reason':'Bank finish: '+str(bank_finish_result.get('reason','Preparation failed')),'completed':completed}
	completed.append('local_bank_finish_v096')
	world.loading_stage.emit('Finalizing scenery…',0.0)
	await tree.physics_frame
	if not valid(world):return {'ok':false,'reason':'Loading cancelled'}
	await tree.physics_frame
	await tree.process_frame
	if not valid(world):return {'ok':false,'reason':'Loading cancelled'}
	var submitted = false
	if DisplayServer.get_name() != 'headless':
		drawn = false
		RenderingServer.frame_post_draw.connect(_on_draw,CONNECT_ONE_SHOT)
		var render_start = Time.get_ticks_msec()
		while not drawn and valid(world) and Time.get_ticks_msec()-render_start < 10000:
			await tree.process_frame
		if RenderingServer.frame_post_draw.is_connected(_on_draw):RenderingServer.frame_post_draw.disconnect(_on_draw)
		if not drawn:return {'ok':false,'reason':'Render submission did not finish'}
		submitted = true
	if not valid(world):return {'ok':false,'reason':'Loading cancelled'}
	if world.has_method("prepare_town_hall_login"):
		var spawn_result:Dictionary = world.prepare_town_hall_login()
		if not spawn_result.get("ok",false):return spawn_result
	ship_result = preload("res://scripts/ship_construction_v096.gd").readiness(world)
	if not ship_result.get("ok",false):return {"ok":false,"reason":"Ship construction: "+str(ship_result.get("reason","Required construction unavailable")),"completed":completed}
	lighting_result = preload("res://scripts/ship_route_lighting_v097.gd").readiness(world.get_node("LaunchpadShip"))
	if not lighting_result.get("ok",false):return {"ok":false,"reason":"Ship route lighting: "+str(lighting_result.get("reason","Required lighting unavailable")),"completed":completed}
	world.startup_assets_ready = true
	return {'ok':true,'completed':completed,'render_frame_submitted':submitted,'gpu_completion_claimed':false}

func _on_draw():
	drawn = true
