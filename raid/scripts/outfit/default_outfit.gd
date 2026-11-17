extends RefCounted
## Default outfit (TASKS item 22 follow-up): the clothes every character wears under tiered
## gear and in place of an empty clothing slot. Shirt (clay-rust henley tee, tucked), canvas
## work pants with belt and cargo pockets, laced leather boots. Built by
## tools/blender_midstyle/build_outfit.py as offset shells of the Appearance-Proof ProofBody,
## so every piece carries the body's own skin weights (same bone names / rest pose as
## models/Appearance-Proof.glb), with an explicit LOD1 (~40%) for the Psy mannequin.
##
## Covered skin is cut out of the body with a per-combination UV mask (alpha scissor), so the
## body can never poke through a garment it is under, whatever the pose.
const SCENE := "res://raid/assets/outfit/default_outfit.gltf"
const ORDER := ["shirt", "pants", "boots"]          # mask tag order
const MESH := {"shirt": "OutfitShirt", "pants": "OutfitPants", "boots": "OutfitBoots"}
## Select-stage clothing slot each piece stands in for (an equipped procedural garment in that
## slot replaces the piece).
const SLOT := {"shirt": "jacket", "pants": "pants", "boots": "boots"}
const MASK := "res://raid/assets/outfit/textures/body_mask_%s.png"
const LOD1_SUFFIX := "_LOD1"
const BODY := "ProofBody"

static func available() -> bool:
	return ResourceLoader.exists(SCENE)

static func mask_tag(pieces: Array) -> String:
	var tag := ""
	for p in ORDER: tag += "1" if p in pieces else "0"
	return tag

static func mask_path(pieces: Array) -> String:
	return MASK % mask_tag(pieces)

## Binds the requested pieces (LOD0 or LOD1) to a skeleton with Appearance-Proof bone names and
## cuts the covered skin out of `body` (when given). Replaces any outfit already attached.
## Returns the pieces attached, in ORDER.
static func dress(skeleton: Skeleton3D, pieces: Array = ORDER, lod: int = 0, body: MeshInstance3D = null) -> Array:
	undress(skeleton, null)
	var shown := []
	if skeleton == null or not available():
		if body != null: apply_body_mask(body, [])
		return shown
	var packed := load(SCENE) as PackedScene
	if packed == null: return shown
	var inst := packed.instantiate()
	for p in ORDER:
		if not p in pieces: continue
		var src := inst.find_child(str(MESH[p]) + (LOD1_SUFFIX if lod == 1 else ""), true, false) as MeshInstance3D
		if src == null: continue
		var mi := MeshInstance3D.new()
		mi.name = "Outfit_" + p
		mi.mesh = src.mesh
		mi.skin = src.skin
		mi.set_meta("outfit_piece", p)
		mi.set_meta("lod", lod)
		skeleton.add_child(mi)
		mi.skeleton = NodePath("..")
		shown.append(p)
	inst.free()
	if body != null: apply_body_mask(body, shown)
	return shown

## Shows only `pieces` of an attached outfit and re-cuts the body to match.
static func show_pieces(skeleton: Skeleton3D, body: MeshInstance3D, pieces: Array) -> Array:
	var shown := []
	if skeleton != null:
		for p in ORDER:
			var n := skeleton.get_node_or_null("Outfit_" + p) as Node3D
			if n == null: continue
			n.visible = p in pieces
			if n.visible: shown.append(p)
	if body != null: apply_body_mask(body, shown)
	return shown

static func undress(skeleton: Skeleton3D, body: MeshInstance3D = null) -> void:
	if skeleton != null:
		for c in skeleton.get_children():
			if c.has_meta("outfit_piece"):
				skeleton.remove_child(c); c.queue_free()
	if body != null: apply_body_mask(body, [])

static func pieces_on(skeleton: Skeleton3D) -> Array:
	var out := []
	if skeleton == null: return out
	for p in ORDER:
		var n := skeleton.get_node_or_null("Outfit_" + p)
		if n != null and n.visible: out.append(p)
	return out

static func tris(skeleton: Skeleton3D) -> int:
	var n := 0
	if skeleton == null: return n
	for c in skeleton.get_children():
		var mi := c as MeshInstance3D
		if mi != null and mi.has_meta("outfit_piece") and mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var a: Array = mi.mesh.surface_get_arrays(s)
				n += (a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX] != null else a[Mesh.ARRAY_VERTEX].size()) / 3
	return n

## Cuts the skin under `pieces` out of the body (alpha scissor on the body UV mask). The body's
## own material(s) - surface overrides, material_override or the mesh material - are kept as
## the base and restored when nothing is covered. Safe to call repeatedly.
static func apply_body_mask(body: MeshInstance3D, pieces: Array) -> void:
	if body == null or body.mesh == null: return
	var tex: Texture2D = null
	if not pieces.is_empty() and ResourceLoader.exists(mask_path(pieces)):
		tex = load(mask_path(pieces)) as Texture2D
	body.set_meta("outfit_mask", mask_tag(pieces) if tex != null else "000")
	if body.material_override != null or body.has_meta("outfit_base_override"):
		if not body.has_meta("outfit_base_override"): body.set_meta("outfit_base_override", body.material_override)
		var base = body.get_meta("outfit_base_override")
		body.material_override = _masked(base, tex) if tex != null else base
		return
	for si in body.mesh.get_surface_count():
		var key := "outfit_base_%d" % si
		if not body.has_meta(key):
			var cur = body.get_surface_override_material(si)
			body.set_meta(key, cur if cur != null else false)
		var base = body.get_meta(key)
		var src: Material = base if base is Material else body.mesh.surface_get_material(si)
		if tex == null:
			body.set_surface_override_material(si, base if base is Material else null)
		else:
			body.set_surface_override_material(si, _masked(src, tex))

## Call after replacing the body's material(s) so the next mask uses the new base.
static func forget_body_base(body: MeshInstance3D) -> void:
	if body == null: return
	for k in body.get_meta_list():
		if str(k).begins_with("outfit_base"): body.remove_meta(k)

static func _masked(src, tex: Texture2D) -> Material:
	var m: BaseMaterial3D = (src as BaseMaterial3D).duplicate() if src is BaseMaterial3D else StandardMaterial3D.new()
	# The Appearance-Proof skin is untextured (albedo colour only), so the mask (white RGB,
	# cut-out in alpha) can sit in the albedo slot without changing the skin tone.
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.set_meta("outfit_mask", true)
	return m
