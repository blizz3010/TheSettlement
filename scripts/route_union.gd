extends RefCounted
# SOURCE-ONLY CANDIDATE. Native execution and visual acceptance still required.
const EPS=0.0001
static func signed_area(p:PackedVector2Array)->float:
 var a=0.0
 for i in range(p.size()):a+=p[i].cross(p[(i+1)%p.size()])
 return a*.5
static func normalized(p:PackedVector2Array)->PackedVector2Array:
 var q=p.duplicate()
 for v in q:
  if not v.is_finite():return PackedVector2Array()
 if q.size()>1 and q[0].is_equal_approx(q[-1]):q.remove_at(q.size()-1)
 if q.size()<3 or absf(signed_area(q))<=EPS:return PackedVector2Array()
 if Geometry2D.is_polygon_clockwise(q):q.reverse()
 return q
static func area(polys:Array)->float:
 var a=0.0
 for p in polys:a+=absf(signed_area(p))
 return a
static func covered(p:PackedVector2Array,components:Array)->bool:
 # Every source polygon must be contained by one union component.
 for c in components:
  if area(Geometry2D.clip_polygons(p,c))<=EPS:return true
 return false
static func union_exact(source:Array)->Array:
 var components=[]
 for raw in source:
  var current=normalized(raw);var i=0
  if current.is_empty():return []
  while i<components.size():
   var combined=Geometry2D.merge_polygons(current,components[i])
   for p in combined:
    if Geometry2D.is_polygon_clockwise(p):return []
   if combined.size()==1:
    current=normalized(combined[0]);components.remove_at(i);i=0
   else:
    if combined.size()!=2:return []
    i+=1
  components.append(current)
 for p in source:
  if not covered(normalized(p),components):return []
 return components
static func inside_any(p:Vector2,polys:Array)->bool:
 for q in polys:
  if Geometry2D.is_point_in_polygon(p,q):return true
 return false
static func scan_intervals(polys:Array,z:float)->Array:
 var intervals=[]
 for poly in polys:
  var hits=[]
  for i in range(poly.size()):
   var a=poly[i];var b=poly[(i+1)%poly.size()]
   if (a.y<=z and b.y>z) or (b.y<=z and a.y>z):hits.append(a.x+(z-a.y)*(b.x-a.x)/(b.y-a.y))
  hits.sort()
  if hits.size()%2!=0:return [Vector2(NAN,NAN)]
  for i in range(0,hits.size(),2):intervals.append(Vector2(hits[i],hits[i+1]))
 intervals.sort_custom(func(a,b):return a.x<b.x)
 var merged=[]
 for v in intervals:
  if merged.is_empty() or v.x>merged[-1].y+0.000001:merged.append(v)
  else:merged[-1].y=maxf(merged[-1].y,v.y)
 return merged
static func build(source:Array,material:Material)->Dictionary:
 if source.is_empty():return {'error':'Empty source'}
 var components=union_exact(source)
 if components.is_empty():return {'error':'Rejected union topology'}
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_material(material)
 var top_area=0.0;var triangles=0
 for poly in components:
  var indices=Geometry2D.triangulate_polygon(poly)
  if indices.size()!=(poly.size()-2)*3:return {'error':'Triangulation failed'}
  for i in range(0,indices.size(),3):
   var a=poly[indices[i]];var b=poly[indices[i+1]];var c=poly[indices[i+2]]
   var t=PackedVector2Array([a,b,c]);var ta=absf(signed_area(t))
   if ta<=0 or area(Geometry2D.clip_polygons(t,poly))>EPS:return {'error':'Triangle outside union'}
   top_area+=ta;triangles+=1
   # Godot uses clockwise front faces; XZ CCW is visible from above.
   # Keep shading normal upward independently of geometric cross-product sign.
   for p in [a,b,c]:st.set_normal(Vector3.UP);st.set_uv(p);st.add_vertex(Vector3(p.x,.045,p.y))
  for i in range(poly.size()):
   var a=poly[i];var b=poly[(i+1)%poly.size()]
   var aa=Vector3(a.x,.045,a.y);var bb=Vector3(b.x,.045,b.y)
   var ab=Vector3(a.x,-.035,a.y);var bc=Vector3(b.x,-.035,b.y)
   var n=Vector3(b.y-a.y,0,a.x-b.x).normalized()
   for v in [aa,ab,bb,bb,ab,bc]:st.set_normal(n);st.set_uv(Vector2(v.x,v.z));st.add_vertex(v)
   triangles+=2
 if absf(top_area-area(components))>EPS:return {'error':'Area mismatch'}
 # Independent bounded raster equivalence, not a substitute for source coverage checks.
 var lo=Vector2(INF,INF);var hi=Vector2(-INF,-INF)
 for p in source:
  for v in p:lo=lo.min(v);hi=hi.max(v)
 var mismatches=0;var samples=0;var max_boundary_delta=0.0
 # Compare complete X intervals on every 2cm Z scanline; stronger and cheaper than point raster.
 for z in range(int(floorf(lo.y/.02)),int(ceilf(hi.y/.02))+1):
  var height=z*.02+.0061;var a=scan_intervals(source,height);var b=scan_intervals(components,height);samples+=1
  if a.size()!=b.size():mismatches+=1;continue
  for i in range(a.size()):
   var delta=maxf(absf(a[i].x-b[i].x),absf(a[i].y-b[i].y));max_boundary_delta=maxf(max_boundary_delta,delta)
   if not is_finite(delta) or delta>.0005:mismatches+=1
 if mismatches!=0:return {'error':'Scanline mismatch'}
 return {'mesh':st.commit(),'components':components,'report':{'source_count':source.size(),'component_count':components.size(),'top_area':top_area,'triangles':triangles,'scanlines':samples,'scanline_mismatches':mismatches,'max_boundary_delta_m':max_boundary_delta,'source_coverage_exact':true}}
