extends RefCounted
# Conservative support/solid bounds for the original compact cot; no gameplay effects.
const SIZE = Vector3(1.856,0.95,1.055)
const OFFSET = Vector3(-0.38,0,-0.055)
static func origin(cell:Vector2i, side:int) -> Vector3:
	return Vector3(cell.x*2,0,cell.y*2)+OFFSET.rotated(Vector3.UP,-side*PI/2)
static func half_size(side:int) -> Vector3:
	return SIZE*0.5 if side%2==0 else Vector3(SIZE.z,SIZE.y,SIZE.x)*0.5
static func overlaps_box(cell:Vector2i,side:int,center:Vector3,size:Vector3) -> bool:
	var d=origin(cell,side)+Vector3(0,SIZE.y/2,0)-center
	var h=half_size(side)+size/2
	return absf(d.x)<h.x-0.001 and absf(d.z)<h.z-0.001 and absf(d.y)<h.y-0.001
static func support_cells(cell:Vector2i,side:int) -> Array[Vector2i]:
	var result:Array[Vector2i]=[]
	var o=origin(cell,side);var h=half_size(side)
	for x in range(cell.x-1,cell.x+2):
		for z in range(cell.y-1,cell.y+2):
			if absf(o.x-x*2)<h.x+1-0.001 and absf(o.z-z*2)<h.z+1-0.001:result.append(Vector2i(x,z))
	return result
static func overlaps_wall(cell:Vector2i,side:int,wallcell:Vector2i,wallside:int) -> bool:
	var direction=[Vector3(0,0,-1),Vector3(1,0,0),Vector3(0,0,1),Vector3(-1,0,0)][wallside]
	var center=Vector3(wallcell.x*2,1.5,wallcell.y*2)+direction*.8
	var size=Vector3(1.98,3,.36) if wallside%2==0 else Vector3(.36,3,1.98)
	return overlaps_box(cell,side,center,size)
static func parts() -> Array:
	# One conservative collider includes frame and headboard; decorative textiles never collide separately.
	return [{"position":Vector3(0,SIZE.y/2,0),"size":SIZE}]
