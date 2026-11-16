extends "res://scripts/shop_panel.gd"
## Item 13: Atlas's recovery stand. Reuses the item 16 / Dan icon, hero, confirm
## and insufficient-funds layout. This is a recovery service, not a buy menu.
const Icons = preload("res://raid/scripts/trader_buy_icons.gd")
const Store = preload("res://raid/scripts/atlas_recovery_store.gd")

var hero: TextureRect
var _store: Store = Store.new()

func _ready():
	super._ready()
	name = "AtlasRecoveryPanel"
	hero = Icons.install_hero(self)

func bind_store(store: Store) -> void:
	_store = store if store != null else Store.new()

func _item_texture(row: Dictionary) -> Texture2D:
	return Icons.texture(str(row.get("icon_item", row.get("item_id", row.get("id", "")))))

func _rebuild_list():
	super._rebuild_list()
	Icons.apply_row_style(self)

func _verb(value: String) -> String:
	return "Recover" if value in ["recover", "overview"] else super._verb(value)

func _review_label(value: String) -> String:
	return "Review recovery" if value in ["recover", "overview"] else super._review_label(value)

func render_board(plot, inventory, store: Store, pending: Dictionary = {}, message: String = "") -> void:
	bind_store(store)
	if action == "how it works":
		render_state(plot, inventory, help_rows(), pending, message)
	else:
		render_state(plot, inventory, recover_rows(store, inventory), pending, message)

func recover_rows(store: Store, inventory) -> Array:
	var rows: Array = []
	for row in store.open_rows():
		var qty: int = int(row.quantity)
		var total: int = int(row.unit_fee) * qty
		var ready: bool = str(row.get("status", "")) == "ready"
		var desc := "Held after you were downed"
		if not str(row.map).is_empty():
			desc += " in %s" % row.map
		if not str(row.source).is_empty():
			desc += " by the %s" % row.source
		desc += ".\n\n%d credits each · %d credits to recover the lot." % [int(row.unit_fee), total]
		if not ready:
			desc += "\n\nAtlas is still preparing this return. It will be ready shortly."
		else:
			desc += "\n\nUnclaimed items expire after %d more raids." % maxi(0, int(row.expire_after_raid) - store.raid_count)
		rows.append({
			"id": row.id,
			"icon_item": row.item_id,
			"item_id": row.item_id,
			"name": "%s × %d%s" % [Store.display_name(str(row.item_id)), qty, "" if ready else " · holding"],
			"category": "Ready" if ready else "Holding",
			"description": desc,
			"price": total,
			"owned": inventory.amount("carried", str(row.item_id)),
			"enabled": ready,
			"reason": "" if ready else "Not ready yet.",
			"max_quantity": 1,
			"space_per_unit": qty,
			"row_action": "recover",
		})
	if rows.is_empty():
		rows.append({
			"id": "recovery_empty",
			"icon_item": "timber",
			"name": "Nothing to recover",
			"category": "Overview",
			"description": "Atlas has no held items for you. Carried supplies lost on a failed raid appear here. Stash, Lockbox and equipped clothing stay at home. Raid field loot still does not persist, so caches found in a raid are not brought back.",
			"price": null,
			"owned": 0,
			"enabled": false,
			"reason": "Nothing to recover.",
			"max_quantity": 1,
			"space_per_unit": 0,
		})
	return rows

func help_rows() -> Array:
	return [{
		"id": "help_recovery",
		"icon_item": "timber",
		"name": "How Atlas recovery works",
		"category": "Help",
		"description": "If you are downed in a raid, the materials you were carrying are brought to Atlas. Stash, Lockbox and the clothes you are wearing stay with your hideout.\n\nPay the recovery fee to get an item back. Fees scale with the usual vendor price. Atlas needs a short moment to prepare a return; unclaimed items expire after three more raids.\n\nRaid field loot still does not persist in this build, so caches, keys and sample rolls from the map are not recovered here. Healing and a live retrieval network are not in this build.",
		"price": null,
		"owned": 0,
		"enabled": false,
		"reason": "Information only.",
		"max_quantity": 1,
		"space_per_unit": 0,
	}]

func _update_summary():
	if _rendering or not is_instance_valid(quantity):
		return
	var row: Dictionary = _selected_row()
	var previous: String = details.text if is_instance_valid(details) else ""
	super._update_summary()
	Icons.update_hero(self, row)
	if not row.is_empty() and row.get("enabled", false):
		Icons.apply_details(self, row, previous)
	if is_instance_valid(confirm_button) and not quote.is_empty() and quote.get("action") == "recover":
		confirm_button.text = "Confirm recovery"
		totals.text = "Recover %s · %d credits\nAfter: %d credits · Carried %d / %d" % [quote.get("name", row.get("name", "")), quote.total, quote.balance_after, quote.carried_after, quote.capacity]
