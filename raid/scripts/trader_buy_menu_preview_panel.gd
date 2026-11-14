extends "res://scripts/shop_panel.gd"
# Item 16 layout preview: the shipped ShopPanel with rendered model icons, larger list icons
# and a large item picture in the details pane. Presentation only; data and trades unchanged.
var icon_dir:String=""
var hero:TextureRect
var _cache:={}
func _ready():
	super._ready()
	var scroll=detail_panel.get_child(0);detail_panel.remove_child(scroll)
	var col=VBoxContainer.new();col.add_theme_constant_override("separation",8);detail_panel.add_child(col)
	hero=TextureRect.new();hero.name="ItemHero";hero.custom_minimum_size=Vector2(0,170);hero.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;hero.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;col.add_child(hero)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;col.add_child(scroll)
func _icon(id:String)->Texture2D:
	if _cache.has(id):return _cache[id]
	var path=icon_dir.path_join(id+".png");var tex:Texture2D=null
	if FileAccess.file_exists(path):tex=ImageTexture.create_from_image(Image.load_from_file(path))
	_cache[id]=tex;return tex
func _item_texture(row:Dictionary)->Texture2D:
	var t=_icon(str(row.get("icon_item",row.get("id",""))))
	return t if t!=null else null # no model yet → no icon (never the old flat SVG in this preview)
func _rebuild_list():
	super._rebuild_list()
	for b in item_buttons.values():
		b.custom_minimum_size.y=64
		for t in b.find_children("*","TextureRect",true,false):t.custom_minimum_size=Vector2(48,48)
func _update_summary():
	super._update_summary()
	if hero==null:return
	var row=_selected_row()
	hero.texture=null if row.is_empty() else _item_texture(row)
	hero.visible=hero.texture!=null
