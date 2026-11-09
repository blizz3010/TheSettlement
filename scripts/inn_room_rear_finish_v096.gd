extends RefCounted
# Restrained intentional open-top room partitions and one local exterior material.
# Architecture, rooms, doors, fixtures, collision and lighting stay authoritative.
const Finish=preload('res://scripts/inn_guest_finish_v094.gd')
const Interior=preload('res://scripts/inn_interior_v094.gd')
const REAR_SURFACE=preload('res://shaders/inn_rear_plaster_v096.gdshader')
static func fail(reason:String)->Dictionary:
 return {'ok':false,'stage':'inn_room_rear_finish_v096','reason':reason}
static func valid_box(node:Node,size:Vector3,position:Vector3)->bool:
 return node is MeshInstance3D and node.mesh is BoxMesh and node.mesh.size.is_equal_approx(size) and node.position.is_equal_approx(position) and node.basis.is_equal_approx(Basis.IDENTITY)
static func preflight(inn:Node3D)->Dictionary:
 if not is_instance_valid(inn):return fail('Missing architecture owner')
 if inn.has_node('CappedGuestPartitionsV096'):return fail('Partition finish owner already exists without a valid completion receipt')
 var upper=inn.get_node_or_null('UpperRoomsAndLanding');var exterior=inn.get_node_or_null('ExteriorWalls')
 if not upper is Node3D or not upper.transform.is_equal_approx(Transform3D.IDENTITY):return fail('Upper room owner or transform changed')
 if not exterior is Node3D or not exterior.transform.is_equal_approx(Transform3D.IDENTITY):return fail('Exterior wall owner or transform changed')
 var rear=exterior.get_node_or_null('RearWall')
 if not valid_box(rear,Vector3(15.8,6.4,.20),Vector3(0,3.2,5.9)):return fail('Rear wall geometry changed')
 if not rear.material_override is StandardMaterial3D or not rear.material_override.albedo_color.is_equal_approx(Color('c6bba1')):return fail('Rear plaster material provenance changed')
 if not is_equal_approx(rear.material_override.roughness,.88) or not is_equal_approx(rear.material_override.metallic_specular,.5):return fail('Rear plaster response changed')
 var caps=[];var parts=[]
 # Plan all eight coping runs and sixteen reveals before creating any node.
 for spec in [['RoomDividerWest',Vector3(-2.7,4.7,3.4),4.6],['RoomDividerNorth',Vector3(-2.7,4.7,-2.85),3.5],['RoomEastWallNorth',Vector3(2.3,4.7,-2.85),3.5],['RoomEastWallSouth',Vector3(2.3,4.7,3.4),4.6]]:
  var label=spec[0];var wall=upper.get_node_or_null(label)
  if not valid_box(wall,Vector3(.14,3,spec[2]),spec[1]):return fail('Partition geometry changed: '+label)
  var sz:Vector3=wall.mesh.size;var top:float=wall.position.y+sz.y*.5
  var z0:float=wall.position.z-sz.z*.5;var z1:float=wall.position.z+sz.z*.5
  if is_equal_approx(z0,1.1):z0+=.0925
  if is_equal_approx(z1,-1.1):z1-=.0925
  var cap_size=Vector3(sz.x+.045,.09,z1-z0);var p=Vector3(wall.position.x,top+.045,(z0+z1)*.5)
  parts.append({'label':'Continuous partition coping '+label,'position':p,'size':cap_size,'material':'along'})
  for side in [-1,1]:parts.append({'label':'Partition top reveal '+label,'position':Vector3(wall.position.x+side*(sz.x*.5+.008),top-.025,wall.position.z),'size':Vector3(.016,.05,sz.z),'material':'edge'})
  caps.append({'wall':label,'center':p,'size':cap_size,'wall_top':top})
 for z in [-1.1,1.1]:
  for side in ['West','East']:
   var label='RoomDoor'+side+str(z).replace('.','_');var center_x=-5.2 if side=='West' else -.2
   var lintel=upper.get_node_or_null(label+'Lintel');var left=upper.get_node_or_null(label+'Left');var right=upper.get_node_or_null(label+'Right')
   var jamb_width=(5-.95)/2;var offset=(.95+jamb_width)/2
   if not valid_box(lintel,Vector3(.95,.75,.14),Vector3(center_x,5.825,z)):return fail('Door lintel geometry changed: '+label)
   if not valid_box(left,Vector3(jamb_width,3,.14),Vector3(center_x-offset,4.7,z)) or not valid_box(right,Vector3(jamb_width,3,.14),Vector3(center_x+offset,4.7,z)):return fail('Door jamb geometry changed: '+label)
   var x0:float=left.position.x-left.mesh.size.x*.5;var x1:float=right.position.x+right.mesh.size.x*.5
   if side=='East':x1+=.0925
   var top:float=lintel.position.y+lintel.mesh.size.y*.5;var p=Vector3((x0+x1)*.5,top+.045,z)
   parts.append({'label':'Continuous door-wall coping '+label,'position':p,'size':Vector3(x1-x0,.09,.185),'material':'across'})
   for face in [-1,1]:parts.append({'label':'Door-wall top reveal '+label,'position':Vector3((x0+x1)*.5,top-.025,z+face*.078),'size':Vector3(x1-x0,.05,.016),'material':'edge'})
   caps.append({'wall':label,'center':p,'size':Vector3(x1-x0,.09,.185),'wall_top':top})
 if caps.size()!=8 or parts.size()!=24:return fail('Incomplete partition finish plan')
 return {'ok':true,'rear':rear,'original':rear.material_override,'caps':caps,'parts':parts}
static func apply(inn:Node3D)->Dictionary:
 if not is_instance_valid(inn):return fail('Missing architecture owner')
 if inn.has_meta('inn_room_rear_finish_v096'):
  var receipt=inn.get_meta('inn_room_rear_finish_v096');var completed=inn.get_node_or_null('CappedGuestPartitionsV096');var rear=inn.get_node_or_null('ExteriorWalls/RearWall')
  if receipt is Dictionary and receipt.get('ok',false) and completed is Node3D and completed.get_child_count()==3 and rear is MeshInstance3D and rear.get_meta('local_finish_owner','')=='InnRearPlasterV096':return receipt
  return fail('Invalid partition or rear plaster completion receipt')
 var plan=preflight(inn)
 if not plan.get('ok',false):return plan
 # Build off-tree. No cap root or rear-material mutation can precede a complete
 # preflight, and construction checks below remain enabled in release builds.
 var root=Node3D.new();root.name='CappedGuestPartitionsV096'
 var materials={'across':Interior.finish('806044',0,0),'along':Interior.finish('806044',0,2),'edge':Interior.finish('644730',0,0)}
 for part in plan.parts:Finish.box(root,part.label,part.position,part.size,materials[part.material])
 Finish.batch(root)
 if root.get_meta('source_meshes',0)!=24 or root.get_meta('draw_surfaces',0)!=3 or not root.find_children('*','CollisionObject3D',true,false).is_empty():
  root.free();return fail('Detached partition output failed validation')
 var rear=plan.rear;var original=plan.original;var caps=plan.caps
 var local=ShaderMaterial.new();local.shader=REAR_SURFACE
 local.set_shader_parameter('original_tint',original.albedo_color);local.set_shader_parameter('exterior_tint',Color('b1a48a'))
 inn.add_child(root);rear.material_override=local;rear.set_meta('local_finish_owner','InnRearPlasterV096')
 var report={'ok':true,'cap_runs':caps,'always_on':true,'open_top_intent':'Continuous coping and narrow reveal; existing pitched roof and airy upper-room openings retained deliberately.','rear_owner':'ExteriorWalls/RearWall','rear_only_outward_face':true,'source_tint':'c6bba1','rear_tint':'b1a48a','global_exposure_changed':false,'collision_changes':false,'new_lights':0,'cap_triangles':288,'cap_draw_surfaces':root.get_meta('draw_surfaces'),'cap_source_meshes':root.get_meta('source_meshes'),'new_materials':4}
 inn.set_meta('inn_room_rear_finish_v096',report);return report
