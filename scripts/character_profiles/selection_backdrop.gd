extends Control
# Lightweight drawn UI artwork; no world loads or external image dependencies.
func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 resized.connect(queue_redraw)
func _draw():
 draw_rect(Rect2(Vector2.ZERO,size),Color("1b211f"))
 var pivot=Vector2(size.x*.76,size.y*.52)
 for i in range(12,0,-1):
  draw_circle(pivot,float(i)*size.y*.065,Color(.10,.18,.17,.035))
 for x in range(0,int(size.x),72):
  draw_line(Vector2(x,0),Vector2(x,size.y),Color(.32,.48,.44,.035),1)
 for y in range(0,int(size.y),72):
  draw_line(Vector2(0,y),Vector2(size.x,y),Color(.32,.48,.44,.035),1)
 draw_polyline(PackedVector2Array([Vector2(0,64),Vector2(size.x*.55,64),Vector2(size.x*.55+24,40),Vector2(size.x,40)]),Color("89623d"),1,true)
 draw_line(Vector2(0,size.y-94),Vector2(size.x,size.y-94),Color("344e48"),1)
