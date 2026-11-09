extends Control
const TransformModel=preload("res://scripts/map_transform.gd")
const Labels=preload("res://scripts/map_label_layout.gd")
const Markers=preload("res://scripts/map_markers.gd")
var transform_model=TransformModel.new()
var markers=Markers.new()
const Cartography=preload("res://scripts/map_cartography.gd")
const OverheadBake=preload("res://scripts/map_overhead_bake.gd")
var scene_snapshot:Node3D
var map_camera:Camera3D
const PlayerOverlay=preload("res://scripts/map_player_overlay.gd")
var layers={}
var construction_rows=[]
var raster:SubViewport
var cartography:Control
var player_overlay:Control
var bake_count=0
var category="All"
var selected_poi=""
func set_survey(value:Dictionary,snapshot:Node3D=null):
 layers=value
 if not is_instance_valid(raster):
  raster=SubViewport.new();raster.size=Vector2i(2048,2048);raster.disable_3d=true
  raster.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(raster)
  cartography=Cartography.new();cartography.size=Vector2(raster.size);raster.add_child(cartography)
 if is_instance_valid(scene_snapshot):
  raster.remove_child(scene_snapshot);scene_snapshot.free()
 scene_snapshot=snapshot
 if is_instance_valid(snapshot):
  cartography.hide()
  map_camera=OverheadBake.setup(raster,snapshot,transform_model.world_bounds)
 else:
  raster.disable_3d=true;cartography.show()
 cartography.layers=layers;cartography.queue_redraw()
 raster.render_target_update_mode=SubViewport.UPDATE_ONCE;bake_count+=1;redraw_map()
func update_player(at:Vector2,yaw:float):
 if player_position==at and is_equal_approx(player_yaw,yaw):return
 player_position=at;player_yaw=yaw
 redraw_map() # Player text shares collision layout; static base remains cached.
func redraw_map():
 queue_redraw()
 if is_instance_valid(player_overlay):player_overlay.queue_redraw()
func poi_hit(at:Vector2)->String:
 for row in layers.get("landmarks",[]):
  if visible_poi(row) and transform_model.project(row.at).distance_to(at)<=12:return row.name
 return ""
func visible_poi(row:Dictionary)->bool:
 if category=="Services" and row.name in ["Lake","Fountain","Your Home","Ship","Fishing spot"]:return false
 if category=="Places" and not row.name in ["Lake","Fountain","Your Home","Ship","Inn","Town Hall","Fishing spot"]:return false
 return not row.name in ["Griddle","Requests"] or transform_model.zoom>=2 or selected_poi==row.name
func locate_player():
 if not can_use():return
 transform_model.center=player_position;transform_model.clamp_center();redraw_map()
func filter_places(value:String):
 category=value;redraw_map()
var input_allowed:Callable
func can_use()->bool:return is_visible_in_tree() and input_allowed.is_valid() and bool(input_allowed.call())
var selected=""
var add_mode=false
var dragging=false
var last=Vector2.ZERO
var player_position=Vector2.ZERO
var player_yaw:float=0
func _ready():
 player_overlay=PlayerOverlay.new();player_overlay.map_view=self;player_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(player_overlay)
 mouse_filter=Control.MOUSE_FILTER_STOP;clip_contents=true;focus_mode=Control.FOCUS_ALL
 resized.connect(func():transform_model.resize(Rect2(Vector2.ZERO,size));redraw_map())
 transform_model.resize(Rect2(Vector2.ZERO,size))
func _gui_input(event):
 if not can_use():dragging=false;add_mode=false;return
 if event is InputEventKey and event.pressed and not event.echo:
  # Host owns map-toggle/Escape even when Delete is a valid custom map binding.
  if event.is_action_pressed("map") or event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_ESCAPE:return
  var movement={KEY_LEFT:Vector2(32,0),KEY_RIGHT:Vector2(-32,0),KEY_UP:Vector2(0,32),KEY_DOWN:Vector2(0,-32)}
  if event.keycode in movement:transform_model.pan(movement[event.keycode]);accept_event()
  elif event.keycode==KEY_DELETE:remove_selected();accept_event()
 if event is InputEventMouseButton:
  if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   transform_model.zoom_at(1.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .8,event.position);accept_event()
  elif event.button_index==MOUSE_BUTTON_MIDDLE:
   dragging=event.pressed;last=event.position;accept_event()
  elif event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
   selected=markers.hit(event.position,transform_model)
   selected_poi=poi_hit(event.position)
   if selected.is_empty() and add_mode:selected=markers.add(transform_model.inverse(event.position),"Marker",markers.revision,transform_model.world_bounds);add_mode=false
   grab_focus();accept_event()
 elif event is InputEventMouseMotion and dragging:
  if (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE)==0:dragging=false
  else:transform_model.pan(event.position-last);last=event.position;accept_event()
 redraw_map()
func add_at_center():
 if not can_use():return
 selected=markers.add(transform_model.center,"Marker",markers.revision,transform_model.world_bounds);redraw_map()
func remove_selected():
 if not can_use():return
 markers.remove(selected,markers.revision);selected="";redraw_map()
func zoom_button(factor:float):
 if not can_use():return
 transform_model.zoom_at(factor,transform_model.viewport.get_center());redraw_map()
func _notification(what):
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:dragging=false;add_mode=false
func _draw():
 draw_rect(Rect2(Vector2.ZERO,size),Color("182b24"))
 if is_instance_valid(raster):
  var bounds=transform_model.world_bounds
  draw_texture_rect(raster.get_texture(),Rect2(transform_model.project(bounds.position),bounds.size*transform_model.scale_value()),false)
 for row in construction_rows:
  var screen=PackedVector2Array()
  for point in row.polygon:screen.append(transform_model.project(point))
  if Cartography.valid_polygon(screen):draw_colored_polygon(screen,Color("c9ab7a"))
 var label_rows=[];var font=ThemeDB.fallback_font
 var marker_rows=markers.rows()
 label_rows.append({"anchor":transform_model.project(player_position),"text":"You are here","icon_radius":14,"extent":font.get_string_size("You are here",HORIZONTAL_ALIGNMENT_LEFT,-1,14)+Vector2(0,2)})
 # Player label, selected marker, other personal markers, then landmarks.
 for selected_pass in [true,false]:
  for row in marker_rows:
   if (row.id==selected)!=selected_pass:continue
   var point=transform_model.project(row.at)
   if Rect2(Vector2.ZERO,size).has_point(point):draw_circle(point,6,Color.ORANGE if row.id==selected else Color.AQUA)
   label_rows.append({"anchor":point,"text":row.label,"extent":font.get_string_size(row.label,HORIZONTAL_ALIGNMENT_LEFT,-1,14)+Vector2(0,2)})
 for row in layers.get("landmarks",[]):
  if not visible_poi(row):continue
  var point=transform_model.project(row.at)
  if Rect2(Vector2.ZERO,size).has_point(point):draw_service_icon(point,row.name)
  label_rows.append({"anchor":point,"text":row.name,"extent":font.get_string_size(row.name,HORIZONTAL_ALIGNMENT_LEFT,-1,14)+Vector2(0,2)})
 if size.x>12 and size.y>12:
  var reserved=[Rect2(8,6,110,26),Rect2(10,size.y-54,120,42)]
  for label_row in Labels.arrange(label_rows,Rect2(Vector2(6,6),size-Vector2(12,12)),reserved):
   draw_rect(label_row.rect.grow(2),Color("182b24e8"))
   draw_string(font,label_row.rect.position+Vector2(0,font.get_ascent(14)),label_row.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14)
 draw_string(font,Vector2(14,25),"N ↑   E →",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("eee1bd"))
 var meters=10.0 if transform_model.zoom<3 else 2.0
 var length=meters*transform_model.scale_value();var start=Vector2(16,size.y-24)
 draw_line(start,start+Vector2(length,0),Color("eee1bd"),2)
 for x in [0.0,length]:draw_line(start+Vector2(x,-4),start+Vector2(x,4),Color("eee1bd"),2)
 draw_string(font,start+Vector2(0,-7),"%d m"%int(meters),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("eee1bd"))
func draw_service_icon(point:Vector2,title:String):
 var color=Color("f6d28b") if title!=selected_poi else Color("80ffe0")
 draw_circle(point,9,Color("182b24"));draw_arc(point,9,0,TAU,16,color,1.5)
 var glyph={"Ship":"↑","Inn":"I","Town Hall":"H","Tailor & Dyes":"T","Rook’s Supplies":"R","Cookhouse":"C","Fishing spot":"≈","Fishing supplies":"F","Your Home":"⌂","Lake":"≈","Psy":"P","Atlas":"A","Dan":"D","Fountain":"○","Requests":"!","Griddle":"G"}.get(title,"•")
 draw_string(ThemeDB.fallback_font,point+Vector2(-4,5),glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)

func _get_tooltip(at:Vector2)->String:
 var id=markers.hit(at,transform_model)
 for row in markers.rows():
  if row.id==id:return row.label+" • session marker"
 for row in layers.get("landmarks",[]):
  if visible_poi(row) and transform_model.project(row.at).distance_to(at)<=12:return row.name
 return ""

func fit_button():
 if not can_use():return
 transform_model.fit();redraw_map()
func begin_place():
 if not can_use():return
 add_mode=true;grab_focus()
