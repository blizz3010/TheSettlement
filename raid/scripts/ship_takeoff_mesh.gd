extends RefCounted
## Runtime split of LaunchpadShip_Runtime into a grounded pad mesh and a hull mesh.
## Does not edit the imported glb or pinned settlement scripts.

const PAD_RADIUS := 5.75
const RUNTIME_NAME := "LaunchpadShip_Runtime"
const PAD_SURFACE_NAMES := {
	"Warm stone concrete": true,
	"Deck inlay cream": true,
	"Amber edge beacons": true
}

static func find_runtime(ship: Node) -> MeshInstance3D:
	if not is_instance_valid(ship):
		return null
	var direct := ship.find_child(RUNTIME_NAME, true, false) as MeshInstance3D
	return direct

static func is_pad_material(mat: Material) -> bool:
	if mat == null:
		return false
	return PAD_SURFACE_NAMES.has(mat.resource_name)

static func triangle_is_pad(a: Vector3, b: Vector3, c: Vector3) -> bool:
	# Radius gap between hull (r <= 5.5) and deck/rails (r >= 5.8) is clean.
	var mean := (Vector2(a.x, a.z).length() + Vector2(b.x, b.z).length() + Vector2(c.x, c.z).length()) / 3.0
	return mean >= PAD_RADIUS

static func split_mesh(src: Mesh, instance: MeshInstance3D = null) -> Dictionary:
	var empty := {"ok": false, "pad": null, "hull": null, "pad_triangles": 0, "hull_triangles": 0}
	if src == null or src.get_surface_count() == 0:
		return empty
	var pad_mesh := ArrayMesh.new()
	var hull_mesh := ArrayMesh.new()
	pad_mesh.resource_name = "TakeoffPadMesh"
	hull_mesh.resource_name = "TakeoffHullMesh"
	var pad_tris := 0
	var hull_tris := 0
	for i in src.get_surface_count():
		var mat: Material = null
		if is_instance_valid(instance):
			mat = instance.get_active_material(i)
		if mat == null:
			mat = src.surface_get_material(i)
		var arrays: Array = src.surface_get_arrays(i)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var force_pad := is_pad_material(mat)
		var pad_arrays: Array = _extract_triangles(arrays, true, force_pad)
		var hull_arrays: Array = _extract_triangles(arrays, false, force_pad)
		var prim := Mesh.PRIMITIVE_TRIANGLES
		if src is ArrayMesh:
			prim = (src as ArrayMesh).surface_get_primitive_type(i)
		if pad_arrays[Mesh.ARRAY_VERTEX] != null and (pad_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() >= 3:
			pad_mesh.add_surface_from_arrays(prim, pad_arrays)
			pad_mesh.surface_set_material(pad_mesh.get_surface_count() - 1, mat)
			pad_tris += (pad_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		if not force_pad and hull_arrays[Mesh.ARRAY_VERTEX] != null and (hull_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() >= 3:
			hull_mesh.add_surface_from_arrays(prim, hull_arrays)
			hull_mesh.surface_set_material(hull_mesh.get_surface_count() - 1, mat)
			hull_tris += (hull_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	if pad_tris == 0 or hull_tris == 0:
		return empty
	return {"ok": true, "pad": pad_mesh, "hull": hull_mesh, "pad_triangles": pad_tris, "hull_triangles": hull_tris}

static func _extract_triangles(arrays: Array, want_pad: bool, force_pad: bool) -> Array:
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		indices = arrays[Mesh.ARRAY_INDEX]
	var has_index := indices.size() >= 3
	var tri_count := indices.size() / 3 if has_index else verts.size() / 3
	# Packed arrays are value types; append to locals and write back.
	var out_v3: Dictionary = {}
	var out_v2: Dictionary = {}
	var out_color: Dictionary = {}
	var out_f32: Dictionary = {}
	var out_i32: Dictionary = {}
	var out_bytes: Dictionary = {}
	for ch in Mesh.ARRAY_MAX:
		out[ch] = null
		if ch == Mesh.ARRAY_INDEX or arrays[ch] == null:
			continue
		if arrays[ch] is PackedVector3Array:
			out_v3[ch] = PackedVector3Array()
		elif arrays[ch] is PackedVector2Array:
			out_v2[ch] = PackedVector2Array()
		elif arrays[ch] is PackedColorArray:
			out_color[ch] = PackedColorArray()
		elif arrays[ch] is PackedFloat32Array:
			out_f32[ch] = PackedFloat32Array()
		elif arrays[ch] is PackedInt32Array:
			out_i32[ch] = PackedInt32Array()
		elif arrays[ch] is PackedByteArray:
			out_bytes[ch] = PackedByteArray()
	var vcount: int = verts.size()
	for t in tri_count:
		var ia: int
		var ib: int
		var ic: int
		if has_index:
			ia = indices[t * 3]
			ib = indices[t * 3 + 1]
			ic = indices[t * 3 + 2]
		else:
			ia = t * 3
			ib = t * 3 + 1
			ic = t * 3 + 2
		if ia < 0 or ic >= verts.size():
			continue
		var is_pad := force_pad or triangle_is_pad(verts[ia], verts[ib], verts[ic])
		if is_pad != want_pad:
			continue
		for idx in [ia, ib, ic]:
			_append_vertex(out_v3, out_v2, out_color, out_f32, out_i32, out_bytes, arrays, idx, vcount)
	for ch in out_v3.keys():
		out[ch] = out_v3[ch]
	for ch in out_v2.keys():
		out[ch] = out_v2[ch]
	for ch in out_color.keys():
		out[ch] = out_color[ch]
	for ch in out_f32.keys():
		out[ch] = out_f32[ch]
	for ch in out_i32.keys():
		out[ch] = out_i32[ch]
	for ch in out_bytes.keys():
		out[ch] = out_bytes[ch]
	return out

static func _append_vertex(out_v3: Dictionary, out_v2: Dictionary, out_color: Dictionary, out_f32: Dictionary, out_i32: Dictionary, out_bytes: Dictionary, arrays: Array, idx: int, vcount: int) -> void:
	for ch in Mesh.ARRAY_MAX:
		if ch == Mesh.ARRAY_INDEX or arrays[ch] == null:
			continue
		var src: Variant = arrays[ch]
		if src is PackedVector3Array:
			var dst: PackedVector3Array = out_v3[ch]
			dst.append((src as PackedVector3Array)[idx])
			out_v3[ch] = dst
		elif src is PackedVector2Array:
			var dst2: PackedVector2Array = out_v2[ch]
			dst2.append((src as PackedVector2Array)[idx])
			out_v2[ch] = dst2
		elif src is PackedColorArray:
			var dstc: PackedColorArray = out_color[ch]
			dstc.append((src as PackedColorArray)[idx])
			out_color[ch] = dstc
		elif src is PackedInt32Array:
			var ints: PackedInt32Array = src
			var dsti: PackedInt32Array = out_i32[ch]
			if ints.size() == vcount:
				dsti.append(ints[idx])
			elif ints.size() == vcount * 4:
				for k in 4:
					dsti.append(ints[idx * 4 + k])
			out_i32[ch] = dsti
		elif src is PackedFloat32Array:
			var floats: PackedFloat32Array = src
			var dstf: PackedFloat32Array = out_f32[ch]
			if floats.size() == vcount:
				dstf.append(floats[idx])
			elif floats.size() == vcount * 4:
				for k in 4:
					dstf.append(floats[idx * 4 + k])
			out_f32[ch] = dstf
		elif src is PackedByteArray:
			var bytes: PackedByteArray = src
			var dstb: PackedByteArray = out_bytes[ch]
			if bytes.size() == vcount:
				dstb.append(bytes[idx])
			elif bytes.size() == vcount * 4:
				for k in 4:
					dstb.append(bytes[idx * 4 + k])
			out_bytes[ch] = dstb

static func attach_hull_and_ground_pad(ship: Node3D, lift_rig: Node3D) -> MeshInstance3D:
	var runtime := find_runtime(ship)
	if runtime == null or runtime.mesh == null:
		return null
	var split: Dictionary = split_mesh(runtime.mesh, runtime)
	if not split.get("ok", false):
		return null
	runtime.mesh = split.pad
	var hull := MeshInstance3D.new()
	hull.name = "TakeoffHull"
	hull.mesh = split.hull
	hull.cast_shadow = runtime.cast_shadow
	var saved := runtime.global_transform
	if is_instance_valid(lift_rig):
		lift_rig.add_child(hull)
	else:
		runtime.get_parent().add_child(hull)
	hull.global_transform = saved
	return hull
