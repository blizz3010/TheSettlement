extends RefCounted
# market_landscape relocates whole planters. Move their original loose lamps too.
# Read its exact journal; never touch player lantern furniture or west-path moves.
static func vector(value:Array)->Vector3:return Vector3(value[0],value[1],value[2])
static func add_to(scene:Node3D):
 assert(not scene.has_meta('plaza_lantern_reconciliation_journal'))
 var changes=[]
 for record in scene.get_meta('market_landscape_journal',[]):
  if record.instance!=-1:continue
  var planter=scene.get_node_or_null(NodePath(record.node))
  if planter==null or not planter.scene_file_path.ends_with('/planter.glb'):continue
  var old=vector(record.from);var next=vector(record.to);var delta=next-old
  var lanterns=[];var lights=[]
  for n in scene.get_children():
   if n is Node3D and n.scene_file_path.ends_with('/lantern.glb') and n.global_position.distance_to(old+Vector3(0,.2,0))<.001:lanterns.append(n)
   if n is OmniLight3D and n.global_position.distance_to(old+Vector3(0,1,0))<.001:lights.append(n)
  # Not every generic planter is a lit ring planter. A partial pair is a defect.
  if lanterns.is_empty() and lights.is_empty():continue
  assert(lanterns.size()==1 and lights.size()==1,'Original ring lamp/light must stay paired')
  for n in [lanterns[0],lights[0]]:
   var before=n.global_transform;n.global_position+=delta
   changes.append({'node':str(n.get_path()),'planter':str(planter.get_path()),'before':before,'after':n.global_transform,'reason':'Follow original ring planter out of walking route'})
 scene.set_meta('plaza_lantern_reconciliation_journal',changes)
 return changes
