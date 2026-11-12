extends RefCounted
# TEST ONLY: inspect installed baked geometry; never regenerate terrain/art or install overlays.
const Plants=preload('res://scripts/intentional_planting_pockets.gd')
const Baked=preload('res://scripts/park_layered_visuals.gd')
const SHRUBS=['ParkAlienShrub0','ParkAlienShrub1','ParkAlienShrub2']
static func under(node:Node,ancestor:Node)->bool:return node==ancestor or ancestor.is_ancestor_of(node)
static func digest(value)->String:return var_to_bytes(value).hex_encode().sha256_text()
static func inspect(world:Node3D,bakedroot:Node3D,binding:Dictionary)->Dictionary:
 if not binding.get('ok',false):return {'ok':false,'reason':'Exact retained shrub identity not bound'}
 var park=world.get_node('HallRoutePark');var tree=park.get_node('ParkAlienTree')
 assert(tree.visible and tree.is_visible_in_tree())
 var retained=[];var retained_receipts=[]
 for name in SHRUBS:
  var shrub=park.get_node(name);assert(shrub.visible and shrub.is_visible_in_tree())
  assert(shrub.find_children('*','CollisionShape3D',true,false).is_empty())
  retained.append(shrub);retained_receipts.append({'path':str(world.get_path_to(shrub)),'transform':str(shrub.global_transform),'visible':shrub.visible})
 # Exact owner keepouts: semantic routes, extra path footprints, tall local solids, seat exits.
 var keepouts=Plants.semantic_masks(world);var names=[]
 for i in range(keepouts.size()):names.append('intentional_planting_pockets.semantic_masks['+str(i)+']')
 var paths=world.get_node('PathFoliageFinish').get_meta('route_polygons')
 for i in range(paths.size()):keepouts.append(paths[i]);names.append('PathFoliageFinish.route_polygons['+str(i)+']')
 for shape in world.find_children('*','CollisionShape3D',true,false):
  if shape.disabled or shape.shape==null:continue
  var box=shape.global_transform*shape.shape.get_debug_mesh().get_aabb()
  if box.size.x<60 and box.size.z<60 and box.end.y>.25:keepouts.append(Plants.rectangle(box));names.append(str(shape.get_path()))
 for bench in world.get_tree().get_nodes_in_group('usable_seats'):
  if not world.is_ancestor_of(bench):continue
  for exit_at in bench.get_meta('seat_exit_local',[]):
   var at=bench.to_global(exit_at);keepouts.append(Plants.rectangle(AABB(at-Vector3(.75,0,.75),Vector3(1.5,2,1.5))));names.append(str(bench.get_path())+' seat exit '+str(exit_at))
 # Exact owner decorative selection. Only the fixed tree and three retained shrubs are exceptions.
 var foliage=[];var labels=[];var exceptions=[]
 for root_name in ['NaturalBorder','SouthernGroundcover','WalkwayPlanting','RouteGardens','ReferenceFoliage','RaisedHideoutTerrace','MarketSurroundings','HallRoutePark']:
  var holder=world.get_node_or_null(root_name)
  if holder==null:continue
  for batch in holder.find_children('*','MultiMeshInstance3D',true,false):
   if not batch.visible or 'grass' in str(batch.name).to_lower():continue
   for i in range(batch.multimesh.instance_count):
    if str(world.get_path_to(batch))==binding.path and i==binding.instance:
     if digest(batch.multimesh.get_instance_transform(i))!=binding.transform_sha:return {'ok':false,'reason':'Bound retained shrub transform changed'}
     exceptions.append({'path':binding.path,'instance':i,'reason':'exact approved retained shrub overlap; no mutation'});continue
    foliage.append(Plants.rectangle(batch.global_transform*batch.multimesh.get_instance_transform(i)*batch.multimesh.mesh.get_aabb()));labels.append(str(batch.get_path())+' instance '+str(i))
  for mesh in holder.find_children('*','MeshInstance3D',true,false):
   if not mesh.visible or mesh.mesh==null:continue
   var reason=''
   if under(mesh,tree):reason='fixed tree: 1m root and actual .2m branch-height checks replace canopy AABB'
   for shrub in retained:
    if under(mesh,shrub):reason='fixed retained bed shrub: deliberate foliage overlap allowed, no removal'
   var box=mesh.global_transform*mesh.mesh.get_aabb()
   if reason!='':exceptions.append({'path':str(world.get_path_to(mesh)),'bounds':str(box),'reason':reason})
   else:foliage.append(Plants.rectangle(box));labels.append(str(mesh.get_path()))
 for garden in world.find_children('LocalMarketSurroundings','Node3D',true,false):
  for mesh in garden.find_children('*','MeshInstance3D',true,false):
   if mesh.visible and mesh.mesh!=null:foliage.append(Plants.rectangle(mesh.global_transform*mesh.mesh.get_aabb()));labels.append(str(mesh.get_path()))
 var groups=[];var rejected=[];var triangles=0
 for group in bakedroot.get_children():
  for mesh in group.find_children('*','MeshInstance3D',true,false):
   var box=mesh.global_transform*mesh.mesh.get_aabb()
   var reasons=[]
   var footprint=Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
   if not Rect2(-23.3,-22.5,4.25,6.0).encloses(footprint):reasons.append({'authority':'approved decorative envelope','bounds':str(box)})
   if not root_clear(box):reasons.append({'authority':'ParkAlienTree 1m root'})
   for k in range(keepouts.size()):
    if Plants.overlap(box,[keepouts[k]],.5):reasons.append({'authority':'route/seat/physical','name':names[k],'polygon':str(keepouts[k])})
   for k in range(foliage.size()):
    if Plants.overlap(box,[foliage[k]],.08):reasons.append({'authority':'retained decoration','name':labels[k],'polygon':str(foliage[k])})
   if not branch_clear(world,box):reasons.append({'authority':'ParkAlienTree .2m branch','detail':last_branch_reason.duplicate(true)})
   # Full triangle heights and root anchors for every NaturalBorder tree instance.
   for batch in world.get_node('NaturalBorder').find_children('*','MultiMeshInstance3D',true,false):
    if not String(batch.name).begins_with('border_tree_'):continue
    for i in range(batch.multimesh.instance_count):
     var t=batch.global_transform*batch.multimesh.get_instance_transform(i)
     var nearest=Vector2(clampf(t.origin.x,box.position.x,box.end.x),clampf(t.origin.z,box.position.z,box.end.z))
     if nearest.distance_to(Vector2(t.origin.x,t.origin.z))<1.0:reasons.append({'authority':'retained tree 1m root','path':str(batch.get_path()),'instance':i})
     var tree_box=t*batch.multimesh.mesh.get_aabb()
     if not Rect2(Vector2(tree_box.position.x,tree_box.position.z),Vector2(tree_box.size.x,tree_box.size.z)).intersects(footprint,true):continue
     var faces=batch.multimesh.mesh.get_faces()
     for j in range(0,faces.size(),3):
      var aa=t*faces[j];var bb=t*faces[j+1];var cc=t*faces[j+2]
      var low=Vector2(minf(aa.x,minf(bb.x,cc.x)),minf(aa.z,minf(bb.z,cc.z)))
      var high=Vector2(maxf(aa.x,maxf(bb.x,cc.x)),maxf(aa.z,maxf(bb.z,cc.z)))
      if Rect2(low,high-low).intersects(footprint,true) and minf(aa.y,minf(bb.y,cc.y))<box.end.y+.2:
       reasons.append({'authority':'retained tree .2m branch','path':str(batch.get_path()),'instance':i,'triangle':j/3});break
   var count=mesh.mesh.get_faces().size()/3;triangles+=count
   var row={'name':String(group.name),'mesh':String(mesh.name),'bounds':str(box),'triangles':count,'reasons':reasons}
   groups.append(row)
   if not reasons.is_empty():rejected.append(row)
 var original=world.get_node('IntentionalPlantingPockets');assert(original.get_meta('budget').accepted==47)
 var buffers=[]
 for batch in original.get_children():
  assert(batch is MultiMeshInstance3D);buffers.append({'name':String(batch.name),'count':batch.multimesh.instance_count,'buffer_sha':digest(batch.multimesh.buffer)})
 if bakedroot.get_child_count()!=11 or triangles<18680 or triangles>19080:return {'ok':false,'reason':'Whole composition group/triangle budget mismatch','triangles':triangles}
 return {'ok':rejected.is_empty(),'groups':groups,'group_count':bakedroot.get_child_count(),'triangles':triangles,'rejected':rejected,'keepout_count':keepouts.size(),'decoration_count':foliage.size(),'decorative_exceptions':exceptions,'retained_shrubs':retained_receipts,'tree_transform':str(tree.global_transform),'baseline_plant_budget':original.get_meta('budget'),'baseline_plant_buffers':buffers,'rules':{'physical_margin':.5,'decoration_margin':.08,'root_radius':1.0,'branch_height':.2},'scope':'Actual baked bounds against exact owner predicates; no terrain reconstruction; buffer hashes require before/after comparison by caller'}

const CENTER=Vector2(-20.3,-19.4)
static func root_clear(box:AABB)->bool:
 var nearest=Vector2(clampf(CENTER.x,box.position.x,box.end.x),clampf(CENTER.y,box.position.z,box.end.z))
 return nearest.distance_to(CENTER)>=1.0
static var last_branch_reason={}
static func branch_clear(world:Node3D,box:AABB)->bool:
 last_branch_reason={}
 var tree=world.get_node('HallRoutePark/ParkAlienTree')
 var footprint=Plants.rectangle(box)
 for mesh in tree.find_children('*','MeshInstance3D',true,false):
  var faces=mesh.mesh.get_faces()
  for i in range(0,faces.size(),3):
   var a=mesh.global_transform*faces[i];var b=mesh.global_transform*faces[i+1];var c=mesh.global_transform*faces[i+2]
   var flat=PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])
   # Conservative projection bounds also catch nearly vertical branches.
   var low=Vector2(minf(a.x,minf(b.x,c.x)),minf(a.z,minf(b.z,c.z)))
   var high=Vector2(maxf(a.x,maxf(b.x,c.x)),maxf(a.z,maxf(b.z,c.z)))
   var overlaps=Rect2(low,high-low).intersects(Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)),true)
   if overlaps and minf(a.y,minf(b.y,c.y))<box.end.y+.20:
    last_branch_reason={'path':str(mesh.get_path()),'triangle_index':i/3,'triangle':[str(a),str(b),str(c)],'plant_bounds':str(box),'required_min_branch_y':box.end.y+.20};return false
 return true
