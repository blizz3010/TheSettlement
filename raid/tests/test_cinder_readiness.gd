extends SceneTree
## Additive generation failure paths; no settlement save I/O or rendering.
const Config=preload("res://raid/scripts/cinder_config.gd")
const Generator=preload("res://raid/scripts/cinder_generator.gd")
var checks:=0
var failures:Array=[]
var returns:=0
class FailedHost:
	extends "res://raid/scripts/ship_transition.gd"
	var restores:=0
	func _create_raid()->Node:
		var result=load("res://raid/cinder_basin.tscn").instantiate()
		var config=load("res://raid/scripts/cinder_config.gd").new()
		config.map_seed=7;config.terrain_amplitude=12.0
		result.settings=config
		return result
	func _restore_title():restores+=1

func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func run():
	var default_report=Generator.new(Config.new()).validate_travel_layout()
	check(default_report.ok and default_report.max_triangle_grade<0.7,"Default trail corridor passes exact triangle grade limit")
	check(default_report.samples>10000,"Preflight samples bounded corridor densely")
	var reports=[]
	for item in [{"seed":7,"amplitude":12.0},{"seed":2,"amplitude":12.0},{"seed":1,"amplitude":NAN}]:
		var config=Config.new();config.map_seed=item.seed;config.terrain_amplitude=item.amplitude
		var scene=load("res://raid/cinder_basin.tscn").instantiate();scene.settings=config
		scene.return_requested.connect(func():returns+=1)
		root.add_child(scene);await process_frame
		check(not scene.is_raid_ready() and not scene.get_raid_failure().is_empty(),"Unsafe/invalid settings explicitly refuse readiness seed %d"%item.seed)
		check(not scene.build_result.ready and scene.build_result.failure==scene.get_raid_failure(),"Failure report matches readiness contract seed %d"%item.seed)
		check(scene.player==null and not scene.has_node("SeededTerrain"),"Refusal occurs before player/terrain activation seed %d"%item.seed)
		var buttons=scene.find_children("*","Button",true,false)
		check(buttons.size()==1 and buttons[0].text=="Return / Exit preview","Refused standalone scene offers exit button seed %d"%item.seed)
		var before=returns;buttons[0].pressed.emit();scene._request_return()
		check(returns==before+1 and scene.returning,"Refused scene returns once seed %d"%item.seed)
		if is_finite(item.amplitude):
			check(not scene.build_result.travel_layout.ok and scene.build_result.travel_layout.max_triangle_grade>0.7,"Unsafe seeds rejected on exact triangle slopes seed %d"%item.seed)
		reports.append(scene.build_result)
		scene.free();await process_frame
	var host=FailedHost.new();root.add_child(host)
	host.open_raid();await process_frame
	check(host.cover.visible and host.raid==null,"Real unsafe raid is freed while ship loading cover remains")
	check(host.status.text.contains("too steep") and host.status.text.contains("settlement was saved"),"Ship host reports generation failure immediately, not after timeout")
	host.return_to_settlement();host.return_to_settlement();await process_frame
	check(host.restores==1,"Failed host return is idempotent")
	host.free();await process_frame
	print("CINDER_READINESS_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"default":default_report,"refusals":reports,"rendered":false,"real_save_io":false}))
	quit(0 if failures.is_empty() else 1)
