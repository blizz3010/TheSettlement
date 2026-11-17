extends SceneTree
## Gear art E0 bench (manual, not in the suite): the third-person gear avatar in idle / walk /
## sprint / crouch poses side by side, plus frame-time timing. Needs a display (Xvfb ok).
## Env GEAR_OUT=<abs dir>, GEAR_BENCH=pose|time, GEAR_WORN=comma ids (default both E0 pieces).
const GearAvatar = preload("res://raid/scripts/gear_tiers/gear_avatar.gd")
var out := ""

class FakePlayer:
	extends Node3D
	var avatar: MeshInstance3D
	var velocity := Vector3.ZERO
	var crouched := false
	func _init():
		avatar = MeshInstance3D.new(); var c := CapsuleMesh.new(); c.radius = 0.3; c.height = 1.7; avatar.mesh = c
		avatar.position.y = 0.9; add_child(avatar)

func _initialize():
	call_deferred("run")

func stage() -> Node3D:
	var w := Node3D.new(); root.add_child(w)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("2b3532")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("b9c4c0"); env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env; w.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, -30, 0); sun.light_energy = 1.4; sun.shadow_enabled = true; w.add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-15, 140, 0); fill.light_energy = 0.4; w.add_child(fill)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(20, 20); floor.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color("4a524c"); fm.roughness = 0.95; floor.material_override = fm; w.add_child(floor)
	return w

func run():
	out = OS.get_environment("GEAR_OUT").strip_edges()
	if out.is_empty(): out = "/tmp/gear_bench"
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1440, 900); DisplayServer.window_set_size(Vector2i(1440, 900))
	var worn_env := OS.get_environment("GEAR_WORN").strip_edges()
	var worn: Array = Array(worn_env.split(",")) if not worn_env.is_empty() else ["gear_helmet_t3", "gear_body_armor_t3"]
	var w := stage()
	var poses := ["idle", "walk", "sprint", "crouch"]
	var p := FakePlayer.new(); w.add_child(p)
	var a = GearAvatar.install(p, worn)
	var cam := Camera3D.new(); w.add_child(cam); cam.fov = 30; cam.current = true
	var view := OS.get_environment("GEAR_VIEW").strip_edges()
	var yaws: Array = Array(view.split(",")) if not view.is_empty() else ["35", "150"]
	var dist := float(OS.get_environment("GEAR_DIST")) if not OS.get_environment("GEAR_DIST").is_empty() else 4.4
	for pose in poses:
		if a != null:
			a.pose_override = pose; a.override_phase = PI * 0.5
		for y in yaws:
			var yaw := deg_to_rad(float(y))
			var look := Vector3(0, 0.62 if pose == "crouch" else 0.95, 0)
			cam.position = look + Vector3(sin(yaw) * dist, 0.35, -cos(yaw) * dist)
			cam.look_at(look)
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("pose_%s_%s.png" % [pose, y]))
	print("GEAR_BENCH shots ", out)
	quit(0)
