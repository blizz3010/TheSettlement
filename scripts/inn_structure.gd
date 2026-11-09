extends RefCounted
# Explicit structural additions and collision for this isolated architectural module.
const Architecture=preload('res://scripts/inn_architecture.gd')
static func beam(parent:Node3D,label:String,a:Vector3,b:Vector3,width:float,depth:float,mat:Material)->MeshInstance3D:
 var n=Architecture.box(parent,label,(a+b)*.5,Vector3(width,depth,a.distance_to(b)),mat)
 n.basis=Basis.looking_at(b-a,Vector3.UP);return n
static func create()->Node3D:
 var root=Architecture.create()
 if root==null:return null
 var structure=Architecture.group(root,'StructuralRailsAndStringers')
 var wood=Architecture.material('594936');var bronze=Architecture.material('938064',.58)
 for x in [4.13,5.67]:
  beam(structure,'LowerHandrail'+str(x),Vector3(x,1.06,-4.5),Vector3(x,2.66,-1.3),.09,.10,wood)
  beam(structure,'LowerStringer'+str(x),Vector3(x,.02,-4.5),Vector3(x,1.46,-1.3),.14,.20,wood)
 for x in [5.93,7.47]:
  beam(structure,'UpperHandrail'+str(x),Vector3(x,2.66,-1.3),Vector3(x,4.26,-4.5),.09,.10,wood)
  beam(structure,'UpperStringer'+str(x),Vector3(x,1.46,-1.3),Vector3(x,3.06,-4.5),.14,.20,wood)
  for i in range(6):
   var z=-1.3-i*.64;var tread=1.6+i*.32
   Architecture.box(structure,'UpperPost'+str(x)+str(i),Vector3(x,tread+.48,z),Vector3(.07,.96,.07),bronze)
 # Outer middle-landing edge; U-turn passage stays inside the rail.
 Architecture.box(structure,'MiddleLandingRail',Vector3(5.8,2.62,.14),Vector3(3.4,.10,.09),wood)
 for x in [4.13,5.8,7.47]:Architecture.box(structure,'MiddleLandingPost'+str(x),Vector3(x,2.08,.14),Vector3(.08,.96,.08),bronze)
 # Solid well guards beside the existing west rail; preserve north arrival opening.
 Architecture.box(structure,'SouthWellRail',Vector3(5.8,4.22,.24),Vector3(3.6,.10,.09),wood)
 for x in [4.1,5.8,7.5]:Architecture.box(structure,'SouthWellPost'+str(x),Vector3(x,3.72,.24),Vector3(.08,1.04,.08),bronze)
 var collisions=Node3D.new();collisions.name='ExplicitArchitectureCollision';root.add_child(collisions)
 var count=0
 for group_name in ['FoundationAndVeranda','ExteriorWalls','InternalStair','StructuralRailsAndStringers','UpperRoomsAndLanding','GroundGatheringAndBar']:
  var group=root.get_node(group_name)
  for mesh in group.get_children():
   if not mesh is MeshInstance3D or not mesh.mesh is BoxMesh:
    root.free();return null
   # Soft bedding is render-only; solid bedframe remains collidable.
   if str(mesh.name).begins_with('BedCover') or str(mesh.name).begins_with('BedPillow'):continue
   var body=StaticBody3D.new();body.name=group_name+'_'+str(mesh.name);body.transform=group.transform*mesh.transform
   var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=mesh.mesh.size;shape.shape=box;body.add_child(shape);collisions.add_child(body);count+=1
 root.set_meta('collision_scope','Exact box solids for structural groups/furniture; bedding and roof render-only. Isolated study, no service or world installation.')
 root.set_meta('collision_count',count)
 return root
