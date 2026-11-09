extends PanelContainer
# Presentation only. All trades are reviewed and committed by source-owned service code.
const ShopTheme=preload("res://scripts/shop_theme.gd")
signal review_requested(item:String,quantity:int,action:String)
signal confirmed
signal cancelled
signal closed
signal tab_changed(action:String)
var shop_definition:Dictionary={}
var action:String="buy"
var selected_item:String=""
var rows:Array=[]
var quote:Dictionary={}
var heading:Label
var note:Label
var details:Label
var feedback:Label
var confirm_button:Button
var cancel_button:Button
var close_button:Button
var review_button:Button
var quantity:SpinBox
var totals:Label
var credits:Label
var emblem:Label
var profession_icon:TextureRect
var search:LineEdit
var categories:OptionButton
var tabs:HBoxContainer
var tab_buttons:Dictionary={}
var items:VBoxContainer
var item_buttons:Dictionary={}
var category_buttons:VBoxContainer
var list_section:VBoxContainer
var body:BoxContainer
var detail_panel:PanelContainer
var summary:VBoxContainer
var confirmation:HBoxContainer
var empty_state:Label
var scrim:ColorRect
var _plot
var _inventory
var _rendering:=false
var _category:String="All"
var clear_filters:Button
var result_count:Label
func _ready():
	name="ShopPanel"
	theme=ShopTheme.make_theme()
	add_theme_stylebox_override("panel",ShopTheme.frame())
	mouse_filter=Control.MOUSE_FILTER_STOP
	scrim=ColorRect.new();scrim.name="ShopScrim";scrim.color=Color(0.025,0.045,0.035,0.58);scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);scrim.mouse_filter=Control.MOUSE_FILTER_STOP
	get_parent().add_child(scrim);get_parent().move_child(scrim,get_index())
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",6);add_child(column)
	var header=HBoxContainer.new();header.add_theme_constant_override("separation",14);column.add_child(header)
	emblem=Label.new();emblem.custom_minimum_size=Vector2(44,44);emblem.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;emblem.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;emblem.add_theme_color_override("font_color",Color("d3b47a"));emblem.add_theme_font_size_override("font_size",30);header.add_child(emblem)
	profession_icon=TextureRect.new();profession_icon.name="ProfessionIcon";profession_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);profession_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;profession_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;profession_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;emblem.add_child(profession_icon)
	var identity=VBoxContainer.new();identity.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(identity)
	heading=Label.new();heading.add_theme_font_override("font",ShopTheme.heading_font());heading.add_theme_font_size_override("font_size",27);identity.add_child(heading)
	note=Label.new();note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.add_theme_color_override("font_color",Color("b8c7b6"));identity.add_child(note)
	credits=Label.new();credits.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;header.add_child(credits)
	tabs=HBoxContainer.new();column.add_child(tabs)
	var filters=HBoxContainer.new();column.add_child(filters)
	categories=OptionButton.new();categories.custom_minimum_size.x=140;categories.item_selected.connect(_category_selected);filters.add_child(categories)
	search=LineEdit.new();search.placeholder_text="Search this shop";search.clear_button_enabled=true;search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;search.text_changed.connect(func(_text):_rebuild_list());filters.add_child(search)
	clear_filters=Button.new();clear_filters.text="Clear filters";clear_filters.tooltip_text="Show every item in this tab. Does not change your inventory.";clear_filters.pressed.connect(_clear_filters);filters.add_child(clear_filters)
	result_count=Label.new();result_count.add_theme_color_override("font_color",Color("b8c7b6"));column.add_child(result_count)
	body=BoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",14);column.add_child(body)
	category_buttons=VBoxContainer.new();category_buttons.custom_minimum_size.x=130;body.add_child(category_buttons)
	list_section=VBoxContainer.new();list_section.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list_section.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(list_section)
	var labels=HBoxContainer.new();list_section.add_child(labels)
	var item_label=Label.new();item_label.text="ITEM";item_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;labels.add_child(item_label)
	var cost_label=Label.new();cost_label.text="UNIT    OWNED";cost_label.add_theme_font_size_override("font_size",15);labels.add_child(cost_label)
	var scroll=ScrollContainer.new();scroll.name="ItemListScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;list_section.add_child(scroll)
	items=VBoxContainer.new();items.size_flags_horizontal=Control.SIZE_EXPAND_FILL;items.add_theme_constant_override("separation",4);scroll.add_child(items)
	detail_panel=PanelContainer.new();detail_panel.custom_minimum_size.x=300;detail_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_panel.add_theme_stylebox_override("panel",ShopTheme.frame("101d19","465a4a",12));body.add_child(detail_panel)
	var detail_scroll=ScrollContainer.new();detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;detail_panel.add_child(detail_scroll)
	details=Label.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.text="Choose an item to see its use and availability.";detail_scroll.add_child(details)
	summary=VBoxContainer.new();summary.add_theme_constant_override("separation",7);column.add_child(summary)
	var selection=HBoxContainer.new();summary.add_child(selection)
	var qlabel=Label.new();qlabel.text="Quantity";selection.add_child(qlabel)
	quantity=SpinBox.new();quantity.min_value=1;quantity.max_value=8;quantity.step=1;quantity.allow_greater=false;quantity.allow_lesser=false;quantity.custom_minimum_size.x=100;quantity.value_changed.connect(func(_value):_update_summary());selection.add_child(quantity)
	var max_button=Button.new();max_button.name="MaximumQuantity";max_button.text="Max";max_button.pressed.connect(func():quantity.value=_maximum());selection.add_child(max_button)
	totals=Label.new();totals.size_flags_horizontal=Control.SIZE_EXPAND_FILL;totals.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;selection.add_child(totals)
	review_button=Button.new();review_button.text="Review purchase";review_button.custom_minimum_size.y=36;review_button.pressed.connect(_review);selection.add_child(review_button)
	confirmation=HBoxContainer.new();confirmation.add_theme_constant_override("separation",10);summary.add_child(confirmation)
	cancel_button=Button.new();cancel_button.text="Cancel";cancel_button.custom_minimum_size.y=36;cancel_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;cancel_button.pressed.connect(func():cancelled.emit());confirmation.add_child(cancel_button)
	confirm_button=Button.new();confirm_button.text="Confirm purchase";confirm_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;confirm_button.pressed.connect(func():confirmed.emit());confirmation.add_child(confirm_button)
	feedback=Label.new();feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;feedback.custom_minimum_size.y=28;feedback.add_theme_color_override("font_color",Color("d6c9a7"));summary.add_child(feedback)
	close_button=Button.new();close_button.text="Close";close_button.custom_minimum_size.y=34;close_button.pressed.connect(func():closed.emit());column.add_child(close_button)
	visibility_changed.connect(_visibility_changed)
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout();configure(shop_definition);hide()
func configure(definition:Dictionary) -> void:
	shop_definition=definition.duplicate(true)
	if not is_instance_valid(heading):return
	heading.text=str(definition.get("title","SHOP"));note.text=str(definition.get("role",""));emblem.text=str(definition.get("emblem","•"))
	profession_icon.texture=preload("res://scripts/shop_profession_icons.gd").texture(str(definition.get("shop_id","")))
	profession_icon.visible=profession_icon.texture!=null
	if profession_icon.visible:emblem.text=""
	for child in tabs.get_children():child.queue_free()
	tab_buttons={}
	var available:Array=definition.get("tabs",["buy"])
	if not action in available:action=str(available[0]) if not available.is_empty() else "buy"
	for name_ in available:
		var key:String=str(name_);var button=Button.new();button.text=key.capitalize();button.toggle_mode=true;button.custom_minimum_size=Vector2(100,34);button.button_pressed=key==action;button.pressed.connect(_change_tab.bind(key));tabs.add_child(button);tab_buttons[key]=button
func render_state(plot,inventory,new_rows:Array,pending:Dictionary={},message:String="") -> void:
	_plot=plot;_inventory=inventory;rows=new_rows.duplicate(true);quote=pending.duplicate(true)
	if not is_instance_valid(heading):return
	_rendering=true
	credits.text="%d credits\nCarried %d / %d" % [plot.credits,inventory.used("carried"),inventory.capacity("carried")]
	if not quote.is_empty():selected_item=str(quote.item);quantity.value=int(quote.quantity)
	var names:Array=["All"]
	for row in rows:
		var category:String=str(row.get("category","Other"))
		if not names.has(category):names.append(category)
	if not _category in names:_category="All"
	categories.clear()
	for child in category_buttons.get_children():child.queue_free()
	for category in names:
		categories.add_item(category)
		var button=Button.new();button.text=category;button.toggle_mode=true;button.button_pressed=_category==category;button.pressed.connect(_choose_category.bind(category));category_buttons.add_child(button)
	categories.select(names.find(_category))
	feedback.text=message;feedback.visible=not message.is_empty()
	_rendering=false
	_rebuild_list();_update_summary()
func _change_tab(value:String):
	if not quote.is_empty():return
	action=value;selected_item="";search.text="";_category="All";quantity.value=1
	for key in tab_buttons:tab_buttons[key].button_pressed=key==action
	tab_changed.emit(action)
func _category_selected(index:int):
	_choose_category(categories.get_item_text(index))
func _choose_category(value:String):
	if not quote.is_empty():return
	_category=value
	for index in range(categories.item_count):
		if categories.get_item_text(index)==value:categories.select(index)
	for button in category_buttons.get_children():button.button_pressed=button.text==value
	_rebuild_list()
func _clear_filters():
	if not quote.is_empty():return
	search.set_text("")
	_choose_category("All")
	search.grab_focus()

func _rebuild_list():
	if not is_instance_valid(items):return
	for child in items.get_children():items.remove_child(child);child.queue_free()
	item_buttons={}
	var found:int=0
	var ordered=rows.duplicate()
	ordered.sort_custom(func(a,b):return a.get("price")!=null and b.get("price")==null)
	var preview_heading=false
	for row in ordered:
		if _category!="All" and row.get("category")!=_category:continue
		if not search.text.strip_edges().is_empty() and not (str(row.get("name",""))+" "+str(row.get("description",""))).to_lower().contains(search.text.strip_edges().to_lower()):continue
		if row.get("price")==null and not preview_heading:
			var upcoming=Label.new();upcoming.text="COMING LATER / INFORMATION";upcoming.add_theme_font_size_override("font_size",14);items.add_child(upcoming);preview_heading=true
		found+=1
		var button=Button.new();button.tooltip_text=str(row.name)+(" · "+str(row.get("reason")) if not str(row.get("reason","")).is_empty() else "");button.custom_minimum_size.y=56;button.toggle_mode=true;button.button_pressed=selected_item==row.id;button.disabled=not quote.is_empty();button.pressed.connect(_select_item.bind(str(row.id)));items.add_child(button);item_buttons[row.id]=button
		var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
		for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,9)
		button.add_child(margin)
		var line=HBoxContainer.new();line.mouse_filter=Control.MOUSE_FILTER_IGNORE;margin.add_child(line)
		var texture=_item_texture(row)
		if texture!=null:
			var icon=TextureRect.new();icon.texture=texture;icon.custom_minimum_size=Vector2(34,34);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.add_child(icon)
		var name_label=Label.new();name_label.text=str(row.name);name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.add_child(name_label)
		var cost=Label.new();cost.text=("Free" if row.get("price")==0 else str(row.get("price"))+" cr") if row.get("price")!=null else ("Known" if row.get("id")=="crafting_guide" else "Preview");cost.custom_minimum_size.x=80;cost.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;cost.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.add_child(cost)
		var owned=Label.new();owned.text=str(row.get("owned",0));owned.custom_minimum_size.x=45;owned.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;owned.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.add_child(owned)
	result_count.text="%d of %d items"%[found,rows.size()]
	clear_filters.disabled=not quote.is_empty() or (search.text.is_empty() and _category=="All")
	# A filtered-out selection must not leave an invisible purchase ready to review.
	if quote.is_empty() and not selected_item.is_empty() and not item_buttons.has(selected_item):
		selected_item=""
		quantity.value=1
	_update_summary()
	if found==0:
		var empty=Label.new();empty.text=str(shop_definition.get("sale_help","No eligible carried items. Stash, Lockbox, clothing and quest items are protected.")) if action=="sell" and rows.is_empty() else "No matching items. Clear search or choose another category.";empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;items.add_child(empty)
func _select_item(item:String):
	if not quote.is_empty():return
	selected_item=item;quantity.value=1
	for id in item_buttons:item_buttons[id].button_pressed=id==item
	_update_summary()
func _selected_row() -> Dictionary:
	for row in rows:
		if row.get("id")==selected_item:return row
	return {}
func _maximum() -> int:
	var row=_selected_row()
	if row.is_empty() or _inventory==null or row.get("price")==null or not row.get("enabled",false):return 1
	var limit:int=int(row.get("max_quantity",8))
	if action=="sell":return maxi(1,mini(limit,mini(int(row.get("owned",0)),int((100000-_plot.credits)/maxi(1,int(row.price))))))
	var affordable=limit if row.price==0 else int(_plot.credits/int(row.price))
	var space_per_unit:int=int(row.get("space_per_unit",1))
	var room=limit if space_per_unit<=0 else int((_inventory.capacity("carried")-_inventory.used("carried"))/space_per_unit)
	return maxi(1,mini(limit,mini(room,affordable)))
func _verb(value:String) -> String:
	return "Sell" if value=="sell" else ("Prepare" if value=="craft" else "Buy")
func _review_label(value:String) -> String:
	return "Review sale" if value=="sell" else ("Review preparation" if value=="craft" else "Review purchase")
func _update_summary():
	if _rendering or not is_instance_valid(quantity):return
	var row=_selected_row();var reviewing=not quote.is_empty()
	quantity.editable=not reviewing and not row.is_empty();search.editable=not reviewing;categories.disabled=reviewing
	clear_filters.disabled=reviewing or (search.text.is_empty() and _category=="All")
	for button in tab_buttons.values():button.disabled=reviewing
	for button in category_buttons.get_children():button.disabled=reviewing
	summary.get_child(0).get_node("MaximumQuantity").disabled=reviewing or row.is_empty() or not row.get("enabled",false)
	confirmation.visible=reviewing;review_button.visible=not reviewing;confirm_button.disabled=not reviewing;cancel_button.disabled=not reviewing
	if row.is_empty():
		details.text=(str(shop_definition.get("sale_help","No eligible carried items. Stash, Lockbox, clothing and quest items are protected.")) if action=="sell" and rows.is_empty() else str(shop_definition.get("help","Choose an item to see its use and availability.")));totals.text="Choose an item";review_button.text=_review_label(action);review_button.disabled=true;return
	details.text=str(row.name)+"\n\n"+str(row.get("description",""))
	var reason:String=str(row.get("reason",""))
	_rendering=true
	quantity.max_value=int(row.get("max_quantity",8))
	_rendering=false
	var count:int=int(quantity.value)
	var valid=bool(row.get("enabled",false)) and row.get("price")!=null
	if valid:
		var total:int=int(row.price)*count
		var after:int=_plot.credits+(total if action=="sell" else -total)
		var used:int=_inventory.used("carried")+(-count if action=="sell" else count*int(row.get("space_per_unit",1)))
		if action=="sell" and int(row.get("owned",0))<count:valid=false;reason="Not enough carried units. Stash and Lockbox are protected."
		elif after<0:valid=false;reason="Not enough credits for this quantity."
		elif after>100000:valid=false;reason="Credit limit is 100,000."
		elif used>_inventory.capacity("carried"):valid=false;reason="Bag full · make %d carried space." % (used-_inventory.capacity("carried"))
		totals.text="%d credits %s\nAfter: %d credits · Carried %d / %d" % [total,"received" if action=="sell" else "total",after,used,_inventory.capacity("carried")]
		review_button.text=_review_label(action)
		review_button.tooltip_text="%d %s · %s" % [count,row.name,"free" if total==0 else str(total)+" credits"]
	else:
		totals.text=reason;review_button.text="Unavailable"
	if not reason.is_empty():details.text+="\n\n"+reason
	if action=="sell":details.text+="\n\n"+str(shop_definition.get("sale_help","Only eligible carried material stacks. Equipment, quest items, stash and Lockbox are protected."))
	review_button.disabled=not valid
	if reviewing:
		totals.text="%s %d %s · %d credits\nAfter: %d credits · Carried %d / %d" % [_verb(quote.action),quote.quantity,quote.get("name",row.name),quote.total,quote.balance_after,quote.carried_after,quote.capacity]
		confirm_button.text="Confirm sale" if quote.action=="sell" else ("Prepare" if quote.action=="craft" else "Confirm purchase")
func _review():
	if review_button.disabled or not quote.is_empty():return
	quantity.apply()
	_update_summary()
	if review_button.disabled:return
	review_requested.emit(selected_item,int(quantity.value),action)
func _fit_layout():
	if not is_inside_tree():return
	var bounds=get_viewport_rect().size
	var target=Vector2(minf(1120,bounds.x-40),minf(700,bounds.y-40))
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size=Vector2.ZERO
	offset_left=-target.x/2;offset_right=target.x/2;offset_top=-target.y/2;offset_bottom=target.y/2
	if is_instance_valid(body):
		var compact=target.x<960
		body.vertical=compact;category_buttons.visible=not compact;categories.visible=compact
		detail_panel.custom_minimum_size=Vector2(0,110) if compact else Vector2(300,0)
		detail_panel.size_flags_vertical=Control.SIZE_FILL if compact else Control.SIZE_EXPAND_FILL
		list_section.custom_minimum_size.y=110 if compact else 0
func _visibility_changed():
	if is_instance_valid(scrim):scrim.visible=visible
	if not visible:quote={}
func _exit_tree():
	if is_instance_valid(scrim):scrim.queue_free()

func _item_texture(row:Dictionary)->Texture2D:
	var id=str(row.get("icon_item",row.get("id","")))
	if id.begins_with("pattern_basic_"):id=id.trim_prefix("pattern_")
	if id=="recipe_griddle_fish":id="cooked_griddle_fish"
	if id in ["fishing_pole","river_fish"]:return preload("res://scripts/fishing_item_icons.gd").texture(id)
	if id in preload("res://scripts/production_item_icons.gd").ITEMS:return preload("res://scripts/production_item_icons.gd").texture(id)
	if _inventory!=null and _inventory.equipment_definitions().has(id):
		return preload("res://scripts/clothing_icons.gd").texture(_inventory.equipment_definitions()[id],{"variant_id":"basic","dyes":{}})
	var path=str(row.get("icon",""))
	return load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
