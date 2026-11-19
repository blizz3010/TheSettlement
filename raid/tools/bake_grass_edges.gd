extends SceneTree
## Queue item 4 (b) bake: where the settlement's grass meets a hard surface or the lake shore.
## Run rendered from the repo root (the Play-flow world does not load headless):
##   xvfb-run -a -s "-screen 0 1440x900x24" godot --path . --rendering-driver opengl3 \
##     -s res://raid/tools/bake_grass_edges.gd
## Run it with SETTLEMENT_P1_VISUAL=off so the lips themselves are not sampled.
## Writes res://assets/p1_visual/grass_edges.json, read at runtime by raid/scripts/grass_edge_lips.gd.
## Method: mirror the visible near-ground surfaces into a private physics space; on a 0.25 m grid
## classify each cell by stacked down rays (lowest hit = ground; a flat surface <= 0.45 m above
## it = cover); a cell is G (turf: bare lawn/terrain or blades/ferns over it), H (paving, stone,
## pad, treads) or S (lake shore apron). Every G cell next to an H or S cell gives one edge point,
## refined by bisection to ~5 mm, with a normal fitted to its neighbours and pointing into grass.
const OUT := "res://assets/p1_visual/grass_edges.json"
const STEP := 0.25
const REGIONS := [Rect2(-32, -36, 72, 76), Rect2(-60, 40, 120, 35)]
const HARD := ["route_limestone", "courtyard_surface", "rook_quiet", "Basin_Stone", "fountain_contact", "PadStone", "peripheral_surface", "ApproachTread"]
const SKIP_COVER := ["Kerb", "small_rock", "Basement", "Descending", "Tailor"]
var world
var space: RID
var info := {}
var keep := []
var st: PhysicsDirectSpaceState3D

func _initialize(): call_deferred("run")

func boot():
	root.size = Vector2i(1440, 900)
	var Session = load("res://scripts/character_profiles/title_session.gd")
	var Rules = load("res://scripts/character_profiles/experimental_rules.gd")
	var session = Session.new(); session.rules = Rules.data()
	var state = session.inspect()
	if state.screen == "create":
		session.create_character("slot_1", {"name": "Baker", "cheek": 0.0, "hair": "hair_short02_v1", "brows": "brow_009_v1", "eyes": "eye_brown_v1", "hair_tint": "natural"}, {"str": 7, "int": 7, "dex": 7}, [], state.bytes, false)
		session.cancel()
	var title = (load("res://raid/play_title.tscn") as PackedScene).instantiate()
	root.add_child(title); current_scene = title
	for i in 10: await process_frame
	title.play_button.pressed.emit()
	for i in 10: await process_frame
	title.character_panel.cards["slot_1"].pressed.emit()
	for i in 10: await process_frame
	title.character_panel.enter_button.pressed.emit()
	while true:
		var sc = current_scene
		if sc != null and sc.get("world_activated") == true and sc.get("world_initialized") == true: break
		await process_frame
	world = current_scene

func skip(n: Node) -> bool:
	var p := n
	while p != null and p != world:
		if p is CanvasLayer or p is SubViewport or p == world.player: return true
		if str(p.name) in ["DomeSurface", "AmbientWildlife", "ValleyBackdrop", "GrassEdgeLips", "HallStairwellFinish", "HallThresholdFinish"]: return true
		p = p.get_parent()
	return false

func key_of(gi: GeometryInstance3D, mesh: Mesh, s: int) -> String:
	var m: Material = gi.material_override
	if m == null and gi is MeshInstance3D: m = gi.get_active_material(s)
	if m == null: m = mesh.surface_get_material(s)
	var mk := "none"
	if m is ShaderMaterial and m.shader: mk = "sh:" + m.shader.resource_path.get_file() + ":" + m.resource_name
	elif m is StandardMaterial3D: mk = "std:" + m.resource_name
	elif m: mk = m.get_class()
	return str(world.get_path_to(gi)) + "|" + mk

func faces(mesh: Mesh, s: int, t: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	if mesh is ArrayMesh and mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES: return out
	var a := mesh.surface_get_arrays(s)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx = a[Mesh.ARRAY_INDEX]
	if idx != null and idx.size() > 0:
		for i in idx: out.append(t * v[i])
	else:
		for p in v: out.append(t * p)
	return out

func add(f: PackedVector3Array, k: String):
	if f.size() < 3: return
	var sh := ConcavePolygonShape3D.new(); sh.set_faces(f); sh.backface_collision = true
	var b := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(b, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_add_shape(b, sh.get_rid())
	PhysicsServer3D.body_set_space(b, space)
	keep.append(sh); info[b] = k

func mirror():
	space = PhysicsServer3D.space_create(); PhysicsServer3D.space_set_active(space, true)
	var region := AABB(Vector3(-62, -4, -40), Vector3(124, 14, 117))
	for gi in world.find_children("*", "GeometryInstance3D", true, false):
		if not gi.is_visible_in_tree() or skip(gi): continue
		if gi is MeshInstance3D and gi.mesh:
			var bb: AABB = gi.global_transform * gi.get_aabb()
			if not bb.intersects(region) or bb.size.y > 14 or bb.position.y > 6: continue
			for s in gi.mesh.get_surface_count(): add(faces(gi.mesh, s, gi.global_transform), key_of(gi, gi.mesh, s))
		elif gi is MultiMeshInstance3D and gi.multimesh and gi.multimesh.mesh and gi.multimesh.instance_count <= 6000 and gi.multimesh.mesh.get_aabb().size.y < 0.35:
			var bb: AABB = gi.global_transform * gi.get_aabb()
			if not bb.intersects(region): continue
			var mm: MultiMesh = gi.multimesh
			for s in mm.mesh.get_surface_count():
				var f := PackedVector3Array()
				for i in (mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count):
					f.append_array(faces(mm.mesh, s, gi.global_transform * mm.get_instance_transform(i)))
				add(f, key_of(gi, mm.mesh, s))

## [class, ground y, cover y]; class "G", "H", "S" or "" (other / nothing)
func classify(x: float, z: float) -> Array:
	var hits := []
	var ex := []
	for k in 10:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 10, z), Vector3(x, -4, z)); q.exclude = ex
		var h := st.intersect_ray(q)
		if h.is_empty(): break
		hits.append([h.position.y, info.get(h.rid, "?"), h.normal.y])
		ex.append(h.rid)
	if hits.is_empty(): return ["", 0.0, 0.0]
	var low = hits[hits.size() - 1]
	var cover = null
	for i in range(hits.size() - 2, -1, -1):
		var hh = hits[i]
		if hh[0] - low[0] <= 0.45 and hh[2] > 0.85: cover = hh
		else: break
	var lk: String = low[1]
	if cover == null:
		if lk.contains("lake_bank"): return ["S", low[0], low[0]]
		if lk.contains("continuous_lawn") or lk.contains("rook_ground_finish"): return ["G", low[0], low[0]]
		return ["", low[0], low[0]]
	var ck: String = cover[1]
	for s in SKIP_COVER: if ck.contains(s): return ["", low[0], cover[0]]
	for s in HARD: if ck.contains(s): return ["H", low[0], cover[0]]
	if ck.contains("lake_bank"): return ["S", low[0], cover[0]]
	if ck.contains("continuous_blades") or ck.contains("Leaves") or ck.contains("Fern") or ck.contains("lawn") or ck.contains("rook_ground_finish") or ck.contains("GroundRelief") or ck.contains("LocalLakeBank"):
		return ["G", low[0], low[0]]
	return ["", low[0], cover[0]]

func run():
	await boot()
	print("BAKE: world up")
	mirror()
	await physics_frame; await physics_frame
	st = PhysicsServer3D.space_get_direct_state(space)
	var grid := {}
	var n := 0
	for r in REGIONS:
		var nx := int(r.size.x / STEP); var nz := int(r.size.y / STEP)
		for i in nx + 1:
			for j in nz + 1:
				var key := Vector2i(roundi((r.position.x + i * STEP) / STEP), roundi((r.position.y + j * STEP) / STEP))
				if grid.has(key): continue
				grid[key] = classify(key.x * STEP, key.y * STEP)
				n += 1
			if i % 40 == 0: await process_frame
	print("BAKE: classified ", n)
	var raw := []
	for key in grid:
		var c: Array = grid[key]
		if c[0] != "G": continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var o = grid.get(key + d)
			if o == null or not (o[0] == "H" or o[0] == "S"): continue
			# bisection between the grass cell centre and the other cell centre
			var a := Vector2(key) * STEP; var b := Vector2(key + d) * STEP
			for it in 6:
				var m := (a + b) * 0.5
				if classify(m.x, m.y)[0] == "G": a = m
				else: b = m
			var e := (a + b) * 0.5
			raw.append([e.x, e.y, c[1], o[2], -d.x, -d.y, 1 if o[0] == "S" else 0])
	print("BAKE: raw edge points ", raw.size())
	# thin to one point per 0.2 m cell per kind, then fit normals from neighbours within 0.6 m
	var thin := {}
	for p in raw:
		var k := "%d,%d,%d" % [roundi(p[0] / 0.2), roundi(p[1] / 0.2), p[6]]
		if not thin.has(k): thin[k] = p
	var pts: Array = thin.values()
	var hash := {}
	for i in pts.size():
		var hk := Vector2i(floori(pts[i][0]), floori(pts[i][1]))
		if not hash.has(hk): hash[hk] = []
		hash[hk].append(i)
	var out := []
	for i in pts.size():
		var p: Array = pts[i]
		var c := Vector2(p[0], p[1])
		var nb := []
		var hk := Vector2i(floori(c.x), floori(c.y))
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				for j in hash.get(hk + Vector2i(dx, dz), []):
					if pts[j][6] == p[6] and Vector2(pts[j][0], pts[j][1]).distance_to(c) < 0.6: nb.append(Vector2(pts[j][0], pts[j][1]))
		var nrm := Vector2(p[4], p[5])
		if nb.size() >= 3:
			var mean := Vector2.ZERO
			for v in nb: mean += v
			mean /= nb.size()
			var sxx := 0.0; var sxz := 0.0; var szz := 0.0
			for v in nb:
				var dv: Vector2 = v - mean
				sxx += dv.x * dv.x; sxz += dv.x * dv.y; szz += dv.y * dv.y
			var ang := 0.5 * atan2(2 * sxz, sxx - szz)
			var tangent := Vector2(cos(ang), sin(ang))
			var fit := Vector2(-tangent.y, tangent.x)
			if fit.dot(nrm) < 0: fit = -fit
			nrm = fit
		var reach := 0.8 if p[6] == 1 else 0.45
		var inner: Vector2 = c + nrm * reach
		var ci: Array = classify(inner.x, inner.y)
		var y_in: float = ci[1] if ci[0] == "G" else p[2]
		out.append([snappedf(c.x, 0.005), snappedf(p[2], 0.005), snappedf(c.y, 0.005), snappedf(nrm.x, 0.001), snappedf(nrm.y, 0.001), p[6], snappedf(p[3], 0.005), snappedf(y_in, 0.005)])
		if i % 400 == 0: await process_frame
	out.sort_custom(func(a, b): return a[0] * 1000 + a[2] < b[0] * 1000 + b[2])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "step": STEP, "fields": ["x", "ground_y", "z", "nx_into_grass", "nz_into_grass", "kind_0path_1shore", "hard_top_y", "ground_y_inside (0.45 m path / 0.8 m shore into grass)"], "points": out}))
	f.close()
	var kinds := [0, 0]
	for p in out: kinds[p[5]] += 1
	print("BAKE: wrote ", out.size(), " points (path ", kinds[0], ", shore ", kinds[1], ") to ", OUT)
	quit(0)
