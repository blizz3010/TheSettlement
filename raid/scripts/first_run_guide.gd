extends Node
## Queue item 2c (Ori, playtest2): no first-run guidance from the Town Hall to the traders and
## the ship. A three-step objective line in the HUD title row (the title fades, see
## hud_title_fade.gd): 1 visit a plaza trader, 2 walk to the ship pad, 3 open raid selection.
## Progress is a small per-character sidecar next to the character save (like Dan's listings),
## so it shows once per settler. A character that has already returned from a raid skips it.
const NAME := "FirstRunGuide"
const FILE_NAME := "first_run_guide.json"
const STEPS := ["trader", "ship", "board", "done"]
const SHIP_PAD_RADIUS := 7.9
const WELCOME := "Welcome to the settlement. Traders are on the plaza ahead; the ship is east of the plaza, along the stone path."
var world: Node
var label: Label
var step := "trader"
var path := ""
var history: Array = []

static func install(w: Node) -> Node:
	if not is_instance_valid(w): return null
	var existing = w.get_node_or_null(NAME)
	if existing != null: return existing
	var root = w.get("hud_root")
	if not is_instance_valid(root): return null
	var n = load("res://raid/scripts/first_run_guide.gd").new()
	n.name = NAME
	n.world = w
	w.add_child(n)
	n.setup(root)
	return n

static func sidecar_path(character_save_path: String) -> String:
	if character_save_path.is_empty(): return ""
	return character_save_path.get_base_dir().path_join(FILE_NAME)

func setup(root: Control) -> void:
	label = Label.new()
	label.name = "FirstRunObjective"
	label.position = Vector2(32, 26)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("f1d79a"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	path = sidecar_path(str(world.get("character_save_path")))
	step = load_step()
	# Coming back from a raid means the loop is already known.
	# ship_settlement_preview.gd records this before the raid outcome is applied and cleared.
	if step != "done" and world.get_meta("returned_from_raid", false) == true: advance("done", "returned_from_raid")
	if step == "trader" and world.has_method("message"): world.message(WELCOME)
	refresh()

func load_step() -> String:
	if path.is_empty() or not FileAccess.file_exists(path): return "trader"
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and str(parsed.get("step", "")) in STEPS: return str(parsed.step)
	return "trader"

func save() -> bool:
	if path.is_empty(): return false
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify({"version": 1, "step": step}))
	f.close()
	return true

func advance(to: String, why: String) -> void:
	if STEPS.find(to) <= STEPS.find(step): return
	step = to
	history.append({"step": to, "why": why})
	save()
	if to == "done" and why != "returned_from_raid" and world.has_method("message"):
		world.message("First steps done. Deploy to Relay Ridge or Cinder Basin; extraction brings you back to the Town Hall.")
	refresh()

func text_for(s: String) -> String:
	var key := "E"
	if world.has_method("key_label"): key = str(world.key_label("interact"))
	match s:
		"trader": return "NEXT 1/3 • Visit a plaza trader: Psy, Dan or Atlas"
		"ship": return "NEXT 2/3 • Ship: east of the plaza, via the stone path"
		"board": return "NEXT 3/3 • On the ship pad, press %s to pick a raid" % key
	return ""

func title_cleared() -> bool:
	var fade = world.get_node_or_null("HudTitleFade")
	return fade == null or fade.fade_started_ms >= 0 or fade.done

func refresh() -> void:
	if not is_instance_valid(label): return
	label.text = text_for(step)
	label.visible = not label.text.is_empty() and title_cleared() and not world.modal_open()

func trader_open() -> bool:
	var tp = world.get("trader_previews")
	if is_instance_valid(tp) and tp.is_open(): return true
	var ft = world.get("fishing_trader")
	if is_instance_valid(ft) and ft.has_method("is_open") and ft.is_open(): return true
	for field in ["supplies_panel", "clothing_panel"]:
		var panel = world.get(field)
		if is_instance_valid(panel) and panel.visible: return true
	return false

func on_ship_pad() -> bool:
	var ship = world.get_node_or_null("LaunchpadShip")
	var p = world.get("player")
	if ship == null or not is_instance_valid(p): return false
	var local: Vector3 = ship.to_local(p.global_position)
	return Vector2(local.x, local.z).length() < SHIP_PAD_RADIUS and local.y > 1.0

func _process(_delta: float) -> void:
	if world.get("world_activated") != true: return
	if step == "trader" and trader_open(): advance("ship", "trader_opened")
	if step in ["trader", "ship"] and on_ship_pad(): advance("board", "on_ship_pad")
	if step != "done" and is_instance_valid(world.get("ship_selection")): advance("done", "raid_select_opened")
	refresh()
