extends Control
const Map = preload("res://scripts/settlement_map.gd")
const FullMapPanel = preload("res://scripts/map_panel.gd")
var scene:Node3D
var mini:Control
var full:PanelContainer
var full_map:Control
var home_backing:Control
var health_bar:ProgressBar
var health_text:Label
var equipment:HBoxContainer
var vitals_panel:VBoxContainer
func setup(world:Node3D):
	scene=world;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
	for child in scene.hud_root.get_children():
		if child is Panel and child.anchor_top==0 and child.offset_top==16:home_backing=child
	mini=Map.new();add_child(mini);mini.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mini.offset_left=-220;mini.offset_top=24;mini.offset_right=-24;mini.offset_bottom=220;mini.setup(scene)
	full=PanelContainer.new();add_child(full);full.set_anchors_and_offsets_preset(Control.PRESET_CENTER);full.offset_left=-390;full.offset_right=390;full.offset_top=-325;full.offset_bottom=325
	var panel_style=StyleBoxFlat.new();panel_style.bg_color=Color("182725");panel_style.border_color=Color("927c52");panel_style.set_border_width_all(2);panel_style.content_margin_left=14;panel_style.content_margin_right=14;panel_style.content_margin_top=12;panel_style.content_margin_bottom=12;full.add_theme_stylebox_override("panel",panel_style)
	var column=VBoxContainer.new();full.add_child(column)
	var header=HBoxContainer.new();column.add_child(header)
	var title=Label.new();title.text="Settlement Map";title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	var close=Button.new();close.text="Close";close.pressed.connect(scene.close_map);header.add_child(close)
	full_map=FullMapPanel.new();full_map.custom_minimum_size=Vector2(600,560);full_map.size_flags_horizontal=Control.SIZE_EXPAND_FILL;full_map.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(full_map);full_map.setup(scene)
	full.hide()
	vitals_panel=VBoxContainer.new();add_child(vitals_panel);vitals_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);vitals_panel.offset_left=24;vitals_panel.offset_top=-78;vitals_panel.offset_right=204;vitals_panel.offset_bottom=-24;vitals_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	health_text=Label.new();vitals_panel.add_child(health_text)
	health_bar=ProgressBar.new();health_bar.custom_minimum_size=Vector2(180,12);health_bar.show_percentage=false;vitals_panel.add_child(health_bar)
	var fill=StyleBoxFlat.new();fill.bg_color=Color("65b49f");fill.corner_radius_top_left=3;fill.corner_radius_bottom_right=3;health_bar.add_theme_stylebox_override("fill",fill)
	var track=StyleBoxFlat.new();track.bg_color=Color("182a28");health_bar.add_theme_stylebox_override("background",track)
	scene.player.vitals.changed.connect(update_health);update_health(scene.player.vitals.current,scene.player.vitals.maximum)
	equipment=HBoxContainer.new();add_child(equipment);equipment.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);var bar_width=scene.quickbar.SLOT_COUNT*54-6;equipment.offset_left=-bar_width/2;equipment.offset_top=-72;equipment.offset_right=bar_width/2;equipment.offset_bottom=-24;equipment.add_theme_constant_override("separation",6)
	for slot in range(scene.quickbar.SLOT_COUNT):
		var button=Button.new();button.text=str(slot+1)+"\n—";button.disabled=true;button.custom_minimum_size=Vector2(48,48);var empty_style=StyleBoxFlat.new();empty_style.bg_color=Color("182725");empty_style.border_color=Color("766849");empty_style.set_border_width_all(1);button.add_theme_stylebox_override("disabled",empty_style);button.tooltip_text="Slot %d — empty. Assign carried items in inventory." % (slot+1);equipment.add_child(button)
	scene.quickbar.selection_changed.connect(update_quickbar)
	update_quickbar(scene.quickbar.selected_index)

var displayed_inventory:RefCounted=null
func _process(_delta):
	if not is_instance_valid(scene):return
	if displayed_inventory!=scene.inventory:update_quickbar(scene.quickbar.selected_index)
	# Plot details belong in Mara’s existing upgrade menu, never a roaming HUD.
	scene.hud.hide()
	if is_instance_valid(home_backing):home_backing.visible=scene.hud.visible
	vitals_panel.visible=not scene.modal_open()
	equipment.visible=not scene.modal_open() and not scene.build_mode
	mini.visible=not scene.modal_open()
	# Bound the panel to the real viewport, including the smallest supported display.
	full.offset_left=-minf(390,size.x/2-24);full.offset_right=minf(390,size.x/2-24)
	full.offset_top=-minf(325,size.y/2-24);full.offset_bottom=minf(325,size.y/2-24)
	full_map.custom_minimum_size=Vector2(minf(600,size.x-80),minf(560,size.y-130))

func update_health(current:float, maximum:float):
	health_bar.max_value=maximum;health_bar.value=current
	health_text.text="HEALTH   %d / %d" % [roundi(current),roundi(maximum)]

func update_quickbar(selected:int):
	displayed_inventory=scene.inventory
	for index in range(equipment.get_child_count()):
		var button=equipment.get_child(index)
		var assignments=scene.inventory.hotbar_assignments
		var context=scene.inventory.hotbar_context()
		var target_id=assignments[index]
		var label="Empty"
		var equipment_icon=false
		button.icon=null
		var tooltip="Empty • assign carried items in inventory"
		if not target_id.is_empty() and preload("res://scripts/hotbar_contract.gd").valid_reference(target_id,context):
			var record=context.targets[target_id]
			if record.kind=="instance":
				var entry=context.owned[record.item_id];var definition=context.definitions[entry.definition_id]
				label=definition.category.capitalize();equipment_icon=true
				button.icon=preload("res://scripts/clothing_icons.gd").texture(definition,entry);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",22)
				tooltip=definition.display_name+(" • equipped" if entry.location=="equipped" else " • carried; equip from Inventory")+" • no quick-use action"
			else:
				label="×"+str(record.count)
				button.icon=preload("res://scripts/fishing_item_icons.gd").texture(record.item_id) if record.item_id in ["fishing_pole","river_fish"] else (preload("res://scripts/production_item_icons.gd").texture(record.item_id) if record.item_id in preload("res://scripts/production_item_icons.gd").ITEMS else load("res://assets/ui/inventory_"+record.item_id+".svg"));button.expand_icon=true;button.add_theme_constant_override("icon_max_width",22)
				tooltip=scene.inventory.ITEMS[record.item_id]+" × "+str(record.count)+(" • select to place" if record.item_id=="lantern_kit" else " • carried material; no use action")
				if record.item_id=="fishing_pole":tooltip="Basic fishing pole • Select this slot, then interact at the marked fishing bank."
				elif record.item_id=="river_fish":tooltip="River fish • Trade at the Cookhouse or prepare a display sample at the griddle. Eating is unavailable."
		button.text=str(index+1) if equipment_icon else "%d\n%s"%[index+1,label]
		button.tooltip_text=tooltip

		var style=button.get_theme_stylebox("disabled").duplicate()
		style.border_color=Color("70c9b2") if index==selected else Color("766849")
		style.set_border_width_all(2 if index==selected else 1)
		button.add_theme_stylebox_override("disabled",style)
