extends RefCounted
static func frame(fill:String,border:String,margin:int) -> StyleBoxFlat:
 var s=StyleBoxFlat.new();s.bg_color=Color(fill);s.border_color=Color(border);s.set_border_width_all(1);s.set_corner_radius_all(3)
 for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:s.set_content_margin(side,margin)
 return s
static func make_theme() -> Theme:
 var t=Theme.new();t.default_font_size=16
 for type in ["Label","Button","OptionButton","CheckButton","TabBar"]:t.set_color("font_color",type,Color("e9dfc8"))
 for type in ["Button","OptionButton"]:
  t.set_stylebox("normal",type,frame("242a29","74634c",8));t.set_stylebox("hover",type,frame("294344","c6a975",8));t.set_stylebox("pressed",type,frame("325253","bfe0d8",8));t.set_stylebox("disabled",type,frame("1b211f","48504a",8))
  var focus=frame("29434400","78c5c1",8);t.set_stylebox("focus",type,focus)
 for type in ["CheckButton","TabBar","HSlider"]:
  t.set_stylebox("focus",type,frame("29434400","78c5c1",3))
 t.set_stylebox("panel","TabContainer",frame("1b211f","74634c",12))
 t.set_stylebox("tab_selected","TabBar",frame("30403a","b29462",12));t.set_stylebox("tab_unselected","TabBar",frame("202624","4f574c",12));t.set_stylebox("tab_hovered","TabBar",frame("294344","c6a975",12))
 t.set_color("font_selected_color","TabBar",Color("f4e4b9"));t.set_color("font_unselected_color","TabBar",Color("aebbb1"))
 t.set_stylebox("slider","HSlider",frame("101817","4f574c",2));t.set_stylebox("grabber_area","HSlider",frame("92764f","b29462",2));t.set_stylebox("grabber_area_highlight","HSlider",frame("bd9b66","d4bc8c",2))
 return t
