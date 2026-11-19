extends RefCounted
## Queue item 4 (b), visual-pass 39/45 (and probe shot hall_threshold_close): at the Town Hall door
## the beige "Flush outer threshold" strip (hall_review_finish.gd, pinned) sits at y 0.056, below
## the plaza pavers (top 0.08), so only a sliver shows between the paver edge and the Hall floor's
## white slab face, reading as a misaligned wedge where the beige, cream and grey surfaces meet.
## Render-only fix, no collider or step change (the walkable step stays 0.08 -> 0.24):
##   - a limestone riser facing over the white slab face across the doorway (to the jamb shoes);
##   - a flush stone sill (4 mm proud of the pavers, 1 cm bevel) that covers the sliver and meets
##     the front foundation courses at both ends;
##   - a dark shadow joint between sill and pavers so the change of material reads as intended.
const S = preload("res://raid/scripts/hall_stairwell_finish.gd")
const NAME := "HallThresholdFinish"
const DOOR_X := 2.36
const FACE_Z := -14.0
const SILL_DEPTH := 0.30
const PAVER_TOP := 0.08
const HALL_FLOOR := 0.24

static func mat(c: Color, rough := 0.85) -> Material:
	var m := ShaderMaterial.new(); m.shader = load("res://assets/materials/courtyard_surface.gdshader")
	m.set_shader_parameter("tint", c); m.set_shader_parameter("roughness", rough); m.set_shader_parameter("variation", 0.18)
	m.set_shader_parameter("grain_scale", 14.0); m.set_shader_parameter("bump_strength", 0.02)
	return m

static func install(world: Node3D) -> Dictionary:
	if world.has_node(NAME): return world.get_node(NAME).get_meta("hall_threshold_finish", {"ok": true, "reused": true})
	var root := Node3D.new(); root.name = NAME; world.add_child(root)
	var riser: SurfaceTool = S.begin(); var sill: SurfaceTool = S.begin(); var joint: SurfaceTool = S.begin()
	# riser facing: 12 mm proud of the slab face, paver top to just under the threshold cap
	S.add_box(riser, Vector3(0, (PAVER_TOP + HALL_FLOOR) * 0.5 - 0.002, FACE_Z + 0.006), Vector3(DOOR_X * 2, HALL_FLOOR - PAVER_TOP - 0.004, 0.012))
	# sill: main slab plus a bevel strip at the outer edge
	var top := PAVER_TOP + 0.004
	S.add_box(sill, Vector3(0, top - 0.02, FACE_Z + 0.012 + (SILL_DEPTH - 0.012) * 0.5 - 0.005), Vector3(DOOR_X * 2, 0.04, SILL_DEPTH - 0.022))
	S.add_box(sill, Vector3(0, top - 0.025, FACE_Z + SILL_DEPTH - 0.012), Vector3(DOOR_X * 2, 0.03, 0.02), Basis(Vector3.RIGHT, deg_to_rad(-35)))
	# end returns to the foundation courses and the shadow joint at the paver edge
	for sx in [-1.0, 1.0]:
		S.add_box(sill, Vector3(sx * (DOOR_X + 0.03), top - 0.02, FACE_Z + SILL_DEPTH * 0.5), Vector3(0.06, 0.04, SILL_DEPTH))
	S.add_box(joint, Vector3(0, PAVER_TOP + 0.001, FACE_Z + SILL_DEPTH + 0.006), Vector3(DOOR_X * 2 + 0.12, 0.004, 0.012))
	for x in [-1.5, -0.5, 0.5, 1.5]:
		S.add_box(joint, Vector3(x, top + 0.0005, FACE_Z + SILL_DEPTH * 0.5), Vector3(0.008, 0.002, SILL_DEPTH - 0.04))
	S.mesh_node(root, "Entrance riser facing", riser, mat(Color("#b4a68a")))
	S.mesh_node(root, "Entrance stone sill", sill, mat(Color("#9c917d")))
	S.mesh_node(root, "Sill shadow joints", joint, mat(Color("#55503f"), 0.95))
	for c in root.get_children(): c.layers = 1
	var r := {"ok": true, "pieces": root.get_child_count(), "colliders_added": 0, "door_width": DOOR_X * 2}
	root.set_meta("hall_threshold_finish", r)
	return r
