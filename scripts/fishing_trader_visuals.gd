extends Node3D
# Provisional scenery only. No inventory, services, prompts, physics or saved state.
const Actor=preload('res://scripts/trader_coverage.gd')
const Fit=preload('res://scripts/staff_fit.gd')
const STAFF='res://assets/npc_coverage/ProvisionalStaff.glb'
const SPOT=Vector2(15,-41.699)
const TARGET=Vector2(15,-44.699)
var host
var visual:Node3D
var actor:Node3D
var result={}
var requested=false
var attempted=false
# Native survey supplies one exact existing tree and a dry-bank position. No fallback search.
var survey={}
func setup(world,placement:Dictionary):
 host=world;survey=placement.duplicate(true);name='FishingTraderVisualController'
func active()->bool:
 return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(host) and host.is_inside_tree() and not host.is_queued_for_deletion() and host.world_initialized and (not host.staged_startup or host.world_activated or host.startup_preparing_assets) and not host.startup_cancel_requested
func begin_after_activation(world):
 if requested or world!=host or not active():return
 requested=true
 var tree=get_tree()
 while active():
  var gardens=host.four_area_gardens
  if not is_instance_valid(gardens) or gardens.is_queued_for_deletion() or not gardens.requested:
   result={'ok':false,'reason':'Gardens missing or cancelled'};return
  if gardens.attempted:
   if not gardens.result.get('ok',false):result={'ok':false,'reason':'Gardens failed'};return
   break
  await tree.physics_frame
 if active():result=install()
func fail(reason:String)->Dictionary:
 return {'ok':false,'reason':reason}
func bounds_clear(box:AABB)->bool:
 # Conservative swept stance/cast rectangle; no corner sampling gaps.
 var r=Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
 var corridor=Rect2(Vector2(13.95,-45.749),Vector2(2.1,5.1))
 return not r.intersects(corridor,true)
func install()->Dictionary:
 attempted=true
 if not active():return fail('World inactive')
 if global_transform!=Transform3D.IDENTITY or host.global_transform!=Transform3D.IDENTITY:return fail('World-space placement requires identity owners')
 if is_instance_valid(visual):return fail('Already installed; no duplicate attachment')
 if survey.keys().size()!=5:return fail('A bound native tree/ground survey is required')
 for key in ['tree_path','tree_index','tree_transform','tree_mesh','feet']:
  if not survey.has(key):return fail('Incomplete survey')
 if not survey.tree_path is NodePath or not survey.tree_index is int or not survey.tree_transform is Transform3D or not survey.tree_mesh is Mesh or not survey.feet is Vector3:return fail('Invalid survey types')
 if not survey.feet.is_finite() or not survey.tree_transform.origin.is_finite() or not survey.tree_transform.basis.x.is_finite() or not survey.tree_transform.basis.y.is_finite() or not survey.tree_transform.basis.z.is_finite():return fail('Nonfinite survey')
 var tree_node=host.get_node_or_null(survey.tree_path)
 if not tree_node is MultiMeshInstance3D or tree_node.is_queued_for_deletion() or not tree_node.is_visible_in_tree():return fail('Tree missing or hidden')
 if tree_node.get_parent()!=host.get_node_or_null('NaturalBorder') or str(tree_node.name) not in ['border_tree_a','border_tree_b']:return fail('Not an original border tree')
 var mm=tree_node.multimesh;var index:int=survey.tree_index
 if mm==null or index<0 or index>=mm.instance_count or (mm.visible_instance_count>=0 and index>=mm.visible_instance_count) or mm.mesh!=survey.tree_mesh:return fail('Tree identity changed')
 var tx=tree_node.global_transform*mm.get_instance_transform(index)
 if tx!=survey.tree_transform:return fail('Tree transform changed')
 var feet:Vector3=survey.feet
 if not bounds_clear(AABB(feet+Vector3(-.55,0,-.55),Vector3(1.1,2.1,1.1))):return fail('Actor would enter casting corridor')
 # Support checks are live. No platform/terrain relocation if this fails.
 for d in [Vector3.ZERO,Vector3(.4,0,.4),Vector3(-.4,0,.4),Vector3(.4,0,-.4),Vector3(-.4,0,-.4)]:
  var p=feet+d
  var query=PhysicsRayQueryParameters3D.create(p+Vector3.UP*1.5,p-Vector3.UP*.6);query.exclude=[host.player.get_rid()]
  var hit=host.get_world_3d().direct_space_state.intersect_ray(query)
  if hit.is_empty() or hit.normal.y<.8 or absf(hit.position.y-feet.y)>.12 or hit.position.y<=.572:return fail('Bank support is wet, steep or uneven')
 var root=Node3D.new();root.name='FishingTraderVisuals';add_child(root)
 var person=Actor.attach(root,'FishingProvisional',STAFF,'Staff_SubtleIdle_Provisional',feet,-PI*.25,Fit.STAFF_SCALE)
 if not is_instance_valid(person):root.free();return fail('Provisional actor failed')
 # Fit imported feet from actual bounds, not another NPC’s terrain Y offset.
 var bottom=INF
 for mesh in person.visual.find_children('*','MeshInstance3D',true,false):
  if mesh.mesh!=null:bottom=minf(bottom,(mesh.global_transform*mesh.mesh.get_aabb()).position.y)
 if not is_finite(bottom):root.free();return fail('Actor has no mesh bounds')
 person.position.y+=feet.y-bottom
 var origin=tx.origin
 # Rods lean on the inland side; all locations are checked before publication.
 var toward=(Vector3(feet.x,origin.y,feet.z)-origin).normalized()
 if toward.length()<.5:root.free();return fail('Actor and trunk coincide')
 var right=toward.cross(Vector3.UP).normalized()
 for i in range(3):
  var base=Vector3(origin.x,feet.y+.04,origin.z)+toward*.6+right*(i-1)*.16
  var tip=Vector3(origin.x,feet.y+1.9+i*.12,origin.z)+toward*.16+right*(i-1)*.09
  rod(root,base,tip,i)
 var box_at=feet+right*.85+toward*.15
 box(root,'TackleCase',box_at+Vector3(0,.11,0),Vector3(.48,.22,.30),Color('4c5545'))
 box(root,'OpenLid',box_at+Vector3(0,.32,-.14),Vector3(.48,.27,.035),Color('8a6b42'))
 for i in range(3):box(root,'Tray'+str(i),box_at+Vector3((i-1)*.14,.235,0),Vector3(.12,.025,.24),Color('b49a68'))
 for i in range(3):
  var bob=MeshInstance3D.new();bob.name='GroundBobber'+str(i);var mesh=SphereMesh.new();mesh.radius=.045;mesh.height=.13;mesh.radial_segments=10;mesh.rings=5;bob.mesh=mesh
  bob.material_override=material(Color('c75a36') if i!=1 else Color('d3aa49'));bob.position=box_at+Vector3((i-1)*.13,.05,.25);bob.rotation.z=PI*.35;root.add_child(bob)
 for mesh in root.find_children('*','MeshInstance3D',true,false):
  if mesh.mesh==null:continue
  if not bounds_clear(mesh.global_transform*mesh.mesh.get_aabb()):root.free();return fail('Prop enters casting corridor')
 preload('res://scripts/fishing_nook_v094.gd').apply(host,root,feet,origin,toward,right)
 visual=root;actor=person;actor.set_activation_enabled(true)
 return {'ok':true,'provisional':true,'service_available':false,'tree_path':str(survey.tree_path),'tree_index':index,'feet':feet,'rods':3,'bobbers':3,'colliders':0,'clearance_scope':'support and casting only; visual/access inspection still required'}
static func material(color:Color)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.8;return m
static func box(parent:Node3D,label:String,at:Vector3,size:Vector3,color:Color):
 var n=MeshInstance3D.new();n.name=label;var m=BoxMesh.new();m.size=size;n.mesh=m;n.material_override=material(color);n.position=at;parent.add_child(n)
static func segment(parent:Node3D,label:String,a:Vector3,b:Vector3,radius:float,color:Color):
 var n=MeshInstance3D.new();n.name=label;var m=CylinderMesh.new();m.height=a.distance_to(b);m.top_radius=radius*.65;m.bottom_radius=radius;m.radial_segments=8;n.mesh=m;n.material_override=material(color)
 var axis=(b-a).normalized();var side=axis.cross(Vector3.FORWARD).normalized()
 if side.length()<.01:side=Vector3.RIGHT
 n.transform=Transform3D(Basis(side,axis,side.cross(axis)),(a+b)*.5);parent.add_child(n)
static func rod(parent:Node3D,a:Vector3,b:Vector3,index:int):
 segment(parent,'Rod'+str(index),a,b,.012,Color('b29157'))
 segment(parent,'Handle'+str(index),a,a.lerp(b,.2),.026,Color('62462e'))
 box(parent,'Reel'+str(index),a.lerp(b,.16)+Vector3(.035,0,0),Vector3(.06,.06,.055),Color('ad8e52'))
func _process(_delta:float):
 if is_instance_valid(actor):actor.set_activation_enabled(active())
func _exit_tree():
 if is_instance_valid(actor):actor.set_activation_enabled(false)
 # Owned children are freed with the controller; never touch the original tree.
