extends RefCounted
# Visual-only connector/market contact. No collision or paving metadata writes.
const U=preload('res://scripts/route_union.gd')
const WIDTH=.25
const LOW=.025
const HIGH=.045
const EPS=.0001
static func clean(polys:Array)->Array:
 var out=[]
 for p in polys:
  # A hole cannot safely be treated as an independent filled polygon.
  if Geometry2D.is_polygon_clockwise(p):return []
  var q=U.normalized(p)
  if q.is_empty():return []
  out.append(q)
 return out
static func difference(source:Array,cutters:Array)->Dictionary:
 var result=source.duplicate()
 for cutter in cutters:
  var next=[]
  for p in result:
   var raw=Geometry2D.clip_polygons(p,cutter)
   var checked=clean(raw)
   if checked.size()!=raw.size():return {'error':'Hole or degenerate difference rejected'}
   next.append_array(checked)
  result=next
 return {'polys':result}
static func intersection(source:Array,cutters:Array)->Dictionary:
 var out=[]
 for p in source:
  for c in cutters:
   var raw=Geometry2D.intersect_polygons(p,c);var checked=clean(raw)
   if checked.size()!=raw.size():return {'error':'Hole or degenerate intersection rejected'}
   out.append_array(checked)
 return {'polys':out}
static func distance_to_market(p:Vector2,market:Array)->float:
 var d=INF
 for poly in market:
  for i in range(poly.size()):d=minf(d,p.distance_to(Geometry2D.get_closest_point_to_segment(p,poly[i],poly[(i+1)%poly.size()])))
 return d
static func height(p:Vector2,market:Array)->float:
 return lerpf(HIGH,LOW,clampf(distance_to_market(p,market)/WIDTH,0,1))
static func emit(st:SurfaceTool,a:Vector2,b:Vector2,c:Vector2,market:Array,graded:bool,depth:int=0)->float:
 # Keep shared polygon triangulation edges intact: adaptive per-triangle splits
 # create float32 T-junctions. Straight bands are planar; corner bands use
 # bounded piecewise-planar interpolation between exact contact/exterior vertices.
 var aa=Vector3(a.x,height(a,market) if graded else LOW,a.y);var bb=Vector3(b.x,height(b,market) if graded else LOW,b.y);var cc=Vector3(c.x,height(c,market) if graded else LOW,c.y)
 var normal=(cc-aa).cross(bb-aa).normalized()
 if normal.y<=0:return -INF
 for v in [aa,bb,cc]:st.set_normal(normal);st.set_uv(Vector2(v.x,v.z));st.add_vertex(v)
 return absf(U.signed_area(PackedVector2Array([a,b,c])))
static func restore_caps(polys:Array,caps:Array)->Array:
 # Geometry2D Boolean clipping rounds inputs. Restore only frozen external
 # endpoint vertices, never shift a contact boundary or expand the footprint.
 var restored=[]
 for poly in polys:
  var p=poly.duplicate()
  for i in range(p.size()):
   for cap in caps:
    if p[i].distance_to(cap)<=EPS:p[i]=cap;break
  restored.append(p)
 return restored
static func prepare(world:Node3D,market:Array,material:Material)->Dictionary:
 if world.global_transform!=Transform3D.IDENTITY or world.has_node('ConnectorMarketContact'):return {'error':'Unknown/already modified world'}
 var records=[];var source=[];var caps=[]
 for i in [1,2]:
  var body=world.get_node_or_null('LaunchpadApproach/StoneConnector%d'%i)
  if body==null or body.get_child_count()!=2:return {'error':'Connector structure changed'}
  var n=body.get_child(1)
  if not n is MeshInstance3D or not n.mesh is BoxMesh:return {'error':'Connector mesh changed'}
  var expected=Vector3(3.2,.08,11 if i==1 else 7.2)
  if not n.mesh.size.is_equal_approx(expected):return {'error':'Connector dimensions changed'}
  var p=preload('res://scripts/market_visual_union.gd').hull(n.mesh,n.global_transform)
  var center=Vector3(16.5,-.015,10) if i==1 else Vector3(22,-.015,6.4)
  var direction=Vector3.RIGHT if i==1 else Vector3.FORWARD
  var expected_transform=Transform3D(Basis.looking_at(direction,Vector3.UP),center)
  if not n.global_transform.is_equal_approx(expected_transform):return {'error':'Connector transform/endpoints changed'}
  var endpoint=INF
  for v in p:endpoint=minf(endpoint,v.x if i==1 else v.y)
  for v in U.normalized(p):
   if (v.x if i==1 else v.y)==endpoint:caps.append(v)
  source.append(p);records.append({'node':n,'mesh':n.mesh,'material':n.material_override,'visible':n.visible,'transform':n.global_transform})
 var corner=world.get_node_or_null('ApproachPathFinish/CornerFill1')
 if not corner is MeshInstance3D or not corner.mesh is ArrayMesh:return {'error':'Corner missing/unsupported mesh'}
 if corner.global_transform!=Transform3D.IDENTITY or corner.mesh.get_surface_count()!=1 or corner.mesh.surface_get_primitive_type(0)!=Mesh.PRIMITIVE_TRIANGLES:return {'error':'Corner transform/topology changed'}
 var corner_vertices=corner.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 if corner_vertices.size()!=3:return {'error':'Corner vertex count changed'}
 var expected_corner=[Vector3(22,.025,10),Vector3(23.6,.025,10),Vector3(22,.025,11.6)]
 for v in corner_vertices:
  var matched=false
  for e in expected_corner:
   if v.distance_to(e)<EPS:matched=true
  if not matched:return {'error':'Corner footprint changed'}
 var cp=preload('res://scripts/market_visual_union.gd').hull(corner.mesh,corner.global_transform)
 var corner_left=difference([cp],market)
 if corner_left.has('error') or U.area(corner_left.polys)>EPS:return {'error':'Corner no longer fully covered'}
 source.append(cp);records.append({'node':corner,'mesh':corner.mesh,'material':corner.material_override,'visible':corner.visible,'transform':corner.global_transform})
 if caps.size()!=4:return {'error':'Expected exactly four external cap endpoints'}
 for cap in caps:
  if U.inside_any(cap,market) or distance_to_market(cap,market)<WIDTH:return {'error':'External endpoint unexpectedly in contact strip'}
 var combined=U.union_exact(source)
 if combined.is_empty():return {'error':'Source union rejected'}
 var remaining=difference(combined,market)
 if remaining.has('error'):return remaining
 remaining.polys=restore_caps(remaining.polys,caps)
 if remaining.polys.is_empty() or U.area(remaining.polys)<=EPS:return {'error':'Empty/near-zero remaining connector footprint'}
 var expanded=[]
 for p in market:
  var raw=Geometry2D.offset_polygon(p,WIDTH,Geometry2D.JOIN_MITER);var q=clean(raw)
  if q.size()!=raw.size():return {'error':'Offset topology rejected'}
  expanded.append_array(q)
 expanded=U.union_exact(expanded)
 if expanded.is_empty():return {'error':'Offset union rejected'}
 var flat=difference(remaining.polys,expanded);var graded=intersection(remaining.polys,expanded)
 if flat.has('error'):return flat
 if graded.has('error'):return graded
 flat.polys=restore_caps(flat.polys,caps);graded.polys=restore_caps(graded.polys,caps)
 var parts=flat.polys+graded.polys
 for cap in caps:
  var found=false
  for poly in parts:
   if cap in poly:found=true
  if not found:return {'error':'Original external endpoint lost'}
 if absf(U.area(parts)-U.area(remaining.polys))>EPS:return {'error':'Partition area mismatch'}
 # Exact coverage, no holes and no duplicate area before any scene mutation.
 var missing=difference(remaining.polys,parts);var excess=difference(parts,remaining.polys)
 if missing.has('error') or excess.has('error') or U.area(missing.polys)>EPS or U.area(excess.polys)>EPS:return {'error':'Partition coverage mismatch'}
 for i in range(parts.size()):
  for j in range(i):
   if U.area(Geometry2D.intersect_polygons(parts[i],parts[j]))>EPS:return {'error':'Duplicate partition coverage'}
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_material(material)
 var area=0.0
 for group in [flat.polys,graded.polys]:
  for p in group:
   var indices=Geometry2D.triangulate_polygon(p)
   if indices.size()!=(p.size()-2)*3:return {'error':'Triangulation rejected'}
   for k in range(0,indices.size(),3):
    var a=p[indices[k]];var b=p[indices[k+1]];var c=p[indices[k+2]]
    if U.signed_area(PackedVector2Array([a,b,c]))<=0:return {'error':'Top winding rejected'}
    area+=emit(st,a,b,c,market,group==graded.polys)
 if not is_finite(area) or absf(area-U.area(remaining.polys))>EPS:return {'error':'Submitted triangle area mismatch'}
 # Retain only exposed connector outer skirts; never recreate an internal contact lip.
 for p in remaining.polys:
  for i in range(p.size()):
   var a=p[i];var b=p[(i+1)%p.size()];var mid=(a+b)*.5
   if distance_to_market(mid,market)<.0005:continue
   var aa=Vector3(a.x,height(a,market),a.y);var bb=Vector3(b.x,height(b,market),b.y)
   var ab=Vector3(a.x,-.055,a.y);var bc=Vector3(b.x,-.055,b.y)
   var normal=Vector3(b.y-a.y,0,a.x-b.x).normalized()
   for v in [aa,ab,bb,bb,ab,bc]:st.set_normal(normal);st.set_uv(Vector2(v.x,v.z));st.add_vertex(v)
 var mesh=st.commit()
 if mesh==null:return {'error':'Empty generated mesh'}
 return {'records':records,'mesh':mesh,'world':world,'market':market,'remaining':remaining.polys,'report':{'top_area':area,'strip_width':WIDTH,'triangles':mesh.surface_get_array_len(0)/3,'originals':3,'market_mesh_changed':false}}
static func valid(p:Dictionary)->bool:
 if p.has('error') or not is_instance_valid(p.get('world')) or p.world.has_node('ConnectorMarketContact'):return false
 for r in p.records:
  if not is_instance_valid(r.node) or r.node.mesh!=r.mesh or r.node.material_override!=r.material or r.node.visible!=r.visible or r.node.global_transform!=r.transform:return false
 return true
static func install(p:Dictionary)->MeshInstance3D:
 if not valid(p):return null
 var n=MeshInstance3D.new();n.name='ConnectorMarketContact';n.mesh=p.mesh
 p.world.add_child(n)
 for r in p.records:r.node.visible=false
 return n
static func rollback(p:Dictionary,n:MeshInstance3D):
 for r in p.records:
  if is_instance_valid(r.node):r.node.mesh=r.mesh;r.node.material_override=r.material;r.node.visible=r.visible
 if is_instance_valid(n):n.get_parent().remove_child(n);n.queue_free()
