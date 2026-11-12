extends SceneTree
const Plants=preload("res://scripts/intentional_planting_pockets.gd")
const Placement=preload("res://scripts/cooking_test_placement.gd")
const Codec=preload("res://scripts/save_codec.gd")
func _initialize():call_deferred("run")
func serial(polys:Array)->Array:
 var result=[]
 for poly in polys:
  var row=[]
  for p in poly:row.append([p.x,p.y])
  result.append(row)
 return result
func capsule_route(world,points:Array)->Dictionary:
 var space=world.get_world_3d().direct_space_state
 var capsule=CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.8
 var checked=0
 for segment in range(points.size()-1):
  var a:Vector2=points[segment];var b:Vector2=points[segment+1]
  var steps=maxi(1,ceili(a.distance_to(b)/.2))
  for i in range(steps+1):
   var at=a.lerp(b,float(i)/steps)
   var ground=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,4,at.y),Vector3(at.x,-4,at.y)))
   if ground.is_empty():return {"ok":false,"reason":"Route lacks ground","at":at}
   var query=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.exclude=[world.player.get_rid()];query.transform=Transform3D(Basis.IDENTITY,Vector3(at.x,ground.position.y+.93,at.y))
   var hits=space.intersect_shape(query,8)
   if not hits.is_empty():return {"ok":false,"reason":"Capsule route blocked","at":at,"collider":str(hits[0].collider.get_path())}
   checked+=1
 return {"ok":true,"samples":checked,"radius":.32,"height":1.8}
func run():
 var isolated=OS.get_environment('QA_PROFILE_ROOT').simplify_path().trim_suffix('/')
 assert(not isolated.is_empty() and isolated.is_absolute_path(),'Set explicit isolated QA_PROFILE_ROOT')
 assert(ProjectSettings.globalize_path('user://').simplify_path().begins_with(isolated+'/'),'Refusing real/nonisolated production profile')
 var dependency=load(get_script().resource_path.get_base_dir().path_join('dependency_closure.gd')).verify()
 assert(DisplayServer.get_name()!="headless")
 root.size=Vector2i(640,360)
 var path=OS.get_environment("EXPECTED_MASKS");assert(FileAccess.get_sha256(path)=="aa6f6d641d1369b1e558bdf0dd3dbc4b67f6f3fbb278fc7c08ff8a65cade512c")
 var expected=JSON.parse_string(FileAccess.get_file_as_string(path))
 assert(Plants._verified_foliage.is_empty()) # Fresh process, no fixture cache injection.
 var world=load("res://main.tscn").instantiate();world.staged_startup=true;world.process_mode=Node.PROCESS_MODE_DISABLED;root.add_child(world)
 while not world.world_initialized:await process_frame
 assert(not world.world_activated and not world.player.enabled and not is_instance_valid(world.cooking_test.station))
 assert(world.get_meta('bundle_coverage_result').ok and world.get_meta('bundle_route_result').ok)
 var actors=world.get_meta('bundle_coverage_result').actors
 assert(actors.size()==5)
 var actor_names=[]
 for actor in actors:actor_names.append(str(actor.name))
 assert(actor_names==['CoverageStudy_Atlas','CoverageStudy_Rook','CoverageStudy_West','CoverageStudy_HallPlotProvisional','CoverageStudy_HallReceptionProvisional'])
 var phase=[]
 for actor in actors:phase.append(actor.animator.current_animation_position)
 await process_frame;await process_frame
 for i in range(actors.size()):assert(actors[i].animator.current_animation_position==phase[i])
 world.activate_loaded_world()
 while not world.park_west_visuals.attempted:await process_frame
 assert(world.park_west_visuals.result.ok)
 assert(world.park_layered_visuals.result.ok)
 root.size=Vector2i(640,360) # Apply AFTER production Options has initialized its display preset.
 print("COOKING_NATIVE_VIEWPORT "+str(root.size))
 await physics_frame;await RenderingServer.frame_post_draw
 world.set_process(false);world.player.set_physics_process(false)
 var binding=JSON.parse_string(FileAccess.get_file_as_string('res://assets/park_layered/binding.json'))
 var baked=world.park_layered_visuals.visual;assert(is_instance_valid(baked))
 var structure=load('res://scripts/park_layered_visuals.gd').inspect_candidate(baked,binding)
 assert(structure.ok and baked.get_child_count()==20)
 var contract=JSON.parse_string(FileAccess.get_file_as_string(get_script().resource_path.get_base_dir().path_join('build-contract.json')))
 var park_expected_path=get_script().resource_path.get_base_dir().path_join('expected-park-polygons.json')
 assert(FileAccess.get_sha256(park_expected_path)==contract.expected_park_polygons_sha256)
 var expected_park=JSON.parse_string(FileAccess.get_file_as_string(park_expected_path));var actual_park=[]
 for mesh in baked.find_children('*','MeshInstance3D',true,false):actual_park.append({'group':str(mesh.get_parent().name),'polygon':serial([Plants.rectangle(mesh.global_transform*mesh.mesh.get_aabb())])[0]})
 assert(JSON.stringify(actual_park)==JSON.stringify(expected_park))
 var before=Codec.encode(world.state,world.inventory,world.request,world.craft,world.onboarding,world.fishing)
 assert(before.version==21 and before.inventory.version==8 and before.fishing.version==1)
 var authority=JSON.parse_string(FileAccess.get_file_as_string("res://assets/planting_review/verified-native-foliage.json"))
 assert(authority.source_sha256.size()==277)
 for file in authority.source_sha256:assert(FileAccess.get_sha256(file)==authority.source_sha256[file])
 assert(is_instance_valid(world.cooking_test.station) and world.cooking_test.clearance.ok)
 var station=world.cooking_test.station;var col=station.own_collider.get_child(0)
 col.disabled=true
 var protected=serial(Plants.preservation_masks(world))
 col.disabled=false
 var foliage=Plants.live_existing_foliage(world)
 assert(JSON.stringify(protected)==JSON.stringify(expected.protected))
 assert(JSON.stringify(serial(foliage))==JSON.stringify(expected.existing_foliage))
 var plants=world.get_node("IntentionalPlantingPockets")
 assert(plants.get_meta("budget").accepted==47)
 var buffers=[]
 for batch in plants.get_children():buffers.append(batch.multimesh.buffer.duplicate())
 var report={"diagnostic_cache_injected":false,"normal_startup_constructed":true,"protected":protected,"existing_foliage":serial(foliage),"plants":plants.get_meta("budget"),"placement":world.cooking_test.clearance,"authority_guards":authority.source_sha256.size(),"actual_window_size":root.size}
 var output=OS.get_environment("REBUILD_OUTPUT");assert(not output.is_empty())
 var with_station=serial(Plants.preservation_masks(world));assert(with_station.size()==protected.size()+1)
 # Exact expected cylinder projection, matching the unmodified mask algorithm.
 var intended=CylinderShape3D.new();intended.radius=.45;intended.height=.75
 assert(col.shape is CylinderShape3D and col.shape.radius==intended.radius and col.shape.height==intended.height)
 var intended_transform=Transform3D(Basis.IDENTITY,station.global_position+Vector3(0,.375,0));assert(col.global_transform==intended_transform)
 var points=PackedVector2Array()
 for i in range(64):
  var v=intended_transform*Vector3(cos(i*TAU/64)*intended.radius/cos(PI/64),0,sin(i*TAU/64)*intended.radius/cos(PI/64))
  points.append(Vector2(v.x,v.z))
 var expected_added=serial(Geometry2D.offset_polygon(Geometry2D.convex_hull(points),.12))
 assert(expected_added.size()==1)
 var remaining=with_station.duplicate(true)
 for row in protected:
  var idx=-1
  for j in range(remaining.size()):
   if JSON.stringify(remaining[j])==JSON.stringify(row):idx=j;break
  assert(idx>=0);remaining.remove_at(idx)
 assert(JSON.stringify(remaining)==JSON.stringify(expected_added))
 report["added_collider_polygons"]=remaining
 report["expected_added_cylinder_polygons"]=expected_added
 col.disabled=true
 assert(JSON.stringify(serial(Plants.preservation_masks(world)))==JSON.stringify(expected.protected))
 col.disabled=false
 assert(JSON.stringify(serial(Plants.live_existing_foliage(world)))==JSON.stringify(expected.existing_foliage))
 assert(plants.get_meta("budget").accepted==47 and plants.get_meta("budget").triangles==38148)
 assert(Codec.encode(world.state,world.inventory,world.request,world.craft,world.onboarding,world.fishing)==before)
 report["station_added_protected_polygon_count"]=1;report["original_masks_exact_after_explicit_collider_exclusion"]=true
 report["state_unchanged"]=true;report["state"]=before
 FileAccess.open(output+"/geometry-proof.json",FileAccess.WRITE).store_string(JSON.stringify(report))
 print("COOKING_ADDITIVE_GEOMETRY_PASS")
 var route_union=world.get_meta('bundle_route_report').union
 assert(route_union.source_count==32 and route_union.triangles==364 and route_union.scanline_mismatches==0)
 report['park_explicit_polygons']=actual_park;report['park_structure']=structure
 var contact=world.get_meta('bundle_route_result').connector_contact;assert(contact.triangles==29 and not contact.market_mesh_changed);report['contact']=contact
 var west=world.park_west_visuals.visual;assert(is_instance_valid(west))
 var west_binding=JSON.parse_string(FileAccess.get_file_as_string('res://assets/park_west/binding.json'))
 var West=load('res://scripts/park_west_visuals.gd')
 assert(West.inspect_candidate(west,west_binding).ok)
 var identity=West.retained_shrub_bound(world,west_binding.retained_shrub);assert(identity.ok)
 var retained:Dictionary=west_binding.retained_shrub.duplicate(true);retained['ok']=true
 var clearance=load(get_script().resource_path.get_base_dir().path_join('west_clearance.gd')).inspect(world,west,retained)
 assert(clearance.ok and clearance.group_count==11 and clearance.triangles==18742)
 var expected_path=get_script().resource_path.get_base_dir().path_join('expected-west-bounds.json')
 assert(FileAccess.get_sha256(expected_path)=='9aa08134fc3a7f59b0bf442a17c3f99909308480fb9b1f0d340802a28d3b4d95')
 var expected_bounds=JSON.parse_string(FileAccess.get_file_as_string(expected_path))
 assert(JSON.stringify(world.park_west_visuals.result.bounds)==JSON.stringify(expected_bounds))
 var edge=west.get_node('FlushStoneEdge');var edge_meshes=edge.find_children('*','MeshInstance3D',true,false);assert(edge_meshes.size()==31)
 var edge_triangles=0
 for mesh in edge_meshes:
  edge_triangles+=mesh.mesh.get_faces().size()/3
  assert(mesh.material_override is ShaderMaterial)
  assert(FileAccess.get_sha256(mesh.material_override.shader.resource_path)=='e184c96318cff88abf8d178210cab349c88eec8545a6cda24716b0607e0ae1fc')
 assert(edge_triangles==62)
 report['west_clearance']=clearance;report['west_bounds']=world.park_west_visuals.result.bounds;report['west_edge_triangles']=edge_triangles
 assert(not world.get_node('MaraStewardPlaceholder').visible)
 var old_position=world.player.global_position;var services=[]
 for at in [Vector3(5.5,.24,-26.5),Vector3(9.5,.24,-29.1),Vector3(5,.24,-17.5)]:
  world.player.global_position=at;services.append(world.can_use_steward())
 world.player.global_position=old_position;assert(services==[true,false,false])
 var capsule=CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.8;var hits=[]
 for at in [Vector3(0,1.17,-16),Vector3(0,1.17,-20),Vector3(0,1.17,-26),Vector3(5.5,1.17,-26.5),Vector3(5,1.17,-17.4)]:
  var query=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,at);query.exclude=[world.player.get_rid()]
  hits.append(world.get_world_3d().direct_space_state.intersect_shape(query,8).size())
 assert(hits==[0,0,0,0,0])
 assert(actors[3].animator.get_animation_library('')!=actors[4].animator.get_animation_library(''))
 report['hall_services']=services;report['hall_route_hits']=hits;report['actor_identities']=actor_names
 report['route_union']=route_union;report['coverage_actors']=5;report['staged_activation_checked']=true
 for actor in actors:
  assert(actor.find_children('*','CollisionObject3D',true,false).is_empty())
  actor.on_screen=false;actor._sync();assert(actor.visual.process_mode==Node.PROCESS_MODE_DISABLED)
  actor.on_screen=true;actor._sync();assert(actor.visual.process_mode==Node.PROCESS_MODE_INHERIT)
 assert(actors[1].animator.get_animation(actors[1].idle_name)!=actors[2].animator.get_animation(actors[2].idle_name))
 world.player.global_position=Vector3(6,.15,19.6);assert(world.dan_accessible())
 world.player.global_position=Vector3(30,.15,32.8);assert(world.supplies_accessible(false))
 world.player.global_position=Vector3(-4.5,.15,2);assert(world.supplies_accessible(true))
 report['dan_rook_west_access']=true
 report['dependency_closure']=dependency
 report['normal_startup_accepted']=true
 for i in range(buffers.size()):assert(plants.get_child(i).multimesh.buffer==buffers[i])
 report['plant_buffers_unchanged']=true
 FileAccess.open(output+'/result.json',FileAccess.WRITE).store_string(JSON.stringify(report))
 var held=station.session;var weak=weakref(station);var park_weak=weakref(baked);var west_weak=weakref(west);var hall_weak=weakref(actors[3])
 world.queue_free();await process_frame;assert(held.disposed and weak.get_ref()==null and park_weak.get_ref()==null and west_weak.get_ref()==null and hall_weak.get_ref()==null);print("REBUILT_COMBINED_NATIVE_EQUIVALENCE_PASS: exact original masks, cylinder,47plants,20park polygons,10west plants/62edge,contact,route,5actor identities/Hall services,Save21,dependencies and disposal; not a repeat of full interaction tests");quit()
