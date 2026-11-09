extends Node3D
# Authored, baked composition. No gameplay save writes or player relocation.
const SCENE=preload('res://assets/plaza_islands/composition.scn')
const COVERAGE=preload('res://assets/plaza_islands/coverage_v085.scn')
const Seat=preload('res://scripts/seat_interaction.gd')
const QUALITY=[Vector2(30,22),Vector2(65,35),Vector2(120,55),Vector2(220,85)]
var host
var visual:Node3D
var attempted=false
var result={}
var polygons:Array=[]
var new_polygons:Array=[]
var original_polygons:Array=[]
var quality=2
var elapsed=0.0
var hidden=[]
var replacements=[]
func setup(world):
 host=world;name='PlazaIslandLandscape';set_process(false)
func begin_after_activation(world):
 if attempted:return
 attempted=true;host=world;call_deferred('install_when_ready')
func installation_active()->bool:
 return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(host) and host.is_inside_tree() and not host.is_queued_for_deletion() and not host.startup_cancel_requested
func install_when_ready():
 if not installation_active():return
 var start=Time.get_ticks_msec()
 for key in ['four_area_gardens','market_edge_gardens','hall_east_spur_gardens','path_shoulder_gardens','inn_site']:
  var controller=host.get(key)
  while is_instance_valid(controller) and controller.get('result') is Dictionary and controller.result.is_empty():
   if Time.get_ticks_msec()-start>180000:result={'ok':false,'reason':'Previous landscaping did not finish','controller':key};return
   await get_tree().process_frame
   if not installation_active():return
 if not installation_active():return
 visual=SCENE.instantiate();visual.name='PlazaIslandComposition'
 visual.add_child(COVERAGE.instantiate())
 configure_grass_materials()
 var data=JSON.parse_string(FileAccess.get_file_as_string('res://assets/plaza_islands/polygons.json'))
 for role in data:
  var polygon=PackedVector2Array()
  for p in data[role].polygon_xz:polygon.append(Vector2(p[0],p[1]))
  polygons.append(polygon)
  # Additive roles are display/count geometry, never old-flora cleanup authority.
  if is_additive_preserve_role(str(role)):continue
  if role not in ["left","right"]:new_polygons.append(polygon)
  else:original_polygons.append(polygon)
 add_to_group('plaza_grass_quality')
 quality=load('res://scripts/game_settings.gd').new().current_grass_quality(self)
 set_process(true);try_install()
func _process(delta):
 elapsed+=delta
 if elapsed<.25:return
 elapsed=0;try_install()
func player_overlaps()->bool:
 if not is_instance_valid(host.player):return false
 var player_box=AABB(host.player.global_position+Vector3(-.55,0,-.55),Vector3(1.1,2.1,1.1))
 for collider in visual.find_children('*','CollisionShape3D',true,false):
  if collider.shape==null:continue
  var t=collider.transform;var parent=collider.get_parent()
  while parent!=visual and parent is Node3D:t=parent.transform*t;parent=parent.get_parent()
  var mesh=collider.shape.get_debug_mesh()
  if mesh!=null and player_box.intersects(t*mesh.get_aabb()):return true
 return false
func try_install():
 if not installation_active():set_process(false);return
 if not is_instance_valid(visual):set_process(false);return
 if player_overlaps():result={'ok':false,'pending':true,'reason':'Waiting for player to clear new solid objects'};return
 replace_old_planting()
 host.add_child(visual)
 for bench in visual.find_children('GardenBench*','Node3D',true,false):Seat.register_bench(bench)
 set_quality(quality);set_process(false)
 result={'ok':true,'scope':'Requested plaza and shop-side landscaping','quality':quality,'bed_count':polygons.size(),'composition':visual.get_meta('landscape_manifest',{})}
 print('PLAZA_ISLANDS_READY ',result)
func is_additive_preserve_role(role:String)->bool:
 if role=="PsyAtlasForegroundGarden0":return true
 const PREFIX="hall_west_front_preserve_"
 if not role.begins_with(PREFIX):return false
 var suffix=role.substr(PREFIX.length())
 return suffix.is_valid_int() and int(suffix)>=0 and str(int(suffix))==suffix
func in_islands(p:Vector2)->bool:
 for polygon in polygons:
  if Geometry2D.is_point_in_polygon(p,polygon):return true
 return false
func in_original_islands(p:Vector2)->bool:
 for polygon in original_polygons:
  if Geometry2D.is_point_in_polygon(p,polygon):return true
 return false
func in_new_beds(p:Vector2)->bool:
 for polygon in new_polygons:
  if Geometry2D.is_point_in_polygon(p,polygon):return true
 return false
func replace_old_planting():
 var legacy=host.get_node_or_null('FourAreaGardens')
 if legacy!=null:
  for name in ['ShipViewIsland','FountainEastBorder']:
   var node=legacy.get_node_or_null(name)
   if node!=null:
    hidden.append(node);node.visible=false
    for body in node.find_children('*','CollisionObject3D',true,false):
     body.collision_layer=0;body.collision_mask=0
 var lawn_owner=host.get_node_or_null('ContinuousGrass')
 var lawn_name=RegEx.new();var lawn_error=lawn_name.compile('^LawnChunk_-?[0-9]+_-?[0-9]+$');assert(lawn_error==OK)
 var natural_border=host.get_node_or_null('NaturalBorder')
 for batch in host.find_children('*','MultiMeshInstance3D',true,false):
  if batch.multimesh==null or batch.multimesh.mesh==null or not batch.is_visible_in_tree():continue
  var label=str(batch.name).to_lower();var match_name=false
  for token in ['ground_','grass','fern','flower','shrub','broadleaf_mound','clover']:
   if token in label:match_name=true;break
  var exact_lawn=batch.get_parent()==lawn_owner and lawn_name.search(str(batch.name))!=null
  if not match_name and not exact_lawn:continue
  var old:MultiMesh=batch.multimesh;var keep=[]
  for i in range(old.instance_count):
   var t=batch.global_transform*old.get_instance_transform(i);var b=t*old.mesh.get_aabb()
   var root_xz=Vector2(t.origin.x,t.origin.z)
   if batch.get_parent()!=natural_border and in_new_beds(root_xz) and b.size.y<=1.5 and b.end.y-t.origin.y<=1.8:continue
   if not exact_lawn and b.size.y<=1.5 and b.end.y<=1.8 and in_original_islands(root_xz):continue
   keep.append(i)
  if keep.size()==old.instance_count:continue
  var next=old.duplicate() as MultiMesh;next.instance_count=keep.size()
  var shown=0
  for i in keep:
   if old.visible_instance_count<0 or i<old.visible_instance_count:shown+=1
  next.visible_instance_count=-1 if old.visible_instance_count<0 else shown
  for j in range(keep.size()):
   var i=keep[j];next.set_instance_transform(j,old.get_instance_transform(i))
   if old.use_colors:next.set_instance_color(j,old.get_instance_color(i))
   if old.use_custom_data:next.set_instance_custom_data(j,old.get_instance_custom_data(i))
  var original_meta=batch.get_meta('source_transforms') if batch.has_meta('source_transforms') else null
  var synchronized=original_meta is Array and original_meta.size()==old.instance_count
  if synchronized:
   var selected_meta=[]
   for index in keep:selected_meta.append(original_meta[index])
   batch.set_meta('source_transforms',selected_meta)
  replacements.append({'batch':batch,'original':old,'replacement':next,'source_transforms':original_meta,'metadata_synchronized':synchronized});batch.multimesh=next
func set_quality(value:int):
 quality=clampi(value,0,3)
 if not is_instance_valid(visual):return
 for batch in visual.find_children('Grass_*','MultiMeshInstance3D',true,false):
  var ratio=QUALITY[quality].x/220.0
  # Keep the slim path-edge seam continuous at every preset. Field density still scales.
  if batch.get_meta('coverage_edge',false):ratio=1.0
  elif batch.get_meta('coverage_field',false):ratio=[.30,.65,1.0,1.0][quality]
  batch.multimesh.visible_instance_count=int(batch.multimesh.instance_count*ratio)
  batch.visibility_range_end=QUALITY[quality].y;batch.visibility_range_end_margin=5.0
func _exit_tree():
 # A player standing in the future footprint can defer attachment. Free that
 # detached scene if the world is closed/reloaded before it becomes safe.
 if is_instance_valid(visual) and visual.get_parent()==null:visual.free()
 visual=null
 replacements.clear();hidden.clear()

func configure_grass_materials():
 # Explicit Color parameters survive source_color resource serialization.
 # Work on local copies; never mutate the shared baked scene resource.
 var materials={}
 for batch in visual.find_children('Grass_*','MultiMeshInstance3D',true,false):
  var original=batch.material_override as ShaderMaterial
  if original==null:continue
  var key=original.get_instance_id()
  if not materials.has(key):
   var material=original.duplicate() as ShaderMaterial
   material.set_shader_parameter('color',Color(.14,.28,.06))
   material.set_shader_parameter('color2',Color(.48,.66,.22))
   materials[key]=material
  batch.material_override=materials[key]
