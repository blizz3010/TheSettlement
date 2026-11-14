extends SceneTree

func _init() -> void:
	var world := Node3D.new()
	world.name = "DummyWorld"
	root.add_child(world)
	var applied: Node3D = preload("res://raid/scripts/settlement_visuals_style_test.gd").apply(world)
	if applied == null:
		printerr("STYLE_TEST_LOAD_FAIL")
		quit(1)
		return
	print("STYLE_TEST_LOAD_OK budget=", applied.get_meta("budget"))
	var required := [
		"IvyLeaves", "HangingBasket00", "Planter00",
		"FrameTreeSouth", "FrameTreeNorth", "CrateStack",
		"LanternPost", "GardenBench", "HomePlotSign",
		"VergeGrass"
	]
	var missing: PackedStringArray = []
	for n in required:
		if applied.find_child(n, true, false) == null:
			missing.append(n)
	if missing.size() > 0:
		printerr("STYLE_TEST_MISSING ", missing)
		quit(2)
		return
	# Confirm new trees have leaf clumps and forks, not sphere lobes.
	var south: Node = applied.find_child("FrameTreeSouth", true, false)
	var has_clumps := south.find_child("LeafClumps", true, false) != null
	var has_fork := south.find_child("Fork0", true, false) != null or south.find_child("Branch0", true, false) != null
	var has_old_sphere := south.find_child("Lobe00", true, false) != null
	print("TREE_SOUTH clumps=", has_clumps, " forks=", has_fork, " old_sphere=", has_old_sphere, " children=", south.get_child_count())
	if not has_clumps or has_old_sphere:
		printerr("TREE_SHAPE_FAIL")
		quit(3)
		return
	print("STYLE_TEST_CHILDREN_OK")
	quit(0)
