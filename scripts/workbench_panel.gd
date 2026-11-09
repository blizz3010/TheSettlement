extends PanelContainer
const MenuTheme = preload("res://scripts/shop_theme.gd")
const CraftingService = preload("res://scripts/crafting_service.gd")
signal action_requested(action: String)
signal closed
var summary: Label
var feedback: Label
var ingredients: Label
var stage: Label
var guidance: Label
var progress: ProgressBar
var content_scroll: ScrollContainer
var review_button: Button
var confirm_button: Button
var cancel_button: Button
var claim_button: Button
var retry_button: Button
var close_button: Button
var last_view := ""

func fit_panel():
	var viewport_size = get_viewport().get_visible_rect().size
	var width = minf(580, viewport_size.x - 24)
	var height = minf(510, viewport_size.y - 24)
	offset_left = -width / 2
	offset_right = width / 2
	offset_top = -height / 2
	offset_bottom = height / 2

func label(parent: Node, font_size := 16) -> Label:
	var result = Label.new()
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", font_size)
	parent.add_child(result)
	return result

func _ready():
	theme = MenuTheme.make_theme()
	theme.default_font_size = 16
	set_anchors_preset(Control.PRESET_CENTER)
	fit_panel()
	get_viewport().size_changed.connect(fit_panel)
	add_theme_stylebox_override("panel", MenuTheme.frame("182622", "a28b60", 18))
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var title = label(column, 22)
	title.text = "WORKBENCH / Warm lantern"
	title.add_theme_font_override("font", MenuTheme.heading_font())
	stage = label(column, 18)
	stage.add_theme_color_override("font_color", Color("d9bd87"))
	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(content_scroll)
	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	content_scroll.add_child(body)
	summary = label(body)
	ingredients = label(body)
	progress = ProgressBar.new()
	progress.max_value = CraftingService.CRAFT_SECONDS
	progress.show_percentage = false
	progress.custom_minimum_size.y = 12
	body.add_child(progress)
	guidance = label(body)
	feedback = label(body, 14)
	feedback.add_theme_color_override("font_color", Color("d9bd87"))
	review_button = button(column, "Review recipe", "review")
	confirm_button = button(column, "Confirm craft", "start")
	cancel_button = button(column, "Back to recipe", "cancel")
	claim_button = button(column, "Claim 1 lantern kit", "claim")
	retry_button = button(column, "Retry paused save", "retry")
	close_button = Button.new()
	close_button.text = "Return to settlement"
	close_button.custom_minimum_size.y = 34
	close_button.tooltip_text = "Esc also closes. Closing a review does not consume materials."
	close_button.pressed.connect(func(): closed.emit())
	column.add_child(close_button)
	hide()

func button(parent: Node, title: String, action: String) -> Button:
	var result = Button.new()
	result.text = title
	result.custom_minimum_size.y = 34
	result.pressed.connect(func(): action_requested.emit(action))
	parent.add_child(result)
	return result

func ingredient_line(inventory, item: String, title: String) -> String:
	var required = int(CraftingService.LANTERN_COST[item])
	var carried = int(inventory.amount("carried", item))
	var missing = maxi(0, required - carried)
	return "%s: %d carried / %d needed  |  %s" % [title, carried, required, "Ready" if missing == 0 else "Need %d more" % missing]

func render(craft, inventory, pending: bool, paused: bool, status := ""):
	var data = craft.data()
	var phase = String(data.get("status", data.get("phase", "idle")))
	var seconds = int(data.get("remaining", data.get("remaining_seconds", 0)))
	var used = int(inventory.used("carried"))
	var capacity = int(inventory.capacity("carried"))
	var has_materials = true
	for item in CraftingService.LANTERN_COST:
		if inventory.amount("carried", item) < CraftingService.LANTERN_COST[item]: has_materials = false
	var reviewing = pending and phase == "idle"
	var save_paused = paused and phase == "working"
	var full = used >= capacity
	var cost = "%d Timber + %d Metal scrap" % [CraftingService.LANTERN_COST.timber, CraftingService.LANTERN_COST.metal]
	summary.text = "Makes 1 lantern kit for supported ground or upper floors.\n%d active-play seconds. No offline progress.\nCarried inventory: %d/%d units" % [CraftingService.CRAFT_SECONDS, used, capacity]
	ingredients.visible = phase == "idle"
	ingredients.text = ingredient_line(inventory, "timber", "Timber") + "\n" + ingredient_line(inventory, "metal", "Metal scrap")
	progress.visible = phase in ["working", "ready"]
	progress.value = CraftingService.CRAFT_SECONDS - seconds
	progress.tooltip_text = "%d of %d active-play seconds saved" % [CraftingService.CRAFT_SECONDS - seconds, CraftingService.CRAFT_SECONDS]
	if phase == "ready":
		stage.text = "READY / Make room to claim" if full else "READY / Lantern kit finished"
		guidance.text = "Your finished kit stays at this workbench. Return to settlement and free at least 1 carried unit, for example by storing a material in Home Stash, then come back to claim." if full else "Claim adds 1 lantern kit to carried inventory. Then return to settlement and place it using the build menu."
	elif save_paused:
		stage.text = "SAVE PAUSED / %d seconds remaining" % seconds
		guidance.text = "Progress stopped because a save failed. Retry paused save to save the next second and resume. Your last saved job is kept; no extra ingredients are charged."
	elif phase == "working":
		stage.text = "WORKING / %d seconds remaining" % seconds
		guidance.text = "Committed cost: %s. You can return to settlement while it crafts. Come back here to claim the finished kit." % cost
	elif reviewing:
		stage.text = "REVIEW / Confirm the cost"
		guidance.text = "Confirm consumes %s from carried inventory when the craft is saved. The job then runs for %d active-play seconds. Back or Return leaves materials untouched." % [cost, CraftingService.CRAFT_SECONDS]
	else:
		stage.text = "RECIPE / Ready to review" if has_materials else "RECIPE / Ingredients needed"
		guidance.text = "Review the cost before starting. Only carried ingredients are used." if has_materials else "Carry the missing ingredients, then return to the front of this workbench. Materials in Home Stash must be withdrawn first."
	feedback.text = status
	feedback.visible = not status.is_empty()
	review_button.visible = phase == "idle" and not reviewing
	review_button.disabled = not has_materials
	review_button.tooltip_text = "Review the carried ingredients before committing." if has_materials else "Carry the missing ingredients shown above."
	confirm_button.visible = reviewing
	confirm_button.disabled = not has_materials
	cancel_button.visible = reviewing
	claim_button.visible = phase == "ready"
	claim_button.disabled = full
	claim_button.tooltip_text = "Free 1 carried unit first. The kit stays here." if full else "Save and add the finished kit to carried inventory."
	retry_button.visible = save_paused
	# Seconds and feedback deliberately do not alter focus during a running job.
	var view = "%s:%s:%s:%s:%s" % [phase, reviewing, save_paused, full, has_materials]
	var focus = get_viewport().gui_get_focus_owner()
	var focus_invalid = focus != null and is_ancestor_of(focus) and (not focus.is_visible_in_tree() or (focus is Button and focus.disabled))
	if is_visible_in_tree() and (view != last_view or focus_invalid):
		var target = close_button
		if reviewing: target = cancel_button
		elif save_paused: target = retry_button
		elif phase == "ready" and not full: target = claim_button
		elif phase == "idle" and has_materials: target = review_button
		target.grab_focus()
		if view != last_view: content_scroll.scroll_vertical = 0
	last_view = view
