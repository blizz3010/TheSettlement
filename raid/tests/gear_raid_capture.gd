extends SceneTree
## Manual rendered capture for the gear raid hookup (TASKS item 22, PR B; not in the suite).
## Seeds a full tier-4 kit into user://gear_locker.json, so run with a disposable XDG profile:
## XDG_DATA_HOME=/tmp/x DISPLAY=:N godot --rendering-driver opengl3 --path . --script res://raid/tests/gear_raid_capture.gd
## Env GEAR_OUT=<abs dir> (default raid/screenshots/gear_raid).
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const Store = preload("res://raid/scripts/gear_tiers/gear_locker_store.gd")
var out := ""
var scene
var cam: Camera3D

func _initialize():
	call_deferred("run")

func shot(name: String):
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("GEAR_SHOT ", name)

func ground(p: Vector2) -> Vector3:
	return Vector3(p.x, scene.generator.height_at(p) + 0.08, p.y)

func run():
	out = OS.get_environment("GEAR_OUT").strip_edges()
	if out.is_empty(): out = ProjectSettings.globalize_path("res://raid/screenshots/gear_raid")
	DirAccess.make_dir_recursive_absolute(out)
	var store = Store.new(); store.path = Store.DEFAULT_PATH
	for slot in Defs.SLOTS: store.state.equip(store.state.grant(Defs.item_id(slot, 4)))
	store.save()
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	scene = load("res://raid/relay_ridge.tscn").instantiate()
	root.add_child(scene)
	while not scene.is_raid_ready(): await process_frame
	scene.return_requested.connect(func(): pass)
	var ctl = scene.health_controller
	var h = ctl.health
	cam = Camera3D.new(); cam.fov = 72; cam.far = 500; scene.add_child(cam); cam.current = true
	for i in 20: await process_frame
	var hz: Vector3 = ctl.hazard.global_position
	var spawn: Vector3 = scene.player.global_position
	var from := hz + (Vector3(spawn.x, hz.y, spawn.z) - hz).normalized() * 6.5
	from = ground(Vector2(from.x, from.z))
	cam.global_position = from + Vector3(0, 1.62, 0); cam.look_at(hz + Vector3(0, 0.4, 0))
	scene.player.position = from
	for i in 20: await process_frame
	await shot("01_gear_hud_full_t4")
	# Take a few reduced hits and show the threat hint near the turret.
	for i in 3:
		h.invulnerable_left = 0.0
		h.damage(12.0, "sentry turret")
	h.invulnerable_left = 0.0
	h.damage(12.0, "live cable")
	var t = ctl.turret
	t.set_physics_process(false)
	var tp: Vector3 = t.global_position
	var view := ground(Vector2(tp.x + 9.0, tp.z + 3.0))
	scene.player.position = view
	var to := tp - view
	scene.player.rotation.y = atan2(-to.x, -to.z)  # face the turret like the camera
	cam.global_position = view + Vector3(0, 1.62, 0); cam.look_at(tp + Vector3(0, 1.2, 0))
	scene.gear.turret_was_tracking = false
	t.tracking = true
	for i in 6: await process_frame
	scene.gear._physics_process(1.0 / 60.0)
	for i in 10: await process_frame
	await shot("02_gear_hud_worn_threat_hint")
	print("GEAR_HUD_TEXT ", scene.gear.hud_label.text.replace("\n", " | "))
	scene.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.DEFAULT_PATH))
	quit(0)
