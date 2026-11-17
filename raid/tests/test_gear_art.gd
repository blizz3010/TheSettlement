extends SceneTree
## Gear art E0 (TASKS item 22): the T3 Warden Helm + T3 Bulwark Carrier art pilot.
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
const HELM := "gear_helmet_t3"
const VEST := "gear_body_armor_t3"
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
	for id in [HELM, VEST]: check_scene(id, sk)
	await check_deformation(sk)
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
	check(GearArt.ids().size() == 2 and HELM in GearArt.ids() and VEST in GearArt.ids(), "E0 art covers exactly the T3 helmet and T3 vest")
	check(GearArt.has_art(HELM) and GearArt.has_art(VEST), "Both E0 pieces resolve to an art scene")
	check(not GearArt.has_art("gear_helmet_t2") and not GearArt.has_art("gear_backpack_t3") and not GearArt.has_art("nope"), "Other ids have no art yet")
	for id in [HELM, VEST]: check(Defs.item(id).size() > 0, id + " is a real gear def")
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
	var ph := GearArt.build("gear_helmet_t2", 0)
	check(ph != null and not ph.has_meta("gear_art"), "Ids without art fall back to the PR A placeholder")
	if ph != null: ph.free()
	check(GearArt.icon(HELM) is Texture2D and GearArt.icon(VEST) is Texture2D, "Both E0 pieces have a rendered icon")
	check(GearArt.icon("gear_helmet_t2") == null, "No icon for ids without art (callers keep the tier chip)")
	check(GearArt.covered([HELM, VEST, "gear_backpack_t3"]) == ["helmet", "jacket_torso"], "Covers: helmet + jacket torso")

# ------------------------------------------------------------------ imported scene
func check_scene(id: String, sk: Skeleton3D):
	var spec: Dictionary = GearArt.ART[id]
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
	if id == HELM: check(used_names == ["head"], "Helmet is rigid on the head bone: " + str(used_names))
	else: check(used_names.size() >= 4 and used_names.all(func(n): return n in TORSO_BONES), "Vest weights only on torso bones: " + str(used_names))
	check(max_w == 4, id + " uses 4 weights per vertex")
	# Materials: 6 PBR surfaces with external, VRAM-compressed textures.
	var mats := 0
	var ext_ok := true
	var vram_ok := true
	var tex_paths := {}
	for s in lod0.mesh.get_surface_count():
		var m := lod0.mesh.surface_get_material(s) as StandardMaterial3D
		if m == null: continue
		mats += 1
		var set := [m.albedo_texture, m.normal_texture, m.roughness_texture, m.ao_texture]
		if not m.normal_enabled or not m.ao_enabled or set.has(null): ext_ok = false; continue
		for i in set.size():
			var p := str(set[i].resource_path)
			if not (p.begins_with("res://raid/assets/gear/t3/textures/") and p.ends_with(".jpg")): ext_ok = false
			tex_paths[p] = true
			var cfg := import_cfg(p)
			if int(cfg.get_value("params", "compress/mode", -1)) != 2: vram_ok = false
			if i == 1 and int(cfg.get_value("params", "compress/normal_map", -1)) != 1: vram_ok = false
	check(mats == 6, "%s has 6 PBR material surfaces (%d)" % [id, mats])
	check(ext_ok, id + " albedo/normal/ORM/AO are external JPGs under raid/assets/gear/t3/textures")
	check(vram_ok, id + " textures import VRAM-compressed (normals as normal maps)")
	var gl := FileAccess.get_file_as_string(GearArt.scene_path(id))
	check(not gl.contains("data:") and gl.contains("textures/t3_") and gl.contains(".jpg"), id + " glTF references external JPGs (nothing embedded)")
	var bytes := 0
	for p in tex_paths.keys(): bytes += FileAccess.get_file_as_bytes(p).size()
	var bin := FileAccess.get_file_as_bytes(GearArt.scene_path(id).get_basename() + ".bin").size()
	facts[id] = {"lod0_tris": t0, "lod1_tris": t1, "lod1_ratio": snappedf(ratio, 0.001), "bin_bytes": bin,
		"gltf_bytes": gl.length(), "texture_bytes": bytes, "bones": used_names, "rest_fit_m": snappedf(rest_fit, 0.00001)}
	inst.free()

# ------------------------------------------------------------------ deformation (CPU skinning)
func check_deformation(sk: Skeleton3D):
	var rep = JSON.parse_string(FileAccess.get_file_as_string("res://raid/assets/gear/t3/BUILD-REPORT.json"))
	check(rep is Dictionary and rep.has(HELM) and rep.has(VEST), "BUILD-REPORT lists both pieces")
	if rep is Dictionary and rep.has(VEST):
		check(float(rep[VEST].clearance_m) > 0.0 and int(rep[VEST].verts_inside_skin) == 0, "Vest clears the body at rest (%s m)" % rep[VEST].clearance_m)
		check(float(rep[HELM].clearance_m) > -0.01 and int(rep[HELM].verts_inside_skin) <= 2, "Helmet within 1 cm of the head+hair shell (%s m, %s verts)" % [rep[HELM].clearance_m, rep[HELM].verts_inside_skin])
		facts["clearance_m"] = {HELM: rep[HELM].clearance_m, VEST: rep[VEST].clearance_m}
	var helm := GearArt.attach(sk, HELM, 0)
	var vest := GearArt.attach(sk, VEST, 0)
	check(helm != null and vest != null and helm.get_parent() == sk and helm.skeleton == NodePath(".."), "attach() binds both meshes under the character skeleton")
	if helm == null or vest == null: return
	check(GearArt.attach(sk, "gear_helmet_t2", 0) == null, "attach() refuses ids without art (no placeholder on characters)")
	await process_frame
	sk.reset_bone_poses()
	var head := sk.find_bone("head")
	var spine := sk.find_bone("spine_02")
	var head_rest := sk.get_bone_global_pose(head)
	var data := {}
	for pair in [[helm, HELM], [vest, VEST]]:
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
	for k in data[HELM].ks.size():
		rest_err = maxf(rest_err, (data[HELM].rest[k] as Vector3).distance_to(data[HELM].a[Mesh.ARRAY_VERTEX][data[HELM].ks[k]]))
	check(rest_err < 0.0005, "Skinned rest pose reproduces the modelled helmet (%.5f m)" % rest_err)
	# Pose: head nods 25 deg, spine bends 20 deg.
	sk.set_bone_pose_rotation(head, sk.get_bone_pose_rotation(head) * Quaternion(Vector3.RIGHT, deg_to_rad(25)))
	sk.set_bone_pose_rotation(spine, sk.get_bone_pose_rotation(spine) * Quaternion(Vector3.RIGHT, deg_to_rad(20)))
	var head_delta := sk.get_bone_global_pose(head) * head_rest.affine_inverse()
	var rigid_err := 0.0
	var moved := 0.0
	var h = data[HELM]
	for k in h.ks.size():
		var p := skinned(sk, h.mi.skin, h.bb, h.a[Mesh.ARRAY_VERTEX][h.ks[k]], h.a[Mesh.ARRAY_BONES], h.a[Mesh.ARRAY_WEIGHTS], h.ks[k])
		rigid_err = maxf(rigid_err, p.distance_to(head_delta * (h.rest[k] as Vector3)))
		moved = maxf(moved, p.distance_to(h.rest[k]))
	check(rigid_err < 0.0005 and moved > 0.02, "Helmet follows the head rigidly (err %.5f m, moved %.3f m)" % [rigid_err, moved])
	var v = data[VEST]
	var top_move := 0.0
	var low_move := 1.0
	for k in v.ks.size():
		var r: Vector3 = v.rest[k]
		var p := skinned(sk, v.mi.skin, v.bb, v.a[Mesh.ARRAY_VERTEX][v.ks[k]], v.a[Mesh.ARRAY_BONES], v.a[Mesh.ARRAY_WEIGHTS], v.ks[k])
		if r.y > 1.25: top_move = maxf(top_move, p.distance_to(r))
		if r.y < 0.98: low_move = minf(low_move, p.distance_to(r))
	check(top_move > 0.03 and low_move < top_move * 0.5, "Vest deforms with the spine: chest moves %.3f m, hem %.3f m" % [top_move, low_move])
	facts["deform"] = {"helmet_rigid_err_m": snappedf(rigid_err, 0.00001), "vest_top_move_m": snappedf(top_move, 0.001), "vest_hem_move_m": snappedf(low_move, 0.001)}
	sk.reset_bone_poses()
	check(GearArt.show_worn(sk, [HELM, "gear_backpack_t3", VEST], 1) == [HELM, VEST], "show_worn attaches only pieces with art")
	var lods := []
	for c in sk.get_children():
		if c.has_meta("gear_art_id"): lods.append(int(c.get_meta("lod")))
	check(lods == [1, 1], "show_worn(lod 1) binds the LOD1 meshes")
	GearArt.detach_all(sk)
	await process_frame
	check(sk.get_children().filter(func(c): return c.has_meta("gear_art_id")).is_empty(), "detach_all clears worn art")

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
	title.queue_free()
	current_scene = null
	await process_frame
	await process_frame

func check_avatar():
	var p := FakePlayer.new(); root.add_child(p)
	var capsule := p.avatar.mesh
	check(GearAvatar.install(p, ["gear_helmet_t2"]) == null and p.avatar.mesh == capsule, "No worn art -> third-person capsule unchanged")
	var a = GearAvatar.install(p, [HELM, VEST, "gear_backpack_t3"])
	await process_frame
	check(a != null and p.avatar.mesh == capsule and p.avatar.transparency == 1.0 and a.get_parent() == p.avatar, "Worn art -> capsule hidden (mesh kept for player.gd resizes), gear avatar under player.avatar")
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
	check(GearAvatar.install(p, []) == null and p.avatar.mesh == capsule and p.avatar.transparency == 0.0 and p.avatar.get_node_or_null("GearAvatar") == null, "Unequipping restores the capsule")
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
