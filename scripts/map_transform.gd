extends RefCounted
const Envelope=preload("res://scripts/settlement_envelope.gd")
var viewport=Rect2(0,0,600,500)
# Map-only southern margin reveals the lake shore; never changes gameplay envelope.
var world_bounds=Rect2(-72,-64,144,144)
var center=Vector2.ZERO
var zoom:float=1
func scale_value()->float:return minf(viewport.size.x/world_bounds.size.x,viewport.size.y/world_bounds.size.y)*zoom
func project(world:Vector2)->Vector2:return viewport.get_center()+(world-center)*scale_value()
func inverse(pixel:Vector2)->Vector2:return center+(pixel-viewport.get_center())/scale_value()
func clamp_center():
	var half=viewport.size/(2*scale_value())
	for axis in range(2):
		center[axis]=world_bounds.get_center()[axis] if half[axis]*2>=world_bounds.size[axis] else clampf(center[axis],world_bounds.position[axis]+half[axis],world_bounds.end[axis]-half[axis])
func resize(rect:Rect2)->bool:
	if not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x<=0 or rect.size.y<=0:return false
	viewport=rect;clamp_center();return true
func zoom_at(factor:float,pixel:Vector2)->bool:
	if not is_finite(factor) or factor<=0 or not pixel.is_finite() or not viewport.has_point(pixel):return false
	var anchor=inverse(pixel);zoom=clampf(zoom*factor,1,8);center=anchor-(pixel-viewport.get_center())/scale_value();clamp_center();return true
func pan(delta:Vector2):
	if not delta.is_finite():return
	center-=delta/scale_value();clamp_center()
func fit():zoom=1;center=world_bounds.get_center();clamp_center()
