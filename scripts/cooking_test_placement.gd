extends RefCounted
const Plants=preload("res://scripts/intentional_planting_pockets.gd")
const CENTER=Vector2(-11.2,6.7)
const ENVELOPE=Rect2(CENTER+Vector2(-.9,-.55),Vector2(1.8,2.8))
# Candidate only. Never relocate existing art to pass this gate.
static func inspect(world:Node3D,foliage_override:Variant=null)->Dictionary:
 var masks=Plants.preservation_masks(world)
 var foliage=Plants.existing_foliage(world) if foliage_override==null else foliage_override
 var envelope=Plants.bounds_xz(ENVELOPE)
 if Plants.overlap(envelope,masks,0) or Plants.overlap(envelope,foliage,0):return {"ok":false,"reason":"Protected route/art envelope overlap"}
 var planting=world.get_node_or_null("IntentionalPlantingPockets")
 if planting==null or int(planting.get_meta("budget",{}).get("accepted",0))!=47:return {"ok":false,"reason":"Reviewed47 planting layer required"}
 for item in planting.find_children("*","MultiMeshInstance3D",true,false):
  if item.multimesh==null:continue
  for i in range(item.multimesh.instance_count):
   var box:AABB=item.global_transform*item.multimesh.get_instance_transform(i)*item.multimesh.mesh.get_aabb()
   if Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).intersects(ENVELOPE):return {"ok":false,"reason":"Accepted planting overlap"}
 var heights=[];var support=[]
 var space=world.get_world_3d().direct_space_state
 for offset in [Vector2.ZERO,Vector2(-.45,-.45),Vector2(.45,-.45),Vector2(-.45,.45),Vector2(.45,.45),Vector2(0,1.3)]:
  var xz=CENTER+offset
  var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(xz.x,5,xz.y),Vector3(xz.x,-5,xz.y)))
  if hit.is_empty() or hit.normal.y<.95:return {"ok":false,"reason":"Missing or steep walkable support"}
  heights.append(hit.position.y);support.append(hit.position)
 if heights.max()-heights.min()>.08:return {"ok":false,"reason":"Uneven support corners/approach"}
 var y=heights.max()
 # Clear physical approach/headroom without ground intersections.
 var shape=BoxShape3D.new();shape.size=Vector3(1.8,1.9,2.8)
 var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,Vector3(CENTER.x,y+1.0,CENTER.y+.85))
 if not space.intersect_shape(query,8).is_empty():return {"ok":false,"reason":"Station/approach obstacle or headroom collision"}
 return {"ok":true,"position":Vector3(CENTER.x,y,CENTER.y),"support":support,"envelope":ENVELOPE,"reason":"Runtime geometric screen passed; native route review still required"}
