extends SceneTree
## TASKS item 22, PR B: raid hookup for tiered gear, in the real Relay Ridge and
## Cinder Basin scenes. Headless; disposable XDG profile (user:// is per-run).
## Prints one machine-readable marker line: GEAR_RAID_TESTS {json}.
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const State = preload("res://raid/scripts/gear_tiers/gear_locker_state.gd")
const Store = preload("res://raid/scripts/gear_tiers/gear_locker_store.gd")
const RaidGear = preload("res://raid/scripts/gear_tiers/raid_gear.gd")
const GearPlayer = preload("res://raid/scripts/gear_tiers/raid_gear_player.gd")
const BasePlayer = preload("res://scripts/player.gd")
var checks := 0
var failures: Array = []
var facts := {}

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func near(a: float, b: float, eps: float = 0.01) -> bool:
	return absf(a - b) <= eps

func _initialize():
	call_deferred("run")

func frames(n: int):
	for i in n: await physics_frame

func remove_locker():
	for f in [Store.DEFAULT_PATH, Store.DEFAULT_PATH + ".tmp", Store.DEFAULT_PATH + ".invalid-backup"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

func write_kit(tier: int) -> void:
	var store = Store.new()
	store.path = Store.DEFAULT_PATH
	for slot in Defs.SLOTS: store.state.equip(store.state.grant(Defs.item_id(slot, tier)))
	check(store.save(), "seeded T%d locker saved" % tier)

func open_scene(path: String):
	var scene = load(path).instantiate()
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 60000
	while not scene.is_raid_ready() and Time.get_ticks_msec() < deadline: await process_frame
	check(scene.is_raid_ready(), path + " ready")
	return scene

func close_scene(scene) -> void:
	scene.queue_free()
	await process_frame
	await process_frame

func saved_state():
	var s = State.new()
	s.restore(JSON.parse_string(FileAccess.get_file_as_string(Store.DEFAULT_PATH)))
	return s

# ----------------------------------------------------------- empty locker
func empty_tests():
	remove_locker()
	var buses := AudioServer.bus_count
	for map in ["res://raid/relay_ridge.tscn", "res://raid/cinder_basin.tscn"]:
		var scene = await open_scene(map)
		if not scene.is_raid_ready(): continue
		var h = scene.health_controller.health
		check(scene.gear == null and scene.get_node_or_null("RaidGear") == null, map + ": no gear node with an empty locker")
		check(scene.player.get_script() == BasePlayer, map + ": raid player is plain player.gd")
		check(not h.reduction.is_valid(), map + ": no reduction hook bound")
		check(scene.health_controller.safe_fall_speed == scene.health_controller.SAFE_FALL_SPEED, map + ": safe fall speed unchanged")
		check(AudioServer.get_bus_index(RaidGear.THREAT_BUS) < 0, map + ": no GearThreat bus")
		check(scene.find_child("GearHud", true, false) == null, map + ": no gear HUD")
		h.invulnerable_left = 0.0
		check(h.damage(12.0, "sentry turret") and h.current() == 88.0, map + ": turret hit unreduced")
		await close_scene(scene)
	check(not FileAccess.file_exists(Store.DEFAULT_PATH), "empty locker: no gear_locker.json written")

# -------------------------------------------------------------- T4 kit
func kit_tests():
	remove_locker()
	write_kit(4)
	var buses := AudioServer.bus_count
	var scene = await open_scene("res://raid/relay_ridge.tscn")
	if not scene.is_raid_ready(): return
	var gear = scene.gear
	var ctl = scene.health_controller
	var h = ctl.health
	check(gear != null and gear.is_inside_tree() and gear.active(), "gear node active")
	check(h.reduction.is_valid(), "reduction hook bound")
	check(scene.player.get_script() == GearPlayer and near(scene.player.gear_sprint_mult, 0.92, 0.0001) and scene.player.gear_walk_mult == 1.0, "16.3 kg kit: sprint x0.92, walk x1.0")
	check(near(ctl.safe_fall_speed, ctl.SAFE_FALL_SPEED + 1.5), "Shockstep boots raise safe fall speed by 1.5 m/s")
	var bus := AudioServer.get_bus_index(RaidGear.THREAT_BUS)
	check(bus >= 0, "GearThreat bus added")
	var comp = AudioServer.get_bus_effect(bus, 0) if bus >= 0 and AudioServer.get_bus_effect_count(bus) > 0 else null
	check(comp is AudioEffectCompressor and comp.ratio == 8.0 and comp.threshold == -22.0, "Echoline headset: strong compression")
	check(gear.streams.size() == 4, "four threat cues loaded (%d)" % gear.streams.size())
	var hud = scene.find_child("GearHud", true, false)
	check(hud != null and hud.visible and gear.hud_label.text.find("Ballistic 60%") >= 0 and gear.hud_label.text.find("16.3 kg") >= 0, "HUD readout: " + gear.hud_label.text.replace("\n", " | "))
	# Direct turret hit: 12 -> 4.8, armor wears, HUD updates.
	h.invulnerable_left = 0.0
	var armor: String = gear.store.state.slots.body_armor
	check(h.damage(12.0, "sentry turret") and near(h.current(), 95.2), "turret 12 -> 4.8 through the hook (%.2f)" % h.current())
	check(gear.store.state.owned[armor].durability < 110.0 and gear.dirty, "armor wore in play")
	check(gear.hud_label.text.find("Durability") >= 0 and gear.hud_label.text.find("lowest") >= 0, "HUD shows durability after a hit")
	# Real hazard tick in play: reduced, face cover adds i-frame time, gloves wear.
	h.reset()
	var gloves: String = gear.store.state.slots.gloves
	var gloves_before: float = gear.store.state.owned[gloves].durability
	scene.player.position = ctl.hazard.global_position + Vector3(0, 0.1, 0)
	scene.player.velocity = Vector3.ZERO
	await frames(2)
	scene.player.set_physics_process(false)
	ctl.hazard.set_physics_process(false)
	h.invulnerable_left = 0.0
	var hz_reduction: float = gear.store.state.reduction_for("hazard")
	var hz_before: float = h.current()
	check(ctl.hazard.step(0.016), "hazard hits in play")
	check(near(hz_before - h.current(), 12.0 * (1.0 - hz_reduction), 0.02), "hazard damage reduced (%.2f)" % (hz_before - h.current()))
	ctl.hazard.set_physics_process(true)
	scene.player.set_physics_process(true)
	check(near(h.invulnerable_left, h.invulnerability_seconds + 0.1, 0.001), "Sealed Respirator adds 0.1 s hazard i-frames")
	check(gear.store.state.owned[gloves].durability < gloves_before, "gloves wore from the hazard")
	# Fall: boots raise the threshold and reduce the rest.
	h.reset(); h.invulnerable_left = 0.0
	check(ctl.land(14.0) == 0.0, "14 m/s landing is now safe (was 6 damage)")
	h.invulnerable_left = 0.0
	var fall_dr: float = gear.store.state.reduction_for("fall")
	ctl.land(18.0)
	check(near(100.0 - h.current(), (18.0 - 14.5) * 6.0 * (1.0 - fall_dr), 0.02), "fall damage reduced (%.2f)" % (100.0 - h.current()))
	# Weight effect on real player motion.
	scene.player.set_physics_process(false)
	scene.player.position = Vector3(scene.settings.SPAWN.x, scene.generator.height_at(scene.settings.SPAWN) + 0.1, scene.settings.SPAWN.y)
	scene.player.velocity = Vector3.ZERO
	for i in 40: scene.player.step_motion(Vector3(1, 0, 0), 7.0, false, 1.0 / 60.0)
	var sprint_v := Vector2(scene.player.velocity.x, scene.player.velocity.z).length()
	scene.player.velocity = Vector3.ZERO
	for i in 40: scene.player.step_motion(Vector3(1, 0, 0), 4.2, false, 1.0 / 60.0)
	var walk_v := Vector2(scene.player.velocity.x, scene.player.velocity.z).length()
	facts["speeds"] = {"sprint": sprint_v, "walk": walk_v}
	check(near(sprint_v, 7.0 * 0.92, 0.05), "sprint capped at 6.44 m/s (%.2f)" % sprint_v)
	check(near(walk_v, 4.2, 0.05), "walk unchanged at 4.2 m/s (%.2f)" % walk_v)
	scene.player.set_physics_process(true)
	# Headset: hearing range and threat cues.
	check(near(gear.threat_range(), 24.0 * 1.6), "Echoline hearing range 38.4 m")
	var p: Vector3 = scene.player.global_position
	check(gear.play_threat("live_cable_crackle", p + Vector3(30, 0, 0)), "cue at 30 m heard with T4")
	check(not gear.play_threat("live_cable_crackle", p + Vector3(40, 0, 0)), "cue at 40 m out of range")
	gear.hearing_range = 0.10
	check(not gear.play_threat("live_cable_crackle", p + Vector3(30, 0, 0)), "T1 range (26.4 m) misses the same 30 m cue")
	gear.hearing_range = 0.60
	var t = ctl.turret
	t.set_physics_process(false)
	scene.player.position = t.global_position + Vector3(10, 0.2, 0)
	scene.player.rotation.y = 0.0
	gear.events.clear()
	gear.turret_was_tracking = false
	t.tracking = true
	gear._physics_process(1.0 / 60.0)
	var cues: Array = gear.events.map(func(e): return e[0])
	check("turret_servo_whine" in cues and "turret_warmup_tone" in cues, "turret acquire plays servo + warmup: " + str(cues))
	check(gear.hint_label.visible and gear.hint_label.text.begins_with("THREAT"), "T4 direction hint: " + gear.hint_label.text)
	t.shots += 1
	gear._physics_process(1.0 / 60.0)
	check(gear.events.map(func(e): return e[0]).has("turret_shot"), "turret shot cue")
	# Downed: gear kept, -25% max durability, saved immediately.
	var before_down := {}
	for id in gear.store.state.equipped_ids(): before_down[id] = float(gear.store.state.owned[id].durability)
	h.invulnerable_left = 0.0
	h.damage(1000.0, "test")
	await process_frame
	check(h.dead and gear.store.state.equipped_ids().size() == 11, "downed: all 11 pieces kept")
	var ok_loss := true
	for id in before_down:
		var maximum := float(Defs.item(gear.store.state.owned[id].def).durability)
		if not near(float(gear.store.state.owned[id].durability), maxf(0.0, before_down[id] - maximum * 0.25), 0.002): ok_loss = false
	check(ok_loss, "downed: each piece lost 25% of max durability")
	var disk = saved_state()
	check(disk.equipped_ids().size() == 11 and near(float(disk.owned[armor].durability), float(gear.store.state.owned[armor].durability), 0.002), "downed state saved to user://gear_locker.json")
	facts["armor_durability_after"] = gear.store.state.owned[armor].durability
	await close_scene(scene)
	check(AudioServer.get_bus_index(RaidGear.THREAT_BUS) < 0 and AudioServer.bus_count == buses, "GearThreat bus removed after the raid (bus count back to %d)" % buses)

# ------------------------------------------- save on exit + light kit
func exit_save_tests():
	remove_locker()
	write_kit(1)
	var scene = await open_scene("res://raid/cinder_basin.tscn")
	if not scene.is_raid_ready(): return
	var gear = scene.gear
	check(gear != null and scene.health_controller.health.reduction.is_valid(), "cinder: gear active")
	check(scene.player.get_script() == BasePlayer, "8.5 kg kit: no weight penalty, plain player.gd")
	var bus := AudioServer.get_bus_index(RaidGear.THREAT_BUS)
	check(bus >= 0 and AudioServer.get_bus_effect_count(bus) == 0, "Earmuff Set: no compression")
	var h = scene.health_controller.health
	h.invulnerable_left = 0.0
	h.damage(12.0, "sentry turret")
	check(near(h.current(), 100.0 - 10.08), "T1 kit turret 12 -> 10.08")
	var armor: String = gear.store.state.slots.body_armor
	var live: float = gear.store.state.owned[armor].durability
	check(live < 60.0, "T1 armor wore")
	scene.return_requested.connect(func(): pass)
	scene._request_return()
	await close_scene(scene)
	var disk = saved_state()
	check(near(float(disk.owned[armor].durability), live, 0.002), "wear saved when the raid ends (%.3f)" % live)
	# Corrupt sidecar: raid still starts, gear empty, bad bytes kept.
	var f := FileAccess.open(Store.DEFAULT_PATH, FileAccess.WRITE); f.store_string("{broken"); f.close()
	var s2 = await open_scene("res://raid/relay_ridge.tscn")
	check(s2.is_raid_ready() and s2.gear == null, "corrupt locker: raid starts with no gear")
	check(FileAccess.file_exists(Store.DEFAULT_PATH + ".invalid-backup"), "corrupt locker kept as .invalid-backup")
	await close_scene(s2)
	remove_locker()

func run():
	await empty_tests()
	await kit_tests()
	await exit_save_tests()
	await process_frame
	print("GEAR_RAID_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "facts": facts}))
	quit(0 if failures.is_empty() else 1)
