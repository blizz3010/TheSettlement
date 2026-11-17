extends SceneTree
## Default outfit (shirt / pants / boots) under tiered gear. Checks the imported scene (LOD0 /
## LOD1, triangle budgets, external VRAM-compressed PBR textures), the skin against the
## Appearance-Proof rig (bind names, rest-pose fit, 4 weights), the body cut-out masks, the
## hooks (select stage, third-person avatar, Psy mannequin) and pose clipping: the rig is posed
## with the avatar's own idle / walk / sprint / crouch cycles and both garments and body are CPU-skinned;
## no visible skin may come out through a garment, the tucked shirt must stay under the pants
## and the trouser hem inside the boot shafts.
## Disposable profile from the runner (writes nothing).
const DefaultOutfit = preload("res://raid/scripts/outfit/default_outfit.gd")
const GearAvatar = preload("res://raid/scripts/gear_tiers/gear_avatar.gd")
const Mannequin = preload("res://raid/scripts/gear_tiers/gear_mannequin.gd")
const RIG := "res://models/Appearance-Proof.glb"
const TEX_DIR := "res://raid/assets/outfit/textures/"
const BUDGET := {"shirt": 22000, "pants": 30000, "boots": 35000}
const TOTAL_BUDGET := 85000
const TOL := 0.002          # metres of skin allowed past a garment surface before it counts as clipping
const POSES := [["idle", 0.0], ["idle", 1.5708], ["idle", 4.7124], ["walk", 0.0], ["walk", 1.5708], ["walk", 3.1416], ["walk", 4.7124],
	["sprint", 0.0], ["sprint", 1.5708], ["sprint", 3.1416], ["sprint", 4.7124],
	["crouch", 0.0], ["crouch_walk", 1.5708], ["crouch_walk", 4.7124]]
var failures: Array = []
var checks := 0
var facts := {}

class FakePlayer:
	extends Node3D
	var avatar: MeshInstance3D
	var velocity := Vector3.ZERO
	var crouched := false
	func _init():
		avatar = MeshInstance3D.new(); avatar.mesh = CapsuleMesh.new(); avatar.position.y = 0.9; add_child(avatar)

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize():
	call_deferred("run")

func tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var idx = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		n += (idx.size() if idx != null else mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX].size()) / 3
	return n

func import_cfg(path: String) -> ConfigFile:
	var c := ConfigFile.new()
	c.load(path + ".import")
	return c

## Cargo cut (loose legs, not skin-tight) and a shirt colour that can't be mistaken for skin.
func check_cut_and_colour():
	var rep = JSON.parse_string(FileAccess.get_file_as_string("res://raid/assets/outfit/BUILD-REPORT.json"))
	var ease := float(rep.pants.get("leg_ease_median_m", 0.0)) if rep is Dictionary else 0.0
	check(ease >= 0.02, "Cargo pants hang loose over the thigh/knee (median %.1f mm off the skin, >= 20 mm)" % (ease * 1000))
	facts["pants_leg_ease_median_m"] = ease
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://raid/assets/outfit/textures/outfit_knit_base.jpg"))
	img.resize(16, 16, Image.INTERPOLATE_BILINEAR)
	var c := Color(0, 0, 0)
	for y in 16:
		for x in 16: c += img.get_pixel(x, y)
	c /= 256.0
	# Skin tones are red > green > blue with a warm hue (0-50 deg); the shirt must sit well away from that.
	var warm := c.r > c.g and c.g > c.b and (c.h < 0.14 or c.h > 0.97)
	check(not warm and c.b >= c.r, "Shirt albedo is a cool slate, not a skin tone (avg %s, hue %.0f deg)" % [c.to_html(false), c.h * 360.0])
	facts["shirt_albedo_avg"] = c.to_html(false)

func run():
	check(DefaultOutfit.available(), "Default outfit scene is present")
	check(DefaultOutfit.mask_tag(["boots", "shirt"]) == "101" and DefaultOutfit.mask_tag([]) == "000", "Mask tags follow shirt/pants/boots order")
	var masks_ok := true
	for tag in ["000", "001", "010", "011", "100", "101", "110", "111"]:
		if not ResourceLoader.exists(DefaultOutfit.MASK % tag): masks_ok = false
	check(masks_ok, "All 8 body cut-out masks are present")
	check_scene()
	check_masks()
	check_cut_and_colour()
	var rig: Node3D = (load(RIG) as PackedScene).instantiate()
	root.add_child(rig)
	var sk := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var body := rig.find_child("ProofBody", true, false) as MeshInstance3D
	check(sk != null and body != null, "Appearance-Proof rig loads")
	if sk != null and body != null:
		await check_dress(sk, body)
		await check_clipping(sk, body)
	rig.queue_free()
	await process_frame
	await check_select_stage()
	await check_avatar()
	await check_mannequin()
	print("DEFAULT_OUTFIT_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "facts": facts}))
	quit(0 if failures.is_empty() else 1)

# ------------------------------------------------------------------ imported scene
func check_scene():
	var inst := (load(DefaultOutfit.SCENE) as PackedScene).instantiate()
	var rig: Node3D = (load(RIG) as PackedScene).instantiate()
	var rsk := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var total := 0
	for p in DefaultOutfit.ORDER:
		var m0 := inst.find_child(DefaultOutfit.MESH[p], true, false) as MeshInstance3D
		var m1 := inst.find_child(DefaultOutfit.MESH[p] + "_LOD1", true, false) as MeshInstance3D
		check(m0 != null and m1 != null and m0.skin != null and m1.skin != null, p + ": LOD0 + LOD1 skinned meshes")
		if m0 == null or m1 == null: continue
		var t0 := tris(m0.mesh); var t1 := tris(m1.mesh); total += t0
		check(t0 >= 4000 and t0 <= BUDGET[p], "%s LOD0 %d tris within budget %d (mid-to-high poly)" % [p, t0, BUDGET[p]])
		var ratio := float(t1) / maxf(t0, 1)
		check(ratio > 0.3 and ratio < 0.5, "%s LOD1 ~40%% (%.3f)" % [p, ratio])
		var names_ok := true
		var rest_fit := 0.0
		for b in m0.skin.get_bind_count():
			var j := rsk.find_bone(m0.skin.get_bind_name(b))
			if j < 0: names_ok = false; continue
			rest_fit = maxf(rest_fit, (rsk.get_bone_global_rest(j) * m0.skin.get_bind_pose(b)).origin.length())
		check(names_ok, p + " skin binds are named Appearance-Proof bones")
		check(rest_fit < 0.001, "%s bind poses invert the rig rest (%.5f m)" % [p, rest_fit])
		var max_w := 0
		var mats := []
		var ext_ok := true
		var vram_ok := true
		for s in m0.mesh.get_surface_count():
			var a = m0.mesh.surface_get_arrays(s)
			max_w = maxi(max_w, (a[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array).size() / maxi((a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 1))
			var m := m0.mesh.surface_get_material(s) as StandardMaterial3D
			if m == null: ext_ok = false; continue
			mats.append(str(m.resource_name))
			var set := [m.albedo_texture, m.normal_texture, m.roughness_texture]
			if not m.normal_enabled or set.has(null): ext_ok = false; continue
			for i in set.size():
				var path := str(set[i].resource_path)
				if not (path.begins_with(TEX_DIR + "outfit_") and path.ends_with(".jpg")): ext_ok = false
				var cfg := import_cfg(path)
				if int(cfg.get_value("params", "compress/mode", -1)) != 2 or not bool(cfg.get_value("params", "mipmaps/generate", false)): vram_ok = false
				if i == 1 and int(cfg.get_value("params", "compress/normal_map", -1)) != 1: vram_ok = false
		check(max_w == 4, p + " uses 4 weights per vertex")
		check(mats.size() >= 2, "%s has %d PBR material surfaces %s" % [p, mats.size(), str(mats)])
		check(ext_ok, p + " albedo/normal/ORM are external JPGs under " + TEX_DIR)
		check(vram_ok, p + " textures import VRAM-compressed with mipmaps (normals as normal maps)")
		facts[p] = {"lod0_tris": t0, "lod1_tris": t1, "materials": mats}
	check(total <= TOTAL_BUDGET, "Whole outfit LOD0 %d tris <= %d" % [total, TOTAL_BUDGET])
	facts["total_lod0_tris"] = total
	var gl := FileAccess.get_file_as_string(DefaultOutfit.SCENE)
	check(not gl.contains("data:") and gl.contains("textures/outfit_"), "glTF references external textures (nothing embedded)")
	var rep = JSON.parse_string(FileAccess.get_file_as_string("res://raid/assets/outfit/BUILD-REPORT.json"))
	var rest_ok := rep is Dictionary
	if rest_ok:
		for p in DefaultOutfit.ORDER:
			if not rep.has(p) or float(rep[p].clearance_m) <= 0.0 or int(rep[p].verts_inside_skin) != 0: rest_ok = false
		facts["rest_clearance_m"] = {"shirt": rep.shirt.clearance_m, "pants": rep.pants.clearance_m, "boots": rep.boots.clearance_m}
	check(rest_ok, "BUILD-REPORT: every piece clears the skin at rest, no vertex inside")
	inst.free(); rig.free()

# ------------------------------------------------------------------ masks
func mask_image(tag: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(DefaultOutfit.MASK % tag))

func hidden_px(img: Image) -> int:
	var n := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			if img.get_pixel(x, y).a < 0.5: n += 1
	return n

func check_masks():
	var h := {}
	for tag in ["000", "100", "010", "001", "111"]:
		var img := mask_image(tag)
		h[tag] = hidden_px(img) if img != null else -1
	check(h["000"] == 0, "Mask 000 hides nothing")
	check(h["100"] > 0 and h["010"] > 0 and h["001"] > 0, "Each piece hides some skin")
	check(h["111"] >= h["100"] + h["010"] + h["001"], "Full outfit hides at least the union (overlaps under the waist / boot tops too)")
	facts["mask_hidden_px_quarter_res"] = h

# ------------------------------------------------------------------ dress / masks on a body
func check_dress(sk: Skeleton3D, body: MeshInstance3D):
	var base := body.get_active_material(0)
	check(DefaultOutfit.dress(sk, DefaultOutfit.ORDER, 0, body) == ["shirt", "pants", "boots"], "dress() binds all three pieces")
	await process_frame
	var kids := sk.get_children().filter(func(c): return c.has_meta("outfit_piece"))
	check(kids.size() == 3 and kids.all(func(c): return c.skeleton == NodePath("..") and int(c.get_meta("lod")) == 0), "Pieces are LOD0 MeshInstance3Ds under the skeleton")
	var m := body.get_surface_override_material(0) as BaseMaterial3D
	check(m != null and m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and m.albedo_texture != null and str(m.albedo_texture.resource_path).ends_with("body_mask_111.png"), "Body skin is cut out under the full outfit (mask 111, alpha scissor)")
	check(m != null and base is BaseMaterial3D and m.albedo_color == (base as BaseMaterial3D).albedo_color, "Cut-out keeps the skin colour")
	DefaultOutfit.show_pieces(sk, body, ["pants", "boots"])
	m = body.get_surface_override_material(0) as BaseMaterial3D
	check(DefaultOutfit.pieces_on(sk) == ["pants", "boots"] and m != null and str(m.albedo_texture.resource_path).ends_with("body_mask_011.png"), "show_pieces() hides the shirt and re-cuts the skin (011)")
	DefaultOutfit.show_pieces(sk, body, [])
	check(body.get_surface_override_material(0) == null, "No pieces -> the body's own material is back")
	DefaultOutfit.show_pieces(sk, body, DefaultOutfit.ORDER)
	facts["outfit_tris_on_rig"] = DefaultOutfit.tris(sk)

# ------------------------------------------------------------------ pose clipping (CPU skinning)
class Skinner:
	var sk: Skeleton3D
	var skin: Skin
	var bb: Array = []
	var mats: Array = []
	func _init(s: Skeleton3D, k: Skin):
		sk = s; skin = k
		for b in skin.get_bind_count(): bb.append(sk.find_bone(skin.get_bind_name(b)))
	func update():
		mats.clear()
		for b in bb.size(): mats.append(sk.get_bone_global_pose(bb[b]) * skin.get_bind_pose(b))
	func point(v: Vector3, bones: PackedInt32Array, w: PackedFloat32Array, k: int) -> Transform3D:
		var basis := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
		var origin := Vector3.ZERO
		var ws := 0.0
		for j in 4:
			var ww := w[k * 4 + j]
			if ww <= 0.0: continue
			var t: Transform3D = mats[bones[k * 4 + j]]
			basis.x += t.basis.x * ww; basis.y += t.basis.y * ww; basis.z += t.basis.z * ww
			origin += t.origin * ww; ws += ww
		basis.x /= ws; basis.y /= ws; basis.z /= ws; origin /= ws
		return Transform3D(basis, origin)

## Sampled vertices of a mesh (optionally one surface / a filter on rest position).
func samples(mi: MeshInstance3D, step: int, surface_mat: String = "") -> Dictionary:
	var out := {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "b": PackedInt32Array(), "w": PackedFloat32Array()}
	for s in mi.mesh.get_surface_count():
		if surface_mat != "":
			var m := mi.mesh.surface_get_material(s)
			if m == null or str(m.resource_name) != surface_mat: continue
		var a = mi.mesh.surface_get_arrays(s)
		var V: PackedVector3Array = a[Mesh.ARRAY_VERTEX]; var N: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var UV = a[Mesh.ARRAY_TEX_UV]; var B: PackedInt32Array = a[Mesh.ARRAY_BONES]; var W: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		for k in range(0, V.size(), step):
			out.v.append(V[k]); out.n.append(N[k]); out.uv.append(UV[k] if UV != null else Vector2.ZERO)
			for j in 4: out.b.append(B[k * 4 + j]); out.w.append(W[k * 4 + j])
	return out

func skin_all(sm: Skinner, d: Dictionary) -> Array:
	sm.update()
	var P := PackedVector3Array(); var Nn := PackedVector3Array()
	for k in d.v.size():
		var t := sm.point(d.v[k], d.b, d.w, k)
		P.append(t * d.v[k]); Nn.append((t.basis * d.n[k]).normalized())
	return [P, Nn]

## For each `a` point, index of the nearest `b` point within `radius` (rest pose), or -1.
func pair(a: PackedVector3Array, b: PackedVector3Array, radius: float) -> PackedInt32Array:
	var cell := radius
	var grid := {}
	for i in b.size():
		var key := Vector3i((b[i] / cell).floor())
		if not grid.has(key): grid[key] = []
		grid[key].append(i)
	var out := PackedInt32Array()
	for p in a:
		var c := Vector3i((p / cell).floor())
		var best := -1; var bd := radius * radius
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var key := c + Vector3i(dx, dy, dz)
					if not grid.has(key): continue
					for i in grid[key]:
						var dd := p.distance_squared_to(b[i])
						if dd < bd: bd = dd; best = i
		out.append(best)
	return out

## Indices of `rest` points that face away from the skin (outer garment surface): excludes the
## inner faces of bands and the backs of thickened patches.
func outer_facing(rest: Array, b_rest: Array) -> Array:
	var pr := pair(rest[0], b_rest[0], 0.05)
	var keep := []
	for k in pr.size():
		if pr[k] >= 0 and (rest[1][k] as Vector3).dot(b_rest[1][pr[k]]) > 0.6: keep.append(k)
	return keep

func subset(rest: Array, idx: Array) -> Array:
	var P := PackedVector3Array(); var N := PackedVector3Array()
	for k in idx: P.append(rest[0][k]); N.append(rest[1][k])
	return [P, N]

func check_clipping(sk: Skeleton3D, body: MeshInstance3D):
	var pieces := {}
	for c in sk.get_children():
		if c.has_meta("outfit_piece"): pieces[str(c.get_meta("outfit_piece"))] = c
	var bs := Skinner.new(sk, body.skin)
	var bd := samples(body, 1)
	sk.reset_bone_poses()
	var b_rest: Array = skin_all(bs, bd)
	# Skin each piece leaves visible when worn on its own (its hems meet bare skin), so every
	# hem is tested even where the full outfit would cover it with the next piece.
	var vis_of := {}
	for p in DefaultOutfit.ORDER:
		var mask := mask_image(DefaultOutfit.mask_tag([p]))
		var visible := PackedByteArray(); visible.resize(bd.v.size())
		for k in bd.v.size():
			var uv: Vector2 = bd.uv[k]
			var px := mask.get_pixel(clampi(int(uv.x * mask.get_width()), 0, mask.get_width() - 1), clampi(int(uv.y * mask.get_height()), 0, mask.get_height() - 1))
			visible[k] = 1 if px.a >= 0.5 else 0
		vis_of[p] = visible
	var avatar = GearAvatar.new()
	avatar.skeleton = sk
	var layers := {}
	for p in DefaultOutfit.ORDER:
		var mi: MeshInstance3D = pieces[p]
		var sm := Skinner.new(sk, mi.skin)
		var d := samples(mi, 3)
		sk.reset_bone_poses()
		var rest: Array = skin_all(sm, d)
		var pr := pair(rest[0], b_rest[0], 0.05)
		layers[p] = {"sm": sm, "d": d, "rest": rest, "pair": pr}
	# Layering pairs: tucked shirt -> pants twill, trouser hem -> boot leather.
	var tuck := samples(pieces.shirt, 2); var tuck_keep := []
	sk.reset_bone_poses()
	var tuck_rest: Array = skin_all(layers.shirt.sm, tuck)
	var twill := samples(pieces.pants, 1, "outfit_twill")
	var twill_rest: Array = skin_all(layers.pants.sm, twill)
	var twill_out := outer_facing(twill_rest, b_rest)
	for k in tuck.v.size(): if tuck_rest[0][k].y < 0.90: tuck_keep.append(k)
	var tuck_pts := PackedVector3Array(); for k in tuck_keep: tuck_pts.append(tuck_rest[0][k])
	var tuck_pair := pair(tuck_pts, subset(twill_rest, twill_out)[0], 0.03)
	var hem := samples(pieces.pants, 1); var hem_keep := []
	var hem_rest: Array = skin_all(layers.pants.sm, hem)
	var leather := samples(pieces.boots, 1, "outfit_leather")
	var leather_rest: Array = skin_all(layers.boots.sm, leather)
	var leather_out := outer_facing(leather_rest, b_rest)
	for k in hem.v.size(): if hem_rest[0][k].y < 0.19: hem_keep.append(k)
	var hem_pts := PackedVector3Array(); for k in hem_keep: hem_pts.append(hem_rest[0][k])
	var hem_pair := pair(hem_pts, subset(leather_rest, leather_out)[0], 0.04)
	var stats := {}
	for p in DefaultOutfit.ORDER: stats[p] = {"visible_pairs": 0, "visible_clip": 0, "worst_visible_m": 1.0, "worst_hidden_m": 1.0}
	var tuck_worst := 1.0; var tuck_out := 0
	var hem_worst := 1.0; var hem_out := 0
	var per_pose := {}
	for pose in POSES:
		avatar.apply_pose(pose[0], pose[1])
		var b: Array = skin_all(bs, bd)
		var pose_clip := 0
		for p in DefaultOutfit.ORDER:
			var L: Dictionary = layers[p]
			var g: Array = skin_all(L.sm, L.d)
			var st: Dictionary = stats[p]
			var visible: PackedByteArray = vis_of[p]
			for k in L.pair.size():
				var j: int = L.pair[k]
				if j < 0: continue
				var sd: float = (g[0][k] - b[0][j]).dot(b[1][j])
				if visible[j] == 1:
					st.visible_pairs += 1
					st.worst_visible_m = minf(st.worst_visible_m, sd)
					if sd < -TOL:
						st.visible_clip += 1; pose_clip += 1
						if OS.has_environment("OUTFIT_DEBUG") and pose[0] == "idle" and pose[1] == 0.0: print("CLIP ", p, " g=", L.rest[0][k], " gn=", L.rest[1][k], " b=", b_rest[0][j], " sd=", sd)
				else:
					st.worst_hidden_m = minf(st.worst_hidden_m, sd)
		var ts: Array = skin_all(layers.shirt.sm, tuck)
		var tw: Array = subset(skin_all(layers.pants.sm, twill), twill_out)
		for i in tuck_pair.size():
			var j: int = tuck_pair[i]
			if j < 0: continue
			var sd: float = (tw[0][j] - ts[0][tuck_keep[i]]).dot(tw[1][j])   # pants outside shirt = positive
			tuck_worst = minf(tuck_worst, sd)
			if sd < -TOL:
				tuck_out += 1
				if OS.has_environment("OUTFIT_DEBUG"): print("TUCK ", pose, " s=", tuck_rest[0][tuck_keep[i]], " p=", tw[0][j], " pn=", tw[1][j], " sd=", sd)
		var hs: Array = skin_all(layers.pants.sm, hem)
		var lb: Array = subset(skin_all(layers.boots.sm, leather), leather_out)
		for i in hem_pair.size():
			var j: int = hem_pair[i]
			if j < 0: continue
			var sd: float = (lb[0][j] - hs[0][hem_keep[i]]).dot(lb[1][j])
			hem_worst = minf(hem_worst, sd)
			if sd < -TOL:
				hem_out += 1
				if OS.has_environment("OUTFIT_DEBUG") and pose[0] == "idle" and pose[1] == 0.0: print("HEM s=", hem_rest[0][hem_keep[i]], " p=", lb[0][j], " pn=", lb[1][j], " sd=", sd)
		per_pose["%s@%.2f" % [pose[0], pose[1]]] = pose_clip
	sk.reset_bone_poses()
	avatar.free()
	for p in DefaultOutfit.ORDER:
		var st: Dictionary = stats[p]
		check(st.visible_pairs > 100, "%s: %d garment/visible-skin pairs tested over %d poses" % [p, st.visible_pairs, POSES.size()])
		check(st.visible_clip == 0, "%s: no visible skin through the garment (worn alone) in idle/walk/sprint/crouch (%d samples past %.0f mm, worst %.1f mm)" % [p, st.visible_clip, TOL * 1000, st.worst_visible_m * 1000])
		st.worst_visible_m = snappedf(st.worst_visible_m, 0.0001); st.worst_hidden_m = snappedf(st.worst_hidden_m, 0.0001)
	check(tuck_pair.size() > 20 and tuck_out == 0, "Tucked shirt stays under the pants in every pose (%d pairs, worst %.1f mm)" % [tuck_pair.size(), tuck_worst * 1000])
	check(hem_pair.size() > 20 and hem_out == 0, "Trouser hems stay inside the boot shafts in every pose (%d pairs, worst %.1f mm)" % [hem_pair.size(), hem_worst * 1000])
	facts["clipping"] = {"tol_m": TOL, "poses": POSES.size(), "per_piece": stats, "per_pose_visible_clip": per_pose,
		"tuck_worst_m": snappedf(tuck_worst, 0.0001), "hem_in_boot_worst_m": snappedf(hem_worst, 0.0001)}

# ------------------------------------------------------------------ hooks
func check_select_stage():
	var title = (load("res://raid/play_title.tscn") as PackedScene).instantiate()
	root.add_child(title); current_scene = title
	await process_frame
	title.play_button.pressed.emit()
	await process_frame
	var panel = title.character_panel
	var stage = panel.preview if is_instance_valid(panel) else null
	check(stage != null and stage.model_ok, "Select screen stage has the Appearance-Proof rig")
	if stage != null and stage.model_ok:
		var body: MeshInstance3D = stage.rig_meshes.ProofBody
		var expect := DefaultOutfit.ORDER.filter(func(p): return not (stage.garments.has(DefaultOutfit.SLOT[p]) and stage.garments[DefaultOutfit.SLOT[p]].visible))
		check(DefaultOutfit.pieces_on(stage.skeleton) == expect and str(body.get_meta("outfit_mask", "")) == DefaultOutfit.mask_tag(expect), "Select stage wears the default outfit where no clothing slot is equipped %s" % str(expect))
		for slot in ["jacket", "pants", "boots"]: if stage.garments.has(slot): stage.garments[slot].visible = false
		stage._apply_default_outfit()
		check(DefaultOutfit.pieces_on(stage.skeleton) == ["shirt", "pants", "boots"] and str(body.get_meta("outfit_mask")) == "111", "Empty clothing slots -> full default outfit, skin cut out (111)")
		if stage.garments.has("jacket"):
			stage.garments.jacket.visible = true
			stage._apply_default_outfit()
			check(DefaultOutfit.pieces_on(stage.skeleton) == ["pants", "boots"] and str(body.get_meta("outfit_mask")) == "011", "Equipped jacket replaces the shirt (mask 011)")
			stage.garments.jacket.visible = false
			stage._apply_default_outfit()
		var shown: Array = stage.show_gear(["gear_body_armor_t3", "gear_helmet_t3"])
		check(shown.size() == 2 and DefaultOutfit.pieces_on(stage.skeleton).size() == 3, "Worn T3 gear goes over the default outfit")
		stage.show_gear([])
	title.queue_free()
	current_scene = null
	await process_frame
	await process_frame

func check_avatar():
	var p := FakePlayer.new(); root.add_child(p)
	var a = GearAvatar.install(p, [])
	await process_frame
	check(a != null and p.avatar.layers == 0, "Third-person: no gear -> dressed avatar replaces the capsule")
	if a != null:
		var body := a.rig.find_child("ProofBody", true, false) as MeshInstance3D
		check(a.outfit_pieces() == ["shirt", "pants", "boots"] and str(body.get_meta("outfit_mask", "")) == "111", "Avatar wears the full default outfit (LOD0), skin cut out")
		var m := body.get_surface_override_material(0) as BaseMaterial3D
		check(m != null and m.albedo_color.r < 0.75, "Avatar keeps its toned skin under the cut-out")
		a = GearAvatar.install(p, ["gear_body_armor_t3", "gear_helmet_t3"])
		check(a.attached_ids().size() == 2 and a.outfit_pieces().size() == 3, "Gear goes over the outfit on the avatar")
	p.queue_free()
	await process_frame

func check_mannequin():
	var m := Mannequin.new(); root.add_child(m)
	await process_frame
	check(m.model_ok and m.outfit_pieces() == ["shirt", "pants", "boots"], "Psy mannequin wears the default outfit")
	var lods := []
	for c in m.skeleton.get_children():
		if c.has_meta("outfit_piece"): lods.append(int(c.get_meta("lod")))
	check(lods == [1, 1, 1], "Mannequin outfit uses the LOD1 meshes")
	var body := m.skeleton.get_parent().find_child("ProofBody", true, false) as MeshInstance3D
	if body == null: body = m.find_child("ProofBody", true, false) as MeshInstance3D
	var mo := body.material_override as BaseMaterial3D if body != null else null
	check(mo != null and mo.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and mo.albedo_color == Color("8d918c"), "Mannequin form is cut out under the outfit and keeps its grey")
	check(m.show_loadout(["gear_body_armor_t3"]) == ["gear_body_armor_t3"] and m.outfit_pieces().size() == 3, "Mannequin gear goes over the outfit")
	m.queue_free()
	await process_frame
