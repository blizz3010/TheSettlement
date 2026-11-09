extends RefCounted
# Presentation-only: reserve every icon before placing text. Never move world anchors.
static func arrange(rows:Array,bounds:Rect2,reserved:Array=[])->Array:
 var placed=[];var occupied=reserved.duplicate();var seen=[]
 for row in rows:
  var radius=float(row.get("icon_radius",11))
  if bounds.has_point(row.anchor):occupied.append(Rect2(row.anchor-Vector2.ONE*radius,Vector2.ONE*radius*2))
 for row in rows:
  var anchor:Vector2=row.anchor
  if not bounds.has_point(anchor):continue
  var duplicate=false
  for prior in seen:
   if prior.text==row.text and prior.anchor.distance_to(anchor)<10:duplicate=true;break
  if duplicate:continue
  seen.append({"text":row.text,"anchor":anchor})
  var extent:Vector2=row.extent
  if extent.x+6>bounds.size.x or extent.y+6>bounds.size.y:continue
  var gap=maxf(14,float(row.get("icon_radius",11))+3)
  for offset in [Vector2(gap,-extent.y-gap),Vector2(-extent.x-gap,-extent.y-gap),Vector2(gap,gap),Vector2(-extent.x-gap,gap),Vector2(-extent.x/2,-extent.y-gap),Vector2(-extent.x/2,gap),Vector2(gap,-extent.y/2),Vector2(-extent.x-gap,-extent.y/2)]:
   var top=anchor+offset
   top.x=clampf(top.x,bounds.position.x+3,bounds.end.x-extent.x-3)
   top.y=clampf(top.y,bounds.position.y+3,bounds.end.y-extent.y-3)
   var rect=Rect2(top,extent);var blocked=false
   for other in occupied:
    if rect.grow(3).intersects(other):blocked=true;break
   if blocked:continue
   occupied.append(rect.grow(3));placed.append({"text":row.text,"rect":rect,"anchor":anchor});break
 return placed
