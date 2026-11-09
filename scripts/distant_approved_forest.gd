extends RefCounted
# Existing v034 approved border assets, reused without topology/material changes.
# Caller retains the entire original seeded generator and its RNG consumption.
const FILES=['border_tree_a','border_tree_b']
static func add_to(parent:Node3D,trunks:Array[Transform3D],crowns:Array[Transform3D],old_trunk:Mesh,old_crown:Mesh)->int:
 var groups=[[],[]];var journal=[];var phases=[[],[]]
 var meshes=[]
 for file in FILES:meshes.append(preload('res://scripts/foliage_wind.gd')._mesh(file))
 for i in range(trunks.size()):
  var root=trunks[i].origin-Vector3(0,trunks[i].basis.y.length()*.5,0)
  var old_bounds:AABB=trunks[i]*old_trunk.get_aabb()
  for j in range(6):old_bounds=old_bounds.merge(crowns[i*6+j]*old_crown.get_aabb())
  var variant=i%2;var mesh:Mesh=meshes[variant];var source=mesh.get_aabb()
  # Natural uniform scale: preserve old overall crown height, not old sphere width.
  var factor=(old_bounds.end.y-root.y)/source.end.y
  var transform=Transform3D(Basis(Vector3.UP,fposmod(i*2.3999632297,TAU)).scaled(Vector3.ONE*factor),root)
  groups[variant].append(transform);phases[variant].append(preload('res://scripts/foliage_wind.gd')._phase(root))
  journal.append({'index':i,'source':FILES[variant],'root':root,'transform':transform,'old_bounds':old_bounds,'new_bounds':transform*source})
 var triangles=0
 for k in range(2):
  var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.use_custom_data=true;mm.mesh=meshes[k];mm.instance_count=groups[k].size()
  for i in range(groups[k].size()):
   mm.set_instance_transform(i,groups[k][i]);mm.set_instance_color(i,Color.WHITE);mm.set_instance_custom_data(i,Color(phases[k][i],0,0,1))
  var batch=MultiMeshInstance3D.new();batch.name='DistantTree'+str(k);batch.multimesh=mm;batch.material_override=preload('res://scripts/foliage_wind.gd')._material(0.0)
  # Existing sun contact shadows make rooted valley trees read as attached to slopes.
  batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;batch.extra_cull_margin=.15
  batch.set_meta('instance_transforms',groups[k]);batch.set_meta('leaf_wind',true);parent.add_child(batch)
  triangles+=meshes[k].get_faces().size()/3*groups[k].size()
 parent.set_meta('approved_forest_journal',journal)
 parent.set_meta('approved_forest_budget',{'triangles':triangles,'batches':2,'textures':0,'new_colliders':0,'new_lights':0,'source_meshes':FILES})
 return triangles
