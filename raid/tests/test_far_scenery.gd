extends SceneTree
## Item 9 contract: far scenery (option B) is on by default, the original thin
## dome ribs are hidden at runtime, and FAR_SCENERY_OPTION=off turns it off.
## The thickened-rib / A / C preview paths are retired. Pinned settlement.gd is
## not edited; this test never loads it.
const Far = preload("res://raid/scripts/far_scenery_options.gd")
var checks := 0
var failures: Array = []
var report := {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

class Backdrop extends Node3D:
	var terrain_vertices: PackedVector3Array

func make_backdrop() -> Backdrop:
	var backdrop := Backdrop.new()
	backdrop.name = "ValleyBackdrop"
	var faces := PackedVector3Array()
	var sectors := 16
	for i in sectors:
		var a0 := TAU * i / sectors
		var a1 := TAU * (i + 1) / sectors
		var inner0 := Vector3(cos(a0) * 50.0, 8.0, sin(a0) * 50.0)
		var inner1 := Vector3(cos(a1) * 50.0, 8.0, sin(a1) * 50.0)
		var outer0 := Vector3(cos(a0) * 340.0, 12.0, sin(a0) * 340.0)
		var outer1 := Vector3(cos(a1) * 340.0, 12.0, sin(a1) * 340.0)
		faces.append_array([inner0, outer0, inner1, inner1, outer0, outer1])
	backdrop.terrain_vertices = faces
	for name in ["MiddleRidge", "OuterFoothills", "ScenicGroundApron", "DistantAlpineRange"]:
		var mesh := MeshInstance3D.new()
		mesh.name = name
		mesh.mesh = PlaneMesh.new()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.45, 0.3)
		mesh.material_override = mat
		backdrop.add_child(mesh)
	return backdrop

func make_rib(world: Node3D, i: int) -> MeshInstance3D:
	var rib := MeshInstance3D.new()
	rib.name = "StubDomeRib%d" % i
	var box := BoxMesh.new()
	box.size = Vector3(0.055, 0.055, 2.0)
	rib.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("93c4be")
	rib.material_override = mat
	rib.visible = true
	world.add_child(rib)
	return rib

func make_world() -> Node3D:
	var world := Node3D.new()
	world.set_meta("inn_lake_mountain_fix", {"ok": true})
	var backdrop := make_backdrop()
	world.add_child(backdrop)
	for i in 3:
		make_rib(world, i)
	root.add_child(world)
	return world

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var src: String = load("res://raid/scripts/far_scenery_options.gd").source_code
	var hook: String = load("res://raid/scripts/ship_settlement_preview.gd").source_code
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://raid/play_title.tscn", "Normal start is play_title.tscn")
	check(hook.contains('preload("res://raid/scripts/far_scenery_options.gd").apply(self)'), "Ship settlement applies far scenery after the lake fix")
	check(hook.contains("FAR_SCENERY_OPTION=off"), "Hook documents the off switch")
	check(not hook.contains("PREVIEW is set"), "Hook no longer gates on a PREVIEW flag")
	check(not src.contains("add_dome_ribs") and not src.contains("RIB_NEW_THICK") and not src.contains("far_dome_rib"), "Thickened-rib code is retired")
	check(not FileAccess.file_exists("res://raid/shaders/far_dome_rib_v100.gdshader"), "Thickened-rib shader is gone")
	check(src.contains("FarSceneryLayerRidges") and src.contains("add_layer_ridges"), "Layered ridge path is present")
	check(not src.contains('if opt == "A"') and not src.contains('if opt == "C"'), "A/C option branches are retired")

	OS.set_environment("FAR_SCENERY_OPTION", "")
	check(Far.enabled(), "Enabled by default when the env is unset")

	var on_world := make_world()
	var on := Far.apply(on_world)
	report["default"] = on
	check(on.get("ok", false) == true and on.get("skipped", true) == false, "Default apply succeeds")
	check(str(on.get("option", "")) == "B", "Default option is B")
	check(on_world.has_node("FarScenery"), "FarScenery root is present")
	check(on_world.has_node("FarScenery/FarSceneryLayerRidges"), "Layered ridges are present")
	check(not on_world.has_node("FarScenery/FarOptionDomeRibs"), "No thickened dome ribs were added")
	var painted: Array = on.get("painted", [])
	check(painted.has("MiddleRidge") and painted.has("DistantAlpineRange"), "Hills and alpine backdrop are painted")
	var mid := on_world.get_node("ValleyBackdrop/MiddleRidge") as MeshInstance3D
	var paint_mat := mid.material_override as ShaderMaterial
	check(paint_mat != null and paint_mat.shader != null, "MiddleRidge uses the far-scenery paint shader")
	if paint_mat:
		check(paint_mat.get_shader_parameter("lake_cut") == false, "PR #5 lake_cut stays off when the lake-fix meta is set")
		check(paint_mat.get_shader_parameter("paint_full") == true, "Full-azimuth paint is on")
	check(int(on.get("hidden_original_ribs", 0)) == 3, "All stub original ribs were hidden")
	for i in 3:
		var rib := on_world.get_node("StubDomeRib%d" % i) as MeshInstance3D
		check(rib.visible == false, "Original rib %d hidden at runtime" % i)
	check(int(on.get("instances", 0)) > 0, "Dense treeline instances were planted")
	var ridges: Dictionary = on.get("layer_ridges", {})
	check(int(ridges.get("rings", 0)) == 2 and int(ridges.get("triangles", 0)) > 200, "Two low-detail ridge rings")
	on_world.free()

	OS.set_environment("FAR_SCENERY_OPTION", "off")
	check(not Far.enabled(), "FAR_SCENERY_OPTION=off disables far scenery")
	var off_world := make_world()
	var off := Far.apply(off_world)
	report["off"] = off
	check(off.get("ok", false) == true and off.get("skipped", false) == true, "Off apply is a clean skip")
	check(not off_world.has_node("FarScenery"), "Off leaves no FarScenery node")
	for i in 3:
		var rib := off_world.get_node("StubDomeRib%d" % i) as MeshInstance3D
		check(rib.visible == true, "Original rib %d stays visible when off" % i)
	off_world.free()
	OS.set_environment("FAR_SCENERY_OPTION", "")

	print("FAR_SCENERY_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "report": report, "rendered": false}))
	quit(0 if failures.is_empty() else 1)
