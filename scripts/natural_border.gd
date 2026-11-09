extends RefCounted
# Original reference-aligned mid-border: same90 anchors/RNG stream as legacy pots.
const FILES=["border_tree_a","border_tree_b","border_shrub_a","border_shrub_b"]
static func anchors() -> Array[Vector3]:
 var rng=RandomNumberGenerator.new();rng.seed=2311
 var result:Array[Vector3]=[]
 for i in range(90):
  var a=rng.randf_range(0,TAU);var r=rng.randf_range(24,40)
  result.append(Vector3(cos(a)*r,0,sin(a)*r))
  rng.randf_range(1.3,3.5) # Preserve original RNG consumption exactly.
 return result
static func hall_adjusted_anchors() -> Array[Vector3]:
 var points=anchors()
 # Conservative maximum broadleaf canopy buffer4.2m includes randomizedscale.
 var hall=AABB(Vector3(-10.6,-1,-33.7),Vector3(21.2,20,21.3))
 for i in range(points.size()):
  if AABB(points[i]-Vector3(4.2,0,4.2),Vector3(8.4,10,8.4)).intersects(hall):
   # Preserve angular direction and deterministicorder; move beyond rear edge.
   var direction=points[i].normalized()
   while AABB(points[i]-Vector3(4.2,0,4.2),Vector3(8.4,10,8.4)).intersects(hall):
    points[i]+=direction
 return points
static func add_to(scene:Node3D):
 var holder=Node3D.new();holder.name="NaturalBorder";scene.add_child(holder)
 var points=hall_adjusted_anchors();var selected:Array[int]=[]
 # Spread trees around the ring; reject complete canopy AABB near plot reserve.
 var reserve=AABB(Vector3(-21.5,-1,-9.5),Vector3(15,20,15))
 for pass_index in range(2):
  for i in range(90):
   if selected.size()==24:break
   if selected.has(i) or (pass_index==0 and i%4!=0):continue
   if AABB(points[i]-Vector3(3.5,0,3.5),Vector3(7,8,7)).intersects(reserve):continue
   selected.append(i)
 var transforms=[[],[],[],[]]
 var rng=RandomNumberGenerator.new();rng.seed=311026
 for i in range(90):
  var tree=selected.has(i)
  var variant=(selected.find(i)%2) if tree else (2+i%2)
  var scale_factor=rng.randf_range(.90,1.18) if tree else rng.randf_range(1.25,2.2)
  var basis=Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*scale_factor)
  transforms[variant].append(Transform3D(basis,points[i]))
 for i in range(4):
  var source=load("res://assets/kit/"+FILES[i]+".glb").instantiate()
  var meshes=source.find_children("*","MeshInstance3D",true,false)
  assert(meshes.size()==1)
  var mesh=meshes[0].mesh
  assert(mesh.get_surface_count()==1)
  var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
  mm.mesh=mesh;mm.instance_count=transforms[i].size()
  for j in range(transforms[i].size()):mm.set_instance_transform(j,transforms[i][j])
  var batch=MultiMeshInstance3D.new();batch.name=FILES[i];batch.multimesh=mm
  batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if i<2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  batch.set_meta("source_transforms",transforms[i])
  holder.add_child(batch);source.free()
 holder.set_meta("tree_count",24);holder.set_meta("shrub_count",66)
 return holder
