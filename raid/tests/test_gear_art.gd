extends SceneTree
## Gear art E0 + E1-A (TASKS item 22): the T3 Warden Helm + T3 Bulwark Carrier art pilot and the
## T1 Shell Cap + T1 Padded Vest. Every set runs the same scene / skin / fit-over-outfit checks.
## Checks the per-item-id lookup and its placeholder fallback, the imported scenes (LOD0/LOD1,
## triangle budgets, external VRAM-compressed PBR textures), the skin against the
## Appearance-Proof rig (bind names, rest-pose fit, bone weights, CPU-skinned deformation),
## and the hooks: select stage, third-person avatar, Psy equip mannequin, raid loot icons.
## Disposable profile from the runner (writes only user://gear_art_test/).
const GearArt = preload("res://raid/scripts/gear_tiers/gear_art.gd")
const GearAvatar = preload("res://raid/scripts/gear_tiers/gear_avatar.gd")
const Mannequin = preload("res://raid/scripts/gear_tiers/gear_mannequin.gd")
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const State = preload("res://raid/scripts/gear_tiers/gear_locker_state.gd")
const RIG := "res://models/Appearance-Proof.glb"
const DefaultOutfit = preload("res://raid/scripts/outfit/default_outfit.gd")
const FIT_TOL := 0.003   # metres a vest vertex may sit inside an arm / the shirt before it counts
const FIT_POSES := [["idle", 0.0], ["idle", 3.1416], ["walk", 0.0], ["walk", 1.5708], ["walk", 3.1416], ["walk", 4.7124],
	["sprint", 0.0], ["sprint", 1.5708], ["sprint", 3.1416], ["sprint", 4.7124], ["crouch", 0.0]]
const HELM := "gear_helmet_t3"
const VEST := "gear_body_armor_t3"
const HELM1 := "gear_helmet_t1"
const VEST1 := "gear_body_armor_t1"
## Art sets: helmet + vest per tier, the helmet's strap / shell material names (strap-over-hair
## check), and the PBR surface count per piece.
const SETS := [
	{"tier": "t3", "helm": HELM, "vest": VEST, "strap": "T3_Webbing", "shell": "T3_Shell"},
	{"tier": "t1", "helm": HELM1, "vest": VEST1, "strap": "T1_Strap", "shell": "T1_Canvas"}]
const MATS := {HELM: 6, VEST: 6, HELM1: 5, VEST1: 4}
const TORSO_BONES := ["pelvis", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"]
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

## CPU skinning of one vertex with the skeleton's current pose.
func skinned(sk: Skeleton3D, skin: Skin, bind_bone: Array, v: Vector3, bones: PackedInt32Array, weights: PackedFloat32Array, k: int) -> Vector3:
	var out := Vector3.ZERO
	var wsum := 0.0
	for j in 4:
		var w := weights[k * 4 + j]
		if w <= 0.0: continue
		var b: int = bones[k * 4 + j]
		out += (sk.get_bone_global_pose(bind_bone[b]) * skin.get_bind_pose(b) * v) * w
		wsum += w
	return out / maxf(wsum, 1e-6)

func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://gear_art_test"))
	check_lookup()
	var rig: Node3D = (load(RIG) as PackedScene).instantiate()
	root.add_child(rig)
	var sk := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	check(sk != null and sk.get_bone_count() == 53, "Appearance-Proof rig has its 53-bone skeleton")
	for id in [HELM, VEST, HELM1, VEST1]: check_scene(id, sk)
	for st in SETS:
		await check_deformation(sk, st.helm, st.vest, st.tier)
		await check_fit_over_outfit(sk, rig.find_child("ProofBody", true, false) as MeshInstance3D, st)
	rig.queue_free()
	await process_frame
	await check_select_stage()
	await check_avatar()
	await check_mannequin_and_icons()
	check_locker_peek()
	print("GEAR_ART_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "facts": facts}))
	quit(0 if failures.is_empty() else 1)

# ------------------------------------------------------------------ lookup / fallback
func check_lookup():
	var want := [HELM, VEST, HELM1, VEST1]
	check(GearArt.ids().size() == 4 and want.all(func(i): return i in GearArt.ids()), "E0 + E1-A art covers exactly the T3 and T1 helmet + vest")
	check(want.all(func(i): return GearArt.has_art(i)), "All four pieces resolve to an art scene")
	check(not GearArt.has_art("gear_helmet_t2") and not GearArt.has_art("gear_backpack_t3") and not GearArt.has_art("nope"), "Other ids have no art yet")
	for id in want: check(Defs.item(id).size() > 0, id + " is a real gear def")
	var art := GearArt.build(HELM, 0)
	check(art != null and art.get_meta("gear_art", false), "build() returns the art scene for an id with art")
	var visible := []
	if art != null:
		for mi in art.find_children("*", "MeshInstance3D", true, false):
			if mi.visible: visible.append(str(mi.name))
		art.free()
	check(visible == ["WardenHelm"], "build(lod 0) shows only the LOD0 mesh: " + str(visible))
	var art1 := GearArt.build(VEST, 1)
	visible = []
	if art1 != null:
		for mi in art1.find_children("*", "MeshInstance3D", true, false):
			if mi.visible: visible.append(str(mi.name))
		art1.free()
	check(visible == ["BulwarkCarrier_LOD1"], "build(lod 1) shows only the LOD1 mesh: " + str(visible))
	for pr in [[HELM1, 0, "ShellCap"], [VEST1, 1, "PaddedVest_LOD1"]]:
		var a1 := GearArt.build(pr[0], pr[1])
		visible = []
		if a1 != null:
			for mi in a1.find_children("*", "MeshInstance3D", true, false):
				if mi.visible: visible.append(str(mi.name))
			a1.free()
		check(visible == [pr[2]], "%s build(lod %d) shows only %s: %s" % [pr[0], pr[1], pr[2], str(visible)])
	var ph := GearArt.build("gear_helmet_t2", 0)
	check(ph != null and not ph.has_meta("gear_art"), "Ids without art fall back to the PR A placeholder")
	if ph != null: ph.free()
	check(want.all(func(i): return GearArt.icon(i) is Texture2D), "All four pieces have a rendered icon")
	check(GearArt.icon("gear_helmet_t2") == null, "No icon for ids without art (callers keep the tier chip)")
	check(GearArt.covered([HELM, VEST, "gear_backpack_t3"]) == ["helmet", "jacket_torso"], "Covers: helmet + jacket torso")
	check(GearArt.covered([HELM1, VEST1]) == ["helmet", "jacket_torso"] and GearArt.helmet_hair(HELM1) == "hair_short02_v1", "T1 covers helmet + jacket torso and wears the short helmet hair")

# ------------------------------------------------------------------ imported scene
func check_scene(id: String, sk: Skeleton3D):
	var spec: Dictionary = GearArt.ART[id]
	var tier := id.right(2)
	var is_helm := id.begins_with("gear_helmet")
	var packed := load(GearArt.scene_path(id)) as PackedScene
	check(packed != null, id + " scene loads")
	if packed == null: return
	var inst := packed.instantiate()
	var lod0 := inst.find_child(str(spec.mesh), true, false) as MeshInstance3D
	var lod1 := inst.find_child(str(spec.mesh) + GearArt.LOD1_SUFFIX, true, false) as MeshInstance3D
	check(lod0 != null and lod1 != null, id + " has LOD0 and LOD1 meshes")
	if lod0 == null or lod1 == null:
		inst.free(); return
	var t0 := tris(lod0.mesh)
	var t1 := tris(lod1.mesh)
	var ratio := float(t1) / float(maxi(t0, 1))
	check(t0 >= 8000 and t0 <= int(spec.tri_budget), "%s LOD0 is mid-high poly within budget (%d <= %d)" % [id, t0, spec.tri_budget])
	check(ratio >= 0.3 and ratio <= 0.5, "%s LOD1 is ~40%% (%.2f)" % [id, ratio])
	# Same rig: the art's skeleton matches the Appearance-Proof rest pose bone for bone.
	var ask := inst.find_child("Skeleton3D", true, false) as Skeleton3D
	var rest_err := 0.0
	if ask != null:
		for b in ask.get_bone_count():
			var j := sk.find_bone(ask.get_bone_name(b))
			if j < 0: rest_err = 99.0; break
			rest_err = maxf(rest_err, ask.get_bone_global_rest(b).origin.distance_to(sk.get_bone_global_rest(j).origin))
	check(ask != null and ask.get_bone_count() == sk.get_bone_count() and rest_err < 0.001, "%s skeleton = Appearance-Proof rest (max %.5f m)" % [id, rest_err])
	var skin := lod0.skin
	var names_ok := skin != null and skin.get_bind_count() > 0
	var rest_fit := 0.0
	if skin != null:
		for b in skin.get_bind_count():
			var j := sk.find_bone(skin.get_bind_name(b))
			if j < 0: names_ok = false; continue
			var ident := sk.get_bone_global_rest(j) * skin.get_bind_pose(b)
			rest_fit = maxf(rest_fit, ident.origin.length())
	check(names_ok, id + " skin binds are named Appearance-Proof bones")
	check(rest_fit < 0.001, "%s bind poses invert the rig rest (rest-pose fit %.5f m)" % [id, rest_fit])
	# Weights: helmet rigid on head; vest only on torso bones.
	var used := {}
	var max_w := 0
	for s in lod0.mesh.get_surface_count():
		var a = lod0.mesh.surface_get_arrays(s)
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		for k in w.size():
			if w[k] > 0.001: used[str(skin.get_bind_name(bones[k]))] = true
		max_w = maxi(max_w, w.size() / maxi(a[Mesh.ARRAY_VERTEX].size(), 1))
	var used_names := used.keys(); used_names.sort()
	if is_helm: check(used_names == ["head"], "Helmet is rigid on the head bone: " + str(used_names))
	else: check(used_names.size() >= 4 and used_names.all(func(n): return n in TORSO_BONES), "Vest weights only on torso bones: " + str(used_names))
	check(max_w == 4, id + " uses 4 weights per vertex")
	# Materials: PBR surfaces with external, VRAM-compressed, mipmapped textures (<= 2048 px).
	var mats := 0
	var ext_ok := true
	var vram_ok := true
	var tex_paths := {}
	var max_px := 0
	for s in lod0.mesh.get_surface_count():
		var m := lod0.mesh.surface_get_material(s) as StandardMaterial3D
		if m == null: continue
		mats += 1
		var set := [m.albedo_texture, m.normal_texture, m.roughness_texture, m.ao_texture]
		if not m.normal_enabled or not m.ao_enabled or set.has(null): ext_ok = false; continue
		for i in set.size():
			var p := str(set[i].resource_path)
			if not (p.begins_with("res://raid/assets/gear/%s/textures/" % tier) and p.ends_with(".jpg")): ext_ok = false
			tex_paths[p] = true
			max_px = maxi(max_px, maxi(set[i].get_width(), set[i].get_height()))
			var cfg := import_cfg(p)
			if int(cfg.get_value("params", "compress/mode", -1)) != 2 or not bool(cfg.get_value("params", "mipmaps/generate", false)): vram_ok = false
			if i == 1 and int(cfg.get_value("params", "compress/normal_map", -1)) != 1: vram_ok = false
	check(mats == int(MATS[id]), "%s has %d PBR material surfaces (%d)" % [id, MATS[id], mats])
	check(ext_ok, id + " albedo/normal/ORM/AO are external JPGs under raid/assets/gear/%s/textures" % tier)
	check(vram_ok, id + " textures import VRAM-compressed with mipmaps (normals as normal maps)")
	check(max_px > 0 and max_px <= 2048, "%s textures are at most 2048 px (%d)" % [id, max_px])
	var gl := FileAccess.get_file_as_string(GearArt.scene_path(id))
	check(not gl.contains("data:") and gl.contains("textures/%s_" % tier) and gl.contains(".jpg"), id + " glTF references external JPGs (nothing embedded)")
	var bytes := 0
	for p in tex_paths.keys(): bytes += FileAccess.get_file_as_bytes(p).size()
	var bin := FileAccess.get_file_as_bytes(GearArt.scene_path(id).get_basename() + ".bin").size()
	facts[id] = {"lod0_tris": t0, "lod1_tris": t1, "lod1_ratio": snappedf(ratio, 0.001), "bin_bytes": bin,
		"gltf_bytes": gl.length(), "texture_bytes": bytes, "max_texture_px": max_px, "bones": used_names, "rest_fit_m": snappedf(rest_fit, 0.00001)}
	inst.free()

# ------------------------------------------------------------------ deformation (CPU skinning)
func check_deformation(sk: Skeleton3D, hid: String, vid: String, tier: String):
	var rep = JSON.parse_string(FileAccess.get_file_as_string("res://raid/assets/gear/%s/BUILD-REPORT.json" % tier))
	check(rep is Dictionary and rep.has(hid) and rep.has(vid), "%s BUILD-REPORT lists both pieces" % tier)
	if rep is Dictionary and rep.has(vid):
		check(float(rep[vid].clearance_m) > 0.0 and int(rep[vid].verts_inside_skin) == 0, tier + ": " + "Vest clears the body at rest (%s m)" % rep[vid].clearance_m)
		check(float(rep[hid].clearance_m) > -0.01 and int(rep[hid].verts_inside_skin) <= 2, tier + ": " + "Helmet within 1 cm of the head+hair shell (%s m, %s verts)" % [rep[hid].clearance_m, rep[hid].verts_inside_skin])
		facts["clearance_m_" + tier] = {hid: rep[hid].clearance_m, vid: rep[vid].clearance_m}
	var helm := GearArt.attach(sk, hid, 0)
	var vest := GearArt.attach(sk, vid, 0)
	check(helm != null and vest != null and helm.get_parent() == sk and helm.skeleton == NodePath(".."), tier + ": " + "attach() binds both meshes under the character skeleton")
	if helm == null or vest == null: return
	check(GearArt.attach(sk, "gear_helmet_t2", 0) == null, "attach() refuses ids without art (no placeholder on characters)")
	await process_frame
	sk.reset_bone_poses()
	var head := sk.find_bone("head")
	var spine := sk.find_bone("spine_02")
	var head_rest := sk.get_bone_global_pose(head)
	var data := {}
	for pair in [[helm, hid], [vest, vid]]:
		var mi: MeshInstance3D = pair[0]
		var a = mi.mesh.surface_get_arrays(0)
		var bb := []
		for b in mi.skin.get_bind_count(): bb.append(sk.find_bone(mi.skin.get_bind_name(b)))
		var rest_pts := []
		var step := maxi(1, a[Mesh.ARRAY_VERTEX].size() / 300)
		var ks := []
		for k in range(0, a[Mesh.ARRAY_VERTEX].size(), step):
			ks.append(k); rest_pts.append(skinned(sk, mi.skin, bb, a[Mesh.ARRAY_VERTEX][k], a[Mesh.ARRAY_BONES], a[Mesh.ARRAY_WEIGHTS], k))
		data[pair[1]] = {"a": a, "bb": bb, "ks": ks, "rest": rest_pts, "mi": mi}
	var rest_err := 0.0
	for k in data[hid].ks.size():
		rest_err = maxf(rest_err, (data[hid].rest[k] as Vector3).distance_to(data[hid].a[Mesh.ARRAY_VERTEX][data[hid].ks[k]]))
	check(rest_err < 0.0005, tier + ": " + "Skinned rest pose reproduces the modelled helmet (%.5f m)" % rest_err)
	# Pose: head nods 25 deg, spine bends 20 deg.
	sk.set_bone_pose_rotation(head, sk.get_bone_pose_rotation(head) * Quaternion(Vector3.RIGHT, deg_to_rad(25)))
	sk.set_bone_pose_rotation(spine, sk.get_bone_pose_rotation(spine) * Quaternion(Vector3.RIGHT, deg_to_rad(20)))
	var head_delta := sk.get_bone_global_pose(head) * head_rest.affine_inverse()
	var rigid_err := 0.0
	var moved := 0.0
	var h = data[hid]
	for k in h.ks.size():
		var p := skinned(sk, h.mi.skin, h.bb, h.a[Mesh.ARRAY_VERTEX][h.ks[k]], h.a[Mesh.ARRAY_BONES], h.a[Mesh.ARRAY_WEIGHTS], h.ks[k])
		rigid_err = maxf(rigid_err, p.distance_to(head_delta * (h.rest[k] as Vector3)))
		moved = maxf(moved, p.distance_to(h.rest[k]))
	check(rigid_err < 0.0005 and moved > 0.02, tier + ": " + "Helmet follows the head rigidly (err %.5f m, moved %.3f m)" % [rigid_err, moved])
	var v = data[vid]
	var top_move := 0.0
	var low_move := 1.0
	for k in v.ks.size():
		var r: Vector3 = v.rest[k]
		var p := skinned(sk, v.mi.skin, v.bb, v.a[Mesh.ARRAY_VERTEX][v.ks[k]], v.a[Mesh.ARRAY_BONES], v.a[Mesh.ARRAY_WEIGHTS], v.ks[k])
		if r.y > 1.25: top_move = maxf(top_move, p.distance_to(r))
		if r.y < 0.98: low_move = minf(low_move, p.distance_to(r))
	check(top_move > 0.03 and low_move < top_move * 0.5, tier + ": " + "Vest deforms with the spine: chest moves %.3f m, hem %.3f m" % [top_move, low_move])
	facts["deform_" + tier] = {"helmet_rigid_err_m": snappedf(rigid_err, 0.00001), "vest_top_move_m": snappedf(top_move, 0.001), "vest_hem_move_m": snappedf(low_move, 0.001)}
	sk.reset_bone_poses()
	check(GearArt.show_worn(sk, [hid, "gear_backpack_t3", vid], 1) == [hid, vid], "show_worn attaches only pieces with art")
	var lods := []
	for c in sk.get_children():
		if c.has_meta("gear_art_id"): lods.append(int(c.get_meta("lod")))
	check(lods == [1, 1], "show_worn(lod 1) binds the LOD1 meshes")
	GearArt.detach_all(sk)
	await process_frame
	check(sk.get_children().filter(func(c): return c.has_meta("gear_art_id")).is_empty(), "detach_all clears worn art")

# ------------------------------------------------------------------ fit over the default outfit (CPU skinning)
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
	func xf(bones: PackedInt32Array, w: PackedFloat32Array, k: int) -> Transform3D:
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

## Mesh samples: positions, normals, skin, dominant bone name; optional bone-name filter.
func fit_samples(mi: MeshInstance3D, step: int, bone_ok: Callable = Callable(), mat_name: String = "") -> Dictionary:
	var d := {"v": PackedVector3Array(), "n": PackedVector3Array(), "b": PackedInt32Array(), "w": PackedFloat32Array()}
	for s in mi.mesh.get_surface_count():
		if mat_name != "":
			var m := mi.mesh.surface_get_material(s)
			if m == null or str(m.resource_name) != mat_name: continue
		var a = mi.mesh.surface_get_arrays(s)
		var V: PackedVector3Array = a[Mesh.ARRAY_VERTEX]; var N: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var B: PackedInt32Array = a[Mesh.ARRAY_BONES]; var W: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		for k in range(0, V.size(), step):
			if bone_ok.is_valid():
				var top := 0; var tw := -1.0
				for j in 4:
					if W[k * 4 + j] > tw: tw = W[k * 4 + j]; top = B[k * 4 + j]
				if not bone_ok.call(str(mi.skin.get_bind_name(top))): continue
			d.v.append(V[k]); d.n.append(N[k])
			for j in 4: d.b.append(B[k * 4 + j]); d.w.append(W[k * 4 + j])
	return d

func fit_skin(sm: Skinner, d: Dictionary) -> Array:
	sm.update()
	var P := PackedVector3Array(); var Nn := PackedVector3Array()
	for k in d.v.size():
		var t := sm.xf(d.b, d.w, k)
		P.append(t * d.v[k]); Nn.append((t.basis * d.n[k]).normalized())
	return [P, Nn]

func grid_of(P: PackedVector3Array, cell: float) -> Dictionary:
	var g := {}
	for i in P.size():
		var key := Vector3i((P[i] / cell).floor())
		if not g.has(key): g[key] = []
		g[key].append(i)
	return g

func nearest_in(g: Dictionary, P: PackedVector3Array, p: Vector3, cell: float) -> int:
	var c := Vector3i((p / cell).floor()); var best := -1; var bd := cell * cell
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var key := c + Vector3i(dx, dy, dz)
				if not g.has(key): continue
				for i in g[key]:
					var dd := p.distance_squared_to(P[i])
					if dd < bd: bd = dd; best = i
	return best

## The T3 vest over the default-outfit shirt and the arms (idle / walk / sprint / crouch, the
## avatar's own cycles), and the helmet straps over the short helmet hair.
func check_fit_over_outfit(sk: Skeleton3D, body: MeshInstance3D, st: Dictionary):
	var hid: String = st.helm; var vid: String = st.vest; var tier: String = st.tier
	check(DefaultOutfit.dress(sk, ["shirt", "pants"], 0, body) == ["shirt", "pants"], "Default-outfit shirt + pants bind under the gear")
	var vest := GearArt.attach(sk, vid, 0)
	var helm := GearArt.attach(sk, hid, 0)
	await process_frame
	var shirt := sk.get_node("Outfit_shirt") as MeshInstance3D
	var is_arm := func(n: String) -> bool: return n.begins_with("upperarm") or n.begins_with("lowerarm")
	var is_torso := func(n: String) -> bool: return n in TORSO_BONES
	var vs := Skinner.new(sk, vest.skin); var vd := fit_samples(vest, 2)
	var bs := Skinner.new(sk, body.skin); var arm_b := fit_samples(body, 1, is_arm)
	var ss := Skinner.new(sk, shirt.skin); var arm_s := fit_samples(shirt, 1, is_arm)
	var torso_s := fit_samples(shirt, 1, is_torso, "outfit_knit")
	var pants := sk.get_node("Outfit_pants") as MeshInstance3D
	var ps := Skinner.new(sk, pants.skin); var waist_p := fit_samples(pants, 1)
	var av = GearAvatar.new(); av.skeleton = sk; av.worn = [vid, hid]
	var arm_clip := 0; var arm_worst := 1.0; var shirt_clip := 0; var shirt_worst := 1.0
	var per_pose := {}
	# Vest -> shirt torso pairs fixed at rest (outer-facing shirt surface only).
	sk.reset_bone_poses()
	var v_rest := fit_skin(vs, vd); var t_rest := fit_skin(ss, torso_s)
	var tg := grid_of(t_rest[0], 0.03)
	var pairs := []
	for k in v_rest[0].size():
		var j := nearest_in(tg, t_rest[0], v_rest[0][k], 0.03)
		if j >= 0 and (v_rest[0][k] - t_rest[0][j]).dot(t_rest[1][j]) > -0.01: pairs.append([k, j])
	# Vest -> pants (waistband / belt / hips) pairs, same rule, only where the vest hangs low.
	var p_rest := fit_skin(ps, waist_p)
	var wp := PackedVector3Array(); var wn := PackedVector3Array(); var widx := []
	for k in p_rest[0].size():
		if p_rest[0][k].y > 0.86: wp.append(p_rest[0][k]); wn.append(p_rest[1][k]); widx.append(k)
	var wg := grid_of(wp, 0.03)
	var vp_pairs := []
	for k in v_rest[0].size():
		if v_rest[0][k].y > 1.0: continue
		var j := nearest_in(wg, wp, v_rest[0][k], 0.03)
		if j >= 0 and (v_rest[0][k] - wp[j]).dot(wn[j]) > -0.01: vp_pairs.append([k, widx[j]])
	var pants_clip := 0; var pants_worst := 1.0
	for pose in FIT_POSES:
		av.apply_pose(pose[0], pose[1])
		var v := fit_skin(vs, vd)
		var pw := fit_skin(ps, waist_p)
		for pr in vp_pairs:
			var sd: float = (v[0][pr[0]] - pw[0][pr[1]]).dot(pw[1][pr[1]])
			pants_worst = minf(pants_worst, sd)
			if sd < -FIT_TOL:
				pants_clip += 1
				if OS.get_environment("FIT_DEBUG") != "" and pants_clip % 25 == 1: print("FIT_DBG pants ", pose, " vest_rest ", v_rest[0][pr[0]], " pants_rest ", p_rest[0][pr[1]], " sd ", sd)
		var a1 := fit_skin(bs, arm_b); var a2 := fit_skin(ss, arm_s)
		var AP: PackedVector3Array = a1[0] + a2[0]; var AN: PackedVector3Array = a1[1] + a2[1]
		var g := grid_of(AP, 0.03)
		var pc := 0
		for k in v[0].size():
			var j := nearest_in(g, AP, v[0][k], 0.03)
			if j < 0: continue
			var sd: float = (v[0][k] - AP[j]).dot(AN[j])
			arm_worst = minf(arm_worst, sd)
			if sd < -FIT_TOL:
				arm_clip += 1; pc += 1
				if OS.get_environment("FIT_DEBUG") != "": print("FIT_DBG arm ", pose, " vest ", v[0][k], " rest ", vd.v[k], " arm ", AP[j], " ", "sleeve" if j >= a1[0].size() else "skin", " sd ", sd)
		var t := fit_skin(ss, torso_s)
		for pr in pairs:
			var sd: float = (v[0][pr[0]] - t[0][pr[1]]).dot(t[1][pr[1]])
			shirt_worst = minf(shirt_worst, sd)
			if sd < -FIT_TOL:
				shirt_clip += 1
				if OS.get_environment("FIT_DEBUG") != "" and shirt_clip % 10 == 1: print("FIT_DBG shirt ", pose, " vest_rest ", v_rest[0][pr[0]], " shirt_rest ", t_rest[0][pr[1]], " sd ", sd)
		per_pose["%s@%.2f" % [pose[0], pose[1]]] = pc
	sk.reset_bone_poses()
	av.free()
	check(arm_clip == 0, tier + ": " + "Vest clears the arms (body + shirt sleeves) in idle/walk/sprint/crouch (%d samples past %.0f mm, worst %.1f mm)" % [arm_clip, FIT_TOL * 1000, arm_worst * 1000])
	check(pants_clip == 0, tier + ": " + "Vest stays over the cargo pants waist in every pose (%d pairs, worst %.1f mm)" % [vp_pairs.size(), pants_worst * 1000 if vp_pairs.size() > 0 else 0.0])
	check(pairs.size() > 200 and shirt_clip == 0, tier + ": " + "Vest stays over the default-outfit shirt in every pose (%d pairs, worst %.1f mm)" % [pairs.size(), shirt_worst * 1000])
	# Helmet straps vs the short helmet hair: radially, nothing of the hair may lie outside a strap.
	var HC := Vector3(0.0, 1.425, 0.035)
	var hair := sk.get_parent().find_child("hair_short02_v1", true, false) as MeshInstance3D
	var hs := Skinner.new(sk, hair.skin); var hd := fit_samples(hair, 1)
	var H: PackedVector3Array = fit_skin(hs, hd)[0]
	var hs_dirs := []
	for h in H: hs_dirs.append([(h - HC).normalized(), (h - HC).length()])
	var ws := Skinner.new(sk, helm.skin); var wd := fit_samples(helm, 1, Callable(), str(st.strap))
	var W: PackedVector3Array = fit_skin(ws, wd)[0]
	# Strap ends tuck up under the shell rim: hair there is hidden by the shell, so skip strap
	# verts with shell further out along the same ray.
	var SH: PackedVector3Array = fit_skin(ws, fit_samples(helm, 1, Callable(), str(st.shell)))[0]
	var sh_dirs := []
	for h in SH: sh_dirs.append([(h - HC).normalized(), (h - HC).length()])
	var buried := 0; var tested := 0; var under_shell := 0
	var cos_lim := cos(deg_to_rad(2.5))
	for p in W:
		var d := (p - HC).normalized(); var r := (p - HC).length()
		var covered := false
		for e in sh_dirs:
			if (e[0] as Vector3).dot(d) > cos_lim and e[1] > r + 0.002: covered = true; break
		if covered: under_shell += 1; continue
		var outer := 0.0
		for e in hs_dirs:
			if (e[0] as Vector3).dot(d) > cos_lim: outer = maxf(outer, e[1])
		if outer <= 0.0: continue
		tested += 1
		if outer > r - 0.0005:
			buried += 1
			if OS.get_environment("FIT_DEBUG") != "": print("FIT_DBG strap ", p, " r ", r, " hair ", outer)
	check(tested > 50 and buried == 0, tier + ": " + "Helmet straps / harness ride over the helmet hair (%d strap verts over hair, %d buried, %d tucked under the shell)" % [tested, buried, under_shell])
	var rep = JSON.parse_string(FileAccess.get_file_as_string("res://raid/assets/gear/%s/BUILD-REPORT.json" % tier))
	if rep is Dictionary and rep.has(vid):
		check(float(rep[vid].get("shirt_clearance_m", -1)) > 0.0 and int(rep[vid].get("verts_inside_shirt", 1)) == 0, tier + ": " + "BUILD-REPORT: vest clears the shirt at rest (%s m)" % str(rep[vid].get("shirt_clearance_m")))
		check(int(rep[hid].get("strap_points_in_hair", 1)) == 0, tier + ": " + "BUILD-REPORT: no strap point buried in the head/hair shell")
	facts["fit_" + tier] = {"arm_worst_m": snappedf(arm_worst, 0.0001), "arm_clip": arm_clip, "per_pose_arm_clip": per_pose,
		"shirt_worst_m": snappedf(shirt_worst, 0.0001), "shirt_pairs": pairs.size(), "strap_verts_tested": tested, "strap_buried": buried, "strap_under_shell": under_shell, "pants_pairs": vp_pairs.size(), "pants_worst_m": snappedf(pants_worst, 0.0001)}
	GearArt.detach_all(sk)
	DefaultOutfit.undress(sk, body)
	await process_frame

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
		check(stage.worn_gear.is_empty(), "No gear locker -> select screen shows no gear (as before)")
		var before := {}
		for n in stage.garments.values():
			if n is Node3D:
				before[n] = n.visible
				for c in n.get_children(): before[c] = c.visible
		var shown: Array = stage.show_gear([HELM, VEST])
		check(shown == [HELM, VEST], "Select stage shows the worn T3 helmet + vest")
		var on_rig: int = stage.skeleton.get_children().filter(func(c): return c.has_meta("gear_art_id")).size()
		check(on_rig == 2, "Both pieces are bound to the select rig's skeleton")
		var hidden_ok: bool = not stage.garments.helmet.visible if stage.garments.has("helmet") else true
		var jacket_hidden := 0
		if stage.garments.has("jacket"):
			for n in stage.garments.jacket.get_children():
				if str(n.name).begins_with("Fabric jacket body") and not n.visible: jacket_hidden += 1
		check(hidden_ok and (jacket_hidden > 0 or not stage.garments.has("jacket")), "Covered procedural helmet / jacket torso are hidden")
		stage.show_gear([])
		var same := true
		for n in before.keys(): if n.visible != before[n]: same = false
		check(same and before.size() > 5, "Taking the gear off restores the procedural garments exactly (%d parts)" % before.size())
		# Helmet hair: a bob-haired settler shows the short helmet hair under the helmet.
		var look: Dictionary = stage.selected_appearance.duplicate(true)
		if look.is_empty(): look = {"name": "Settler", "cheek": 0.0, "hair": "hair_short02_v1", "brows": "brow_009_v1", "eyes": "eye_brown_v1", "hair_tint": "natural"}
		look.hair = "hair_bob01_v1"
		var shown_ok: bool = stage.show_appearance(look)
		var bob: MeshInstance3D = stage.rig_meshes.hair_bob01_v1; var short: MeshInstance3D = stage.rig_meshes.hair_short02_v1
		check(shown_ok and bob.visible and not short.visible, "Bob appearance shows the bob")
		stage.show_gear([HELM])
		check(short.visible and not bob.visible, "Under the T3 helmet the bob swaps to the short helmet hair")
		stage.show_appearance(look)
		check(short.visible and not bob.visible, "Re-applying the appearance keeps the helmet hair while the helmet is worn")
		stage.show_gear([])
		check(bob.visible and not short.visible, "Helmet off -> the chosen bob comes back")
	title.queue_free()
	current_scene = null
	await process_frame
	await process_frame

func check_avatar():
	var p := FakePlayer.new(); root.add_child(p)
	var capsule := p.avatar.mesh
	# Default outfit available -> the dressed character replaces the capsule even with no art.
	var bare = GearAvatar.install(p, ["gear_helmet_t2"])
	await process_frame
	check(bare != null and bare.attached_ids().is_empty() and bare.outfit_pieces() == ["shirt", "pants", "boots"] and p.avatar.mesh == capsule and p.avatar.layers == 0, "No worn art -> avatar in the default outfit, no gear (capsule mesh kept, hidden)")
	var a = GearAvatar.install(p, [HELM, VEST, "gear_backpack_t3"])
	await process_frame
	check(a != null and p.avatar.mesh == capsule and p.avatar.layers == 0 and a.get_parent() == p.avatar, "Worn art -> capsule hidden (mesh kept for player.gd resizes), gear avatar under player.avatar")
	if a != null:
		check(a.attached_ids() == [HELM, VEST], "Avatar wears exactly the pieces with art")
		a._process(0.016)
		check(a.state == "idle", "Avatar idles when the player stands still")
		p.velocity = Vector3(0, 0, -4.2); a._process(0.016)
		check(a.state == "walk", "Walking speed -> walk cycle")
		p.velocity = Vector3(0, 0, -7.0); a._process(0.016)
		check(a.state == "sprint", "Sprint speed -> sprint cycle")
		p.velocity = Vector3.ZERO; p.crouched = true; a._process(0.016)
		var crouch_y: float = a.skeleton.get_bone_global_pose(a.skeleton.find_bone("head")).origin.y + a.rig.position.y
		p.crouched = false; a._process(0.016)
		var stand_y: float = a.skeleton.get_bone_global_pose(a.skeleton.find_bone("head")).origin.y + a.rig.position.y
		check(a.state == "idle" and stand_y - crouch_y > 0.2, "Crouch lowers the head (%.2f m)" % (stand_y - crouch_y))
		p.avatar.position.y = 0.55; a._process(0.016)
		check(is_equal_approx(a.position.y, -0.55), "Avatar stays on the floor when player.gd moves the holder (crouch capsule)")
	var off = GearAvatar.install(p, [])
	check(off != null and off == a and off.attached_ids().is_empty() and off.outfit_pieces().size() == 3 and p.avatar.layers == 0, "Unequipping leaves the avatar in its default outfit")
	p.queue_free()
	await process_frame

func check_mannequin_and_icons():
	var m := Mannequin.new(); root.add_child(m)
	await process_frame
	check(m.model_ok, "Psy equip-tab mannequin loads the rig")
	check(m.show_loadout([VEST, HELM]) == [VEST, HELM], "Mannequin shows the worn pieces with art")
	var lods := []
	for c in m.skeleton.get_children():
		if c.has_meta("gear_art_id"): lods.append(int(c.get_meta("lod")))
	check(lods == [1, 1], "Mannequin uses the LOD1 meshes")
	m.queue_free()
	var Panel = load("res://raid/scripts/gear_tiers/psy_gear_tier_panel.gd")
	var panel = Panel.new()
	check(panel._item_texture({"id": "x1", "def": HELM, "tier": 3}) == GearArt.icon(HELM), "Psy rows use the rendered T3 helmet icon")
	var chip = panel._item_texture({"id": "x2", "def": "gear_helmet_t2", "tier": 2})
	check(chip != null and chip != GearArt.icon(HELM), "Pieces without art keep the tier chip")
	panel.free()
	var World = load("res://raid/scripts/raid_world.gd")
	var w = World.new()
	var row := HBoxContainer.new()
	w._gear_badge(row, "gear_body_armor_t3@60")
	check(row.get_node_or_null("GearIcon") is TextureRect and row.get_node_or_null("TierBadge") == null, "Raid loot row shows the vest icon")
	var row2 := HBoxContainer.new()
	w._gear_badge(row2, "gear_helmet_t4@80")
	check(row2.get_node_or_null("TierBadge") != null and row2.get_node_or_null("GearIcon") == null, "Raid loot row keeps the tier badge without art")
	row.free(); row2.free(); w.free()
	await process_frame

func check_locker_peek():
	var path := "user://gear_art_test/none.json"
	check(GearArt.worn_from_locker(path) == [] and not FileAccess.file_exists(path), "Locker peek is read-only (no file created)")
	var st = State.new()
	st.equip(st.grant(HELM)); st.equip(st.grant("gear_backpack_t2"))
	var f := FileAccess.open("user://gear_art_test/locker.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(st.data())); f.close()
	var worn := GearArt.worn_from_locker("user://gear_art_test/locker.json")
	check(HELM in worn and "gear_backpack_t2" in worn, "Locker peek returns the equipped defs: " + str(worn))
