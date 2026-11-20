extends RefCounted
## PR B, inn hillside (visual pass findings.md P2 "Inn hillside is a uniform Low-grass carpet ... dead-end
## path stub"). Three unpinned overrides, all limited to the inn-hill mask (x -27..29, z 22..53):
##  ground: SettlementTerrain/GroundRelief gets its own copy of the turf material on
##    raid/assets/materials/p2b_ground_finish.gdshader (rook_ground_finish_v096 + dry / clover / mottle
##    patches). Other meshes that share the original material keep it.
##  blades: the SettlementGroundGrassV086 batches touching the mask (originals and their GrassViewCulling
##    sub-chunks) get a copy of their material on raid/assets/materials/p2b_grass_lod.gdshader, which uses
##    the same patch field to shorten / thin tufts in dry patches and tint them. ContinuousGrass LawnChunk
##    blades in the mask are recoloured per instance from the same field (the shared continuous_blades
##    material is left alone; other scripts check it).
##  stub: the rounded limestone cap that ends the inn-foot path west of the ramp (MarketExpansion route
##    pad centred at (-6, 30), r 2 m) dead-ends in the lawn. It is finished as a small overlook: the plaza
##    bench (same art, member collision and seat registration as the Town Hall garden benches) on its
##    south edge facing the inn hill, and a fern planter (screens_planters kit, pot collider) on its west
##    end. The walking line along the path stays clear (bench back at z 28.4, path centre z 30).
const GROUND_SHADER := preload("res://raid/assets/materials/p2b_ground_finish.gdshader")
const GRASS_SHADER := preload("res://raid/assets/materials/p2b_grass_lod.gdshader")
const GRASS_LOD_PATH := "res://assets/settlement_grass_v086/grass_lod.gdshader"
const MASK_MIN := Vector2(-27.0, 22.0)
const MASK_MAX := Vector2(29.0, 53.0)
const Kit = preload("res://raid/scripts/p2b_kit.gd")
const STUB_CENTER := Vector3(-6.0, 0.0, 30.0)
const BENCH_AT := Vector3(-6.0, 0.0, 28.75)   # faces +z (the inn hill); seat depth runs 28.4..29.2
const PLANTER_AT := Vector3(-7.45, 0.0, 30.0)

static func apply(world: Node3D) -> Dictionary:
	var out := {"ok": true}
	out["ground"] = ground(world)
	out["blades"] = blades(world)
	out["lawn"] = lawn(world)
	out["stub"] = stub(world)
	out["ok"] = out.ground.get("ok", false) and out.blades.get("ok", false)
	return out

static func _copy_params(src: ShaderMaterial, dst: ShaderMaterial) -> int:
	var n := 0
	for u in src.shader.get_shader_uniform_list():
		var v = src.get_shader_parameter(u.name)
		if v != null:
			dst.set_shader_parameter(u.name, v); n += 1
	dst.render_priority = src.render_priority
	return n

static func ground(world: Node3D) -> Dictionary:
	var gr := world.get_node_or_null("SettlementTerrain/GroundRelief") as GeometryInstance3D
	if gr == null or not (gr.material_override is ShaderMaterial):
		return {"ok": false, "reason": "GroundRelief turf material missing"}
	var src: ShaderMaterial = gr.material_override
	if src.shader == GROUND_SHADER: return {"ok": true, "reused": true}
	var sm := ShaderMaterial.new()
	sm.shader = GROUND_SHADER
	sm.resource_name = "P2BInnHillGround"
	var n := _copy_params(src, sm)
	gr.material_override = sm
	return {"ok": true, "from": src.shader.resource_path, "params": n}

static func _touches_mask(g: GeometryInstance3D) -> bool:
	var bb: AABB = g.global_transform * g.get_aabb()
	return bb.position.x < MASK_MAX.x and bb.end.x > MASK_MIN.x and bb.position.z < MASK_MAX.y and bb.end.z > MASK_MIN.y

static func blades(world: Node3D) -> Dictionary:
	var cache := {}
	var swapped := 0
	var roots: Array = []
	var comp := world.find_child("SettlementGroundGrassV086", true, false)
	if comp: roots.append(comp)
	var gvc := world.get_node_or_null("GrassViewCulling")
	if gvc: roots.append(gvc)
	for r in roots:
		for n in r.find_children("Ground*", "MultiMeshInstance3D", true, false):
			var g := n as MultiMeshInstance3D
			var src := g.material_override as ShaderMaterial
			if src == null or src.shader == null or src.shader.resource_path != GRASS_LOD_PATH: continue
			if not _touches_mask(g): continue
			if not cache.has(src):
				var sm := ShaderMaterial.new()
				sm.shader = GRASS_SHADER
				sm.resource_name = "P2BInnHillGrass"
				_copy_params(src, sm)
				cache[src] = sm
			g.material_override = cache[src]
			swapped += 1
	return {"ok": swapped > 0, "batches": swapped, "materials": cache.size()}

## GDScript mirror of hill_hash / hill_noise in the two P2B shaders (sine-free, so CPU and GPU agree).
static func _fr(x: float) -> float: return x - floor(x)
static func hill_hash(p: Vector2) -> float:
	var a := _fr(p.x * 0.1031); var b := _fr(p.y * 0.1031); var c := a
	var d := a * (b + 33.33) + b * (c + 33.33) + c * (a + 33.33)
	a += d; b += d; c += d
	return _fr((a + b) * c)
static func hill_noise(p: Vector2) -> float:
	var i := p.floor(); var f := p - i
	f = f * f * (Vector2(3, 3) - 2.0 * f)
	var x0: float = lerp(hill_hash(i), hill_hash(i + Vector2(1, 0)), f.x)
	var x1: float = lerp(hill_hash(i + Vector2(0, 1)), hill_hash(i + Vector2(1, 1)), f.x)
	return lerp(x0, x1, f.y)
static func _ss(a: float, b: float, x: float) -> float: return smoothstep(a, b, x)
static func hill_mask(p: Vector2) -> float:
	return _ss(-27.0, -22.0, p.x) * (1.0 - _ss(24.0, 29.0, p.x)) * _ss(22.0, 27.0, p.y) * (1.0 - _ss(49.0, 53.0, p.y))
## {mask, dry, clover, mottle} at world xz p.
static func patch(p: Vector2) -> Dictionary:
	var dry := _ss(0.52, 0.74, hill_noise(p * 0.115 + Vector2(3.1, 9.7)))
	var clover := _ss(0.56, 0.80, hill_noise(p * 0.205 + Vector2(11.3, 4.2))) * (1.0 - dry)
	return {"mask": hill_mask(p), "dry": dry, "clover": clover, "mottle": hill_noise(p * 0.62 + Vector2(1.7, 5.3))}

static func tint(p: Vector2) -> Color:
	var q := patch(p)
	var m: float = q.mottle
	var t := Vector3.ONE * lerpf(0.88, 1.12, m)
	t = t.lerp(Vector3(1.32, 1.18, 0.62), q.dry * 0.75)
	t = t.lerp(Vector3(0.70, 0.86, 0.72), q.clover * 0.8)
	t = Vector3.ONE.lerp(t, q.mask)
	return Color(t.x, t.y, t.z)

static func lawn(world: Node3D) -> Dictionary:
	var cg := world.get_node_or_null("ContinuousGrass")
	if cg == null: return {"ok": false, "reason": "ContinuousGrass missing"}
	var changed := 0
	var chunks := 0
	for n in cg.get_children():
		var g := n as MultiMeshInstance3D
		if g == null or not String(g.name).begins_with("LawnChunk_") or g.multimesh == null or not g.multimesh.use_colors: continue
		if not _touches_mask(g): continue
		if g.has_meta("p2b_hill_tinted"): continue
		var mm := g.multimesh
		var c0 := changed
		for i in mm.instance_count:
			var t: Transform3D = g.global_transform * mm.get_instance_transform(i)
			var p := Vector2(t.origin.x, t.origin.z)
			if hill_mask(p) <= 0.0: continue
			var k := tint(p)
			var c := mm.get_instance_color(i)
			mm.set_instance_color(i, Color(c.r * k.r, c.g * k.g, c.b * k.b, c.a))
			changed += 1
		if changed > c0:
			g.set_meta("p2b_hill_tinted", true); chunks += 1
	return {"ok": true, "chunks": chunks, "instances": changed}

static func _floor_y(world: Node3D, at: Vector3, fallback: float) -> float:
	var space := world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 2.0, 0), at - Vector3(0, 2.0, 0))
	var hit := space.intersect_ray(q)
	return float(hit.position.y) if not hit.is_empty() else fallback

static func stub(world: Node3D) -> Dictionary:
	if world.has_node("P2InnPathOverlook"):
		return {"ok": true, "reused": true}
	var root := Node3D.new()
	root.name = "P2InnPathOverlook"
	world.add_child(root)
	var bench := Node3D.new()
	bench.name = "OverlookBench"
	bench.position = Vector3(BENCH_AT.x, _floor_y(world, BENCH_AT, 0.01), BENCH_AT.z)
	bench.rotation.y = PI   # bench front is local -z; PI turns it to face +z
	root.add_child(bench)
	var art := (load("res://assets/kit/plaza_bench.glb") as PackedScene).instantiate()
	bench.add_child(art)
	preload("res://scripts/architecture_materials.gd").apply(art)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/plaza_bench_v019/manifest.json"))
	var body := StaticBody3D.new()
	body.name = "MemberCollision"
	bench.add_child(body)
	var members := 0
	if manifest is Dictionary:
		for member in manifest.members:
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(member.size[0], member.size[1], member.size[2])
			shape.shape = box
			shape.position = Vector3(member.position[0], member.position[1], member.position[2])
			body.add_child(shape)
			members += 1
	preload("res://scripts/seat_interaction.gd").register_bench(bench)
	var planter := (load("res://assets/screens_planters/plaza_planter_fern.gltf") as PackedScene).instantiate() as Node3D
	planter.name = "OverlookPlanter"
	planter.position = Vector3(PLANTER_AT.x, _floor_y(world, PLANTER_AT, 0.01), PLANTER_AT.z)
	Kit.set_lods(planter, [20.0])
	root.add_child(planter)
	return {"ok": members > 0, "bench": bench.global_position, "bench_members": members, "planter": planter.global_position}
