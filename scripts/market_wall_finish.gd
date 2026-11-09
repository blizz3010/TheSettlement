extends RefCounted
# Original editable, deterministic rear/side joinery. Only the three authored stands.
# Every new member is visual-only and remains over the existing plinth.
static var wall_wood:ShaderMaterial
static func wood()->ShaderMaterial:
 if wall_wood==null:
  wall_wood=ShaderMaterial.new();wall_wood.shader=preload('res://assets/materials/market_wall_timber.gdshader');wall_wood.resource_name='Quiet market wall timber'
 return wall_wood
static func apply(shop:Node3D,spec:Dictionary,api,materials:Dictionary):
 var w:float=spec.width;var d:float=spec.depth;var back=-d/2+.3
 var timber=wood();var stone=materials.stone;var bronze=materials.bronze
 # Restrict replacement to the two generic side sheets; counter/fronts stay exact.
 var replaced=0
 for child in shop.get_children():
  for mesh in child.get_children():
   if mesh is MeshInstance3D and mesh.mesh is BoxMesh and mesh.mesh.size.is_equal_approx(Vector3(.18,2.5,d-1.6)) and mesh.material_override==materials.wood:
    mesh.material_override=timber;replaced+=1
 assert(replaced==2,'Exactly two side sheets must receive quiet timber')
 var r=Node3D.new();r.name='WallFinish';shop.add_child(r)
 var rear=back-.14;var side_length=d-1.6;var side_start=-.5-side_length/2;var side_end=-.5+side_length/2
 # Rear mineral infill is retained, divided into three broad structural bays.
 api.box(r,'Rear limestone footing',Vector3(0,.36,rear),Vector3(w-.4,.48,.16),stone)
 for y in [.65,3.42]:api.box(r,'Rear timber rail',Vector3(0,y,rear),Vector3(w-.4,.15,.16),timber)
 for x in [-w/2+.3,-w/6,w/6,w/2-.3]:
  api.box(r,'Rear timber upright',Vector3(x,2.04,rear),Vector3(.16,2.91,.16),timber)
  api.box(r,'Rear bronze joint',Vector3(x,.78,rear-.085),Vector3(.19,.22,.025),bronze)
 # One knee in each outer bay, not a lattice of decorative micro-pieces.
 for sign in [-1,1]:
  var x=sign*(w/2-.3)
  preload('res://scripts/market_facades.gd').beam(api,r,'Rear timber knee',Vector3(x,2.6,rear),Vector3(x-sign*.78,3.42,rear),.12,timber)
 for sign in [-1,1]:
  var x=sign*(w/2-.15)
  api.box(r,'Side limestone footing',Vector3(x,.36,-.5),Vector3(.16,.48,side_length),stone)
  for y in [.65,2.56]:api.box(r,'Side timber rail',Vector3(x,y,-.5),Vector3(.16,.14,side_length),timber)
  for z in [side_start+.08,lerpf(side_start,side_end,.33),lerpf(side_start,side_end,.67),side_end-.08]:
   api.box(r,'Side timber upright',Vector3(x,1.61,z),Vector3(.16,2.04,.14),timber)
   api.box(r,'Side bronze joint',Vector3(x+sign*.085,.78,z),Vector3(.025,.22,.18),bronze)
  for end in [-1,1]:
   var z=side_start+.08 if end==-1 else side_end-.08
   preload('res://scripts/market_facades.gd').beam(api,r,'Side timber knee',Vector3(x,1.86,z),Vector3(x,2.56,z-end*.65),.11,timber)
 var count=0
 for mesh in r.find_children('*','MeshInstance3D',true,false):
  var b=(shop.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb()
  assert(b.position.x>=-w/2 and b.end.x<=w/2 and b.position.z>=-d/2 and b.end.z<=d/2,'Wall finish must remain on old plinth')
  count+=1
 assert(r.find_children('*','CollisionObject3D',true,false).is_empty())
 shop.set_meta('wall_finish',{'boxes':count,'triangles':count*12,'new_colliders':0,'materials_reused':2,'new_shared_materials':1})
