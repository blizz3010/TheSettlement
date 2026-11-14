extends "res://scripts/character_profiles/selection_panel.gd"
## Item 15b adapter: same select panel, but the preview is the real character model.
const ModelStage=preload("res://raid/scripts/character_model_stage.gd")

func _ready():
	super._ready()
	var old=preview
	var index=old.get_index()
	var replacement=ModelStage.new()
	preview_holder.add_child(replacement)
	preview_holder.move_child(replacement,index)
	preview_holder.remove_child(old);old.queue_free()
	preview=replacement
	refresh()
