extends Node
## Manual rendered capture for gear art E0 (TASKS item 22; not in the suite): third person in
## the ship settlement (V view of pinned player.gd) with the gear avatar wearing the T3 Warden
## Helm + T3 Bulwark Carrier, in idle / walk / sprint / crouch, from the game's own
## third-person camera and from a side camera (deformation), plus the capsule "before" and
## frame times. Writes user:// files, so use a disposable XDG profile:
## XDG_DATA_HOME=/tmp/x xvfb-run -a godot --rendering-driver opengl3 --path . res://raid/tests/gear_art_settlement_capture.tscn
## Env GEAR_OUT=<abs dir> (default raid/screenshots/gear_art_e0). llvmpipe timings: relative only.
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const Store = preload("res://raid/scripts/gear_tiers/gear_locker_store.gd")
const GearAvatar = preload("res://raid/scripts/gear_tiers/gear_avatar.gd")
var out := ""
var world
var timing := {}

func _ready():
	get_tree().create_timer(2400).timeout.connect(func(): print("GEAR_SETTLE watchdog"); get_tree().quit(3))
	call_deferred("run")

func log_(s: String): print("GEAR_SETTLE ", s, "  t=", Time.get_ticks_msec() / 1000)

func shot(name: String):
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("GEAR_SHOT ", name)

func frame_ms(frames: int) -> float:
	var t := Time.get_ticks_usec()
	for i in frames: await get_tree().process_frame
	return snappedf((Time.get_ticks_usec() - t) / 1000.0 / frames, 0.01)

func seed_locker(on: bool):
	for f in [Store.DEFAULT_PATH, Store.DEFAULT_PATH + ".tmp"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	if not on: return
	var store = Store.new(); store.path = Store.DEFAULT_PATH
	for slot in ["helmet", "body_armor", "tactical_rig", "backpack", "gloves", "boots"]:
		store.state.equip(store.state.grant(Defs.item_id(slot, 3)))
	store.save()

func seed_settler():
	var Session = load("res://scripts/character_profiles/title_session.gd")
	var Rules = load("res://scripts/character_profiles/experimental_rules.gd")
	var session = Session.new(); session.rules = Rules.data()
	var state = session.inspect()
	if state.screen == "create":
		var r = session.create_character("slot_1", {"name":"Settler","cheek":0.0,"hair":"hair_short02_v1","brows":"brow_009_v1","eyes":"eye_brown_v1","hair_tint":"natural"}, {"str":7,"int":7,"dex":7}, [], state.bytes, false)
		session.cancel()
		log_("seeded settler " + str(r.get("ok", false)))

func hide_ui():
	for child in world.get_children():
		if child is CanvasLayer: child.visible = false

func run():
	out = OS.get_environment("GEAR_OUT").strip_edges()
	if out.is_empty(): out = ProjectSettings.globalize_path("res://raid/screenshots/gear_art_e0")
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	seed_locker(true)
	seed_settler()
	# Real play flow: title -> Play -> settler -> Enter -> threaded world load + staged startup.
	var title = (load("res://raid/play_title.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(title); get_tree().current_scene = title
	for i in 10: await get_tree().process_frame
	title.play_button.pressed.emit()
	for i in 10: await get_tree().process_frame
	var panel = title.character_panel
	panel.cards["slot_1"].pressed.emit()
	for i in 10: await get_tree().process_frame
	panel.enter_button.pressed.emit()
	var deadline := Time.get_ticks_msec() + 1500000
	while true:
		var sc = get_tree().current_scene
		if sc != null and sc.get("world_activated") == true and sc.get("world_initialized") == true: break
		if Time.get_ticks_msec() > deadline: log_("BREAK world did not activate"); get_tree().quit(1); return
		await get_tree().process_frame
	world = get_tree().current_scene
	log_("world " + str(world.get_script().resource_path))
	for i in 8: await get_tree().process_frame
	var p = world.player
	p.enabled = false
	var holder: MeshInstance3D = p.avatar
	var av = holder.get_node_or_null("GearAvatar")
	log_("avatar installed by the settlement: " + str(av != null) + " worn " + str(av.attached_ids() if av else []))
	hide_ui()
	if not p.third_person: p.toggle_view()
	# Face along the open plaza; the game's third-person camera sits 3.5 m behind, 1 m up.
	p.update_camera_view()
	for i in 3: await get_tree().process_frame
	# Before: the old capsule stand-in (the avatar now always shows in the default outfit, so it
	# is hidden and the capsule put back on its layers for this one shot).
	if av != null: av.visible = false
	var look: Array = holder.get_meta("gear_capsule_look") if holder.has_meta("gear_capsule_look") else [1, GeometryInstance3D.SHADOW_CASTING_SETTING_ON]
	holder.layers = look[0]; holder.cast_shadow = look[1]
	for i in 4: await get_tree().process_frame
	timing["third_person_capsule_ms"] = await frame_ms(6)
	await shot("08_before_third_person_capsule")
	holder.layers = 0; holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	av = GearAvatar.install(p, ["gear_helmet_t3", "gear_body_armor_t3"])
	av.visible = true
	for i in 4: await get_tree().process_frame
	timing["third_person_gear_avatar_ms"] = await frame_ms(6)
	var side := Camera3D.new(); side.fov = 40; side.near = 0.05; world.add_child(side)
	var game_cam: Camera3D = p.camera
	var poses := [["idle", "09"], ["walk", "10"], ["sprint", "11"], ["crouch", "12"]]
	for pr in poses:
		av.pose_override = pr[0]; av.override_phase = PI * 0.5
		if pr[0] == "crouch":
			p.update_crouch(true)
			log_("crouched " + str(p.crouched))
			if not p.crouched:
				p.crouched = true; holder.position.y = p.CROUCH_HEIGHT * 0.5
		game_cam.current = true
		p.update_camera_view()
		await shot("%s_third_person_%s" % [pr[1], pr[0]])
		# Side view (3/4 front-left) to show how the vest and helmet follow the pose.
		var c: Vector3 = p.global_position + Vector3(0, 0.62 if pr[0] == "crouch" else 1.0, 0)
		var fwd: Vector3 = -p.global_transform.basis.z
		var right: Vector3 = p.global_transform.basis.x
		side.global_position = c + (fwd * 2.2 - right * 1.6) + Vector3(0, 0.3, 0)
		side.look_at(c)
		side.current = true
		await shot("13_side_%s_%s" % [pr[1], pr[0]])
	game_cam.current = true
	print("GEAR_ART_SETTLEMENT_MS ", JSON.stringify(timing))
	seed_locker(false)
	get_tree().quit()
