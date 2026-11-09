extends RefCounted
# Original east-only study; coordinates authored in Blender Z-up/front -Y.
# Convert to Godot Y-up/front +Z, then inherit the art's identical east yaw.
static func box(holder: Node3D, title: String, at: Vector3, size: Vector3):
 var body=StaticBody3D.new()
 body.name=title
 body.position=Vector3(at.x,at.z,-at.y)
 var shape=CollisionShape3D.new()
 var mesh=BoxShape3D.new()
 mesh.size=Vector3(size.x,size.z,size.y)
 shape.shape=mesh
 body.add_child(shape)
 holder.add_child(body)
 return body
static func add_collision(scene: Node3D):
 var holder=Node3D.new()
 holder.name="EastTraderCollision"
 holder.position=Vector3(8,0,-3)
 holder.rotation.y=-PI/2
 scene.add_child(holder)
 # No blanket volume: front customer approach and right staff portal stay clear.
 box(holder,"RearWall",Vector3(0,1.21,1.40),Vector3(3.6,.18,2.8))
 box(holder,"LeftWall",Vector3(-1.78,0,1.4),Vector3(.20,2.5,2.8))
 box(holder,"RightWindowBay",Vector3(1.78,-.79,1.22),Vector3(.24,.88,2.44))
 box(holder,"RightRearPier",Vector3(1.78,1.10,1.40),Vector3(.20,.28,2.8))
 box(holder,"RightLintel",Vector3(1.78,0,2.64),Vector3(.20,2.5,.23))
 box(holder,"Counter",Vector3(0,-.65,.49),Vector3(3.5,.8,.98))
 box(holder,"RearShelves",Vector3(0,.94,1.23),Vector3(3.24,.42,2.32))
 box(holder,"Roof",Vector3(0,.25,2.83),Vector3(3.86,2.40,.12))
 for x in [-1.8,1.8]:
  for y in [-1.25,1.25]:box(holder,"Post",Vector3(x,y,1.45),Vector3(.21,.23,2.9))
 return holder
