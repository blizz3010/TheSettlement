extends VBoxContainer
const DragPreview=preload("res://scripts/item_drag_preview.gd")
const Contract=preload("res://scripts/hotbar_contract.gd")
signal assignment_requested(index:int,target_id:String,snapshot_revision:int)
signal material_assignment_requested(index:int,payload:Dictionary,snapshot_revision:int)
var material_drop_validator:Callable=Callable()
signal swap_requested(source:int,destination:int,snapshot_revision:int)
var context:Dictionary={}
var assignments:Array=[]
var revision:int=0
var buttons:Array[Button]=[]
var selected_target:String="" # Retained inert compatibility field; no selection UI.
var clear_menu:PopupMenu
var menu_slot:int=-1
var menu_revision:int=-1
var menu_target:String=""
func render(next_context:Dictionary,next_assignments:Array,next_revision:int)->void:
	close_clear_menu()
	context=next_context.duplicate(true);assignments=next_assignments.duplicate(true);revision=next_revision;selected_target=""
	for child in get_children():
		if child!=clear_menu:remove_child(child);child.queue_free()
	buttons.clear()
	var heading=Label.new();heading.text="QUICK ACCESS  1–6  •  Drag carried items to any slot";add_child(heading)
	if not Contract.validate(assignments,context):
		var invalid=Label.new();invalid.text="Quick-access state unavailable.";add_child(invalid);return
	var row=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;row.add_theme_constant_override("separation",6);add_child(row)
	for index in range(Contract.SLOT_COUNT):
		var button=Button.new();button.custom_minimum_size=Vector2(76,42);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.text="%d\n%s"%[index+1,target_name(assignments[index])]
		if context.targets.has(assignments[index]) and context.targets[assignments[index]].kind=="stack":
			var item_id=context.targets[assignments[index]].item_id
			button.icon=preload("res://scripts/fishing_item_icons.gd").texture(item_id) if item_id in ["fishing_pole","river_fish"] else (preload("res://scripts/production_item_icons.gd").texture(item_id) if item_id in preload("res://scripts/production_item_icons.gd").ITEMS else load("res://assets/ui/inventory_"+item_id+".svg"));button.expand_icon=true;button.add_theme_constant_override("icon_max_width",24)
		if context.targets.has(assignments[index]) and context.targets[assignments[index]].kind=="instance":
			var entry=context.owned[context.targets[assignments[index]].item_id]
			button.icon=preload("res://scripts/clothing_icons.gd").texture(context.definitions[entry.definition_id],entry)
			button.expand_icon=true;button.add_theme_constant_override("icon_max_width",28)
		button.tooltip_text=target_name(assignments[index])+"\nDrag to assign or move a shortcut. Right click for Clear shortcut. This does not equip, consume or discard the item."
		button.set_drag_forwarding(begin_slot_drag.bind(index,button),can_drop.bind(index),drop.bind(index))
		button.gui_input.connect(func(event):
			if revision==next_revision and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:open_clear_menu(index,next_revision);accept_event()
		)
		buttons.append(button);row.add_child(button)
	var note=Label.new();note.text="Drag carried items here. Select your pole slot to fish at the marked bank. Lantern kits open placement; fish have no use action yet.";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.add_theme_font_size_override("font_size",11);add_child(note)
func target_name(target_id:String)->String:
	if target_id.is_empty():return "Empty"
	if not context.targets.has(target_id):return "Unavailable"
	var entry=context.targets[target_id]
	if entry.kind=="instance":return context.definitions[context.owned[entry.item_id].definition_id].display_name
	return preload("res://scripts/inventory_state.gd").ITEMS.get(entry.item_id,entry.item_id)+" × "+str(entry.count)
func begin_slot_drag(_position:Vector2,index:int,tile:Control=null)->Variant:
	if index<0 or index>=assignments.size() or assignments[index].is_empty():return null
	if tile!=null:DragPreview.attach(tile,tile.icon,target_name(assignments[index]))
	return {"kind":"quick_access", "target_id":assignments[index],"source_slot":index,"revision":revision}
func can_drop(_position:Vector2,payload:Variant,index:int)->bool:
	if index<0 or index>=Contract.SLOT_COUNT or not payload is Dictionary:return false
	if payload.has("panel"):
		return material_drop_validator.is_valid() and material_drop_validator.call(payload)
	if payload.size()!=4:return false
	if not payload.get("revision") is int or payload.revision!=revision or not payload.get("target_id") is String:return false
	if not payload.get("kind") in ["owned_equipment","quick_access"]:return false
	if payload.kind=="quick_access":
		if not payload.get("source_slot") is int or payload.source_slot<0 or payload.source_slot>=assignments.size():return false
		if assignments[payload.source_slot]!=payload.target_id:return false
	else:
		if not payload.get("instance_id") is String or not context.targets.has(payload.target_id):return false
		if context.targets[payload.target_id].kind!="instance" or context.targets[payload.target_id].item_id!=payload.instance_id:return false
	return Contract.valid_reference(payload.target_id,context)
func drop(position:Vector2,payload:Variant,index:int)->void:
	if not can_drop(position,payload,index):return
	if payload.has("panel"):material_assignment_requested.emit(index,payload,revision)
	elif payload.kind=="quick_access":swap_requested.emit(payload.source_slot,index,revision)
	else:assignment_requested.emit(index,payload.target_id,revision)

func close_clear_menu()->void:
	menu_slot=-1;menu_revision=-1;menu_target=""
	if is_instance_valid(clear_menu):clear_menu.hide()
func open_clear_menu(index:int,snapshot_revision:int)->bool:
	if snapshot_revision!=revision or index<0 or index>=assignments.size() or assignments[index].is_empty():return false
	if not Contract.valid_reference(assignments[index],context):return false
	if not is_instance_valid(clear_menu):
		clear_menu=PopupMenu.new();clear_menu.name="ShortcutMenu";add_child(clear_menu)
		clear_menu.add_item("Clear shortcut",0);clear_menu.id_pressed.connect(commit_clear_shortcut)
	menu_slot=index;menu_revision=revision;menu_target=assignments[index]
	clear_menu.position=Vector2i(get_viewport().get_mouse_position());clear_menu.popup()
	return true
func commit_clear_shortcut(id:int)->void:
	var index=menu_slot;var snapshot_revision=menu_revision;var target=menu_target
	close_clear_menu()
	if id!=0 or not is_visible_in_tree() or snapshot_revision!=revision or index<0 or index>=assignments.size():return
	if assignments[index]!=target or not Contract.valid_reference(target,context):return
	assignment_requested.emit(index,"",revision)
func _notification(what:int)->void:
	if what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():close_clear_menu()
