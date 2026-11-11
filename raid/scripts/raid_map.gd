extends Control
## Session-only navigation. Pins guide to public approaches, never through locks.
var generator
var player
var raid_state
var extraction_targets:Array=[]
var close_key:="M"
var map_title:="Relay Ridge"
var waypoint_id:=""
const PIN_COLOR=Color("f4d28a")

func _ready():
	focus_mode=Control.FOCUS_ALL
	mouse_filter=Control.MOUSE_FILTER_STOP

func _map_point(point:Vector2)->Vector2:
	return size*0.5+point*minf(size.x,size.y)/330.0

func _extraction_markers()->Array:
	# Use the generated beacon nodes, not their nearby trail endpoints.
	var markers:Array=[]
	for target in extraction_targets:
		if not is_instance_valid(target.get("node")):continue
		var point:Vector3=target.node.position
		markers.append({"id":target.poi.id,"name":target.poi.name,"position":Vector2(point.x,point.z)})
	return markers

func _destinations()->Array:
	var destinations:Array=[]
	if generator==null:return destinations
	for poi in generator.pois:
		destinations.append({"id":"poi:"+poi.id,"name":poi.name,"kind":"approach","position":poi.get("forecourt",poi.at+Vector2(0,18 if poi.id in ["camp","substation"] else 24)),"map_position":poi.at})
	for marker in _extraction_markers():
		destinations.append({"id":"extract:"+marker.id,"name":marker.name,"kind":"beacon","position":marker.position,"map_position":marker.position})
	return destinations

func selected_destination()->Dictionary:
	for destination in _destinations():
		if destination.id==waypoint_id:return destination
	return {}

func _select_at(point:Vector2):
	var best:Dictionary={}
	var distance:=24.0
	for destination in _destinations():
		var candidate=point.distance_to(_map_point(destination.map_position))
		if candidate<distance:best=destination;distance=candidate
	if not best.is_empty():waypoint_id=best.id
	queue_redraw()

func _cycle_destination(direction:int):
	var destinations=_destinations()
	if destinations.is_empty():return
	var index=-1
	for i in destinations.size():
		if destinations[i].id==waypoint_id:index=i;break
	if index<0:index=0 if direction>0 else destinations.size()-1
	else:index=posmod(index+direction,destinations.size())
	waypoint_id=destinations[index].id
	queue_redraw()

func _gui_input(event:InputEvent):
	# Queued clicks/keys after dismissal must not alter the next map session.
	if not is_visible_in_tree():return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT:_select_at(event.position);accept_event()
		elif event.button_index==MOUSE_BUTTON_RIGHT:waypoint_id="";queue_redraw();accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		# Preserve rebound Map and Escape for the world's close/cancel handler.
		if event.is_action_pressed("map") or event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_ESCAPE:return
		match event.keycode:
			KEY_LEFT:_cycle_destination(-1);accept_event()
			KEY_RIGHT:_cycle_destination(1);accept_event()
			KEY_DELETE:waypoint_id="";queue_redraw();accept_event()

static func compass(direction:Vector2)->String:
	if direction.length_squared()<0.0001:return "HERE"
	var clockwise=atan2(direction.x,-direction.y)
	return ["N","NE","E","SE","S","SW","W","NW"][posmod(int(round(clockwise/(PI/4.0))),8)]

func _player_heading()->Vector2:
	if not is_instance_valid(player):return Vector2.UP
	return Vector2(-player.global_basis.z.x,-player.global_basis.z.z).normalized()

func navigation_text()->String:
	if not is_instance_valid(player):return ""
	var heading="Facing "+compass(_player_heading())
	var destination=selected_destination()
	if destination.is_empty():return heading+"  •  Open map to pin a site or extraction"
	var offset:Vector2=destination.position-Vector2(player.position.x,player.position.z)
	var target=destination.name+(" approach" if destination.kind=="approach" else "")
	if offset.length()<=4.0:
		return heading+"  •  "+target+" nearby"+(" • Approach and interact" if destination.kind=="beacon" else "")
	return heading+"  •  "+target+"  "+compass(offset)+"  %d m direct"%int(ceil(offset.length()))

func _draw():
	if generator==null:return
	var scale_value=minf(size.x,size.y)/330.0
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.03,0.06,0.07,0.98))
	for route in generator.routes:
		var points=PackedVector2Array()
		for p in route:points.append(_map_point(p))
		draw_polyline(points,Color("7e9985"),3.0,true)
	var font=ThemeDB.fallback_font
	for poi in generator.pois:
		var at=_map_point(poi.at)
		draw_circle(at,poi.radius*scale_value,Color(poi.theme,0.26))
		draw_circle(at,4,poi.theme)
		draw_string(font,at+Vector2(-45,-18),poi.name,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
		draw_string(font,at+Vector2(-30,22),"Quality %d-%d"%[poi.loot[0],poi.loot[1]],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("bacac1"))
		if raid_state!=null and raid_state.visited.has(poi.id):
			draw_arc(at,8,0,TAU,24,Color("c5dfcc"),1.5,true)
		if raid_state!=null and raid_state.searched.has(poi.id):
			draw_string(font,at+Vector2(-30,37),"SEARCHED",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("8ce3bd"))
	for marker in _extraction_markers():
		var at=_map_point(marker.position)
		draw_circle(at,7,Color("70e4bf"));draw_string(font,at+Vector2(-22,-12),"EXTRACT",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("70e4bf"))
	var selected=selected_destination()
	if not selected.is_empty():
		draw_arc(_map_point(selected.map_position),13,0,TAU,32,PIN_COLOR,2.0,true)
		var pin=_map_point(selected.position)
		draw_polyline(PackedVector2Array([pin+Vector2(0,-7),pin+Vector2(6,0),pin+Vector2(0,7),pin+Vector2(-6,0),pin+Vector2(0,-7)]),PIN_COLOR,2.0,true)
	if is_instance_valid(player):
		var at=_map_point(Vector2(player.position.x,player.position.z))
		var forward=_player_heading()
		var side=Vector2(-forward.y,forward.x)
		draw_colored_polygon(PackedVector2Array([at+forward*10,at-forward*6+side*5,at-forward*6-side*5]),Color.WHITE)
	draw_string(font,Vector2(18,26),map_title.to_upper()+"  /  North ↑  /  Seed %d"%generator.config.map_seed,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
	var caption="Pin a public approach or beacon. Follow the marked trails."
	if not selected.is_empty():caption="PIN: "+selected.name+" / "+selected.kind+" • Distance is straight-line"
	draw_string(font,Vector2(18,49),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15,PIN_COLOR)
	draw_string(font,Vector2(18,size.y-44),"Click a site/beacon or ← / → to pin • Right-click / Delete: clear",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("bacac1"))
	draw_string(font,Vector2(18,size.y-20),close_key+" / Escape: close • Ring: visited • Extraction: 8 seconds",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("bacac1"))
