extends Node
## Item 12 rollout studio shots (manual): every raid prop variant, original GLB and remodel,
## shot from the same three-quarter front camera under one sun. Covers the palette variants
## that no current map places (olive stacks, sand containers).
## Env: ROLLOUT_OUT=<abs dir>
const Bench = preload("res://raid/tests/midstyle_rollout_bench_iso.gd")
const SIZE := {"relay": [Vector3(1.9, 1.5, 2.6), Vector3(0, 0.95, 0)], "loot": [Vector3(1.9, 1.5, 2.4), Vector3(0, 0.5, 0)],
	"cargo_container": [Vector3(5.6, 3.0, 7.0), Vector3(0, 1.1, 0)], "cargo_stack_large": [Vector3(3.4, 2.6, 4.4), Vector3(0, 1.05, 0)],
	"cargo_stack_pallet": [Vector3(2.6, 2.0, 3.4), Vector3(0, 0.7, 0)]}

func _ready() -> void:
	get_tree().create_timer(900).timeout.connect(func(): get_tree().quit(3))
	call_deferred("run")

func run() -> void:
	var out := OS.get_environment("ROLLOUT_OUT")
	get_tree().root.size = Vector2i(900, 700); DisplayServer.window_set_size(Vector2i(900, 700))
	var root := Node3D.new(); add_child(root)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.36, 0.40, 0.42)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.62, 0.62, 0.66)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.shadow_enabled = true; sun.rotation_degrees = Vector3(-48, 28, 0); sun.light_energy = 1.1; root.add_child(sun)
	var floor_mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); floor_mi.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.55, 0.53, 0.48); floor_mi.material_override = fm; root.add_child(floor_mi)
	var cam := Camera3D.new(); cam.fov = 40.0; root.add_child(cam); cam.current = true
	for key in Bench.ORIGINAL:
		var frame: Array = SIZE["relay"]
		for prefix in SIZE:
			if (key as String).begins_with(prefix): frame = SIZE[prefix]
		for on in [false, true]:
			var path: String = "res://assets/midstyle_rollout/%s.gltf" % key if on else Bench.ORIGINAL[key]
			var n: Node3D = (load(path) as PackedScene).instantiate(); root.add_child(n)
			var lever := n.find_child("Relay_Lever", true, false) as Node3D
			if lever: lever.rotation_degrees.x = -40.0  # in-game rest pose
			cam.position = frame[0]; cam.look_at(frame[1])
			for i in 5: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("studio_%s_%s.png" % [key, "after" if on else "before"]))
			n.free()
	get_tree().quit(0)
