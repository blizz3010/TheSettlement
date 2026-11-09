extends RefCounted
# Original bounded near/mid-distance clusters. Far backdrop and fountain untouched.
const TREES = [Vector3(13,0,-9),Vector3(-15,0,-11.5),Vector3(-13.5,0,-21),Vector3(13.5,0,-28)]
const SHRUBS = [Vector3(11.7,0,-9),Vector3(13.7,0,-8.2),Vector3(-8.8,0,-10),Vector3(-10.8,0,-11)]
static func add_to(scene: Node3D):
 var holder=Node3D.new()
 holder.name="ReferenceFoliage"
 scene.add_child(holder)
 for i in range(TREES.size()):
  var tree=load("res://assets/kit/reference_broadleaf_tree_a.glb").instantiate()
  tree.name="Tree%d"%i
  tree.position=TREES[i]
  holder.add_child(tree)
  var body=StaticBody3D.new()
  body.name="Trunk%d"%i
  body.position=TREES[i]+Vector3(0,1.25,0)
  var shape=CollisionShape3D.new()
  var cylinder=CylinderShape3D.new()
  cylinder.radius=.48
  cylinder.height=2.5
  shape.shape=cylinder
  body.add_child(shape)
  holder.add_child(body)
 for i in range(SHRUBS.size()):
  var shrub=load("res://assets/kit/reference_low_shrub_%s.glb"%("a" if i%2==0 else "b")).instantiate()
  shrub.name="Shrub%d"%i
  shrub.position=SHRUBS[i]
  holder.add_child(shrub)
 # Keep imported opaque vertex colors; never invoke architectural material styling.
 return holder
