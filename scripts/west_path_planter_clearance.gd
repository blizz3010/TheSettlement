extends RefCounted
# Preserve complete authored planter roots and the original companion lighting.
const MOVES=[
 [Vector3(-8.684467,0,-3.597224),Vector3(-12,-.05,-7.8),'planter_fern_variant.glb',false],
 [Vector3(-6.646804,0,-6.646804),Vector3(-9.7,-.05,-8.2),'planter.glb',true]
]
static func bounds(n:Node3D)->AABB:
 var result=AABB();var found=false
 for mesh in n.find_children('*','MeshInstance3D',true,false):
  var b=mesh.global_transform*mesh.mesh.get_aabb();result=result.merge(b) if found else b;found=true
 assert(found);return result
static func add_to(scene:Node3D):
 assert(not scene.has_meta('west_path_planter_clearance_journal'))
 var journal=[]
 for spec in MOVES:
  var matches=[]
  for n in scene.get_children():
   if n is Node3D and n.scene_file_path.ends_with('/'+spec[2]) and n.position.distance_to(spec[0])<.001:matches.append(n)
  assert(matches.size()==1,'Expected exact original west-route planter')
  var planter:Node3D=matches[0];var before=planter.transform;var delta:Vector3=spec[1]-planter.position
  var old_bounds=bounds(planter);var companions=[]
  if spec[3]:
   var lanterns=[];var lights=[]
   for n in scene.get_children():
    if n is Node3D and n.scene_file_path.ends_with('/lantern.glb') and n.position.distance_to(spec[0]+Vector3(0,.2,0))<.001:lanterns.append(n)
    if n is OmniLight3D and n.position.distance_to(spec[0]+Vector3(0,1,0))<.001:lights.append(n)
   assert(lanterns.size()==1 and lights.size()==1,'Keep original paired lantern/light together')
   companions.append_array(lanterns);companions.append_array(lights)
  planter.position+=delta
  for n in companions:n.position+=delta
  var after_bounds=bounds(planter)
  assert(after_bounds.end.z< -6.8 and after_bounds.position.z> -9.7,'Keep full plant clear of west route and hall-front walk')
  assert(after_bounds.end.x< -8.4,'Keep new board approach clear')
  journal.append({'node':str(planter.get_path()),'reason':'Original ring planter intersects legacy west path','before':before,'after':planter.transform,'before_bounds':old_bounds,'after_bounds':after_bounds,'companions_moved':companions.size(),'colliders_moved_with_root':planter.find_children('*','CollisionShape3D',true,false).size()})
 scene.set_meta('west_path_planter_clearance_journal',journal)
