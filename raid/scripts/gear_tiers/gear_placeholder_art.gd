extends RefCounted
## PLACEHOLDER art only (TASKS item 22, PR A). One primitive per slot, tinted by
## tier with a trim band, so shop/inventory/preview work in PR C can show
## something before the mid-to-high-poly art waves (PR E1-E3) replace it.
## Meter scale; sizes approximate the worn item. Not used by any live scene yet.
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const SHAPES := {
	"helmet": ["sphere", Vector3(0.26, 0.20, 0.28)], "visor": ["box", Vector3(0.22, 0.08, 0.02)],
	"headset": ["cylinder", Vector3(0.24, 0.06, 0.06)], "face_cover": ["box", Vector3(0.16, 0.10, 0.04)],
	"body_armor": ["box", Vector3(0.40, 0.48, 0.24)], "tactical_rig": ["box", Vector3(0.38, 0.22, 0.10)],
	"gloves": ["box", Vector3(0.10, 0.04, 0.18)], "jacket": ["capsule", Vector3(0.44, 0.62, 0.26)],
	"pants": ["capsule", Vector3(0.34, 0.86, 0.22)], "boots": ["box", Vector3(0.12, 0.14, 0.30)],
	"backpack": ["box", Vector3(0.34, 0.46, 0.20)],
}

static func material(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

static func _mesh(kind: String, size: Vector3) -> Mesh:
	match kind:
		"sphere":
			var s := SphereMesh.new(); s.radius = size.x * 0.5; s.height = size.y * 2.0; s.is_hemisphere = true
			s.radial_segments = 24; s.rings = 8; return s
		"cylinder":
			var c := CylinderMesh.new(); c.top_radius = size.y; c.bottom_radius = size.y; c.height = size.x
			c.radial_segments = 16; return c
		"capsule":
			var p := CapsuleMesh.new(); p.radius = size.z * 0.5 + size.x * 0.15; p.height = size.y; return p
	var b := BoxMesh.new(); b.size = size; return b

## Returns a Node3D named after the item, or null for unknown ids.
static func build(def_id: String) -> Node3D:
	var def := Defs.item(def_id)
	if def.is_empty(): return null
	var spec: Array = SHAPES[def.slot]
	var root := Node3D.new()
	root.name = def_id
	root.set_meta("placeholder", true)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _mesh(spec[0], spec[1])
	body.material_override = material(Defs.TIER_COLORS[def.tier], 0.85 - 0.1 * def.tier)
	root.add_child(body)
	# Trim band: one per tier so the tier reads at a glance on the placeholder.
	for i in def.tier:
		var band := MeshInstance3D.new()
		band.name = "TierBand%d" % (i + 1)
		var bm := BoxMesh.new()
		var size: Vector3 = spec[1]
		bm.size = Vector3(size.x * 1.02, 0.012, size.z * 1.02)
		band.mesh = bm
		band.position.y = -size.y * 0.3 + i * 0.03
		band.material_override = material(Defs.TIER_TRIM[def.tier], 0.4)
		root.add_child(band)
	return root
