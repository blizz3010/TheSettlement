extends PanelContainer
const DragPreview=preload("res://scripts/item_drag_preview.gd")
signal clothing_transfer_requested(instance_id:String,source:String,destination:String,snapshot_revision:int,snapshot:Dictionary)
signal clothing_cell_requested(instance_id:String,source:String,destination:String,slot_index:int,snapshot_revision:int,snapshot:Dictionary)
signal transfer_requested(source: String, destination: String, item: String, amount: int)
signal cell_transfer_requested(source:String,destination:String,item:String,slot_index:int,snapshot_revision:int)
signal slot_take_requested(item: String, slot_index: int)
signal move_stash_requested
signal closed
signal equipment_action_requested(action:String,instance_id:String,slot:String,snapshot_revision:int)
signal quick_access_requested(index:int,target_id:String,source_slot:int,snapshot_revision:int)
var equipment_editor
var quick_access_editor
const ITEM_NAMES = {"cooked_griddle_fish":"Griddle fish (display sample)", "cloth_linen":"Linen cloth", "thread_spool":"Thread spool", "fishing_pole":"Basic fishing pole", "river_fish":"River fish", "timber":"Timber", "stone":"Stone", "metal":"Metal scrap", "lantern_kit":"Lantern kit", "stream_fish":"Stream fish"}
const ITEM_HELP = {"cooked_griddle_fish":"Persistent display sample from ordinary fish. Carry, inspect or store it. Cannot be eaten or sold; no health, stamina, hunger or buffs.", "cloth_linen":"Tailoring ingredient. Use the tailor’s known patterns to make basic clothing.", "thread_spool":"Tailoring ingredient. Used with linen cloth at the tailor.", "fishing_pole":"Carry this pole, drag it to a hotbar slot, then select that slot before fishing at the marked bank.", "river_fish":"Ordinary river catch. Separate from the First catch quest fish. Trade at the Cookhouse or prepare a display sample at the nearby griddle. Eating is not available.", "timber":"Building and crafting material.", "stone":"Settlement building material.", "metal":"Metal used for workbenches and lanterns.", "lantern_kit":"Crafted lantern. Place through the building tools.", "stream_fish":"One starter-request catch. Carry to the physical board. No selling, food use or XP in this test."}
var columns: HBoxContainer
var description: Label
var feedback: Label
var access_stash := false
var allow_move_stash := false
var destination := "lockbox"
var tabs: HBoxContainer
var rendered_snapshot:Dictionary={}
var active_clothing_drag:Dictionary={}
var active_lockbox_drag:Dictionary={}
var current_inventory
var generation := 0
var drag_serial := 0
var active_drag: Dictionary = {}
var drag_in_progress := false
var selected_items := {"carried":"", "stash":""}
var equipment: VBoxContainer
var lockbox_area: VBoxContainer
func frame(color: String, border := "756044", margin := 12) -> StyleBoxFlat:
	var style=StyleBoxFlat.new();style.bg_color=Color(color);style.border_color=Color(border)
	style.set_border_width_all(1);style.set_corner_radius_all(3)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: style.set_content_margin(side,margin)
	return style
func label(text: String, font_size := 16) -> Label:
	var node=Label.new();node.text=text;node.add_theme_font_size_override("font_size",font_size);node.add_theme_color_override("font_color",Color("e9dfc8"))
	if font_size>=18:node.add_theme_font_override("font",load("res://assets/fonts/DejaVuSerif.ttf"))
	return node
func _ready():
	resized.connect(queue_redraw)
	get_viewport().size_changed.connect(fit_viewport)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left=26;offset_top=24;offset_right=-26;offset_bottom=-24
	add_theme_stylebox_override("panel",frame("171c1c","b29462",16))
	var ui_theme=Theme.new()
	ui_theme.set_stylebox("normal","Button",frame("242a29","74634c",7))
	ui_theme.set_stylebox("hover","Button",frame("294344","c6a975",7))
	ui_theme.set_stylebox("pressed","Button",frame("325253","bfe0d8",7))
	var focus_style=frame("294344","78c5c1",7);focus_style.bg_color.a=0.0
	ui_theme.set_stylebox("focus","Button",focus_style)
	ui_theme.set_stylebox("disabled","Button",frame("1b211f","48504a",7))
	ui_theme.set_color("font_color","Button",Color("e9dfc8"))
	ui_theme.set_color("font_disabled_color","Button",Color("7e8d85"))
	ui_theme.set_font_size("font_size","Button",14)
	theme=ui_theme
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",10);add_child(box)
	var heading=HBoxContainer.new();box.add_child(heading)
	var title=label("CHARACTER & STORAGE",28);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(title)
	var close=Button.new();close.text="×";close.tooltip_text="Close inventory";close.custom_minimum_size=Vector2(36,36);close.pressed.connect(func():closed.emit());heading.add_child(close)
	description=label("Drag between containers • Click items to/from nearby Home Stash • Right click clothing to equip",14);box.add_child(description)
	tabs=HBoxContainer.new();box.add_child(tabs)
	var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(scroll)
	var body=HBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",16);scroll.add_child(body)
	equipment=VBoxContainer.new();equipment.custom_minimum_size.x=276;equipment.add_theme_constant_override("separation",10)
	var equipment_frame=PanelContainer.new();equipment_frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL;equipment_frame.size_flags_stretch_ratio=0.8;equipment_frame.add_theme_stylebox_override("panel",frame("1b211f","826d4d",10));body.add_child(equipment_frame);equipment_frame.add_child(equipment)
	equipment_editor=preload("res://scripts/equipment_controls.gd").new();equipment.add_child(equipment_editor)
	equipment_editor.action_requested.connect(func(action,instance_id,slot,snapshot_revision):equipment_action_requested.emit(action,instance_id,slot,snapshot_revision))
	columns=HBoxContainer.new();columns.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.size_flags_stretch_ratio=2.0;columns.add_theme_constant_override("separation",16);body.add_child(columns)
	quick_access_editor=preload("res://scripts/quick_access_editor.gd").new();box.add_child(quick_access_editor)
	quick_access_editor.material_drop_validator=can_assign_material
	quick_access_editor.material_assignment_requested.connect(func(index,payload,snapshot_revision):
		if snapshot_revision==generation and can_assign_material(payload):
			var target_id="material:"+payload.item;active_drag.clear();quick_access_requested.emit(index,target_id,-1,snapshot_revision)
	)
	quick_access_editor.assignment_requested.connect(func(index,target_id,snapshot_revision):quick_access_requested.emit(index,target_id,-1,snapshot_revision))
	quick_access_editor.swap_requested.connect(func(source,destination,snapshot_revision):
		if source is int and destination is int and source>=0 and source<6 and destination>=0 and destination<6 and current_inventory!=null and snapshot_revision==generation:quick_access_requested.emit(destination,current_inventory.hotbar_assignments[source],source,snapshot_revision)
	)
	feedback=label("",14);feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;feedback.custom_minimum_size.y=24;box.add_child(feedback)
	hide()
func cell_height() -> float:
	return clampf((get_viewport_rect().size.y-480.0)/6.0,48.0,82.0)
func icon(item: String) -> Texture2D:
	if item in preload("res://scripts/production_item_icons.gd").ITEMS:return preload("res://scripts/production_item_icons.gd").texture(item)
	if item in ["fishing_pole","river_fish"]:return preload("res://scripts/fishing_item_icons.gd").texture(item)
	return load("res://assets/ui/inventory_"+item+".svg")
func render(inventory, can_use_stash: bool, status := "", appearance: Dictionary = {}):
	var focused=get_viewport().gui_get_focus_owner()
	var focus_key=focused.get_meta("inventory_focus","") if focused != null else ""
	current_inventory=inventory;access_stash=can_use_stash
	rendered_snapshot=inventory.data()
	active_clothing_drag.clear()
	destination="stash" # Compatibility field; no destination selector or Lockbox click shortcut.
	fit_viewport.call_deferred()
	generation+=1
	active_drag.clear()
	var revision=generation
	equipment_editor.render(inventory.hotbar_context(),generation,appearance)
	quick_access_editor.render(inventory.hotbar_context(),inventory.hotbar_assignments,generation)
	feedback.text=status
	for parent in [columns,tabs]:
		for child in parent.get_children(): parent.remove_child(child);child.queue_free()
	if access_stash and allow_move_stash:
		var move_button=Button.new();move_button.text="Move Home Stash";move_button.set_meta("inventory_focus","move_stash")
		move_button.pressed.connect(func():
			if revision==generation and visible and access_stash and allow_move_stash: move_stash_requested.emit()
		)
		tabs.add_child(move_button)
	for container in ["carried","stash"]:
		var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.custom_minimum_size.x=310;column.add_theme_constant_override("separation",4)
		var region=PanelContainer.new();region.size_flags_horizontal=Control.SIZE_EXPAND_FILL;region.add_theme_stylebox_override("panel",frame("1b211f","92764f",10));columns.add_child(region);region.add_child(column)
		column.add_child(label(("CARRIED INVENTORY" if container=="carried" else "HOME STASH")+"   %d / %d"%[inventory.used(container),inventory.capacity(container)],18))
		region.set_drag_forwarding(Callable(),can_drop_unit.bind(container),drop_unit.bind(container))
		var meter=ProgressBar.new();meter.custom_minimum_size.y=4;meter.show_percentage=false;meter.max_value=inventory.capacity(container);meter.value=inventory.used(container);meter.mouse_filter=Control.MOUSE_FILTER_IGNORE
		meter.add_theme_stylebox_override("background",frame("111716","343f39",0));meter.add_theme_stylebox_override("fill",frame("9a8055","c7ab76",0));column.add_child(meter)
		column.add_child(label("8 prototype units • includes carried garments" if container=="carried" else ("24 item spaces • Base storage" if access_stash else "BASE ONLY • approach your storage chest"),12))
		var contents: Dictionary=inventory.container(container)
		if selected_items[container].is_empty() or contents.get(selected_items[container],0)<=0:
			selected_items[container]="timber"
			for candidate in ITEM_NAMES:
				if contents.get(candidate,0)>0:selected_items[container]=candidate;break
		var units: Array[String]=[]
		for item in ITEM_NAMES:
			for unit in range(contents.get(item,0)):units.append(item)
		var garment_ids:Array[String]=[]
		for instance_id in inventory.equipment_owned:
			if inventory.equipment_owned[instance_id].location==("carried" if container=="carried" else "home_stash"):garment_ids.append(instance_id)
		garment_ids.sort()
		if container=="stash" and inventory.used(container)>inventory.capacity(container):
			column.add_child(label("Over capacity • Withdraw items before adding more",12))
		var grid=GridContainer.new();grid.name=container.capitalize()+"UnitGrid";grid.columns=4;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",4);column.add_child(grid)
		for index in range(maxi(inventory.capacity(container),units.size()+garment_ids.size())):
			var item: String=units[index] if index<units.size() else ""
			var tile=Button.new();tile.custom_minimum_size=Vector2(62,cell_height());tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			tile.set_meta("inventory_focus","tile_"+container+"_"+str(index));tile.set_meta("item_id",item)
			var slot_mark=label("%02d"%(index+1),10);slot_mark.position=Vector2(5,3);slot_mark.modulate=Color(0.72,0.76,0.67,0.55);slot_mark.mouse_filter=Control.MOUSE_FILTER_IGNORE;tile.add_child(slot_mark)
			tile.add_theme_stylebox_override("normal",frame("242c29" if not item.is_empty() else "171e1b","887451" if not item.is_empty() else "39453e",7))
			tile.disabled=item.is_empty() or (container=="stash" and not access_stash)
			tile.tooltip_text="Empty item space" if item.is_empty() else ITEM_NAMES[item]+" • 1 unit\n"+ITEM_HELP[item]
			if not item.is_empty():
				tile.icon=icon(item);tile.expand_icon=true;tile.add_theme_constant_override("icon_max_width",52)
				tile.set_drag_forwarding(begin_unit_drag.bind(container,item,revision,tile),can_drop_unit.bind(container),drop_unit.bind(container))
				tile.mouse_entered.connect(func():
					if revision==generation:feedback.text=ITEM_NAMES[item]+" • "+ITEM_HELP[item]
				)
				tile.pressed.connect(func():
					if revision==generation and not drag_in_progress:click_unit(container,item)
				)
			if item.is_empty():
				var gear_index=index-units.size()
				if gear_index>=0 and gear_index<garment_ids.size():
					var garment_id:String=garment_ids[gear_index]
					var garment=inventory.equipment_owned[garment_id]
					var definition=inventory.equipment_definitions()[garment.definition_id]
					tile.text=definition.category.capitalize();tile.disabled=container=="stash" and not access_stash
					tile.icon=preload("res://scripts/clothing_icons.gd").texture(definition,garment);tile.expand_icon=true;tile.add_theme_constant_override("icon_max_width",44)
					tile.gui_input.connect(func(event):
						if container=="carried" and revision==generation and not drag_in_progress and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
							equipment_editor.request_quick_equip(garment_id,revision);tile.accept_event()
					)
					tile.set_meta("garment_id",garment_id)
					tile.tooltip_text=definition.display_name+" • 1 prototype unit\n"+("Click or drag to withdraw. Withdraw before equipping." if container=="stash" else ("Click or drag to Home Stash. Right click to equip." if access_stash else "Right click to equip. Drag to its equipment slot or hotbar."))
					tile.pressed.connect(func():
						if revision==generation and not drag_in_progress:
							if access_stash:click_clothing(container,garment_id)
							else:equipment_editor.selected_instance=garment_id
					)
					tile.set_drag_forwarding(begin_clothing_drag.bind(container,garment_id,revision,tile),can_drop_unit.bind(container),drop_unit.bind(container))
				else:tile.set_drag_forwarding(Callable(),can_drop_unit.bind(container),drop_unit.bind(container))
			grid.add_child(tile)
		var selected: String=selected_items[container]
		var count: int=contents.get(selected,0)
		column.add_child(label(ITEM_NAMES[selected]+"   × "+str(count) if count>0 else ("Clothing shown above" if not garment_ids.is_empty() else ("No carried materials" if container=="carried" else "Home Stash is empty")),16))
		if container=="carried":
			column.add_child(label("BACKPACK / RIG  •  Coming later",13))
			var protected_panel=PanelContainer.new();protected_panel.add_theme_stylebox_override("panel",frame("2b291e","c49a45",10));column.add_child(protected_panel);protected_panel.set_drag_forwarding(Callable(),can_drop_lockbox.bind(-1),drop_lockbox.bind(-1))
			lockbox_area=VBoxContainer.new();protected_panel.add_child(lockbox_area)
			lockbox_area.add_child(label("LOCKBOX   •   2 × 2   •   %d / 4"%inventory.used("lockbox"),18))
			var cells=GridContainer.new();cells.columns=2;cells.add_theme_constant_override("h_separation",8);cells.add_theme_constant_override("v_separation",8);lockbox_area.add_child(cells)
			for slot_index in range(4):
				var cell=inventory.lockbox[slot_index]
				if cell is Dictionary:
					add_lockbox_garment(cells,cell.instance_id,slot_index,revision)
					continue
				var item: String=cell
				var slot=Button.new();slot.name="LockboxSlot%d"%slot_index;slot.custom_minimum_size=Vector2(128,cell_height());slot.set_meta("inventory_focus","slot_%d"%slot_index)
				slot.text="Empty" if item.is_empty() else "× 1"
				if not item.is_empty():
					slot.icon=icon(item);slot.expand_icon=true;slot.add_theme_constant_override("icon_max_width",42)
				slot.disabled=item.is_empty() or inventory.used("carried")>=inventory.capacity("carried")
				slot.tooltip_text=("Empty cell. " if item.is_empty() else ITEM_NAMES[item]+". ")+"One unit per cell. Take this exact cell to carried inventory. Protection is planned; raids are not implemented."
				slot.pressed.connect(func():
					if revision==generation and not drag_in_progress:slot_take_requested.emit(item,slot_index)
				)
				slot.set_drag_forwarding(begin_unit_drag.bind("lockbox",item,revision,slot,slot_index),can_drop_lockbox.bind(slot_index),drop_lockbox.bind(slot_index))
				cells.add_child(slot)
			lockbox_area.add_child(label("Drag carried items into an empty cell. Withdraw clothing before equipping, dyeing or quick access.",12))
	if not focus_key.is_empty():restore_focus.call_deferred(focus_key,revision)
func select_item(container: String, item: String):
	if not selected_items.has(container) or not ITEM_NAMES.has(item):return
	selected_items[container]=item
	render(current_inventory,access_stash)
func find_action(key: String) -> Button:
	for control in find_children("*","Button",true,false):
		if control.get_meta("inventory_focus","")==key:return control
	return null
func restore_focus(key: String, revision: int):
	if generation!=revision or not visible:return
	var control=find_action(key)
	if control!=null and not control.disabled:control.grab_focus();return
	for candidate in find_children("*","Button",true,false):
		if candidate.is_visible_in_tree() and not candidate.disabled:candidate.grab_focus();return

func _draw():
	for corner in [Vector2(7,7),Vector2(size.x-7,7),Vector2(7,size.y-7),Vector2(size.x-7,size.y-7)]:
		var inward=Vector2(1 if corner.x<size.x/2 else -1,1 if corner.y<size.y/2 else -1)
		draw_line(corner,corner+Vector2(17*inward.x,0),Color("c5a36b"),2)
		draw_line(corner,corner+Vector2(0,17*inward.y),Color("c5a36b"),2)
		draw_circle(corner+inward*5,2,Color("b39055"))

# Payloads are single-use capabilities tied to this panel, tab, render and state.
# No candidate is published here: settlement's existing transaction saves first.
func begin_unit_drag(_position: Vector2, source: String, item: String, revision: int, tile: Control, slot_index:int=-1) -> Variant:
	if not visible or revision!=generation or current_inventory.amount(source,item)<1:return null
	if not source in ["carried","stash","lockbox"] or (source=="stash" and not access_stash):return null
	if source=="lockbox" and (slot_index<0 or slot_index>=4 or (not current_inventory.lockbox[slot_index] is String or current_inventory.lockbox[slot_index]!=item)):return null
	drag_serial+=1
	active_drag={"panel":get_instance_id(),"serial":drag_serial,"generation":generation,"source":source,"item":item,"slot_index":slot_index,"snapshot":current_inventory.data()}
	drag_in_progress=true
	DragPreview.attach(tile,icon(item),ITEM_NAMES[item]+" × 1")
	return active_drag.duplicate(true)
func current_drag(payload:Variant)->bool:
	return visible and payload is Dictionary and not active_drag.is_empty() and payload==active_drag and payload.get("generation")==generation and payload.get("snapshot")==current_inventory.data()
func can_drop_unit(_position:Vector2,payload:Variant,target:String)->bool:
	if current_lockbox_drag(payload):
		if target!="carried":return false
		if current_inventory.used("carried")>=current_inventory.capacity("carried"):
			feedback.text="Carried inventory is full. Make room first.";return false
		return true
	if can_drop_clothing(payload,target):return true
	if target=="carried" and visible and not equipment_editor.worn_slot_for_payload(payload).is_empty():
		return current_inventory.used("carried")<current_inventory.capacity("carried")
	if not current_drag(payload) or not target in ["carried","stash"] or target==payload.source:return false
	if "stash" in [payload.source,target] and not access_stash:return false
	if payload.source=="lockbox" and target!="carried":return false
	return current_inventory.amount(payload.source,payload.item)>0 and current_inventory.used(target)<current_inventory.capacity(target)
func drop_unit(position:Vector2,payload:Variant,target:String):
	if not can_drop_unit(position,payload,target):return
	if current_lockbox_drag(payload):
		var id:String=payload.instance_id;var cell:int=payload.cell
		active_lockbox_drag.clear()
		clothing_cell_requested.emit(id,"lockbox","carried",cell,generation,rendered_snapshot.duplicate(true));return
	if can_drop_clothing(payload,target):
		var id:String=payload.instance_id;var source:String=current_inventory.equipment_owned[id].location
		active_clothing_drag.clear();active_lockbox_drag.clear();equipment_editor.active_owned_drag.clear()
		clothing_transfer_requested.emit(id,source,"home_stash" if target=="stash" else "carried",generation,rendered_snapshot.duplicate(true));return
	var worn_slot:String=equipment_editor.worn_slot_for_payload(payload)
	if target=="carried" and not worn_slot.is_empty():
		equipment_action_requested.emit("unequip",payload.instance_id,worn_slot,generation);return
	var source:String=payload.source;var item:String=payload.item;var slot_index:int=payload.slot_index
	active_drag.clear()
	if selected_items.has(source):selected_items[source]=item
	if source=="lockbox":cell_transfer_requested.emit(source,target,item,slot_index,generation)
	else:transfer_requested.emit(source,target,item,1)
func can_drop_lockbox(_position:Vector2,payload:Variant,slot_index:int)->bool:
	if visible and payload is Dictionary and equipment_editor.current_owned_drag(payload):
		var id=payload.get("instance_id")
		if not id is String or not current_inventory.equipment_owned.has(id) or current_inventory.equipment_owned[id].location!="carried":return false
		if current_inventory.data()!=rendered_snapshot or slot_index < -1 or slot_index>=4:return false
		if current_inventory.used("lockbox")>=4 or (slot_index>=0 and not current_inventory.empty_lockbox_cell(current_inventory.lockbox[slot_index])):
			feedback.text="That Lockbox cell is occupied or full.";return false
		return true
	if not current_drag(payload) or payload.source!="carried" or slot_index < -1 or slot_index>=4:return false
	if slot_index>=0 and not current_inventory.empty_lockbox_cell(current_inventory.lockbox[slot_index]):return false
	return current_inventory.amount("carried",payload.item)>0 and current_inventory.used("lockbox")<4
func drop_lockbox(position:Vector2,payload:Variant,slot_index:int):
	if not can_drop_lockbox(position,payload,slot_index):return
	if equipment_editor.current_owned_drag(payload):
		var id:String=payload.instance_id
		equipment_editor.active_owned_drag.clear()
		clothing_cell_requested.emit(id,"carried","lockbox",slot_index,generation,rendered_snapshot.duplicate(true));return
	var item:String=payload.item;active_drag.clear()
	cell_transfer_requested.emit("carried","lockbox",item,slot_index,generation)
func click_unit(source: String, item: String):
	if not visible or not ITEM_NAMES.has(item) or current_inventory.amount(source,item)<1:return
	if not source in ["carried","stash"] or not access_stash:return
	selected_items[source]=item
	var target: String="stash" if source=="carried" else "carried"
	# Existing authoritative handler rechecks live proximity, capacity and save.
	var revision=generation
	transfer_requested.emit(source,target,item,1)
	if revision==generation:render(current_inventory,access_stash)
func _notification(what: int):
	if what==NOTIFICATION_DRAG_END:
		active_clothing_drag.clear();active_lockbox_drag.clear();equipment_editor.active_owned_drag.clear()
		active_drag.clear()
		finish_drag.call_deferred()
	if what==NOTIFICATION_VISIBILITY_CHANGED and not visible:
		active_drag.clear();active_clothing_drag.clear();active_lockbox_drag.clear();equipment_editor.active_owned_drag.clear();drag_in_progress=false
func finish_drag():
	drag_in_progress=false

func fit_viewport():
	# Wrapped labels can temporarily raise minimum size during rebuilding.
	await get_tree().process_frame
	if not is_inside_tree():return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left=26;offset_top=24;offset_right=-26;offset_bottom=-24

func can_assign_material(payload:Variant)->bool:
	return visible and payload is Dictionary and not active_drag.is_empty() and payload==active_drag and payload.get("generation")==generation and payload.get("snapshot")==current_inventory.data() and payload.get("source")=="carried" and ITEM_NAMES.has(payload.get("item")) and current_inventory.amount("carried",payload.item)>0

func begin_clothing_drag(position:Vector2,container:String,instance_id:String,revision:int,tile:Control=null)->Variant:
	if not visible or revision!=generation or rendered_snapshot!=current_inventory.data():return null
	if not current_inventory.equipment_owned.has(instance_id):return null
	var source:String=current_inventory.equipment_owned[instance_id].location
	if container=="carried" and source=="carried":
		drag_in_progress=true
		return equipment_editor.begin_owned_drag(position,instance_id,tile)
	if container!="stash" or source!="home_stash" or not access_stash:return null
	drag_serial+=1;drag_in_progress=true
	active_clothing_drag={"kind":"stored_clothing","panel":get_instance_id(),"serial":drag_serial,"generation":generation,"instance_id":instance_id,"snapshot":rendered_snapshot.duplicate(true)}
	var entry:Dictionary=current_inventory.equipment_owned[instance_id]
	var definition:Dictionary=current_inventory.equipment_definitions()[entry.definition_id]
	DragPreview.attach(tile,preload("res://scripts/clothing_icons.gd").texture(definition,entry),definition.display_name)
	return active_clothing_drag.duplicate(true)
func can_drop_clothing(payload:Variant,target:String)->bool:
	if not visible or not access_stash or not target in ["carried","stash"] or current_inventory.data()!=rendered_snapshot or not payload is Dictionary:return false
	var id=payload.get("instance_id")
	if not id is String or not current_inventory.equipment_owned.has(id):return false
	var source:String=current_inventory.equipment_owned[id].location
	if source=="home_stash":
		if target!="carried" or active_clothing_drag.is_empty() or payload!=active_clothing_drag:return false
	elif source in ["carried","equipped"]:
		if target!="stash" or not equipment_editor.current_owned_drag(payload):return false
	else:return false
	return current_inventory.used(target)<current_inventory.capacity(target)
func click_clothing(container:String,instance_id:String):
	if not visible or not access_stash or rendered_snapshot!=current_inventory.data() or not current_inventory.equipment_owned.has(instance_id):return
	var source:String="carried" if container=="carried" else "home_stash"
	if current_inventory.equipment_owned[instance_id].location!=source:return
	clothing_transfer_requested.emit(instance_id,source,"home_stash" if container=="carried" else "carried",generation,rendered_snapshot.duplicate(true))

func add_lockbox_garment(cells:GridContainer,id:String,cell:int,revision:int):
	var entry:Dictionary=current_inventory.equipment_owned[id]
	var definition:Dictionary=current_inventory.equipment_definitions()[entry.definition_id]
	var tile=Button.new();tile.name="LockboxSlot%d"%cell;tile.custom_minimum_size=Vector2(128,cell_height())
	tile.set_meta("inventory_focus","slot_%d"%cell);tile.set_meta("garment_id",id)
	tile.text=definition.category.capitalize();tile.icon=preload("res://scripts/clothing_icons.gd").texture(definition,entry);tile.expand_icon=true;tile.add_theme_constant_override("icon_max_width",44)
	tile.tooltip_text=definition.display_name+" • One provisional unit. Click or drag to carried inventory before equipping, dyeing or quick access."
	tile.pressed.connect(func():
		if visible and generation==revision and not drag_in_progress:
			clothing_cell_requested.emit(id,"lockbox","carried",cell,revision,rendered_snapshot.duplicate(true))
	)
	tile.set_drag_forwarding(begin_lockbox_clothing_drag.bind(id,cell,revision,tile),can_drop_lockbox.bind(cell),drop_lockbox.bind(cell))
	cells.add_child(tile)
func begin_lockbox_clothing_drag(_position:Vector2,id:String,cell:int,revision:int,tile:Button)->Variant:
	if not visible or cell<0 or cell>=4 or revision!=generation or rendered_snapshot!=current_inventory.data() or (not current_inventory.lockbox[cell] is Dictionary or current_inventory.lockbox[cell]!={"kind":"equipment","instance_id":id}):return null
	drag_serial+=1;drag_in_progress=true
	active_lockbox_drag={"kind":"lockbox_clothing","panel":get_instance_id(),"serial":drag_serial,"generation":generation,"instance_id":id,"cell":cell,"snapshot":rendered_snapshot.duplicate(true)}
	DragPreview.attach(tile,tile.icon,current_inventory.equipment_definitions()[current_inventory.equipment_owned[id].definition_id].display_name)
	return active_lockbox_drag.duplicate(true)
func current_lockbox_drag(payload:Variant)->bool:
	return visible and payload is Dictionary and not active_lockbox_drag.is_empty() and payload==active_lockbox_drag and payload.get("generation")==generation and payload.get("snapshot")==current_inventory.data()
