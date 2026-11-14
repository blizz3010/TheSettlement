extends RefCounted
## Item 11 STYLE TEST (preview only, awaiting Michael's OK).
## Swaps two high-severity item-12 props for mid-stylized Blender remodels:
##  * Tailor & Dyes dress form (box torso, egg head, box waistcoat) -> tailor_dress_form.glb
##  * Rook's counter-top stock (ledger, three timber cubes, two plan rolls) -> rook_counter_stock.glb
##  * Town Hall reception desk body (relocated hall-mesh slabs) -> hall_reception_desk.glb
## Pinned builders are untouched: the old pieces are hidden (tailor) or cut out of the
## Rook static batch (Rook's art is merged into per-material batches at startup).
## Render-only: no collision, interaction, stock or save data changes.
## Set false (e.g. by a capture driver) to keep the stock props for "before" shots.
static var enabled := true
const DRESS_FORM := "res://assets/midstyle_test/tailor_dress_form.glb"
const ROOK_COUNTER := "res://assets/midstyle_test/rook_counter_stock.glb"
const RECEPTION_DESK := "res://assets/midstyle_test/hall_reception_desk.glb"
## Desk centre on the hall floor, matching the kept v098 collider (0, .82, -22).
const RECEPTION_ORIGIN := Vector3(0, 0, -22)
## Dress form footprint in TailorAtelier-local space (v094 form at x=0, z=-1.35).
const DRESS_FORM_ORIGIN := Vector3(0, 0, -1.35)
const DRESS_FORM_REGION := AABB(Vector3(-.42, .05, -1.62), Vector3(.84, 2.12, .54))
## Rook counter-top dressing volume in RookReferenceArt-local space (top surface y=1.15).
const ROOK_TOP_REGION := AABB(Vector3(-1.98, 1.152, -1.93), Vector3(3.96, .17, .86))

static func apply(world: Node3D) -> Dictionary:
	var result := {"ok": true, "tailor": {}, "rook": {}}
	var tailor := world.get_node_or_null("TailorAtelier") as Node3D
	if tailor != null and not tailor.has_node("MidstyleDressForm"):
		result.tailor = _swap_dress_form(tailor)
	var rook := world.get_node_or_null("RookReferenceArt") as Node3D
	if rook != null and not rook.has_node("MidstyleCounterStock"):
		result.rook = _swap_rook_counter(rook)
	result["reception"] = {}
	var assembly := world.get_node_or_null("HallReceptionAssemblyV098") as Node3D
	if assembly != null and not assembly.has_node("MidstyleReceptionDesk"):
		result.reception = _swap_reception(world, assembly)
	result.ok = result.tailor.get("ok", false) and result.rook.get("ok", false) and result.reception.get("ok", false)
	world.set_meta("midstyle_style_test", result)
	return result

static func _local_center(root: Node3D, mesh: MeshInstance3D) -> Vector3:
	return (root.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb().get_center()

static func _swap_dress_form(tailor: Node3D) -> Dictionary:
	var hidden: Array[String] = []
	var removed := 0
	for node in tailor.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree() or mesh.skin != null: continue
		if mesh.mesh is PrimitiveMesh:
			# Loose v094 pieces (base, stand, wooden head) are hidden whole.
			if DRESS_FORM_REGION.has_point(_local_center(tailor, mesh)):
				mesh.visible = false
				mesh.set_meta("midstyle_replaced", true)
				hidden.append(str(tailor.get_path_to(mesh)))
		elif mesh.mesh is ArrayMesh and not str(mesh.name).begins_with("Midstyle"):
			# Sealed v097 essentials (torso, waistcoat, lapels, shoulders) are cut out.
			removed += _cut_region(mesh, tailor, DRESS_FORM_REGION)
	var packed := load(DRESS_FORM) as PackedScene
	if packed == null: return {"ok": false, "reason": "missing " + DRESS_FORM, "hidden": hidden}
	var form := packed.instantiate() as Node3D
	form.name = "MidstyleDressForm"
	form.position = DRESS_FORM_ORIGIN
	tailor.add_child(form)
	return {"ok": not hidden.is_empty() or removed > 0, "hidden": hidden, "removed_triangles": removed, "triangles": _triangles(form)}

static func _swap_reception(world: Node3D, assembly: Node3D) -> Dictionary:
	# hall_reception_v098 leaves a receipt naming the exact hall-mesh vertices of the
	# relocated desk components; only triangles made wholly of those are removed.
	var receipt: Dictionary = world.get_meta("hall_reception_v098", {})
	if not receipt.get("ok", false): return {"ok": false, "reason": "no v098 reception receipt"}
	var hall: MeshInstance3D = null
	for node in world.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).mesh == receipt.mesh:
			hall = node
			break
	if hall == null: return {"ok": false, "reason": "reception hall mesh not found"}
	var selected: Dictionary = receipt.selected
	var packed: Array = hall.mesh.get("_surfaces").duplicate()
	var removed := 0
	for s in selected:
		var arrays := hall.mesh.surface_get_arrays(s)
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if index.is_empty():
			index.resize(arrays[Mesh.ARRAY_VERTEX].size())
			for i in index.size(): index[i] = i
		var keep_set: Dictionary = selected[s]
		var kept := PackedInt32Array()
		for t in range(0, index.size(), 3):
			if keep_set.has(index[t]) and keep_set.has(index[t + 1]) and keep_set.has(index[t + 2]): removed += 1
			else: kept.append_array([index[t], index[t + 1], index[t + 2]])
		if kept.is_empty(): continue
		arrays[Mesh.ARRAY_INDEX] = kept
		var part := ArrayMesh.new()
		part.add_surface_from_arrays(hall.mesh.surface_get_primitive_type(s), arrays)
		part.surface_set_material(0, hall.mesh.surface_get_material(s))
		packed[s] = part.get("_surfaces")[0]
	var before: Mesh = hall.mesh
	var rebuilt := ArrayMesh.new()
	rebuilt.set("_surfaces", packed)
	for key in before.get_meta_list(): rebuilt.set_meta(key, before.get_meta(key))
	hall.mesh = rebuilt
	var packed_scene := load(RECEPTION_DESK) as PackedScene
	if packed_scene == null: return {"ok": false, "reason": "missing " + RECEPTION_DESK, "removed_triangles": removed}
	var desk := packed_scene.instantiate() as Node3D
	desk.name = "MidstyleReceptionDesk"
	desk.position = RECEPTION_ORIGIN
	assembly.add_child(desk)
	return {"ok": removed > 0, "removed_triangles": removed, "triangles": _triangles(desk)}

static func _swap_rook_counter(rook: Node3D) -> Dictionary:
	var removed := 0
	var batches := 0
	for node in rook.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.has_meta("source_meshes"): continue
		var cut := _cut_region(mesh, rook, ROOK_TOP_REGION)
		if cut > 0:
			removed += cut
			batches += 1
	var packed := load(ROOK_COUNTER) as PackedScene
	if packed == null: return {"ok": false, "reason": "missing " + ROOK_COUNTER, "removed_triangles": removed}
	var stock := packed.instantiate() as Node3D
	stock.name = "MidstyleCounterStock"
	rook.add_child(stock)
	return {"ok": removed > 0, "removed_triangles": removed, "batches_cut": batches, "triangles": _triangles(stock)}

## Rebuilds a merged static batch without the triangles that sit wholly inside the
## given volume. Everything else in the batch is kept byte-for-byte.
static func _cut_region(mesh: MeshInstance3D, root: Node3D, region: AABB) -> int:
	var to_rook := root.global_transform.affine_inverse() * mesh.global_transform
	var source := mesh.mesh
	var rebuilt := ArrayMesh.new()
	var removed := 0
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if index.is_empty():
			index.resize(verts.size())
			for i in verts.size(): index[i] = i
		var kept := PackedInt32Array()
		for t in range(0, index.size(), 3):
			var inside := true
			for k in 3:
				if not region.has_point(to_rook * verts[index[t + k]]):
					inside = false
					break
			if inside: removed += 1
			else: kept.append_array([index[t], index[t + 1], index[t + 2]])
		if kept.is_empty(): continue  # the whole surface was counter-top dressing
		arrays[Mesh.ARRAY_INDEX] = kept
		rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var surface_material := source.surface_get_material(s)
		if surface_material != null: rebuilt.surface_set_material(rebuilt.get_surface_count() - 1, surface_material)
	if removed > 0:
		mesh.set_meta("midstyle_removed_triangles", removed)
		if rebuilt.get_surface_count() == 0:
			mesh.visible = false
		else:
			mesh.mesh = rebuilt
	return removed

static func _triangles(root: Node) -> int:
	var total := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = node.mesh
		if m == null: continue
		for s in m.get_surface_count():
			var a := m.surface_get_arrays(s)
			var idx = a[Mesh.ARRAY_INDEX]
			total += (idx.size() if idx != null and idx.size() > 0 else a[Mesh.ARRAY_VERTEX].size()) / 3
	return total
