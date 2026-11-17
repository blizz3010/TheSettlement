extends RefCounted
## Per-item-id art lookup for tiered gear (TASKS item 22, gear art waves; E0 pilot =
## gear_helmet_t3 "Warden Helm" + gear_body_armor_t3 "Bulwark Carrier").
## Each entry points at a skinned .gltf built by tools/blender_midstyle/build_gear_e0.py on the
## Appearance-Proof rig (same bone names/rest pose as models/Appearance-Proof.glb), with an
## explicit LOD1 mesh (~40%) for the Psy mannequin, and an optional rendered icon.
## Ids without an entry fall back to the PR A primitive placeholder (build) or to the caller's
## tier chip/badge (icon). Waves E1-E3 only add rows here; no pinned file changes.
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const Placeholder = preload("res://raid/scripts/gear_tiers/gear_placeholder_art.gd")
const State = preload("res://raid/scripts/gear_tiers/gear_locker_state.gd")

## "covers": garment parts of the select-stage procedural outfit this piece sits over
## (hidden while worn so they don't poke through).
const ART := {
	"gear_helmet_t3": {"scene": "res://raid/assets/gear/t3/gear_helmet_t3.gltf", "mesh": "WardenHelm",
		"icon": "res://raid/assets/trader_icons/gear_helmet_t3.png", "covers": ["helmet"], "tri_budget": 12000},
	"gear_body_armor_t3": {"scene": "res://raid/assets/gear/t3/gear_body_armor_t3.gltf", "mesh": "BulwarkCarrier",
		"icon": "res://raid/assets/trader_icons/gear_body_armor_t3.png", "covers": ["jacket_torso"], "tri_budget": 18000},
}
const LOD1_SUFFIX := "_LOD1"
static var _icons := {}

static func has_art(def_id: String) -> bool:
	return ART.has(def_id) and ResourceLoader.exists(str(ART[def_id].scene))

static func ids() -> Array:
	return ART.keys()

static func scene_path(def_id: String) -> String:
	return str(ART[def_id].scene) if ART.has(def_id) else ""

static func covers(def_id: String) -> Array:
	return ART[def_id].get("covers", []) if ART.has(def_id) else []

## Rendered icon, or null (callers keep their tier chip / badge).
static func icon(def_id: String) -> Texture2D:
	if not ART.has(def_id): return null
	if _icons.has(def_id): return _icons[def_id]
	var path := str(ART[def_id].get("icon", ""))
	var tex: Texture2D = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	_icons[def_id] = tex
	return tex

## Stand-alone model: the art scene (own skeleton, rest pose) with only the requested LOD
## visible, or the PR A placeholder for ids without art. Null for unknown ids.
static func build(def_id: String, lod: int = 0) -> Node3D:
	if not has_art(def_id): return Placeholder.build(def_id)
	var packed := load(scene_path(def_id)) as PackedScene
	if packed == null: return Placeholder.build(def_id)
	var root := packed.instantiate() as Node3D
	root.name = def_id
	root.set_meta("gear_art", true)
	root.set_meta("lod", lod)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		mi.visible = str(mi.name).ends_with(LOD1_SUFFIX) == (lod == 1)
	return root

## Binds the item's mesh (LOD0 or LOD1) to a character Skeleton3D with the Appearance-Proof
## bone names, so it deforms with that character. Returns the MeshInstance3D (child of the
## skeleton, named "GearArt_<id>"), or null when the id has no art (no placeholder is
## attached to characters: the primitive stand-ins are for icons/benches only).
static func attach(skeleton: Skeleton3D, def_id: String, lod: int = 0) -> MeshInstance3D:
	if skeleton == null or not has_art(def_id): return null
	detach(skeleton, def_id)
	var packed := load(scene_path(def_id)) as PackedScene
	if packed == null: return null
	var inst := packed.instantiate()
	var want := str(ART[def_id].mesh) + (LOD1_SUFFIX if lod == 1 else "")
	var src := inst.find_child(want, true, false) as MeshInstance3D
	if src == null:
		inst.free(); return null
	var mi := MeshInstance3D.new()
	mi.name = "GearArt_" + def_id
	mi.mesh = src.mesh
	mi.skin = src.skin
	mi.set_meta("gear_art_id", def_id)
	mi.set_meta("lod", lod)
	inst.free()
	skeleton.add_child(mi)
	mi.skeleton = NodePath("..")
	return mi

static func detach(skeleton: Skeleton3D, def_id: String) -> void:
	if skeleton == null: return
	var old := skeleton.get_node_or_null("GearArt_" + def_id)
	if old != null:
		skeleton.remove_child(old); old.queue_free()

static func detach_all(skeleton: Skeleton3D) -> void:
	if skeleton == null: return
	for c in skeleton.get_children():
		if c.has_meta("gear_art_id"):
			skeleton.remove_child(c); c.queue_free()

## Shows exactly the worn pieces that have art (LOD as given). Returns the attached ids.
static func show_worn(skeleton: Skeleton3D, worn_ids: Array, lod: int = 0) -> Array:
	detach_all(skeleton)
	var shown := []
	for id in worn_ids:
		if attach(skeleton, str(id), lod) != null: shown.append(str(id))
	return shown

## Garment parts hidden by the worn pieces (union of "covers").
static func covered(worn_ids: Array) -> Array:
	var out := []
	for id in worn_ids:
		for c in covers(str(id)):
			if not c in out: out.append(c)
	return out

## Worn tiered ids from the gear locker sidecar WITHOUT creating it (the select screen must
## not write files). Empty when there is no locker or it is unreadable.
static func worn_from_locker(path: String = "user://gear_locker.json") -> Array:
	if not FileAccess.file_exists(path): return []
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK: return []
	var state = State.new()
	if not state.restore(json.data): return []
	var out := []
	for iid in state.equipped_ids(): out.append(str(state.owned[iid].def))
	return out
