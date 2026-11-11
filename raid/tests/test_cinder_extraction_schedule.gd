extends SceneTree
## Scheduler regression: production motion called by a priority-0 test driver.
## Headless mouse capture is unavailable, so this is not native-input acceptance.
const STEP:=1.0/60.0
var checks:=0
var failures:Array=[]
var scene
var driver
var returns:=0
class MotionDriver:
	extends Node
	var player
	var direction:=Vector3.ZERO
	var jump:=false
	func _physics_process(delta):player.step_motion(direction if player.enabled else Vector3.ZERO,4.2,jump and player.enabled,delta)
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func place(at:Vector2):
	scene.set_physics_process(false);driver.set_physics_process(false)
	scene.player.position=Vector3(at.x,scene.generator.height_at(at)+0.08,at.y);scene.player.velocity=Vector3.ZERO
	for i in 30:
		scene.player.step_motion(Vector3.ZERO,4.2,false,STEP)
		await physics_frame
func last_tick(target:Dictionary,direction:Vector3,jump:bool):
	scene._interact(target);scene._begin_extraction(target)
	scene.raid_state.extraction_seconds=scene.State.EXTRACTION_DURATION-STEP*0.5
	# Model an already-moving player at the final tick. The confirmation panel
	# correctly zeroes velocity when it opens, before this countdown fixture.
	scene.player.velocity.x=direction.x*4.2;scene.player.velocity.z=direction.z*4.2
	driver.direction=direction;driver.jump=jump
	scene.set_physics_process(true);driver.set_physics_process(true)
	await physics_frame;await physics_frame
	scene.set_physics_process(false);driver.set_physics_process(false)
func run():
	scene=load("res://raid/cinder_basin.tscn").instantiate();root.add_child(scene)
	var deadline=Time.get_ticks_msec()+60000
	while not scene.is_raid_ready() and Time.get_ticks_msec()<deadline:await process_frame
	check(scene.is_raid_ready(),"Actual scene ready")
	if not scene.is_raid_ready():scene.free();quit(1);return
	scene.player.set_physics_process(false)
	driver=MotionDriver.new();driver.player=scene.player;driver.set_physics_process(false);scene.add_child(driver)
	check(scene.process_physics_priority>driver.process_physics_priority,"Raid countdown runs after production-motion driver")
	var target:Dictionary={}
	for item in scene.targets:
		if item.kind=="extract":target=item;break
	await place(scene.settings.EXTRACTS[0])
	await last_tick(target,Vector3.ZERO,true)
	check(scene.raid_state.extracted_at.is_empty() and scene.raid_state.extraction_id.is_empty(),"Final-tick jump cancels rather than completing extraction")
	check(not scene.player.is_on_floor() and scene.player.enabled and not scene.modal.visible,"Final-tick jump remains airborne and playable")
	var beacon:Vector3=target.node.global_position
	await place(Vector2(beacon.x-scene.EXTRACTION_RADIUS+0.02,beacon.z))
	await last_tick(target,Vector3.LEFT,false)
	check(not scene._extraction_eligible(target),"Scheduled production motion crossed zone boundary")
	check(scene.raid_state.extracted_at.is_empty() and scene.raid_state.extraction_id.is_empty() and not scene.modal.visible,"Final-tick boundary crossing cancels without result modal")
	await place(scene.settings.EXTRACTS[0])
	await last_tick(target,Vector3.ZERO,false)
	check(scene.raid_state.extracted_at==target.poi.id and scene.modal.visible and not scene.player.enabled,"Scheduled stationary final tick completes normally")
	scene.return_requested.connect(func():returns+=1);scene._request_return();scene._request_return()
	check(returns==1,"Scheduled completion returns once")
	print("CINDER_EXTRACTION_SCHEDULE_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"scheduled_callbacks":true,"production_motion":true,"native_input":false,"rendered":false}))
	scene.free();await preload("res://raid/tests/audio_shutdown.gd").drain(self);quit(0 if failures.is_empty() else 1)
