extends "res://raid/scripts/character_model_stage.gd"
## Item 15b follow-up: the in-game inventory equipment preview had the same
## head-graft bug as the select screen (equipment_controls.gd -> clothing_preview.gd
## -> inventory_character_head.gd). This is the real-rig stage from the select-screen
## fix, re-sized for the inventory column (no select-screen sizing or transparency).
func _ready():
	super._ready()
	# Undo the select-screen-only presentation from selection_stage.gd.
	size_flags_vertical=Control.SIZE_SHRINK_CENTER
	size_flags_horizontal=Control.SIZE_FILL
	custom_minimum_size=Vector2(270,320)
	render_view.transparent_bg=false
	render_view.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
	set_angle(28)

func redraw_preview():
	# The inventory column re-renders while visible (as the shipped preview did).
	if is_instance_valid(render_view):render_view.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
