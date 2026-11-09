extends RefCounted
# Presentation only. Godot owns pointer following and drop/cancel lifetime.
# Reuse committed tile textures; no inventory state or payload changes.
static func create(texture:Texture2D,title:String)->Control:
	var anchor=Control.new();anchor.name="ItemDragPreview";anchor.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var card=PanelContainer.new();card.position=Vector2(16,16);card.mouse_filter=Control.MOUSE_FILTER_IGNORE;anchor.add_child(card)
	var style=StyleBoxFlat.new();style.bg_color=Color("26332f");style.border_color=Color("d3b57b");style.set_border_width_all(1);style.set_corner_radius_all(4)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:style.set_content_margin(side,6)
	card.add_theme_stylebox_override("panel",style)
	var column=VBoxContainer.new();column.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(column)
	var icon=TextureRect.new();icon.name="ItemIcon";icon.texture=texture;icon.custom_minimum_size=Vector2(56,56);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(icon)
	var caption=Label.new();caption.text=title;caption.add_theme_font_size_override("font_size",12);caption.add_theme_color_override("font_color",Color("e9dfc8"));caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(caption)
	return anchor
static func attach(source:Control,texture:Texture2D,title:String)->void:
	# Null is retained for existing payload-only fixture/API callers.
	if source==null or not source.is_inside_tree():return
	source.set_drag_preview(create(texture,title))
