extends RefCounted
## Candidate shared envelope. Never moves saved coordinates or reserved plots.
const HORIZONTAL_RADIUS=65.0
const VERTICAL_RADIUS=42.0
const CENTER_Y=-1.0
const COLLISION_INSET=.15
const TERRAIN_EXTENT=66
const MAP_BOUNDS=Rect2(-66,-66,132,132)
const INN_CENTER=Vector2(0,52.7)
const TERRACE=Rect2(-9,43.2,18,17)
const PRESERVED_SITES=[Rect2(-10,32.5,8,7),Rect2(6,34.5,8,7),Rect2(26,29.5,8,7)]
static func radius_at(y:float)->float:
 return HORIZONTAL_RADIUS*sqrt(maxf(0,1-pow((y-CENTER_Y)/VERTICAL_RADIUS,2)))-COLLISION_INSET
static func reservations_clear(rect:Rect2)->bool:
 for site in PRESERVED_SITES:
  if rect.intersects(site):return false
 return not rect.intersects(Rect2(-30,9,12,12))
