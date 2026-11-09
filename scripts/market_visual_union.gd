extends RefCounted
const ROOK_APRON=Rect2(28,27,4,3)
const Union=preload('res://scripts/route_union.gd')
static func hull(mesh:Mesh,t:Transform3D)->PackedVector2Array:
 var points=PackedVector2Array()
 for v in mesh.get_faces():
  var w=t*v;points.append(Vector2(w.x,w.z))
 return Geometry2D.convex_hull(points)
static func prepare(world:Node3D,material:Material)->Dictionary:
 var market=world.get_node_or_null('MarketExpansion')
 if market==null or world.global_transform!=Transform3D.IDENTITY or market.has_node('MarketRouteExactVisualUnion'):return {'error':'Unknown or already installed world'}
 var source=[];var discs=[];var replacements=[];var routes=0
 for n in market.get_children():
  if n is MeshInstance3D and n.mesh is CylinderMesh:
   if not is_equal_approx(n.mesh.top_radius,2) or not is_equal_approx(n.mesh.height,.08) or not is_equal_approx(n.global_position.y,.008):return {'error':'Unknown market disc'}
   source.append(hull(n.mesh,n.global_transform));discs.append({'node':n,'visible':n.visible,'mesh':n.mesh,'transform':n.global_transform})
 for batch in market.find_children('*','MultiMeshInstance3D',true,false):
  var old=batch.material_override
  if not old is ShaderMaterial or old.shader!=world.COURTYARD_SHADER or old.get_shader_parameter('tint')!=Color(.46,.44,.38,1):continue
  var mm=batch.multimesh;var keep=[];var removed=0
  for i in range(mm.instance_count):
   var t=batch.global_transform*mm.get_instance_transform(i);var bounds=t*mm.mesh.get_aabb()
   if bounds.end.y>=.035 and bounds.end.y<=.060:
    var size=t.basis.get_scale()
    if not is_equal_approx(size.y,.08) or not (is_equal_approx(size.x,4) or is_equal_approx(size.z,3.4)):return {'error':'Unknown market route instance'}
    source.append(hull(mm.mesh,t));removed+=1
   else:keep.append(i)
  if removed==0:continue
  var candidate=MultiMesh.new();candidate.transform_format=mm.transform_format;candidate.use_colors=mm.use_colors;candidate.use_custom_data=mm.use_custom_data;candidate.mesh=mm.mesh;candidate.instance_count=keep.size()
  for j in range(keep.size()):
   var i=keep[j];candidate.set_instance_transform(j,mm.get_instance_transform(i))
   if mm.use_colors:candidate.set_instance_color(j,mm.get_instance_color(i))
   if mm.use_custom_data:candidate.set_instance_custom_data(j,mm.get_instance_custom_data(i))
  replacements.append({'node':batch,'original':mm,'candidate':candidate,'buffer':mm.buffer.duplicate(),'transform':batch.global_transform});routes+=removed
 if discs.size()!=16 or routes!=16:return {'error':'Expected exactly16 discs and16 route instances','disc_count':discs.size(),'route_count':routes}
 # The Rook apron was a separate brown slab over the shared route. Include
 # a symmetric apron centered on the doorway so paving contact is continuous.
 # Preserve the original node and every collision/audio/grass mask.
 var rook=world.get_node_or_null('EastTraderFrontage/Rook connector')
 if not rook is MeshInstance3D or not rook.mesh is BoxMesh:return {'error':'Unknown Rook approach'}
 if not rook.global_position.is_equal_approx(Vector3(30.5,.015,28.5)) or not rook.mesh.size.is_equal_approx(Vector3(3,.08,3)):return {'error':'Rook approach geometry changed'}
 source.append(PackedVector2Array([ROOK_APRON.position,Vector2(ROOK_APRON.end.x,ROOK_APRON.position.y),ROOK_APRON.end,Vector2(ROOK_APRON.position.x,ROOK_APRON.end.y)]))
 discs.append({'node':rook,'visible':rook.visible,'mesh':rook.mesh,'transform':rook.global_transform})
 var built=Union.build(source,material)
 if not built.has('mesh') or built.mesh==null:return {'error':built.get('error','Union build failed')}
 return {'built':built,'discs':discs,'replacements':replacements,'market':market}
static func valid(prepared:Dictionary)->bool:
 if prepared.has('error') or not is_instance_valid(prepared.get('market')) or prepared.market.has_node('MarketRouteExactVisualUnion'):return false
 for r in prepared.replacements:
  if not is_instance_valid(r.node) or r.node.multimesh!=r.original or r.original.buffer!=r.buffer or r.node.global_transform!=r.transform:return false
 for r in prepared.discs:
  if not is_instance_valid(r.node) or r.node.mesh!=r.mesh or r.node.global_transform!=r.transform or r.node.visible!=r.visible:return false
 return true
static func install(prepared:Dictionary)->MeshInstance3D:
 # Validate the entire transaction before first visible mutation. No await inside commit.
 if not valid(prepared):return null
 var node=MeshInstance3D.new();node.name='MarketRouteExactVisualUnion';node.mesh=prepared.built.mesh
 prepared.market.add_child(node);node.global_transform=Transform3D.IDENTITY
 for r in prepared.replacements:r.node.multimesh=r.candidate
 for r in prepared.discs:r.node.visible=false
 return node
static func rollback(prepared:Dictionary,node:MeshInstance3D):
 for r in prepared.replacements:
  if is_instance_valid(r.node):r.node.multimesh=r.original
 for r in prepared.discs:
  if is_instance_valid(r.node):r.node.visible=r.visible
 if is_instance_valid(node):node.get_parent().remove_child(node);node.queue_free()

# Called after the last grass layer is installed, inside the startup barrier.
# Expand only the left shoulder; keep the accepted right edge and all collision.
static func finish_rook_approach(world:Node3D)->Dictionary:
 if world.has_meta('rook_centered_approach'):return world.get_meta('rook_centered_approach')
 var poly=PackedVector2Array([ROOK_APRON.position,Vector2(ROOK_APRON.end.x,ROOK_APRON.position.y),ROOK_APRON.end,Vector2(ROOK_APRON.position.x,ROOK_APRON.end.y)])
 var market=world.get_node_or_null('MarketExpansion')
 var paths=world.get_node_or_null('PathFoliageFinish')
 if market==null or paths==null:return {'ok':false,'reason':'Rook paving owners missing'}
 var prepared=[];var journal=[]
 var before_counts={'all':0,'near':0,'far':0};var removed_counts={'all':0,'near':0,'far':0}
 var removed=0;var batches=0
 for batch in world.find_children('*','MultiMeshInstance3D',true,false):
  if world.startup_cancel_requested:return {'ok':false,'reason':'Loading cancelled before Rook grass commit'}
  var label=str(batch.name).to_lower()
  if not ('grass' in label or label.begins_with('lawnchunk_') or label.begins_with('groundnear_') or label.begins_with('groundfar_')):continue
  if batch.multimesh==null or batch.multimesh.mesh==null:continue
  var kind='near' if label.begins_with('groundnear_') else ('far' if label.begins_with('groundfar_') else 'other')
  before_counts.all+=batch.multimesh.instance_count
  if kind!='other':before_counts[kind]+=batch.multimesh.instance_count
  var whole=batch.global_transform*batch.get_aabb()
  if not Rect2(Vector2(whole.position.x,whole.position.z),Vector2(whole.size.x,whole.size.z)).intersects(ROOK_APRON):continue
  var old=batch.multimesh;var keep=[];var rejected=[];var shown=0
  for i in old.instance_count:
   var t=batch.global_transform*old.get_instance_transform(i)
   var bounds=t*old.mesh.get_aabb()
   var footprint=Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))
   if footprint.intersects(ROOK_APRON):removed+=1;rejected.append(i);continue
   keep.append(i)
   if old.visible_instance_count<0 or i<old.visible_instance_count:shown+=1
  if keep.size()==old.instance_count:continue
  var next=old.duplicate() as MultiMesh;next.instance_count=keep.size()
  for j in keep.size():
   var i=keep[j];next.set_instance_transform(j,old.get_instance_transform(i))
   if old.use_colors:next.set_instance_color(j,old.get_instance_color(i))
   if old.use_custom_data:next.set_instance_custom_data(j,old.get_instance_custom_data(i))
  next.visible_instance_count=-1 if old.visible_instance_count<0 else shown
  # Exact retained-buffer proof; no unreviewed repositioning of neighbouring grass.
  var source_buffer=old.buffer;var result_buffer=next.buffer
  var stride=int(source_buffer.size()/old.instance_count)
  if result_buffer.size()!=keep.size()*stride:return {'ok':false,'reason':'Rook grass buffer size mismatch'}
  var source_bytes=source_buffer.to_byte_array();var result_bytes=result_buffer.to_byte_array()
  var row_bytes=stride*4
  for j in keep.size():
   if result_bytes.slice(j*row_bytes,(j+1)*row_bytes)!=source_bytes.slice(keep[j]*row_bytes,(keep[j]+1)*row_bytes):return {'ok':false,'reason':'Rook grass retained buffer changed'}
  for i in rejected:
   var ab=batch.global_transform*old.get_instance_transform(i)*old.mesh.get_aabb()
   if not Rect2(Vector2(ab.position.x,ab.position.z),Vector2(ab.size.x,ab.size.z)).intersects(ROOK_APRON):return {'ok':false,'reason':'Grass removal outside Rook apron'}
  removed_counts.all+=rejected.size()
  if kind!='other':removed_counts[kind]+=rejected.size()
  journal.append({'batch':str(world.get_path_to(batch)),'kind':kind,'before':old.instance_count,'after':next.instance_count,'removed':rejected.size(),'retained_buffer_exact':true,'removed_bounds_verified':true})
  var selected_meta=null
  if batch.has_meta('source_transforms'):
   var original=batch.get_meta('source_transforms')
   if original is Array and original.size()==old.instance_count:
    var selected=[]
    for i in keep:selected.append(original[i])
    selected_meta=selected
  prepared.append({'batch':batch,'before':old,'next':next,'metadata':selected_meta});batches+=1
 # No await from validation through commit: cancellation cannot expose half a trim.
 if world.startup_cancel_requested:return {'ok':false,'reason':'Loading cancelled before Rook grass commit'}
 for entry in prepared:
  if not is_instance_valid(entry.batch) or entry.batch.multimesh!=entry.before:return {'ok':false,'reason':'Grass changed before Rook commit'}
 for entry in prepared:
  entry.batch.multimesh=entry.next
  if entry.metadata!=null:entry.batch.set_meta('source_transforms',entry.metadata)
 var masks=market.get_meta('paving_polygons',[]).duplicate();masks.append(poly);market.set_meta('paving_polygons',masks)
 if paths!=null:
  var routes=paths.get_meta('route_polygons',[]).duplicate();routes.append(poly);paths.set_meta('route_polygons',routes)
 for body in world.find_children('*','StaticBody3D',true,false):
  if body.has_meta('audio_ground_regions'):
   var audio=body.get_meta('market_paving_polygons',[]).duplicate();audio.append(poly);body.set_meta('market_paving_polygons',audio)
 var after_counts={}
 for key in before_counts:after_counts[key]=before_counts[key]-removed_counts[key]
 var result={'before_counts':before_counts,'after_counts':after_counts,'removed_counts':removed_counts,'journal':journal,'ok':true,'center_x':30.0,'width':4.0,'grass_instances_removed':removed,'grass_batches_updated':batches,'collision_changes':0,'paving_mask_added':poly}
 world.set_meta('rook_centered_approach',result)
 return result
