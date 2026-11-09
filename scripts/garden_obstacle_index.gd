extends RefCounted
# Broad-phase acceleration only: stable original record order is preserved.
# Existing exact AABB/narrow-phase predicates still decide every acceptance.
const CELL=2.0
const MAX_CELLS_PER_RECORD=128
static func indexable(bounds:AABB)->bool:
 if not bounds.position.is_finite() or not bounds.size.is_finite() or not bounds.end.is_finite():return false
 if bounds.size.x<0 or bounds.size.y<0 or bounds.size.z<0:return false
 # Keep floor conversion and Rect2i subtraction far inside int32 limits.
 return absf(bounds.position.x)<=1000000.0 and absf(bounds.position.z)<=1000000.0 and absf(bounds.end.x)<=1000000.0 and absf(bounds.end.z)<=1000000.0
static func extent(bounds:AABB)->Rect2i:
 var low=Vector2i(floori(bounds.position.x/CELL),floori(bounds.position.z/CELL))
 var high=Vector2i(floori(bounds.end.x/CELL),floori(bounds.end.z/CELL))
 return Rect2i(low,high-low+Vector2i.ONE)
static func build(records:Array)->Dictionary:
 var bins={};var broad=[]
 for i in range(records.size()):
  var bounds:AABB=records[i].bounds
  if not bounds.position.is_finite() or not bounds.size.is_finite() or not bounds.end.is_finite() or bounds.size.x<0 or bounds.size.y<0 or bounds.size.z<0:return {'ok':false,'reason':'Malformed obstacle bounds'}
  if not indexable(bounds):broad.append(i);continue
  var cells=extent(bounds)
  if cells.size.x*cells.size.y>MAX_CELLS_PER_RECORD:broad.append(i);continue
  for x in range(cells.position.x,cells.end.x):
   for z in range(cells.position.y,cells.end.y):
    var key=Vector2i(x,z)
    if not bins.has(key):bins[key]=[]
    bins[key].append(i)
 return {'ok':true,'records':records,'bins':bins,'broad':broad}
static func candidates(index:Dictionary,screened:AABB)->Array:
 if not indexable(screened):return index.records
 var ids={}
 for i in index.broad:ids[i]=true
 var cells=extent(screened)
 for x in range(cells.position.x,cells.end.x):
  for z in range(cells.position.y,cells.end.y):
   for i in index.bins.get(Vector2i(x,z),[]):ids[i]=true
 var ordered=ids.keys();ordered.sort()
 var result=[]
 for i in ordered:result.append(index.records[i])
 return result
