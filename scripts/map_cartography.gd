extends Control
# Only drawn inside an UPDATE_ONCE viewport; presentation uses its single texture.
const TransformModel=preload("res://scripts/map_transform.gd")
var layers={}
var transform_model=TransformModel.new()
var accepted=0
var rejected=0
static func valid_polygon(points:PackedVector2Array)->bool:
 if points.size()<3:return false
 var area=0.0;var bounds=Rect2(points[0],Vector2.ZERO)
 for i in range(points.size()):
  if not points[i].is_finite():return false
  area+=points[i].cross(points[(i+1)%points.size()]);bounds=bounds.expand(points[i])
 if bounds.size.x<.5 or bounds.size.y<.5 or absf(area)*.5<.5:return false
 return Geometry2D.triangulate_polygon(points).size()==(points.size()-2)*3
func _draw():
 accepted=0;rejected=0
 transform_model.resize(Rect2(Vector2.ZERO,size));transform_model.fit()
 draw_rect(Rect2(Vector2.ZERO,size),Color("263d30"))
 for kind in ["terrain","water","paths","buildings"]:
  for row in layers.get(kind,[]):
   var screen=PackedVector2Array()
   for point in row.polygon:screen.append(transform_model.project(point))
   if not valid_polygon(screen):rejected+=1;continue
   var color={"terrain":Color("4c6549"),"water":Color("468594"),"paths":Color("c9b58d"),"buildings":Color("907862")}[kind]
   if kind=="terrain":color=color.lightened(clampf(float(row.get("height",0))*.025,0,.18))
   draw_colored_polygon(screen,color);accepted+=1
