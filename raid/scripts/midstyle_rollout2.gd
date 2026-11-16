extends RefCounted
## Item 12 rollout 2: mid-to-high poly remodels of the launchpad ship (#6) and the
## plaza request board (#16). Built by tools/blender_midstyle/build_rollout2.py into
## assets/midstyle_rollout2. Render-only runtime swap: pinned launchpad_ship.glb,
## its import/scn, collision_geometry.json, launchpad_ship.gd, settlement.gd and
## home_request_signage.gd are not edited. Safe to call twice.
## The ship settlement (ship_settlement_preview.gd) turns this on with midstyle_swap
## / midstyle_rollout; that settlement is the world of the normal game start.
static var enabled := false
const DIR := "res://assets/midstyle_rollout2/"
const HULL := DIR + "launchpad_hull.gltf"
const PAD := DIR + "launchpad_pad.gltf"
const BOARD := DIR + "request_board.gltf"

static func apply(world: Node3D) -> Dictionary:
	var result := {"ok": true, "ship": {}, "board": {}}
	if not enabled:
		result["ok"] = false
		result["reason"] = "disabled"
		world.set_meta("midstyle_rollout2", result)
		return result
	result.ship = _swap_ship(world)
	result.board = _swap_board(world)
	result.ok = result.ship.get("ok", false) and result.board.get("ok", false)
	world.set_meta("midstyle_rollout2", result)
	return result

static func _triangles(root: Node) -> int:
	var total := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null: continue
		for s in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(s)
			if arrays[Mesh.ARRAY_INDEX] != null:
				total += arrays[Mesh.ARRAY_INDEX].size() / 3
			elif arrays[Mesh.ARRAY_VERTEX] != null:
				total += arrays[Mesh.ARRAY_VERTEX].size() / 3
	return total

static func _swap_ship(world: Node3D) -> Dictionary:
	var ship := world.get_node_or_null("LaunchpadShip") as Node3D
	if ship == null:
		return {"ok": false, "reason": "LaunchpadShip missing"}
	if ship.has_node("MidstyleLaunchpadHull") and ship.has_node("MidstyleLaunchpadPad"):
		return {"ok": true, "already": true, "triangles": _triangles(ship.get_node("MidstyleLaunchpadHull")) + _triangles(ship.get_node("MidstyleLaunchpadPad"))}
	if not ResourceLoader.exists(HULL) or not ResourceLoader.exists(PAD):
		return {"ok": false, "reason": "missing hull or pad glTF"}
	var runtime := ship.find_child("LaunchpadShip_Runtime", true, false) as MeshInstance3D
	if runtime != null:
		runtime.visible = false
		runtime.set_meta("midstyle_replaced", true)
	var pad_packed := load(PAD) as PackedScene
	var hull_packed := load(HULL) as PackedScene
	if pad_packed == null or hull_packed == null:
		return {"ok": false, "reason": "pad/hull failed to load"}
	var pad := pad_packed.instantiate() as Node3D
	pad.name = "MidstyleLaunchpadPad"
	ship.add_child(pad)
	var hull := hull_packed.instantiate() as Node3D
	hull.name = "MidstyleLaunchpadHull"
	ship.add_child(hull)
	return {"ok": true, "triangles": _triangles(pad) + _triangles(hull), "pad_triangles": _triangles(pad), "hull_triangles": _triangles(hull), "hidden_runtime": runtime != null}

static func _hide_meshes(root: Node, hidden: Array) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or not mesh.visible:
			continue
		if str(mesh.name).begins_with("Midstyle"):
			continue
		mesh.visible = false
		mesh.set_meta("midstyle_replaced", true)
		hidden.append(str(root.get_path_to(mesh)))

static func _swap_board(world: Node3D) -> Dictionary:
	var board := world.get_node_or_null("RequestBoard") as Node3D
	if board == null:
		return {"ok": false, "reason": "RequestBoard missing"}
	if board.has_node("MidstyleRequestBoard"):
		return {"ok": true, "already": true, "triangles": _triangles(board.get_node("MidstyleRequestBoard"))}
	if not ResourceLoader.exists(BOARD):
		return {"ok": false, "reason": "missing request_board.gltf"}
	# home_request_signage looks for the original 1.8 x 1.5 x 0.15 backing box. We only
	# run after that script, and we hide meshes (not the collider siblings).
	var hidden: Array = []
	_hide_meshes(board, hidden)
	# The "REQUEST BOARD" Label3D is already hidden by signage; leave labels alone otherwise.
	var packed := load(BOARD) as PackedScene
	if packed == null:
		return {"ok": false, "reason": "request board failed to load", "hidden": hidden}
	var art := packed.instantiate() as Node3D
	art.name = "MidstyleRequestBoard"
	board.add_child(art)
	return {"ok": true, "hidden": hidden, "triangles": _triangles(art)}
