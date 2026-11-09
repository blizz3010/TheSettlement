extends RefCounted
## Selected park A only. Pure geometry/grade; no scene, state or asset dependencies.
const ENVELOPE=Rect2(-22.0,-22.7,9.1,6.2)
const SPUR=Rect2(-17.0,-20.0,4.1,2.2)
const NORTH_PAD=Rect2(-18.2,-22.3,2.4,2.0)
const SOUTH_PAD=Rect2(-18.2,-18.95,2.4,2.0)
const LINK=Rect2(-18.1,-20.3,2.2,.3)
const PAVING=[SPUR,NORTH_PAD,SOUTH_PAD,LINK]
const ENTRY=Vector2(-12.9,-18.9)
const TREE=Vector2(-13.5,-21.0)
const LAMP=Vector2(-14.6,-15.0)
const UNDER_PAVING=.015
static var _topology_cache:Dictionary={}
static var _axis_cache:Dictionary={}
static var _cell_topology_cache:Dictionary={}
const SPECIAL_X=[-22.0,-18.2,-18.1,-17.0,-15.9,-15.8,-12.9]
const SPECIAL_Z=[-22.7,-22.3,-21.3,-20.3,-20.0,-18.9,-18.95,-17.8,-17.7,-16.95,-16.5]
static func inside(p:Vector2)->bool:
 return p.x>=ENVELOPE.position.x and p.x<=ENVELOPE.end.x and p.y>=ENVELOPE.position.y and p.y<=ENVELOPE.end.y
static func rect_distance(p:Vector2,r:Rect2)->float:
 return p.distance_to(Vector2(clampf(p.x,r.position.x,r.end.x),clampf(p.y,r.position.y,r.end.y)))
static func paved(p:Vector2)->bool:
 for r in PAVING:
  if rect_distance(p,r)<.00001:return true
 return false
static func paving_distance(p:Vector2)->float:
 var d=INF
 for r in PAVING:d=minf(d,rect_distance(p,r))
 return d
static func paving_top(p:Vector2)->float:
 # Original edge y=.08. Reach the level seat-pad zone before overlapping it.
 return lerpf(.18,.08,clampf((p.x+15.8)/2.9,0.0,1.0))
static func grade(p:Vector2,old_mesh_height:float)->float:
 if not inside(p):return old_mesh_height
 var d=paving_distance(p)
 if d>=2.0:return old_mesh_height
 var edge=minf(minf(p.x-ENVELOPE.position.x,ENVELOPE.end.x-p.x),minf(p.y-ENVELOPE.position.y,ENVELOPE.end.y-p.y))
 var amount=1.0-smoothstep(0.0,2.0,d)
 if d>.00001:amount=minf(amount,clampf(edge/maxf(edge+d,.00001),0.0,1.0))
 # Preserve current tree/trunk roots and the full waylamp terrain exclusion.
 amount*=smoothstep(.75,1.0,p.distance_to(TREE))
 amount*=smoothstep(1.5,1.8,p.distance_to(LAMP))
 # At the existing path edge the old ground remains below the joined paving.
 if p.x> -13.15:amount*=1.0-smoothstep(-13.15,-12.9,p.x)
 return maxf(-.05,lerpf(old_mesh_height,paving_top(p)-UNDER_PAVING,amount))
static func axis_breaks(cell:int,is_x:bool)->Array:
 var key=Vector2i(cell,1 if is_x else 0)
 if _axis_cache.has(key):return _axis_cache[key]
 var values=[float(cell),float(cell+1)]
 for i in range(1,4):values.append(cell+i*.25)
 for v in SPECIAL_X if is_x else SPECIAL_Z:
  if v>cell+.00001 and v<cell+1-.00001:values.append(v)
 values.sort();_axis_cache[key]=values
 assert(_axis_cache.size()<64,"Bounded local axis cache")
 return values
static func affected_cell(x:int,z:int)->bool:
 return Rect2(x,z,1,1).intersects(ENVELOPE,true)
static func polygon(r:Rect2)->PackedVector2Array:
 return PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
static func triangles_for_rect(x:int,z:int,r:Rect2)->Array:
 var key=Vector4(r.position.x,r.position.y,r.size.x,r.size.y)
 if _topology_cache.has(key):return _topology_cache[key]
 # Split at the original one-metre diagonal, so unchanged outside portions retain
 # their EXACT old triangle plane instead of resampling a curved analytic field.
 var a=Vector2(x,z);var b=a+Vector2.RIGHT;var c=a+Vector2.DOWN;var d=a+Vector2.ONE
 var triangles=[]
 for old in [PackedVector2Array([a,b,c]),PackedVector2Array([b,d,c])]:
  for clipped in Geometry2D.intersect_polygons(old,polygon(r)):
   # Canonicalize float32 polygon-clip noise before triangulation. At the
   # -18.2/-17.8 diagonal intersection clipping otherwise emits a micron sliver.
   # Integer-round/divide on a shared 0.1mm lattice avoids Vector2.snapped's
   # float32 step multiplication creating adjacent -18.2/-18.20001 variants.
   # All authored quarter/centimetre breaks already lie on this lattice;
   # grade is sampled AFTER welding, identically for render and collision.
   var welded=PackedVector2Array()
   for point in clipped:
    var canonical=Vector2(roundf(point.x*10000.0)/10000.0,roundf(point.y*10000.0)/10000.0)
    if welded.is_empty() or canonical!=welded[-1]:welded.append(canonical)
   if welded.size()>1 and welded[0]==welded[-1]:welded.remove_at(welded.size()-1)
   if welded.size()<3:continue
   var indices=Geometry2D.triangulate_polygon(welded)
   for i in range(0,indices.size(),3):
    var a2=welded[indices[i]];var b2=welded[indices[i+1]];var c2=welded[indices[i+2]]
    if absf((b2-a2).cross(c2-a2))<.00000001:continue
    triangles.append([a2,b2,c2])
 _topology_cache[key]=triangles
 assert(_topology_cache.size()<=4096,"Bounded local topology cache")
 return triangles
static func cell_triangles(x:int,z:int)->Array:
 var key=Vector2i(x,z)
 if _cell_topology_cache.has(key):return _cell_topology_cache[key]
 var xs=axis_breaks(x,true);var zs=axis_breaks(z,false);var result=[]
 for i in range(xs.size()-1):
  for j in range(zs.size()-1):
   var r=Rect2(xs[i],zs[j],xs[i+1]-xs[i],zs[j+1]-zs[j])
   result.append_array(triangles_for_rect(x,z,r))
 _cell_topology_cache[key]=result
 assert(_cell_topology_cache.size()<=128,'Bounded local full-cell topology cache')
 return result
static func cell_faces(x:int,z:int,vertex_height:Callable)->PackedVector3Array:
 var faces=PackedVector3Array()
 for tri in cell_triangles(x,z):
  # Match existing terrain winding (a,b,c) and upward visible face.
  var ordered=tri.duplicate()
  if (ordered[1]-ordered[0]).cross(ordered[2]-ordered[0])<0:ordered.reverse()
  for p in ordered:faces.append(Vector3(p.x,vertex_height.call(p),p.y))
 return faces
static func _interpolated_height(p:Vector2,t:Array,vertex_height:Callable):
 var a:Vector2=t[0];var b:Vector2=t[1];var c:Vector2=t[2];var determinant=(b-a).cross(c-a)
 if absf(determinant)<.0000001:return null
 var wb=(p-a).cross(c-a)/determinant;var wc=(b-a).cross(p-a)/determinant;var wa=1.0-wb-wc
 if minf(wa,minf(wb,wc))<-.00001:return null
 return vertex_height.call(a)*wa+vertex_height.call(b)*wb+vertex_height.call(c)*wc
static func surface_height(p:Vector2,vertex_height:Callable)->float:
 var x=int(floorf(p.x));var z=int(floorf(p.y));var xs=axis_breaks(x,true);var zs=axis_breaks(z,false)
 var r=Rect2(x,z,1,1)
 for i in range(xs.size()-1):
  if p.x>=xs[i]-.000001 and p.x<=xs[i+1]+.000001:r.position.x=xs[i];r.size.x=xs[i+1]-xs[i];break
 for j in range(zs.size()-1):
  if p.y>=zs[j]-.000001 and p.y<=zs[j+1]+.000001:r.position.y=zs[j];r.size.y=zs[j+1]-zs[j];break
 for t in triangles_for_rect(x,z,r):
  var height=_interpolated_height(p,t,vertex_height)
  if height!=null:return height
 # Decimal subrect bounds and the welded float32 edge can select opposite
 # sides of a tiny boundary. Search the SAME cached triangles as the mesh;
 # never substitute curved analytical grade for an existing triangle plane.
 for t in cell_triangles(x,z):
  var height=_interpolated_height(p,t,vertex_height)
  if height!=null:return height
 assert(false,'Park surface has no containing actual cell triangle at '+str(p))
 return NAN
