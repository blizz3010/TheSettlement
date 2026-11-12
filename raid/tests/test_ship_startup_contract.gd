extends SceneTree
## Cold real title + threaded real settlement. No startup or scene doubles.
var failures: Array = []
var checks := 0
func check(ok: bool, label: String):
 checks += 1
 if not ok: failures.append(label); push_error(label)
func _initialize(): call_deferred("run")
func run():
 var title_packed = load("res://raid/ship_title_preview.tscn")
 check(title_packed is PackedScene, "Real ship title loads")
 var title = title_packed.instantiate()
 root.add_child(title); current_scene = title
 await process_frame
 title.play_button.pressed.emit()
 check(is_instance_valid(title.character_panel), "Real Play opens character selection")
 var path = title.world_path
 check(path == "res://raid/ship_settlement_preview.tscn", "Title uses actual ship world")
 check(ResourceLoader.load_threaded_request(path, "PackedScene") == OK, "Cold threaded request accepted")
 var deadline = Time.get_ticks_msec() + 300000
 while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS and Time.get_ticks_msec() < deadline: await process_frame
 check(ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED, "Real world finishes threaded load")
 var packed = ResourceLoader.load_threaded_get(path)
 check(packed is PackedScene, "Threaded result is a real scene")
 var world = packed.instantiate()
 var script = world.get_script()
 check(script != null and script.resource_path == "res://raid/scripts/ship_settlement_preview.gd" and script.can_instantiate(), "Ship world has valid instantiable production script")
 check(title._world_supports_startup(world), "Exact production startup predicate accepts real world")
 for signal_name in ["gameplay_ready", "loading_stage"]: check(world.has_signal(signal_name), "Inherited signal: " + signal_name)
 for method_name in ["prepare_startup_assets", "activate_loaded_world", "request_startup_cancel"]: check(world.has_method(method_name), "Inherited method: " + method_name)
 for name in ["staged_startup", "world_initialized", "startup_cancel_requested"]: check(world.get(name) is bool and world.get(name) == false, "Initial readiness flag: " + name)
 check(not world.is_inside_tree() and not world.character_slot_bound, "Probe does not start or bind settlement")
 world.free()
 title.music.stop(); title.music.stream = null
 title.video.stop(); title.video.stream = null
 await create_timer(0.2).timeout
 title.queue_free(); current_scene = null
 await create_timer(0.2).timeout
 print("SHIP_STARTUP_CONTRACT_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "native": false, "full_world_activation": false, "scope": "Cold real title, selection, threaded production world, inherited startup contract; no scenery readiness bypass or gameplay acceptance"}))
 quit(0 if failures.is_empty() else 1)
