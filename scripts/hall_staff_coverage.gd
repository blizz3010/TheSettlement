extends RefCounted
## Provisional render-only hall occupancy. Reception has NO service.
const Actor=preload('res://scripts/trader_coverage.gd')
const Fit=preload('res://scripts/staff_fit.gd')
const STAFF='res://assets/npc_coverage/ProvisionalStaff.glb'
const IDS=['HallPlotProvisional','HallReceptionProvisional']
const ROOT_Y=.24+Fit.WEST_Y
static func failure(reason:String)->Dictionary:
 return {'ok':false,'reason':reason,'actors':[]}
static func restore_placeholder(placeholder,was_visible:bool):
 if is_instance_valid(placeholder):placeholder.visible=was_visible
static func rollback(created:Array):
 for actor in created:
  if is_instance_valid(actor):
   actor.set_activation_enabled(false)
   if actor.get_parent()!=null:actor.get_parent().remove_child(actor)
   actor.queue_free()
static func prepare_tint(visual:Node3D,tint:Color)->Array:
 var changes=[]
 for mesh in visual.find_children('*','MeshInstance3D',true,false):
  if not str(mesh.name).begins_with('StaffWorkwear'):continue
  if mesh.mesh==null:return []
  for surface in range(mesh.mesh.get_surface_count()):
   var original=mesh.get_active_material(surface)
   if not original is StandardMaterial3D:return []
   var local=original.duplicate();local.resource_local_to_scene=true
   local.albedo_color=tint;local.roughness=.88
   changes.append({'mesh':mesh,'surface':surface,'original':original,'replacement':local})
 return changes
static func apply(world:Node3D,coverage:Dictionary,staff_asset:String=STAFF)->Dictionary:
 if not coverage.get('ok',false):return failure('Existing trader coverage unavailable')
 var placeholder=world.get_node_or_null('MaraStewardPlaceholder')
 if not placeholder is MeshInstance3D or not placeholder.mesh is CapsuleMesh:return failure('Expected exact standalone steward capsule')
 if not placeholder.position.is_equal_approx(Vector3(5.5,1.13,-29.3)):return failure('Steward anchor changed')
 if not is_equal_approx(placeholder.mesh.radius,.25) or not is_equal_approx(placeholder.mesh.height,1.65):return failure('Steward primitive changed')
 var previous=world.get_meta('hall_staff_result',{})
 if previous is Dictionary and previous.get('ok',false):
  var old_actors=previous.get('actors',[])
  if old_actors.size()!=2:return failure('Stale hall occupancy state')
  for i in range(2):
   var actor=old_actors[i]
   if not is_instance_valid(actor) or actor.get_parent()!=world or actor.get_script()!=Actor or actor.name!='CoverageStudy_'+IDS[i] or not is_instance_valid(actor.visual):return failure('Stale hall actor; explicit cleanup required')
  var retained=coverage.get('actors',[]).duplicate()
  for actor in old_actors:
   if not actor in retained:retained.append(actor)
  coverage['actors']=retained
  return previous
 for id in IDS:
  if world.has_node('CoverageStudy_'+id):return failure('Foreign or uncommitted hall actor name')
 var actors=[];var changes=[]
 var specs=[[IDS[0],Vector3(5.5,ROOT_Y,-29.3),Color('#a5aa8c')],[IDS[1],Vector3(0,ROOT_Y,-23.15),Color('#bca985')]]
 for spec in specs:
  var actor=Actor.attach(world,spec[0],staff_asset,'Staff_SubtleIdle_Provisional',spec[1],0.0,Fit.STAFF_SCALE)
  if not is_instance_valid(actor):
   rollback(actors);return failure('Hall staff asset failed to instantiate')
  actors.append(actor)
  actor.set_meta('role_scope','Existing plot service visual only' if spec[0]==IDS[0] else 'Reception ambience only; no service')
  var local_changes=prepare_tint(actor.visual,spec[2])
  if local_changes.is_empty():
   rollback(actors);return failure('Expected private workwear material unavailable')
  changes.append_array(local_changes)
 for change in changes:
  if not is_instance_valid(change.mesh) or change.mesh.get_active_material(change.surface)!=change.original:
   rollback(actors);return failure('Material changed during preparation')
 for change in changes:change.mesh.set_surface_override_material(change.surface,change.replacement)
 var was_visible=placeholder.visible
 # Only the plot actor replaces this capsule; reception has no placeholder.
 # Reception-only removal must not reveal a duplicate under the surviving steward.
 actors[0].tree_exiting.connect(func():restore_placeholder(placeholder,was_visible),CONNECT_ONE_SHOT)
 placeholder.visible=false
 var combined=coverage.get('actors',[]).duplicate()
 combined.append_array(actors)
 coverage['actors']=combined
 var result={'ok':true,'actors':actors,'placeholder':placeholder,'prior_visible':was_visible,'identity':'provisional; canonical steward A/B unresolved','reception_service':false}
 var reception=world.get_node_or_null('HallReceptionAssemblyV098')
 if reception!=null:reception.set_meta('render_only_reception_actor',weakref(actors[1]))
 world.set_meta('hall_staff_result',result)
 return result
