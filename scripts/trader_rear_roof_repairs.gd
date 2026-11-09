extends RefCounted
## Atlas and Dan rear joins only; existing roof geometry, solids and routes stay exact.
static func dan_underside(x:float)->float:
 return 5.15-.22*absf(x)-.07/cos(atan2(1.1,5.0))
static func gable(root:Node3D,api,cream:Material):
 var back=-3.2;var top=dan_underside(4.8)+.01;var ridge=dan_underside(0)+.01
 var polygon=[Vector2(-4.8,3.49),Vector2(4.8,3.49),Vector2(4.8,top),Vector2(0,ridge),Vector2(-4.8,top)]
 var vertices=PackedVector3Array()
 for z in [back-.09,back+.09]:
  for p in polygon:vertices.append(Vector3(p.x,p.y,z))
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 # Both mineral wall faces, triangulated from a convex rear-gable polygon.
 for i in range(1,4):
  for index in [0,i,i+1,5,5+i+1,5+i]:st.add_vertex(vertices[index])
 for i in range(5):
  var j=(i+1)%5
  for index in [i,5+i,j,j,5+i,5+j]:st.add_vertex(vertices[index])
 st.generate_normals()
 var mesh=MeshInstance3D.new();mesh.name='Fitted mineral rear gable';mesh.mesh=st.commit();mesh.material_override=cream;root.add_child(mesh)
 var body=StaticBody3D.new();body.name='Rear gable infill collision';body.set_meta('audio_surface','stone');root.add_child(body)
 var collision=CollisionShape3D.new();var shape=ConvexPolygonShape3D.new();shape.points=vertices;collision.shape=shape;body.add_child(collision)
 return mesh
static func add_to(scene:Node3D)->Array:
 var api=preload('res://scripts/market_expansion.gd')
 var timber=preload('res://scripts/market_wall_finish.gd').wood()
 var cream=api.mat(Color('#c9bc98'));cream.cull_mode=BaseMaterial3D.CULL_DISABLED
 var bronze=scene.courtyard_material('market_bronze',Color('#9b7944'),'bronze')
 var roots=[]
 for id in ['Atlas','Dan']:
  var shop=scene.get_node('MarketExpansion/'+id+'Stand')
  assert(not shop.has_node('RearRoofRepair'),'Repair must apply once')
  var repair=Node3D.new();repair.name='RearRoofRepair';shop.add_child(repair);roots.append(repair)
  var half=3.5 if id=='Atlas' else 5.0;var back=-3.7 if id=='Atlas' else -3.2
  var post_x=half-.25
  var target=3.975 if id=='Atlas' else dan_underside(post_x)+.01
  for x in [-post_x,post_x]:
   api.box(repair,'Rear corner post extension',Vector3(x,(3.74+target)*.5,back),Vector3(.2,target-3.74,.2),timber)
   api.box(repair,'Rear post bronze splice',Vector3(x,3.75,back),Vector3(.23,.09,.23),bronze)
  if id=='Atlas':
   api.box(repair,'Rear upper mineral infill',Vector3(0,(3.49+3.975)*.5,back),Vector3(6.6,3.975-3.49,.18),cream,true)
   api.box(repair,'Rear upper timber head rail',Vector3(0,3.90,back-.14),Vector3(6.6,.14,.16),timber)
  else:
   gable(repair,api,cream)
   for side in [-1,1]:
    preload('res://scripts/market_facades.gd').beam(api,repair,'Rear fitted gable rake',Vector3(side*4.7,dan_underside(4.7)-.055,back-.14),Vector3(0,dan_underside(0)-.055,back-.14),.11,timber)
  for x in [-half+.3,-half/3,half/3,half-.3]:
   var top=3.975 if id=='Atlas' else dan_underside(absf(x)+.08)+.01
   api.box(repair,'Rear upper bay upright',Vector3(x,(3.49+top)*.5,back-.14),Vector3(.16,top-3.49,.16),timber)
  repair.set_meta('repair_journal',{'role':id,'old_post_top':3.75,'new_post_top':target,'old_wall_top':3.5,'new_wall_edge_top':3.975 if id=='Atlas' else dan_underside(4.8)+.01,'roof_underside_at_posts':3.96 if id=='Atlas' else dan_underside(post_x),'existing_shapes_modified':0,'new_collision_shapes':1,'scope':'rear wall, rear corner posts and matching upper bay joinery; front awning unchanged'})
  if id=='Atlas':preload('res://scripts/shop_surround_detail.gd').finish_repair(shop,repair)
 return roots
