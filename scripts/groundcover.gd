extends RefCounted
# Original static southern groundcover. Local coordinates are world-space meters.
# Call only on the identity-transform settlement root. No physics, state or wind.
static func add_to(scene:Node3D) -> Node3D:
 assert(not scene.has_node("SouthernGroundcover"), "Groundcover must be installed only once")
 var holder=Node3D.new();holder.name="SouthernGroundcover";scene.add_child(holder)
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/groundcover/placement.json"))
 var groups={}
 for p in data.placements:
  if not groups.has(p.asset):groups[p.asset]=[]
  groups[p.asset].append(p)
 for name in groups:
  var source=load("res://assets/groundcover/"+name+".glb").instantiate()
  var nodes=source.find_children("*","MeshInstance3D",true,false)
  assert(nodes.size()==1 and nodes[0].transform.is_equal_approx(Transform3D.IDENTITY))
  var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=nodes[0].mesh;mm.instance_count=groups[name].size()
  var transforms=[]
  for i in range(groups[name].size()):
   var p=groups[name][i]
   var t=Transform3D(Basis(Vector3.UP,p.yaw),Vector3(p.position[0],p.position[1],p.position[2]))
   mm.set_instance_transform(i,t);transforms.append(t)
  var batch=MultiMeshInstance3D.new();batch.name=name;batch.multimesh=mm
  batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  batch.set_meta("source_transforms",transforms);holder.add_child(batch);source.free()
 # No soil skin: low plants root directly on existing ground Y=-0.05.
 return holder
