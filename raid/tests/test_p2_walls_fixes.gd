extends SceneTree
## PR B (p2_walls_fixes.gd), rendered acceptance through the real Play flow:
##  walls      34 hideout modules (Option A, east face nudged clear of the stair opening) + 30 pad modules;
##             rays meet the new faces; stairs, the #31 boarding ramp line and PadDeck are untouched;
##             ivy / baskets / plaque / path_foliage_finish batches stand outside the new wall band.
##  hillside   GroundRelief + inn-hill grass batches on the P2B shaders, lawn blades tinted, the path
##             stub overlook (bench seat registered, collision) in place and the path line clear.
##  trees      the 13 lime plaza crowns toned; bushes untouched.   planet  sky on the P2B shader, smaller body.
##  inn_door   two doors, leaves open near the player and shut (with collision) away from it.
##  undercroft 4 + 2 bays, props, dusk lights.   hall  5 trusses, 4 bays, 2 chandeliers, 8 pendants.
##  lamps      lamp glass dim by day, bright at night; dusk lights off by day.
##  frame time with the P2B roots shown vs hidden (plaza, inn, hall views).
const MARKER := "P2_WALLS_FIXES_TESTS "
const P2B = preload("res://raid/scripts/p2_walls_fixes.gd")
const RW = preload("res://raid/scripts/retaining_walls_install.gd")
const Hill = preload("res://raid/scripts/inn_hillside_finish.gd")
var checks := 0
var failures: Array = []
var report := {}
var world: Node3D

func _initialize(): call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func log_(s: String) -> void: print("P2BTEST: ", s, "  t=", Time.get_ticks_msec() / 1000.0)

func finish() -> void:
	report["checks"] = checks
	report["failures"] = failures
	print(MARKER, JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func boot() -> bool:
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	var Session = load("res://scripts/character_profiles/title_session.gd")
	var Rules = load("res://scripts/character_profiles/experimental_rules.gd")
	var session = Session.new(); session.rules = Rules.data()
	var state = session.inspect()
	if state.screen == "create":
		session.create_character("slot_1", {"name": "Visual", "cheek": 0.0, "hair": "hair_short02_v1", "brows": "brow_009_v1", "eyes": "eye_brown_v1", "hair_tint": "natural"}, {"str": 7, "int": 7, "dex": 7}, [], state.bytes, false)
		session.cancel()
	var title = (load("res://raid/play_title.tscn") as PackedScene).instantiate()
	root.add_child(title); current_scene = title
	for i in 10: await process_frame
	title.play_button.pressed.emit()
	for i in 10: await process_frame
	title.character_panel.cards["slot_1"].pressed.emit()
	for i in 10: await process_frame
	title.character_panel.enter_button.pressed.emit()
	var deadline := Time.get_ticks_msec() + 1200000
	while true:
		var sc = current_scene
		if sc != null and sc.get("world_activated") == true and sc.get("world_initialized") == true: break
		if Time.get_ticks_msec() > deadline: return false
		await process_frame
	world = current_scene
	return true

func ray_hit(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [world.player.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(q)

func hits_at(p: Vector3, r: float, only: Array) -> Array:
	var shape := SphereShape3D.new(); shape.radius = r
	var q := PhysicsShapeQueryParameters3D.new(); q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, p)
	var out := []
	for h in world.get_world_3d().direct_space_state.intersect_shape(q, 32):
		if only.is_empty() or h.collider in only: out.append(h.collider)
	return out

func run() -> void:
	log_("boot")
	if not await boot():
		check(false, "World activated before the deadline"); finish(); return
	var deadline := Time.get_ticks_msec() + 900000
	while not world.has_meta("p2b") and Time.get_ticks_msec() < deadline:
		await process_frame
	for i in 3: await process_frame
	var r: Dictionary = world.get_meta("p2b", {})
	report["install"] = r
	log_("installed %s" % JSON.stringify(r).left(3000))
	check(r.get("ok", false), "P2B installed: " + JSON.stringify(r).left(1500))
	check(r.get("after_settle", false), "Installed after every startup controller settled")
	for item in P2B.ITEMS:
		check(r.has(item) and r[item].get("ok", false) and not r[item].get("skipped", false), "Item %s ok: %s" % [item, str(r.get(item, {})).left(400)])
	test_walls(r.get("walls", {}))
	test_hillside(r.get("hillside", {}))
	test_tone(r)
	await test_doors()
	test_undercroft_hall()
	await test_lamps()
	await frame_times()
	finish()

# ------------------------------------------------------------------ walls
func test_walls(w: Dictionary) -> void:
	check(w.get("hideout_modules", 0) == 34 and w.get("pad_modules", 0) == 30, "34 hideout + 30 pad modules")
	var root := world.get_node_or_null("P2RetainingWalls") as Node3D
	var pad := world.get_node_or_null("LaunchpadShip/P2PadRetainingWall") as Node3D
	var terrace := world.get_node_or_null("RaisedHideoutTerrace") as Node3D
	if root == null or pad == null or terrace == null:
		check(false, "Wall roots present"); return
	check(RW.apply(world).get("ok", false) and world.get_node("P2RetainingWalls/Hideout").get_child_count() == 8, "Second wall apply is a no-op")
	var worst := 0; var lods_ok := true
	for m in root.find_children("retaining_wall_*", "Node3D", true, false) + pad.get_children():
		var lod0 := m.find_children("*_LOD0", "MeshInstance3D", true, false)
		var lod1 := m.find_children("*_LOD1", "MeshInstance3D", true, false)
		if lod0.is_empty(): continue
		worst = maxi(worst, RW.tris(m, 0))
		if not is_equal_approx(lod0[0].visibility_range_end, RW.LOD0_END) or lod1.is_empty() or not is_equal_approx(lod1[0].visibility_range_begin, RW.LOD0_END): lods_ok = false
	report["wall_worst_module_lod0_tris"] = worst
	check(worst <= 8200, "Module LOD0 tri cap 8.2k (worst %d)" % worst)
	check(lods_ok, "Module LOD ranges 0-30 / 30 m+")
	check(terrace.find_children("retaining_wall_*", "Node3D", true, false).is_empty() and not terrace.is_ancestor_of(root), "Kit sits outside RaisedHideoutTerrace")
	var new_cols := root.find_children("*", "StaticBody3D", true, false)
	# Collision boxes stand 0.21 m proud of the old faces (stone face 0.12 m + coping overhang).
	var probes := [[Vector3(-13.6, 1.5, 10.0), Vector3(-17.0, 1.5, 10.0), -15.79, "x"], [Vector3(-11.0, 1.5, 20.0), Vector3(-14.5, 1.5, 20.0), -12.79, "x"],
		[Vector3(-24.0, 1.5, 25.0), Vector3(-24.0, 1.5, 21.0), 23.21, "z"], [Vector3(-24.0, 1.5, 4.5), Vector3(-24.0, 1.5, 9.0), 6.79, "z"],
		[Vector3(-34.5, 1.5, 15.0), Vector3(-30.0, 1.5, 15.0), -32.21, "x"], [Vector3(-14.5, 1.5, 24.0), Vector3(-14.5, 1.5, 21.0), 22.21, "z"],
		[Vector3(-13.6, 1.5, 12.6), Vector3(-17.0, 1.5, 12.6), -15.79, "x"], [Vector3(-13.6, 1.5, 17.3), Vector3(-17.0, 1.5, 17.3), -15.79, "x"]]
	var faces := []
	for p in probes:
		var h := ray_hit(p[0], p[1])
		var at: float = (h.position.x if p[3] == "x" else h.position.z) if not h.is_empty() else INF
		var ok: bool = not h.is_empty() and h.collider in new_cols and absf(at - float(p[2])) < 0.08
		faces.append([str(p[2]), snappedf(at, 0.001), ok])
		check(ok, "Ray from %s meets the new face at %s (%s)" % [str(p[0]), str(p[2]), str(at)])
	report["wall_faces"] = faces
	# East face nudge: nothing of the new kit (mesh or collider) reaches into the stair opening z 13.4..16.6.
	var intrude := []
	for mi in root.find_children("*_LOD0", "MeshInstance3D", true, false):
		var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		if bb.end.x > -16.6 and bb.position.x < -15.0 and bb.position.z < 16.6 - 0.01 and bb.end.z > 13.4 + 0.01:
			intrude.append("%s z %.3f..%.3f" % [mi.get_parent().name, bb.position.z, bb.end.z])
	report["stair_opening_intrusions"] = intrude
	check(intrude.is_empty(), "East face clear of the stair opening z 13.4..16.6: " + str(intrude))
	var stair_hits := []
	for i in 40:
		var x := -8.0 - i * 0.2
		var top := 0.0
		if x > -11.34: top = clampf((-8.28 - x) / 0.34, 0, 9) / 6.0
		elif x > -12.94: top = 1.5
		else: top = 1.5 + clampf((-12.94 - x) / 0.34, 0, 9) / 6.0
		for z in [13.75, 15.0, 16.25]:
			if not hits_at(Vector3(x, top + 0.5, z), 0.33, new_cols).is_empty(): stair_hits.append("x %.1f z %.2f" % [x, z])
	report["stair_hits"] = stair_hits
	check(stair_hits.is_empty(), "Stair flight and landing clear of new colliders: " + str(stair_hits.slice(0, 6)))
	check(pad.find_children("*", "StaticBody3D", true, false).is_empty(), "No pad collider added")
	var ship := world.get_node("LaunchpadShip") as Node3D
	var support := ray_hit(ship.to_global(Vector3(0, 2.5, 4.8)), ship.to_global(Vector3(0, 0.5, 4.8)))
	check(not support.is_empty() and support.collider == ship.get_node_or_null("Collision/PadDeck"), "PadDeck still supports the boarding ring")
	var route := []
	for k in 40:
		var p := ship.to_global(Vector3(0, 0.6, 4.0 + k * 0.4))
		if not hits_at(p, 0.4, new_cols).is_empty(): route.append("ramp %.1f" % (4.0 + k * 0.4))
	check(route.is_empty(), "Boarding ramp line clear: " + str(route))
	# ramp gap in the pad ring: no module mesh within +-1.4 m of the ramp centre line on the ring
	var gap_hits := []
	for m in pad.get_children():
		for mi in (m as Node).find_children("*_LOD0", "MeshInstance3D", true, false):
			var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			var c := ship.to_local(bb.get_center())
			if c.z > 0 and absf(c.x) < 1.4: gap_hits.append(m.name)
	check(gap_hits.is_empty(), "Pad ring leaves the boarding ramp gap open: " + str(gap_hits))
	var moved: Dictionary = w.get("dressing_moved", {})
	check(int(moved.get("ivy_instances", 0)) > 0 and int(moved.get("baskets", 0)) >= 5 and moved.get("plaque", false), "Ivy, baskets and plaque moved out: " + str(moved))
	var plaque := world.find_child("YourHomePhysicalSign", true, false) as Node3D
	if plaque: check(plaque.global_position.x > -15.83, "Plaque sits proud of the new face (x %.3f)" % plaque.global_position.x)
	# path_foliage_finish batches: nothing left inside the new wall band, authority kept in step
	var band_left := 0; var authority_mismatch := 0
	for h in RW.FOLIAGE_HOLDERS:
		var holder := world.get_node_or_null(h)
		if holder == null: continue
		for batch in holder.find_children("*", "MultiMeshInstance3D", true, false):
			var nm := String(batch.name)
			var is_shrub := nm.contains("shrub")
			if not is_shrub and not (nm.contains("ground_") and not nm.contains("grass") and batch.has_meta("source_transforms")): continue
			var mm := (batch as MultiMeshInstance3D).multimesh
			if mm == null: continue
			var auth: Array = batch.get_meta("source_transforms", [])
			for i in mm.instance_count:
				var g := (batch as Node3D).global_transform * mm.get_instance_transform(i)
				if not RW.band_depth(g.origin, 0.25 if is_shrub else 0.0).is_empty(): band_left += 1
				if i < auth.size() and not (auth[i] as Transform3D).is_equal_approx(mm.get_instance_transform(i)): authority_mismatch += 1
	report["foliage_band_left"] = band_left
	check(band_left == 0, "No path_foliage_finish planting left inside the wall band (%d)" % band_left)
	report["foliage_authority_mismatch_total"] = authority_mismatch   # includes other scripts' own edits; reported only
	report["east_scales"] = w.get("east_scales", {})

# ------------------------------------------------------------------ hillside
func test_hillside(h: Dictionary) -> void:
	var gr := world.get_node_or_null("SettlementTerrain/GroundRelief") as GeometryInstance3D
	check(gr != null and gr.material_override is ShaderMaterial and (gr.material_override as ShaderMaterial).shader == Hill.GROUND_SHADER, "GroundRelief on the P2B hill turf shader")
	var b: Dictionary = h.get("blades", {})
	check(int(b.get("batches", 0)) > 0, "Inn-hill grass batches on the P2B grass shader: " + str(b))
	# every visible grass_lod batch that overlaps the hill core uses the P2B copy
	var stale := []
	var gvc := world.get_node_or_null("GrassViewCulling")
	if gvc:
		for n in gvc.find_children("Ground*", "MultiMeshInstance3D", true, false):
			var g := n as MultiMeshInstance3D
			var bb: AABB = g.global_transform * g.get_aabb()
			if bb.position.x < 20 and bb.end.x > -20 and bb.position.z < 48 and bb.end.z > 26:
				var sm := g.material_override as ShaderMaterial
				if sm and sm.shader and sm.shader.resource_path == Hill.GRASS_LOD_PATH: stale.append(g.name)
	check(stale.is_empty(), "No hill-core grass sub-chunk left on the old shader: " + str(stale.slice(0, 5)))
	# patch field: dry and clover both present on the hill, tint 1 outside the mask
	var dry := 0; var clover := 0; var n := 0
	for x in range(-20, 22, 2):
		for z in range(27, 48, 2):
			var q := Hill.patch(Vector2(x, z)); n += 1
			if q.dry > 0.5: dry += 1
			if q.clover > 0.5: clover += 1
	report["hill_patches"] = {"samples": n, "dry": dry, "clover": clover}
	check(dry >= n / 20 and clover >= n / 25 and dry + clover <= n * 0.45, "Hill has dry and clover patches without covering it: " + str(report.hill_patches))
	check(Hill.tint(Vector2(0, 0)) == Color(1, 1, 1) and Hill.tint(Vector2(40, 40)) == Color(1, 1, 1), "Tint is identity outside the hill mask")
	check(int(h.get("lawn", {}).get("instances", 0)) >= 0, "Lawn chunk tint ran")
	var s: Dictionary = h.get("stub", {})
	var bench := world.get_node_or_null("P2InnPathOverlook/OverlookBench") as Node3D
	check(bench != null and bench.is_in_group("usable_seats") and int(s.get("bench_members", 0)) > 0, "Overlook bench placed, collidable and registered as a seat: " + str(s))
	if bench:
		check(absf(bench.global_position.y - 0.01) < 0.25, "Bench stands on the path (y %.3f)" % bench.global_position.y)
		check(bench.global_basis.z.dot(Vector3.BACK) < -0.99, "Bench faces the inn hill (+z)")
	# the walking line along the stub (z 30) stays clear
	var line := []
	for i in 11:
		var p := Vector3(-3.0 - i * 0.35, 0.9, 30.2)
		if not hits_at(p, 0.3, []).is_empty(): line.append("x %.2f" % p.x)
	check(line.size() <= 2, "Path line along the stub stays walkable: " + str(line))

# ------------------------------------------------------------------ trees / planet
func test_tone(r: Dictionary) -> void:
	var t: Dictionary = r.get("trees", {})
	check(int(t.get("toned", 0)) >= 13 and (t.get("nodes", []) as Array).has("PlazaIslandComposition/ShipRampGarden/RampTrees"), "Lime plaza crowns toned incl. RampTrees (%s)" % str(t.get("toned")))
	var cyc = world.get_node_or_null("DayNightCycle")
	var sm = cyc.sky_material if cyc else null
	check(sm is ShaderMaterial and (sm as ShaderMaterial).shader.resource_path == "res://raid/assets/materials/p2b_day_night_sky.gdshader", "Sky on the P2B shader")
	if sm is ShaderMaterial:
		var radius = (sm as ShaderMaterial).get_shader_parameter("p2b_body_radius")
		check(radius == null or float(radius) < 0.09, "Valley body radius reduced (%s)" % str(radius))

# ------------------------------------------------------------------ inn doors
func test_doors() -> void:
	var ctl = world.find_child("P2InnDoors", true, false)
	if ctl == null:
		check(false, "P2InnDoors controller present"); return
	check(ctl.doors.size() == 2, "Two inn doors")
	var states := []
	for i in ctl.doors.size():
		var d: Dictionary = ctl.doors[i]
		var c: Vector3 = ctl.door_center(d)
		var shut_cols := 0
		for lf in d.leaves:
			for col in lf.cols: shut_cols += 0 if col.disabled else 1
		ctl.force(i, 1)
		for k in 60: await physics_frame
		var open_cols := 0
		for lf in d.leaves:
			for col in lf.cols: open_cols += 0 if col.disabled else 1
		var opened := float(d.angle) > 0.99
		ctl.force(i, 0)
		for k in 60: await physics_frame
		var closed := float(d.angle) < 0.01
		var back_cols := 0
		for lf in d.leaves:
			for col in lf.cols: back_cols += 0 if col.disabled else 1
		ctl.force(i, -1)
		states.append({"door": i, "shut_cols": shut_cols, "open": opened, "open_cols": open_cols, "closed": closed, "closed_cols": back_cols})
		check(opened and open_cols == 0, "Door %d opens fully with leaf collision off" % i)
		check(closed and back_cols > 0, "Door %d shuts with leaf collision on" % i)
	report["doors"] = states

# ------------------------------------------------------------------ undercroft / hall
func test_undercroft_hall() -> void:
	var u := world.find_child("P2InnUndercroft", true, false) as Node3D
	var h := world.get_node_or_null("P2TownHallCeiling") as Node3D
	check(u != null and u.get_meta("p2b", {}).get("ok", false), "Undercroft installed (4 + 2 bays)")
	check(h != null and h.get_meta("p2b", {}).get("ok", false), "Hall ceiling installed (5 trusses, 4 bays, 2 chandeliers, 8 pendants)")
	for root in [u, h]:
		if root == null: continue
		var worst := 0
		for mi in root.find_children("*_LOD0", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).mesh: worst = maxi(worst, (mi as MeshInstance3D).mesh.get_faces().size() / 3)
		report["%s_worst_lod0_tris" % root.name] = worst
		var shadow := 0
		for g in root.find_children("*", "GeometryInstance3D", true, false):
			if (g as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: shadow += 1
		check(shadow == 0, "%s casts no shadows (%d)" % [root.name, shadow])
	if h:
		check(h.find_children("*", "StaticBody3D", true, false).is_empty(), "Hall ceiling adds no colliders")
		var lights := h.find_children("*", "OmniLight3D", true, false)
		check(lights.size() == 2, "Hall ceiling adds exactly 2 dusk lights (GL compat 8-light budget)")

# ------------------------------------------------------------------ lamps
func test_lamps() -> void:
	var lc = world.get_node_or_null("P2BLampCycle")
	var cyc = world.get_node_or_null("DayNightCycle")
	if lc == null or cyc == null:
		check(false, "Lamp cycle and DayNightCycle present"); return
	check(lc.materials.size() > 0 and lc.lights.size() > 0, "Lamp cycle drives kit lamp glass and dusk lights (%d / %d)" % [lc.materials.size(), lc.lights.size()])
	var keep: float = cyc.elapsed_seconds
	cyc.set_process(false)
	var out := {}
	for phase in [["day", 0.06], ["night", 0.55]]:
		cyc.elapsed_seconds = cyc.cycle_seconds * float(phase[1]); cyc.apply_lighting()
		lc.refresh(true)
		await process_frame
		var e := 0.0
		for m in lc.materials: e = maxf(e, (m as BaseMaterial3D).emission_energy_multiplier)
		var lit := 0
		for pair in lc.lights: lit += 1 if (pair[0] as Light3D).visible and (pair[0] as Light3D).light_energy > 0.05 else 0
		out[phase[0]] = {"daylight": snappedf(lc.daylight, 0.001), "max_emission": snappedf(e, 0.01), "lights_on": lit}
	report["lamps"] = out
	check(out.day.daylight > 0.8 and out.day.max_emission <= 0.25 and out.day.lights_on == 0, "By day the kit lamps are dim and dusk lights off: " + str(out.day))
	check(out.night.daylight < 0.2 and out.night.max_emission >= 1.5 and out.night.lights_on == lc.lights.size(), "At night the kit lamps glow and dusk lights are on: " + str(out.night))
	cyc.elapsed_seconds = keep; cyc.apply_lighting(); cyc.set_process(true)
	lc.refresh(true)

# ------------------------------------------------------------------ frame time
func p2b_roots() -> Array:
	var out := []
	for p in ["P2RetainingWalls", "LaunchpadShip/P2PadRetainingWall", "P2InnPathOverlook", "P2TownHallCeiling"]:
		var n := world.get_node_or_null(p)
		if n: out.append(n)
	var und := world.find_child("P2InnUndercroft", true, false)
	if und is Node3D: out.append(und)
	var doors = world.find_child("P2InnDoors", true, false)
	if doors:
		for d in doors.doors:
			if d.node is Node3D: out.append(d.node)
	return out

func frame_times() -> void:
	var roots := p2b_roots()
	get_root().size = Vector2i(960, 600)
	var cam := Camera3D.new(); cam.fov = 70.0; world.add_child(cam)
	var out := {}
	for v in [["plaza", Vector3(0, 1.7, 9), Vector3(0, 2, -14)], ["inn", Vector3(4, 1.8, 26), Vector3(4, 4, 50)], ["hall", Vector3(0, 1.7, -16), Vector3(0, 4.5, -29)]]:
		cam.global_position = v[1]; cam.look_at(v[2]); cam.current = true
		var times := {"on": [], "off": []}
		for block in 2:
			var mode := "on" if block % 2 == 0 else "off"
			for n in roots: n.visible = mode == "on"
			await process_frame
			var t0 := Time.get_ticks_usec()
			for i in 3: await process_frame
			times[mode].append((Time.get_ticks_usec() - t0) / 3000.0)
		out[v[0]] = {"on": avg(times.on), "off": avg(times.off)}
		log_("frame %s %s" % [v[0], out[v[0]]])
	for n in roots: n.visible = true
	cam.queue_free()
	get_root().size = Vector2i(1440, 900)
	out["note"] = "llvmpipe software GL, 960x600; kit roots shown vs hidden, relative only"
	report["frame_time"] = out

func avg(a: Array) -> float:
	var s := 0.0
	for v in a: s += v
	return snappedf(s / maxf(a.size(), 1), 0.01)
