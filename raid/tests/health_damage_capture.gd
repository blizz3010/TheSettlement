extends SceneTree
## Manual rendered capture for the health/damage PR (not part of the suite).
## DISPLAY=:N godot --rendering-driver opengl3 --path . --script res://raid/tests/health_damage_capture.gd
## Env HD_OUT=<abs dir> (default raid/screenshots/health_damage).
var out := ""
var scene
var cam: Camera3D

func _initialize():
	call_deferred("run")

func shot(name: String):
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("HD_SHOT ", name)

func eye_at(feet: Vector3, look: Vector3):
	cam.global_position = feet + Vector3(0, 1.62, 0)
	cam.look_at(look)

func ground(p: Vector2) -> Vector3:
	return Vector3(p.x, scene.generator.height_at(p) + 0.08, p.y)

func run():
	out = OS.get_environment("HD_OUT").strip_edges()
	if out.is_empty(): out = ProjectSettings.globalize_path("res://raid/screenshots/health_damage")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	scene = load("res://raid/relay_ridge.tscn").instantiate()
	root.add_child(scene)
	while not scene.is_raid_ready(): await process_frame
	scene.return_requested.connect(func(): pass)  # keep the process alive on return
	var ctl = scene.health_controller
	var h = ctl.health
	cam = Camera3D.new(); cam.fov = 72; cam.far = 500; scene.add_child(cam); cam.current = true
	for i in 20: await process_frame
	# 1. HUD at full health near spawn, facing the hazard.
	var hz: Vector3 = ctl.hazard.global_position
	var spawn: Vector3 = scene.player.global_position
	var view_from := hz + (Vector3(spawn.x, hz.y, spawn.z) - hz).normalized() * 6.5
	view_from = ground(Vector2(view_from.x, view_from.z))
	eye_at(view_from, hz + Vector3(0, 0.4, 0))
	scene.player.position = view_from
	for i in 20: await process_frame
	await shot("01_hud_full_hazard")
	# 2. Step into the live cable: hit flash, damage number, bar drops.
	scene.player.position = hz + Vector3(0, 0.1, 0)
	var start: float = h.current()
	while h.current() == start: await physics_frame
	scene.player.position = view_from
	await shot("02_hazard_hit_hud_damaged")
	for i in 60: await physics_frame
	h.invulnerable_left = 0.0
	h.damage(45.0, "test")  # show low-health tint
	for i in 40: await process_frame
	await shot("03_hud_low_health")
	h.reset()
	# 3. Sentry turret firing.
	var tr: Vector3 = ctl.turret.global_position
	var found := false
	for k in 16:
		var a := TAU * k / 16.0
		var p := ground(Vector2(tr.x, tr.z) + Vector2(cos(a), sin(a)) * 9.0)
		scene.player.position = p
		for i in 3: await physics_frame
		if ctl.turret.has_line_of_sight(): found = true; break
	var feet: Vector3 = scene.player.position
	var side := (tr - feet).cross(Vector3.UP).normalized() * 2.2
	eye_at(feet + side - (tr - feet).normalized() * 1.5, tr + Vector3(0, 1.0, 0))
	if found:
		var shots: int = ctl.turret.shots
		while ctl.turret.shots == shots: await physics_frame
		await shot("04_turret_firing")
		for i in 100: await physics_frame
		var s2: int = ctl.turret.shots
		while ctl.turret.shots == s2: await physics_frame
		await shot("05_turret_second_hit")
	# 4. Downed -> raid failed screen.
	h.invulnerable_left = 0.0
	h.damage(1000.0, "sentry turret")
	for i in 20: await process_frame
	await shot("06_downed_raid_failed")
	print("HD_DONE ", JSON.stringify({"found_los": found, "placement": str(ctl.placement)}))
	quit(0)
