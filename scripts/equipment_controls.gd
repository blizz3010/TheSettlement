extends VBoxContainer
const DragPreview=preload("res://scripts/item_drag_preview.gd")
const Catalog=preload("res://scripts/equipment_catalog.gd")
const Contract=preload("res://scripts/hotbar_contract.gd")
signal action_requested(action:String, instance_id:String, slot:String, snapshot_revision:int)
const LABELS={"helmet":"Helmet","visor":"Visor","headset":"Headset","face_cover":"Face cover","body_armor":"Body armor","tactical_rig":"Tactical rig","gloves":"Gloves","jacket":"Jacket","pants":"Pants","boots":"Boots","backpack":"Backpack","primary_firearm":"Primary","sidearm":"Sidearm","secondary_tool":"Secondary / Tool"}
var context:Dictionary={}
var revision:int=0
var slots:Dictionary={}
var owned_buttons:Dictionary={}
var active_owned_drag:Dictionary={}
var selected_instance:String=""
var character_preview
var equipment_row:HBoxContainer
var left_slots:VBoxContainer
var right_slots:VBoxContainer
var unequip_menu:PopupMenu
var menu_instance:String=""
var menu_slot:String=""
var menu_revision:int=-1
const ClothingIcons=preload("res://scripts/clothing_icons.gd")
func render(next_context:Dictionary, next_revision:int, appearance:Dictionary={}) -> void:
	active_owned_drag.clear()
	close_unequip_menu()
	context=next_context.duplicate(true);revision=next_revision
	# Keep the SubViewport in-tree across refreshes: no renderer/world teardown.
	for child in get_children():
		if child!=equipment_row and child!=unequip_menu:remove_child(child);child.queue_free()
	if is_instance_valid(equipment_row):equipment_row.hide()
	slots.clear();owned_buttons.clear()
	var heading=Label.new();heading.text="CHARACTER / EQUIPMENT";add_child(heading);move_child(heading,0)
	if not Contract.valid_context(context):
		var unavailable=Label.new();unavailable.text="Equipment data unavailable.";add_child(unavailable);return
	if not context.owned.has(selected_instance):selected_instance=""
	if not is_instance_valid(equipment_row):
		equipment_row=HBoxContainer.new();equipment_row.add_theme_constant_override("separation",4);add_child(equipment_row)
		left_slots=VBoxContainer.new();left_slots.size_flags_horizontal=Control.SIZE_EXPAND_FILL;equipment_row.add_child(left_slots)
		character_preview=preload("res://scripts/clothing_preview.gd").new();equipment_row.add_child(character_preview)
		character_preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
		character_preview.get_child(0).render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
		right_slots=VBoxContainer.new();right_slots.size_flags_horizontal=Control.SIZE_EXPAND_FILL;equipment_row.add_child(right_slots)
	equipment_row.show();move_child(equipment_row,1)
	for side in [left_slots,right_slots]:
		for button in side.get_children():side.remove_child(button);button.queue_free()
	character_preview.custom_minimum_size=Vector2(96 if get_viewport_rect().size.x<1280 else 140,300)
	character_preview.show_equipped(context)
	var appearance_ok=character_preview.show_appearance(appearance)
	if not appearance_ok:
		var warning=Label.new();warning.text="Character appearance unavailable";add_child(warning)
	elif not appearance.is_empty():
		heading.text=appearance.name+" / EQUIPMENT"
	var slot_index=0
	for slot in Catalog.SLOT_TYPES:
		var button=Button.new();button.custom_minimum_size=Vector2(84,44);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size",12)
		button.text=LABELS[slot]+"\nEmpty" if context.slots[slot].is_empty() else LABELS[slot]
		if not context.slots[slot].is_empty():
			var worn=context.owned[context.slots[slot]]
			button.icon=ClothingIcons.texture(context.definitions[worn.definition_id],worn)
			if button.icon!=null:
				button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;button.vertical_icon_alignment=VERTICAL_ALIGNMENT_BOTTOM
				button.expand_icon=true;button.add_theme_constant_override("icon_max_width",30);button.custom_minimum_size.y=60
			else:button.text+="\n"+item_name(context.slots[slot])
		button.tooltip_text=(LABELS[slot]+": Empty" if context.slots[slot].is_empty() else item_name(context.slots[slot]))+"\nDrag owned gear here to equip. Right click worn gear for Unequip, or drag it to carried inventory.";button.set_meta("equipment_slot",slot)
		button.set_drag_forwarding(begin_slot_drag.bind(slot,button),can_drop.bind(slot),drop.bind(slot))
		button.pressed.connect(func():
			if revision==next_revision and not selected_instance.is_empty():action_requested.emit("equip",selected_instance,slot,revision)
		)
		button.gui_input.connect(func(event):
			if revision==next_revision and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and not context.slots[slot].is_empty():
				open_unequip_menu(slot,next_revision);accept_event()
		)
		slots[slot]=button;(left_slots if slot_index%2==0 else right_slots).add_child(button);slot_index+=1
	var note=Label.new();note.text="Current clothing and basic helmet are cosmetic only.\nNo protection or extra carrying capacity is implemented."
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.add_theme_font_size_override("font_size",11);add_child(note)
func item_name(instance_id:String)->String:
	if not context.owned.has(instance_id):return "Unavailable"
	return context.definitions[context.owned[instance_id].definition_id].display_name
func target_for(instance_id:String)->String:
	for target_id in context.get("targets",{}):
		var record=context.targets[target_id]
		if record.kind=="instance" and record.item_id==instance_id:return target_id
	return ""
func begin_owned_drag(_position:Vector2,instance_id:String,tile:Control=null)->Variant:
	var target_id=target_for(instance_id)
	if target_id.is_empty() or not Contract.valid_reference(target_id,context):return null
	active_owned_drag={"kind":"owned_equipment", "target_id":target_id,"instance_id":instance_id,"revision":revision}
	var entry:Dictionary=context.owned[instance_id]
	DragPreview.attach(tile,ClothingIcons.texture(context.definitions[entry.definition_id],entry),item_name(instance_id))
	return active_owned_drag.duplicate(true)
func begin_slot_drag(position:Vector2,slot:String,tile:Control=null)->Variant:
	return begin_owned_drag(position,context.slots.get(slot,""),tile)
func can_drop(_position:Vector2,payload:Variant,slot:String)->bool:
	if not payload is Dictionary or payload.size()!=4:return false
	if payload.get("kind")!="owned_equipment" or not payload.get("revision") is int or payload.revision!=revision:return false
	if not payload.get("instance_id") is String or not payload.get("target_id") is String:return false
	if not Contract.valid_reference(payload.target_id,context) or not context.owned.has(payload.instance_id):return false
	if context.targets[payload.target_id].kind!="instance" or context.targets[payload.target_id].item_id!=payload.instance_id:return false
	return Catalog.accepts(slot,context.definitions[context.owned[payload.instance_id].definition_id])
func drop(position:Vector2,payload:Variant,slot:String)->void:
	if can_drop(position,payload,slot):action_requested.emit("equip",payload.instance_id,slot,revision)

func request_quick_equip(instance_id:String,snapshot_revision:int)->bool:
	if snapshot_revision!=revision or not Contract.valid_context(context) or not context.owned.has(instance_id):return false
	var entry:Dictionary=context.owned[instance_id]
	if entry.location!="carried":return false
	var definition:Dictionary=context.definitions[entry.definition_id]
	for slot in Catalog.SLOT_TYPES:
		if Catalog.accepts(slot,definition):
			action_requested.emit("equip",instance_id,slot,revision);return true
	return false

func close_unequip_menu()->void:
	menu_instance="";menu_slot="";menu_revision=-1
	if is_instance_valid(unequip_menu):unequip_menu.hide()
func open_unequip_menu(slot:String,snapshot_revision:int)->bool:
	if snapshot_revision!=revision or not Contract.valid_context(context):return false
	var instance_id:String=context.slots.get(slot,"")
	if instance_id.is_empty() or not context.owned.has(instance_id) or context.owned[instance_id].location!="equipped":return false
	if not is_instance_valid(unequip_menu):
		unequip_menu=PopupMenu.new();unequip_menu.name="WornItemMenu";add_child(unequip_menu)
		unequip_menu.add_item("Unequip",0)
		unequip_menu.id_pressed.connect(commit_menu_unequip)
	menu_instance=instance_id;menu_slot=slot;menu_revision=revision
	unequip_menu.position=Vector2i(get_viewport().get_mouse_position())
	unequip_menu.popup()
	return true
func commit_menu_unequip(id:int)->void:
	var instance_id=menu_instance;var slot=menu_slot;var snapshot_revision=menu_revision
	close_unequip_menu()
	if id!=0 or not is_visible_in_tree() or snapshot_revision!=revision:return
	if context.slots.get(slot,"")!=instance_id or instance_id.is_empty():return
	action_requested.emit("unequip",instance_id,slot,revision)
func worn_slot_for_payload(payload:Variant)->String:
	if not is_visible_in_tree() or not payload is Dictionary:return ""
	for slot in Catalog.SLOT_TYPES:
		if can_drop(Vector2.ZERO,payload,slot) and context.slots[slot]==payload.instance_id and context.owned[payload.instance_id].location=="equipped":return slot
	return ""
func _notification(what:int)->void:
	if what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():close_unequip_menu()

func current_owned_drag(payload:Variant)->bool:
	return payload is Dictionary and not active_owned_drag.is_empty() and payload==active_owned_drag and payload.get("revision")==revision and context.owned.has(payload.get("instance_id",""))
