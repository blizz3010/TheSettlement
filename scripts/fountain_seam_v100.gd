extends RefCounted
# V96-05. Replace the radial asset itself, not a skin above competing geometry.
# Outer ring and square clipping share the exact 192-point polygon and top datum.
const Edges=preload('res://scripts/paving_edges.gd')
static func point(radius:float,angle:float)->Vector2:return Vector2(cos(angle),sin(angle))*radius
static func course(inner:float,outer:float,start:int,end:int)->PackedVector2Array:
 var poly=PackedVector2Array()
 for i in range(start,end+1):poly.append(point(outer,TAU*i/Edges.APRON_SEGMENTS))
 for i in range(end,start-1,-1):poly.append(point(inner,TAU*i/Edges.APRON_SEGMENTS))
 return poly
static func apply(node:MeshInstance3D)->Dictionary:
 if node.has_meta('fountain_seam_v100'):return node.get_meta('fountain_seam_v100')
 if node.mesh==null or str(node.name)!='fountain_apron':return {'ok':false,'reason':'Not the radial apron owner'}
 var bounds=node.mesh.get_aabb()
 if not bounds.position.is_equal_approx(Vector3(-4.68,.058,-4.68)) or not bounds.size.is_equal_approx(Vector3(9.36,.018,9.36)):return {'ok':false,'reason':'Unexpected radial apron geometry'}
 var original=node.mesh;var mats=[]
 for s in original.get_surface_count():
  var m=original.surface_get_material(s)
  if m==null or not m.resource_name.begins_with('Limestone_Fountain_'):return {'ok':false,'reason':'Unrecognized apron material'}
  mats.append(m)
 if mats.size()!=4:return {'ok':false,'reason':'Expected four limestone surfaces'}
 var builders=[]
 for m in mats:
  var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_material(m);builders.append(st)
 var pieces=0;var triangles=0
 # Retain a legible radial arrangement. Narrow shallow joints replace the deep
 # original 18 mm slots. The outer 20 cm course has no broken radial joints.
 for ring in 3:
  var inner=[2.90,3.42,3.96][ring];var outer=[3.408,3.948,4.468][ring]
  for sector in 48:
   var a=sector*4;var poly=course(inner,outer,a,a+4)
   # Inset radial ends by 6 mm, preserving curved inner/outer boundaries.
   var tangent=Vector2(-sin(TAU*a/192.0),cos(TAU*a/192.0))*.006
   poly[0]+=tangent;poly[poly.size()-1]+=tangent
   var tangent_end=Vector2(-sin(TAU*(a+4)/192.0),cos(TAU*(a+4)/192.0))*.006
   poly[4]-=tangent_end;poly[5]-=tangent_end
   var mesh=Edges.prism(poly,.050,Edges.PLAZA_TOP)
   builders[(sector+ring)%4].append_from(mesh,0,Transform3D.IDENTITY);triangles+=mesh.get_faces().size()/3;pieces+=1
 # A single annulus, with no duplicated radial end walls at sector seams.
 var border:SurfaceTool=builders[0]
 for i in Edges.APRON_SEGMENTS:
  var a=point(4.48,TAU*i/Edges.APRON_SEGMENTS);var b=point(Edges.APRON_RADIUS,TAU*i/Edges.APRON_SEGMENTS)
  var c=point(Edges.APRON_RADIUS,TAU*(i+1)/Edges.APRON_SEGMENTS);var d=point(4.48,TAU*(i+1)/Edges.APRON_SEGMENTS)
  for spec in [[Edges.PLAZA_TOP,Vector3.UP,[a,b,c,a,c,d]],[.050,Vector3.DOWN,[c,b,a,d,c,a]]]:
   for p in spec[2]:border.set_normal(spec[1]);border.add_vertex(Vector3(p.x,spec[0],p.y))
  for edge in [[b,c,1.0],[d,a,-1.0]]:
   var n=Vector3((edge[0].x+edge[1].x)*.5,0,(edge[0].y+edge[1].y)*.5).normalized()*edge[2]
   for p in [Vector3(edge[0].x,.060,edge[0].y),Vector3(edge[0].x,.050,edge[0].y),Vector3(edge[1].x,.050,edge[1].y),Vector3(edge[0].x,.060,edge[0].y),Vector3(edge[1].x,.050,edge[1].y),Vector3(edge[1].x,.060,edge[1].y)]:border.set_normal(n);border.add_vertex(p)
  triangles+=8
 pieces+=1
 var result_mesh=ArrayMesh.new()
 for st in builders:st.commit(result_mesh)
 node.mesh=result_mesh
 var result={'ok':true,'source_replaced':true,'new_overlay_nodes':0,'shared_top_m':Edges.PLAZA_TOP,'outer_radius_m':Edges.APRON_RADIUS,'outer_segments':Edges.APRON_SEGMENTS,'border_width_m':.20,'triangles':triangles,'pieces':pieces,'surfaces_before':4,'surfaces_after':4,'collision_changes':0,'native_visual_pass':false}
 node.set_meta('fountain_seam_v100',result);node.set_meta('fountain_seam_source',original)
 return result
