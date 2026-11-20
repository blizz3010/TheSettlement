extends RefCounted
## Queue item 4 (b), visual-pass 39/45/206/221 and the lake edge: grass met paving with a ruler-straight
## knife edge and no soil, and the lake shore was a hard line of lawn against the bank.
## Data: assets/p1_visual/grass_edges.json (raid/tools/bake_grass_edges.gd), one point every ~0.2 m
## on every grass/hard and grass/shore boundary, with the into-grass normal and ground heights.
## Built at runtime, render-only (no colliders, no route or walk change, nothing on the paving):
##   - an irregular soil/gravel lip: overlapping noisy patches 0.12-0.40 m into the lawn (shore:
##     0.3-0.75 m of wet bank), tucked under the paver edge where there is room;
##   - pebbles along the lip (mid-poly, half buried), reeds along the shore;
##   - the lawn blades over the lip are removed and the next 0.3 m are shortened, so the grass
##     edge itself becomes irregular. Only instance transforms change (count and order kept).
const DATA := "res://assets/p1_visual/grass_edges.json"
const NAME := "GrassEdgeLips"
const TILE := 12.0
const SEGMENTS := 10
const LIP_RANGE := 80.0
const PEBBLE_RANGE := 36.0
const REED_RANGE := 55.0
const FADE := 0.3

static func load_points() -> Array:
	if not FileAccess.file_exists(DATA): return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return d.points if d is Dictionary and d.has("points") else []

static func width(x: float, z: float, kind: int, noise: FastNoiseLite) -> float:
	var n := noise.get_noise_2d(x * 1.0, z * 1.0) * 0.5 + 0.5
	var n2 := noise.get_noise_2d(x * 4.3 + 17.0, z * 4.3) * 0.5 + 0.5
	if kind == 1: return lerpf(0.30, 0.75, n * 0.7 + n2 * 0.3)
	return lerpf(0.12, 0.40, n * 0.75 + n2 * 0.25)

static func material(kind: int) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = load("res://assets/p1_visual/edge_soil.gdshader")
	if kind == 1:
		m.set_shader_parameter("soil_a", Color(0.27, 0.23, 0.17)); m.set_shader_parameter("soil_b", Color(0.38, 0.33, 0.25))
		m.set_shader_parameter("wet", 0.45); m.set_shader_parameter("grit_amount", 0.55)
	return m

static func pebble_mesh(seed: int) -> ArrayMesh:
	# subdivided octahedron (128 tris) with a noisy radius, flattened: a mid-poly river pebble
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var tris := [[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.UP, Vector3.BACK, Vector3.LEFT], [Vector3.UP, Vector3.LEFT, Vector3.FORWARD], [Vector3.UP, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.LEFT, Vector3.BACK], [Vector3.DOWN, Vector3.FORWARD, Vector3.LEFT], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD]]
	for l in 2:
		var nt := []
		for t in tris:
			var a: Vector3 = t[0]; var b: Vector3 = t[1]; var c: Vector3 = t[2]
			var ab := ((a + b) * 0.5).normalized(); var bc := ((b + c) * 0.5).normalized(); var ca := ((c + a) * 0.5).normalized()
			nt.append_array([[a, ab, ca], [ab, b, bc], [ca, bc, c], [ab, bc, ca]])
		tris = nt
	var noise := FastNoiseLite.new(); noise.seed = seed; noise.frequency = 1.3
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in tris:
		for v in [t[0], t[2], t[1]]:
			var r := 1.0 + noise.get_noise_3dv(v * 1.7) * 0.28
			st.add_vertex(Vector3(v.x * r * 1.15, v.y * r * 0.55, v.z * r))
	st.generate_normals()
	return st.commit()

static func reed_mesh() -> ArrayMesh:
	# seven tapered, curved blades, 4 segments each (8 tris per blade), double-sided material
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new(); rng.seed = 91
	for b in 7:
		var ang := TAU * b / 7.0 + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x)
		var h := rng.randf_range(0.55, 1.0)
		var lean := rng.randf_range(0.1, 0.35)
		var base := dir * rng.randf_range(0.0, 0.06)
		var prev_l := Vector3.ZERO; var prev_r := Vector3.ZERO
		for s in 5:
			var t := s / 4.0
			var c := base + Vector3(0, h * t, 0) + dir * lean * t * t
			var w := 0.018 * (1.0 - t) + 0.002
			var l := c - side * w; var r := c + side * w
			if s > 0:
				for v in [prev_l, prev_r, r, prev_l, r, l]:
					st.set_color(Color(0.36 + 0.2 * t, 0.42 + 0.15 * t, 0.2, 1)); st.add_vertex(v)
			prev_l = l; prev_r = r
	st.generate_normals()
	return st.commit()

## Pulls a rim vertex back so it lies at most `tuck` past the nearest edge point of its kind.
static func keep_off_hard(q: Vector2, kind: int, tuck: float, pts: Array, cell: Dictionary) -> Vector2:
	for it in 4:
		var best := INF; var bn := Vector2.ZERO; var bdn := 0.0
		var key := Vector2i(floori(q.x), floori(q.y))
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var lst = cell.get(key + Vector2i(dx, dz))
				if lst == null: continue
				for j in lst:
					var p: Array = pts[j]
					if int(p[5]) != kind: continue
					var d := Vector2(q.x - p[0], q.y - p[2])
					var dd := d.length_squared()
					if dd < best:
						best = dd; bn = Vector2(p[3], p[4]); bdn = d.dot(bn)
		if best == INF or bdn >= -tuck: return q
		q += bn * (-tuck - bdn + 0.002)
	return q

static func install(world: Node3D) -> Dictionary:
	var pts := load_points()
	if pts.is_empty(): return {"ok": false, "reason": "no bake data"}
	if world.has_node(NAME):
		# second startup pass (staged start): keep the built lips, trim only batches added since
		var old: Node = world.get_node(NAME)
		var prev: Dictionary = old.get_meta("grass_edge_lips", {})
		var again := trim_grass(world, pts, old.get_meta("lip_widths", PackedFloat32Array()))
		for k in again: prev[k] = int(prev.get(k, 0)) + int(again[k])
		old.set_meta("grass_edge_lips", prev)
		return prev
	var t0 := Time.get_ticks_usec()
	var root := Node3D.new(); root.name = NAME; world.add_child(root)
	var noise := FastNoiseLite.new(); noise.seed = 4; noise.frequency = 0.9
	var rng := RandomNumberGenerator.new(); rng.seed = 20261119
	var tiles := {}      # Vector3i(tx, tz, kind) -> SurfaceTool
	var pebbles := {}    # Vector2i tile -> Array[Transform3D, Color]
	var reeds := {}
	var widths := PackedFloat32Array(); widths.resize(pts.size())
	var cell := {}   # 1 m hash of edge points, used to keep patch rims off the paving at corners
	for j in pts.size():
		var ck := Vector2i(floori(pts[j][0]), floori(pts[j][2]))
		if not cell.has(ck): cell[ck] = PackedInt32Array()
		cell[ck].append(j)
	var stats := {"points": pts.size(), "patches": 0, "pebbles": 0, "reeds": 0}
	for i in pts.size():
		var p: Array = pts[i]
		var e := Vector2(p[0], p[2]); var n := Vector2(p[3], p[4]); var t := Vector2(-n.y, n.x)
		var kind: int = p[5]
		var gy: float = p[1]; var hard_top: float = p[6]; var gy_in: float = p[7] if p.size() > 7 else gy
		var reach := 0.8 if kind == 1 else 0.45
		var w := width(e.x, e.y, kind, noise)
		widths[i] = w
		var room := hard_top - gy
		var tuck := 0.05 if (kind == 0 and room > 0.035) else (0.12 if kind == 1 else 0.0)
		var lift := clampf(room - 0.012, 0.004, 0.014) if kind == 0 else 0.012
		var along := rng.randf_range(0.17, 0.26)
		var half := (w + tuck) * 0.5
		var c := keep_off_hard(e + n * (half - tuck), kind, 0.0, pts, cell)
		var key := Vector3i(floori(e.x / TILE), floori(e.y / TILE), kind)
		if not tiles.has(key):
			var s := SurfaceTool.new(); s.begin(Mesh.PRIMITIVE_TRIANGLES); tiles[key] = s
		var st: SurfaceTool = tiles[key]
		var ring := []
		for k in SEGMENTS:
			var a := TAU * k / SEGMENTS
			var r := 1.0 + noise.get_noise_2d(c.x * 7.0 + k * 3.1, c.y * 7.0) * 0.32
			var o := t * cos(a) * along * r + n * sin(a) * half * r
			var q := keep_off_hard(c + o, kind, tuck, pts, cell)
			var d_in := clampf(o.dot(n) + (half - tuck), 0.0, reach)
			var y := lerpf(gy, gy_in, d_in / reach) + lift
			var edge_side := o.dot(n) < 0.0
			ring.append([Vector3(q.x, y if not edge_side else minf(y, gy + lift), q.y), 1.0 - clampf(o.dot(n) / maxf(half, 0.01), 0.0, 1.0) * 0.9])
		var cy := lerpf(gy, gy_in, clampf(half - tuck, 0.0, reach) / reach) + lift + 0.006
		for k in SEGMENTS:
			var a2: Array = ring[k]; var b2: Array = ring[(k + 1) % SEGMENTS]
			st.set_normal(Vector3.UP); st.set_color(Color(1, 1, 1, 1.0)); st.add_vertex(Vector3(c.x, cy, c.y))
			st.set_color(Color(1, 1, 1, b2[1])); st.add_vertex(b2[0])
			st.set_color(Color(1, 1, 1, a2[1])); st.add_vertex(a2[0])
		stats.patches += 1
		var tk := Vector2i(key.x, key.y)
		var chance := 0.8 if kind == 1 else 0.4
		while rng.randf() < chance:
			chance -= 0.5
			var off := e + n * rng.randf_range(0.0, w * 0.85) + t * rng.randf_range(-0.12, 0.12)
			var sc := rng.randf_range(0.04, 0.12) if kind == 1 else rng.randf_range(0.025, 0.07)
			var yy := lerpf(gy, gy_in, clampf((off - e).dot(n), 0.0, reach) / reach) + lift
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc))
			if not pebbles.has(tk): pebbles[tk] = []
			var tone := rng.randf_range(0.72, 1.0)
			pebbles[tk].append([Transform3D(b, Vector3(off.x, yy + sc * 0.12, off.y)), Color(tone * 0.93, tone * 0.9, tone * 0.84)])
			stats.pebbles += 1
		if kind == 1 and rng.randf() < 0.22:
			var off2 := e + n * rng.randf_range(-0.05, 0.35) + t * rng.randf_range(-0.1, 0.1)
			var s2 := rng.randf_range(0.7, 1.25)
			if not reeds.has(tk): reeds[tk] = []
			reeds[tk].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s2, s2, s2)), Vector3(off2.x, gy - 0.02, off2.y)))
			stats.reeds += 1
	var mats := [material(0), material(1)]
	for key in tiles:
		var st: SurfaceTool = tiles[key]
		var mi := MeshInstance3D.new(); mi.name = "Lip_%d_%d_%s" % [key.x, key.y, "shore" if key.z == 1 else "path"]
		mi.mesh = st.commit(); mi.material_override = mats[key.z]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = LIP_RANGE
		root.add_child(mi)
	var pm := pebble_mesh(7)
	var pmat := StandardMaterial3D.new(); pmat.albedo_color = Color(0.62, 0.6, 0.55); pmat.roughness = 0.85; pmat.vertex_color_use_as_albedo = true
	for tk in pebbles:
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = pm
		var arr: Array = pebbles[tk]; mm.instance_count = arr.size()
		for j in arr.size():
			mm.set_instance_transform(j, arr[j][0]); mm.set_instance_color(j, arr[j][1])
		var mmi := MultiMeshInstance3D.new(); mmi.name = "Pebbles_%d_%d" % [tk.x, tk.y]; mmi.multimesh = mm; mmi.material_override = pmat
		mmi.visibility_range_end = PEBBLE_RANGE; mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	var rm := reed_mesh()
	var rmat := StandardMaterial3D.new(); rmat.vertex_color_use_as_albedo = true; rmat.cull_mode = BaseMaterial3D.CULL_DISABLED; rmat.roughness = 0.8
	for tk in reeds:
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = rm
		var arr: Array = reeds[tk]; mm.instance_count = arr.size()
		for j in arr.size(): mm.set_instance_transform(j, arr[j])
		var mmi := MultiMeshInstance3D.new(); mmi.name = "Reeds_%d_%d" % [tk.x, tk.y]; mmi.multimesh = mm; mmi.material_override = rmat
		mmi.visibility_range_end = REED_RANGE
		root.add_child(mmi)
	var trim := trim_grass(world, pts, widths)
	stats.merge(trim)
	var tris := 0
	for c in root.get_children():
		if c is MeshInstance3D: tris += c.mesh.get_faces().size() / 3
		elif c is MultiMeshInstance3D: tris += c.multimesh.instance_count * c.multimesh.mesh.get_faces().size() / 3
	stats["tris"] = tris
	stats["nodes"] = root.get_child_count()
	stats["build_ms"] = snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.1)
	stats["ok"] = true
	root.set_meta("lip_widths", widths)
	root.set_meta("grass_edge_lips", stats)
	return stats

## Blade batches: the plaza composition grass (before GrassViewCulling splits it) and the
## continuous lawn chunks. Blades on the lip are zero-scaled, the next FADE m are shortened.
static func grass_batches(world: Node3D, include_split := false) -> Array:
	var out := []
	for rootname in ["PlazaIslandComposition", "ContinuousGrass"]:
		var r := world.get_node_or_null(rootname)
		if r == null: continue
		for n in r.find_children("*", "MultiMeshInstance3D", true, false):
			var mm: MultiMesh = n.multimesh
			if mm == null or mm.mesh == null or mm.instance_count < 64 or mm.transform_format != MultiMesh.TRANSFORM_3D: continue
			if n.has_meta("grass_view_culling_split") and not include_split: continue
			if n.has_meta("p1_trimmed") and not include_split: continue
			var mat = n.material_override
			var code := ""
			if mat is ShaderMaterial and mat.shader: code = mat.shader.resource_path
			if not (code.contains("grass") or code.contains("blades") or str(n.name).to_lower().contains("grass") or str(n.name).begins_with("Lawn")): continue
			out.append(n)
	return out

static func trim_grass(world: Node3D, pts: Array, widths: PackedFloat32Array) -> Dictionary:
	var hash := {}
	for i in pts.size():
		var k := Vector2i(floori(pts[i][0] / 0.5), floori(pts[i][2] / 0.5))
		if not hash.has(k): hash[k] = PackedInt32Array()
		hash[k].append(i)
	var near := {}
	for k in hash:
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]: near[k + Vector2i(dx, dz)] = true
	var hidden := 0; var shortened := 0; var seen := 0; var batches := 0
	for n in grass_batches(world):
		var mm: MultiMesh = n.multimesh
		var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
		var buf: PackedFloat32Array = mm.buffer
		var meta := false
		if buf.is_empty() and mm.has_meta("grass_view_culling_buffer"): buf = mm.get_meta("grass_view_culling_buffer"); meta = true
		if buf.size() != mm.instance_count * stride: continue
		var xf: Transform3D = n.global_transform
		var bb: AABB = xf * n.get_aabb()
		# quick reject: no edge point within the batch footprint
		var any := false
		for kx in range(floori((bb.position.x - 1.0) / 0.5), floori((bb.end.x + 1.0) / 0.5) + 1):
			for kz in range(floori((bb.position.z - 1.0) / 0.5), floori((bb.end.z + 1.0) / 0.5) + 1):
				if hash.has(Vector2i(kx, kz)): any = true; break
			if any: break
		n.set_meta("p1_trimmed", true)
		if not any: continue
		batches += 1
		var changed := false
		var ident := xf.is_equal_approx(Transform3D.IDENTITY)
		for i in mm.instance_count:
			var o := i * stride
			var w := Vector3(buf[o + 3], buf[o + 7], buf[o + 11])
			if not ident: w = xf * w
			var ck := Vector2i(floori(w.x * 2.0), floori(w.z * 2.0))
			if not near.has(ck): continue
			var best := INF; var best_dn := 0.0; var best_w := 0.0
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var lst = hash.get(ck + Vector2i(dx, dz))
					if lst == null: continue
					for j in lst:
						var p: Array = pts[j]
						var dxz := Vector2(w.x - p[0], w.z - p[2])
						var dd := dxz.length_squared()
						if dd < best:
							best = dd; best_dn = dxz.dot(Vector2(p[3], p[4])); best_w = widths[j]
			if best == INF: continue
			seen += 1
			var f := 1.0
			if best_dn < best_w - 0.03: f = 0.0
			elif best_dn < best_w + FADE: f = lerpf(0.45, 1.0, (best_dn - best_w + 0.03) / (FADE + 0.03))
			if f >= 0.999: continue
			if f <= 0.0:
				for q in 12: if q != 3 and q != 7 and q != 11: buf[o + q] = 0.0
				hidden += 1
			else:
				# shorten the blade: scale the basis Y column (offsets 1, 5, 9)
				buf[o + 1] *= f; buf[o + 5] *= f; buf[o + 9] *= f
				shortened += 1
			changed = true
		if changed:
			if meta: mm.set_meta("grass_view_culling_buffer", buf)
			else: mm.buffer = buf
	return {"grass_batches_touched": batches, "blades_near_edges": seen, "blades_hidden": hidden, "blades_shortened": shortened}
