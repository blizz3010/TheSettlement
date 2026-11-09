extends RefCounted
# One quiet, opaque shell shared by shops and specialized services.
const Base=preload("res://scripts/options_theme.gd")
static func frame(fill:String="182622",border:String="a28b60",margin:int=16) -> StyleBoxFlat:
	return Base.frame(fill,border,margin)
static func make_theme() -> Theme:
	var value=Base.make_theme()
	value.default_font_size=18
	for kind in ["Button","OptionButton","LineEdit","SpinBox"]:
		value.set_color("font_disabled_color",kind,Color("a9b6aa"))
	value.set_stylebox("normal","LineEdit",frame("101c19","65766b",9))
	value.set_stylebox("focus","LineEdit",frame("101c19","78c5c1",9))
	value.set_color("font_placeholder_color","LineEdit",Color("a9b6aa"))
	# Selected rows have a thicker left border as well as fill, not color alone.
	var selected=frame("325253","bfe0d8",8);selected.border_width_left=4
	value.set_stylebox("pressed","Button",selected)
	var focus=frame("29434400","78c5c1",8);focus.set_border_width_all(2)
	value.set_stylebox("focus","Button",focus)
	value.set_stylebox("panel","PanelContainer",frame())
	return value
static func heading_font() -> Font:
	return load("res://assets/fonts/DejaVuSerif.ttf")
