extends RefCounted
## Swaps the inventory's head-graft preview for the real-rig preview, without
## touching the pinned inventory scripts. Connected to SceneTree.node_added by the
## settlement adapter. Only exact clothing_preview.gd instances that sit in an
## equipment_controls.gd row are replaced (the tailor's dye preview is untouched).
const ClothingPreview=preload("res://scripts/clothing_preview.gd")
const EquipmentControls=preload("res://scripts/equipment_controls.gd")
const RigPreview=preload("res://raid/scripts/inventory_model_preview.gd")

static func on_node_added(node:Node):
	if node.get_script()!=ClothingPreview:return
	var row=node.get_parent()
	if row==null:return
	var controls=row.get_parent()
	if controls==null or controls.get_script()!=EquipmentControls:return
	(func():swap(controls,node)).call_deferred()

static func swap(controls:Node,old:Node):
	if not is_instance_valid(controls) or not is_instance_valid(old) or controls.character_preview!=old:return
	var row=old.get_parent()
	if row==null:return
	var replacement=RigPreview.new()
	row.add_child(replacement);row.move_child(replacement,old.get_index())
	replacement.mouse_filter=old.mouse_filter
	replacement.custom_minimum_size=old.custom_minimum_size
	replacement.render_view.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
	controls.character_preview=replacement
	# Re-apply exactly what equipment_controls.render() just showed on the old node.
	replacement.show_equipped(controls.context)
	var appearance:Dictionary=old.selected_appearance
	row.remove_child(old);old.queue_free()
	replacement.show_appearance(appearance)
