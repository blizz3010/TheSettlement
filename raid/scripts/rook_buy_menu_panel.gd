extends "res://scripts/supplies_panel.gd"
## Item 16: Rook's Supplies buy menu with rendered model icons and a detail hero.
const Icons = preload("res://raid/scripts/trader_buy_icons.gd")
var hero: TextureRect

func _ready():
	super._ready()
	name = "RookBuyMenuPanel"
	hero = Icons.install_hero(self)

func _item_texture(row: Dictionary) -> Texture2D:
	var t := Icons.texture(str(row.get("icon_item", row.get("id", ""))))
	return t

func _rebuild_list():
	super._rebuild_list()
	Icons.apply_row_style(self)

func _update_summary():
	super._update_summary()
	var row := _selected_row()
	var previous := details.text if is_instance_valid(details) else ""
	Icons.update_hero(self, row)
	Icons.apply_details(self, row, previous)
	if not row.is_empty() and is_instance_valid(details) and action == "sell":
		var help := str(shop_definition.get("sale_help", "Only eligible carried material stacks. Equipment, quest items, stash and Lockbox are protected."))
		if not details.text.contains(help):
			details.text += "\n\n" + help
