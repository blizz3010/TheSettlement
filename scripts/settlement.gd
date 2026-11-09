extends Node3D
const Envelope=preload("res://scripts/settlement_envelope.gd")
const HomeRoofGeometry = preload("res://scripts/home_roof_geometry.gd")
const OptionsPanel = preload("res://scripts/options_panel.gd")
var settlement_hud
var quickbar=preload("res://scripts/quickbar_state.gd").new()
var controls: Label
var build_wheel
var wheel_prior_build := false
var options_panel
var quest_journal
var skills_panel
const FishingState = preload("res://scripts/fishing_state.gd")
const FISHING_SPOT = Vector3(15,.7665,-41.699)
const FISHING_TARGET = Vector3(15,.322,-44.699)
var fishing = FishingState.new()
var fishing_session = preload("res://scripts/fishing_session.gd").new()
var fishing_prop:Node3D
var fishing_accept:Button
var fishing_details:Label
const CraftState = preload("res://scripts/craft_state.gd")
const CraftingService = preload("res://scripts/crafting_service.gd")
const WorkbenchPanel = preload("res://scripts/workbench_panel.gd")
const FurnitureGeometry = preload("res://scripts/furniture_geometry.gd")
var craft = CraftState.new()
var crafting_service = CraftingService.new()
var workbench_panel: PanelContainer
var pending_craft := false
var craft_paused := false
var craft_accumulator := 0.0
var furniture_under_aim: Dictionary = {}
const RailingGeometry = preload("res://scripts/railing_geometry.gd")
const StairGeometry = preload("res://scripts/stair_geometry.gd")
const SuppliesPurchase = preload("res://scripts/supplies_purchase.gd")
const SuppliesPanel = preload("res://scripts/supplies_panel.gd")
var supplies_panel: PanelContainer
var fishing_trader
var trader_previews
var fishing_trader_restore:int=0
var fishing_progress_snapshot:Dictionary={}
const OwnedFishing=preload("res://scripts/owned_fishing_catch.gd")
var pending_supply := ""
var selling_materials := false
var supplies_purchase = SuppliesPurchase.new()
var supplies_transaction=preload("res://scripts/shop_transaction.gd").new()
var supplies_token:int=0
const SUPPLIES_COUNTER = Vector3(30,1.3,34.0)
const WestTraderCollision = preload("res://scripts/west_trader_collision.gd")
const TraderMaterialDisplays = preload("res://scripts/trader_material_displays.gd")
const TraderFrontage = preload("res://scripts/trader_frontage.gd")
const ReferenceFoliage = preload("res://scripts/reference_foliage.gd")
const FountainPlaza = preload("res://scripts/fountain_plaza.gd")
const ArchitectureMaterials = preload("res://scripts/architecture_materials.gd")
const ValleyBackdrop = preload("res://scripts/valley_backdrop.gd")
const DoorGeometry = preload("res://scripts/door_geometry.gd")
const Player = preload("res://scripts/player.gd")
const PlotState = preload("res://scripts/plot_state.gd")
const InventoryState = preload("res://scripts/inventory_state.gd")
const InventoryPanel = preload("res://scripts/inventory_panel.gd")
const SaveCodec = preload("res://scripts/save_codec.gd")
const OnboardingState = preload("res://scripts/onboarding_state.gd")
var onboarding = OnboardingState.new()
var clothing_service=preload("res://scripts/starter_clothing.gd").new()
var clothing_panel
var tailoring_service=preload("res://scripts/tailor_purchase.gd").new()
var tailoring_transactions=preload("res://scripts/shop_transaction.gd").new(tailoring_service.quote_candidate)
var clothing_accept:Button
const RequestState = preload("res://scripts/request_state.gd")
const RequestPanel = preload("res://scripts/request_panel.gd")
const BOARD = Vector3(-5.8,0,-9.1)
const PlazaSeating = preload("res://scripts/plaza_seating.gd")
var request = RequestState.new()
var request_panel: PanelContainer
const PlotLayout=preload("res://scripts/plot_layout.gd")
const STASH = PlotLayout.STASH
var stash_holder: Node3D
var stash_body: StaticBody3D
var moving_stash := false
var stash_move_source: Dictionary = {}
var stash_panel_source: Dictionary = {}
var stash_prior_kind := "foundation"
var stash_prior_build := false
var stash_prior_level := 0
var stash_prior_rotation := 0
var inventory = InventoryState.new()
var inventory_panel: PanelContainer
const PLOT = PlotLayout.ORIGIN
const VENDOR = Vector3(5.5,0,-26.5)
const HallGeometry = preload("res://scripts/town_hall_geometry.gd")
const LEGACY_SAVE = "user://settlement_v1.json"
var _character_slot: String = ""
var character_save_path: String:
	get:
		if _character_slot.is_empty(): return LEGACY_SAVE
		if _character_slot not in ["slot_1", "slot_2"]: return ""
		return "user://characters/%s/settlement_v1.json" % _character_slot
var character_slot_bound := false
var _character_appearance: Dictionary = {}
var character_appearance: Dictionary:
	get: return _character_appearance.duplicate(true)
# Optional future title binding. Default remains legacy; no migration or file creation.
func bind_character_slot(slot: String, appearance: Dictionary = {}) -> bool:
	if is_inside_tree() or is_node_ready() or world_initialized or character_slot_bound or slot not in ["slot_1", "slot_2"]:
		return false
	if not appearance.is_empty():
		var validator=preload("res://scripts/character_preview/creator_draft.gd").new()
		if not validator.valid(appearance) or appearance.name!=appearance.name.strip_edges(): return false
	_character_appearance=appearance.duplicate(true)
	_character_slot = slot
	character_slot_bound = true
	return true

func bind_legacy_continue() -> bool:
	if is_inside_tree() or is_node_ready() or world_initialized or character_slot_bound:
		return false
	character_slot_bound = true
	return true

const COURTYARD_SHADER = preload("res://assets/materials/courtyard_surface.gdshader")
var surface_cache: Dictionary = {}
var courtyard_surface_count := 0
var state = PlotState.new()
var player: CharacterBody3D
var pieces: Node3D
var boundary: Node3D
var ghost: Node3D
var ghost_material: StandardMaterial3D
const BuildSnap = preload("res://scripts/build_snap.gd")
var snap_context := ""
var snap_cell := Vector2i.ZERO
var target_outline: Node3D
var target_edge: MeshInstance3D
var piece_kind := "foundation"
var build_rotation := 0
var build_level := 0
var aim_level := 0
var has_build_target := false
var selection_reason := ""
var wall_under_aim: Dictionary = {}
var door_under_aim := false
var ceiling_under_aim := false
var stairs_under_aim := false
var railing_under_aim: Dictionary = {}
const CEILING_HEIGHT = 3.18
const CEILING_SIZE = Vector3(2,0.18,2)
const PIECE_NAMES = {"foundation":"Foundation","wall":"Solid wall","window_wall":"Window wall","doorframe":"Doorframe","door":"Door leaf","ceiling":"Flat roof / deck","pitched_roof":"Pitched roof half","canvas_awning":"Canvas awning","stairs":"Stairs","railing":"Deck railing","workbench":"Workbench","lantern":"Lantern kit","home_stash":"Move Home Stash","bed":"Starter bed"}
var hud: Label
var prompt: Label
var prompt_panel: PanelContainer
var vendor_prompt_active := false
var hall_visual_root: Node3D
var hall_material_result: Dictionary = {}
var hall_terrain_display_result: Dictionary = {}
var hud_root: Control
var wayfinding_labels: Array[Label3D] = []
var notice: Label
var dialog: PanelContainer
var dialog_text: Label
var upgrade_button: Button
var build_mode := false
var selected := Vector2i.ZERO
var selection_valid := false
var notice_time := 0.0
var elapsed := 0.0
var water: MeshInstance3D
var bronze = material("695441",0.65)
var stone = material("a99d81")
var dark = material("303e39")
var timber = material("765239")
var cream = material("e7d6ac")
var orange = material("ba572e")
var teal = material("237a78")
var purple = material("8d4b9a")
func material(hex: String, metallic := 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = 0.72
	m.metallic = metallic
	return m
func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, collision := false) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	if collision:
		var solid=collider(parent,pos,size)
		if size==Vector3(108,.6,108): solid.set_meta("audio_ground_regions",true)
	return node
func collider(parent: Node3D, pos: Vector3, size: Vector3):
	var body = StaticBody3D.new()
	body.set_meta("audio_surface","stone")
	var shape = CollisionShape3D.new()
	var data = BoxShape3D.new()
	data.size = size
	shape.shape = data
	body.add_child(shape)
	body.position = pos
	parent.add_child(body)
	return body
func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 64
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node
func courtyard_material(key: String, tint: Color, kind := "stone") -> ShaderMaterial:
	var cache_key = key + str(tint)
	if surface_cache.has(cache_key): return surface_cache[cache_key]
	var mat = ShaderMaterial.new()
	mat.shader = COURTYARD_SHADER
	mat.set_shader_parameter("tint",tint)
	mat.set_shader_parameter("metallic",0.72 if kind == "bronze" else (0.75 if kind == "edge" else 0.0))
	mat.set_shader_parameter("roughness",0.52 if kind == "bronze" else (0.40 if kind == "edge" else 0.86))
	mat.set_shader_parameter("variation",0.16 if kind == "bronze" else (0.08 if kind == "edge" else 0.18))
	mat.set_shader_parameter("grain_scale",24.0 if kind == "bronze" else (28.0 if kind == "edge" else 16.0))
	mat.set_shader_parameter("bump_strength",0.018 if kind == "bronze" else (0.008 if kind == "edge" else 0.025))
	mat.set_shader_parameter("patina",0.20 if kind == "bronze" else (0.06 if kind == "edge" else 0.0))
	surface_cache[cache_key] = mat
	return mat
func style_courtyard(node: Node):
	if node is MeshInstance3D:
		for index in range(node.mesh.get_surface_count()):
			var source = node.mesh.surface_get_material(index)
			if not source is StandardMaterial3D: continue
			var material_name = source.resource_name
			var kind = ""
			if material_name.begins_with("Limestone_"): kind = "stone"
			elif material_name == "Weathered_Bronze": kind = "bronze"
			elif material_name == "Polished_Bronze_Edges": kind = "edge"
			if not kind.is_empty():
				node.set_surface_override_material(index,courtyard_material(material_name,source.albedo_color,kind))
				courtyard_surface_count += 1
	for child in node.get_children(): style_courtyard(child)
func asset(file: String, pos: Vector3, yaw := 0.0) -> Node3D:
	var path = "res://assets/kit/" + file + ".glb"
	if not ResourceLoader.exists(path): return null
	var obj = load(path).instantiate()
	if file in ["fountain","fountain_apron","foundation","planter","planter_fern_variant"]: style_courtyard(obj)
	if file in ["fountain","fountain_apron"]: FountainPlaza.style_surfaces(obj)
	if file == "fountain": FountainPlaza.style_water(obj)
	if file in ["home_storage_chest","town_hall","canopy_stall","vendor_desk","trader_frontage","west_trader"]: ArchitectureMaterials.apply(obj)
	obj.position = pos
	obj.rotation.y = yaw
	add_child(obj)
	return obj
func label3(text: String, pos: Vector3, size := 32, billboard := true):
	var label = Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = size
	label.pixel_size = 0.009
	label.modulate = Color("f4e5bc")
	label.outline_size = 5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	add_child(label)
	return label
const Seats = preload("res://scripts/seat_interaction.gd")
const ApprovedAudio = preload("res://scripts/approved_settlement_audio.gd")
var settlement_audio: Node3D
signal loading_stage(label: String, elapsed_ms: float)
signal gameplay_ready
var staged_startup := false
var cooking_test
var park_layered_visuals
var four_area_gardens
var cooking_nook_visuals
var inn_site
var market_edge_gardens
var hall_east_spur_gardens
var plaza_island_landscape
var path_shoulder_gardens
var park_west_visuals
var cooking_window_focused:bool=true
var cooking_detach_restore:int=0
var world_initialized := false
var world_activated := false
var town_hall_login_requested := false
var town_hall_login_placed := false
var startup_preparing_assets := false
var startup_assets_ready := false
var startup_asset_gate = preload("res://scripts/startup_asset_gate.gd").new()
var startup_metrics: Array = []
var startup_last_usec := 0
var startup_frame_usec := 0
var startup_last_label := "bootstrap"
var startup_yield_count := 0
var startup_cancel_requested := false
var startup_process_overrides: Dictionary = {}
var startup_tracked_nodes: Dictionary = {}
var startup_tracking := false
var startup_quiesce_usec := 0
var startup_quiesce_max_usec := 0
var startup_quiesce_visits := 0
var startup_quiesce_calls := 0
var startup_wait_usec := 0
var startup_checkpoint_count := 0
var startup_phase := "constructing"
func _ready():
	cooking_window_focused=DisplayServer.get_name()=="headless" or DisplayServer.window_is_focused()
	if staged_startup: _start_startup_tracking()
	startup_last_usec = Time.get_ticks_usec()
	startup_frame_usec = startup_last_usec
	_initialize_world()

func request_startup_cancel():
	_set_coverage_active(false)
	startup_cancel_requested = true
	if world_initialized and not world_activated: _finish_startup_cancel()

func _finish_startup_cancel():
	startup_phase = "cancelled"
	if not is_queued_for_deletion(): queue_free()

func _startup_checkpoint(label: String) -> bool:
	startup_checkpoint_count += 1
	if startup_cancel_requested or is_queued_for_deletion(): return true
	var now = Time.get_ticks_usec()
	var milliseconds = float(now-startup_last_usec)/1000.0
	startup_metrics.append({"stage":startup_last_label,"milliseconds":milliseconds})
	startup_last_label = label
	loading_stage.emit(label,milliseconds)
	if staged_startup and now-startup_frame_usec >= 16000:
		_quiesce_startup_children()
		startup_yield_count += 1
		var waiting_at = Time.get_ticks_usec()
		await get_tree().process_frame
		startup_wait_usec += Time.get_ticks_usec()-waiting_at
		startup_frame_usec = Time.get_ticks_usec()
	startup_last_usec = Time.get_ticks_usec()
	return startup_cancel_requested

func _start_startup_tracking():
	if startup_tracking: return
	startup_tracking = true
	get_tree().node_added.connect(_startup_node_added)
	get_tree().node_removed.connect(_startup_node_removed)
	# One seed traversal; no recursive wildcard search on subsequent frame yields.
	for node in find_children("*","",true,false): startup_tracked_nodes[node] = true

func _startup_node_added(node: Node):
	if startup_preparing_assets and is_ancestor_of(node): startup_asset_gate.track_collision(node)
	if is_ancestor_of(node): startup_tracked_nodes[node] = true

func _startup_node_removed(node: Node):
	startup_tracked_nodes.erase(node)

func _stop_startup_tracking():
	if startup_tracking and is_inside_tree():
		if get_tree().node_added.is_connected(_startup_node_added): get_tree().node_added.disconnect(_startup_node_added)
		if get_tree().node_removed.is_connected(_startup_node_removed): get_tree().node_removed.disconnect(_startup_node_removed)
	startup_tracking = false
	startup_tracked_nodes.clear()

func _exit_tree():
	_set_coverage_active(false)
	_stop_startup_tracking()

func _quiesce_startup_children():
	var began = Time.get_ticks_usec()
	startup_quiesce_calls += 1
	# Keep checking EVERY member each yield: catches changes made after _ready too.
	# A new-node-only queue would silently weaken that existing startup contract.
	var children = startup_tracked_nodes if startup_tracking else find_children("*","",true,false)
	for node in children:
		startup_quiesce_visits += 1
		if not is_instance_valid(node): continue
		if node.process_mode == Node.PROCESS_MODE_ALWAYS or node.process_mode == Node.PROCESS_MODE_WHEN_PAUSED:
			startup_process_overrides[node] = node.process_mode
			node.process_mode = Node.PROCESS_MODE_INHERIT
	var elapsed = Time.get_ticks_usec()-began
	startup_quiesce_usec += elapsed
	startup_quiesce_max_usec = maxi(startup_quiesce_max_usec,elapsed)

func _set_coverage_active(enabled:bool):
	var coverage=get_meta("bundle_coverage_result",{})
	if not coverage is Dictionary or not coverage.get("ok",false):return
	for actor in coverage.get("actors",[]):
		if is_instance_valid(actor):actor.set_activation_enabled(enabled)

func request_town_hall_login()->bool:
	if is_inside_tree() or is_node_ready() or world_initialized: return false
	town_hall_login_requested = true
	return true

func prepare_town_hall_login()->Dictionary:
	if not town_hall_login_requested: return {"ok":true,"requested":false}
	var result = preload("res://scripts/login_spawn.gd").prepare(self,not town_hall_login_placed)
	if result.get("ok",false): town_hall_login_placed = true
	return result

func prepare_startup_assets()->Dictionary:
	return await startup_asset_gate.prepare(self)

func activate_loaded_world():
	if staged_startup and not startup_assets_ready: return
	_stop_startup_tracking()
	startup_phase = "activated"
	assert(world_initialized and not startup_cancel_requested)
	world_activated = true
	startup_preparing_assets = false
	for node in startup_process_overrides:
		if is_instance_valid(node): node.process_mode = startup_process_overrides[node]
	startup_process_overrides.clear()
	process_mode = Node.PROCESS_MODE_INHERIT
	startup_asset_gate.restore_collision_modes()
	player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if staged_startup: settlement_audio.setup(player)
	_set_coverage_active(true)
	if is_instance_valid(cooking_test):cooking_test.begin_after_activation(self)
	if is_instance_valid(park_layered_visuals):park_layered_visuals.begin_after_activation(self)
	if is_instance_valid(park_west_visuals):park_west_visuals.begin_after_activation(self)
	if is_instance_valid(four_area_gardens):four_area_gardens.begin_after_activation(self)
	if is_instance_valid(cooking_nook_visuals):cooking_nook_visuals.begin_after_activation(self)
	if is_instance_valid(fishing_trader):fishing_trader.begin_after_activation(self)
	if is_instance_valid(inn_site):inn_site.begin_after_activation(self)
	if is_instance_valid(path_shoulder_gardens):path_shoulder_gardens.begin_after_activation(self)
	if is_instance_valid(market_edge_gardens):market_edge_gardens.begin_after_activation(self)
	if is_instance_valid(hall_east_spur_gardens):hall_east_spur_gardens.begin_after_activation(self)
	if is_instance_valid(plaza_island_landscape):plaza_island_landscape.begin_after_activation(self)

func _initialize_world():
	if await _startup_checkpoint("001 get_tree().auto_accept_quit=false"):
		_finish_startup_cancel()
		return
	get_tree().auto_accept_quit=false
	if await _startup_checkpoint("002 await build_world()"):
		_finish_startup_cancel()
		return
	await build_world()
	if await _startup_checkpoint("003 preload('res://scripts/groundcover.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/groundcover.gd").add_to(self)
	if await _startup_checkpoint("004 preload('res://scripts/hideout_terrace.gd').reconcile(self,'SouthernGroundcover')"):
		_finish_startup_cancel()
		return
	preload("res://scripts/hideout_terrace.gd").reconcile(self,"SouthernGroundcover")
	if await _startup_checkpoint("005 preload('res://scripts/walkway_planting.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/walkway_planting.gd").add_to(self)
	if await _startup_checkpoint("006 preload('res://scripts/market_expansion.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	var market_root: Node3D
	if staged_startup: market_root=await preload("res://scripts/market_expansion.gd").add_to_staged(self)
	else: market_root=preload("res://scripts/market_expansion.gd").add_to(self)
	if startup_cancel_requested or is_queued_for_deletion() or not is_instance_valid(market_root):
		_finish_startup_cancel()
		return
	if await _startup_checkpoint("007 preload('res://scripts/home_request_signage.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/home_request_signage.gd").add_to(self)
	if await _startup_checkpoint("008 preload('res://scripts/psy_rear_roof_repair.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/psy_rear_roof_repair.gd").add_to(self)
	if await _startup_checkpoint("009 preload('res://scripts/trader_rear_roof_repairs.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/trader_rear_roof_repairs.gd").add_to(self)
	if await _startup_checkpoint("010 preload('res://scripts/approach_path_finish.gd').apply(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/approach_path_finish.gd").apply(self)
	if await _startup_checkpoint("011 add_child(preload('res://scripts/ambient_wildlife.gd').new())"):
		_finish_startup_cancel()
		return
	add_child(preload("res://scripts/ambient_wildlife.gd").new())
	if await _startup_checkpoint("012 preload('res://scripts/market_landscape.gd').apply_to(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/market_landscape.gd").apply_to(self)
	if await _startup_checkpoint("013 preload('res://scripts/plaza_lantern_reconciliation.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/plaza_lantern_reconciliation.gd").add_to(self)
	if await _startup_checkpoint("014 preload('res://scripts/west_path_planter_clearance.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/west_path_planter_clearance.gd").add_to(self)
	if await _startup_checkpoint("015 preload('res://scripts/route_gardens.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/route_gardens.gd").add_to(self)
	if await _startup_checkpoint("016 preload('res://scripts/path_foliage_finish.gd').apply(self)"):
		_finish_startup_cancel()
		return
	if staged_startup: await preload("res://scripts/path_foliage_finish.gd").apply_staged(self)
	else: preload("res://scripts/path_foliage_finish.gd").apply(self)
	if await _startup_checkpoint("017 preload('res://scripts/rook_shop_art.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	if staged_startup: await preload("res://scripts/rook_shop_art.gd").add_to_staged(self)
	else: preload("res://scripts/rook_shop_art.gd").add_to(self)
	if await _startup_checkpoint("018 preload('res://scripts/rook_shop.gd').finalize_routes(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/rook_shop.gd").finalize_routes(self)
	if await _startup_checkpoint("019 Seats.add_to(self)"):
		_finish_startup_cancel()
		return
	Seats.add_to(self)
	if await _startup_checkpoint("019a Park A occupancy preparation"):
		_finish_startup_cancel()
		return
	preload("res://scripts/park_hall.gd").prepare(self)
	if await _startup_checkpoint("020 preload('res://scripts/settlement_terrain.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	if staged_startup: await preload("res://scripts/settlement_terrain.gd").add_to_staged(self)
	else: preload("res://scripts/settlement_terrain.gd").add_to(self)
	if await _startup_checkpoint("020a Park A construction"):
		_finish_startup_cancel()
		return
	preload("res://scripts/park_hall.gd").add_to(self)
	if await _startup_checkpoint("021 preload('res://scripts/dome_boundary.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	if preload("res://scripts/dome_boundary.gd").add_to(self)==null:
		push_error("Settlement expansion boundary/ground preparation refused")
		request_startup_cancel()
		_finish_startup_cancel()
		return
	if await _startup_checkpoint("022 preload('res://scripts/settlement_stream.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	if staged_startup: await preload("res://scripts/settlement_stream.gd").add_to_staged(self)
	else: preload("res://scripts/settlement_stream.gd").add_to(self)
	if await _startup_checkpoint("023 preload('res://scripts/continuous_grass.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	if staged_startup: await preload("res://scripts/continuous_grass.gd").add_to_staged(self)
	else: preload("res://scripts/continuous_grass.gd").add_to(self)
	if await _startup_checkpoint("024 preload('res://scripts/day_night_cycle.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/day_night_cycle.gd").add_to(self)
	if await _startup_checkpoint("025 preload('res://scripts/dome_surface.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/dome_surface.gd").add_to(self)
	if await _startup_checkpoint("026 preload('res://scripts/sky_birds.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/sky_birds.gd").add_to(self)
	if await _startup_checkpoint("027 preload('res://scripts/ruined_valley.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	if staged_startup: await preload("res://scripts/ruined_valley.gd").add_to_staged(self)
	else: preload("res://scripts/ruined_valley.gd").add_to(self)
	if await _startup_checkpoint("027a bounded facade vines034"):
		_finish_startup_cancel()
		return
	preload("res://scripts/scenery_optional_details.gd").add_facade_vines(self)
	if await _startup_checkpoint("027b east bench detail035"):
		_finish_startup_cancel()
		return
	preload("res://scripts/scenery_optional_details.gd").add_lived_in_props(self)
	if await _startup_checkpoint("027c existing ruin clue038"):
		_finish_startup_cancel()
		return
	preload("res://scripts/scenery_optional_details.gd").add_ruin_clues(self)
	if await _startup_checkpoint("027c1 bundled render-only routes and staff"):
		_finish_startup_cancel()
		return
	set_meta("bundle_route_result",preload("res://scripts/bundle_route_finish.gd").apply(self))
	set_meta("bundle_coverage_result",preload("res://scripts/trader_coverage_bundle.gd").apply(self))
	set_meta("hall_staff_result",preload("res://scripts/hall_staff_coverage.gd").apply(self,get_meta("bundle_coverage_result",{})))
	hall_material_result=preload("res://scripts/hall_private_material_finish.gd").apply(hall_visual_root)
	if not hall_material_result.get("ok",false):
		set_meta("hall_material_failure",hall_material_result.get("reason","Unknown failure"))
		_finish_startup_cancel()
		return
	hall_terrain_display_result=preload("res://scripts/hall_terrain_display.gd").apply(self)
	if not hall_terrain_display_result.get("ok",false):
		set_meta("hall_terrain_display_failure",hall_terrain_display_result.get("reason","Unknown failure"))
		_finish_startup_cancel()
		return
	if await _startup_checkpoint("027d intentional planting pockets"):
		_finish_startup_cancel()
		return
	preload("res://scripts/intentional_planting_pockets.gd").add_to(self)
	if await _startup_checkpoint("028 pieces = Node3D.new()"):
		_finish_startup_cancel()
		return
	pieces = Node3D.new()
	add_child(pieces)
	if await _startup_checkpoint("030 boundary = Node3D.new()"):
		_finish_startup_cancel()
		return
	boundary = Node3D.new()
	add_child(boundary)
	if await _startup_checkpoint("032 player = Player.new()"):
		_finish_startup_cancel()
		return
	player = Player.new()
	if staged_startup: player.enabled = false
	add_child(player)
	if await _startup_checkpoint("035 player.position = Vector3(6,0.1,11)"):
		_finish_startup_cancel()
		return
	player.position = Vector3(6,0.1,11)
	if await _startup_checkpoint("036 player.rotation.y = 0.25"):
		_finish_startup_cancel()
		return
	player.rotation.y = 0.25
	if await _startup_checkpoint("037 create_ui()"):
		_finish_startup_cancel()
		return
	create_ui()
	if await _startup_checkpoint("038 create_preview()"):
		_finish_startup_cancel()
		return
	create_preview()
	if await _startup_checkpoint("039 load_game(false)"):
		_finish_startup_cancel()
		return
	var character_loaded = load_game(false)
	if character_slot_bound and not character_loaded:
		startup_cancel_requested = true
		_finish_startup_cancel()
		return
	if await _startup_checkpoint("040 refresh_plot()"):
		_finish_startup_cancel()
		return
	refresh_plot()
	if await _startup_checkpoint("041 if not staged_startup: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED"):
		_finish_startup_cancel()
		return
	if not staged_startup: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if await _startup_checkpoint("042 settlement_audio=preload('res://scripts/settlement_audio.gd').new()"):
		_finish_startup_cancel()
		return
	settlement_audio=preload("res://scripts/settlement_audio.gd").new()
	add_child(settlement_audio)
	if await _startup_checkpoint("044 if not staged_startup: settlement_audio.setup(player)"):
		_finish_startup_cancel()
		return
	if not staged_startup: settlement_audio.setup(player)
	if await _startup_checkpoint("045 preload('res://scripts/settlement_ui_finish.gd').apply(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/settlement_ui_finish.gd").apply(self)
	if await _startup_checkpoint("046 settlement_hud=preload('res://scripts/settlement_hud.gd').new()"):
		_finish_startup_cancel()
		return
	settlement_hud=preload("res://scripts/settlement_hud.gd").new()
	hud_root.add_child(settlement_hud)
	if await _startup_checkpoint("048 settlement_hud.setup(self)"):
		_finish_startup_cancel()
		return
	settlement_hud.setup(self)
	if await _startup_checkpoint("049 if '--smoke' in OS.get_cmdline_user_args(): smoke.call_deferred()"):
		_finish_startup_cancel()
		return

	if staged_startup:
		_quiesce_startup_children()
		startup_phase = "physics_barrier"
		await get_tree().physics_frame
		await get_tree().process_frame
		if startup_cancel_requested:
			_finish_startup_cancel()
			return
		startup_phase = "render_barrier"
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		if startup_cancel_requested:
			_finish_startup_cancel()
			return
	# The controller is quiescent during staged loading. Physical placement waits
	# until activation, when inherited-disabled collision bodies are available.
	cooking_test=preload("res://scripts/cooking_world_controller.gd").new()
	add_child(cooking_test);cooking_test.setup(self)
	park_layered_visuals=preload("res://scripts/park_layered_visuals.gd").new()
	add_child(park_layered_visuals);park_layered_visuals.setup(self)
	park_west_visuals=preload("res://scripts/park_west_visuals.gd").new()
	add_child(park_west_visuals);park_west_visuals.setup(self)
	four_area_gardens=preload("res://scripts/landscape_four_gardens.gd").new()
	add_child(four_area_gardens);four_area_gardens.setup(self)
	cooking_nook_visuals=preload("res://scripts/cooking_nook_visuals.gd").new()
	add_child(cooking_nook_visuals);cooking_nook_visuals.setup(self)
	fishing_trader=preload("res://scripts/fishing_trader_controller.gd").new()
	add_child(fishing_trader);fishing_trader.setup(self)
	trader_previews=preload("res://scripts/trader_preview_controller.gd").new()
	add_child(trader_previews);trader_previews.setup(self,false)
	preload("res://scripts/trader_workbench_finish.gd").apply(self)
	inn_site=preload("res://scripts/inn_site_install.gd").new()
	add_child(inn_site);inn_site.setup(self)
	path_shoulder_gardens=preload("res://scripts/path_shoulder_gardens.gd").new()
	add_child(path_shoulder_gardens);path_shoulder_gardens.setup(self)
	market_edge_gardens=preload("res://scripts/market_edge_gardens.gd").new()
	add_child(market_edge_gardens);market_edge_gardens.setup(self,"res://assets/garden_bake/west-grass-recipe.bin","57ec5799d19a2eaf90158a2a74b255ab1082a10040c07b398f2b86c09f77eb16")
	hall_east_spur_gardens=preload("res://scripts/hall_east_spur_gardens.gd").new()
	add_child(hall_east_spur_gardens);hall_east_spur_gardens.setup(self,"res://assets/garden_bake/hall-east-spur-recipe.bin","aa0926aea811ac5e3e7a156269c4a2c0e236cda4a58c7b652bb3338c34447cd1")
	plaza_island_landscape=preload("res://scripts/plaza_island_landscape.gd").new()
	add_child(plaza_island_landscape);plaza_island_landscape.setup(self)
	startup_phase = "initialized"
	world_initialized = true
	if not staged_startup:
		_set_coverage_active(true)
		cooking_test.begin_after_activation(self)
		park_layered_visuals.begin_after_activation(self)
		park_west_visuals.begin_after_activation(self)
		four_area_gardens.begin_after_activation(self)
		cooking_nook_visuals.begin_after_activation(self)
		fishing_trader.begin_after_activation(self)
		inn_site.begin_after_activation(self)
		path_shoulder_gardens.begin_after_activation(self)
		market_edge_gardens.begin_after_activation(self)
		hall_east_spur_gardens.begin_after_activation(self)
		plaza_island_landscape.begin_after_activation(self)
	gameplay_ready.emit()
	if "--smoke" in OS.get_cmdline_user_args(): smoke.call_deferred()
func build_world():
	if await _startup_checkpoint("050 ReferenceFoliage.add_to(self)"):
		_finish_startup_cancel()
		return
	ReferenceFoliage.add_to(self)
	if await _startup_checkpoint("051 add_child(ValleyBackdrop.new())"):
		_finish_startup_cancel()
		return
	var backdrop = ValleyBackdrop.new()
	backdrop.staged_startup = staged_startup
	add_child(backdrop)
	if staged_startup: await backdrop.initialize_staged(self)
	if await _startup_checkpoint("052 var env = WorldEnvironment.new()"):
		_finish_startup_cancel()
		return
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://assets/materials/cloud_sky.gdshader")
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("bfd7df")
	e.ambient_light_energy = 0.32
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	if await _startup_checkpoint("066 var sun = DirectionalLight3D.new()"):
		_finish_startup_cancel()
		return
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-28,0)
	sun.light_color = Color("ffe0a8")
	sun.light_energy = 0.78
	sun.shadow_enabled = true
	add_child(sun)
	if await _startup_checkpoint("072 box(self,Vector3(0,-0.35,0),Vector3(108,0.6,108),material('364839'),true)"):
		_finish_startup_cancel()
		return
	box(self,Vector3(0,-0.35,0),Vector3(108,0.6,108),material("364839"),true)
	# Bounded v0.2 courtyard art pass: shared world-space stone, unchanged geometry/collision.
	if await _startup_checkpoint("073 var paving = courtyard_material('paving',Color(0.46,0.44,0.38,1))"):
		_finish_startup_cancel()
		return
	var paving = courtyard_material("paving",Color(0.46,0.44,0.38,1))
	# Plaza paving and connecting pedestrian routes, all at natural walking scale.
	if await _startup_checkpoint("074 var plaza_support=cylinder(self,Vector3(0,-0.02,0),10,0.14,paving)"):
		_finish_startup_cancel()
		return
	var plaza_support=cylinder(self,Vector3(0,-0.02,0),10,0.14,paving)
	if await _startup_checkpoint("075 box(self,Vector3(0,-0.02,-12),Vector3(7,0.14,18),paving)"):
		_finish_startup_cancel()
		return
	box(self,Vector3(0,-0.02,-12),Vector3(7,0.14,18),paving)
	if await _startup_checkpoint("076 box(self,Vector3(-12,-0.02,-4),Vector3(24,0.14,5),paving)"):
		_finish_startup_cancel()
		return
	box(self,Vector3(-12,-0.02,-4),Vector3(24,0.14,5),paving)
	if await _startup_checkpoint("077 preload('res://scripts/paving_edges.gd').add_tiles(self,plaza_support,paving)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/paving_edges.gd").add_tiles(self,plaza_support,paving)
	if await _startup_checkpoint("078 if not asset('fountain',Vector3.ZERO):"):
		_finish_startup_cancel()
		return
	if not asset("fountain",Vector3.ZERO):
		cylinder(self,Vector3(0,0.35,0),2.5,0.7,bronze)
		cylinder(self,Vector3(0,1.3,0),0.4,2.5,bronze)
		var water_mat = material("226b73",0.4)
		water_mat.roughness = 0.15
		water = cylinder(self,Vector3(0,0.65,0),2.05,0.05,water_mat)
	if await _startup_checkpoint("079 asset('fountain_apron',Vector3.ZERO)"):
		_finish_startup_cancel()
		return
	asset("fountain_apron",Vector3.ZERO)
	if await _startup_checkpoint("080 FountainPlaza.build_collision(self)"):
		_finish_startup_cancel()
		return
	FountainPlaza.build_collision(self)
	if await _startup_checkpoint("081 var hall=asset('town_hall',HallGeometry.ANCHOR)"):
		_finish_startup_cancel()
		return
	var hall=asset("town_hall",HallGeometry.ANCHOR)
	hall_visual_root=hall
	if await _startup_checkpoint("082 assert(hall!=null,'Town hall art missing')"):
		_finish_startup_cancel()
		return
	assert(hall!=null,"Town hall art missing")
	if await _startup_checkpoint("083 HallGeometry.build(self)"):
		_finish_startup_cancel()
		return
	if staged_startup: await HallGeometry.build_staged(self)
	else: HallGeometry.build(self)
	# Existing steward placeholder relocated; no new named cast or welcome stock.
	if await _startup_checkpoint("084 var npc = MeshInstance3D.new()"):
		_finish_startup_cancel()
		return
	var npc = MeshInstance3D.new()
	var cap = CapsuleMesh.new()
	cap.radius = 0.25
	cap.height = 1.65
	npc.mesh = cap
	npc.material_override = teal
	npc.position = Vector3(5.5,1.13,-29.3)
	npc.name = "MaraStewardPlaceholder"
	add_child(npc)
	if await _startup_checkpoint("093 var mara_label=label3('MARA • PLOT STEWARD',Vector3(5.5,2.4,-28.2),25)"):
		_finish_startup_cancel()
		return
	var mara_label=label3("MARA • PLOT STEWARD",Vector3(5.5,2.4,-28.2),25)
	if await _startup_checkpoint("094 mara_label.name='MaraServiceLabel'"):
		_finish_startup_cancel()
		return
	mara_label.name="MaraServiceLabel"
	if await _startup_checkpoint("095 mara_label.pixel_size=.0035"):
		_finish_startup_cancel()
		return
	mara_label.pixel_size=.0035
	if await _startup_checkpoint("096 wayfinding_labels.append(mara_label)"):
		_finish_startup_cancel()
		return
	wayfinding_labels.append(mara_label)
	if await _startup_checkpoint("097 var west_trader = asset('west_trader',Vector3(-7,0,2),PI/2)"):
		_finish_startup_cancel()
		return
	var west_trader = asset("west_trader",Vector3(-7,0,2),PI/2)
	if await _startup_checkpoint("098 if west_trader: west_trader.name = 'WestTraderFrontage'"):
		_finish_startup_cancel()
		return
	if west_trader: west_trader.name = "WestTraderFrontage"
	if await _startup_checkpoint("099 WestTraderCollision.add_collision(self)"):
		_finish_startup_cancel()
		return
	WestTraderCollision.add_collision(self)
	if await _startup_checkpoint("100 preload('res://scripts/rook_shop.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/rook_shop.gd").add_to(self)
	if await _startup_checkpoint("101 TraderMaterialDisplays.add_to_counter(west_trader,true)"):
		_finish_startup_cancel()
		return
	TraderMaterialDisplays.add_to_counter(west_trader,true)
	var west_kitchen_result=preload("res://scripts/west_cooking_dressing.gd").apply(self,west_trader)
	if not west_kitchen_result.ok:
		set_meta("west_cooking_dressing_failure",west_kitchen_result.reason)
		_finish_startup_cancel()
		return
	if await _startup_checkpoint("102 var east_service_label = label3('ROOK'S SUPPLIES',Vector3(30,3.0,29.6),24)"):
		_finish_startup_cancel()
		return
	var east_service_label = label3("ROOK'S SUPPLIES",Vector3(30,3.0,29.6),24)
	if await _startup_checkpoint("103 east_service_label.name = 'EastServiceLabel'"):
		_finish_startup_cancel()
		return
	east_service_label.name = "EastServiceLabel"
	if await _startup_checkpoint("104 east_service_label.rotation.y=PI"):
		_finish_startup_cancel()
		return
	east_service_label.rotation.y=PI
	if await _startup_checkpoint("105 east_service_label.pixel_size = 0.006"):
		_finish_startup_cancel()
		return
	east_service_label.pixel_size = 0.006
	if await _startup_checkpoint("106 wayfinding_labels.append(east_service_label)"):
		_finish_startup_cancel()
		return
	wayfinding_labels.append(east_service_label)
	if await _startup_checkpoint("107 var west_service_label = label3('SELL MATERIALS\nWest counter',Vector3(-7,3.4,2),24)"):
		_finish_startup_cancel()
		return
	var west_service_label = label3("COOKHOUSE\nMaterials counter",Vector3(-7,3.4,2),24)
	if await _startup_checkpoint("108 west_service_label.name = 'WestServiceLabel'"):
		_finish_startup_cancel()
		return
	west_service_label.name = "WestServiceLabel"
	if await _startup_checkpoint("109 west_service_label.pixel_size = 0.006"):
		_finish_startup_cancel()
		return
	west_service_label.pixel_size = 0.006
	if await _startup_checkpoint("110 wayfinding_labels.append(west_service_label)"):
		_finish_startup_cancel()
		return
	wayfinding_labels.append(west_service_label)
	if await _startup_checkpoint("111 var board_root=Node3D.new()"):
		_finish_startup_cancel()
		return
	var board_root=Node3D.new()
	board_root.name="RequestBoard"
	board_root.position=BOARD
	board_root.rotation.y=atan2(-BOARD.x,-BOARD.z) # Readable +Z face toward fountain.
	add_child(board_root)
	if await _startup_checkpoint("116 box(board_root,Vector3(0,1.35,0),Vector3(1.8,1.5,0.15),timber,true)"):
		_finish_startup_cancel()
		return
	box(board_root,Vector3(0,1.35,0),Vector3(1.8,1.5,0.15),timber,true)
	if await _startup_checkpoint("117 for x in [-0.7,0.7]: box(board_root,Vector3(x,0.8,0),Vector3(0.12,1.6,0.2),bronze)"):
		_finish_startup_cancel()
		return
	for x in [-0.7,0.7]: box(board_root,Vector3(x,0.8,0),Vector3(0.12,1.6,0.2),bronze)
	if await _startup_checkpoint("118 var board_label = label3('REQUEST BOARD\nStarter request',Vector3(0,1.5,0.17),20,false)"):
		_finish_startup_cancel()
		return
	var board_label = label3("REQUEST BOARD\nStarter request",Vector3(0,1.5,0.17),20,false)
	if await _startup_checkpoint("119 board_label.reparent(board_root,false)"):
		_finish_startup_cancel()
		return
	board_label.reparent(board_root,false)
	if await _startup_checkpoint("120 board_label.pixel_size = 0.006"):
		_finish_startup_cancel()
		return
	board_label.pixel_size = 0.006
	if await _startup_checkpoint("121 wayfinding_labels.append(board_label)"):
		_finish_startup_cancel()
		return
	wayfinding_labels.append(board_label)
	if await _startup_checkpoint("122 PlazaSeating.add_to(self)"):
		_finish_startup_cancel()
		return
	PlazaSeating.add_to(self)
	if await _startup_checkpoint("123 var hideout_label = label3('YOUR HIDEOUT',Vector3(-17,5.05,12.5),28)"):
		_finish_startup_cancel()
		return
	var hideout_label = label3("YOUR HIDEOUT",Vector3(-17,5.05,12.5),28)
	if await _startup_checkpoint("124 hideout_label.pixel_size = 0.006"):
		_finish_startup_cancel()
		return
	hideout_label.pixel_size = 0.006
	if await _startup_checkpoint("125 wayfinding_labels.append(hideout_label)"):
		_finish_startup_cancel()
		return
	wayfinding_labels.append(hideout_label)
	if await _startup_checkpoint("126 stash_holder = Node3D.new()"):
		_finish_startup_cancel()
		return
	stash_holder = Node3D.new()
	stash_holder.name = "HomeStash"
	add_child(stash_holder)
	if await _startup_checkpoint("129 var chest = load('res://assets/kit/home_storage_chest.glb').instantiate()"):
		_finish_startup_cancel()
		return
	var chest = load("res://assets/kit/home_storage_chest.glb").instantiate()
	ArchitectureMaterials.apply(chest)
	stash_holder.add_child(chest)
	if await _startup_checkpoint("132 stash_body = collider(stash_holder,Vector3(0,0.45,0),Vector3(1.5,0.9,0.85))"):
		_finish_startup_cancel()
		return
	stash_body = collider(stash_holder,Vector3(0,0.45,0),Vector3(1.5,0.9,0.85))
	if await _startup_checkpoint("133 stash_body.set_meta('home_stash',true)"):
		_finish_startup_cancel()
		return
	stash_body.set_meta("home_stash",true)
	if await _startup_checkpoint("134 var stash_label = label3('HOME STASH',STASH+Vector3(0,1.7,0),25)"):
		_finish_startup_cancel()
		return
	var stash_label = label3("HOME STASH",STASH+Vector3(0,1.7,0),25)
	if await _startup_checkpoint("135 stash_label.reparent(stash_holder,false)"):
		_finish_startup_cancel()
		return
	stash_label.reparent(stash_holder,false)
	if await _startup_checkpoint("136 stash_label.position=Vector3(0,1.7,0)"):
		_finish_startup_cancel()
		return
	stash_label.position=Vector3(0,1.7,0)
	if await _startup_checkpoint("137 refresh_stash()"):
		_finish_startup_cancel()
		return
	refresh_stash()
	if await _startup_checkpoint("138 stash_label.pixel_size = 0.006"):
		_finish_startup_cancel()
		return
	stash_label.pixel_size = 0.006
	if await _startup_checkpoint("139 wayfinding_labels.append(stash_label)"):
		_finish_startup_cancel()
		return
	wayfinding_labels.append(stash_label)
	# v031: natural ground-grown border, same legacy90 anchors, no physics changes.
	if await _startup_checkpoint("140 preload('res://scripts/natural_border.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/natural_border.gd").add_to(self)
	if await _startup_checkpoint("141 preload('res://scripts/launchpad_ship.gd').add_to(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/launchpad_ship.gd").add_to(self)
	if await _startup_checkpoint("142 preload('res://scripts/launchpad_ship.gd').reconcile_border(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/launchpad_ship.gd").reconcile_border(self)
	if await _startup_checkpoint("143 preload('res://scripts/hideout_terrace.gd').build(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/hideout_terrace.gd").build(self)
	if await _startup_checkpoint("144 preload('res://scripts/hideout_terrace.gd').reconcile(self,'NaturalBorder')"):
		_finish_startup_cancel()
		return
	preload("res://scripts/hideout_terrace.gd").reconcile(self,"NaturalBorder")
	if await _startup_checkpoint("145 preload('res://scripts/foliage_wind.gd').apply_to(self)"):
		_finish_startup_cancel()
		return
	preload("res://scripts/foliage_wind.gd").apply_to(self)
	if await _startup_checkpoint("146 for i in range(16):"):
		_finish_startup_cancel()
		return
	for i in range(16):
		var a = i*TAU/16
		var p = Vector3(cos(a)*9.4,0,sin(a)*9.4)
		if abs(p.x)<3 and p.z<0: continue
		# One original fern planter overlapped the east workbay; preserve type/count.
		if i == 15: p = Vector3(11,0,-6.2)
		# All other ring positions, lanterns and border massing unchanged.
		asset("planter_fern_variant" if i%2 else "planter",p)
		if i%2==0:
			asset("lantern",p+Vector3(0,0.2,0))
			var light = OmniLight3D.new()
			light.position = p+Vector3(0,1,0)
			light.light_color = Color("ffbc62")
			light.light_energy = 1.5
			light.omni_range = 3
			add_child(light)
	# Protective dome ribs: readable subtle horizon structure, not a skybox painted concept.
	if await _startup_checkpoint("147 var dome_mat = material('93c4be',0.4)"):
		_finish_startup_cancel()
		return
	var dome_mat = material("93c4be",0.4)
	if await _startup_checkpoint("148 for a in range(0,180,30):"):
		_finish_startup_cancel()
		return
	for a in range(0,180,30):
		for step in range(36):
			var t = step*PI/36
			var p1 = Vector3(cos(t)*Envelope.HORIZONTAL_RADIUS,Envelope.CENTER_Y+sin(t)*Envelope.VERTICAL_RADIUS,0).rotated(Vector3.UP,deg_to_rad(a))
			var p2 = Vector3(cos(t+PI/36)*Envelope.HORIZONTAL_RADIUS,Envelope.CENTER_Y+sin(t+PI/36)*Envelope.VERTICAL_RADIUS,0).rotated(Vector3.UP,deg_to_rad(a))
			var beam = box(self,(p1+p2)/2,Vector3(0.055,0.055,p1.distance_to(p2)),dome_mat)
			beam.look_at(p2,Vector3.UP)
	if await _startup_checkpoint("149 for side in [-1,1]:"):
		_finish_startup_cancel()
		return
	for side in [-1,1]:
		collider(self,Vector3(side*45.5,3,0),Vector3(1,6,92))
		collider(self,Vector3(0,3,side*45.5),Vector3(92,6,1))
	if await _startup_checkpoint("base-world construction complete"):
		_finish_startup_cancel()
		return
func ui_backing(root: Control, pos: Vector2, dimensions: Vector2, anchor := Control.PRESET_TOP_LEFT):
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(anchor)
	panel.position = pos
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.055,0.055,0.88)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel",style)
	root.add_child(panel)
func create_ui():
	var layer = CanvasLayer.new()
	add_child(layer)
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	hud_root = root
	var ui_theme = Theme.new()
	ui_theme.set_color("font_outline_color","Label",Color(0.015,0.025,0.025,1))
	ui_theme.set_constant("outline_size","Label",5)
	root.theme = ui_theme
	ui_backing(root,Vector2(20,16),Vector2(600,108))
	ui_backing(root,Vector2(20,-110),Vector2(680,98),Control.PRESET_BOTTOM_LEFT)
	var title = Label.new()
	title.text = "S E T T L E M E N T   /   FIRST PLAYABLE"
	title.position = Vector2(32,24)
	title.add_theme_font_size_override("font_size",22)
	root.add_child(title)
	hud = Label.new()
	hud.position = Vector2(32,60)
	hud.add_theme_color_override("font_color",Color("eadbb8"))
	root.add_child(hud)
	controls = Label.new()
	controls.text = "WASD  Move   •   Mouse  Look   •   Shift  Sprint   •   Space  Jump   •   Ctrl  Crouch (hold)\nV  View  •  E  Interact  •  I  Inventory  •  B  Build wheel   •   R  Rotate\nLeft / right click  Place / remove   •   F5 Save   •   F9 Load   •   Esc Options"
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.position = Vector2(32,-96)
	controls.add_theme_font_size_override("font_size",16)
	root.add_child(controls)
	# Keep status and building instructions below the aiming area, above controls.
	prompt_panel = PanelContainer.new()
	prompt_panel.name = "ActionStatusPanel"
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt_panel)
	prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var prompt_style = StyleBoxFlat.new()
	prompt_style.bg_color = Color(0.025,0.055,0.055,0.94)
	prompt_style.border_color = Color("8c7954")
	prompt_style.set_border_width_all(1)
	prompt_style.set_corner_radius_all(5)
	prompt_style.content_margin_left = 14
	prompt_style.content_margin_right = 14
	prompt_style.content_margin_top = 10
	prompt_style.content_margin_bottom = 10
	prompt_panel.add_theme_stylebox_override("panel",prompt_style)
	prompt = Label.new()
	prompt.name = "ActionStatusText"
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.add_theme_font_size_override("font_size",18)
	prompt.add_theme_constant_override("outline_size",1)
	prompt_panel.add_child(prompt)
	root.resized.connect(layout_status_panel)
	layout_status_panel()
	prompt_panel.hide()
	var reticle = Label.new()
	reticle.text = "+"
	reticle.add_theme_constant_override("outline_size",8)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.position = Vector2(-5,-14)
	reticle.add_theme_color_override("font_color",Color("e6d6b5"))
	root.add_child(reticle)
	notice = Label.new()
	notice.position = Vector2(32,120)
	notice.add_theme_font_size_override("font_size",18)
	root.add_child(notice)
	dialog = PanelContainer.new()
	dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dialog.position = Vector2(-260,-180)
	dialog.custom_minimum_size = Vector2(520,330)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("182a29")
	style.border_color = Color("b89b61")
	style.set_border_width_all(2)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	dialog.add_theme_stylebox_override("panel",style)
	root.add_child(dialog)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	dialog.add_child(column)
	var header = Label.new()
	header.text = "MARA  /  TOWN HALL"
	header.add_theme_font_size_override("font_size",24)
	column.add_child(header)
	dialog_text = Label.new()
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.custom_minimum_size = Vector2(460,110)
	column.add_child(dialog_text)
	upgrade_button = Button.new()
	upgrade_button.text = "Expand plot • 100 settlement credits"
	upgrade_button.custom_minimum_size.y = 46
	upgrade_button.pressed.connect(upgrade_plot)
	column.add_child(upgrade_button)
	var close = Button.new()
	close.text = "Return to settlement"
	close.pressed.connect(close_dialog)
	column.add_child(close)
	dialog.hide()
	inventory_panel = InventoryPanel.new()
	root.add_child(inventory_panel)
	inventory_panel.transfer_requested.connect(transfer_inventory)
	inventory_panel.cell_transfer_requested.connect(transfer_inventory_cell)
	inventory_panel.clothing_cell_requested.connect(transfer_clothing_lockbox)
	inventory_panel.closed.connect(close_inventory)
	inventory_panel.equipment_action_requested.connect(change_equipment)
	inventory_panel.clothing_transfer_requested.connect(transfer_clothing_storage)
	inventory_panel.quick_access_requested.connect(change_quick_access)
	inventory_panel.move_stash_requested.connect(func(): begin_stash_move(true))
	inventory_panel.slot_take_requested.connect(func(item,slot): transfer_inventory("lockbox","carried",item,1,null,slot))
	request_panel = RequestPanel.new()
	root.add_child(request_panel)
	request_panel.action_requested.connect(request_action)
	request_panel.closed.connect(close_request_board)
	clothing_accept=Button.new()
	clothing_accept.text="A fresh outfit • Accept and visit the tailor"
	clothing_accept.tooltip_text="Free basic jacket, gloves, pants and boots. Then dye one eligible garment. Clothing is cosmetic."
	clothing_accept.pressed.connect(accept_clothing)
	request_panel.body.add_child(clothing_accept)
	fishing_details=Label.new();fishing_details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	request_panel.body.add_child(fishing_details)
	fishing_accept=Button.new();fishing_accept.pressed.connect(func():fishing_board_action())
	request_panel.body.add_child(fishing_accept)
	request_panel.body.move_child(fishing_details,1)
	request_panel.body.move_child(fishing_accept,2)
	request_panel.body.move_child(clothing_accept,3)
	clothing_panel=preload("res://scripts/clothing_panel.gd").new()
	root.add_child(clothing_panel)
	clothing_panel.action_requested.connect(clothing_action)
	clothing_panel.closed.connect(close_clothing)
	clothing_panel.review_requested.connect(tailor_shop_review)
	clothing_panel.confirmed.connect(tailor_shop_confirm)
	clothing_panel.cancelled.connect(tailor_shop_cancel)
	supplies_panel=SuppliesPanel.new()
	root.add_child(supplies_panel)
	supplies_panel.review_requested.connect(select_supply)
	supplies_panel.tab_changed.connect(change_supply_tab)
	tree_exiting.connect(func():supplies_transaction.cancel();tailoring_transactions.cancel())
	supplies_panel.confirmed.connect(confirm_supply)
	supplies_panel.cancelled.connect(cancel_supply)
	supplies_panel.closed.connect(close_supplies)
	workbench_panel=WorkbenchPanel.new();root.add_child(workbench_panel)
	workbench_panel.action_requested.connect(craft_action)
	workbench_panel.closed.connect(close_workbench)
	build_wheel=preload("res://scripts/build_wheel.gd").new();root.add_child(build_wheel)
	build_wheel.piece_selected.connect(choose_wheel_piece)
	build_wheel.cancelled.connect(close_build_wheel)
	build_wheel.exit_build.connect(exit_build_wheel)
	quest_journal=preload("res://scripts/quest_journal.gd").new();root.add_child(quest_journal)
	quest_journal.closed.connect(close_quests)
	skills_panel=preload("res://scripts/skills_panel.gd").new();root.add_child(skills_panel)
	skills_panel.closed.connect(close_skills)
	options_panel=OptionsPanel.new();root.add_child(options_panel)
	options_panel.setup(player,save_game.bind(false))
	options_panel.closed.connect(close_options)
	options_panel.quit_requested.connect(func():get_tree().quit())
func refresh_plot():
	refresh_stash()
	for child in pieces.get_children(): child.free()
	for child in boundary.get_children(): child.free()
	var span = 12.0 if state.expanded else 8.0
	var center = PLOT + (Vector3(2,0,2) if state.expanded else Vector3.ZERO)
	box(boundary,center+Vector3(0,0.02,0),Vector3(span,0.08,span),preload("res://scripts/home_finish_v094.gd").plot_material())
	for axis in [0,1]:
		for side in [-1,1]:
			var pos = center + (Vector3(side*span/2,0.09,0) if axis==0 else Vector3(0,0.09,side*span/2))
			box(boundary,pos,Vector3(0.08,0.08,span) if axis==0 else Vector3(span,0.08,0.08),bronze)
	for cell in state.cells:
		var pos = cell_position(cell)
		var path = "res://assets/kit/foundation.glb"
		if ResourceLoader.exists(path):
			var node = load(path).instantiate()
			style_courtyard(node)
			node.position = pos
			pieces.add_child(node)
		else: box(pieces,pos+Vector3(0,0.09,0),Vector3(1.96,0.18,1.96),stone)
		var floor_body = collider(pieces,pos+Vector3(0,0.09,0),Vector3(2,0.18,2))
		floor_body.set_meta("build_cell",cell)
	for wall in state.walls: create_wall(wall)
	for door in state.doors: create_door(door)
	for ceiling in state.ceilings: create_ceiling(ceiling)
	for stair in state.stairs: create_stairs(stair)
	for railing in state.railings: create_railing(railing)
	if not state.workbench.is_empty(): create_furniture("workbench",state.workbench)
	for lantern in state.lanterns: create_furniture("lantern",lantern)
	if not state.bed.is_empty(): create_furniture("bed",state.bed)
	if is_instance_valid(settlement_hud):settlement_hud.mini.refresh_geometry()
func railing_position(cell: Vector2i, side: int) -> Vector3:
	return ceiling_position(cell)+Vector3(0,0.18,0)+Vector3(0,0,-0.94).rotated(Vector3.UP,-side*PI/2)
func create_railing(record: Dictionary):
	var holder=RailingGeometry.assembly(true,record.cell,record.rotation)
	holder.name="DeckRailing";holder.position=railing_position(record.cell,record.rotation)
	holder.rotation.y=-record.rotation*PI/2;pieces.add_child(holder)
func railing_clear(cell: Vector2i, side: int) -> bool:
	var basis=Basis(Vector3.UP,-side*PI/2)
	for part in RailingGeometry.parts():
		var shape=BoxShape3D.new();shape.size=part.size-Vector3.ONE*0.002
		var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.exclude=[player.get_rid()]
		query.transform=Transform3D(basis,railing_position(cell,side)+basis*part.position)
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	return true
func railing_occupied(cell: Vector2i, side: int) -> bool:
	var local=(player.position-railing_position(cell,side)).rotated(Vector3.UP,side*PI/2)
	return abs(local.x)<1.23 and abs(local.z)<0.39 and local.y<1.0 and local.y+1.8>0
func stair_position(cell: Vector2i) -> Vector3:
	return cell_position(cell)+Vector3(0,0.18,0)
func create_stairs(record: Dictionary):
	var holder=StairGeometry.assembly(true,record.cell)
	holder.name="Stairs"
	holder.position=stair_position(record.cell)
	holder.rotation.y=-record.rotation*PI/2
	pieces.add_child(holder)
func stair_occupied(cell: Vector2i, side: int) -> bool:
	var local=(player.position-stair_position(cell)).rotated(Vector3.UP,side*PI/2)
	return abs(local.x)<1.04 and local.z>-3.4 and local.z<1.4 and local.y>-1.8 and local.y<4.3
func ceiling_occupied(cell: Vector2i, level := 0) -> bool:
	var local=player.position-ceiling_position(cell,level)
	return abs(local.x)<1.33 and abs(local.z)<1.33 and local.y>=0 and local.y<2.1
func stair_clear(cell: Vector2i, side: int) -> bool:
	var basis=Basis(Vector3.UP,-side*PI/2)
	# Sweep a full-height capsule above every tread and across the landing.
	var shape=CapsuleShape3D.new();shape.radius=0.32;shape.height=1.8
	for i in range(41):
		var progress=float(i)/40.0
		var z=1.0-progress*4.0
		var tread=clampi(int(floor(progress*StairGeometry.COUNT)),0,StairGeometry.COUNT-1)
		var y=StairGeometry.step_height(tread)
		var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.exclude=[player.get_rid()]
		query.transform=Transform3D(Basis.IDENTITY,stair_position(cell)+basis*Vector3(0,y+0.91,z))
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	for z in [-3.15,-3.5,-4.0]:
		var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.exclude=[player.get_rid()]
		query.transform=Transform3D(Basis.IDENTITY,stair_position(cell)+basis*Vector3(0,3.18+0.91,z))
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	for part in StairGeometry.parts():
		var box_shape=BoxShape3D.new();box_shape.size=part.size-Vector3.ONE*0.002
		var query=PhysicsShapeQueryParameters3D.new();query.shape=box_shape;query.exclude=[player.get_rid()]
		query.transform=Transform3D(basis*Basis(Vector3.RIGHT,part.rotation),stair_position(cell)+basis*part.position)
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	return true
func cell_position(cell: Vector2i) -> Vector3:
	return PlotLayout.cell(cell)
func ceiling_position(cell: Vector2i, level := 0) -> Vector3:
	return cell_position(cell)+Vector3(0,CEILING_HEIGHT*(level+1),0)
func ceiling_visual() -> Node3D:
	# Reuse the original kit's exact 2m limestone slab, no expanded rim or invisible overhang.
	var visual = load("res://assets/kit/foundation.glb").instantiate()
	style_courtyard(visual)
	return visual
func create_ceiling(record: Dictionary):
	var holder = Node3D.new()
	holder.name = "Ceiling"
	holder.position = ceiling_position(record.cell,record.get("level",0))
	holder.rotation.y = -record.rotation*PI/2
	holder.add_child(ceiling_visual() if record.get("roof_kind","ceiling") == "ceiling" else HomeRoofGeometry.assembly(record.roof_kind))
	pieces.add_child(holder)
	if record.get("roof_kind","ceiling") != "ceiling":
		for part in HomeRoofGeometry.parts(record.roof_kind):
			var roof_body = collider(holder,part.position,part.size)
			roof_body.rotation.x = part.angle
			# collider() places its shape locally; rotate around the part center.
			roof_body.position = part.position
			roof_body.get_child(0).position = Vector3.ZERO
			roof_body.set_meta("build_cell",record.cell)
			roof_body.set_meta("build_ceiling",true)
			roof_body.set_meta("roof_kind",record.roof_kind)
			roof_body.set_meta("build_level",record.get("level",0))
			roof_body.set_meta("audio_surface","wood")
		return
	var body = collider(holder,Vector3(0,0.09,0),CEILING_SIZE)
	body.set_meta("build_cell",record.cell)
	body.set_meta("audio_surface","wood")
	body.set_meta("build_ceiling",true)
	body.set_meta("build_level",record.get("level",0))
func home_roof_clear(kind: String, cell: Vector2i, side: int, level: int) -> bool:
	var bounds = HomeRoofGeometry.envelope(kind,side)
	if bounds.position.x < -1 or bounds.end.x > 1 or bounds.position.z < -1 or bounds.end.z > 1: return false
	var basis = Basis(Vector3.UP,-side*PI/2)
	for part in HomeRoofGeometry.parts(kind):
		var shape = BoxShape3D.new(); shape.size = part.size-Vector3.ONE*0.002
		var query = PhysicsShapeQueryParameters3D.new(); query.shape = shape
		query.transform = Transform3D(basis*Basis(Vector3.RIGHT,part.angle),ceiling_position(cell,level)+basis*part.position)
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	return true
func ceiling_clear(cell: Vector2i, level := 0) -> bool:
	var shape = BoxShape3D.new()
	# Numerical contact tolerance at wall tops and adjacent slab edges, not overlap allowance.
	shape.size = CEILING_SIZE-Vector3.ONE*0.002
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,ceiling_position(cell,level)+Vector3(0,0.09,0))
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func wall_position(cell: Vector2i, side: int, level := 0) -> Vector3:
	# Inset 0.20m keeps the thickest imported window panel wholly inside its support footprint.
	var offset = Vector3(0,0,-0.8).rotated(Vector3.UP,-side*PI/2)
	return cell_position(cell)+Vector3(0,0.18+CEILING_HEIGHT*level,0)+offset
func create_wall(record: Dictionary):
	var holder = Node3D.new()
	holder.position = wall_position(record.cell,record.rotation,record.get("level",0))
	holder.rotation.y = -record.rotation*PI/2
	pieces.add_child(holder)
	var visual = load("res://assets/kit/"+record.type+".glb").instantiate()
	ArchitectureMaterials.apply(visual)
	# Imported bronze end caps are 2.01m; preserve a 1.98m legal footprint.
	visual.scale.x = 1.98/2.01
	holder.add_child(visual)
	var bodies: Array = []
	if record.type == "doorframe":
		bodies.append(collider(holder,Vector3(-0.88,1.5,0),Vector3(0.22,3,0.30)))
		bodies.append(collider(holder,Vector3(0.88,1.5,0),Vector3(0.22,3,0.30)))
		bodies.append(collider(holder,Vector3(0,2.88,0),Vector3(1.98,0.24,0.30)))
	else:
		bodies.append(collider(holder,Vector3(0,1.5,0),Vector3(1.98,3,0.36)))
	for body in bodies:
		body.set_meta("build_wall",record.duplicate())
		body.set_meta("build_level",record.get("level",0))
		body.set_meta("build_cell",record.cell)
func create_door(record: Dictionary):
	var frame = DoorGeometry.assembly(record.open)
	frame.position = wall_position(record.cell,record.rotation,record.get("level",0))
	frame.rotation.y = -record.rotation*PI/2
	pieces.add_child(frame)
	var pivot = frame.get_node("Leaf")
	var bodies=[collider(pivot,DoorGeometry.CENTER,DoorGeometry.SIZE)]
	for x in [-0.635,0.635]: bodies.append(collider(frame,Vector3(x,1.37,0),Vector3(0.27,2.68,0.18)))
	for body in bodies:
		body.set_meta("build_wall",{"type":"doorframe","cell":record.cell,"rotation":record.rotation,"level":record.get("level",0)})
		body.set_meta("build_cell",record.cell)
		body.set_meta("build_door",true)
		body.set_meta("build_level",record.get("level",0))
func upper_wall_clear(kind: String, cell: Vector2i, side: int) -> bool:
	var parts=[{"pos":Vector3(0,1.5,0),"size":Vector3(1.98,3,0.36)}]
	if kind=="doorframe": parts=[{"pos":Vector3(-0.88,1.5,0),"size":Vector3(0.22,3,0.30)},{"pos":Vector3(0.88,1.5,0),"size":Vector3(0.22,3,0.30)},{"pos":Vector3(0,2.88,0),"size":Vector3(1.98,0.24,0.30)}]
	var excluded: Array[RID]=[player.get_rid()]
	# Existing kit uses intentionally intersecting perpendicular corner caps. Only fixed
	# upper wall bodies are ignored here; moving door leaves, railings and other solids are not.
	for holder in pieces.get_children():
		for body in holder.get_children():
			if body is StaticBody3D and body.has_meta("build_wall") and not body.has_meta("build_door"):
				var other=body.get_meta("build_wall")
				if other.get("level",0)==1 and other.cell==cell and (other.rotation-side)%2!=0: excluded.append(body.get_rid())
	var basis=Basis(Vector3.UP,-side*PI/2)
	for part in parts:
		var shape=BoxShape3D.new();shape.size=part.size-Vector3.ONE*0.002
		var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.exclude=excluded
		query.transform=Transform3D(basis,wall_position(cell,side,1)+basis*part.pos)
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	return true
func aimed_door() -> Dictionary:
	var from = player.camera.global_position
	var query = PhysicsRayQueryParameters3D.create(from,from-player.camera.global_basis.z*7.5)
	query.exclude = [player.get_rid()]
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.position.distance_to(player.global_position+Vector3(0,1,0)) <= 3.0 and is_instance_valid(hit.get("collider")) and hit.collider.has_meta("build_wall"):
		var record = hit.collider.get_meta("build_wall")
		var index = state.door_index(record.cell,record.rotation,record.get("level",0))
		if index >= 0: return state.doors[index].duplicate()
	return {}
func door_swing_clear(record: Dictionary) -> bool:
	# Test the complete swept sector, padded to cover intervals; never swing through a body.
	var excluded: Array[RID] = []
	for holder in pieces.get_children():
		for child in holder.get_children():
			if child is StaticBody3D and child.has_meta("build_wall"):
				var wall = child.get_meta("build_wall")
				if state.level_edge_key(wall.cell,wall.rotation,wall.get("level",0))==state.level_edge_key(record.cell,record.rotation,record.get("level",0)): excluded.append(child.get_rid())
			for nested in child.get_children():
				if nested is StaticBody3D and nested.has_meta("build_wall"):
					var wall = nested.get_meta("build_wall")
					if state.level_edge_key(wall.cell,wall.rotation,wall.get("level",0))==state.level_edge_key(record.cell,record.rotation,record.get("level",0)): excluded.append(nested.get_rid())
	var frame = Transform3D(Basis(Vector3.UP,-record.rotation*PI/2),wall_position(record.cell,record.rotation,record.get("level",0)))
	var shape=BoxShape3D.new();shape.size=DoorGeometry.SIZE+Vector3(0.02,0.0,0.04)
	for step in range(91):
		var pivot=Transform3D(Basis(Vector3.UP,-step*PI/180),DoorGeometry.HINGE)
		var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.exclude=excluded
		query.transform=frame*pivot*Transform3D(Basis.IDENTITY,DoorGeometry.CENTER)
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	return true
func toggle_aimed_door(writer_override = null) -> bool:
	if build_mode or modal_open(): return false
	var record = aimed_door()
	if record.is_empty(): return false
	if not door_swing_clear(record): message("Door blocked: step clear of its swing area."); return false
	var candidate=plot_candidate()
	if candidate==null or not candidate.set_door_open(record.cell,record.rotation,not record.open,record.get("level",0)): return false
	return publish_plot_candidate(candidate,"Door %s • saved" % ("closed" if record.open else "opened"),writer_override)
func preview_style(node: Node):
	if node is MeshInstance3D:
		node.material_override = ghost_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children(): preview_style(child)
func create_preview():
	snap_context = ""
	if is_instance_valid(ghost): ghost.free()
	if piece_kind == "home_stash":
		ghost=Node3D.new()
		var chest_preview=load("res://assets/kit/home_storage_chest.glb").instantiate()
		chest_preview.rotation.y=PI
		ghost.add_child(chest_preview)
	elif piece_kind in ["workbench","lantern","bed"]:
		ghost=FurnitureGeometry.assembly(piece_kind)
	elif piece_kind == "railing":
		ghost=RailingGeometry.assembly()
	elif piece_kind == "stairs":
		ghost=StairGeometry.assembly()
	elif piece_kind in ["pitched_roof","canvas_awning"]:
		ghost = HomeRoofGeometry.assembly(piece_kind)
	elif piece_kind == "ceiling":
		ghost = ceiling_visual()
	elif piece_kind == "door":
		ghost = DoorGeometry.assembly(false)
	else: ghost = load("res://assets/kit/"+piece_kind+".glb").instantiate()
	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_material.albedo_color = Color(0.3,0.9,0.7,0.45)
	preview_style(ghost)
	if piece_kind in PlotState.WALL_TYPES: ghost.scale.x = 1.98/2.01
	add_child(ghost)
	ghost.hide()
func select_piece(kind: String):
	if not player_in_home_area():message("Please visit your home");return
	if player.seated: message("Stand up before building."); return
	if moving_stash: cancel_stash_move()
	piece_kind = kind
	if kind in ["foundation","stairs","railing","workbench","bed"]: build_level=0
	create_preview()
func player_overlap(kind: String, cell: Vector2i, side: int, level := 0) -> bool:
	if kind in ["workbench","lantern","bed"]: return furniture_player_overlap(kind,cell,side,level)
	if kind == "railing": return railing_occupied(cell,side)
	if kind == "stairs": return stair_occupied(cell,side)
	if kind in PlotState.ROOF_TYPES:
		var local = player.position-ceiling_position(cell,level)
		return abs(local.x)<1.35 and abs(local.z)<1.35 and local.y<(1.1 if kind != "ceiling" else 0.18) and local.y+1.8>0
	var local = player.position - (cell_position(cell) if kind == "foundation" else wall_position(cell,side,level))
	if kind == "foundation": return abs(local.x)<1.35 and abs(local.z)<1.35 and local.y < 0.5
	local = local.rotated(Vector3.UP,side*PI/2)
	# Block all placement around the character, even the door opening, to avoid trapping it.
	return abs(local.x)<1.32 and abs(local.z)<0.52 and local.y < 3.0 and local.y > -1.8
func update_target_outline():
	if not is_instance_valid(target_outline):
		target_outline=Node3D.new()
		add_child(target_outline)
		var ink=StandardMaterial3D.new()
		ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color=Color("e9d99a")
		for axis in [0,1]:
			for side in [-1,1]:
				var line=box(target_outline,Vector3(side*.98,0,0) if axis==0 else Vector3(0,0,side*.98),Vector3(.025,.012,1.98) if axis==0 else Vector3(1.98,.012,.025),ink)
				line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		target_edge=box(target_outline,Vector3.ZERO,Vector3(1.98,.018,.075),ink)
		target_edge.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target_outline.position=cell_position(selected)+Vector3(0,.20 if build_level==0 and piece_kind!="railing" else 3.38,0)
	target_outline.show()
	target_edge.visible=piece_kind in PlotState.WALL_TYPES or piece_kind in ["door","railing"]
	target_edge.position=Vector3(0,.012,-.96).rotated(Vector3.UP,-build_rotation*PI/2)
	target_edge.rotation.y=-build_rotation*PI/2
func update_build_target(for_removal := false):
	if is_instance_valid(target_outline): target_outline.hide()
	if moving_stash:
		snap_context=""
		update_stash_target()
		return
	has_build_target = false
	selection_valid = false
	wall_under_aim = {}
	door_under_aim = false
	ceiling_under_aim = false
	stairs_under_aim = false
	railing_under_aim = {}
	furniture_under_aim = {}
	aim_level=0
	ghost.hide()
	var from = player.camera.global_position
	var direction = -player.camera.global_basis.z
	var query = PhysicsRayQueryParameters3D.create(from,from+direction*12)
	query.exclude = [player.get_rid()]
	var prior_snap_context=snap_context
	snap_context=""
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if hit and is_instance_valid(hit.get("collider")) and hit.collider.has_meta("build_cell"):
		selected = hit.collider.get_meta("build_cell")
		aim_level=int(hit.collider.get_meta("build_level",0))
		ceiling_under_aim = hit.collider.has_meta("build_ceiling")
		# Extend only the selected ceiling level from a physical slab side face.
		# Right-click always retains the actual hit cell, never the placement neighbor.
		if piece_kind in PlotState.ROOF_TYPES and ceiling_under_aim and not hit.collider.has_meta("roof_kind") and aim_level == build_level and not for_removal:
			selected = BuildSnap.ceiling_neighbor(selected,hit.normal)
		stairs_under_aim = hit.collider.has_meta("build_stairs")
		if hit.collider.has_meta("build_railing"): railing_under_aim=hit.collider.get_meta("build_railing")
		if hit.collider.has_meta("build_furniture"): furniture_under_aim=hit.collider.get_meta("build_furniture")
		has_build_target = true
		if hit.collider.has_meta("build_wall"):
			wall_under_aim = hit.collider.get_meta("build_wall")
			door_under_aim = hit.collider.has_meta("build_door")
			if piece_kind == "door": build_rotation = wall_under_aim.rotation
	elif not piece_kind in ["railing","workbench","lantern","bed"] and build_level==0 and direction.y < -0.03:
		var distance = (PlotLayout.BUILD_PLANE_Y-from.y)/direction.y
		if distance > 0 and distance < 12:
			var point = PlotLayout.to_local(from+direction*distance)
			var context="%s:%d:%d" % [piece_kind,build_rotation,build_level]
			var raw=BuildSnap.cell_at(point,Vector2i.ZERO,false)
			selected=BuildSnap.cell_at(point,snap_cell,prior_snap_context==context and state.allowed(snap_cell) and state.allowed(raw))
			snap_cell=selected
			snap_context=context
			has_build_target = true
	if not has_build_target:
		selection_reason = "Look at your plot or a placed piece."
		return
	if piece_kind == "railing" and ((not ceiling_under_aim and railing_under_aim.is_empty()) or aim_level!=0):
		has_build_target=false
		selection_reason="Aim directly at a ceiling tile or deck railing."
		return
	if piece_kind in ["workbench","lantern","bed"] and (not wall_under_aim.is_empty() or stairs_under_aim or not railing_under_aim.is_empty()):
		has_build_target=false;selection_reason="Aim directly at a supported floor tile or furnishing.";return
	if piece_kind in ["workbench","lantern","bed"] and ((build_level==0 and (ceiling_under_aim or aim_level!=0)) or (build_level==1 and ceiling_under_aim and aim_level!=0)):
		has_build_target=false;selection_reason="Aim at the floor for the selected furnishing level.";return
	if piece_kind == "door" and wall_under_aim.is_empty() and not ceiling_under_aim:
		has_build_target = false
		selection_reason = "Aim directly at an existing doorframe."
		return
	if build_level==1:
		var upper_hit=(ceiling_under_aim and aim_level in [0,1]) or (not wall_under_aim.is_empty() and aim_level==1) or (not furniture_under_aim.is_empty() and aim_level==1)
		if not upper_hit:
			has_build_target=false
			selection_reason="Upper floor: aim directly at a deck tile or upper piece."
			return
		if piece_kind=="door" and (wall_under_aim.is_empty() or aim_level!=1):
			has_build_target=false
			selection_reason="Aim directly at an upper doorframe."
			return
	elif piece_kind=="door" and not wall_under_aim.is_empty() and aim_level!=0:
		has_build_target=false
		selection_reason="Select Upper floor for this doorframe."
		return
	selection_reason = state.placement_error(piece_kind,selected,build_rotation,build_level)
	if selection_reason.is_empty() and piece_kind in ["workbench","lantern"]:
		var action="build_bench" if piece_kind=="workbench" else "place_lantern"
		if crafting_service.candidate(action,state,inventory,request,craft,selected,build_rotation,build_level).is_empty(): selection_reason=crafting_service.last_error
		elif not furniture_clear(piece_kind,selected,build_rotation,build_level): selection_reason="Furniture or its approach is obstructed."
	if selection_reason.is_empty() and piece_kind=="bed" and not furniture_clear("bed",selected,build_rotation,build_level): selection_reason="Bed or its side access is obstructed."
	if selection_reason.is_empty() and piece_kind in PlotState.WALL_TYPES and not structure_furniture_clear(piece_kind,selected,build_rotation,build_level): selection_reason="Remove the furnishing from this wall space first."
	if selection_reason.is_empty() and player_overlap(piece_kind,selected,build_rotation,build_level): selection_reason = "Step clear of the target piece."
	if selection_reason.is_empty() and piece_kind in ["pitched_roof","canvas_awning"] and not home_roof_clear(piece_kind,selected,build_rotation,build_level): selection_reason = "Roof space is obstructed or outside the plot envelope."
	if selection_reason.is_empty() and piece_kind == "ceiling" and not ceiling_clear(selected,build_level): selection_reason = "Ceiling space is obstructed."
	if selection_reason.is_empty() and piece_kind == "stairs" and not stair_clear(selected,build_rotation): selection_reason="Stair route or headroom is obstructed."
	if selection_reason.is_empty() and piece_kind == "railing" and not railing_clear(selected,build_rotation): selection_reason="Railing space is obstructed."
	if selection_reason.is_empty() and build_level==1 and piece_kind in PlotState.WALL_TYPES and not upper_wall_clear(piece_kind,selected,build_rotation): selection_reason="Upper wall space is obstructed."
	selection_valid = selection_reason.is_empty()
	ghost.show()
	if state.allowed(selected): update_target_outline()
	ghost.position = furniture_origin(piece_kind,selected,build_rotation,build_level) if piece_kind in ["workbench","lantern","bed"] else railing_position(selected,build_rotation) if piece_kind == "railing" else stair_position(selected) if piece_kind == "stairs" else ceiling_position(selected,build_level) if piece_kind in PlotState.ROOF_TYPES else (cell_position(selected) if piece_kind == "foundation" else wall_position(selected,build_rotation,build_level))
	ghost.rotation.y = 0 if piece_kind == "foundation" else -build_rotation*PI/2
	ghost_material.albedo_color = Color(0.3,0.9,0.7,0.45) if selection_valid else Color(0.95,0.25,0.12,0.40)
func _process(delta):
	vendor_prompt_active = false
	if not world_initialized: return
	if fishing_trader_restore!=0:_restore_fishing_trader_detach(fishing_trader_restore)
	if not moving_stash and (build_mode or (is_instance_valid(build_wheel) and build_wheel.visible)) and not player_in_home_area():cancel_home_build()
	elapsed += delta
	advance_craft(delta)
	advance_fishing(delta)
	notice_time -= delta
	if notice_time <= 0: notice.text = ""
	update_control_labels()
	hud.text = "YOUR HOME  %s   /   %d credits   /   %d foundations • %d walls" % ["12 × 12 m" if state.expanded else "8 × 8 m",state.credits,state.cells.size(),state.walls.size()]
	hud.text += "\n" + onboarding_hint()
	selection_valid = false
	ghost.hide()
	if is_instance_valid(target_outline): target_outline.hide()
	if not build_mode or modal_open(): snap_context=""
	for label in wayfinding_labels: label.visible = not build_mode and not modal_open() and not label.get_meta("hide_service_caption",false)
	if is_instance_valid(clothing_panel) and clothing_panel.visible:
		if not tailor_shop_access():close_clothing()
		elif not tailoring_transactions.pending_quote().is_empty() and not tailoring_transactions.current(state,inventory,request,tailor_shop_context()):tailor_shop_cancel()
	if supplies_panel.visible:
		if not supplies_accessible():close_supplies()
		elif supplies_token!=0 and not supplies_transaction.current(state,inventory,request,supplies_context()):cancel_supply("Your inventory, balance or progress changed. Review again.")
	if workbench_panel.visible and not workbench_accessible():
		pending_craft=false;workbench_panel.render(craft,inventory,pending_craft,craft_paused,"Move back to the front of the workbench.")
	if fishing_session.active():
		prompt.text=fishing_session.hint(key_label("interact"))
		prompt_panel.show();layout_status_panel()
		return
	if modal_open():
		if build_wheel.visible:
			prompt.text=build_menu_help()
			prompt_panel.show();layout_status_panel()
		else:
			prompt.text="";prompt_panel.hide()
		return
	if player.seated:
		prompt.text = "E  Stand up"
	elif build_mode:
		update_build_target()
		var facing = ["North","East","South","West"][build_rotation]
		prompt.text = "BUILD • %s • %s %d°\n%s Piece wheel / Exit build • R Rotate\n%s" % [PIECE_NAMES[piece_kind],facing,build_rotation*90,key_label("build"),"Left click place • Right click remove" if selection_valid else selection_reason]
		prompt.text += "\nFloor: %s • PageUp/Down: Ground / Upper" % ("Upper" if build_level==1 else "Ground")
		if piece_kind=="workbench": prompt.text += "\nCost: 2 carried Timber + 1 Metal • Click places and spends • Idle pickup refunds"
		elif piece_kind=="bed": prompt.text += "\nFree cosmetic bed (prototype) • No sleep/heal/respawn • Right click removes"
		elif piece_kind=="lantern": prompt.text += "\nCost: 1 carried lantern kit • Right click picks up into carried"
		if not railing_under_aim.is_empty() or piece_kind == "railing": prompt.text += "\nAim ceiling tile • exposed edges only • Right click: remove railing"
		elif piece_kind in ["pitched_roof","canvas_awning"]: prompt.text += "\nTerminal cover • %s: rotate slope • not an upper-floor deck • free during testing" % key_label("rotate")
		elif piece_kind == "ceiling": prompt.text += ("\nSupported deck + wall/neighbor roof support • aim roof to remove" if build_level==1 else "\nFoundation + wall/neighbor ceiling support • aim tile/cell to remove")
		elif ceiling_under_aim: prompt.text += "\nRight click: remove ceiling"
		elif not wall_under_aim.is_empty(): prompt.text += "\nRight click: remove " + ("door leaf" if door_under_aim or piece_kind == "door" else PIECE_NAMES[wall_under_aim.type].to_lower())
		if moving_stash:
			prompt.text = "MOVE HOME STASH • Contents stay safely in storage\n%s Rotate • Left click confirm • Right click / Esc cancel\n%s" % [key_label("rotate"), "Valid ground foundation" if selection_valid else selection_reason]
		elif can_move_home_stash() and aimed_stash(): prompt.text += "\nOpen Home Stash → Move"
	elif not aimed_door().is_empty():
		prompt.text = "E  %s door" % ("Close" if aimed_door().open else "Open")
	elif workbench_accessible():
		prompt.text = "E  Workbench • Craft a warm lantern"
	elif not aimed_furniture("lantern").is_empty():
		prompt.text = "E  Toggle lantern light"
	elif stash_accessible():
		prompt.text = "E  Open Home Stash • Store / withdraw materials"
		if can_move_home_stash() and aimed_stash(): prompt.text += "\nOpen Home Stash → Move"
	elif player.position.distance_to(BOARD) < 2.8:
		prompt.text = "E  Request board • One-time courtyard repairs"
	elif can_use_steward():
		vendor_prompt_active = true
		prompt.text = "E  Talk to Mara • Plot upgrades" if preload("res://scripts/vendor_prompt_layout.gd").near_counter(player.global_position,VENDOR) else ""
	elif is_instance_valid(trader_previews) and not trader_previews.nearest().is_empty():
		vendor_prompt_active=true
		prompt.text=trader_previews.prompt_text()
	elif tailor_accessible():
		vendor_prompt_active = true
		prompt.text = key_label("interact")+"  Tailor & Dyes • Clothing, craft and color"
	elif supplies_accessible():
		vendor_prompt_active = true
		prompt.text = "E  Rook’s supplies • Buy / Sell materials" if preload("res://scripts/vendor_prompt_layout.gd").near_counter(player.global_position,SUPPLIES_COUNTER) else ""
	elif is_instance_valid(cooking_test) and cooking_test.vendor_accessible():
		vendor_prompt_active = true
		prompt.text = key_label("interact")+"  Trade cooking supplies" if preload("res://scripts/vendor_prompt_layout.gd").near_counter(player.global_position,Vector3(-5.8,1.3,2)) else ""
	elif Seats.target(self,player) != null: prompt.text = "E  Sit"
	elif fishing_accessible():
		prompt.text="E  Cast selected fishing pole • Northern stream" if fishing_rod_selected() else "Carry a fishing pole • Assign and select its quick-access slot"
	elif is_instance_valid(cooking_test) and cooking_test.accessible():
		prompt.text=key_label("interact")+"  Use griddle • Prepare ordinary fish"
	elif is_instance_valid(fishing_trader) and fishing_trader.accessible():
		prompt.text=key_label("interact")+"  Fishing supplies • Buy a fishing pole"
	else: prompt.text = ""
	if prompt.text.begins_with("E  "): prompt.text = key_label("interact") + prompt.text.substr(1)
	prompt.text = prompt.text.replace("• R Rotate", "• " + key_label("rotate") + " Rotate")
	prompt_panel.visible = not prompt.text.is_empty() and (not build_mode or moving_stash)
	layout_status_panel()

func layout_status_panel():
	if not is_instance_valid(prompt_panel): return
	prompt_panel.z_index = 0
	if is_instance_valid(build_wheel) and build_wheel.visible:
		# Keep help in the clear side gutter, above the modal dimmer and outside
		# the wheel. The previous 700 px bottom-left panel crossed its sectors.
		prompt_panel.z_index = 1
		prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var width = minf(340, maxf(160, build_wheel.center.x-build_wheel.radius-40))
		var font = prompt.get_theme_font("font")
		var font_size = prompt.get_theme_font_size("font_size")
		var height = maxf(70, font.get_multiline_string_size(prompt.text,HORIZONTAL_ALIGNMENT_LEFT,width-28,font_size).y+28)
		prompt_panel.offset_left = 20
		prompt_panel.offset_right = 20+width
		# Keep longer cost help clear of actual bottom controls on short viewports.
		var top = maxf(20, minf((hud_root.size.y-height)/2, controls.get_global_rect().position.y-12-height))
		prompt_panel.offset_top = top-hud_root.size.y/2
		prompt_panel.offset_bottom = prompt_panel.offset_top+height
	else:
		# All nonmodal ActionStatus hints stay above the action bar, never the reticle.
		preload("res://scripts/vendor_prompt_layout.gd").apply(self)

func _unhandled_input(event):
	if not world_initialized: return
	if is_instance_valid(trader_previews) and trader_previews.consume(event):return
	if is_instance_valid(fishing_trader) and fishing_trader.consume(event):return
	if is_instance_valid(cooking_test) and cooking_test.consume(event):return
	if event is InputEventKey and event.pressed and not event.echo:
		if fishing_session.active():
			if event.is_action_pressed("interact"):
				fishing_session.retrieve()
				get_viewport().set_input_as_handled();return
			# Menu/load/movement/fixed shortcuts cancel before existing dispatch.
			var cancel_key=event.physical_keycode if event.physical_keycode!=0 else event.keycode
			if cancel_key==KEY_ESCAPE:
				cancel_fishing("Cast cancelled. Nothing was spent.");get_viewport().set_input_as_handled();return
			cancel_fishing("Cast cancelled before changing controls or opening a menu.")
		# Resolve the new action before legacy canonical-key translation. A prior
		# custom L binding is never shadowed by a hard-coded KEY_L case.
		if event.is_action_pressed("skills"):
			if is_instance_valid(skills_panel) and skills_panel.visible:close_skills()
			else:open_skills()
			if is_inside_tree():get_viewport().set_input_as_handled()
			return
		if is_instance_valid(skills_panel) and skills_panel.visible:
			if event.physical_keycode==KEY_ESCAPE or event.keycode==KEY_ESCAPE:close_skills()
			if is_inside_tree():get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("quests"):
			if is_instance_valid(quest_journal) and quest_journal.visible:close_quests()
			else:open_quests()
			if is_inside_tree():get_viewport().set_input_as_handled()
			return
		if is_instance_valid(quest_journal) and quest_journal.visible:
			if event.physical_keycode==KEY_ESCAPE or event.keycode==KEY_ESCAPE:close_quests()
			if is_inside_tree():get_viewport().set_input_as_handled()
			return
		# Some native/remote navigation events carry only the logical PageUp/Down code.
		# Keep all other bindings physical; this fallback is only the floor selector.
		var binding_code = event.physical_keycode
		if binding_code == 0 and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
			binding_code = event.keycode
		# Translate rebindable actions to the existing dispatch; fixed shortcuts remain fixed.
		var action_keys={"interact":KEY_E,"inventory":KEY_I,"view":KEY_V,"build":KEY_B,"rotate":KEY_R,"map":KEY_M}
		for action in action_keys:
			if event.is_action_pressed(action):
				binding_code=action_keys[action]
				break
		# Old physical keys must not continue triggering rebound actions.
		if binding_code in action_keys.values():
			var matched=false
			for action in action_keys:
				if action_keys[action]==binding_code and event.is_action_pressed(action):matched=true
			if not matched:return
		# Quick access outside building; existing building number keys retain priority.
		if binding_code>=KEY_1 and binding_code<KEY_1+quickbar.SLOT_COUNT and not build_mode and not modal_open():
			activate_quickbar(binding_code-KEY_1)
			return
		match binding_code:
			KEY_ESCAPE:
				if moving_stash: cancel_stash_move()
				elif is_instance_valid(settlement_hud) and settlement_hud.full.visible: close_map()
				elif build_wheel.visible: close_build_wheel()
				elif inventory_panel.visible: close_inventory()
				elif dialog.visible: close_dialog()
				elif is_instance_valid(clothing_panel) and clothing_panel.visible: close_clothing()
				elif request_panel.visible: close_request_board()
				elif supplies_panel.visible: close_supplies()
				elif workbench_panel.visible: close_workbench()
				elif options_panel.visible: options_panel.cancel_and_close()
				else: open_options()
			KEY_M:
				if is_instance_valid(settlement_hud) and settlement_hud.full.visible: close_map()
				elif not modal_open(): open_map()
			KEY_I:
				if inventory_panel.visible: close_inventory()
				elif not modal_open(): open_inventory(false)
			KEY_V: if not modal_open(): player.toggle_view()
			KEY_B:
				if build_wheel.visible:close_build_wheel()
				elif not modal_open(): open_build_wheel()
			KEY_1: if not modal_open(): select_piece("foundation")
			KEY_2: if not modal_open(): select_piece("wall")
			KEY_3: if not modal_open(): select_piece("window_wall")
			KEY_4: if not modal_open(): select_piece("doorframe")
			KEY_5: if not modal_open(): select_piece("door")
			KEY_6: if not modal_open(): select_piece("ceiling")
			KEY_7: if not modal_open(): select_piece("stairs")
			KEY_8: if not modal_open(): select_piece("railing")
			KEY_9: if not modal_open(): select_piece("workbench")
			KEY_0: if not modal_open(): select_piece("lantern")
			KEY_PAGEUP, KEY_PAGEDOWN:
				if build_mode and not modal_open() and not moving_stash:
					build_level=1 if binding_code==KEY_PAGEUP else 0
					if build_level==1 and piece_kind in ["foundation","stairs","railing","workbench","bed"]: select_piece("wall")
			KEY_R: if not modal_open(): build_rotation = (build_rotation+1)%4
			KEY_E:
				if not modal_open():
					if player.seated:
						if not player.try_stand_from_seat(): message("No clear place to stand. Move the obstruction first.")
					elif not build_mode and not aimed_door().is_empty():
						if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: toggle_aimed_door()
					elif not build_mode and workbench_accessible(): open_workbench()
					elif not build_mode and not aimed_furniture("lantern").is_empty(): toggle_lantern()
					elif stash_accessible(): open_inventory(true)
					elif not build_mode and player.position.distance_to(BOARD)<2.8: open_request_board()
					elif can_use_steward(): open_dialog()
					elif not build_mode and is_instance_valid(trader_previews) and not trader_previews.nearest().is_empty():trader_previews.open(trader_previews.nearest())
					elif not build_mode and tailor_accessible(): open_clothing()
					elif not build_mode and supplies_accessible(): open_supplies()
					elif not build_mode and is_instance_valid(cooking_test) and cooking_test.vendor_accessible(): cooking_test.open_vendor()
					elif not build_mode and Seats.target(self,player) != null:
						if not Seats.sit(player,Seats.target(self,player)): message("Move to the clear front of the seat to sit.")
					elif not build_mode and fishing_accessible():start_fishing()
					elif is_instance_valid(cooking_test) and cooking_test.accessible():cooking_test.open()
					elif is_instance_valid(fishing_trader) and fishing_trader.accessible():fishing_trader.open()
			KEY_F5: if not options_panel.visible and not build_wheel.visible and not settlement_hud.full.visible: save_game()
			KEY_F9: if not options_panel.visible and not build_wheel.visible and not settlement_hud.full.visible: load_game()
	if event is InputEventMouseButton and event.pressed and not modal_open():
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		build_action(event.button_index)
func build_action(button: MouseButton, writer_override = null):
	if moving_stash and not modal_open():
		if button == MOUSE_BUTTON_RIGHT: cancel_stash_move()
		elif button == MOUSE_BUTTON_LEFT:
			update_stash_target()
			if selection_valid: commit_stash_move(selected,build_rotation,writer_override)
			else: message(selection_reason)
		return
	if not build_mode or modal_open(): return
	if not player_in_home_area():cancel_home_build();return
	# Re-resolve at click time; never act on last frame's aim after a picker/mouse change.
	update_build_target(button == MOUSE_BUTTON_RIGHT)
	if not has_build_target: return
	if button == MOUSE_BUTTON_LEFT:
		if not selection_valid:
			message(selection_reason)
			return
		if piece_kind in ["workbench","lantern"]:
			commit_crafting("build_bench" if piece_kind=="workbench" else "place_lantern",selected,build_rotation,build_level,writer_override,true)
			return
		var candidate = plot_candidate()
		if candidate == null: return
		if candidate.place_piece(piece_kind,selected,build_rotation,build_level):
			publish_plot_candidate(candidate,PIECE_NAMES[piece_kind]+" placed • saved",writer_override)
		else: message(candidate.last_error)
	elif button == MOUSE_BUTTON_RIGHT:
		if aimed_stash(): message("Home Stash cannot be removed. Use Move Home Stash.");return
		if not furniture_under_aim.is_empty():
			var record=aimed_furniture(furniture_under_aim.kind)
			if record.is_empty(): message("Move closer to pick up the furnishing.");return
			if furniture_player_overlap(record.kind,record.cell,record.rotation,record.level,state.workbench if record.kind=="workbench" else {}): message("Step clear before picking up furniture.");return
			if record.kind=="bed":
				var bed_candidate=plot_candidate()
				if bed_candidate!=null and bed_candidate.remove_bed(): publish_plot_candidate(bed_candidate,"Starter bed removed • no materials refunded • saved",writer_override)
				return
			commit_crafting("remove_bench" if record.kind=="workbench" else "pickup_lantern",record.cell,record.rotation,record.level,writer_override,true)
			return
		var candidate = plot_candidate()
		if candidate == null: return
		var removed = false
		if not railing_under_aim.is_empty() or piece_kind == "railing":
			var rail_cell=railing_under_aim.get("cell",selected)
			var rail_side=railing_under_aim.get("rotation",build_rotation)
			removed=candidate.remove_railing(rail_cell,rail_side)
		elif stairs_under_aim or piece_kind == "stairs":
			var index=state.stair_index(selected)
			if index>=0 and stair_occupied(state.stairs[index].cell,state.stairs[index].rotation): message("Step off the stairs before removing them.");return
			removed=candidate.remove_stair(selected)
		elif piece_kind in PlotState.ROOF_TYPES or ceiling_under_aim:
			if ceiling_occupied(selected,aim_level) or (state.ceiling_index(selected,aim_level)>=0 and state.ceilings[state.ceiling_index(selected,aim_level)].has("roof_kind") and player_overlap(state.ceilings[state.ceiling_index(selected,aim_level)].roof_kind,selected,build_rotation,aim_level)): message("Step off the ceiling before removing it.");return
			removed = candidate.remove_ceiling(selected,aim_level)
		elif not wall_under_aim.is_empty():
			removed = candidate.remove_door(wall_under_aim.cell,wall_under_aim.rotation,wall_under_aim.get("level",0)) if door_under_aim or piece_kind == "door" else candidate.remove_wall(wall_under_aim.cell,wall_under_aim.rotation,wall_under_aim.get("level",0))
		elif piece_kind == "foundation": removed = candidate.remove(selected)
		else: removed = candidate.remove_wall(selected,build_rotation,build_level)
		if removed: publish_plot_candidate(candidate,"Piece removed • saved",writer_override)
		else: message(candidate.last_error)

func plot_candidate() -> RefCounted:
	var candidate = PlotState.new()
	if not candidate.restore(state.data()):
		message("Building action blocked: current plot state is invalid.")
		return null
	return candidate
func publish_plot_candidate(candidate, success_notice: String, writer_override = null, next_onboarding = null) -> bool:
	# Plot and onboarding transition commit together before either live state changes.
	if next_onboarding == null: next_onboarding = onboarding_candidate(candidate)
	if next_onboarding == null: return false
	if not save_payload(SaveCodec.encode(candidate,inventory,request,craft,next_onboarding,fishing),false,writer_override): return false
	state = candidate
	onboarding = next_onboarding
	refresh_plot()
	message(success_notice)
	return true

func can_use_steward() -> bool:
	if player.position.distance_to(VENDOR)>=4: return false
	# Radius remains4m, but enclosing architecture must not permit through-wall service.
	if abs(player.position.x)>8.4 or player.position.z> -14.1 or player.position.z< -31.4: return false
	var query=PhysicsRayQueryParameters3D.create(player.position+Vector3(0,1.55,0),Vector3(5.5,1.95,-29.1))
	query.exclude=[player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func open_dialog():
	if moving_stash: cancel_stash_move()
	if not can_use_steward(): return
	build_mode = false
	dialog.show()
	player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	update_dialog()
func update_dialog():
	dialog_text.text = "Your home starts here. Build freely within your marked plot.\n\n" + ("Your expansion is complete: 12 × 12 metres. Ground and upper rooms are available; the stair landing remains an open terrace." if state.expanded else "Expand your 8 × 8 metre plot to 12 × 12 metres for 100 credits. This prototype starts with 150 test credits.")
	dialog_text.text += "\n\nYOUR PLOT  %s  •  %d credits\n%d foundations  •  %d walls\n%s" % ["12 × 12 m" if state.expanded else "8 × 8 m",state.credits,state.cells.size(),state.walls.size(),onboarding_hint()]
	upgrade_button.disabled = state.expanded or state.credits < 100
	upgrade_button.text = "Expansion complete" if state.expanded else "Expand plot • 100 settlement credits"
func close_dialog():
	dialog.hide()
	player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func upgrade_plot(writer_override = null) -> bool:
	var candidate = plot_candidate()
	var success := false
	if candidate != null and candidate.upgrade():
		success = publish_plot_candidate(candidate,"Plot expanded to 12 × 12 m • saved",writer_override)
	update_dialog()
	return success

func message(value: String):
	notice.text = value
	notice_time = 5
func modal_open(include_cooking:bool=true,include_fishing_trader:bool=true,include_preview_traders:bool=true) -> bool:
	return (include_preview_traders and is_instance_valid(trader_previews) and trader_previews.is_open()) or (include_fishing_trader and is_instance_valid(fishing_trader) and fishing_trader.is_open()) or (include_cooking and is_instance_valid(cooking_test) and cooking_test.is_open()) or (is_instance_valid(skills_panel) and skills_panel.visible) or fishing_session.active() or (is_instance_valid(quest_journal) and quest_journal.visible) or (is_instance_valid(clothing_panel) and clothing_panel.visible) or (is_instance_valid(settlement_hud) and settlement_hud.full.visible) or (is_instance_valid(build_wheel) and build_wheel.visible) or (is_instance_valid(options_panel) and options_panel.visible) or dialog.visible or inventory_panel.visible or request_panel.visible or supplies_panel.visible or (is_instance_valid(workbench_panel) and workbench_panel.visible)
func open_inventory(with_stash := false):
	cancel_fishing("")
	if modal_open(): return
	if with_stash and not stash_accessible(): return
	if moving_stash: cancel_stash_move()
	stash_panel_source = state.home_stash.duplicate(true) if with_stash else {}
	build_mode = false
	ghost.hide()
	player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	inventory_panel.destination = "stash" if with_stash else "lockbox"
	render_inventory(inventory,with_stash)
	inventory_panel.show()
func close_inventory():
	inventory_panel.hide()
	player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func transfer_inventory(source: String, destination: String, item: String, amount: Variant, writer_override = null, slot_index: Variant = -1) -> bool:
	if not equipment_intent_current(inventory_panel.generation):return false
	var stash_move = source == "stash" or destination == "stash"
	if stash_move and not inventory_panel.access_stash: return false
	if stash_move and (not stash_accessible() or stash_panel_source != state.home_stash):
		render_inventory(inventory,true,"Too far from Home Stash. Close this panel and move closer.")
		return false
	# Destination comes from the actual drop target; click shortcut mode is not authorization.
	var candidate = inventory.transfer_candidate(source,destination,item,amount,slot_index)
	if candidate == null:
		render_inventory(inventory,inventory_panel.access_stash,inventory.last_error)
		return false
	if not save_payload(SaveCodec.encode(state,candidate,request,craft,onboarding,fishing),false,writer_override):
		render_inventory(inventory,inventory_panel.access_stash,notice.text)
		return false
	inventory = candidate
	render_inventory(inventory,inventory_panel.access_stash,"Transferred • saved locally")
	return true
func save_game(show_notice := true) -> bool:
	var next = onboarding_candidate(state)
	if next == null or not save_payload(SaveCodec.encode(state,inventory,request,craft,next,fishing),show_notice): return false
	onboarding = next
	return true
func parse_save_bytes(bytes: String) -> Variant:
	var parser = JSON.new()
	if parser.parse(bytes) != OK: return null
	return parser.data
func save_payload(payload: Dictionary, show_notice := true, writer_override = null) -> bool:
	if character_save_path.is_empty(): return false
	if fishing_session.active():cancel_fishing("Cast cancelled before another action was saved.")
	if staged_startup and not world_initialized: return false
	# Validate the entire proposed envelope before touching backups, temp files or live state.
	if SaveCodec.decode(payload).is_empty():
		message("Save blocked: proposed state is invalid. Nothing changed.")
		return false
	if FileAccess.file_exists(character_save_path):
		var previous = parse_save_bytes(FileAccess.get_file_as_string(character_save_path))
		if SaveCodec.decode(previous).is_empty():
			message("Save blocked: existing save is invalid. Close the game and preserve or restore it before continuing.")
			return false
		if int(previous.version)>=22 and int(payload.version)<int(previous.version):
			message("Save blocked: automatic downgrade is not supported.")
			return false
		if int(previous.version) in [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20] or (int(previous.version)>=21 and int(payload.version)>int(previous.version)):
			var backup_path = character_save_path+".v%d-backup" % int(previous.version)
			if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(backup_path)):
				message("Save failed: legacy backup path is a folder. Previous save unchanged.")
				return false
			if FileAccess.file_exists(backup_path) and FileAccess.get_file_as_bytes(backup_path)!=FileAccess.get_file_as_bytes(character_save_path):
				message("Save blocked: existing legacy backup differs from this save. Preserve both files before retrying; nothing was overwritten.")
				return false
			if not FileAccess.file_exists(backup_path):
				var err = DirAccess.copy_absolute(ProjectSettings.globalize_path(character_save_path),ProjectSettings.globalize_path(backup_path))
				if err != OK or FileAccess.get_file_as_bytes(backup_path)!=FileAccess.get_file_as_bytes(character_save_path):
					message("Save failed: could not preserve the exact legacy backup. Previous save unchanged.")
					return false
	var file = writer_override if writer_override != null else FileAccess.open(character_save_path+".tmp",FileAccess.WRITE)
	if not file: message("Save failed: cannot open local save."); return false
	return commit_save(file,character_save_path,show_notice,payload)
func commit_save(file, target: String, show_notice := true, payload = null) -> bool:
	if character_save_path.is_empty() or target != character_save_path:
		if file != null: file.close()
		message("Save refused: character target changed. Previous save preserved.")
		return false
	var encoded=JSON.stringify(SaveCodec.encode(state,inventory,request,craft,onboarding,fishing) if payload == null else payload)
	file.store_string(encoded)
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK:
		message("Save failed: disk write incomplete. Previous save preserved.")
		return false
	# A successful flush alone is not proof that the staged file contains the
	# complete proposed save. Verify exact bytes before replacing live progress.
	if not FileAccess.file_exists(target+".tmp") or FileAccess.get_file_as_bytes(target+".tmp") != encoded.to_utf8_buffer():
		message("Save failed: staged data could not be verified. Previous save preserved.")
		return false
	var err = DirAccess.rename_absolute(ProjectSettings.globalize_path(target+".tmp"),ProjectSettings.globalize_path(target))
	if err != OK: message("Save failed: could not commit local save."); return false
	if show_notice: message("Hideout saved locally")
	return true
func load_game(show_notice := true) -> bool:
	tailoring_transactions.cancel()
	if is_instance_valid(clothing_panel) and clothing_panel.visible:close_clothing()
	if is_instance_valid(cooking_test):cooking_test.close()
	if is_instance_valid(trader_previews):trader_previews.close()
	if character_save_path.is_empty(): return false
	if is_instance_valid(fishing_trader):fishing_trader.close()
	cancel_fishing("")
	if player != null and player.seated and not player.try_stand_from_seat(): message("Cannot load while the seat exit is blocked."); return false
	if moving_stash: cancel_stash_move()
	pending_craft=false
	if is_instance_valid(supplies_panel) and supplies_panel.visible: cancel_supply("Load requested. Trade selection cleared.")
	if not FileAccess.file_exists(character_save_path):
		if show_notice: message("No saved hideout yet.")
		return false
	var file = FileAccess.open(character_save_path,FileAccess.READ)
	if not file: message("Could not read save. Current hideout preserved."); return false
	var candidate = SaveCodec.decode(parse_save_bytes(file.get_as_text()))
	file.close()
	if candidate.is_empty():
		message("Invalid save. Current hideout preserved.")
		return false
	state = candidate.plot
	inventory = candidate.inventory
	request = candidate.request
	craft = candidate.craft
	onboarding = candidate.onboarding
	fishing = candidate.fishing
	craft_accumulator=0.0;craft_paused=false
	refresh_plot()
	if supplies_panel.visible: cancel_supply("Hideout loaded. Review a new trade.")
	if request_panel.visible:
		request_panel.render(request,inventory,"Hideout loaded")
		if is_instance_valid(clothing_accept):refresh_clothing_board()
		refresh_fishing_board()
	if is_instance_valid(clothing_panel) and clothing_panel.visible:
		tailoring_transactions.cancel()
		clothing_panel.render(inventory,onboarding,"Hideout loaded. Draft discarded.",state)
	if dialog.visible: update_dialog()
	if inventory_panel.visible: render_inventory(inventory,inventory_panel.access_stash,"Hideout loaded")
	if workbench_panel.visible: workbench_panel.render(craft,inventory,false,false,"Hideout loaded. Review a new action.")
	if show_notice: message("Hideout loaded")
	return true
func smoke():
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(player.camera.current)
	assert(pieces != null and boundary.get_child_count() > 0)
	print("SCENE_SMOKE_PASS: world, collision, player camera, plot and UI initialized")
	get_tree().quit()

func open_request_board():
	if modal_open() or build_mode or player.position.distance_to(BOARD) >= 2.8: return
	ghost.hide()
	player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	request_panel.render(request,inventory)
	refresh_clothing_board()
	refresh_fishing_board()
	request_panel.show()
	if not request_panel.action_button.disabled: request_panel.action_button.grab_focus()
	elif not clothing_accept.disabled:clothing_accept.grab_focus()
func close_request_board():
	request_panel.hide()
	player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func request_action(action: String, writer_override = null) -> bool:
	if not request_panel.visible or dialog.visible or inventory_panel.visible or workbench_panel.visible or build_mode: return false
	if player.position.distance_to(BOARD) >= 2.8:
		request_panel.render(request,inventory,"Too far from the board. Return to the settlement and move closer.")
		return false
	var candidate = request.candidate(action,state,inventory)
	if candidate.is_empty():
		request_panel.render(request,inventory,request.last_error)
		return false
	if not save_payload(SaveCodec.encode(candidate.plot,candidate.inventory,candidate.request,craft,onboarding,fishing),false,writer_override):
		request_panel.render(request,inventory,notice.text)
		return false
	state = candidate.plot
	inventory = candidate.inventory
	request = candidate.request
	request_panel.render(request,inventory,"Accepted • saved locally" if action == "accept" else "Delivered • 25 credits received • saved locally")
	return true

func supplies_accessible(_selling := false) -> bool:
	# Both directions belong to Rook. Never trade through a rear wall.
	if not cooking_window_focused or not is_instance_valid(player) or player.seated or moving_stash:return false
	var p=player.global_position
	if not preload("res://scripts/rook_shop.gd").customer_access(p):return false
	var eye=p+Vector3(0,1.3,0)
	if eye.distance_to(SUPPLIES_COUNTER)>2.8:return false
	var query=PhysicsRayQueryParameters3D.create(eye,SUPPLIES_COUNTER)
	query.exclude=[player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func supplies_context() -> Dictionary:
	return {"craft":craft.data(),"onboarding":onboarding.data(),"fishing":fishing.data()}
func supplies_trade_accessible() -> bool:
	if fishing_session.active():return false
	if not is_inside_tree() or is_queued_for_deletion() or not supplies_panel.visible or build_mode or not supplies_accessible():return false
	for panel in [dialog,inventory_panel,request_panel,workbench_panel,options_panel,clothing_panel,skills_panel,quest_journal,build_wheel]:
		if is_instance_valid(panel) and panel.visible:return false
	if is_instance_valid(settlement_hud) and settlement_hud.full.visible:return false
	if is_instance_valid(fishing_trader) and fishing_trader.is_open():return false
	if is_instance_valid(trader_previews) and trader_previews.is_open():return false
	if is_instance_valid(cooking_test) and cooking_test.is_open():return false
	return true
func refresh_supplies(feedback:String=""):
	supplies_panel.selling=selling_materials
	supplies_panel.render(state,inventory,pending_supply,feedback,supplies_transaction.pending_quote())
func open_supplies(selling := false):
	if modal_open() or build_mode or not supplies_accessible():return
	supplies_transaction.cancel();supplies_token=0;pending_supply=""
	selling_materials=selling
	player.enabled=false;player.velocity=Vector3.ZERO
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	refresh_supplies();supplies_panel.show();supplies_panel.close_button.grab_focus()
func close_supplies():
	supplies_transaction.cancel();supplies_token=0;pending_supply=""
	supplies_panel.hide()
	if cooking_window_focused and not modal_open():
		player.enabled=true;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func cancel_supply(feedback := "Selection cancelled. Nothing traded."):
	supplies_transaction.cancel();supplies_token=0;pending_supply=""
	refresh_supplies(feedback)
	if supplies_panel.visible:supplies_panel.close_button.grab_focus()
func change_supply_tab(action:String):
	if not action in ["buy","sell"]:return
	cancel_supply("");selling_materials=action=="sell";refresh_supplies()
func select_supply(item:String,quantity:int=1,action:String="") -> bool:
	if not supplies_trade_accessible() or supplies_token!=0:return false
	var trade_action="sell" if selling_materials else "buy"
	if not action.is_empty() and action!=trade_action:return false
	var quote=supplies_transaction.select("rook",trade_action,item,quantity,state,inventory,request,supplies_context())
	if quote.is_empty():cancel_supply(supplies_transaction.last_error);return false
	supplies_token=quote.token;pending_supply=item
	refresh_supplies()
	# Default focus is Cancel; selection input cannot confirm a purchase.
	supplies_panel.cancel_button.grab_focus()
	return true
func confirm_supply(writer_override = null) -> bool:
	var candidate=supplies_transaction.confirm(supplies_token,state,inventory,request,supplies_trade_accessible,func(next):return save_payload(SaveCodec.encode(next.plot,next.inventory,next.request,craft,onboarding,fishing),false,writer_override),supplies_context())
	supplies_token=0;pending_supply=""
	if candidate.is_empty():cancel_supply(supplies_transaction.last_error);return false
	state=candidate.plot;inventory=candidate.inventory;request=candidate.request
	ApprovedAudio.emit_for(self,"confirm_buy")
	var receipt:Dictionary=candidate.receipt
	cancel_supply("%s %d %s for %d credits · saved locally." % ["Sold" if receipt.action=="sell" else "Bought",receipt.quantity,receipt.name,receipt.total])
	return true

# Furniture uses the same floor support heights as the structural building system.
func furniture_position(cell: Vector2i, level := 0) -> Vector3:
	return cell_position(cell)+Vector3(0,0.18+CEILING_HEIGHT*level,0)
# Fixed, versioned anchor: new benches tuck 10 cm forward; migrated benches never move.
func furniture_origin(kind:String, cell:Vector2i, side:int, level:=0, record:Dictionary={}) -> Vector3:
	var origin=furniture_position(cell,level)
	if kind=="bed": origin+=preload("res://scripts/bed_geometry.gd").OFFSET.rotated(Vector3.UP,-side*PI/2)
	if kind=="workbench" and record.get("anchor","front_inset_v1")=="front_inset_v1":
		origin+=Vector3(0,0,-0.10).rotated(Vector3.UP,-side*PI/2)
	return origin
func create_furniture(kind:String, record:Dictionary):
	var holder=FurnitureGeometry.assembly(kind,true,record)
	holder.position=furniture_origin(kind,record.cell,record.rotation,record.get("level",0),record);holder.rotation.y=-record.rotation*PI/2;pieces.add_child(holder)
func furniture_player_overlap(kind:String, cell:Vector2i, side:int, level:int, record:Dictionary={}) -> bool:
	var local=(player.position-furniture_origin(kind,cell,side,level,record)).rotated(Vector3.UP,side*PI/2)
	for part in FurnitureGeometry.parts(kind):
		var half=part.size*0.5
		if absf(local.x-part.position.x)<half.x+0.32 and absf(local.z-part.position.z)<half.z+0.32 and local.y<part.position.y+half.y and local.y+1.8>part.position.y-half.y: return true
	return false
func furniture_clear(kind:String, cell:Vector2i, side:int, level:int) -> bool:
	var basis=Basis(Vector3.UP,-side*PI/2);var origin=furniture_origin(kind,cell,side,level)
	# A later furniture placement must not consume the relocated chest's standing aisle.
	if state.home_stash.location=="plot":
		var chest_basis=Basis(Vector3.UP,-state.home_stash.rotation*PI/2)
		var point=basis.inverse()*(stash_position()+chest_basis*Vector3(0,0.91,-0.8)-origin)
		for part in FurnitureGeometry.parts(kind):
			var half=part.size*0.5
			if absf(point.x-part.position.x)<half.x+0.28 and absf(point.z-part.position.z)<half.z+0.28 and absf(point.y-part.position.y)<half.y+0.9: return false
	# Shared circulation is allowed; furniture solids may not consume another approach.
	var approaches:Array=[]
	if not state.workbench.is_empty():
		var b=state.workbench;var bo=furniture_origin("workbench",b.cell,b.rotation,0,b);var bb=Basis(Vector3.UP,-b.rotation*PI/2)
		for z in [-0.45,-0.75]: approaches.append(bo+bb*Vector3(0,.91,z))
	if not state.bed.is_empty():
		var b=state.bed;var bo=furniture_origin("bed",b.cell,b.rotation);var bb=Basis(Vector3.UP,-b.rotation*PI/2)
		for x in [-.55,.55]: approaches.append(bo+bb*Vector3(x,.91,.87))
	for approach in approaches:
		var point=basis.inverse()*(approach-origin)
		for part in FurnitureGeometry.parts(kind):
			var half=part.size*.5
			if absf(point.x-part.position.x)<half.x+.32 and absf(point.z-part.position.z)<half.z+.32 and absf(point.y-part.position.y)<half.y+.9:return false
	for part in FurnitureGeometry.parts(kind):
		var shape=BoxShape3D.new();shape.size=part.size-Vector3.ONE*0.002
		var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.exclude=[player.get_rid()];query.transform=Transform3D(basis,origin+basis*part.position)
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	if kind=="workbench":
		# Reserve a usable full-height approach, without blocking the person placing it.
		var shape=CapsuleShape3D.new();shape.radius=0.32;shape.height=1.8
		for z in [-0.45,-0.75]:
			var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.exclude=[player.get_rid()];query.transform=Transform3D(Basis.IDENTITY,origin+basis*Vector3(0,0.91,z))
			if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	if kind=="bed":
		var shape=CapsuleShape3D.new();shape.radius=.32;shape.height=1.8
		for x in [-.55,.55]:
			var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.exclude=[player.get_rid()];query.transform=Transform3D(Basis.IDENTITY,origin+basis*Vector3(x,.91,.87))
			if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
	return true
func structure_furniture_clear(kind:String, cell:Vector2i, side:int, level:int) -> bool:
	var parts=[{"position":Vector3(0,1.5,0),"size":Vector3(1.98,3,0.36)}]
	if kind=="doorframe": parts=[{"position":Vector3(-0.88,1.5,0),"size":Vector3(0.22,3,0.30)},{"position":Vector3(0.88,1.5,0),"size":Vector3(0.22,3,0.30)},{"position":Vector3(0,2.88,0),"size":Vector3(1.98,0.24,0.30)}]
	var basis=Basis(Vector3.UP,-side*PI/2)
	# Preserve the stash standing approach when adding walls after relocation.
	if state.home_stash.location=="plot":
		var chest_basis=Basis(Vector3.UP,-state.home_stash.rotation*PI/2)
		var point=basis.inverse()*(stash_position()+chest_basis*Vector3(0,0.91,-0.8)-wall_position(cell,side,level))
		for part in parts:
			var half=part.size*0.5
			if absf(point.x-part.position.x)<half.x+0.28 and absf(point.z-part.position.z)<half.z+0.28 and absf(point.y-part.position.y)<half.y+0.9: return false
	# Match the reserved front approach in both placement orders.
	if not state.workbench.is_empty():
		var bench=state.workbench
		var bench_basis=Basis(Vector3.UP,-bench.rotation*PI/2)
		for z in [-0.45,-0.75]:
			var point=basis.inverse()*(furniture_origin("workbench",bench.cell,bench.rotation,0,bench)+bench_basis*Vector3(0,0.91,z)-wall_position(cell,side,level))
			for part in parts:
				var half=part.size*0.5
				if absf(point.x-part.position.x)<half.x+0.32 and absf(point.z-part.position.z)<half.z+0.32 and absf(point.y-part.position.y)<half.y+0.9: return false
	if not state.bed.is_empty():
		var b=state.bed;var bo=furniture_origin("bed",b.cell,b.rotation);var bb=Basis(Vector3.UP,-b.rotation*PI/2)
		for x in [-.55,.55]:
			var point=basis.inverse()*(bo+bb*Vector3(x,.91,.87)-wall_position(cell,side,level))
			for part in parts:
				var half=part.size*.5
				if absf(point.x-part.position.x)<half.x+.32 and absf(point.z-part.position.z)<half.z+.32 and absf(point.y-part.position.y)<half.y+.9:return false
	for part in parts:
		var shape=BoxShape3D.new();shape.size=part.size-Vector3.ONE*0.002
		var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.exclude=[player.get_rid()];query.transform=Transform3D(basis,wall_position(cell,side,level)+basis*part.position)
		for hit in get_world_3d().direct_space_state.intersect_shape(query,64):
			if hit.collider.has_meta("build_furniture") or hit.collider.has_meta("home_stash"): return false
	return true
func aimed_furniture(kind:String) -> Dictionary:
	var from=player.camera.global_position
	var query=PhysicsRayQueryParameters3D.create(from,from-player.camera.global_basis.z*5.0);query.exclude=[player.get_rid()]
	var hit=get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.position.distance_to(player.global_position+Vector3(0,1,0))<=2.4 and is_instance_valid(hit.get("collider")) and hit.collider.has_meta("build_furniture"):
		var record=hit.collider.get_meta("build_furniture")
		if record.kind==kind: return record.duplicate()
	return {}
func workbench_accessible() -> bool:
	if state.workbench.is_empty(): return false
	var bench=state.workbench;var origin=furniture_origin("workbench",bench.cell,bench.rotation,0,bench)
	var local=(player.position-origin).rotated(Vector3.UP,bench.rotation*PI/2)
	if local.z > 0.14 or local.z < -1.65 or absf(local.x)>0.85 or absf(local.y)>0.6: return false
	var target=origin+Vector3(0,0.84,0.25).rotated(Vector3.UP,-bench.rotation*PI/2)
	var eye=player.position+Vector3(0,1.3,0)
	if eye.distance_to(target)>1.8: return false
	var query=PhysicsRayQueryParameters3D.create(eye,target);query.exclude=[player.get_rid()]
	var hit=get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit.collider.has_meta("build_furniture") and hit.collider.get_meta("build_furniture").kind=="workbench")
func open_workbench():
	if modal_open() or build_mode or not workbench_accessible(): return
	pending_craft=false;ghost.hide();player.enabled=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	workbench_panel.render(craft,inventory,false,craft_paused);workbench_panel.show();workbench_panel.close_button.grab_focus()
func close_workbench():
	pending_craft=false;workbench_panel.hide();player.enabled=true;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func craft_action(action:String, writer_override=null) -> bool:
	if not workbench_panel.visible or dialog.visible or inventory_panel.visible or request_panel.visible or supplies_panel.visible or build_mode: return false
	if not workbench_accessible(): pending_craft=false;workbench_panel.render(craft,inventory,false,craft_paused,"Move back to the front of the workbench.");return false
	if action=="cancel": pending_craft=false;workbench_panel.render(craft,inventory,false,craft_paused,"Selection cancelled. Nothing consumed.");return true
	if action=="review":
		if pending_craft or craft.status!="idle": return false
		var preview=crafting_service.candidate("start",state,inventory,request,craft)
		if preview.is_empty(): workbench_panel.render(craft,inventory,false,craft_paused,crafting_service.last_error);return false
		pending_craft=true;workbench_panel.render(craft,inventory,true,craft_paused,"Confirm: consume 1 carried Timber and 1 Metal for one lantern kit.");workbench_panel.cancel_button.grab_focus();return true
	if action=="start":
		var had_pending=pending_craft;pending_craft=false
		if not had_pending: return false
		craft_accumulator=0.0
		return commit_crafting("start",Vector2i.ZERO,0,0,writer_override)
	if action=="claim": return commit_crafting("claim",Vector2i.ZERO,0,0,writer_override)
	if action=="retry" and craft_paused and craft.status=="working":
		if commit_crafting("tick",Vector2i.ZERO,0,0,writer_override): craft_paused=false;craft_accumulator=0.0;workbench_panel.render(craft,inventory,false,false,"Saved. Crafting resumed.");return true
	return false
func commit_crafting(action:String, cell:=Vector2i.ZERO, side:=0, level:=0, writer_override=null, redraw:=false) -> bool:
	var candidate=crafting_service.candidate(action,state,inventory,request,craft,cell,side,level)
	if candidate.is_empty():
		message(crafting_service.last_error)
		if workbench_panel.visible: workbench_panel.render(craft,inventory,false,craft_paused,crafting_service.last_error)
		return false
	var next_onboarding=onboarding_candidate(candidate.plot)
	if next_onboarding==null: return false
	if not save_payload(SaveCodec.encode(candidate.plot,candidate.inventory,candidate.request,candidate.craft,next_onboarding,fishing),false,writer_override):
		if workbench_panel.visible: workbench_panel.render(craft,inventory,false,craft_paused,notice.text)
		return false
	state=candidate.plot;inventory=candidate.inventory;request=candidate.request;craft=candidate.craft;onboarding=next_onboarding
	if redraw: refresh_plot()
	if action!="tick": message("%s • saved locally" % {"build_bench":"Workbench placed","remove_bench":"Workbench picked up; materials returned","start":"Craft started; materials consumed","claim":"Claimed 1 lantern kit","place_lantern":"Lantern placed","pickup_lantern":"Lantern kit returned","toggle_lantern":"Lantern switched"}.get(action,"Craft updated"))
	if workbench_panel.visible: workbench_panel.render(craft,inventory,pending_craft,craft_paused,"Output ready to claim." if craft.status=="ready" else notice.text)
	if inventory_panel.visible: render_inventory(inventory,inventory_panel.access_stash)
	return true
func advance_craft(delta:float):
	if craft.status!="working" or craft_paused: craft_accumulator=0.0;return
	# Count active frames only. One committed second per callback; no catch-up/offline burst.
	craft_accumulator+=minf(maxf(delta,0),0.25)
	if craft_accumulator<1.0: return
	craft_accumulator=0.0
	if not commit_crafting("tick"):
		craft_paused=true
		message("Crafting paused: save failed. Return to the workbench and Retry.")
		if workbench_panel.visible: workbench_panel.render(craft,inventory,false,true,notice.text)
func toggle_lantern(writer_override=null) -> bool:
	if build_mode or modal_open(): return false
	var record=aimed_furniture("lantern")
	if record.is_empty(): return false
	return commit_crafting("toggle_lantern",record.cell,record.rotation,record.level,writer_override,true)

func open_options():
	cancel_fishing("")
	if moving_stash: cancel_stash_move()
	if modal_open():return
	options_panel.open()
	player.enabled=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func close_options():
	player.enabled=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func key_label(action: String) -> String:
	return OS.get_keycode_string(int(options_panel.current.bindings[action]))
func update_control_labels():
	if not is_instance_valid(options_panel):return
	controls.text = "%s/%s/%s/%s Move • Mouse Look • %s Sprint • %s Jump • %s Crouch (hold)\n%s View • %s Interact • %s Inventory • %s Build wheel • %s Rotate\n%s Quest journal • %s Skills • Left / right click Place / remove • F5 Save • F9 Load • Esc Options" % [key_label("forward"),key_label("left"),key_label("backward"),key_label("right"),key_label("sprint"),key_label("jump"),key_label("crouch"),key_label("view"),key_label("interact"),key_label("inventory"),key_label("build"),key_label("rotate"),key_label("quests"),key_label("skills")]

func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		cooking_window_focused=false
		tailoring_transactions.cancel()
		if is_instance_valid(clothing_panel) and clothing_panel.visible:close_clothing()
		if is_instance_valid(trader_previews):trader_previews.close()
		if is_instance_valid(supplies_panel) and supplies_panel.visible:cancel_supply("Focus changed. Review a new trade.")
		if is_instance_valid(fishing_trader):fishing_trader.close()
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
		cooking_window_focused=true
		if map_restore_pending:call_deferred("_restore_map_controls")
		if cooking_detach_restore!=0:call_deferred("_restore_cooking_detach",cooking_detach_restore,false)
	if staged_startup and not world_initialized: return
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:cancel_fishing("")
	if what==NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(options_panel):
		if is_instance_valid(trader_previews):trader_previews.close()
		if is_instance_valid(cooking_test):cooking_test.close()
		if not options_panel.visible:
			if is_instance_valid(skills_panel) and skills_panel.visible:close_skills()
			if is_instance_valid(quest_journal) and quest_journal.visible:close_quests()
			if is_instance_valid(settlement_hud) and settlement_hud.full.visible:close_map()
			if build_wheel.visible:close_build_wheel()
			if inventory_panel.visible:close_inventory()
			elif dialog.visible:close_dialog()
			elif is_instance_valid(clothing_panel) and clothing_panel.visible:close_clothing()
			elif request_panel.visible:close_request_board()
			elif supplies_panel.visible:close_supplies()
			elif workbench_panel.visible:close_workbench()
			open_options()
		options_panel.request_quit()

func open_build_wheel():
	cancel_fishing("")
	if not player_in_home_area():message("Please visit your home");return
	if player.seated: message("Stand up before building."); return
	if moving_stash: cancel_stash_move()
	if modal_open(): return
	wheel_prior_build = build_mode
	ghost.hide()
	player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	build_wheel.open(piece_kind)
	if notice.text == "Please visit your home":
		notice.text = ""; notice_time = 0
func close_build_wheel():
	build_wheel.hide()
	build_mode = wheel_prior_build
	player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func choose_wheel_piece(kind: String):
	if not build_wheel.visible or not kind in build_wheel.KINDS: return
	if not player_in_home_area():cancel_home_build();return
	get_viewport().set_input_as_handled()
	close_build_wheel()
	select_piece(kind)
	build_mode = true
func exit_build_wheel():
	close_build_wheel()
	build_mode = false
	ghost.hide()

# The unique HomeStash is a world object, never an inventory kit. Moving only changes
# its Plot placement record; the 24-slot InventoryState.stash remains authoritative.
func stash_position(record: Dictionary = {}) -> Vector3:
	var placement=state.home_stash if record.is_empty() else record
	if placement.location=="starter_external": return STASH
	return furniture_position(placement.cell)+Vector3(-0.20,0,0).rotated(Vector3.UP,-placement.rotation*PI/2)
func refresh_stash():
	if not is_instance_valid(stash_holder): return
	stash_holder.get_child(0).rotation.y=0.0 if state.home_stash.location=="starter_external" else PI
	stash_holder.position=stash_position()
	stash_holder.rotation.y=PlotLayout.STASH_YAW if state.home_stash.location=="starter_external" else -state.home_stash.rotation*PI/2
func stash_accessible() -> bool:
	if not is_instance_valid(stash_body) or player.position.distance_to(stash_position())>=2.8: return false
	var query=PhysicsRayQueryParameters3D.create(player.position+Vector3(0,1.3,0),stash_position()+Vector3(0,0.45,0))
	query.exclude=[player.get_rid()]
	var hit=get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider==stash_body
func aimed_stash() -> bool:
	if not stash_accessible(): return false
	var from=player.camera.global_position
	var query=PhysicsRayQueryParameters3D.create(from,from-player.camera.global_basis.z*3.2)
	query.exclude=[player.get_rid()]
	var hit=get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider==stash_body
func stash_shortcut_free() -> bool:
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and not event.shift_pressed and (event.physical_keycode==KEY_M or event.keycode==KEY_M): return false
	return true
func begin_stash_move(from_panel := false) -> bool:
	if moving_stash or not can_move_home_stash() or not stash_accessible(): return false
	if from_panel:
		if not inventory_panel.visible or not inventory_panel.access_stash or stash_panel_source!=state.home_stash: return false
	elif modal_open() or not aimed_stash(): return false
	stash_prior_build=build_mode;stash_prior_kind=piece_kind;stash_prior_level=build_level;stash_prior_rotation=build_rotation
	if from_panel: close_inventory()
	stash_move_source=state.home_stash.duplicate(true)
	moving_stash=true;build_mode=true;build_level=0;build_rotation=int(state.home_stash.get("rotation",0));piece_kind="home_stash"
	create_preview()
	message("Move Home Stash • Choose a ground foundation. Contents stay in the original chest until saved.")
	return true
func cancel_stash_move():
	if not moving_stash: return
	moving_stash=false;stash_move_source={};build_mode=stash_prior_build;piece_kind=stash_prior_kind;build_level=stash_prior_level;build_rotation=stash_prior_rotation
	create_preview()
	message("Stash move cancelled. Original chest and contents unchanged.")
func stash_destination_error(cell: Vector2i, side: int) -> String:
	if not can_move_home_stash(): return "Complete your 2×2 home before the MOVE quest."
	if onboarding.status != "completed" and onboarding.footprint_for_cell(state,cell).is_empty(): return "MOVE quest: choose a foundation inside your completed 2×2 home."
	var reason=state.stash_placement_error(cell,side)
	if not reason.is_empty(): return reason
	var record={"location":"plot","cell":cell,"rotation":side}
	var origin=stash_position(record);var basis=Basis(Vector3.UP,-side*PI/2)
	var local=basis.inverse()*(player.position-origin)
	if absf(local.x)<1.07 and absf(local.z)<0.745 and local.y<0.9 and local.y+1.8>0: return "Step clear of the destination chest."
	if not state.bed.is_empty():
		var b=state.bed;var bo=furniture_origin("bed",b.cell,b.rotation);var bb=Basis(Vector3.UP,-b.rotation*PI/2)
		for x in [-.55,.55]:
			var point=basis.inverse()*(bo+bb*Vector3(x,.91,.87)-origin)
			if absf(point.x)<.749+.32 and absf(point.z)<.424+.32 and absf(point.y-.45)<.449+.9:return "Keep the bed side access clear."
	# Check its solid and full-height standing approach. Exclude only the original
	# chest and player, never other furniture or architecture. Original stays solid.
	for part in [{"position":Vector3(0,0.45,0),"size":Vector3(1.498,0.898,0.848)}, {"position":Vector3(0,0.91,-0.8),"size":Vector3(0.56,1.8,0.56)}, {"position":Vector3(0,1.49,0),"size":Vector3(1.498,1.18,0.848)}]:
		var shape=BoxShape3D.new();shape.size=part.size
		var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.exclude=[player.get_rid(),stash_body.get_rid()]
		query.transform=Transform3D(basis,origin+basis*part.position)
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return "Chest, lid or standing approach is obstructed."
	return ""
func update_stash_target():
	has_build_target=false;selection_valid=false;ghost.hide()
	selection_reason="Aim directly at a ground foundation inside your plot."
	var from=player.camera.global_position
	var query=PhysicsRayQueryParameters3D.create(from,from-player.camera.global_basis.z*12)
	query.exclude=[player.get_rid(),stash_body.get_rid()]
	var hit=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("build_cell"): return
	var body=hit.collider
	if body.has_meta("build_wall") or body.has_meta("build_ceiling") or body.has_meta("build_furniture") or body.has_meta("build_stairs") or body.has_meta("build_railing"): return
	selected=body.get_meta("build_cell");has_build_target=true
	selection_reason=stash_destination_error(selected,build_rotation)
	selection_valid=selection_reason.is_empty()
	ghost.position=stash_position({"location":"plot","cell":selected,"rotation":build_rotation})
	ghost.rotation.y=-build_rotation*PI/2
	ghost_material.albedo_color=Color(0.3,0.9,0.7,0.45) if selection_valid else Color(0.95,0.25,0.12,0.4)
	ghost.show()
func commit_stash_move(cell: Vector2i, side: int, writer_override = null) -> bool:
	if not moving_stash or not can_move_home_stash() or modal_open() or stash_move_source!=state.home_stash: return false
	# Click handler re-resolves aim; this entry also rechecks destination immediately.
	var error=stash_destination_error(cell,side)
	if not error.is_empty(): message(error);return false
	var candidate=plot_candidate()
	if candidate==null or not candidate.move_stash(cell,side): return false
	var next = onboarding_candidate(state)
	if next == null: return false
	if onboarding.status != "completed":
		next = onboarding.completion_candidate(candidate,stash_move_source)
		if next == null: return false
	if not publish_plot_candidate(candidate,"MOVE complete • Home Stash moved • contents preserved • saved" if onboarding.status != "completed" else "Home Stash moved • contents preserved • saved",writer_override,next): return false
	moving_stash=false;stash_move_source={};build_mode=stash_prior_build;piece_kind=stash_prior_kind;build_level=stash_prior_level;build_rotation=stash_prior_rotation
	create_preview()
	return true

# Prototype milestones only: no grants, rewards, sleep, healing or respawn.
func onboarding_candidate(plot):
	var next = OnboardingState.new()
	if not next.restore(onboarding.data()): return null
	next.refresh(plot)
	return next
func can_move_home_stash() -> bool:
	return onboarding.move_permission(state)
func render_inventory(contents, near: bool, status := ""):
	inventory_panel.allow_move_stash = near and can_move_home_stash()
	inventory_panel.render(contents,near,status,character_appearance)
func onboarding_hint() -> String:
	if onboarding.status == "completed":
		if onboarding.home_step=="bench_pending": return "WORKBENCH • Build a ground-floor workbench • MOVE unlocked"
		if onboarding.home_step=="bed_pending": return "STARTER BED • Place a cosmetic bed from B wheel • MOVE unlocked"
		return "Prototype home milestones complete • MOVE unlocked"
	if onboarding.status == "move_active":
		return "MOVE • Bring Home Stash inside your completed 2×2" if can_move_home_stash() else "MOVE • Restore the enclosed, roofed 2×2 home first"
	return "STARTER HOME • Roofed 2×2 + door • Free structure (prototype)"

var map_restore_pending=false
func open_map():
	if not world_initialized or startup_cancel_requested or (staged_startup and not world_activated) or not cooking_window_focused:return
	cancel_fishing("")
	if modal_open():return
	if moving_stash:cancel_stash_move()
	build_mode=false
	ghost.hide()
	settlement_hud.full_map.refresh_geometry()
	settlement_hud.full.show()
	settlement_hud.full_map.reset_gestures()
	settlement_hud.full_map.view.grab_focus()
	for action in ["forward","backward","left","right","sprint","jump","crouch","interact"]:Input.action_release(action)
	player.velocity=Vector3.ZERO
	player.enabled=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func close_map():
	if not is_instance_valid(settlement_hud) or not settlement_hud.full.visible:return
	settlement_hud.full_map.reset_gestures()
	settlement_hud.full.hide()
	map_restore_pending=true
	_restore_map_controls()
func _restore_map_controls():
	if not map_restore_pending:return
	if not is_inside_tree() or is_queued_for_deletion() or startup_cancel_requested or not world_initialized or (staged_startup and not world_activated):map_restore_pending=false;return
	if not cooking_window_focused or not is_instance_valid(player) or modal_open():return
	map_restore_pending=false
	player.enabled=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

# APPLICATION-OWNED interim prototype allocation, not final item footprints or
# pocket/rig/backpack dimensions. No extra capacity: one existing carried unit
# per unequipped starter garment. Home Stash movement remains outside this slice.
func equipment_movement_allowed(before:Dictionary,after:Dictionary,changes:Array) -> bool:
	return preload("res://scripts/starter_clothing_allocation.gd").allowed(before,after,changes)
func equipment_intent_current(snapshot_revision:int) -> bool:
	return not moving_stash and not (is_instance_valid(options_panel) and options_panel.visible) and not (is_instance_valid(build_wheel) and build_wheel.visible) and not (is_instance_valid(settlement_hud) and settlement_hud.full.visible) and inventory_panel.visible and snapshot_revision==inventory_panel.generation and not dialog.visible and not request_panel.visible and not supplies_panel.visible and not workbench_panel.visible and not build_mode
func change_equipment(action:String,instance_id:String,slot:String,snapshot_revision:int,writer_override=null) -> bool:
	if not equipment_intent_current(snapshot_revision):return false
	var near_stash=inventory_panel.access_stash and stash_accessible() and stash_panel_source==state.home_stash
	var candidate=inventory.equipment_candidate(action,instance_id,slot,equipment_movement_allowed,near_stash)
	if candidate==null:render_inventory(inventory,inventory_panel.access_stash,inventory.last_error);return false
	return publish_equipment_inventory(candidate,"Equipment saved",writer_override)
func change_quick_access(index:int,target_id:String,source_slot:int,snapshot_revision:int,writer_override=null) -> bool:
	if not equipment_intent_current(snapshot_revision):return false
	var candidate=inventory.hotbar_candidate(index,target_id,source_slot)
	if candidate==null:render_inventory(inventory,inventory_panel.access_stash,inventory.last_error);return false
	return publish_equipment_inventory(candidate,"Quick access saved",writer_override)
func publish_equipment_inventory(candidate,status:String,writer_override=null) -> bool:
	if not save_payload(SaveCodec.encode(state,candidate,request,craft,onboarding,fishing),false,writer_override):
		render_inventory(inventory,inventory_panel.access_stash,notice.text);return false
	inventory=candidate
	render_inventory(inventory,inventory_panel.access_stash,status)
	if is_instance_valid(settlement_hud):settlement_hud.update_quickbar(quickbar.selected_index)
	return true

func activate_quickbar(index:Variant) -> bool:
	if build_mode or moving_stash or modal_open():return false
	if not index is int or index<0 or index>=quickbar.SLOT_COUNT:return false
	var target_id:String=inventory.hotbar_assignments[index]
	if not preload("res://scripts/hotbar_contract.gd").valid_reference(target_id,inventory.hotbar_context()):return false
	if target_id=="material:lantern_kit" and not player_in_home_area():message("Please visit your home");return false
	if target_id=="material:lantern_kit" and player!=null and player.get("seated")==true:
		message("Stand up before building.");return false
	quickbar.select(index)
	if target_id=="material:lantern_kit":
		# Preview only. Existing placement collision/crafting/save transaction owns use.
		if inventory.amount("carried","lantern_kit")<1:return false
		select_piece("lantern");build_mode=true
	return true

func transfer_inventory_cell(source:String,destination:String,item:String,slot_index:int,snapshot_revision:int,writer_override=null)->bool:
	if not equipment_intent_current(snapshot_revision):return false
	if not "lockbox" in [source,destination]:return false
	return transfer_inventory(source,destination,item,1,writer_override,slot_index)

func player_in_home_area()->bool:
	return is_instance_valid(player) and PlotLayout.contains_home_position(player.position,state.expanded)
func cancel_home_build():
	if is_instance_valid(build_wheel) and build_wheel.visible:close_build_wheel()
	build_mode=false;wheel_prior_build=false
	if is_instance_valid(ghost):ghost.hide()
	if is_instance_valid(target_outline):target_outline.hide()
	if is_instance_valid(prompt_panel):prompt_panel.hide()
	message("Please visit your home")
func build_menu_help()->String:
	var text="BUILD • %s\nChoose a piece • %s closes this menu • %s rotates during placement"%[PIECE_NAMES[piece_kind],key_label("build"),key_label("rotate")]
	text+="\nLeft click place • Right click remove • PageUp/Down: Ground / Upper"
	if piece_kind=="workbench":text+="\nCost: 2 carried Timber + 1 Metal"
	elif piece_kind=="lantern":text+="\nCost: 1 carried lantern kit"
	return text

func tailor_accessible()->bool:
	return preload("res://scripts/tailor_atelier.gd").accessible(self,player)
func tailor_shop_context()->Dictionary:
	return {"onboarding":onboarding.data(),"craft":craft.data(),"fishing":fishing.data(),"service_mode":clothing_panel.service_mode,"shop_action":clothing_panel.action,"selected_item":clothing_panel.selected_item,"pattern":clothing_panel.patterns.selected}
func tailor_other_modal_open()->bool:
	for panel in [dialog,inventory_panel,request_panel,workbench_panel,options_panel,supplies_panel,skills_panel,quest_journal,build_wheel]:
		if is_instance_valid(panel) and panel.visible:return true
	if is_instance_valid(settlement_hud) and settlement_hud.full.visible:return true
	if fishing_session.active():return true
	if is_instance_valid(fishing_trader) and fishing_trader.is_open():return true
	if is_instance_valid(cooking_test) and cooking_test.is_open():return true
	if is_instance_valid(trader_previews) and trader_previews.is_open():return true
	return false
func tailor_shop_access()->bool:
	if not is_inside_tree() or is_queued_for_deletion() or not world_initialized or startup_cancel_requested:return false
	if staged_startup and not world_activated:return false
	if not is_instance_valid(player) or player.seated or moving_stash or build_mode or not cooking_window_focused:return false
	return is_instance_valid(clothing_panel) and clothing_panel.visible and not tailor_other_modal_open() and tailor_accessible()
func tailor_shop_review(item:String,quantity:int,action:String):
	if not tailor_shop_access():return
	var quote=tailoring_transactions.select("tailor",action,item,quantity,state,inventory,request,tailor_shop_context())
	clothing_panel.render(inventory,onboarding,tailoring_service.last_error if not tailoring_service.last_error.is_empty() else tailoring_transactions.last_error,state,quote)
func tailor_shop_confirm(writer_override=null)->bool:
	var pending=tailoring_transactions.pending_quote()
	if pending.is_empty():return false
	var writer=func(candidate):return save_payload(SaveCodec.encode(candidate.plot,candidate.inventory,candidate.request,craft,onboarding,fishing),false,writer_override)
	var candidate=tailoring_transactions.confirm(pending.token,state,inventory,request,tailor_shop_access,writer,tailor_shop_context())
	if not candidate.is_empty():state=candidate.plot;inventory=candidate.inventory;request=candidate.request
	clothing_panel.render(inventory,onboarding,"Saved. "+str(pending.get("name","Tailoring transaction"))+" complete." if not candidate.is_empty() else tailoring_transactions.last_error,state)
	if not candidate.is_empty():ApprovedAudio.emit_for(self,"confirm_buy")
	return not candidate.is_empty()
func tailor_shop_cancel():
	tailoring_transactions.cancel()
	clothing_panel.render(inventory,onboarding,"Review cancelled. Nothing spent or changed.",state)

func dan_accessible() -> bool:
	# Narrow front customer strip; never through the rear or side walls.
	var p=player.global_position
	if p.x<3.0 or p.x>9.0 or p.z<18.5 or p.z>21.0 or absf(p.y)>0.6:return false
	var target=Vector3(6,1.5,21.2)
	var eye=p+Vector3(0,1.5,0)
	if eye.distance_to(target)>2.8:return false
	var query=PhysicsRayQueryParameters3D.create(eye,target)
	query.exclude=[player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func accept_clothing(writer_override=null) -> bool:
	if not request_panel.visible or player.position.distance_to(BOARD)>=2.8:return false
	var candidate=clothing_service.accept(inventory,onboarding)
	if not publish_clothing(candidate,writer_override):return false
	refresh_clothing_board()
	refresh_fishing_board()
	request_panel.feedback_label.text="A fresh outfit accepted. Visit Tailor & Dyes at the west path end."
	return true
func open_clothing():
	if modal_open() or build_mode or not tailor_accessible():return
	tailoring_transactions.cancel()
	clothing_panel.render(inventory,onboarding,"",state)
	clothing_panel.show();player.enabled=false;player.velocity=Vector3.ZERO;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if not clothing_panel.claim.disabled:clothing_panel.claim.grab_focus()
	else:clothing_panel.tab_buttons[clothing_panel.service_mode].grab_focus()
func close_clothing():
	tailoring_transactions.cancel()
	if is_instance_valid(clothing_panel):clothing_panel.hide()
	if is_instance_valid(player) and world_initialized and (not staged_startup or world_activated) and cooking_window_focused and not modal_open():
		player.enabled=true;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	elif not cooking_window_focused:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func clothing_action(action:String,instance_id:String,rgba:Array,writer_override=null) -> bool:
	if not tailor_shop_access() or not tailoring_transactions.pending_quote().is_empty():return false
	var candidate:Dictionary={}
	if action=="claim":candidate=clothing_service.talk_tailor(inventory,onboarding,equipment_movement_allowed)
	elif action=="dye":candidate=clothing_service.dye(inventory,onboarding,instance_id,"fabric",rgba)
	var success=publish_clothing(candidate,writer_override)
	clothing_panel.render(inventory,onboarding,clothing_service.last_error if not clothing_service.last_error.is_empty() else ("Saved." if success else "No change was saved. Your items and dye allowances are unchanged."),state)
	refresh_clothing_board()
	return success
func publish_clothing(candidate:Dictionary,writer_override=null) -> bool:
	if candidate.size()!=3 or not candidate.has("inventory") or not candidate.has("onboarding") or not candidate.has("source"):return false
	if candidate.source!={"inventory":inventory.data(),"onboarding":onboarding.data()}:return false
	if not save_payload(SaveCodec.encode(state,candidate.inventory,request,craft,candidate.onboarding,fishing),false,writer_override):return false
	inventory=candidate.inventory;onboarding=candidate.onboarding
	return true

func refresh_clothing_board():
	clothing_accept.disabled=onboarding.clothing_step!="available"
	clothing_accept.text={"available":"A fresh outfit • Accept and visit the tailor","talk_dan":"A fresh outfit • Visit the tailor at the west path end","claim_pending":"A fresh outfit • Claim at the tailor when four units fit","dye_active":"Make it yours • Dye one garment at the tailor","complete":"Clothing quests complete • Free dye tracked per slot"}[onboarding.clothing_step]

# The journal reads persisted progression and current carried counts only.
func open_quests():
	cancel_fishing("")
	if not world_initialized or modal_open() or moving_stash:return
	build_mode=false
	ghost.hide()
	quest_journal.render(request,onboarding,inventory,key_label("quests"),options_panel.backend.quest_binding_notice(options_panel.current),fishing)
	player.enabled=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func close_quests():
	quest_journal.hide()
	var focus=get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if is_instance_valid(focus) and quest_journal.is_ancestor_of(focus):focus.release_focus()
	player.enabled=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

# Owned-pole fishing at the existing marked bank. Quest and ordinary fish remain distinct; no XP.
func fishing_accessible() -> bool:
	if not is_instance_valid(player) or player.seated or player.crouched or moving_stash:return false
	var delta=player.global_position-FISHING_SPOT
	return Vector2(delta.x,delta.z).length()<=.75 and absf(delta.y)<=.3 and player.global_position.y>FISHING_TARGET.y+.25 and player.is_on_floor() and player.get_floor_normal().y>=.8
func refresh_fishing_board():
	if not is_instance_valid(fishing_accept):return
	fishing_details.text="FIRST CATCH • Separate one-time starter request\nCarry a fishing pole and select its assigned quick-access slot at the marked northern stream, east of the Hall. No bait, durability or XP per cast. One quest catch in this test; carry it back here."
	fishing_accept.disabled=fishing.status=="completed" or (fishing.status=="active" and inventory.amount("carried",FishingState.ITEM)!=1)
	fishing_accept.text="First catch • Accept" if fishing.status=="not_started" else ("First catch complete • Owned pole fishing remains available" if fishing.status=="completed" else "First catch • Deliver 1 carried stream fish (no reward)")
func fishing_board_action(writer_override=null) -> bool:
	if not request_panel.visible or player.global_position.distance_to(BOARD)>=2.8 or build_mode or fishing_session.active():return false
	var action="accept" if fishing.status=="not_started" else "deliver"
	var next=fishing.candidate(action,inventory)
	if next.is_empty():request_panel.feedback_label.text=fishing.last_error;return false
	if not save_payload(SaveCodec.encode(state,next.inventory,request,craft,onboarding,next.fishing),false,writer_override):
		request_panel.feedback_label.text=notice.text;return false
	inventory=next.inventory;fishing=next.fishing;refresh_fishing_board()
	request_panel.feedback_label.text="First catch accepted. Follow the east side of the Hall to the northern stream. Buy a pole from the nearby fisherman and select its quick-access slot." if action=="accept" else "Fish delivered and saved. No reward or XP. You can keep fishing with your selected owned pole."
	return true
func fishing_rod_selected() -> bool:
	if inventory.amount("carried","fishing_pole")<1:return false
	var index=quickbar.selected_index
	if not index is int or index<0 or index>=inventory.hotbar_assignments.size():return false
	return inventory.hotbar_assignments[index]=="material:fishing_pole" and preload("res://scripts/hotbar_contract.gd").valid_reference("material:fishing_pole",inventory.hotbar_context())

func start_fishing() -> bool:
	if modal_open() or build_mode or not fishing_accessible():return false
	if not fishing_rod_selected():
		message("Carry a fishing pole, assign it in Inventory to quick access, then select its slot.");return false
	if not OwnedFishing.can_cast(inventory,fishing):
		message("Make one free carried space before casting; keep your pole carried and selected.")
		return false
	if (-player.global_basis.z).dot((FISHING_TARGET-player.global_position).normalized())<.5:
		message("Face the stream to cast your selected fishing pole.");return false
	var hand=player.global_position+Vector3(.16,1.68,-1.65)
	var cast_query=PhysicsRayQueryParameters3D.create(hand,FISHING_TARGET+Vector3(0,.06,0))
	cast_query.exclude=[player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(cast_query).is_empty():
		message("Cast line is blocked. Reposition on the marked dry bank.");return false
	notice.text="";notice_time=0
	fishing_progress_snapshot=fishing.data().duplicate(true)
	fishing_session.begin(inventory);player.enabled=false;player.velocity=Vector3.ZERO
	fishing_prop=preload("res://scripts/fishing_visual.gd").new();add_child(fishing_prop)
	return true
func cancel_fishing(feedback:String=""):
	if not fishing_session.active() and not is_instance_valid(fishing_prop):return
	fishing_session.cancel();fishing_progress_snapshot={}
	if is_instance_valid(fishing_prop):fishing_prop.queue_free()
	fishing_prop=null
	if is_instance_valid(player):player.enabled=not modal_open()
	if not feedback.is_empty():message(feedback)
func advance_fishing(delta:float):
	if not fishing_session.active():return
	if not fishing_rod_selected() or not fishing_accessible() or inventory.data()!=fishing_session.inventory_snapshot or fishing.data()!=fishing_progress_snapshot:
		cancel_fishing("Cast cancelled: stance or inventory changed. Nothing was kept.");return
	var previous_phase:String=fishing_session.phase
	fishing_session.advance(delta)
	if previous_phase!=fishing_session.phase:
		if fishing_session.phase=="waiting":ApprovedAudio.emit_at(self,"splash",FISHING_TARGET)
		elif fishing_session.phase=="bite":ApprovedAudio.emit_for(self,"fish_bite")
	if is_instance_valid(fishing_prop):fishing_prop.update_prop(player,FISHING_TARGET,fishing_session.phase,fishing_session.elapsed)
	if fishing_session.phase=="resolve":resolve_fishing(fishing_session.token)
func resolve_fishing(token:int,writer_override=null) -> bool:
	if not fishing_rod_selected() or not fishing_accessible() or fishing.data()!=fishing_progress_snapshot or not OwnedFishing.can_cast(inventory,fishing):
		cancel_fishing("Catch not kept: stance or inventory capacity changed.");return false
	if not fishing_session.claim(token,inventory):return false
	var next=OwnedFishing.candidate(inventory,fishing)
	if next.is_empty():cancel_fishing("Catch not kept. Nothing changed.");return false
	var saved=save_payload(SaveCodec.encode(state,next.inventory,request,craft,onboarding,next.fishing),false,writer_override)
	if saved:
		inventory=next.inventory;fishing=next.fishing
		ApprovedAudio.emit_for(self,"item_pickup")
	cancel_fishing("")
	if saved:message("Fish saved in carried inventory. Quest stream fish goes to First catch; ordinary river fish is separate. No XP or reward awarded.")
	return saved

# Storage payloads express intent only. Recheck the live physical stash and the
# complete inventory snapshot before building a save-first relocation candidate.
func transfer_clothing_storage(instance_id:String,source:String,destination:String,snapshot_revision:int,snapshot:Dictionary,writer_override=null)->bool:
	if not equipment_intent_current(snapshot_revision) or snapshot!=inventory.data():return false
	if not inventory_panel.access_stash or not stash_accessible() or stash_panel_source!=state.home_stash:
		render_inventory(inventory,inventory_panel.access_stash,"Move near Home Stash and reopen it before transferring clothing.");return false
	var candidate=inventory.clothing_storage_candidate(instance_id,source,destination)
	if candidate==null:render_inventory(inventory,inventory_panel.access_stash,inventory.last_error);return false
	return publish_equipment_inventory(candidate,"Clothing transferred • saved locally",writer_override)

# Read-only catalogue, not a progression system. Opening never writes gameplay data.
func open_skills():
	cancel_fishing("")
	if not world_initialized or modal_open() or moving_stash:return
	build_mode=false
	ghost.hide()
	for action in ["forward","backward","left","right","sprint","jump","crouch","interact"]:
		Input.action_release(action)
	skills_panel.render(key_label("skills"),options_panel.backend.skills_binding_notice(options_panel.current))
	player.enabled=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func close_skills():
	skills_panel.hide()
	var focus=get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if is_instance_valid(focus) and skills_panel.is_ancestor_of(focus):focus.release_focus()
	player.enabled=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func transfer_clothing_lockbox(instance_id:String,source:String,destination:String,slot_index:int,snapshot_revision:int,snapshot:Dictionary,writer_override=null)->bool:
	if not equipment_intent_current(snapshot_revision) or snapshot!=inventory.data():return false
	var candidate=inventory.clothing_lockbox_candidate(instance_id,source,destination,slot_index)
	if candidate==null:render_inventory(inventory,inventory_panel.access_stash,inventory.last_error);return false
	return publish_equipment_inventory(candidate,"Clothing transferred • saved locally",writer_override)

func _restore_cooking_detach(controller_id:int,_was_focus_suspended:bool):
	# Deferred: distinguish controller removal from world teardown. Current focus
	# wins over the earlier snapshot; a live host retries on focus return.
	if not is_inside_tree() or is_queued_for_deletion() or startup_cancel_requested or not world_initialized or (staged_startup and not world_activated):
		cooking_detach_restore=0;return
	if is_instance_valid(cooking_test) and cooking_test.get_instance_id()!=controller_id:
		cooking_detach_restore=0;return
	cooking_detach_restore=controller_id
	if not cooking_window_focused or not is_instance_valid(player) or not player.is_inside_tree() or modal_open(false):return
	cooking_detach_restore=0
	player.enabled=true;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _restore_fishing_trader_detach(controller_id:int):
	if not is_inside_tree() or is_queued_for_deletion() or startup_cancel_requested or not world_initialized or (staged_startup and not world_activated):
		fishing_trader_restore=0;return
	if is_instance_valid(fishing_trader) and fishing_trader.get_instance_id()!=controller_id:
		fishing_trader_restore=0;return
	if is_instance_valid(fishing_trader) and fishing_trader.is_inside_tree() and fishing_trader.is_open():
		fishing_trader_restore=0;return
	fishing_trader_restore=controller_id
	if not cooking_window_focused or not is_instance_valid(player) or not player.is_inside_tree() or modal_open(true,false):return
	fishing_trader_restore=0;player.enabled=true;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
