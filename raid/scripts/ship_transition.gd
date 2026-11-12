extends Node
## Owns only disposable raid state. Settlement was saved and freed before entry.
const Catalog = preload("res://raid/scripts/raid_catalog.gd")
var raid_id := "relay_ridge"
var binding: Dictionary = {}
var raid: Node
var returning := false
var opening := false
var cover: CanvasLayer
var status: Label
var return_button: Button

func _ready():
	cover = CanvasLayer.new()
	cover.layer = 120
	add_child(cover)
	var panel = ColorRect.new()
	panel.color = Color("101b24")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(panel)
	var column = VBoxContainer.new()
	column.position = Vector2(36, 36)
	panel.add_child(column)
	status = Label.new()
	status.text = "Preparing " + Catalog.display_name(raid_id) + " preview…"
	column.add_child(status)
	return_button = Button.new()
	return_button.text = "Cancel / Return to saved settlement"
	return_button.pressed.connect(return_to_settlement)
	column.add_child(return_button)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func open_raid():
	if opening or returning: return
	opening = true
	raid = _create_raid()
	if raid == null:
		_fail("The raid scene is unavailable. Your settlement was saved.")
		return
	if not raid.has_signal("return_requested") or not raid.has_method("is_raid_ready"):
		raid.free()
		raid = null
		_fail("The raid readiness contract is unavailable. Your settlement was saved.")
		return
	raid.return_requested.connect(return_to_settlement)
	add_child(raid)
	var deadline = Time.get_ticks_msec() + 60000
	while is_instance_valid(raid) and not raid.is_raid_ready():
		if returning: return
		if raid.has_method("get_raid_failure") and not raid.get_raid_failure().is_empty():
			var reason:String=raid.get_raid_failure()
			raid.queue_free()
			raid=null
			_fail("Raid preparation stopped: "+reason+" Your settlement was saved.")
			return
		if Time.get_ticks_msec() > deadline:
			raid.queue_free()
			raid = null
			_fail("Raid preparation timed out. Return to the saved settlement.")
			return
		await get_tree().process_frame
	if returning: return
	if not is_instance_valid(raid):
		_fail("Raid preparation was interrupted. Return to the saved settlement.")
		return
	cover.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _create_raid() -> Node:
	var path = Catalog.scene_path(raid_id)
	if path.is_empty() or not ResourceLoader.exists(path): return null
	var packed = load(path)
	return packed.instantiate() if packed is PackedScene else null

func _fail(reason: String):
	status.text = reason
	cover.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func return_to_settlement():
	if returning: return
	returning = true
	# Deferred deletion prevents freeing a node while it is emitting return_requested.
	call_deferred("_restore_title")

func _restore_title():
	if is_instance_valid(raid):
		raid.free()
		raid = null
	var title = load("res://raid/ship_title_preview.tscn").instantiate()
	title.return_binding = binding.duplicate(true)
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	queue_free()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Departure save is already committed; preview loot has no persistence.
		get_tree().quit()
