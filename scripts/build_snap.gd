extends RefCounted
# A small spatial deadband prevents tiny mouse motion from flickering between
# bare-ground cells. Direct physics hits never use this resolver.
const DEAD_BAND := 0.06
static func cell_at(point: Vector3, previous: Vector2i, retain: bool) -> Vector2i:
 var next := Vector2i(floori(point.x/2.0),floori(point.z/2.0))
 if retain:
  if point.x >= previous.x*2.0-DEAD_BAND and point.x < (previous.x+1)*2.0+DEAD_BAND: next.x=previous.x
  if point.z >= previous.y*2.0-DEAD_BAND and point.z < (previous.y+1)*2.0+DEAD_BAND: next.y=previous.y
 return next

# Only a direct vertical slab-edge hit expresses adjacent placement intent.
# Top/underside hits keep their own cell; no support or bounds rules live here.
static func ceiling_neighbor(cell: Vector2i, normal: Vector3) -> Vector2i:
 if absf(normal.y)>0.1:return cell
 if absf(normal.x)>0.9 and absf(normal.z)<0.1:
  return cell+Vector2i(1 if normal.x>0 else -1,0)
 if absf(normal.z)>0.9 and absf(normal.x)<0.1:
  return cell+Vector2i(0,1 if normal.z>0 else -1)
 return cell
