extends Control
var map_view:Control
func _draw():
 if not is_instance_valid(map_view):return
 var p=map_view.transform_model.project(map_view.player_position)
 var direction=Vector2(-sin(map_view.player_yaw),-cos(map_view.player_yaw))
 var side=Vector2(-direction.y,direction.x)
 draw_circle(p,10,Color("182b24"))
 draw_colored_polygon(PackedVector2Array([p+direction*12,p-direction*7+side*6,p-direction*4,p-direction*7-side*6]),Color("80ffe0"))
