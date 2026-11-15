extends SceneTree
## Health/damage acceptance (headless, --fixed-fps 60, disposable XDG profile).
## Covers: health component maths + i-frames + heal/regen/death/reset, vitals -> raid HUD,
## hazard zone and sentry turret damage in the real Relay Ridge scene, fall and
## out-of-bounds damage, downed -> raid failed -> existing return path, settlement reset.
const Health = preload("res://raid/scripts/health_component.gd")
const Vitals = preload("res://scripts/player_vitals.gd")
const Outcome = preload("res://raid/scripts/raid_outcome.gd")
const SettlementHealth = preload("res://raid/scripts/settlement_health.gd")
var checks := 0
var failures: Array = []
var facts := {}

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize():
	call_deferred("run")

func frames(n: int):
	for i in n: await physics_frame

func unit_tests():
	var vitals = Vitals.new()
	var changes := []
	vitals.changed.connect(func(c, m): changes.append([c, m]))
	var h = Health.new()
	root.add_child(h)
	h.set_physics_process(false)  # drive time explicitly
	var died := []
	h.died.connect(func(s): died.append(s))
	check(h.bind(vitals, 100.0) and vitals.current == 100.0, "bind sets full health")
	check(h.damage(30.0, "test") and vitals.current == 70.0, "damage lowers vitals via set_values")
	check(changes.size() >= 1 and changes[-1] == [70.0, 100.0], "vitals.changed emitted for HUD")
	check(not h.damage(30.0, "test") and vitals.current == 70.0, "i-frames block an immediate second hit")
	h.tick(0.3)
	check(not h.damage(10.0, "test"), "still invulnerable at 0.3 s")
	h.tick(0.31)
	check(h.damage(10.0, "test") and vitals.current == 60.0, "hit lands after 0.6 s i-frames")
	check(not h.damage(-5.0) and not h.damage(NAN) and not h.damage(0.0), "invalid damage rejected")
	check(is_equal_approx(h.heal(25.0), 25.0) and vitals.current == 85.0, "heal restores")
	check(is_equal_approx(h.heal(50.0), 15.0) and vitals.current == 100.0, "heal capped at max")
	h.regen_per_second = 10.0; h.regen_delay = 1.0
	h.tick(1.0); h.damage(40.0, "test")
	h.tick(0.5)
	check(vitals.current == 60.0, "no regen inside the delay")
	for i in 30: h.tick(0.1)
	check(vitals.current > 75.0 and vitals.current <= 100.0, "regen after delay (%.1f)" % vitals.current)
	h.regen_per_second = 0.0
	h.invulnerable_left = 0.0
	check(h.damage(500.0, "test") and vitals.current == 0.0 and h.dead, "lethal damage clamps at 0 and kills")
	check(died == ["test"], "died emitted once")
	check(h.heal(50.0) == 0.0 and not h.damage(5.0), "dead cannot be healed or damaged")
	check(h.reset() and not h.dead and vitals.current == 100.0, "reset revives at full")
	h.queue_free()

func find_los_spot(scene, turret: Node3D, distance: float) -> bool:
	for k in 16:
		var a := TAU * k / 16.0
		var p := Vector2(turret.position.x, turret.position.z) + Vector2(cos(a), sin(a)) * distance
		scene.player.position = Vector3(p.x, scene.generator.height_at(p) + 0.08, p.y)
		scene.player.velocity = Vector3.ZERO
		await frames(3)
		if turret.has_line_of_sight(): return true
	return false

func scene_tests():
	var scene = load("res://raid/relay_ridge.tscn").instantiate()
	root.add_child(scene)
	var deadline := Time.get_ticks_msec() + 60000
	while not scene.is_raid_ready() and Time.get_ticks_msec() < deadline: await process_frame
	check(scene.is_raid_ready(), "relay ridge ready with health wired")
	if not scene.is_raid_ready(): return
	var returns := [0]
	scene.return_requested.connect(func(): returns[0] += 1)
	var ctl = scene.health_controller
	var h = ctl.health
	var hud = ctl.hud
	check(h != null and h.get_parent() == scene.player and h.vitals == scene.player.vitals, "health component on raid player, bound to its vitals")
	check(hud.bar.value == 100.0 and hud.value_label.text == "100 / 100", "HUD starts full")
	check(ctl.hazard != null and ctl.turret != null, "hazard and turret placed: " + str(ctl.placement))
	if ctl.hazard == null or ctl.turret == null: return
	var hz: Vector2 = ctl.placement.hazard
	var tr: Vector2 = ctl.placement.turret
	check(scene.generator.route_distance(hz) >= ctl.HAZARD_ROUTE_CLEARANCE and scene.generator.route_distance(tr) >= ctl.TURRET_ROUTE_CLEARANCE, "dangers stay clear of travel routes")
	facts["placement"] = {"hazard": str(hz), "turret": str(tr)}
	# Hazard zone.
	scene.player.position = ctl.hazard.global_position + Vector3(0, 0.1, 0)
	scene.player.velocity = Vector3.ZERO
	await frames(2)
	h.invulnerable_left = 0.0
	var before: float = h.current()
	var flashes: int = hud.flashes
	check(ctl.hazard.step(0.016), "hazard damages a player standing in it")
	check(h.current() == before - ctl.hazard.damage, "hazard damage amount")
	check(hud.bar.value == h.current() and hud.value_label.text.begins_with(str(int(h.current()))), "HUD bar and value follow damage")
	check(hud.flashes == flashes + 1 and hud.flash.color.a > 0.2, "hit flash shown")
	check(not ctl.hazard.step(0.016) and h.current() == before - ctl.hazard.damage, "i-frames stop hazard re-hits")
	await frames(45)  # 0.75 s: i-frames lapse, the hazard's own physics tick hits again
	check(h.current() <= before - 2 * ctl.hazard.damage, "hazard hits again after i-frames (%.0f)" % h.current())
	scene._field_notes()
	h.invulnerable_left = 0.0
	var paused: float = h.current()
	check(not ctl.combat_active() and not ctl.hazard.step(0.016) and h.current() == paused, "no hazard damage while a menu is open")
	scene._close_modal()
	h.reset()
	# Fall damage.
	h.invulnerable_left = 0.0
	check(ctl.land(8.0) == 0.0 and h.current() == 100.0, "normal landing is safe")
	check(is_equal_approx(ctl.land(18.0), 30.0) and h.current() == 70.0, "4m+ landing hurts ((18-13)*6)")
	# Out of bounds: damage + respawn at spawn.
	h.invulnerable_left = 0.0
	scene.player.position = Vector3(scene.settings.SPAWN.x, -8.0, scene.settings.SPAWN.y)
	await process_frame; await process_frame
	check(h.current() == 70.0 - ctl.OUT_OF_BOUNDS_DAMAGE and scene.player.position.y > -1.0, "falling out of the map hurts and respawns")
	h.reset()
	# Sentry turret.
	scene.player.position = Vector3(tr.x + 40.0, scene.generator.height_at(tr + Vector2(40, 0)) + 0.1, tr.y)
	await frames(30)
	check(ctl.turret.shots == 0 and not ctl.turret.tracking, "turret ignores a player out of range")
	var los: bool = await find_los_spot(scene, ctl.turret, 9.0)
	check(los, "found a spot with line of sight to the turret")
	if los:
		h.reset()
		await frames(170)  # warmup 0.9 + interval 1.6 -> at least 1 shot, normally 2
		facts["turret_shots"] = ctl.turret.shots
		check(ctl.turret.shots >= 1 and ctl.turret.hits >= 1, "turret fires and hits (%d shots)" % ctl.turret.shots)
		check(h.current() == 100.0 - ctl.turret.hits * ctl.turret.damage, "turret damage per hit")
		check(hud.bar.value == h.current(), "HUD follows turret damage")
	# Death -> raid fail -> return.
	h.invulnerable_left = 0.0
	Outcome.last = {}
	h.damage(1000.0, "sentry turret")
	await process_frame
	check(h.dead and ctl.downed and scene.downed, "player downed at 0 HP")
	check(scene.modal.visible and not scene.player.enabled, "downed screen shown, controls off")
	var heading: Label = scene.modal_content.get_child(0)
	check(heading.text.begins_with("Downed"), "downed heading: " + heading.text)
	check(Outcome.last.get("outcome", "") == "downed" and Outcome.last.get("loot_persisted", true) == false, "raid failure recorded for the settlement")
	scene._close_modal()
	check(scene.modal.visible, "downed screen cannot be dismissed back into play")
	check(not ctl.combat_active(), "dangers inert while downed")
	check(ctl.auto_return_left > 0.0, "auto-return countdown armed")
	ctl.return_after_downed()
	check(scene.returning and returns[0] == 1, "downed uses the existing return path (return_requested)")
	scene.queue_free()
	await process_frame

func settlement_tests():
	var player = preload("res://scripts/player.gd").new()
	player.enabled = false
	root.add_child(player)
	var hud_updates := []
	player.vitals.changed.connect(func(c, m): hud_updates.append(c))
	var h = SettlementHealth.attach(player)
	check(h != null and SettlementHealth.attach(player) == h, "settlement health attaches once")
	check(player.vitals.current == 100.0 and h.regen_per_second > 0.0, "settlement health full, regenerating")
	h.set_physics_process(false)
	h.damage(40.0, "test")
	check(hud_updates.has(60.0), "settlement HUD vitals source updated")
	for i in 160: h.tick(0.1)  # 16 s: 4 s delay + 12 s at 5 HP/s
	check(player.vitals.current == 100.0, "settlement regen back to full (%.1f)" % player.vitals.current)
	Outcome.record({"outcome": "downed", "map": "Relay Ridge", "source": "sentry turret"})
	h.damage(50.0, "test")
	var note := SettlementHealth.on_return(h)
	check(player.vitals.current == 100.0 and note.find("Relay Ridge") >= 0, "return after downed: full health + note")
	check(Outcome.last.is_empty() and SettlementHealth.on_return(h) == "", "outcome consumed once")
	player.queue_free()

func run():
	unit_tests()
	await scene_tests()
	settlement_tests()
	await process_frame
	print("HEALTH_DAMAGE_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "facts": facts}))
	quit(0 if failures.is_empty() else 1)
