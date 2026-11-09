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

# Read-only journal diagnosis, never used as placement or unlock authority.
# Choose the most complete existing 2x2 anchor; keep deterministic tie ordering.
func home_checklist(plot) -> String:
	var anchors:Array=plot.cells.duplicate()
	anchors.sort_custom(func(a,b):return a.x<b.x or (a.x==b.x and a.y<b.y))
	if anchors.is_empty():return "Start with four connected foundation cells in a 2×2 square."
	var best:Dictionary={};var best_score=-2147483648
	for anchor in anchors:
		var footprint=cells_for_anchor(anchor)
		var foundations=0;var roofs=0;var walls=0;var doors=0;var obstructions=0
		for cell in footprint:
			if plot.allowed(cell) and plot.cells.has(cell):foundations+=1
			if plot.ceiling_index(cell,0)>=0 and plot.ceiling_supported(cell,-1,0):roofs+=1
			if plot.stair_index(cell)>=0 or plot.upper_reserved(cell):obstructions+=1
			for side in range(4):
				var wi=plot.wall_index(cell,side,0)
				if footprint.has(cell+plot.stair_direction(side)):
					if wi>=0:obstructions+=1
				elif wi>=0 and plot.walls[wi].type in ["wall","window_wall","doorframe"]:
					if plot.walls[wi].type!="doorframe" or plot.door_index(cell,side,0)>=0:walls+=1
					if plot.walls[wi].type=="doorframe" and plot.door_index(cell,side,0)>=0:doors+=1
		var score=foundations+roofs+walls+mini(doors,1)-obstructions
		if score>best_score:
			best_score=score;best={"anchor":anchor,"foundations":foundations,"roofs":roofs,"walls":walls,"doors":doors,"obstructions":obstructions}
	var a:Vector2i=best.anchor
	var lines=PackedStringArray(["Closest 2×2 at plot cell (%d, %d):"%[a.x,a.y],"Foundations: %d / 4 • Supported roof cells: %d / 4"%[best.foundations,best.roofs],"Closed outside edges: %d / 8 • Installed door: %s"%[best.walls,"yes" if best.doors>0 else "needed"]])
	lines.append("Interior clear: yes" if best.obstructions==0 else "Remove interior partitions/stairs or upper-floor reservations from this 2×2.")
	if valid_house_at(plot,a):lines.append("This footprint meets the house checks. Visit Home Stash for the MOVE step.")
	return "\n".join(lines)
