extends RefCounted
# Installed synchronously inside the existing landscape startup barrier.
# Only approved old vegetation roots inside the authored bed are removed.
# Main paving, home/steps, colliders and saves are never selected by this cleanup.
static func apply(world:Node3D,garden:Node3D,target:Node3D=null)->Dictionary:
 var polygon:PackedVector2Array=garden.get_meta('home_garden_manifest').outline
 var pad=world.get_node_or_null('CookingNookVisuals/ConnectedWorkPad') as MeshInstance3D
 var old_bed=world.get_node_or_null('MarketEdgeGardens/WestAvenueSouth') as Node3D
 if pad==null or pad.mesh==null or old_bed==null:return {'ok':false,'reason':'Expected home garden replacement targets missing'}
 var pad_bounds=pad.global_transform*pad.mesh.get_aabb()
 if pad_bounds.position.distance_to(Vector3(-12.1,-.04,6.15))>.02 or pad_bounds.size.distance_to(Vector3(5.32,.09,2.8))>.04:return {'ok':false,'reason':'Cooking work-pad identity changed'}
 # This is decorative former cooking paving, NOT either original stair approach slab.
 pad.visible=false
 old_bed.visible=false
 for body in old_bed.find_children('*','CollisionObject3D',true,false):
  body.collision_layer=0;body.collision_mask=0
 var removed=0
 for owner_name in ['WalkwayPlanting','SouthernGroundcover','ContinuousGrass','RouteGardens','RaisedHideoutTerrace','NaturalBorder']:
  var holder=world.get_node_or_null(owner_name)
  if holder==null:continue
  for batch in holder.find_children('*','MultiMeshInstance3D',true,false):
   if batch.multimesh==null:continue
   var label=str(batch.name).to_lower()
   if not ('grass' in label or 'flower' in label or 'shrub' in label or 'fern' in label or 'lawnchunk' in label or 'base planting' in label or 'border_tree' in label):continue
   var old=batch.multimesh
   var keep=[]
   for i in range(old.instance_count):
    var p=(batch.global_transform*old.get_instance_transform(i)).origin
    if p.y<.5 and p.y>-.3 and Vector2(p.x,p.z).length()>=10.02 and Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon):removed+=1
    else:keep.append(i)
   if keep.size()==old.instance_count:continue
   var next=old.duplicate() as MultiMesh;next.instance_count=keep.size();next.visible_instance_count=-1 if old.visible_instance_count<0 else mini(old.visible_instance_count,keep.size())
   for j in range(keep.size()):
    var i=keep[j];next.set_instance_transform(j,old.get_instance_transform(i))
    if old.use_colors:next.set_instance_color(j,old.get_instance_color(i))
    if old.use_custom_data:next.set_instance_custom_data(j,old.get_instance_custom_data(i))
   if batch.has_meta('source_transforms'):
    var records=batch.get_meta('source_transforms')
    if records is Array and records.size()==old.instance_count:
     var selected=[]
     for i in keep:selected.append(records[i])
     batch.set_meta('source_transforms',selected)
   batch.multimesh=next
 if target==null:target=world
 target.add_child(garden)
 return {'ok':true,'removed_old_low_plants':removed,'manifest':garden.get_meta('home_garden_manifest'),'slab_removal_verified':true,'old_tree_bed_replaced':'MarketEdgeGardens/WestAvenueSouth'}
