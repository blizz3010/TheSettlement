extends RefCounted
const MarketUnion=preload('res://scripts/market_visual_union.gd')
const Contact=preload('res://scripts/connector_contact_finish.gd')
const RouteDetail=preload('res://scripts/route_material_detail.gd')
const SHADER=preload('res://assets/route_limestone_candidate.gdshader')
static func route_mesh(m,world):
 var p=str(m.get_path())
 if '/HallSurroundPaths/' in p or '/HallRoutePark/JoinedParkStone' in p or '/ApproachPathFinish/' in p or '/LaunchpadApproach/StoneConnector' in p:return true
 var market=world.get_node('MarketExpansion');var terrace=world.get_node('RaisedHideoutTerrace')
 if m.get_parent()==market and m.mesh is CylinderMesh:return true
 if m.mesh is BoxMesh:
  var size=m.mesh.size;var parent=m.get_parent()
  if parent.get_parent()==market and is_equal_approx(size.x,4) and is_equal_approx(size.y,.08):return true
  if parent.get_parent()!=null and parent.get_parent().get_parent()==market and is_equal_approx(size.y,.08) and is_equal_approx(size.z,3.4):return true
  if parent.get_parent()==terrace and is_equal_approx(size.x,2.6) and is_equal_approx(size.y,.08):return true
  if parent==world and (size.is_equal_approx(Vector3(7,.14,18)) or size.is_equal_approx(Vector3(24,.14,5))):return true
 return '/RaisedHideoutTerrace/SupportedApproachJoin/' in p
static func apply(world:Node3D)->Dictionary:
 if world.has_meta('bundle_route_report'):return world.get_meta('bundle_route_report')
 for name in ['MarketExpansion','RaisedHideoutTerrace','HallRoutePark','ApproachPathFinish','HallSurroundPaths','LaunchpadApproach']:
  if not world.has_node(name):return {'ok':false,'reason':'Missing route owner '+name}
 var mat=world.courtyard_material('scenery_route_candidate',Color(.46,.44,.38,1)).duplicate();mat.shader=SHADER
 var prepared=MarketUnion.prepare(world,mat)
 if prepared.has('error'):return {'ok':false,'reason':prepared.error,'detail':prepared}
 var contact=Contact.prepare(world,prepared.built.components,mat)
 if contact.has('error'):return {'ok':false,'reason':contact.error}
 var changes=[]
 for node in world.find_children('*','MeshInstance3D',true,false):
  if route_mesh(node,world):changes.append({'node':node,'before':node.material_override,'after':mat})
 for holder_name in ['MarketExpansion','RaisedHideoutTerrace']:
  for batch in world.get_node(holder_name).find_children('*','MultiMeshInstance3D',true,false):
   var old=batch.material_override
   if not old is ShaderMaterial or old.shader!=world.COURTYARD_SHADER or old.get_shader_parameter('tint')!=Color(.46,.44,.38,1):continue
   var count=0
   for i in range(batch.multimesh.instance_count):
    var t=batch.global_transform*batch.multimesh.get_instance_transform(i);var b=t*batch.multimesh.mesh.get_aabb()
    if b.end.y>=.035 and b.end.y<=.060:
     var size=t.basis.get_scale()
     if not is_equal_approx(size.y,.08) or not (is_equal_approx(size.x,4) or is_equal_approx(size.x,2.6) or is_equal_approx(size.z,3.4)):return {'ok':false,'reason':'Unknown shared stone route instance'}
     count+=1
   if count>0:
    var gated=old.duplicate();gated.shader=SHADER;gated.set_shader_parameter('route_min_y',.035);gated.set_shader_parameter('route_max_y',.060)
    changes.append({'node':batch,'before':old,'after':gated})
 for change in changes:
  if not is_instance_valid(change.node) or change.node.material_override!=change.before:return {'ok':false,'reason':'Concurrent material mutation'}
 if not Contact.valid(contact):return {'ok':false,'reason':'Concurrent connector mutation'}
 var node=MarketUnion.install(prepared)
 if node==null:return {'ok':false,'reason':'Concurrent route mutation'}
 var contact_node=Contact.install(contact)
 if contact_node==null:
  MarketUnion.rollback(prepared,node)
  return {'ok':false,'reason':'Connector commit rejected; market restored'}
 RouteDetail.bind(world,mat)
 for change in changes:
  change.node.material_override=change.after
  RouteDetail.bind(world,change.after)
 var report={'ok':true,'union':prepared.built.report,'material_targets':changes.size(),'connector_contact':contact.report}
 world.set_meta('bundle_route_report',report)
 return report
