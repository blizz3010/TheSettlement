extends "res://raid/scripts/ship_title_preview.gd"
## Normal game entry (project main_scene). Michael's flow:
## Main Menu -> Character Select (item 15 mockup A) -> Settlement -> board the ship -> raids.
## Layers on the ship title so the pinned title_menu.gd stays untouched; the world is the
## ship settlement (res://raid/ship_settlement_preview.tscn), which carries the raids.
const MockupASelection = preload("res://raid/scripts/select_redesign_panel.gd")

func _ready():
	super._ready()
	# The inherited preview banner is for the opt-in review entry, not the normal game.
	if return_binding.is_empty(): status.hide()

func _play():
	if starting or replaying_intro or is_instance_valid(character_panel): return
	characters.rules = CharacterRules.data()
	character_panel = MockupASelection.new()
	character_panel.session = characters
	character_panel.back_requested.connect(_close_characters)
	character_panel.launch_requested.connect(_launch_character)
	menu.hide()
	add_child(character_panel)
