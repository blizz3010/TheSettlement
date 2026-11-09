extends Control
## Modal UI only: never pauses the tree or changes gameplay/save state.
signal piece_selected(kind: String)
signal cancelled
signal exit_build
const KINDS = ["foundation","wall","window_wall","doorframe","door","ceiling","stairs","railing","workbench","lantern","bed","pitched_roof","canvas_awning"]
const NAMES = ["Foundation","Wall","Window\nwall","Door\nframe","Door","Flat roof","Stairs","Railing","Work\nbench","Lantern","Starter\nbed","Pitched\nroof","Canvas\nawning"]
var icons: Array[Texture2D] = []
var hovered := -1
var radius := 240.0
var center := Vector2.ZERO
var exit_button: Button
var cancel_button: Button
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	for kind in KINDS: icons.append(load("res://assets/ui/build/"+kind+".svg"))
	exit_button = Button.new(); exit_button.text = "Exit build"
	add_child(exit_button); exit_button.pressed.connect(func(): exit_build.emit())
	cancel_button = Button.new(); cancel_button.text = "Back"
	add_child(cancel_button); cancel_button.pressed.connect(func(): cancelled.emit())
	for button in [exit_button,cancel_button]:
		var frame = StyleBoxFlat.new()
		frame.bg_color = Color("15242be8")
		frame.border_color = Color("8d7852")
		frame.set_border_width_all(1)
		frame.set_corner_radius_all(3)
		button.add_theme_stylebox_override("normal",frame)
		button.add_theme_color_override("font_color",Color("eee2c8"))
	resized.connect(_layout); _layout(); hide()
func _layout():
	center = size * 0.5
	radius = minf(308.0, minf(size.x, size.y) * 0.47) # Preserve label clearance with 13 sectors.
	for b in [exit_button,cancel_button]:
		b.add_theme_font_size_override("font_size", 12 if radius < 170 else 16)
		b.size = Vector2(radius * 0.62, 26)
	exit_button.position = center + Vector2(-exit_button.size.x/2, -28)
	cancel_button.position = center + Vector2(-cancel_button.size.x/2, 2)
	queue_redraw()
func open(kind: String):
	hovered = KINDS.find(kind); show(); grab_focus(); queue_redraw()
func index_at(point: Vector2) -> int:
	var d = point-center
	if d.length() < radius * .38 or d.length() > radius: return -1
	return int(fposmod(d.angle() + PI/2 + PI/KINDS.size(), TAU) / (TAU/KINDS.size()))
func _gui_input(event):
	if event is InputEventMouseMotion:
		hovered = index_at(event.position); queue_redraw()
	if event is InputEventMouseButton:
		accept_event() # Both press and release belong to the wheel, never placement.
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var chosen = index_at(event.position)
			if chosen >= 0: piece_selected.emit(KINDS[chosen])
func _input(event):
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode in [KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN]:
		grab_focus()
		hovered = posmod(hovered + (-1 if event.keycode in [KEY_LEFT,KEY_UP] else 1), KINDS.size())
		queue_redraw(); get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_ENTER,KEY_KP_ENTER] and hovered >= 0 and get_viewport().gui_get_focus_owner() == self:
		get_viewport().set_input_as_handled(); piece_selected.emit(KINDS[hovered])
func _draw():
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.015,0.025,0.035,.46))
	var font = ThemeDB.fallback_font
	var fs = 10 if radius < 170 else 17
	for i in KINDS.size():
		var angle = -PI/2 + i*TAU/KINDS.size()
		var points = PackedVector2Array()
		for j in 13: points.append(center+Vector2.from_angle(angle-PI/KINDS.size()+.015+j*(TAU/KINDS.size()-.03)/12)*radius)
		for j in 13: points.append(center+Vector2.from_angle(angle+PI/KINDS.size()-.015-j*(TAU/KINDS.size()-.03)/12)*radius*.40)
		draw_colored_polygon(points,Color("5a5038f5") if i == hovered else Color("1b2c34ee"))
		draw_polyline(points + PackedVector2Array([points[0]]),Color("97815b"),1.0,true)
		var lines = NAMES[i].split("\n")
		var pos = center+Vector2.from_angle(angle)*radius*.72
		var icon_size = 17.0 if radius < 170 else 30.0
		if i < icons.size(): draw_texture_rect(icons[i],Rect2(pos+Vector2(-icon_size/2,-icon_size-7),Vector2.ONE*icon_size),false)
		pos.y += 7 if radius < 170 else 10
		for line in lines.size():
			var width = font.get_string_size(lines[line],HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
			draw_string(font,pos+Vector2(-width/2,(line-(lines.size()-1)*.5)*(fs+2)+fs*.3),lines[line],HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color("eee6d6"))

	draw_arc(center,radius+3,0,TAU,128,Color("b19868"),1.5,true)
	draw_arc(center,radius*.39,0,TAU,96,Color("8f7850"),1.0,true)
