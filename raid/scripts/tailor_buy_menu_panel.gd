extends "res://scripts/clothing_panel.gd"
## Item 16: Tailor buy menu with rendered model icons and a detail hero.
const Icons = preload("res://raid/scripts/trader_buy_icons.gd")
var hero: TextureRect

func _ready():
	super._ready()
	name = "TailorBuyMenuPanel"
	hero = Icons.install_hero(self)

func _item_texture(row: Dictionary) -> Texture2D:
	return Icons.texture(str(row.get("icon_item", row.get("id", ""))))

func _rebuild_list():
	super._rebuild_list()
	Icons.apply_row_style(self)

func _update_summary():
	super._update_summary()
	var row := _selected_row()
	Icons.update_hero(self, row)
	if service_mode == "shop" and not row.is_empty() and is_instance_valid(details):
		var reason := str(row.get("reason", ""))
		details.text = Icons.stats_text(row)
		if not reason.is_empty() and not details.text.contains(reason):
			details.text += "\n\n" + reason
	# Hide the hero on dye/craft tabs — those already have their own preview.
	if is_instance_valid(hero):
		hero.visible = service_mode == "shop" and hero.texture != null
