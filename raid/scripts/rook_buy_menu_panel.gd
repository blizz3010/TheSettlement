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
	Icons.update_hero(self, row)
	if not row.is_empty() and is_instance_valid(details):
		var reason := str(row.get("reason", ""))
		details.text = Icons.stats_text(row)
		if not reason.is_empty() and not details.text.contains(reason):
			details.text += "\n\n" + reason
		if action == "sell":
			details.text += "\n\n" + str(shop_definition.get("sale_help", "Only eligible carried material stacks. Equipment, quest items, stash and Lockbox are protected."))
