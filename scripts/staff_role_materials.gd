extends RefCounted
## Prepare every private override before changing any surface; no shared mutation.
static func apply_to(visual:Node3D,role:String)->bool:
 if not is_instance_valid(visual) or role not in ['Rook','West']:return false
 var tint=Color('#bca985') if role=='Rook' else Color('#8faaa1')
 var changes=[]
 for mesh in visual.find_children('*','MeshInstance3D',true,false):
  if not str(mesh.name).begins_with('StaffWorkwear'):continue
  if mesh.mesh==null:return false
  for surface in range(mesh.mesh.get_surface_count()):
   var original=mesh.get_active_material(surface)
   if not original is StandardMaterial3D:return false
   var local=original.duplicate();local.resource_local_to_scene=true;local.albedo_color=tint;local.roughness=.88
   changes.append({'mesh':mesh,'surface':surface,'original':original,'replacement':local})
 if changes.is_empty():return false
 for change in changes:
  if not is_instance_valid(change.mesh) or change.mesh.get_active_material(change.surface)!=change.original:return false
 for change in changes:change.mesh.set_surface_override_material(change.surface,change.replacement)
 return true
