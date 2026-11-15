extends RefCounted
## Shared rendered-icon loader and detail-pane hero for item 16 buy menus.
## Icons live at res://raid/assets/trader_icons/<id>.png (imported, or loaded from disk).
const ICON_DIR := "res://raid/assets/trader_icons"
static var _cache: Dictionary = {}

static func path_for(id: String) -> String:
	var key := _key(id)
	return ICON_DIR.path_join(key + ".png")

static func _key(id: String) -> String:
	if id.begins_with("pattern_basic_"):
		return "pattern_sheet"
	return id

static func texture(id: String) -> Texture2D:
	var key := _key(id)
	if _cache.has(key):
		return _cache[key]
	var res_path := ICON_DIR.path_join(key + ".png")
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		tex = load(res_path) as Texture2D
	if tex == null:
		var abs_path := ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

static func install_hero(panel: Control) -> TextureRect:
	if panel.has_meta("trader_hero") and is_instance_valid(panel.get_meta("trader_hero")):
		return panel.get_meta("trader_hero")
	if not is_instance_valid(panel.detail_panel):
		return null
	# ShopPanel puts a ScrollContainer (with the details Label) in detail_panel.
	# Clothing/dye already has a 3D preview elsewhere; the shop tab still gets a hero.
	var scroll: Node = null
	for child in panel.detail_panel.get_children():
		if child is ScrollContainer:
			scroll = child
			break
	if scroll == null:
		return null
	panel.detail_panel.remove_child(scroll)
	var col := VBoxContainer.new()
	col.name = "TraderDetailColumn"
	col.add_theme_constant_override("separation", 8)
	panel.detail_panel.add_child(col)
	var hero := TextureRect.new()
	hero.name = "ItemHero"
	hero.custom_minimum_size = Vector2(0, 170)
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hero)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	panel.set_meta("trader_hero", hero)
	return hero

static func apply_row_style(panel: Control) -> void:
	if not is_instance_valid(panel) or not "item_buttons" in panel:
		return
	for b in panel.item_buttons.values():
		if b is Control:
			b.custom_minimum_size.y = 64
			for t in b.find_children("*", "TextureRect", true, false):
				t.custom_minimum_size = Vector2(48, 48)

static func update_hero(panel: Control, row: Dictionary) -> void:
	var hero: TextureRect = panel.get_meta("trader_hero") if panel.has_meta("trader_hero") else null
	if hero == null:
		return
	if row.is_empty():
		hero.texture = null
		hero.visible = false
		return
	hero.texture = texture(str(row.get("icon_item", row.get("id", ""))))
	hero.visible = hero.texture != null

static func stats_text(row: Dictionary) -> String:
	if row.is_empty():
		return ""
	var bits: PackedStringArray = []
	bits.append(str(row.get("name", "")))
	var cat := str(row.get("category", ""))
	if not cat.is_empty():
		bits.append("Category  " + cat)
	if row.get("price") == null:
		bits.append("Price  —")
	elif int(row.price) == 0:
		bits.append("Price  Free")
	else:
		bits.append("Price  %d credits" % int(row.price))
	bits.append("Owned  %s" % str(row.get("owned", 0)))
	var space := int(row.get("space_per_unit", 1))
	if row.get("price") != null and row.get("enabled", false):
		bits.append("Bag space  %s" % ("none (learned)" if space == 0 else str(space) + " carried unit" + ("" if space == 1 else "s")))
	var desc := str(row.get("description", "")).strip_edges()
	if not desc.is_empty():
		bits.append("")
		bits.append(desc)
	return "\n".join(bits)
