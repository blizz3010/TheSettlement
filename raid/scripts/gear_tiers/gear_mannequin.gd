extends SubViewportContainer
## Psy equip-tab loadout mannequin (TASKS item 22, gear art E0). A neutral grey dress form
## built from the Appearance-Proof rig (hair/face hidden) in the default outfit (LOD1), wearing the LOD1 meshes of the worn
## tiered pieces that have real art, plus the selected piece as a try-on. Own world, renders
## only when the loadout changes.
const SOURCE := "res://models/Appearance-Proof.glb"
const GearArt = preload("res://raid/scripts/gear_tiers/gear_art.gd")
const DefaultOutfit = preload("res://raid/scripts/outfit/default_outfit.gd")
const HIDE := ["hair_short02_v1", "hair_bob01_v1", "brow_009_v1", "brow_001_v1", "eye_brown_v1", "eye_blue_v1"]
var viewport: SubViewport
var skeleton: Skeleton3D
var shown: Array = []
var model_ok := false

func _ready():
	name = "GearMannequin"
	custom_minimum_size = Vector2(230, 330)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new(); viewport.size = Vector2i(460, 660); viewport.own_world_3d = true
	viewport.transparent_bg = true; viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var root := Node3D.new(); root.name = "MannequinStage"; viewport.add_child(root)
	var env := Environment.new(); env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("c9d3cf"); env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-28, -35, 0); key.light_energy = 1.5; root.add_child(key)
	var rim := DirectionalLight3D.new(); rim.rotation_degrees = Vector3(-10, 150, 0); rim.light_energy = 0.6; rim.light_color = Color("a8c0cc"); root.add_child(rim)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 1.05
	cam.position = Vector3(0.95, 1.12, 2.2); root.add_child(cam); cam.look_at(Vector3(0, 1.02, 0)); cam.current = true
	var packed := load(SOURCE) as PackedScene
	if packed == null: return
	var rig := packed.instantiate() as Node3D; rig.name = "Mannequin"; root.add_child(rig)
	skeleton = rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var form := StandardMaterial3D.new(); form.albedo_color = Color("8d918c"); form.roughness = 0.7
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		if str(mi.name) in HIDE: mi.visible = false
		elif str(mi.name) == "ProofBody": mi.material_override = form
	# Default outfit (LOD1) dresses the form under the gear; covered form is cut out.
	DefaultOutfit.dress(skeleton, DefaultOutfit.ORDER, 1, rig.find_child("ProofBody", true, false) as MeshInstance3D)
	# Dress-form stand under the pelvis.
	var stand := MeshInstance3D.new(); var cyl := CylinderMesh.new(); cyl.top_radius = 0.018; cyl.bottom_radius = 0.018; cyl.height = 0.8
	stand.mesh = cyl; stand.position = Vector3(0, 0.4, -0.06); stand.material_override = form; root.add_child(stand)
	model_ok = skeleton != null
	show_loadout(shown)

## Worn pieces (+ try-on) with art, LOD1. Returns the ids shown.
func show_loadout(ids: Array) -> Array:
	shown = ids.duplicate()
	if not model_ok: return []
	var out := GearArt.show_worn(skeleton, ids, 1)
	if viewport != null: viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	return out

func outfit_pieces() -> Array:
	return DefaultOutfit.pieces_on(skeleton)

func attached_ids() -> Array:
	var out := []
	if skeleton == null: return out
	for c in skeleton.get_children():
		if c.has_meta("gear_art_id"): out.append(str(c.get_meta("gear_art_id")))
	return out
