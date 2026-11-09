extends RefCounted
# I01: explicitly partition the old stone slab, then build a supported L deck.
# Only patio floor/guards change. No terrain, shore, vegetation or saved state.
const Art=preload('res://scripts/inn_architecture.gd')
const Front=preload('res://scripts/inn_front_v087.gd')
const REAR=Rect2(-8.7,58.7,20.7,4.3)
const EAST=Rect2(7.9,53.0,4.1,5.7)
const STONE=[Rect2(-9,43.2,.3,17),Rect2(-8.7,43.2,17.7,9.8),Rect2(-8.7,53,16.6,5.7)]
static func fail(reason:String)->Dictionary:return {'ok':false,'reason':reason}
static func prepare(terrace:Node3D)->Dictionary:
 if terrace==null or not terrace.transform.is_equal_approx(Transform3D.IDENTITY):return fail('Expected untransformed terrace')
 var old=terrace.get_node_or_null('TerraceDeck');var body=terrace.get_node_or_null('TerraceDeckBody')
 if not old is MeshInstance3D or not old.mesh is BoxMesh or not old.position.is_equal_approx(Vector3(0,3.28,51.7)) or not old.mesh.size.is_equal_approx(Vector3(18,.20,17)):return fail('Original terrace slab geometry changed')
 if not body is StaticBody3D or not body.transform.is_equal_approx(old.transform) or body.get_child_count()!=1 or body.collision_layer!=1 or body.collision_mask!=1:return fail('Original terrace support changed')
 var shape=body.get_child(0)
 if not shape is CollisionShape3D or not shape.shape is BoxShape3D or shape.disabled or not shape.transform.is_equal_approx(Transform3D.IDENTITY) or not shape.shape.size.is_equal_approx(old.mesh.size):return fail('Original terrace box changed')
 if terrace.has_node('JoinedDeckStoneRemainderV098'):return fail('Already partitioned')
 var holder=Node3D.new();holder.name='JoinedDeckStoneRemainderV098'
 for i in STONE.size():
  var r:Rect2=STONE[i]
  Front.solid(holder,'RetainedStone%d'%i,Vector3(r.get_center().x,3.28,r.get_center().y),Vector3(r.size.x,.20,r.size.y),old.material_override)
  holder.get_node('RetainedStone%dCollision'%i).set_meta('audio_surface','stone')
 return {'ok':true,'replacement':holder,'original_visual':old,'original_body':body,'terrace':terrace}
static func build(lake:Node3D,deck:Callable,rail:Callable):
 deck.call(lake,'RearBalcony',REAR);deck.call(lake,'EastBalcony',EAST)
 lake.set_meta('joined_deck_rects_v098',[REAR,EAST])
 for name in ['RearBalconyCollision','EastBalconyCollision']:lake.get_node(name).set_meta('audio_surface','wood')
 # Outside drops only. No cross-rail divides the joined east/rear walking floor.
 for ends in [[Vector3(-8.7,3.38,60.2),Vector3(-8.7,3.38,63)],[Vector3(-8.7,3.38,63),Vector3(12,3.38,63)],[Vector3(12,3.38,53),Vector3(12,3.38,63)],[Vector3(8.95,3.38,53),Vector3(12,3.38,53)]]:rail.call(lake,ends[0],ends[1])
 var wood=Art.material('59412b')
 # Retain the exact north guard: all of it borders the unextended terrace.
 Front.solid(lake,'EastGuardNorth',Vector3(8.95,3.92,48.125),Vector3(.10,1.04,9.75),wood)
 # Close the 30cm west terrace shoulder; do not leave an unprotected outside gap.
 Front.solid(lake,'RearWestShoulderGuard',Vector3(-8.85,3.92,60.15),Vector3(.30,1.04,.10),wood)
 Art.box(lake,'JoinedCornerTimberPile',Vector3(11.6,1.325,62.6),Vector3(.35,3.95,.35),wood)
 Art.box(lake,'JoinedRearBearingExtension',Vector3(10.275,3.015,62.6),Vector3(3.35,.21,.22),wood)
static func commit(plan:Dictionary,lake:Node3D):
 plan.terrace.add_child(plan.replacement)
 # Keep the exact originals available for inspection, but not as hidden collision
 # beneath timber. Original resources and layer/mask values are recorded.
 plan.original_visual.hide()
 plan.original_body.set_meta('pre_join_layer',plan.original_body.collision_layer)
 plan.original_body.set_meta('pre_join_mask',plan.original_body.collision_mask)
 plan.original_body.collision_layer=0;plan.original_body.collision_mask=0
 lake.set_meta('joined_decks_v098',{'ok':true,'rear':REAR,'east':EAST,'stone_remainders':STONE,'floor_top':3.38,'entrance_step':.02,'removed_internal_guards':['RearGuardWest','EastGuardSouth'],'north_guard_preserved':true,'shoreline_changes':false,'new_floor_bodies':5,'disabled_original_floor_bodies':1})
