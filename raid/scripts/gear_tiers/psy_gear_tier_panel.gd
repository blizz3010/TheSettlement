extends "res://scripts/shop_panel.gd"
## Psy "Gear & Armor" tier panel (TASKS item 22, PR C). Reuses the pinned shop
## panel layout (list, details, review/confirm, credits) and adds tabs for
## repair, upgrade and equip. Tier rows get a coloured tier chip (placeholder art;
## rendered icons arrive with the art waves). The T0 helmet keeps its rendered icon.
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const Icons = preload("res://raid/scripts/trader_buy_icons.gd")
const GearArt = preload("res://raid/scripts/gear_tiers/gear_art.gd")
const Mannequin = preload("res://raid/scripts/gear_tiers/gear_mannequin.gd")
var chip_cache := {}
var loadout_help := ""
var worn_defs: Array = []
var mannequin: SubViewportContainer

func _ready():
	super._ready()
	name = "PsyGearTierPanel"

func _item_texture(row: Dictionary) -> Texture2D:
	var tier := int(row.get("tier", 0))
	# Gear art E0: rendered icon when the piece has real art, else the tier chip.
	var art_icon := GearArt.icon(str(row.get("def", row.get("id", ""))))
	if art_icon != null: return art_icon
	if tier >= 1 and tier <= 4: return _chip(tier)
	return Icons.texture(str(row.get("icon_item", row.get("id", ""))))

func _chip(tier: int) -> Texture2D:
	if chip_cache.has(tier): return chip_cache[tier]
	var img := Image.create(34, 34, false, Image.FORMAT_RGBA8)
	img.fill(Defs.TIER_COLORS[tier])
	var trim: Color = Defs.TIER_TRIM[tier]
	for b in tier:
		for x in 34:
			for y in range(26 - b * 6, 29 - b * 6): img.set_pixel(x, y, trim)
	for x in 34:
		img.set_pixel(x, 0, trim); img.set_pixel(x, 33, trim)
	var tex := ImageTexture.create_from_image(img)
	chip_cache[tier] = tex
	return tex

func _verb(value: String) -> String:
	return {"sell": "Sell", "repair": "Repair", "upgrade": "Upgrade", "equip": "Apply"}.get(value, "Buy")

func _review_label(value: String) -> String:
	return {"sell": "Review sale", "repair": "Review repair", "upgrade": "Review upgrade", "equip": "Review loadout change"}.get(value, "Review purchase")

func set_loadout_help(text: String) -> void:
	loadout_help = text

## Gear art E0: worn tiered defs, shown on the equip-tab mannequin (LOD1) with the selected
## piece as a try-on.
func set_worn(defs: Array) -> void:
	worn_defs = defs.duplicate()

func _update_mannequin() -> void:
	var on_equip := action == "equip"
	if on_equip and not is_instance_valid(mannequin) and is_instance_valid(body):
		mannequin = Mannequin.new(); body.add_child(mannequin)
	if not is_instance_valid(mannequin): return
	mannequin.visible = on_equip
	if not on_equip: return
	var ids := worn_defs.duplicate()
	for row in rows:
		if str(row.get("id", "")) == selected_item and not selected_item.is_empty():
			var def_id := str(row.get("def", row.get("id", "")))
			var item := Defs.item(def_id)
			if not item.is_empty():
				ids = ids.filter(func(d): return Defs.item(str(d)).get("slot", "") != item.slot)
				ids.append(def_id)
	mannequin.show_loadout(ids)

func _update_summary():
	if action == "equip" and not loadout_help.is_empty(): shop_definition["help"] = loadout_help
	super._update_summary()
	_update_mannequin()
	# Keep the 11-slot loadout visible on the equip tab while a piece is selected.
	if action == "equip" and not selected_item.is_empty() and not loadout_help.is_empty() and is_instance_valid(details):
		details.text += "\n\n" + loadout_help
	if _rendering or not is_instance_valid(confirm_button): return
	if not quote.is_empty():
		confirm_button.text = {"sell": "Confirm sale", "repair": "Confirm repair", "upgrade": "Confirm upgrade", "equip": "Confirm"}.get(str(quote.get("action", "")), "Confirm purchase")
