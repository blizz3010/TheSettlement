extends "res://scripts/clothing_preview.gd"
# Read-only presentation of the same appearance and equipped clothing as inventory.
# The body remains the game's provisional static mannequin, not a new character rig.
var camera:Camera3D
var render_view:SubViewport
var angle:=0.0
func _ready():
 super._ready()
 custom_minimum_size=Vector2(220,220)
 size_flags_vertical=Control.SIZE_EXPAND_FILL
 size_flags_horizontal=Control.SIZE_EXPAND_FILL
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 render_view=get_child(0) as SubViewport
 render_view.transparent_bg=true
 for node in stage.get_children():
  if node is Camera3D:camera=node
 camera.position=Vector3(.85,1.35,3.8)
 camera.look_at(Vector3(0,1.04,0))
 camera.size=2.25
 # Render only after selection, resize or deliberate rotation. No idle GPU loop.
 render_view.render_target_update_mode=SubViewport.UPDATE_ONCE
 resized.connect(redraw_preview)
func redraw_preview():
 if is_instance_valid(render_view):render_view.render_target_update_mode=SubViewport.UPDATE_ONCE
func set_angle(degrees:float):
 angle=clampf(degrees,-90,90)
 if not is_instance_valid(camera):return
 var a=deg_to_rad(angle)
 camera.position=Vector3(sin(a)*3.8,1.35,cos(a)*3.8)
 camera.look_at(Vector3(0,1.04,0))
 redraw_preview()
func present(appearance:Dictionary,inventory)->bool:
 show_equipped(inventory.hotbar_context())
 var ok=show_appearance(appearance)
 set_angle(12)
 redraw_preview()
 return ok
