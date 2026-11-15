extends "res://scripts/fishing_supply_panel.gd"
## Item 16: Fishing Supplies buy menu — pole and bait, rendered icons, confirm + funds.
const Icons = preload("res://raid/scripts/trader_buy_icons.gd")
const Stock = preload("res://raid/scripts/fishing_supply_catalog_ext.gd")
var hero: TextureRect

func _ready():
	super._ready()
	name = "FishingBuyMenuPanel"
	# The pinned panel only reviews quantity == 1 and only knows the pole.
	if review_requested.is_connected(_review_pole):
		review_requested.disconnect(_review_pole)
	review_requested.connect(_review_stock)
	configure(Stock.definition())
	hero = Icons.install_hero(self)

func _review_stock(item: String, count: int, mode: String):
	if mode == "buy" and count >= 1 and not Stock.row(item).is_empty():
		selected.emit(item)

func render(plot, inventory, pending: String, message: String = ""):
	var offered: Array = Stock.rows(inventory, "buy")
	var receipt := {}
	var row := Stock.row(pending)
	if not row.is_empty():
		var qty := int(quantity.value) if is_instance_valid(quantity) else 1
		qty = maxi(1, mini(qty, int(row.max_quantity)))
		var total: int = int(row.price) * qty
		receipt = {
			"token": 0,
			"shop_id": "fishing",
			"action": "buy",
			"item": pending,
			"name": row.name,
			"quantity": qty,
			"unit_price": int(row.price),
			"total": total,
			"balance_after": plot.credits - total,
			"carried_after": inventory.used("carried") + qty,
			"capacity": inventory.capacity("carried"),
		}
	render_state(plot, inventory, offered, receipt, message)

func _item_texture(row: Dictionary) -> Texture2D:
	return Icons.texture(str(row.get("icon_item", row.get("id", ""))))

func _rebuild_list():
	super._rebuild_list()
	Icons.apply_row_style(self)

func _update_summary():
	super._update_summary()
	var row := _selected_row()
	var previous := details.text if is_instance_valid(details) else ""
	Icons.update_hero(self, row)
	Icons.apply_details(self, row, previous)
