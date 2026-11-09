extends RefCounted
# Pure progression model. Caller commits a full save candidate before publishing it.
# This model never grants items, spends materials, or edits Plot/Inventory.
const STATUSES = ["house_pending","move_active","completed"]
const HOME_STEPS = ["bench_pending","bed_pending","complete"]
const CLOTHING_STEPS = ["available","talk_dan","claim_pending","dye_active","complete"]
var clothing_step := "available"
var home_step := "bench_pending"
var status := "house_pending"
func data() -> Dictionary:
	return {"version":3,"clothing_step":clothing_step,"status":status,"home_step":home_step}
func restore(value: Variant) -> bool:
	if not value is Dictionary: return false
	var version = value.get("version")
	if not (version is int or version is float) or not is_finite(float(version)) or (version != 1 and version != 2 and version != 3): return false
	if value.size() != (2 if version == 1 else (3 if version == 2 else 4)): return false
	if not value.get("status") is String or not value.status in STATUSES: return false
	var step = "bench_pending" if version == 1 else value.get("home_step")
	if not step is String or not step in HOME_STEPS: return false
	if value.status != "completed" and step != "bench_pending": return false
	var next_clothing = value.get("clothing_step") if version == 3 else "available"
	if not next_clothing is String or not next_clothing in CLOTHING_STEPS: return false
	clothing_step = next_clothing
	status = value.status
	home_step = step
	return true
func cells_for_anchor(anchor: Vector2i) -> Array[Vector2i]:
	return [anchor,anchor+Vector2i(1,0),anchor+Vector2i(0,1),anchor+Vector2i(1,1)]
func valid_house_at(plot, anchor: Vector2i) -> bool:
	var footprint = cells_for_anchor(anchor)
	var has_door := false
	for cell in footprint:
		if not plot.allowed(cell) or not plot.cells.has(cell): return false
		if plot.ceiling_index(cell,0) < 0 or not plot.ceiling_supported(cell,-1,0): return false
		if plot.stair_index(cell) >= 0 or plot.upper_reserved(cell): return false
		for side in range(4):
			var wi = plot.wall_index(cell,side,0)
			if footprint.has(cell+plot.stair_direction(side)):
				# Any internal wall/window/doorframe partitions the starter room.
				if wi >= 0: return false
			else:
				if wi < 0 or not plot.walls[wi].type in ["wall","window_wall","doorframe"]: return false
				if plot.walls[wi].type == "doorframe":
					if plot.door_index(cell,side,0) < 0: return false
					has_door = true
	return has_door
func valid_footprints(plot) -> Array:
	# Scan only existing foundation anchors; sorting makes input/save order irrelevant.
	var anchors: Array = plot.cells.duplicate()
	anchors.sort_custom(func(a,b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	var footprints: Array = []
	for anchor in anchors:
		if valid_house_at(plot,anchor): footprints.append(cells_for_anchor(anchor))
	return footprints
func footprint_for_cell(plot, cell: Vector2i) -> Array:
	for footprint in valid_footprints(plot):
		if footprint.has(cell): return footprint
	return []
func refresh(plot) -> bool:
	var before = data()
	if status == "house_pending" and not valid_footprints(plot).is_empty(): status = "move_active"
	if status == "completed":
		if home_step == "bench_pending" and not plot.workbench.is_empty() and plot.allowed(plot.workbench.cell) and plot.cells.has(plot.workbench.cell): home_step = "bed_pending"
		if home_step == "bed_pending" and not plot.bed.is_empty(): home_step = "complete"
	return data() != before
func move_permission(plot) -> bool:
	return status == "completed" or (status == "move_active" and not valid_footprints(plot).is_empty())
func destination_allowed(plot, cell: Vector2i) -> bool:
	# Completed is an unlock, not permission to bypass Plot placement/physics checks.
	return status == "completed" or (move_permission(plot) and not footprint_for_cell(plot,cell).is_empty())
func completion_candidate(plot, source_record: Dictionary):
	if status != "move_active" or not move_permission(plot): return null
	if source_record != {"id":"HomeStash","location":"starter_external"}: return null
	var chest = plot.home_stash
	if chest.size() != 5 or not chest.get("level") is int: return null
	if chest.get("id") != "HomeStash" or chest.get("location") != "plot" or chest.get("level") != 0: return null
	if not chest.get("cell") is Vector2i or not chest.get("rotation") is int: return null
	if not destination_allowed(plot,chest.cell) or not plot.stash_placement_error(chest.cell,chest.rotation).is_empty(): return null
	var candidate = get_script().new()
	if not candidate.restore(data()): return null
	candidate.status = "completed"
	candidate.refresh(plot)
	return candidate
