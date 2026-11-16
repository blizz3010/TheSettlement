extends Node3D
## TASKS item 21 root-cause fix: view-dependent culling for the dense settlement grass.
## Ori's Town Hall "stall" was the frame rate: at the spawn the default High preset drew
## ~16.5M primitives per frame, ~14.6M of them 130-triangle grass clumps in
## PlazaIslandComposition (SettlementGroundGrassV086 near chunks, coverage and garden beds).
## On the box's software renderer that is ~9.5 s per frame, so input looked dead.
##
## This cuts only grass that cannot be seen; what is on screen is unchanged:
##  1. Every 130-triangle grass batch is split once into 3 m sub-chunks (same mesh, material,
##     instance transforms and order), so frustum culling and the rules below work per 3 m.
##  2. Near-LOD grass (grass_lod / fishing_grass shaders, near_mode on) flattens every blade
##     beyond `near_end` to zero height in the vertex shader. Sub-chunks wholly beyond that
##     distance only drew flat slivers on the soil, so they are skipped.
##  3. While the camera is inside the Town Hall, exterior grass is only visible through the
##     glazing (sill y = 1.18 on every wall) or the open doorway. Sub-chunks whose every
##     sample point is hidden below the sill line from the camera are skipped.
## Grass quality from Options still applies: the originals keep their visible_instance_count
## and visibility ranges (set by the pinned quality controllers); sub-chunks mirror them.
## settlement_grass_v086.gd, plaza_island_landscape.gd and the baked scenes are pinned and
## are not edited; the originals are only hidden while their sub-chunks stand in for them.
const NODE_NAME := "GrassViewCulling"
const CELL := 3.0
const MIN_TRIS := 100
const MIN_INSTANCES := 256
## Town Hall shell (TownHallCollision walls; glazing journal assets/hall_v097).
const HALL_MIN := Vector2(-8.8, -31.8)
const HALL_MAX := Vector2(8.8, -14.2)
const HALL_INNER_MARGIN := 0.2
const SILL_Y := 1.18
const SILL_MARGIN := 0.15
const DOOR_HALF_WIDTH := 2.1
const DOOR_MARGIN := 0.25
const DOOR_TOP := 4.77
const HALL_TOP := 6.2
const NEAR_MARGIN := 0.5
const UPDATE_MOVE := 0.25
const UPDATE_INTERVAL_MS := 250
const SPLIT_BUDGET_USEC := 12000
## Each 3 m sub-chunk keeps a 3 x 3 grid of 1 m bins (highest root, tallest blade) for the
## glazing test, so blades the near-LOD shader has already shortened are judged at their
## drawn height rather than the whole chunk's bounding box.
const BINS := 3
## Per bin: highest root y, tallest blade, then the blades' x/z extent (min x, max x, min z, max z).
const BIN_STRIDE := 6
const TOP_MARGIN := 0.05
## The headless (dummy) renderer keeps no MultiMesh instance data, so headless tests attach
## the instance buffer to the MultiMesh under this meta key; the game reads mm.buffer.
const BUFFER_META := "grass_view_culling_buffer"

static func instance_buffer(mm: MultiMesh) -> PackedFloat32Array:
	var buf: PackedFloat32Array = mm.buffer
	if buf.is_empty() and mm.has_meta(BUFFER_META): buf = mm.get_meta(BUFFER_META)
	return buf

static func slice_buffer(buf: PackedFloat32Array, stride: int, indices: PackedInt32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in indices:
		out.append_array(buf.slice(i * stride, i * stride + stride))
	return out

var world: Node3D
var enabled := true
var pending: Array = []          # original MultiMeshInstance3D still to split
var batches: Array = []          # {original, subs:[{mmi, indices, aabb, near, near_end}], vis, vb, ve}
var last_camera := Vector3.INF
var last_update_ms := 0
var split_done := false
var split_usec := 0
var stats := {"subchunks": 0, "visible": 0, "culled_distance": 0, "culled_sill": 0, "batches": 0, "instances": 0, "update_usec": 0}
var force_update := true
var last_collect_ms := 0
var last_frame_usec := 0
const RECOLLECT_MS := 5000

static func install(host: Node3D) -> Node:
	if host == null or not is_instance_valid(host): return null
	var existing := host.get_node_or_null(NODE_NAME)
	if existing != null: return existing
	if OS.get_environment("SETTLEMENT_GRASS_CULLING") == "off": return null
	var node = load("res://raid/scripts/grass_view_culling.gd").new()
	node.name = NODE_NAME
	node.world = host
	host.add_child(node)
	return node

func _ready():
	if world == null: world = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true
	global_transform = Transform3D.IDENTITY
	collect()

static func _tri_count(mesh: Mesh) -> int:
	if mesh == null: return 0
	var t := 0
	for si in mesh.get_surface_count():
		var arr = mesh.surface_get_arrays(si)
		var idx = arr[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null and idx.size() > 0 else arr[Mesh.ARRAY_VERTEX].size()) / 3
	return t

## Finds the dense grass batches under PlazaIslandComposition (nearest to the player first).
func collect() -> void:
	var root = world.get_node_or_null("PlazaIslandComposition")
	if root == null: return
	var tri_cache := {}
	var found: Array = []
	for n in root.find_children("*", "MultiMeshInstance3D", true, false):
		if n.has_meta("grass_view_culling_split"): continue
		var mm: MultiMesh = n.multimesh
		if mm == null or mm.mesh == null or mm.instance_count < MIN_INSTANCES: continue
		if mm.transform_format != MultiMesh.TRANSFORM_3D: continue
		if not tri_cache.has(mm.mesh): tri_cache[mm.mesh] = _tri_count(mm.mesh)
		if tri_cache[mm.mesh] < MIN_TRIS: continue
		found.append(n)
	var p := _camera_pos()
	found.sort_custom(func(a, b): return (a.global_transform * a.get_aabb()).get_center().distance_squared_to(p) < (b.global_transform * b.get_aabb()).get_center().distance_squared_to(p))
	pending = found

func _camera_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null: return cam.global_position
	var player = world.get("player") if world != null else null
	if is_instance_valid(player): return player.global_position + Vector3.UP * 1.68
	return Vector3.ZERO

static func _near_info(mat: Material) -> Dictionary:
	if not mat is ShaderMaterial or mat.shader == null: return {"near": false, "near_start": 0.0, "near_end": 0.0}
	var code: String = mat.shader.code
	if not code.contains("near_mode") or not code.contains("near_end"): return {"near": false, "near_start": 0.0, "near_end": 0.0}
	var mode = mat.get_shader_parameter("near_mode")
	var near_end = mat.get_shader_parameter("near_end")
	var near_start = mat.get_shader_parameter("near_start")
	var ne := float(near_end) if near_end != null else 24.0
	return {"near": mode == null or bool(mode), "near_start": float(near_start) if near_start != null else ne - 6.0, "near_end": ne}

## Splits one batch into CELL-sized sub-chunks; instance order inside each is preserved.
func split(original: MultiMeshInstance3D) -> void:
	if not is_instance_valid(original) or original.has_meta("grass_view_culling_split"): return
	var mm: MultiMesh = original.multimesh
	var count := mm.instance_count
	var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
	var buf := instance_buffer(mm)
	if buf.size() != count * stride: return
	var from_meta := mm.buffer.is_empty()
	var mesh_box: AABB = mm.mesh.get_aabb()
	var xf: Transform3D = original.global_transform
	var mesh_top := maxf(mm.mesh.get_aabb().end.y, 0.0)
	var scale_y := xf.basis.get_scale().y
	var cells := {}
	var bins := {}
	var boxes := {}
	for i in count:
		var o := i * stride
		# Transform3D buffer layout: basis rows with origin x,y,z at offsets 3, 7, 11;
		# the basis Y column (blade up axis) is at offsets 1, 5, 9.
		var w := xf * Vector3(buf[o + 3], buf[o + 7], buf[o + 11])
		var key := Vector2i(floori(w.x / CELL), floori(w.z / CELL))
		if not cells.has(key):
			cells[key] = PackedInt32Array()
			var empty := PackedFloat32Array(); empty.resize(BINS * BINS * BIN_STRIDE)
			for b in BINS * BINS:
				var q := b * BIN_STRIDE
				empty[q] = -INF; empty[q + 1] = -INF; empty[q + 2] = INF; empty[q + 3] = -INF; empty[q + 4] = INF; empty[q + 5] = -INF
			bins[key] = empty
		cells[key].append(i)
		var sc := Vector3(buf[o + 0], buf[o + 4], buf[o + 8]).length()
		var ext := Vector3(maxf(absf(mesh_box.position.x), absf(mesh_box.end.x)) * sc, 0.0, maxf(absf(mesh_box.position.z), absf(mesh_box.end.z)) * sc)
		var lo := w - ext + Vector3(0, minf(mesh_box.position.y, 0.0), 0)
		var hi := w + ext
		if not boxes.has(key): boxes[key] = AABB(lo, hi - lo)
		else: boxes[key] = boxes[key].merge(AABB(lo, hi - lo))
		# Per 1 m bin: highest blade root and tallest blade (before the shader's distance fade).
		var bx := clampi(floori((w.x - key.x * CELL) / (CELL / BINS)), 0, BINS - 1)
		var bz := clampi(floori((w.z - key.y * CELL) / (CELL / BINS)), 0, BINS - 1)
		var bi := (bz * BINS + bx) * BIN_STRIDE
		var h := mesh_top * Vector3(buf[o + 1], buf[o + 5], buf[o + 9]).length() * scale_y
		var bb: PackedFloat32Array = bins[key]
		if w.y > bb[bi]: bb[bi] = w.y
		if h > bb[bi + 1]: bb[bi + 1] = h
		# Roots only: a clump's lateral spread (<= ~0.2 m) shifts the sill crossing by a few
		# centimetres, well inside SILL_MARGIN.
		bb[bi + 2] = minf(bb[bi + 2], w.x); bb[bi + 3] = maxf(bb[bi + 3], w.x)
		bb[bi + 4] = minf(bb[bi + 4], w.z); bb[bi + 5] = maxf(bb[bi + 5], w.z)
		bins[key] = bb
		var top_box: AABB = boxes[key]
		if w.y + h > top_box.end.y: top_box.size.y = w.y + h - top_box.position.y; boxes[key] = top_box
	var subs: Array = []
	var info := _near_info(original.material_override)
	for key in cells:
		var indices: PackedInt32Array = cells[key]
		var sub_buf := slice_buffer(buf, stride, indices)
		var sub_mm := MultiMesh.new()
		sub_mm.transform_format = MultiMesh.TRANSFORM_3D
		sub_mm.use_colors = mm.use_colors
		sub_mm.use_custom_data = mm.use_custom_data
		sub_mm.mesh = mm.mesh
		sub_mm.instance_count = indices.size()
		sub_mm.buffer = sub_buf
		if from_meta: sub_mm.set_meta(BUFFER_META, sub_buf)
		var sub := MultiMeshInstance3D.new()
		sub.name = "%s_%d_%d" % [original.name, key.x, key.y]
		sub.multimesh = sub_mm
		sub.material_override = original.material_override
		sub.material_overlay = original.material_overlay
		sub.cast_shadow = original.cast_shadow
		sub.layers = original.layers
		sub.gi_mode = original.gi_mode
		sub.extra_cull_margin = original.extra_cull_margin
		sub.lod_bias = original.lod_bias
		sub.visibility_range_fade_mode = original.visibility_range_fade_mode
		add_child(sub)
		sub.global_transform = xf
		subs.append({"mmi": sub, "indices": indices, "aabb": boxes[key], "near": info.near, "near_start": info.near_start, "near_end": info.near_end, "cell": key, "bins": bins[key]})
	original.set_meta("grass_view_culling_split", true)
	var batch := {"original": original, "subs": subs, "vis": -2, "vb": -1.0, "ve": -1.0, "vbm": -1.0, "vem": -1.0, "mat": original.material_override}
	batches.append(batch)
	_sync_quality(batch)
	original.visible = false
	stats.batches += 1
	stats.subchunks += subs.size()
	stats.instances += count
	force_update = true

## Mirrors the original's (pinned controller-owned) density and range onto its sub-chunks.
func _sync_quality(batch: Dictionary) -> void:
	var o: MultiMeshInstance3D = batch.original
	if not is_instance_valid(o): return
	var v := o.multimesh.visible_instance_count
	if v != batch.vis:
		batch.vis = v
		for s in batch.subs:
			var idx: PackedInt32Array = s.indices
			s.mmi.multimesh.visible_instance_count = -1 if v < 0 else idx.bsearch(v)
	if o.visibility_range_begin != batch.vb or o.visibility_range_end != batch.ve or o.visibility_range_begin_margin != batch.vbm or o.visibility_range_end_margin != batch.vem:
		batch.vb = o.visibility_range_begin; batch.ve = o.visibility_range_end
		batch.vbm = o.visibility_range_begin_margin; batch.vem = o.visibility_range_end_margin
		for s in batch.subs:
			s.mmi.visibility_range_begin = batch.vb; s.mmi.visibility_range_end = batch.ve
			s.mmi.visibility_range_begin_margin = batch.vbm; s.mmi.visibility_range_end_margin = batch.vem
	var info := _near_info(o.material_override)
	for s in batch.subs:
		s.near = info.near; s.near_start = info.near_start; s.near_end = info.near_end
	# Someone re-showed the original (e.g. a rebuild): keep exactly one copy on screen.
	if o.visible and mode != "original": o.visible = false

func camera_inside_hall(c: Vector3) -> bool:
	return c.x > HALL_MIN.x + HALL_INNER_MARGIN and c.x < HALL_MAX.x - HALL_INNER_MARGIN and c.z > HALL_MIN.y + HALL_INNER_MARGIN and c.z < HALL_MAX.y - HALL_INNER_MARGIN and c.y > -4.5 and c.y < HALL_TOP

## Ray from camera c (inside the hall) to p: visible through glazing or the doorway?
static func ray_visible(c: Vector3, p: Vector3) -> bool:
	var dx := p.x - c.x
	var dz := p.z - c.z
	var t := INF
	var front := false
	if dx > 0.0: t = minf(t, (HALL_MAX.x - c.x) / dx)
	elif dx < 0.0: t = minf(t, (HALL_MIN.x - c.x) / dx)
	if dz > 0.0:
		var tz := (HALL_MAX.y - c.z) / dz
		if tz < t: t = tz; front = true
	elif dz < 0.0:
		var tz := (HALL_MIN.y - c.z) / dz
		if tz < t: t = tz; front = false
	if t >= 1.0: return true    # the point is inside the shell itself
	var y := c.y + (p.y - c.y) * t
	if y > SILL_Y - SILL_MARGIN: return true
	if front and absf(c.x + dx * t) < DOOR_HALF_WIDTH + DOOR_MARGIN and y < DOOR_TOP: return true
	return false

static func aabb_visible_from_hall(c: Vector3, box: AABB) -> bool:
	var top := box.end.y + 0.1
	for a in [0.0, 0.5, 1.0]:
		for b in [0.0, 0.5, 1.0]:
			if ray_visible(c, Vector3(box.position.x + box.size.x * a, top, box.position.z + box.size.z * b)): return true
	return false

## Height factor the grass_lod / fishing_grass vertex shader applies at xz distance d
## (near mode: 1 - smoothstep(near_start, near_end, d)); 1.0 for other grass shaders.
static func near_keep(s: Dictionary, d: float) -> float:
	if not s.near: return 1.0
	return 1.0 - smoothstep(s.near_start, s.near_end, d)

## Glazing/doorway test per 1 m bin, each bin judged at its tallest drawn blade.
static func sub_visible_from_hall(c: Vector3, s: Dictionary) -> bool:
	# Coarse pass at the sub-chunk's full bounding-box height first (cheap, conservative).
	if not aabb_visible_from_hall(c, s.aabb): return false
	var bins: PackedFloat32Array = s.bins
	for b in BINS * BINS:
		var bi := b * BIN_STRIDE
		if bins[bi] == -INF: continue
		# Sample the corners of the blades' own footprint in this bin (not the empty bin area,
		# which can reach inside the hall where no grass grows).
		var x0: float = bins[bi + 2]; var x1: float = bins[bi + 3]
		var z0: float = bins[bi + 4]; var z1: float = bins[bi + 5]
		var box := AABB(Vector3(x0, 0, z0), Vector3(x1 - x0, 0, z1 - z0))
		var top: float = bins[bi] + bins[bi + 1] * near_keep(s, xz_distance(c, box)) + TOP_MARGIN
		for x in [x0, x1]:
			for z in [z0, z1]:
				if ray_visible(c, Vector3(x, top, z)): return true
	return false

static func xz_distance(c: Vector3, box: AABB) -> float:
	var dx := maxf(maxf(box.position.x - c.x, 0.0), c.x - box.end.x)
	var dz := maxf(maxf(box.position.z - c.z, 0.0), c.z - box.end.z)
	return sqrt(dx * dx + dz * dz)

func update_visibility(c: Vector3) -> void:
	if mode == "original": return
	var t0 := Time.get_ticks_usec()
	var inside := camera_inside_hall(c)
	var vis := 0; var cd := 0; var cs := 0
	for batch in batches:
		_sync_quality(batch)
		for s in batch.subs:
			var show := enabled and mode != "none"
			if mode == "split": pass
			elif show and s.near and xz_distance(c, s.aabb) > s.near_end + NEAR_MARGIN:
				show = false; cd += 1
			elif show and inside and not sub_visible_from_hall(c, s):
				show = false; cs += 1
			if s.mmi.visible != show: s.mmi.visible = show
			if show: vis += 1
	stats.visible = vis; stats.culled_distance = cd; stats.culled_sill = cs
	stats.update_usec = Time.get_ticks_usec() - t0

func set_enabled(value: bool) -> void:
	enabled = value
	force_update = true
	update_visibility(_camera_pos())

## Measurement/test hook: "original" shows the untouched source batches (pre-fix state),
## "split" shows every sub-chunk, "none" hides all of this grass, "cull" is the normal mode.
var mode := "cull"
func set_mode(value: String) -> void:
	mode = value
	for batch in batches:
		if is_instance_valid(batch.original): batch.original.visible = value == "original"
		for sub in batch.subs: sub.mmi.visible = value != "original"
	if value != "original": update_visibility(_camera_pos())

func _process(_delta: float) -> void:
	if world == null or not is_instance_valid(world): return
	var frame_usec := Time.get_ticks_usec() - last_frame_usec if last_frame_usec > 0 else 0
	last_frame_usec = Time.get_ticks_usec()
	if not pending.is_empty():
		var start := Time.get_ticks_usec()
		# Small slices on a normal frame rate; on a slow renderer a frame already takes
		# seconds, so spend up to half a frame splitting instead of crawling one batch per frame.
		var budget := clampi(frame_usec / 2, SPLIT_BUDGET_USEC, 3000000)
		while not pending.is_empty() and Time.get_ticks_usec() - start < budget:
			split(pending.pop_front())
		split_usec += Time.get_ticks_usec() - start
		if pending.is_empty():
			split_done = true
			print("GRASS_VIEW_CULLING split batches=%d subchunks=%d instances=%d split_ms=%d" % [stats.batches, stats.subchunks, stats.instances, split_usec / 1000])
	var now := Time.get_ticks_msec()
	# The plaza composition can attach late (deferred while the player stands in its
	# footprint); pick up any dense batch that appears after install.
	if pending.is_empty() and now - last_collect_ms > RECOLLECT_MS:
		last_collect_ms = now
		collect()
	var c := _camera_pos()
	if force_update or c.distance_to(last_camera) > UPDATE_MOVE or now - last_update_ms > UPDATE_INTERVAL_MS:
		force_update = false
		last_camera = c
		last_update_ms = now
		update_visibility(c)

## Restores the originals (used by tests and if the node is removed).
func _exit_tree() -> void:
	for batch in batches:
		if is_instance_valid(batch.original): batch.original.visible = true
