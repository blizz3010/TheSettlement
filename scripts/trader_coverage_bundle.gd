extends RefCounted
const Actor=preload('res://scripts/trader_coverage.gd')
const Fit=preload('res://scripts/staff_fit.gd')
const ATLAS='res://assets/npc_coverage/Atlas-Static-Sleeve-Fit.glb'
const STAFF='res://assets/npc_coverage/ProvisionalStaff.glb'
static func apply(world:Node3D)->Dictionary:
 var parent=world.get_node_or_null('MarketExpansion/AtlasStand')
 if parent==null:return {'ok':false,'reason':'Missing Atlas stand'}
 var actors=[];var created=[]
 var specs=[
  [parent,'Atlas',ATLAS,'Atlas_Standing',Vector3(0,Fit.ATLAS_Y,1.3),0.0,1.0],
  [world,'Rook',STAFF,'Staff_SubtleIdle_Provisional',Vector3(30,Fit.ROOK_Y,35.35),PI,Fit.STAFF_SCALE],
  [world,'West',STAFF,'Staff_SubtleIdle_Provisional',Vector3(-7,Fit.WEST_Y,2),PI/2,Fit.STAFF_SCALE]]
 for spec in specs:
  var previous=spec[0].get_node_or_null('CoverageStudy_'+spec[1])
  var actor=Actor.attach(spec[0],spec[1],spec[2],spec[3],spec[4],spec[5],spec[6])
  if not is_instance_valid(actor):
   for added in created:
    added.get_parent().remove_child(added);added.queue_free()
   return {'ok':false,'reason':'Coverage asset failed to instantiate'}
  actors.append(actor)
  if actor!=previous:created.append(actor)
 return {'ok':true,'actors':actors,'role_tints':true,'atlas_idle':'coverage_private/quiet_idle'}
