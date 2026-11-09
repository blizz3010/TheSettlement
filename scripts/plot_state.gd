extends RefCounted
# Deterministic structural model. Walls belong to one support cell; shared edges deduplicate.
const BedGeometry = preload("res://scripts/bed_geometry.gd")
const FurnitureGeometry = preload("res://scripts/furniture_geometry.gd")
const DoorGeometry = preload("res://scripts/door_geometry.gd")
const ROOF_TYPES = ["ceiling","pitched_roof","canvas_awning"]
const WALL_TYPES = ["wall","window_wall","doorframe"]
var expanded := false
var credits := 150
var cells: Array[Vector2i] = []
var walls: Array[Dictionary] = []
var doors: Array[Dictionary] = []
var ceilings: Array[Dictionary] = []
var stairs: Array[Dictionary] = []
var railings: Array[Dictionary] = []
var bed: Dictionary = {}
var workbench: Dictionary = {}
var lanterns: Array[Dictionary] = []
# The unique chest is never an inventory item. Contents remain in InventoryState.stash.
var home_stash: Dictionary = {"id":"HomeStash","location":"starter_external"}
var last_error := ""
func bed_supports(cell: Vector2i) -> bool:
	return not bed.is_empty() and BedGeometry.support_cells(bed.cell,bed.rotation).has(cell)
func rotated_size(size: Vector3, side: int) -> Vector3:
	return size if side % 2 == 0 else Vector3(size.z,size.y,size.x)
func bed_furniture_overlap(bed_cell: Vector2i, bed_side: int, kind: String, record: Dictionary) -> bool:
	var side = int(record.rotation)
	var origin = Vector3(record.cell.x*2,3.18*record.get("level",0),record.cell.y*2)
	if kind == "home_stash":
		origin += Vector3(-0.20,0,0).rotated(Vector3.UP,-side*PI/2)
		return BedGeometry.overlaps_box(bed_cell,bed_side,origin+Vector3(0,0.45,0),rotated_size(Vector3(1.5,0.9,0.85),side))
	if kind == "workbench" and record.get("anchor","front_inset_v1") == "front_inset_v1": origin += Vector3(0,0,-0.10).rotated(Vector3.UP,-side*PI/2)
	for part in FurnitureGeometry.parts(kind):
		if BedGeometry.overlaps_box(bed_cell,bed_side,origin+part.position.rotated(Vector3.UP,-side*PI/2),rotated_size(part.size,side)): return true
	return false
func bed_door_overlap(bed_cell: Vector2i, bed_side: int, cell: Vector2i, side: int, opened: bool) -> bool:
	var basis = Basis(Vector3.UP,-side*PI/2)
	var origin = Vector3(cell.x*2,0,cell.y*2)+Vector3(0,0,-0.8).rotated(Vector3.UP,-side*PI/2)
	var pose = DoorGeometry.pose(opened)
	var center = origin+basis*(pose*DoorGeometry.CENTER)
	return BedGeometry.overlaps_box(bed_cell,bed_side,center,rotated_size(DoorGeometry.SIZE,(side+int(opened))%4))
func bed_error(cell: Vector2i, side: int, level := 0) -> String:
	if not bed.is_empty(): return "Only one starter bed is supported."
	if level != 0 or side < 0 or side > 3 or not allowed(cell): return "Place the bed on your ground floor."
	for support in BedGeometry.support_cells(cell,side):
		if not allowed(support) or not cells.has(support): return "Every part of the bed needs a foundation inside your plot."
		if stair_index(support) >= 0 or upper_reserved(support): return "Keep stairs and their arrival clear."
	for wall in walls:
		if wall.get("level",0) == 0 and BedGeometry.overlaps_wall(cell,side,wall.cell,wall.rotation): return "The bed intersects a wall or doorway."
	for door in doors:
		if door.get("level",0) == 0 and bed_door_overlap(cell,side,door.cell,door.rotation,door.open): return "The bed intersects a door."
	if not workbench.is_empty() and bed_furniture_overlap(cell,side,"workbench",workbench): return "The bed intersects the workbench."
	if home_stash.location == "plot" and bed_furniture_overlap(cell,side,"home_stash",home_stash): return "The bed intersects Home Stash."
	for lamp in lanterns:
		if bed_furniture_overlap(cell,side,"lantern",lamp): return "The bed intersects a lantern."
	return ""
func remove_bed() -> bool:
	if bed.is_empty(): last_error = "No bed."; return false
	bed = {}; last_error = ""; return true
func stash_at(cell: Vector2i, level := 0) -> bool:
	return level == 0 and home_stash.get("location") == "plot" and home_stash.get("cell") == cell
func stash_placement_error(cell: Vector2i, side := 0) -> String:
	if home_stash.get("id") != "HomeStash": return "Invalid Home Stash identity."
	if not allowed(cell) or side < 0 or side > 3: return "Home Stash must stay inside your plot."
	if not cells.has(cell): return "Home Stash needs a ground-floor foundation."
	if not bed.is_empty() and bed_furniture_overlap(bed.cell,bed.rotation,"home_stash",{"cell":cell,"rotation":side}): return "Home Stash intersects the bed."
	# Ignore its own current placement, so rotation and moving within the same cell work.
	if (not workbench.is_empty() and workbench.cell == cell) or lantern_index(cell,0) >= 0: return "This floor cell already has furniture."
	if stair_index(cell) >= 0 or upper_reserved(cell): return "Keep stairs and their arrival clear."
	for edge in range(4):
		var wi = wall_index(cell,edge,0)
		if wi >= 0 and walls[wi].type == "doorframe": return "Keep doorway floor cells clear."
	return ""
func move_stash(cell: Vector2i, side := 0) -> bool:
	last_error = stash_placement_error(cell,side)
	if not last_error.is_empty(): return false
	home_stash = {"id":"HomeStash","location":"plot","cell":cell,"rotation":side,"level":0}
	return true
func furniture_at(cell: Vector2i, level := 0) -> bool:
	return stash_at(cell,level) or (level == 0 and not workbench.is_empty() and workbench.cell == cell) or lantern_index(cell,level) >= 0
func lantern_index(cell: Vector2i, level := 0) -> int:
	for i in range(lanterns.size()):
		if lanterns[i].cell == cell and lanterns[i].level == level: return i
	return -1
func furniture_error(kind: String, cell: Vector2i, side: int, level: int) -> String:
	if not allowed(cell) or side < 0 or side > 3 or level < 0 or level > 1: return "Invalid furniture placement."
	if kind == "workbench" and (level != 0 or not workbench.is_empty()): return "Only one ground-floor workbench is supported."
	if kind not in ["workbench","lantern"]: return "Unknown furniture."
	if level == 0 and not cells.has(cell): return "Furniture needs a foundation."
	if level == 1 and (not deck_at(cell) or not ceiling_supported(cell)): return "Furniture needs a supported deck."
	if furniture_at(cell,level): return "This floor cell already has furniture."
	if not bed.is_empty() and bed_furniture_overlap(bed.cell,bed.rotation,kind,{"cell":cell,"rotation":side,"level":level}): return "Furniture intersects the bed."
	if stair_index(cell) >= 0 or upper_reserved(cell): return "Keep stairs and their arrival clear."
	for edge in range(4):
		var wi = wall_index(cell,edge,level)
		if wi >= 0 and walls[wi].type == "doorframe": return "Keep doorway floor cells clear."
	return ""
func remove_workbench() -> bool:
	if workbench.is_empty(): last_error = "No workbench."; return false
	workbench = {}; last_error = ""; return true
func remove_lantern(cell: Vector2i, level := 0) -> bool:
	var i = lantern_index(cell,level)
	if i < 0: last_error = "No lantern."; return false
	lanterns.remove_at(i); last_error = ""; return true
func set_lantern_on(cell: Vector2i, level: int, lit: bool) -> bool:
	var i = lantern_index(cell,level)
	if i < 0: last_error = "No lantern."; return false
	lanterns[i].on = lit; last_error = ""; return true
func stair_direction(side: int) -> Vector2i:
	return [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)][side] if side >= 0 and side < 4 else Vector2i.ZERO
func stair_cells(cell: Vector2i, side: int) -> Array:
	return [cell,cell+stair_direction(side)]
func stair_landing(cell: Vector2i, side: int) -> Vector2i:
	return cell+stair_direction(side)*2
func stair_index(cell: Vector2i) -> int:
	for i in range(stairs.size()):
		if stair_cells(stairs[i].cell,stairs[i].rotation).has(cell): return i
	return -1
func remove_stair(cell: Vector2i) -> bool:
	var index = stair_index(cell)
	if index < 0: last_error = "No stairs in this cell."; return false
	stairs.remove_at(index)
	last_error = ""
	return true
func stair_error(cell: Vector2i, side: int) -> String:
	var landing = stair_landing(cell,side)
	for c in stair_cells(cell,side)+[landing]:
		if bed_supports(c) or furniture_at(c,0) or furniture_at(c,1): return "Remove furniture before adding stairs here."
	if railing_index(landing,(side+2)%4) >= 0: return "Remove the railing from the stair arrival edge first."
	for c in stair_cells(cell,side):
		if not allowed(c) or not cells.has(c): return "Stairs need two foundations inside your plot."
		if stair_index(c) >= 0: return "Stairs overlap another staircase."
		if ceiling_index(c) >= 0: return "Keep the stair ascent open above."
		for wall in walls:
			if wall.cell == c: return "Remove walls from the stair run first."
		for stair in stairs:
			if stair_landing(stair.cell,stair.rotation) == c: return "Keep the existing stair landing clear."
	if not allowed(landing) or not deck_at(landing): return "Stairs need a supported ceiling landing beyond the run."
	if ceiling_index(landing,1) >= 0: return "Keep the stair landing uncovered."
	for wall in walls:
		if wall.cell == landing and wall.get("level",0) == 1: return "Keep the stair landing uncovered."
	var support_sides = [1,3] if side % 2 == 0 else [0,2]
	for support in support_sides:
		var i = wall_index(landing,support)
		if i < 0 or walls[i].cell != landing: return "Landing needs its own two side walls parallel to the stairs."
	for wall in walls:
		if wall.cell == landing and wall.get("level",0) == 0 and not support_sides.has(wall.rotation): return "Keep the stair arrival edge open."
	return ""
func allowed(cell: Vector2i) -> bool:
	var extent = 4 if expanded else 2
	return cell.x >= -2 and cell.y >= -2 and cell.x < extent and cell.y < extent
func edge_key(cell: Vector2i, side: int) -> String:
	match side:
		0: return "H:%d:%d" % [cell.x,cell.y]
		1: return "V:%d:%d" % [cell.x+1,cell.y]
		2: return "H:%d:%d" % [cell.x,cell.y+1]
		3: return "V:%d:%d" % [cell.x,cell.y]
	return "invalid"
func level_edge_key(cell: Vector2i, side: int, level := 0) -> String:
	return "%d:%s" % [level,edge_key(cell,side)]
func wall_index(cell: Vector2i, side: int, level := 0) -> int:
	var key = level_edge_key(cell,side,level)
	for i in range(walls.size()):
		if level_edge_key(walls[i].cell,walls[i].rotation,walls[i].get("level",0)) == key: return i
	return -1
func railing_index(cell: Vector2i, side: int) -> int:
	var key = edge_key(cell,side)
	for i in range(railings.size()):
		if edge_key(railings[i].cell,railings[i].rotation) == key: return i
	return -1
func railing_error(cell: Vector2i, side: int) -> String:
	if not deck_at(cell) or not ceiling_supported(cell): return "Railings need a supported ceiling."
	if railing_index(cell,side) >= 0: return "This deck edge already has a railing."
	if wall_index(cell,side,1) >= 0: return "Remove the upper wall from this railing edge first."
	if ceiling_index(cell+stair_direction(side)) >= 0: return "Railings belong on exposed deck edges only."
	for stair in stairs:
		if stair_landing(stair.cell,stair.rotation) == cell and side == (stair.rotation+2)%4: return "Keep the stair arrival edge open."
	return ""
func remove_railing(cell: Vector2i, side: int) -> bool:
	var index = railing_index(cell,side)
	if index < 0: last_error = "No railing on this edge."; return false
	railings.remove_at(index)
	last_error = ""
	return true
# Only flat panels are load-bearing decks. Roof choices are terminal covers, never
# paths to an upper floor or additional structural span.
func deck_at(cell: Vector2i) -> bool:
	var i = ceiling_index(cell,0)
	return i >= 0 and ceilings[i].get("roof_kind","ceiling") == "ceiling"
func ceiling_index(cell: Vector2i, level := 0) -> int:
	for i in range(ceilings.size()):
		if ceilings[i].cell == cell and ceilings[i].get("level",0) == level: return i
	return -1
# Conservative prototype span, not a final structural-balance rule.
# A connected panel must be within two cardinal tile edges of an own-wall anchor.
const MAX_CEILING_SPAN := 2
func ceiling_base_supported(cell: Vector2i, excluded_wall_index: int, level: int) -> bool:
	if level == 0: return cells.has(cell)
	return level == 1 and deck_at(cell) and ceiling_supported(cell,excluded_wall_index,0)
func ceiling_wall_anchor(cell: Vector2i, excluded_wall_index: int, level: int) -> bool:
	var sides = [false,false,false,false]
	for i in range(walls.size()):
		if i != excluded_wall_index and walls[i].cell == cell and walls[i].get("level",0) == level:
			sides[walls[i].rotation] = true
	return sides.count(true) >= 2
func ceiling_supported(cell: Vector2i, excluded_wall_index := -1, level := 0) -> bool:
	if level < 0 or level > 1 or not ceiling_base_supported(cell,excluded_wall_index,level): return false
	var queue: Array = [{"cell":cell,"distance":0}]
	var visited: Dictionary = {cell:true}
	while not queue.is_empty():
		var current = queue.pop_front()
		if ceiling_wall_anchor(current.cell,excluded_wall_index,level): return true
		if current.distance >= MAX_CEILING_SPAN: continue
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var neighbor: Vector2i = current.cell+offset
			if visited.has(neighbor) or ceiling_index(neighbor,level)<0: continue
			if ceilings[ceiling_index(neighbor,level)].get("roof_kind","ceiling") != "ceiling": continue
			visited[neighbor]=true
			if ceiling_base_supported(neighbor,excluded_wall_index,level):
				queue.append({"cell":neighbor,"distance":current.distance+1})
	return false
func remove_ceiling(cell: Vector2i, level := 0) -> bool:
	if level == 0 and furniture_at(cell,1): last_error = "Remove furniture before its deck."; return false
	if level == 0:
		for wall in walls:
			if wall.cell == cell and wall.get("level",0) == 1: last_error = "Remove upper walls before their deck."; return false
		if ceiling_index(cell,1) >= 0: last_error = "Remove the upper roof before its deck."; return false
		for railing in railings:
			if railing.cell == cell: last_error = "Remove railings before their ceiling."; return false
		for stair in stairs:
			if stair_landing(stair.cell,stair.rotation) == cell: last_error = "Remove stairs before their landing."; return false
	var index = ceiling_index(cell,level)
	if index < 0: last_error = "No ceiling in this cell at this level."; return false
	var removed = ceilings[index]
	ceilings.remove_at(index)
	for remaining in ceilings:
		if not ceiling_supported(remaining.cell,-1,remaining.get("level",0)):
			ceilings.insert(index,removed)
			last_error = "Remove dependent ceilings first; this panel carries their support."
			return false
	last_error = ""
	return true
func upper_reserved(cell: Vector2i) -> bool:
	for stair in stairs:
		if stair_landing(stair.cell,stair.rotation) == cell or stair_cells(stair.cell,stair.rotation).has(cell): return true
	return false
func placement_error(kind: String, cell: Vector2i, side := 0, level := 0) -> String:
	if not allowed(cell): return "Outside your plot."
	if side < 0 or side > 3: return "Invalid rotation."
	if level < 0 or level > 1: return "Only ground and upper building levels are supported."
	if kind == "bed": return bed_error(cell,side,level)
	if level == 0 and WALL_TYPES.has(kind) and not bed.is_empty() and BedGeometry.overlaps_wall(bed.cell,bed.rotation,cell,side): return "This wall intersects the bed."
	if kind in ["workbench","lantern"]: return furniture_error(kind,cell,side,level)
	# A shared doorway reserves both neighboring floor cells, regardless of edge owner.
	if kind == "doorframe" and (furniture_at(cell,level) or furniture_at(cell+stair_direction(side),level)):
		return "Remove furniture before adding a doorway here."
	if level == 1:
		if kind in ["foundation","stairs","railing"]: return "This piece is available on the ground build level only."
		if upper_reserved(cell): return "Keep the stair run and landing uncovered."
		if not deck_at(cell) or not ceiling_supported(cell): return "Upper pieces need a supported deck tile."
	if kind == "stairs": return stair_error(cell,side)
	if kind == "railing": return railing_error(cell,side)
	if ROOF_TYPES.has(kind) or WALL_TYPES.has(kind):
		if stair_index(cell) >= 0: return "Keep the stair run clear."
		if level == 0 and WALL_TYPES.has(kind):
			for stair in stairs:
				if stair_landing(stair.cell,stair.rotation) == cell and side % 2 == stair.rotation % 2: return "Keep the stair arrival edge open."
	if kind == "foundation":
		return "This cell already has a foundation." if cells.has(cell) else ""
	if ROOF_TYPES.has(kind):
		if level == 0:
			for edge in range(4):
				if railing_index(cell,edge) >= 0: return "Remove the boundary railing before extending this deck."
		if ceiling_index(cell,level) >= 0: return "This cell already has a ceiling at this level."
		if level == 0 and not cells.has(cell): return "Place a foundation first: ceilings need support."
		if not ceiling_supported(cell,-1,level): return "Ceiling needs two own walls or a supported ceiling within two connected tiles."
		return ""
	if kind == "door":
		if level == 0 and not bed.is_empty() and bed_door_overlap(bed.cell,bed.rotation,cell,side,false): return "Door blocked by the bed."
		var index = wall_index(cell,side,level)
		if index < 0 or walls[index].type != "doorframe": return "Aim at an existing doorframe first."
		if door_index(cell,side,level) >= 0: return "This doorframe already has a door."
		return ""
	if not WALL_TYPES.has(kind): return "Unknown building piece."
	if level == 0 and not cells.has(cell): return "Place a foundation first: walls need support."
	if level == 1 and railing_index(cell,side) >= 0: return "Remove the railing from this upper wall edge first."
	if wall_index(cell,side,level) >= 0: return "This edge already has a wall or doorway at this level."
	return ""
func place(cell: Vector2i) -> bool:
	return place_piece("foundation",cell,0)
func place_piece(kind: String, cell: Vector2i, side := 0, level := 0) -> bool:
	last_error = placement_error(kind,cell,side,level)
	if not last_error.is_empty(): return false
	if kind == "bed": bed = {"cell":cell,"rotation":side}
	elif kind == "workbench": workbench = {"cell":cell,"rotation":side,"anchor":"front_inset_v1"}
	elif kind == "lantern": lanterns.append({"cell":cell,"rotation":side,"level":level,"on":true})
	elif kind == "foundation": cells.append(cell)
	elif kind == "railing": railings.append({"cell":cell,"rotation":side})
	elif kind == "stairs": stairs.append({"cell":cell,"rotation":side})
	elif ROOF_TYPES.has(kind):
		var roof = {"cell":cell,"rotation":side,"level":level}
		if kind != "ceiling": roof.roof_kind = kind
		ceilings.append(roof)
	elif kind == "door":
		var frame = walls[wall_index(cell,side,level)]
		doors.append({"cell":frame.cell,"rotation":frame.rotation,"open":false,"level":level})
	else: walls.append({"type":kind,"cell":cell,"rotation":side,"level":level})
	return true
func remove(cell: Vector2i) -> bool:
	last_error = ""
	if bed_supports(cell): last_error = "Remove the bed before its supporting foundations."; return false
	if furniture_at(cell,0): last_error = "Remove furniture before its foundation."; return false
	if stair_index(cell) >= 0: last_error = "Remove stairs before their foundations."; return false
	if not cells.has(cell): last_error = "No foundation in this cell."; return false
	if ceiling_index(cell) >= 0: last_error = "Remove the ceiling before its foundation."; return false
	for wall in walls:
		if wall.cell == cell:
			last_error = "Remove attached walls first; foundation removal is blocked."
			return false
	cells.erase(cell)
	return true
func remove_wall(cell: Vector2i, side: int, level := 0) -> bool:
	var index = wall_index(cell,side,level)
	if index < 0: last_error = "No wall on this edge."; return false
	if door_index(cell,side,level) >= 0: last_error = "Remove the attached door before its frame."; return false
	for ceiling in ceilings:
		if not ceiling_supported(ceiling.cell,index,ceiling.get("level",0)):
			last_error = "Remove the ceiling first; this wall supports it."
			return false
	walls.remove_at(index)
	last_error = ""
	return true
func door_index(cell: Vector2i, side: int, level := 0) -> int:
	var key = level_edge_key(cell,side,level)
	for i in range(doors.size()):
		if level_edge_key(doors[i].cell,doors[i].rotation,doors[i].get("level",0)) == key: return i
	return -1
func remove_door(cell: Vector2i, side: int, level := 0) -> bool:
	var index = door_index(cell,side,level)
	if index < 0: last_error = "No door on this edge."; return false
	doors.remove_at(index)
	last_error = ""
	return true
func set_door_open(cell: Vector2i, side: int, opened: bool, level := 0) -> bool:
	var index = door_index(cell,side,level)
	if index < 0: last_error = "No door on this edge."; return false
	if level == 0 and not bed.is_empty() and bed_door_overlap(bed.cell,bed.rotation,cell,side,opened): last_error = "Door blocked by the bed."; return false
	doors[index].open = opened
	last_error = ""
	return true
func upgrade() -> bool:
	if expanded or credits < 100: return false
	credits -= 100
	expanded = true
	return true
func data() -> Dictionary:
	var pieces: Array = []
	for c in cells: pieces.append({"type":"foundation","cell":[c.x,c.y],"rotation":0})
	for wall in walls: pieces.append({"type":wall.type,"cell":[wall.cell.x,wall.cell.y],"rotation":wall.rotation,"level":wall.get("level",0)})
	var saved_doors: Array = []
	for door in doors: saved_doors.append({"cell":[door.cell.x,door.cell.y],"rotation":door.rotation,"open":door.open,"level":door.get("level",0)})
	var saved_ceilings: Array = []
	for ceiling in ceilings:
		var roof = {"cell":[ceiling.cell.x,ceiling.cell.y],"rotation":ceiling.rotation,"level":ceiling.get("level",0)}
		if ceiling.has("roof_kind"): roof.roof_kind = ceiling.roof_kind
		saved_ceilings.append(roof)
	var saved_stairs: Array = []
	for stair in stairs: saved_stairs.append({"cell":[stair.cell.x,stair.cell.y],"rotation":stair.rotation})
	var saved_railings: Array = []
	for railing in railings: saved_railings.append({"cell":[railing.cell.x,railing.cell.y],"rotation":railing.rotation})
	var saved_bench = {} if workbench.is_empty() else {"cell":[workbench.cell.x,workbench.cell.y],"rotation":workbench.rotation,"anchor":workbench.get("anchor","")}
	var saved_lanterns: Array = []
	for lamp in lanterns: saved_lanterns.append({"cell":[lamp.cell.x,lamp.cell.y],"rotation":lamp.rotation,"level":lamp.level,"on":lamp.on})
	var saved_stash = home_stash.duplicate(true)
	if saved_stash.get("location") == "plot": saved_stash.cell = [home_stash.cell.x,home_stash.cell.y]
	var saved_bed = {} if bed.is_empty() else {"cell":[bed.cell.x,bed.cell.y],"rotation":bed.rotation}
	return {"version":12,"bed":saved_bed,"home_stash":saved_stash,"workbench":saved_bench,"lanterns":saved_lanterns,"expanded":expanded,"credits":credits,"pieces":pieces,"doors":saved_doors,"ceilings":saved_ceilings,"stairs":saved_stairs,"railings":saved_railings}
func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value)
func parse_cell(item: Variant) -> Variant:
	if not item is Array or item.size() != 2: return null
	if not integer(item[0]) or not integer(item[1]): return null
	if abs(item[0]) > 100 or abs(item[1]) > 100: return null
	return Vector2i(int(item[0]),int(item[1]))
func record_level(record: Dictionary, version: int) -> int:
	if version < 7: return -1 if record.has("level") else 0
	var value = record.get("level")
	return int(value) if integer(value) and value >= 0 and value <= 1 else -1
func restore(value: Variant) -> bool:
	if not value is Dictionary: return false
	if not integer(value.get("version")) or not int(value.version) in [1,2,3,4,5,6,7,8,9,10,11,12]: return false
	var version = int(value.version)
	if not value.get("expanded") is bool or not integer(value.get("credits")): return false
	if value.credits < 0 or value.credits > 100000: return false
	if not value.get("pieces") is Array or value.pieces.size() > (324 if version >= 7 else 200): return false
	if version < 3 and value.has("doors"): return false
	if version >= 3 and (not value.get("doors") is Array or value.doors.size() > (288 if version >= 7 else 144)): return false
	if version < 4 and value.has("ceilings"): return false
	if version >= 4 and (not value.get("ceilings") is Array or value.ceilings.size() > (72 if version >= 7 else 36)): return false
	if version < 5 and value.has("stairs"): return false
	if version >= 5 and (not value.get("stairs") is Array or value.stairs.size() > 18): return false
	if version < 6 and value.has("railings"): return false
	if version >= 6 and (not value.get("railings") is Array or value.railings.size() > 144): return false
	if version < 8 and (value.has("workbench") or value.has("lanterns")): return false
	if version < 9 and value.has("home_stash"): return false
	if version < 11 and value.has("bed"): return false
	if version >= 8:
		if value.size() != (12 if version >= 11 else 11 if version >= 9 else 10) or not value.get("workbench") is Dictionary or not value.get("lanterns") is Array or value.lanterns.size() > 72: return false
	var candidate = get_script().new()
	candidate.expanded = value.expanded
	candidate.credits = int(value.credits)
	var pending_walls: Array = []
	var pending_doors: Array = []
	var pending_ceilings: Array = []
	for item in value.pieces:
		if version == 1:
			var cell = parse_cell(item)
			if cell == null or not candidate.place(cell): return false
		else:
			if not item is Dictionary: return false
			var cell = parse_cell(item.get("cell"))
			var kind = item.get("type")
			var side = item.get("rotation",0)
			if cell == null or not kind is String or not integer(side) or side < 0 or side > 3: return false
			if kind == "foundation":
				if item.has("level") or (version >= 7 and item.size() != 3) or side != 0 or not candidate.place(cell): return false
			elif WALL_TYPES.has(kind):
				var level = record_level(item,version)
				if level < 0 or (version >= 7 and item.size() != 4): return false
				pending_walls.append({"type":kind,"cell":cell,"rotation":int(side),"level":level})
			else: return false
	if version >= 3:
		for door in value.doors:
			if not door is Dictionary or not door.get("open") is bool: return false
			var cell = parse_cell(door.get("cell"))
			var side = door.get("rotation")
			var level = record_level(door,version)
			if cell == null or not integer(side) or side < 0 or side > 3 or level < 0 or (version >= 7 and door.size() != 4): return false
			pending_doors.append({"cell":cell,"rotation":int(side),"level":level,"open":door.open})
	if version >= 4:
		for ceiling in value.ceilings:
			if not ceiling is Dictionary: return false
			var roof_kind = ceiling.get("roof_kind","ceiling")
			if not roof_kind is String or not ROOF_TYPES.has(roof_kind): return false
			if ceiling.has("roof_kind") and (version < 12 or roof_kind == "ceiling"): return false
			if ceiling.size() != ((4 if ceiling.has("roof_kind") else 3) if version >= 7 else 2): return false
			var cell = parse_cell(ceiling.get("cell"))
			var side = ceiling.get("rotation")
			var level = record_level(ceiling,version)
			if cell == null or not integer(side) or side < 0 or side > 3 or level < 0: return false
			var roof = {"cell":cell,"rotation":int(side),"level":level}
			if ceiling.has("roof_kind"): roof.roof_kind = roof_kind
			pending_ceilings.append(roof)
	# Ground supports first, then stairs/railings, then upper rooms. Serialized order is irrelevant.
	for level in [0,1]:
		if level == 1:
			if version >= 5:
				for stair in value.stairs:
					if not stair is Dictionary or stair.size() != 2: return false
					var cell = parse_cell(stair.get("cell")); var side = stair.get("rotation")
					if cell == null or not integer(side) or side < 0 or side > 3 or not candidate.place_piece("stairs",cell,int(side)): return false
			if version >= 6:
				for railing in value.railings:
					if not railing is Dictionary or railing.size() != 2: return false
					var cell = parse_cell(railing.get("cell")); var side = railing.get("rotation")
					if cell == null or not integer(side) or side < 0 or side > 3 or not candidate.place_piece("railing",cell,int(side)): return false
		for wall in pending_walls:
			if wall.level == level and not candidate.place_piece(wall.type,wall.cell,wall.rotation,level): return false
		for door in pending_doors:
			if door.level != level: continue
			if not candidate.place_piece("door",door.cell,door.rotation,level): return false
			candidate.set_door_open(door.cell,door.rotation,door.open,level)
		# Resolve anchors before dependents, independent of serialized array order.
		var unresolved: Array = []
		for ceiling in pending_ceilings:
			if ceiling.level == level: unresolved.append(ceiling)
		while not unresolved.is_empty():
			var progress := false
			for i in range(unresolved.size()-1,-1,-1):
				var ceiling = unresolved[i]
				if candidate.place_piece(ceiling.get("roof_kind","ceiling"),ceiling.cell,ceiling.rotation,level):
					unresolved.remove_at(i)
					progress = true
			if not progress: return false
	# Preserve the input record order after graph validation, avoiding save churn.
	candidate.ceilings.assign(pending_ceilings)
	if version >= 8:
		var bench = value.workbench
		if not bench.is_empty():
			if bench.size() != (3 if version >= 10 else 2): return false
			if version >= 10 and (not bench.get("anchor") is String or not bench.anchor in ["legacy_center","front_inset_v1"]): return false
			var bc = parse_cell(bench.get("cell")); var br = bench.get("rotation")
			if bc == null or not integer(br) or br < 0 or br > 3 or not candidate.place_piece("workbench",bc,int(br),0): return false
			candidate.workbench.anchor = bench.anchor if version >= 10 else "legacy_center"
		for lamp in value.lanterns:
			if not lamp is Dictionary or lamp.size() != 4 or not lamp.get("on") is bool: return false
			var lc = parse_cell(lamp.get("cell")); var lr = lamp.get("rotation"); var ll = lamp.get("level")
			if lc == null or not integer(lr) or lr < 0 or lr > 3 or not integer(ll) or ll < 0 or ll > 1 or not candidate.place_piece("lantern",lc,int(lr),int(ll)): return false
			candidate.set_lantern_on(lc,int(ll),lamp.on)
	if version >= 9:
		var stash = value.get("home_stash")
		if not stash is Dictionary or stash.get("id") != "HomeStash": return false
		if stash.get("location") == "starter_external":
			if stash.size() != 2: return false
		elif stash.get("location") == "plot":
			if stash.size() != 5 or not integer(stash.get("level")) or stash.level != 0: return false
			var sc = parse_cell(stash.get("cell")); var sr = stash.get("rotation")
			if sc == null or not integer(sr) or sr < 0 or sr > 3 or not candidate.move_stash(sc,int(sr)): return false
		else: return false
	if version >= 11:
		var saved_bed = value.get("bed")
		if not saved_bed is Dictionary: return false
		if not saved_bed.is_empty():
			if saved_bed.size() != 2: return false
			var bc = parse_cell(saved_bed.get("cell")); var br = saved_bed.get("rotation")
			if bc == null or not integer(br) or br < 0 or br > 3 or not candidate.place_piece("bed",bc,int(br),0): return false
	bed = candidate.bed.duplicate(true)
	home_stash = candidate.home_stash.duplicate(true)
	expanded = candidate.expanded
	credits = candidate.credits
	cells.assign(candidate.cells); walls.assign(candidate.walls); doors.assign(candidate.doors)
	ceilings.assign(candidate.ceilings); stairs.assign(candidate.stairs); railings.assign(candidate.railings)
	workbench = candidate.workbench.duplicate(true); lanterns.assign(candidate.lanterns)
	last_error = ""
	return true
