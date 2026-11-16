extends SceneTree
## Item 12 rollout 2 contract: midstyle_rollout2.gd swaps the launchpad ship visual and
## the plaza request board when enabled, is idempotent, leaves pinned files and ship
## collision / runtime mesh / takeoff split contract intact, and is turned on by the
## normal game start (ship settlement).
const Rollout2 = preload("res://raid/scripts/midstyle_rollout2.gd")
const TakeoffMesh = preload("res://raid/scripts/ship_takeoff_mesh.gd")
var checks := 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func triangles(root: Node) -> int:
	var total := 0
	if root == null:
		return 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for s in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(s)
			if arrays[Mesh.ARRAY_INDEX] != null:
				total += arrays[Mesh.ARRAY_INDEX].size() / 3
			elif arrays[Mesh.ARRAY_VERTEX] != null:
				total += arrays[Mesh.ARRAY_VERTEX].size() / 3
	return total

func files_exist() -> void:
	for path in [Rollout2.HULL, Rollout2.PAD, Rollout2.BOARD]:
		check(ResourceLoader.exists(path), "Remodel exists " + path)

func verify_disabled_is_noop() -> void:
	Rollout2.enabled = false
	var world := Node3D.new(); root.add_child(world)
	var result := Rollout2.apply(world)
	check(result.get("ok", true) == false, "Disabled apply is not ok")
	check(world.get_node_or_null("MidstyleLaunchpadHull") == null, "Disabled: no hull node")
	check(world.get_node_or_null("RequestBoard") == null or world.get_node_or_null("RequestBoard/MidstyleRequestBoard") == null, "Disabled: no board art")
	world.free()

func verify_assets() -> void:
	for path in [Rollout2.HULL, Rollout2.PAD, Rollout2.BOARD]:
		var packed := load(path) as PackedScene
		check(packed != null, "Loads " + path)
		if packed == null:
			continue
		var art := packed.instantiate() as Node3D
		root.add_child(art)
		var tris := triangles(art)
		check(tris > 0, path + " has triangles (" + str(tris) + ")")
		check(art.find_children("*", "CollisionObject3D", true, false).is_empty(), "No embedded collision " + path)
		check(art.find_children("*", "Light3D", true, false).is_empty(), "No embedded lights " + path)
		for node in art.find_children("*", "Node", true, false):
			check(node.get_script() == null, "No imported script " + path)
		# Mid-to-high poly: each remodel is denser than the stock primitive/low-poly read.
		if path == Rollout2.HULL:
			check(tris >= 20000, "Hull is mid-to-high poly (" + str(tris) + " >= 20000)")
		elif path == Rollout2.PAD:
			check(tris >= 8000, "Pad is mid-to-high poly (" + str(tris) + " >= 8000)")
		else:
			check(tris >= 8000, "Request board is mid-to-high poly (" + str(tris) + " >= 8000)")
		art.free()

func verify_ship_bounds_and_split() -> void:
	# Hull stays inside a loose envelope around the original (r<=5.5 body, height, length)
	# so it sits on the unchanged collision and under the pad rails.
	var packed := load(Rollout2.HULL) as PackedScene
	if packed == null:
		check(false, "Hull packed for bounds")
		return
	var hull := packed.instantiate() as Node3D
	root.add_child(hull)
	var box := AABB(); var first := true
	for mesh in hull.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for s in mesh.mesh.get_surface_count():
			var verts = mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var to_root := hull.global_transform.affine_inverse() * mesh.global_transform
			for v in verts:
				var p: Vector3 = to_root * v
				if first:
					box = AABB(p, Vector3.ZERO); first = false
				else:
					box = box.expand(p)
	check(not first, "Hull has vertices")
	# Original ivory/ochre/alloy lived roughly x -5.5..4.8, y 1.47..5.65, z ±3.8; gear goes to y~1.47.
	# Allow a little extra for bells, fins and shoes, but stay on the pad (r 8) and off the rails (r 7.65).
	check(box.position.x >= -6.2 and box.end.x <= 6.0, "Hull length stays near the original " + str(box))
	check(box.position.y >= 1.20 and box.end.y <= 6.2, "Hull height stays near the original " + str(box))
	check(box.position.z >= -4.3 and box.end.z <= 4.3, "Hull width stays inside the pad rails " + str(box))
	# Stock runtime mesh (pinned glb) still splits into pad + hull for takeoff.
	if ResourceLoader.exists("res://assets/kit/launchpad_ship.glb"):
		var stock := (load("res://assets/kit/launchpad_ship.glb") as PackedScene).instantiate() as Node3D
		root.add_child(stock)
		var runtime: MeshInstance3D = stock.find_child("LaunchpadShip_Runtime", true, false)
		check(runtime != null and runtime.mesh != null, "Stock LaunchpadShip_Runtime still present")
		if runtime != null and runtime.mesh != null:
			check(runtime.mesh.get_surface_count() == 10, "Stock ship still has 10 surfaces")
			var split: Dictionary = TakeoffMesh.split_mesh(runtime.mesh, runtime)
			check(split.get("ok", false) and int(split.pad_triangles) > 0 and int(split.hull_triangles) > 0, "Stock mesh still splits for takeoff")
		stock.free()
	hull.free()

func verify_board_bounds() -> void:
	var packed := load(Rollout2.BOARD) as PackedScene
	if packed == null:
		check(false, "Board packed for bounds")
		return
	var art := packed.instantiate() as Node3D
	root.add_child(art)
	var box := AABB(); var first := true
	for mesh in art.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for s in mesh.mesh.get_surface_count():
			var verts = mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var to_root := art.global_transform.affine_inverse() * mesh.global_transform
			for v in verts:
				var p: Vector3 = to_root * v
				if first:
					box = AABB(p, Vector3.ZERO); first = false
				else:
					box = box.expand(p)
	# Original board: panel 1.8 x 1.5 x 0.15 at y=1.35, posts at x=±0.7. Keep a tight envelope
	# so it does not eat the path or the hall. Allow a modest drip-cap / paper curl overhang.
	check(box.position.x >= -1.15 and box.end.x <= 1.15, "Board width stays on the posts " + str(box))
	check(box.position.y >= -0.05 and box.end.y <= 2.45, "Board height stays near the original " + str(box))
	check(box.position.z >= -0.25 and box.end.z <= 0.35, "Board depth stays a thin facing " + str(box))
	art.free()

func verify_apply_and_idempotent() -> void:
	Rollout2.enabled = true
	var world := Node3D.new(); root.add_child(world)
	# Minimal ship + board stand-ins.
	var ship := Node3D.new(); ship.name = "LaunchpadShip"; world.add_child(ship)
	var art := Node3D.new(); art.name = "Art"; ship.add_child(art)
	var runtime := MeshInstance3D.new(); runtime.name = "LaunchpadShip_Runtime"
	var boxmesh := BoxMesh.new(); boxmesh.size = Vector3(1, 1, 1); runtime.mesh = boxmesh
	art.add_child(runtime)
	var board := Node3D.new(); board.name = "RequestBoard"; world.add_child(board)
	var panel := MeshInstance3D.new(); var pm := BoxMesh.new(); pm.size = Vector3(1.8, 1.5, 0.15)
	panel.mesh = pm; panel.position = Vector3(0, 1.35, 0); board.add_child(panel)
	var body := StaticBody3D.new(); board.add_child(body)
	var col := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = Vector3(1.8, 1.5, 0.15)
	col.shape = shape; body.add_child(col)

	var first: Dictionary = Rollout2.apply(world)
	check(first.get("ok", false), "First apply ok " + str(first))
	check(ship.has_node("MidstyleLaunchpadHull") and ship.has_node("MidstyleLaunchpadPad"), "Ship nodes added")
	check(board.has_node("MidstyleRequestBoard"), "Board node added")
	check(runtime.visible == false, "Stock runtime mesh hidden")
	check(panel.visible == false, "Stock board panel hidden")
	check(board.get_node("StaticBody3D") != null and is_instance_valid(col), "Board collider kept")
	var hull_tris: int = first.ship.get("hull_triangles", 0)
	var pad_tris: int = first.ship.get("pad_triangles", 0)
	var board_tris: int = first.board.get("triangles", 0)
	check(hull_tris > 0 and pad_tris > 0 and board_tris > 0, "Apply reports triangle counts")

	var second: Dictionary = Rollout2.apply(world)
	check(second.get("ok", false) and second.ship.get("already", false) and second.board.get("already", false), "Second apply is idempotent")
	check(ship.find_children("MidstyleLaunchpadHull", "Node3D", true, false).size() == 1, "Only one hull")
	check(board.find_children("MidstyleRequestBoard", "Node3D", true, false).size() == 1, "Only one board art")
	world.free()

func verify_normal_start_enables() -> void:
	# The play-flow title uses the ship settlement, which turns the swap on.
	var src := FileAccess.get_file_as_string("res://raid/scripts/ship_settlement_preview.gd")
	check(src.contains("MidstyleRollout2.enabled = MidstyleSwap.enabled"), "Ship settlement enables rollout 2")
	check(src.contains("MidstyleRollout2.apply(self)"), "Ship settlement applies rollout 2")
	var takeoff := FileAccess.get_file_as_string("res://raid/scripts/ship_takeoff_cutscene.gd")
	check(takeoff.contains("MidstyleLaunchpadHull"), "Takeoff lifts the remodelled hull")
	check(FileAccess.file_exists("res://project.godot") and FileAccess.get_file_as_string("res://project.godot").contains("res://raid/play_title.tscn"), "Normal main scene is play_title")

func verify_pins_untouched() -> void:
	# These paths must still be the pinned originals; we never write them.
	for path in [
		"res://assets/kit/launchpad_ship.glb",
		"res://assets/kit/launchpad_ship.glb.import",
		"res://assets/source/launchpad_ship/collision_geometry.json",
		"res://scripts/launchpad_ship.gd",
		"res://scripts/home_request_signage.gd",
	]:
		check(ResourceLoader.exists(path) or FileAccess.file_exists(path), "Pinned path still present " + path)

func run() -> void:
	files_exist()
	verify_disabled_is_noop()
	verify_assets()
	verify_ship_bounds_and_split()
	verify_board_bounds()
	verify_apply_and_idempotent()
	verify_normal_start_enables()
	verify_pins_untouched()
	print("MIDSTYLE_ROLLOUT2_TESTS %d/%d" % [checks - failures.size(), checks])
	if not failures.is_empty():
		print("FAILURES:")
		for f in failures:
			print(" - ", f)
	quit(1 if not failures.is_empty() else 0)
