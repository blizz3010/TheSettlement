extends RefCounted
# Clip individual pavers against the actual faceted support, not a center-radius test.
static func footprint(mesh:Mesh,t:Transform3D)->PackedVector2Array:
 var points=PackedVector2Array()
 for vertex in mesh.get_faces():
  var p=t*vertex;points.append(Vector2(p.x,p.z))
 return Geometry2D.convex_hull(points)
static func prism(poly:PackedVector2Array,bottom:float,top:float)->ArrayMesh:
 var indices=Geometry2D.triangulate_polygon(poly)
 assert(not indices.is_empty())
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for j in range(0,indices.size(),3):
  for k in [0,1,2]:
   var p=poly[indices[j+k]];st.set_normal(Vector3.UP);st.add_vertex(Vector3(p.x,top,p.y))
  for k in [2,1,0]:
   var p=poly[indices[j+k]];st.set_normal(Vector3.DOWN);st.add_vertex(Vector3(p.x,bottom,p.y))
 for i in range(poly.size()):
  var a=poly[i];var b=poly[(i+1)%poly.size()]
  var n=Vector3(b.y-a.y,0,a.x-b.x).normalized()
  for p in [Vector3(a.x,top,a.y),Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y),Vector3(a.x,top,a.y),Vector3(b.x,bottom,b.y),Vector3(b.x,top,b.y)]:
   st.set_normal(n);st.add_vertex(p)
 return st.commit()
# Fountain plaza only. Keep the one-metre module and the real outer support hull,
# but use shallow 12 mm joints instead of raised 25 mm slots. The radial apron
# remains the visual accent; trim every adjacent slab to its edge, including cells
# whose centres sit inside the circle but whose corners are still exposed.
const PLAZA_JOINT := 0.012
const PLAZA_TOP := 0.060
const APRON_RADIUS := 4.68
const APRON_SEGMENTS := 192
static func apron_clearance()->PackedVector2Array:
 var boundary=PackedVector2Array()
 for i in range(APRON_SEGMENTS):
  var angle=TAU*float(i)/float(APRON_SEGMENTS)
  boundary.append(Vector2(cos(angle),sin(angle))*(APRON_RADIUS+PLAZA_JOINT))
 return boundary
static func add_tiles(scene:Node3D,support:MeshInstance3D,stone:Material):
 var boundary=footprint(support.mesh,support.global_transform)
 var apron=apron_clearance()
 var holder=Node3D.new();holder.name='SupportedPlazaTiles';scene.add_child(holder)
 var journal=[]
 var cells={}
 for x in range(-9,10):
  for z in range(-9,10):
   # Retain the original outer tile selection and support polygon. Neither routes
   # nor garden authority masks are derived from the new apron trim.
   if Vector2(x,z).length()>=9.5:continue
   var half=(1.0-PLAZA_JOINT)/2.0
   var cell=Vector2i(x,z)
   var rect=Rect2(Vector2(cell)-Vector2.ONE*half,Vector2.ONE*half*2)
   var tile=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
   var supported=Geometry2D.intersect_polygons(tile,boundary)
   assert(supported.size()==1)
   var clipped=Geometry2D.clip_polygons(supported[0],apron)
   if clipped.is_empty():continue
   assert(clipped.size()==1)
   cells[cell]={'rect':rect,'original':tile,'supported':clipped[0]}
 # Absorb eight very small corner cuts into the next full stone. Extending that
 # neighbour's cutting blank across the joint avoids loose triangular chips.
 # This affects only the circle/grid meeting, never the plaza's outside edge.
 var absorbed=[]
 for cell in cells:
  var row=cells[cell];var area=0.0;var poly:PackedVector2Array=row.supported
  for i in poly.size():area+=poly[i].cross(poly[(i+1)%poly.size()])
  if absf(area)*.5>=.02:continue
  var step=Vector2i(signi(cell.x),0) if absi(cell.x)>absi(cell.y) else Vector2i(0,signi(cell.y))
  var neighbour=cell+step
  assert(cells.has(neighbour))
  var rect:Rect2=cells[neighbour].rect.merge(row.rect)
  var blank=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
  var cut=Geometry2D.clip_polygons(blank,apron)
  assert(cut.size()==1)
  cells[neighbour]={'rect':rect,'original':blank,'supported':cut[0]}
  absorbed.append(cell)
 for cell in absorbed:cells.erase(cell)
 for cell in cells:
  var row=cells[cell];var poly:PackedVector2Array=row.supported
  assert(not Geometry2D.is_polygon_clockwise(poly))
  var mesh=MeshInstance3D.new();mesh.name='Paver_%d_%d'%[cell.x,cell.y]
  mesh.mesh=prism(poly,.0395,PLAZA_TOP);mesh.material_override=stone;holder.add_child(mesh)
  journal.append({'center':Vector2(cell),'original':row.original,'supported':poly})
 holder.set_meta('support_polygon',boundary);holder.set_meta('journal',journal)
 holder.set_meta('apron_clearance',apron)
 holder.set_meta('paving_finish',{'joint_m':PLAZA_JOINT,'top_m':PLAZA_TOP,'apron_radius_m':APRON_RADIUS,'collision_added':0,'absorbed_slivers':absorbed.size()})
static func join_hideout(root:Node3D,slabs:Array,stone:Material):
 # Only the small concave notch between the two existing terminal cross-sections.
 # Preserve both original slab transforms and the full-width stair mouth.
 var points=PackedVector2Array();var polys=[]
 for i in range(2):
  var mesh=slabs[i].get_child(0) as MeshInstance3D
  polys.append(footprint(mesh.mesh,mesh.global_transform))
  var z=-mesh.mesh.size.z/2 # First destination and aligned second north/start edge.
  for x in [-mesh.mesh.size.x/2,mesh.mesh.size.x/2]:
   var p=mesh.to_global(Vector3(x,0,z));points.append(Vector2(p.x,p.z))
 var gaps=[Geometry2D.convex_hull(points)]
 for poly in polys:
  var rest=[]
  for gap in gaps:rest.append_array(Geometry2D.clip_polygons(gap,poly))
  gaps=rest
 var journal=[]
 for gap in gaps:
  if Geometry2D.triangulate_polygon(gap).is_empty():continue
  var body=StaticBody3D.new();body.name='SupportedApproachJoin';body.set_meta('audio_surface','stone');root.add_child(body)
  var mesh=MeshInstance3D.new();mesh.mesh=prism(gap,-.025,.055);mesh.material_override=stone;body.add_child(mesh)
  var collider=CollisionShape3D.new();var shape=ConvexPolygonShape3D.new();var vertices=PackedVector3Array()
  for p in gap:
   vertices.append(Vector3(p.x,-.025,p.y));vertices.append(Vector3(p.x,.055,p.y))
  shape.points=vertices;collider.shape=shape;body.add_child(collider)
  journal.append(gap)
 root.set_meta('supported_join_polygons',journal)
