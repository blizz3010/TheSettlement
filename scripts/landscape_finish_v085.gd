extends RefCounted
# Final approved additions are installed inside the existing startup barrier.
const GROUND = preload('res://assets/settlement_grass_v086/coverage.scn')
const HOME = preload('res://assets/plaza_islands/home_garden.scn')
const ATLAS = preload('res://assets/atlas_strip_v085/composition.scn')
const HomeCleanup = preload('res://scripts/home_garden_v085.gd')
const Seat = preload('res://scripts/seat_interaction.gd')
static func apply(world:Node3D)->Dictionary:
 if world.has_meta('landscape_finish_v085'):return world.get_meta('landscape_finish_v085')
 var controller=world.get('plaza_island_landscape')
 if controller==null or not is_instance_valid(controller.visual):return {'ok':false,'reason':'Main landscape composition missing'}
 var old=world.get_node_or_null('MarketExpansion/AtlasStand/LocalMarketSurroundings') as Node3D
 if old==null:return {'ok':false,'reason':'Expected Atlas side planting missing'}
 var garden=HOME.instantiate()
 var home_result=HomeCleanup.apply(world,garden,controller.visual)
 if not home_result.get('ok',false):garden.free();return home_result
 var atlas=ATLAS.instantiate()
 var grass=atlas.get_node_or_null('AtlasContinuousGrass')
 if grass!=null:
  grass.name='Grass_AtlasContinuous'
  grass.set_meta('coverage_edge',true)
 controller.visual.add_child(atlas)
 old.visible=false
 for body in old.find_children('*','CollisionObject3D',true,false):
  body.collision_layer=0;body.collision_mask=0
 var bench=atlas.get_node_or_null('AtlasRoadFacingBench')
 Seat.register_bench(bench)
 controller.configure_grass_materials()
 controller.set_quality(controller.quality)
 var approved=preload('res://scripts/approved_gardens_v086.gd').apply(world)
 if not approved.get('ok',false):return approved
 var inn_front=preload('res://scripts/inn_front_v087.gd').apply(world)
 if not inn_front.get('ok',false):return inn_front
 if world.get_node_or_null('ValleyBackdrop')==null:return {'ok':false,'reason':'Lake backdrop missing'}
 var lake=preload('res://scripts/inn_lake_v088.gd').apply(world)
 if not lake.get('ok',false):return lake
 if not lake.get('backdrop',{}).get('present',false):return {'ok':false,'reason':'Lake backdrop adaptation missing'}
 var ground=GROUND.instantiate()
 controller.visual.add_child(ground)
 ground.set_quality(controller.quality)
 var rook_approach=preload('res://scripts/market_visual_union.gd').finish_rook_approach(world)
 if not rook_approach.get('ok',false):return rook_approach
 var contacts:Dictionary=preload('res://scripts/paths_gardens_v094.gd').apply(world)
 if not contacts.get('ok',false):return contacts
 var fishing_finish:Dictionary=preload('res://scripts/fishing_nook_v094.gd').finalize_grass(world)
 if not fishing_finish.get('ok',false):return fishing_finish
 var distant=preload('res://scripts/distant_valley_v093.gd').apply(world)
 if not distant.get('ok',false):return distant
 var riverbank:Dictionary=preload('res://scripts/riverbank_stage1_v094.gd').apply(world)
 if not riverbank.get('ok',false):return riverbank
 var northern:Dictionary=preload('res://scripts/north_woodland_stage2_v094.gd').apply(world)
 if not northern.get('ok',false):return northern
 var north_trees:Dictionary=preload('res://scripts/north_trees_stage3_v094.gd').apply(world)
 if not north_trees.get('ok',false):return north_trees
 var ship_grass:Dictionary=preload('res://scripts/ship_grass_clearance_v099.gd').apply(world)
 if not ship_grass.get('ok',false):return ship_grass
 var night:Dictionary=preload('res://scripts/night_hierarchy_v094.gd').apply(world)
 if not night.get('ok',false):return night
 var result={'ship_grass_clearance_v099':ship_grass,'north_trees_stage3':north_trees,'north_woodland_stage2':northern,'contact_finish':contacts,'riverbank_stage1':riverbank,'night_hierarchy':night,'fishing_finish':fishing_finish,'distant_valley':distant,'ok':true,'home':home_result,'atlas':atlas.get_meta('atlas_strip_v085'),'bench_registered':bench.is_in_group('usable_seats'),'approved_gardens':approved,'inn_front':inn_front,'lake':lake,'ground_coverage':ground.get_meta('coverage_manifest',{})}
 world.set_meta('landscape_finish_v085',result)
 print('LANDSCAPE_FINISH_V085_READY ',result)
 return result
