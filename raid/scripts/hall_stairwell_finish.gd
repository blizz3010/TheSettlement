extends RefCounted
## Queue item 4 (a), visual-pass 18/20/38/39: the Town Hall stairwell read as a raw hole in the floor.
## The basement stair cut (scripts/hall_basement_blockout.gd, pinned) clips the Hall floor's top faces
## and splits the old terrain slab around the aperture, so between the Hall floor (+0.24) and the
## basement ceiling (-0.80) the shaft walls are the split terrain boxes' green turf sides and the floor
## has no edge. The basement itself is finished and reachable, so the aperture is kept and finished:
##   - limestone shaft lining on all four sides (both lit layers), a bronze reveal at the ceiling line;
##   - a timber floor nosing around the aperture, flush (12 mm), no collision change;
##   - closed stairs: a sloped timber soffit under each descending flight, solid side stringers, and
##     a closed riser face on every tread;
##   - glass balustrade infill between the existing guard rails at floor level (rails unchanged).
## Visual only: no collider, route or step changes. CLOSE_SLAB = true instead lays a finished floor
## slab over the aperture and hides the descending stair (not the default: it would cut the basement off).
const Layout = preload("res://scripts/hall_shared_stair_layout.gd")
const F = preload("res://scripts/hall_basement_finish.gd")
const NAME := "HallStairwellFinish"
const CLOSE_SLAB := false
const FLOOR_Y := 0.24
const SHAFT_BOTTOM := -0.80
const LINING := 0.035
const INSET := 0.006
const LAYERS := 1 | 4096

static func add_box(st: SurfaceTool, c: Vector3, size: Vector3, basis := Basis()) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)], [Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)], [Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)]]
	for f in faces:
		var n: Vector3 = f[0]; var u: Vector3 = f[1]; var v: Vector3 = f[2]
		var o: Vector3 = n * h
		var du: Vector3 = u * h; var dv: Vector3 = v * h
		var q := [o - du - dv, o + du - dv, o + du + dv, o - du + dv]
		var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		var uscale := Vector2(absf((u * size).length()), absf((v * size).length()))
		for k in [0, 2, 1, 0, 3, 2]:
			st.set_normal(basis * n)
			st.set_uv(uv[k] * uscale)
			st.add_vertex(c + basis * q[k])

static func mesh_node(root: Node3D, n: String, st: SurfaceTool, m: Material) -> MeshInstance3D:
	st.generate_tangents()
	var mi := MeshInstance3D.new(); mi.name = n; mi.mesh = st.commit(); mi.material_override = m; mi.layers = LAYERS
	root.add_child(mi)
	return mi

static func begin() -> SurfaceTool:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); return st

static func install(world: Node3D) -> Dictionary:
	if world.has_node(NAME): return world.get_node(NAME).get_meta("hall_stairwell_finish", {"ok": true, "reused": true})
	if not world.has_node("HallBasementBlockout"): return {"ok": false, "reason": "no basement stairwell"}
	var root := Node3D.new(); root.name = NAME; world.add_child(root)
	var H: Rect2 = Layout.HOLE
	var x0 := H.position.x; var x1 := H.end.x; var z0 := H.position.y; var z1 := H.end.y
	var lime: Material = F.stone(Color("#b4a68a")); var timber: Material = F.plain(Color("#554333")); var bronze: Material = F.plain(Color("#8a714d"), .63)
	var glass := StandardMaterial3D.new(); glass.albedo_color = Color(0.78, 0.86, 0.84, 0.28); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; glass.roughness = 0.08; glass.metallic_specular = 0.7
	var stone := begin(); var wood := begin(); var metal := begin(); var pane := begin()
	var hgt := FLOOR_Y - SHAFT_BOTTOM
	var yc := (FLOOR_Y + SHAFT_BOTTOM) * 0.5
	var stats := {"lining_faces": 4, "risers": 0, "soffits": 0, "glass_panels": 0, "slab": CLOSE_SLAB}
	if CLOSE_SLAB:
		add_box(stone, Vector3(H.get_center().x, FLOOR_Y - 0.02, H.get_center().y), Vector3(H.size.x, 0.04, H.size.y))
		for n in world.get_node("HallBasementBlockout").find_children("Descending*", "", true, false): if n is Node3D: n.visible = false
	# 1. shaft lining, inner faces just inside the aperture so they cover the turf sides
	add_box(stone, Vector3(x0 + INSET - LINING * 0.5, yc, (z0 + z1) * 0.5), Vector3(LINING, hgt, H.size.y + 2 * LINING))
	add_box(stone, Vector3(x1 - INSET + LINING * 0.5, yc, (z0 + z1) * 0.5), Vector3(LINING, hgt, H.size.y + 2 * LINING))
	add_box(stone, Vector3((x0 + x1) * 0.5, yc, z0 + INSET - LINING * 0.5), Vector3(H.size.x, hgt, LINING))
	add_box(stone, Vector3((x0 + x1) * 0.5, yc, z1 - INSET + LINING * 0.5), Vector3(H.size.x, hgt, LINING))
	# bronze reveal where the lining meets the basement ceiling, and a mid course line
	for y in [SHAFT_BOTTOM + 0.03, FLOOR_Y - 0.30]:
		var t := 0.012 if y > SHAFT_BOTTOM + 0.1 else 0.02
		add_box(metal, Vector3(x0 + INSET + t * 0.5, y, (z0 + z1) * 0.5), Vector3(t, 0.035, H.size.y))
		add_box(metal, Vector3(x1 - INSET - t * 0.5, y, (z0 + z1) * 0.5), Vector3(t, 0.035, H.size.y))
		add_box(metal, Vector3((x0 + x1) * 0.5, y, z0 + INSET + t * 0.5), Vector3(H.size.x, 0.035, t))
		add_box(metal, Vector3((x0 + x1) * 0.5, y, z1 - INSET - t * 0.5), Vector3(H.size.x, 0.035, t))
	# 2. flush timber nosing on the floor around the aperture (outside it, 12 mm)
	var nw := 0.11
	add_box(wood, Vector3(x0 - nw * 0.5 + INSET, FLOOR_Y + 0.006, (z0 + z1) * 0.5), Vector3(nw, 0.012, H.size.y + 2 * nw))
	add_box(wood, Vector3(x1 + nw * 0.5 - INSET, FLOOR_Y + 0.006, (z0 + z1) * 0.5), Vector3(nw, 0.012, H.size.y + 2 * nw))
	add_box(wood, Vector3((x0 + x1) * 0.5, FLOOR_Y + 0.006, z0 - nw * 0.5 + INSET), Vector3(H.size.x, 0.012, nw))
	add_box(wood, Vector3((x0 + x1) * 0.5, FLOOR_Y + 0.006, z1 + nw * 0.5 - INSET), Vector3(H.size.x, 0.012, nw))
	if not CLOSE_SLAB:
		# 3. closed flights: soffit under the tread line, solid stringers, riser faces
		var flights := [[Layout.DOWN_EAST_X, Layout.START_Z, -1.0, Layout.GROUND_Y], [Layout.DOWN_WEST_X, Layout.TURN_Z, 1.0, Layout.TURN_Y]]
		for fl in flights:
			var x: float = fl[0]; var zs: float = fl[1]; var dir: float = fl[2]; var ys: float = fl[3]
			var run := Layout.GOING * Layout.STEPS; var drop := Layout.RISE * Layout.STEPS
			var a := Vector3(x, ys - 0.17 - 0.03, zs); var b := Vector3(x, ys - drop - 0.17 - 0.03, zs + dir * run)
			var along := (b - a); var len := along.length()
			var bz := Basis(Vector3.RIGHT, atan2(-along.y / len, along.z / len))
			var mid := (a + b) * 0.5
			# soffit board under the flight, clipped to the basement ceiling-to-floor span by construction
			add_box(wood, mid - Vector3(0, 0.03, 0), Vector3(1.62, 0.025, len), bz)
			stats.soffits += 1
			for side in [-0.80, 0.80]:
				add_box(wood, mid + Vector3(side, 0.08, 0), Vector3(0.05, 0.34, len), bz)
			for i in Layout.STEPS:
				var top := ys - Layout.RISE * i
				var zf := zs + dir * Layout.GOING * i
				# riser face at the nosing of tread i-1, from tread i's top up to tread i-1's top
				add_box(wood, Vector3(x, top - Layout.RISE * 0.5, zf + dir * 0.012), Vector3(1.60, Layout.RISE, 0.02))
				add_box(metal, Vector3(x, top + 0.004, zf - dir * 0.03), Vector3(1.62, 0.008, 0.05))
				stats.risers += 1
	# 4. glass balustrade infill on the floor-level guards (west, east, north), between the rails
	for g in [[Vector3(x0, 0, z0), Vector3(x0, 0, z1)], [Vector3(x1, 0, z0), Vector3(x1, 0, z1)], [Vector3(x0, 0, z0), Vector3(x1, 0, z0)]]:
		var p0: Vector3 = g[0]; var p1: Vector3 = g[1]
		var c := (p0 + p1) * 0.5 + Vector3(0, FLOOR_Y + 0.62, 0)
		var size := Vector3(absf(p1.x - p0.x), 0.72, absf(p1.z - p0.z))
		if size.x < 0.01: size.x = 0.012
		else: size.z = 0.012
		add_box(pane, c, size)
		stats.glass_panels += 1
	mesh_node(root, "Shaft limestone lining", stone, lime)
	mesh_node(root, "Stair timber dressing", wood, timber)
	mesh_node(root, "Bronze reveals and nosings", metal, bronze)
	var gl := mesh_node(root, "Glass balustrade infill", pane, glass)
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tris := 0
	for m in root.get_children():
		if m is MeshInstance3D: tris += m.mesh.get_faces().size() / 3
	stats["ok"] = true; stats["tris"] = tris; stats["colliders_added"] = 0
	root.set_meta("hall_stairwell_finish", stats)
	return stats
