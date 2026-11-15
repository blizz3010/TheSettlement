extends Node
# Item 16 preview driver: renders sample icons, a contact sheet and Rook/Psy buy-menu shots.
# Env: TI_OUT (shot dir), TI_ONLY (comma ids, optional), TI_SKIP_ICONS=1 to reuse PNGs.
const Renderer=preload("res://raid/scripts/trader_icon_renderer.gd")
const ShopPanel=preload("res://scripts/shop_panel.gd")
const PreviewPanel=preload("res://raid/scripts/trader_buy_menu_preview_panel.gd")
const ShopCatalog=preload("res://scripts/shop_catalog.gd")
const PsyGear=preload("res://scripts/psy_gear_catalog.gd")
const Plot=preload("res://scripts/plot_state.gd")
const Inventory=preload("res://scripts/inventory_state.gd")
var out:String
var icon_dir:String
func _ready():
	out=OS.get_environment("TI_OUT");if out.is_empty():out="/tmp/trader_icons"
	DirAccess.make_dir_recursive_absolute(out)
	icon_dir=ProjectSettings.globalize_path("res://raid/assets/trader_icons_preview")
	run.call_deferred()
func run():
	var ids:Array=Renderer.ITEMS.keys()
	var only=OS.get_environment("TI_ONLY")
	if not only.is_empty():ids=Array(only.split(","))
	if OS.get_environment("TI_SKIP_ICONS")!="1":
		var r=Renderer.new();add_child(r);await get_tree().process_frame
		for id in ids:
			var t=Time.get_ticks_msec();var img:Image=await r.render(id)
			var err=img.save_png(icon_dir.path_join(id+".png"))
			print("TI: icon %s err=%d alpha_px=%d %dms"%[id,err,_opaque(img),Time.get_ticks_msec()-t])
		r.queue_free()
	if only.is_empty() or OS.get_environment("TI_SHEET")=="1":
		await contact_sheet()
		await menu("rook","before",false);await menu("rook","after",true);await menu("psy","after",true)
	print("TI: done");get_tree().quit()
func _opaque(img:Image)->int:
	var n=0;var d=img.get_data()
	for i in range(3,d.size(),4):if d[i]>16:n+=1
	return n
func _snap(name_:String):
	for i in 4:await RenderingServer.frame_post_draw
	var img=get_viewport().get_texture().get_image();var e=img.save_png(out.path_join(name_));print("TI: shot %s err=%d %s"%[name_,e,str(img.get_size())])
func _tex(id:String)->Texture2D:
	var p=icon_dir.path_join(id+".png")
	return ImageTexture.create_from_image(Image.load_from_file(p)) if FileAccess.file_exists(p) else null
func _label(text:String,size:int,color:Color)->Label:
	var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;return l
func contact_sheet():
	var layer=CanvasLayer.new();add_child(layer)
	var bg=ColorRect.new();bg.color=Color("0f1a17");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(bg)
	var col=VBoxContainer.new();col.position=Vector2(30,18);col.add_theme_constant_override("separation",10);layer.add_child(col)
	var theme_=preload("res://scripts/shop_theme.gd")
	var title=_label("ITEM 16 · ICON STYLE PREVIEW · rendered from in-game models (transparent PNG, 256 px)",22,Color("d3b47a"));title.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;title.add_theme_font_override("font",theme_.heading_font());col.add_child(title)
	var grid=GridContainer.new();grid.columns=6;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);col.add_child(grid)
	for id in Renderer.ITEMS:
		var spec=Renderer.ITEMS[id];var cell=PanelContainer.new();cell.add_theme_stylebox_override("panel",theme_.frame("182622","465a4a",8));grid.add_child(cell)
		var v=VBoxContainer.new();v.add_theme_constant_override("separation",2);cell.add_child(v)
		var t=TextureRect.new();t.texture=_tex(id);t.custom_minimum_size=Vector2(200,200);t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;t.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;v.add_child(t)
		v.add_child(_label(spec.name,17,Color("e6e0cf")));v.add_child(_label(spec.trader+" · "+("game model" if spec.src=="glb" else ("tailor preview garment" if spec.src=="garment" else "trader rod build")),13,Color("9fb3a6")))
	var strip_title=_label("Same PNGs on a light backdrop and at in-menu sizes (64 / 48 / 34 px):",15,Color("b8c7b6"));strip_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;col.add_child(strip_title)
	var strip=PanelContainer.new();strip.add_theme_stylebox_override("panel",theme_.frame("c9c5b8","8a826d",8));col.add_child(strip)
	var rows_=VBoxContainer.new();rows_.add_theme_constant_override("separation",6);strip.add_child(rows_)
	for size in [64,48,34]:
		var row=HBoxContainer.new();row.add_theme_constant_override("separation",8);rows_.add_child(row)
		var sl=_label("%d px"%size,13,Color("2a2f2b"));sl.custom_minimum_size.x=48;row.add_child(sl)
		for id in Renderer.ITEMS:
			var t=TextureRect.new();t.texture=_tex(id);t.custom_minimum_size=Vector2(size,size);t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;t.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;t.size_flags_vertical=Control.SIZE_SHRINK_CENTER;row.add_child(t)
	await _snap("icon_contact_sheet.png")
	layer.queue_free()
func menu(shop:String,tag:String,preview:bool):
	var layer=CanvasLayer.new();add_child(layer)
	var bg=ColorRect.new();bg.color=Color("26332c");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(bg)
	var host=Control.new();host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(host)
	var panel=PreviewPanel.new() if preview else ShopPanel.new()
	if preview:panel.icon_dir=icon_dir
	host.add_child(panel)
	var plot=Plot.new();var inv=Inventory.new()
	var definition=ShopCatalog.definition() if shop=="rook" else PsyGear.definition()
	panel.configure(definition)
	var rows=ShopCatalog.rows("buy",inv) if shop=="rook" else PsyGear.rows(inv,"buy")
	panel.render_state(plot,inv,rows);panel.show()
	panel._select_item("timber" if shop=="rook" else "helmet_basic")
	var tag_label=Label.new();tag_label.text=("MOCKUP · " if preview else "CURRENT · ")+"real ShopPanel + real %s catalogue (fresh save: %d credits)%s"%[shop.capitalize(),plot.credits," · icon/layout preview, not merged" if preview else ""]
	tag_label.add_theme_color_override("font_color",Color("ffd98a"));tag_label.add_theme_font_size_override("font_size",15);tag_label.position=Vector2(12,6);layer.add_child(tag_label)
	await _snap("%s_buy_menu_%s.png"%[shop,tag])
	layer.queue_free()
