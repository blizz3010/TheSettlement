extends SceneTree
## TASKS item 21 regression (Ori's Town Hall "stall"). Headless, no pinned file is loaded
## except the real player.gd / options_panel.gd / grass_lod shader used as-is.
##  A. Stall path: a synthetic settlement grass layout shaped like the measured one (6 m
##     near-LOD chunks of 130-triangle clumps around the Town Hall shell, terrain rising
##     behind it, a coverage bed) must fit a primitive budget at the login spawn once
##     raid/scripts/grass_view_culling.gd is active, and nothing that can be seen is cut:
##     every culled instance is either flattened by the shader at that distance or hidden
##     behind the hall's solid lower walls (checked with independent physics ray casts).
##  B. Escape / quit / return option: raid/scripts/town_hall_recovery.gd on a fake world
##     with the real options panel and player.
const Culling = preload("res://raid/scripts/grass_view_culling.gd")
const Recovery = preload("res://raid/scripts/town_hall_recovery.gd")
const GRASS_SHADER = preload("res://assets/settlement_grass_v086/grass_lod.gdshader")
const SPAWN_EYE := Vector3(0.0, 1.95, -17.2)
const PLAZA_EYE := Vector3(0.0, 1.88, -8.0)
const HALL_REAR_EYE := Vector3(0.0, 1.95, -24.5)
const PER_CHUNK := 400
## Budget at the spawn view (frustum + visibility range, like the engine): the culled
## layout must draw at most this share of the unculled one.
const SPAWN_BUDGET_SHARE := 0.75
var checks := 0
var failures: Array = []
var report := {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func frames(n: int) -> void:
	for i in n: await process_frame

func physics(n: int) -> void:
	for i in n: await physics_frame

# ---------------------------------------------------------------- A. grass layout
static func clump_mesh() -> ArrayMesh:
	# 65 blades x 2 triangles = 130 triangles, 0.7 m tall, like the baked clumps.
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for b in 65:
		var a := TAU * b / 65.0
		var r := 0.05 + 0.12 * fmod(b * 0.618, 1.0)
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var side := Vector3(-sin(a), 0.0, cos(a)) * 0.03
		var n := verts.size()
		verts.append_array([base - side, base + side, base + Vector3(0, 0.7, 0) + side * 0.2, base + Vector3(0, 0.7, 0) - side * 0.2])
		idx.append_array([n, n + 1, n + 2, n, n + 2, n + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

static func ground_y(x: float, z: float) -> float:
	return maxf(0.0, (-31.8 - z) * 0.12) if absf(x) < 30.0 else 0.0

static func in_hall(x: float, z: float) -> bool:
	return x > -8.8 and x < 8.8 and z > -31.8 and z < -14.2

func make_batch(parent: Node3D, name: String, rect: Rect2, count: int, mat: Material, range_end: float, rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = clump_mesh() if not parent.has_meta("mesh") else parent.get_meta("mesh")
	parent.set_meta("mesh", mm.mesh)
	var xforms: Array = []
	var tries := 0
	while xforms.size() < count and tries < count * 4:
		tries += 1
		var x := rect.position.x + rng.randf() * rect.size.x
		var z := rect.position.y + rng.randf() * rect.size.y
		if in_hall(x, z): continue
		var s := rng.randf_range(0.8, 1.25)
		xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, ground_y(x, z), z)))
	mm.instance_count = xforms.size()
	# The headless renderer stores no instance data: hand the buffer over as meta
	# (Culling.BUFFER_META), in the engine's Transform3D + colour layout.
	var buf := PackedFloat32Array()
	var box := AABB()
	for i in xforms.size():
		var t: Transform3D = xforms[i]
		buf.append_array([t.basis.x.x, t.basis.y.x, t.basis.z.x, t.origin.x, t.basis.x.y, t.basis.y.y, t.basis.z.y, t.origin.y, t.basis.x.z, t.basis.y.z, t.basis.z.z, t.origin.z, rng.randf(), 1.0, 1.0, 1.0])
		var ib := AABB(t.origin - Vector3(0.3, 0, 0.3), Vector3(0.6, 0.9, 0.6))
		box = ib if i == 0 else box.merge(ib)
	mm.buffer = buf
	mm.set_meta(Culling.BUFFER_META, buf)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = range_end
	mmi.set_meta("test_aabb", box)
	parent.add_child(mmi)
	return mmi

func make_grass_world() -> Node3D:
	var world := Node3D.new()
	world.name = "GrassWorld"
	var comp := Node3D.new()
	comp.name = "PlazaIslandComposition"
	world.add_child(comp)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var near := ShaderMaterial.new()
	near.shader = GRASS_SHADER
	near.set_shader_parameter("near_mode", true)
	near.set_shader_parameter("near_start", 18.0)
	near.set_shader_parameter("near_end", 24.0)
	for cx in range(-8, 8):
		for cz in range(-12, 4):
			make_batch(comp, "GroundNear_%d_%d_Field" % [cx, cz], Rect2(cx * 6.0, cz * 6.0, 6.0, 6.0), PER_CHUNK, near, 30.0, rng)
	var bed := StandardMaterial3D.new()
	bed.albedo_color = Color(0.3, 0.5, 0.2)
	make_batch(comp, "Grass_Coverage_Bed", Rect2(10.0, -12.0, 8.0, 8.0), 1500, bed, 55.0, rng)
	make_batch(comp, "Grass_Hall_Rear", Rect2(-6.0, -40.0, 12.0, 6.0), 1500, bed, 55.0, rng)
	# Small batch (below MIN_INSTANCES) stays untouched.
	make_batch(comp, "Grass_Tiny", Rect2(20.0, 0.0, 2.0, 2.0), 40, bed, 55.0, rng)
	# Solid lower walls of the hall up to the glazing sill, doorway open (independent check).
	var walls := StaticBody3D.new()
	walls.name = "HallLowerWalls"
	world.add_child(walls)
	for spec in [[Vector3(-8.8, -0.5, -23.0), Vector3(0.3, 3.36, 17.6)], [Vector3(8.8, -0.5, -23.0), Vector3(0.3, 3.36, 17.6)], [Vector3(0.0, -0.5, -31.8), Vector3(17.6, 3.36, 0.3)], [Vector3(-5.45, -0.5, -14.2), Vector3(6.7, 3.36, 0.3)], [Vector3(5.45, -0.5, -14.2), Vector3(6.7, 3.36, 0.3)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[1]
		shape.shape = box
		shape.position = spec[0] + Vector3(0, spec[1].y * 0.5 - 1.0 + 0.5, 0) - Vector3(0, 0.5, 0)
		walls.add_child(shape)
	var cam := Camera3D.new()
	cam.name = "Eye"
	cam.fov = 76
	world.add_child(cam)
	return world

## What the engine would draw: visible, in the frustum, inside the visibility range.
func budget(world: Node3D, gc = null) -> Dictionary:
	var boxes := {}
	if gc != null:
		for batch in gc.batches:
			for s in batch.subs: boxes[s.mmi] = s.aabb
	var cam: Camera3D = world.get_node("Eye")
	var planes := cam.get_frustum()
	var tris := 0
	var draws := 0
	for n in world.find_children("*", "MultiMeshInstance3D", true, false):
		if not n.is_visible_in_tree(): continue
		var mm: MultiMesh = n.multimesh
		var box: AABB = n.get_meta("test_aabb") if n.has_meta("test_aabb") else boxes.get(n, AABB())
		if n.visibility_range_end > 0.0 and cam.global_position.distance_to(box.get_center()) > n.visibility_range_end: continue
		var inside := true
		for pl in planes:
			var any := false
			for i in 8:
				if not pl.is_point_over(box.get_endpoint(i)): any = true; break
			if not any: inside = false; break
		if not inside: continue
		var v := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		tris += v * 130
		draws += 1
	return {"tris": tris, "draws": draws}

func place_eye(world: Node3D, pos: Vector3, yaw: float) -> void:
	var cam: Camera3D = world.get_node("Eye")
	cam.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	cam.current = true

static func xf_at(mm: MultiMesh, i: int) -> Transform3D:
	var b := Culling.instance_buffer(mm)
	var o := i * 16
	return Transform3D(Vector3(b[o], b[o + 4], b[o + 8]), Vector3(b[o + 1], b[o + 5], b[o + 9]), Vector3(b[o + 2], b[o + 6], b[o + 10]), Vector3(b[o + 3], b[o + 7], b[o + 11]))

static func color_at(mm: MultiMesh, i: int) -> Color:
	var b := Culling.instance_buffer(mm)
	return Color(b[i * 16 + 12], b[i * 16 + 13], b[i * 16 + 14], b[i * 16 + 15])

static func instance_top(mm: MultiMesh, i: int, eye: Vector3, near: bool) -> Vector3:
	var xf := xf_at(mm, i)
	var d := Vector2(xf.origin.x - eye.x, xf.origin.z - eye.z).length()
	var keep := 1.0 - smoothstep(18.0, 24.0, d) if near else 1.0
	return xf.origin + Vector3(0, 0.7 * xf.basis.y.length() * keep + 0.02, 0)

## Culled blades (not flattened by distance) must be hidden from eye by the solid walls.
func hidden_check(world: Node3D, gc, eye: Vector3) -> Dictionary:
	var space := world.get_world_3d().direct_space_state
	var out := {"tested": 0, "visible": []}
	for batch in gc.batches:
		for s in batch.subs:
			if s.mmi.visible: continue
			var mm: MultiMesh = s.mmi.multimesh
			for j in mm.instance_count:
				var xf := xf_at(mm, j)
				if s.near and Vector2(xf.origin.x - eye.x, xf.origin.z - eye.z).length() >= 24.0: continue
				out.tested += 1
				var top := instance_top(mm, j, eye, s.near)
				if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, top)).is_empty() and out.visible.size() < 5: out.visible.append(str(top))
	return out

func test_grass() -> void:
	var world := make_grass_world()
	root.add_child(world)
	place_eye(world, SPAWN_EYE, 0.0)
	await frames(2)
	var before := budget(world)
	var originals: Array = []
	for n in world.get_node("PlazaIslandComposition").get_children():
		if n is MultiMeshInstance3D: originals.append(n)
	var gc = Culling.install(world)
	check(gc != null, "grass culling installs")
	var t0 := Time.get_ticks_msec()
	while not gc.split_done and Time.get_ticks_msec() - t0 < 60000: await frames(1)
	check(gc.split_done, "grass split finishes")
	gc.force_update = true
	await frames(2)
	var after := budget(world, gc)
	report.spawn = {"before": before, "after": after, "stats": gc.stats.duplicate()}
	check(before.tris > 1000000, "synthetic spawn view reproduces the heavy grass load (%d tris)" % before.tris)
	check(after.tris <= int(before.tris * SPAWN_BUDGET_SHARE), "spawn primitive budget: %d <= %.0f%% of %d" % [after.tris, SPAWN_BUDGET_SHARE * 100.0, before.tris])
	check(gc.stats.culled_sill > 0 and gc.stats.culled_distance > 0, "both culling rules active at the spawn")
	# Exact copy: every instance appears once with identical data, originals hidden.
	var tiny = world.get_node("PlazaIslandComposition/Grass_Tiny")
	check(tiny.visible and not tiny.has_meta("grass_view_culling_split"), "small batches are left alone")
	var exact := true
	for batch in gc.batches:
		var o: MultiMeshInstance3D = batch.original
		var seen := 0
		for s in batch.subs:
			seen += s.indices.size()
			for j in range(0, s.indices.size(), 37):
				var i: int = s.indices[j]
				if not xf_at(s.mmi.multimesh, j).is_equal_approx(xf_at(o.multimesh, i)): exact = false
				if not color_at(s.mmi.multimesh, j).is_equal_approx(color_at(o.multimesh, i)): exact = false
			if s.mmi.material_override != o.material_override or s.mmi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: exact = false
		if seen != o.multimesh.instance_count or o.visible: exact = false
	check(exact, "sub-chunks copy every instance (transform, colour, material, no shadows) once; originals hidden")
	# Nothing visible is cut: physics rays from the eye to each culled blade tip hit a wall.
	await physics(3)
	var hidden_spawn := hidden_check(world, gc, SPAWN_EYE)
	place_eye(world, HALL_REAR_EYE, 0.0)
	gc.force_update = true
	await frames(2)
	report.hall_rear = {"stats": gc.stats.duplicate(), "after": budget(world, gc)}
	var hidden_rear := hidden_check(world, gc, HALL_REAR_EYE)
	report.hidden_checked = [hidden_spawn.tested, hidden_rear.tested]
	check(hidden_spawn.tested > 50 and hidden_spawn.visible.is_empty(), "every culled blade at the spawn is behind the solid lower walls (%d checked, visible: %s)" % [hidden_spawn.tested, str(hidden_spawn.visible)])
	check(hidden_rear.tested > 50 and hidden_rear.visible.is_empty(), "every culled blade at the hall rear is behind the solid lower walls (%d checked, visible: %s)" % [hidden_rear.tested, str(hidden_rear.visible)])
	place_eye(world, SPAWN_EYE, 0.0)
	gc.force_update = true
	await frames(2)
	var flat_ok := true
	# Quality presets still apply (pinned controllers set visible_instance_count on originals).
	var o0: MultiMeshInstance3D = gc.batches[0].original
	var v := int(o0.multimesh.instance_count * 0.3)
	o0.multimesh.visible_instance_count = v
	gc.force_update = true
	await frames(2)
	var shown := 0
	var prefix_ok := true
	for s in gc.batches[0].subs:
		var sv: int = s.mmi.multimesh.visible_instance_count
		shown += sv
		if sv > 0 and s.indices[sv - 1] >= v: prefix_ok = false
		if sv < s.indices.size() and s.indices[sv] < v: prefix_ok = false
	check(shown == v and prefix_ok, "grass density from Options carries over to the sub-chunks")
	o0.multimesh.visible_instance_count = -1
	# Outdoors on the plaza: no glazing culling, only blades the shader flattens are skipped.
	place_eye(world, PLAZA_EYE, PI)
	gc.force_update = true
	await frames(2)
	var plaza := budget(world, gc)
	report.plaza = {"stats": gc.stats.duplicate(), "after": plaza}
	check(gc.stats.culled_sill == 0, "outdoors nothing is culled by the hall glazing rule")
	for batch in gc.batches:
		for s in batch.subs:
			if s.mmi.visible: continue
			var mm: MultiMesh = s.mmi.multimesh
			for j in mm.instance_count:
				var xf := xf_at(mm, j)
				if not s.near or Vector2(xf.origin.x - PLAZA_EYE.x, xf.origin.z - PLAZA_EYE.z).length() < 24.0: flat_ok = false
	check(flat_ok, "outdoors every culled blade is one the near-LOD shader draws at zero height")
	# Test hooks and teardown restore the untouched batches.
	gc.set_mode("original")
	var restored := true
	for batch in gc.batches:
		if not batch.original.visible: restored = false
		for s in batch.subs:
			if s.mmi.visible: restored = false
	check(restored, "original mode shows the untouched batches only")
	gc.set_mode("cull")
	gc.queue_free()
	await frames(2)
	var back := true
	for o in originals:
		if not o.visible: back = false
	check(back, "removing the culling node restores the original grass")
	OS.set_environment("SETTLEMENT_GRASS_CULLING", "off")
	check(Culling.install(world) == null, "SETTLEMENT_GRASS_CULLING=off disables it")
	OS.unset_environment("SETTLEMENT_GRASS_CULLING")
	world.queue_free()
	await frames(2)

# ---------------------------------------------------------------- B. recovery
class FakeHud extends Node:
	var full := Control.new()
	func _ready(): add_child(full); full.hide()

class FakeWorld extends Node3D:
	var world_initialized := true
	var staged_startup := true
	var world_activated := true
	var startup_cancel_requested := false
	var cooking_window_focused := true
	var moving_stash := false
	var map_restore_pending := false
	var ship_contract = null
	var ship_takeoff = null
	var ship_selection = null
	var player
	var options_panel
	var settlement_hud
	var inventory_panel := Control.new()
	var dialog := Control.new()
	var request_panel := Control.new()
	var supplies_panel := Control.new()
	var saves := 0
	var save_ok := true
	var messages: Array = []
	func modal_open() -> bool:
		return options_panel.visible or settlement_hud.full.visible or inventory_panel.visible or dialog.visible or request_panel.visible or supplies_panel.visible
	func open_options():
		if modal_open(): return
		options_panel.open(); player.enabled = false
	func close_options(): player.enabled = true
	func open_map():
		if modal_open(): return
		settlement_hud.full.show(); player.enabled = false
	func close_map():
		if not settlement_hud.full.visible: return
		settlement_hud.full.hide(); player.enabled = true
	func close_inventory(): inventory_panel.hide(); player.enabled = true
	func close_dialog(): dialog.hide(); player.enabled = true
	func close_request_board(): request_panel.hide(); player.enabled = true
	func close_supplies(): supplies_panel.hide(); player.enabled = true
	func message(t): messages.append(t)
	func save_game(_quiet := true) -> bool:
		saves += 1
		return save_ok
	func _unhandled_input(event):
		# Baseline: Escape opens the pause menu when nothing else is open. A broken panel
		# (request_panel here) swallows nothing but also never closes: the stuck case.
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not modal_open(): open_options()

func esc() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.physical_keycode = KEY_ESCAPE
	e.pressed = true
	root.push_input(e)
	var up := e.duplicate()
	up.pressed = false
	root.push_input(up)

func make_fake_world() -> FakeWorld:
	var w := FakeWorld.new()
	w.name = "FakeSettlement"
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 0.24, 40)
	shape.shape = box
	shape.position = Vector3(0, 0.12, -17.0)
	floor_body.add_child(shape)
	w.add_child(floor_body)
	w.player = load("res://scripts/player.gd").new()
	w.player.name = "Player"
	w.add_child(w.player)
	w.player.position = Vector3(3.0, 0.27, -24.0)
	var layer := CanvasLayer.new()
	w.add_child(layer)
	w.options_panel = load("res://scripts/options_panel.gd").new()
	layer.add_child(w.options_panel)
	w.options_panel.setup(w.player, func(): return w.save_game(false))
	w.options_panel.closed.connect(w.close_options)
	w.settlement_hud = FakeHud.new()
	w.add_child(w.settlement_hud)
	for c in [w.inventory_panel, w.dialog, w.request_panel, w.supplies_panel]:
		layer.add_child(c); c.hide()
	return w

func test_recovery() -> void:
	var w := make_fake_world()
	root.add_child(w)
	await physics(3)
	var rec = Recovery.install(w)
	var quit_calls := [0]
	rec.quit_handler = func(): quit_calls[0] += 1
	await frames(1)
	var back: Button = w.options_panel.back_button
	check(is_instance_valid(rec.return_button) and rec.return_button.text == "Return to Town Hall entrance", "pause menu has Return to Town Hall entrance")
	check(rec.return_button.get_parent() == back.get_parent() and rec.return_button.get_index() == back.get_index() + 1, "the return option sits right after Back to Game")
	check(is_instance_valid(rec.quit_now_button) and rec.quit_now_button.get_parent() == w.options_panel.quit_row, "quit prompt has Quit without saving")
	check(Recovery.install(w) == rec and w.options_panel.back_button.get_parent().find_children("ReturnToTownHallEntrance", "", false, false).size() == 1, "install is idempotent")
	# Return option from a messy state: seated with no valid exit, crouched, a panel open.
	w.open_options()
	w.inventory_panel.show()
	w.player.seated = true
	w.player.seated_exits.clear()
	w.player.crouched = true
	w.player.rotation.y = 0.7
	w.player.pitch = -1.25
	rec.return_button.pressed.emit()
	await physics(2)
	var p = w.player
	var r: Dictionary = rec.last_return
	check(r.get("ok") == true and r.get("used") == "entrance", "return option succeeds at the entrance: %s" % str(r))
	check(Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(0.0, -15.4)) < 0.05 and absf(p.global_position.y - 0.27) < 0.05, "player stands just inside the doorway (%s)" % str(p.global_position))
	check(absf(wrapf(p.rotation.y - PI, -PI, PI)) < 0.01 and absf(p.pitch + 0.04) < 0.001, "player faces out of the hall with a level view")
	check(not p.seated and not p.crouched and p.enabled and not w.options_panel.visible and not w.inventory_panel.visible and not w.modal_open(), "return option closes every overlay and restores control")
	# Doorway blocked -> login spawn; both blocked -> refuses and keeps the pause menu.
	var blocker := StaticBody3D.new()
	var bs := CollisionShape3D.new()
	var bb := BoxShape3D.new(); bb.size = Vector3(1.5, 2.0, 1.5)
	bs.shape = bb; blocker.add_child(bs); w.add_child(blocker)
	blocker.global_position = Vector3(0, 1.24, -15.4)
	await physics(2)
	r = rec.return_to_entrance("test")
	check(r.get("ok") == true and r.get("used") == "login_spawn", "blocked doorway falls back to the login spawn")
	var blocker2 := blocker.duplicate()
	w.add_child(blocker2)
	blocker2.global_position = Vector3(0, 1.24, -17.2)
	p.global_position = Vector3(3, 0.27, -24)
	await physics(2)
	r = rec.return_to_entrance("test")
	check(r.get("ok") == false and w.options_panel.visible, "both blocked: refuses safely and keeps the pause menu open")
	blocker.queue_free(); blocker2.queue_free()
	w.options_panel.cancel_and_close()
	await physics(2)
	# Escape closes the map and does not open the pause menu.
	w.open_map()
	check(w.settlement_hud.full.visible, "map opens")
	rec.escape_times.clear()
	esc()
	await frames(1)
	check(not w.settlement_hud.full.visible and not w.options_panel.visible, "Escape closes the map instead of opening options")
	# Escape on a stuck panel: three presses force everything closed and open the pause menu.
	rec.escape_times.clear()
	w.request_panel.show()
	p.enabled = false
	Input.action_press("forward")
	esc(); esc()
	await frames(1)
	check(w.request_panel.visible and not w.options_panel.visible, "stuck panel ignores single Escapes (baseline behaviour)")
	esc()
	await frames(1)
	check(not w.request_panel.visible and w.options_panel.visible and not Input.is_action_pressed("forward"), "third Escape within 2 s unsticks: overlays closed, keys released, pause menu open")
	check(rec.panics == 1, "panic counted once")
	# Quit always works: save failure no longer traps the player, and a second close quits.
	w.save_ok = false
	w.options_panel.request_quit()
	w.options_panel.confirm_quit()
	check(w.options_panel.visible and quit_calls[0] == 0, "baseline: Save and Quit with a failed save keeps the game open")
	rec.quit_now_button.pressed.emit()
	check(quit_calls[0] == 1, "Quit without saving quits immediately")
	w.save_ok = true
	rec.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(quit_calls[0] == 1, "first window close only shows the quit prompt")
	rec.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(quit_calls[0] == 2 and w.saves >= 2, "second window close while the prompt is up saves and quits")
	# Mouse/control recapture after an overlay closes without restoring it.
	w.options_panel.cancel_and_close()
	p.enabled = false
	w.inventory_panel.show()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 800: await frames(1)
	check(not p.enabled, "no recapture while an overlay is open")
	w.inventory_panel.hide()
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 800: await frames(1)
	check(p.enabled and rec.recaptures >= 1, "control is restored within the grace period once overlays close")
	# A key-binding capture keeps Escape for itself.
	w.open_options()
	w.options_panel.capture_action = "forward"
	rec.escape_times.clear()
	esc(); esc(); esc()
	await frames(1)
	check(rec.panics == 1 and w.options_panel.visible, "Escape during key-binding capture is left to the options panel")
	w.queue_free()
	await frames(2)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await test_grass()
	await test_recovery()
	print("TOWN_HALL_STALL_REPORT " + JSON.stringify(report))
	print("TOWN_HALL_STALL_TESTS " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
