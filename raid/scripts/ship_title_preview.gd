extends "res://scripts/title_menu.gd"
## Opt-in entry. Uses all original character binding and startup gates.
var return_binding: Dictionary = {}

func _ready():
	world_path = "res://raid/ship_settlement_preview.tscn"
	super._ready()
	status.text = "SHIP RAID PREVIEW • Isolated test saves only • No persistent raid loot"
	status.show()
	_layout()
	if not return_binding.is_empty(): call_deferred("_continue_after_preview")

func _continue_after_preview():
	characters.rules = CharacterRules.data()
	var slot = str(return_binding.get("slot", ""))
	if slot.is_empty():
		if not FileAccess.file_exists("user://settlement_v1.json"):
			_return_failed("The saved settlement is unavailable. No replacement save was created.")
			return
		legacy_launch = true
	else:
		var selection = characters.select_character(slot)
		if not selection.get("ok", false):
			_return_failed("Could not restore the selected character: " + str(selection.get("reason", "Unavailable")))
			return
		if characters.pending.get("appearance", {}) != return_binding.get("appearance", {}):
			characters.cancel()
			_return_failed("Character appearance changed during the preview. Select your character again.")
			return
		legacy_launch = false
		character_token = int(selection.generation)
	# Already launched through the title once. Do not replay or write intro state.
	intro_pending = false
	_launch_world()

func _return_failed(reason: String):
	status.text = reason
	status.show()

const FixedCharacterSelection = preload("res://raid/scripts/character_select_panel_fixed.gd")

func _play():
	# Item 15b: same flow as the pinned title menu, but the select panel shows the
	# real character rig instead of the head-graft mannequin.
	if starting or replaying_intro or is_instance_valid(character_panel): return
	characters.rules = CharacterRules.data()
	character_panel = FixedCharacterSelection.new()
	character_panel.session = characters
	character_panel.back_requested.connect(_close_characters)
	character_panel.launch_requested.connect(_launch_character)
	menu.hide()
	add_child(character_panel)
