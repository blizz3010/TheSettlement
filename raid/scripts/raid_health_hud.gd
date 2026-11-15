extends Control
## Raid health HUD: bar + value bound to player vitals, red hit flash, damage number,
## low-health tint. Mirrors the settlement HUD bar colours (settlement_hud.gd).
const FILL := Color("65b49f")
const FILL_LOW := Color("c9734f")
const TRACK := Color("182a28")
const FLASH_SECONDS := 0.45
var bar: ProgressBar
var value_label: Label
var flash: ColorRect
var hit_label: Label
var fill_style: StyleBoxFlat
var flash_left := 0.0
var hit_left := 0.0
var shown_current := 100.0
var shown_maximum := 100.0
var flashes := 0

func _init():
	name = "RaidHealthHud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash = ColorRect.new()
	flash.name = "HitFlash"
	flash.color = Color(0.85, 0.12, 0.08, 0.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var panel := PanelContainer.new()
	panel.name = "HealthPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(24, -112)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.06, 0.1, 0.11, 0.72)
	back.set_corner_radius_all(6)
	back.content_margin_left = 12; back.content_margin_right = 12; back.content_margin_top = 8; back.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", back)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var caption := Label.new()
	caption.text = "HEALTH"
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_color_override("font_color", Color("cfe3da"))
	row.add_child(caption)
	bar = ProgressBar.new()
	bar.name = "HealthBar"
	bar.custom_minimum_size = Vector2(220, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	fill_style = StyleBoxFlat.new()
	fill_style.bg_color = FILL
	fill_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill_style)
	var track := StyleBoxFlat.new()
	track.bg_color = TRACK
	track.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", track)
	row.add_child(bar)
	value_label = Label.new()
	value_label.name = "HealthValue"
	value_label.custom_minimum_size.x = 76
	value_label.add_theme_font_size_override("font_size", 15)
	row.add_child(value_label)
	hit_label = Label.new()
	hit_label.name = "HitNumber"
	hit_label.add_theme_font_size_override("font_size", 22)
	hit_label.add_theme_color_override("font_color", Color("ff8a6a"))
	hit_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hit_label.add_theme_constant_override("outline_size", 4)
	hit_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hit_label.position = Vector2(400, -146)
	hit_label.modulate.a = 0.0
	add_child(hit_label)
	update_values(100.0, 100.0)

func bind(health: Node) -> void:
	health.vitals.changed.connect(update_values)
	health.damaged.connect(on_damaged)
	update_values(health.vitals.current, health.vitals.maximum)

func update_values(current: float, maximum: float) -> void:
	shown_current = current
	shown_maximum = maximum
	bar.max_value = maximum
	bar.value = current
	value_label.text = "%d / %d" % [ceili(current), roundi(maximum)]
	fill_style.bg_color = FILL_LOW if maximum > 0 and current / maximum <= 0.3 else FILL

func on_damaged(amount: float, _source: String, _current: float) -> void:
	flashes += 1
	flash_left = FLASH_SECONDS
	hit_left = 0.9
	hit_label.text = "-%d" % ceili(amount)
	_apply(0.0)

func _process(delta: float) -> void:
	if flash_left <= 0.0 and hit_left <= 0.0: return
	_apply(delta)

func _apply(delta: float) -> void:
	flash_left = maxf(0.0, flash_left - delta)
	hit_left = maxf(0.0, hit_left - delta)
	flash.color.a = 0.32 * (flash_left / FLASH_SECONDS)
	hit_label.modulate.a = clampf(hit_left / 0.5, 0.0, 1.0)
	hit_label.position.y = -146 - (0.9 - hit_left) * 30.0
