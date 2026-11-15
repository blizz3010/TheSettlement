extends Node
## Raid health wiring: player health + HUD, fall and out-of-bounds damage, one hazard
## zone and one sentry turret placed off the fixed travel routes, and the downed flow
## (raid fails, the existing return path takes the player back to the settlement).
const Health = preload("res://raid/scripts/health_component.gd")
const Hud = preload("res://raid/scripts/raid_health_hud.gd")
const Hazard = preload("res://raid/scripts/hazard_zone.gd")
const Turret = preload("res://raid/scripts/sentry_turret.gd")
const Outcome = preload("res://raid/scripts/raid_outcome.gd")
const MAX_HP := 100.0
## Landing faster than this (m/s, gravity 20) hurts: roughly a 4 m drop. A normal jump lands at 6.
const SAFE_FALL_SPEED := 13.0
const FALL_DAMAGE_PER_MS := 6.0
const OUT_OF_BOUNDS_DAMAGE := 25.0
const AUTO_RETURN_SECONDS := 12.0
## Hazards keep clear of the fixed travel routes so route play is never forced through them.
const HAZARD_ROUTE_CLEARANCE := 9.0
const TURRET_ROUTE_CLEARANCE := 21.0

var world: Node
var health: Node
var hud: Control
var hazard: Node3D
var turret: Node3D
var was_airborne := false
var last_vertical_speed := 0.0
var last_position := Vector3.INF
var downed := false
var auto_return_left := -1.0
var placement: Dictionary = {}

func setup(raid_world: Node, ui_parent: Control) -> void:
	name = "RaidHealth"
	world = raid_world
	process_physics_priority = 2  # after the player (0) and the raid world (1)
	health = Health.new()
	health.name = "Health"
	health.invulnerability_seconds = 0.6
	world.player.add_child(health)
	health.bind(world.player.vitals, MAX_HP)
	health.died.connect(_on_died)
	hud = Hud.new()
	ui_parent.add_child(hud)
	hud.bind(health)
	_place_dangers()

func combat_active() -> bool:
	if downed or world == null or not world.ready_for_play or world.returning: return false
	if not world.raid_state.extracted_at.is_empty(): return false
	if not world.player.enabled: return false
	if is_instance_valid(world.modal) and world.modal.visible: return false
	if is_instance_valid(world.map_panel) and world.map_panel.visible: return false
	return true

# ---------------------------------------------------------------- placement
func _site_ok(p: Vector2, route_clearance: float, keep_from: Array) -> bool:
	var g = world.generator
	if maxf(absf(p.x), absf(p.y)) > 132.0: return false
	if g.route_distance(p) < route_clearance: return false
	for poi in g.pois:
		if p.distance_to(poi.at) < poi.radius + route_clearance: return false
	for e in world.settings.EXTRACTS:
		if p.distance_to(e) < 24.0: return false
	if p.distance_to(world.settings.SPAWN) < 22.0: return false
	for other in keep_from:
		if p.distance_to(other) < 30.0: return false
	# Reasonably flat footprint.
	var h: float = g.height_at(p)
	for o in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
		if absf(g.height_at(p + o) - h) > 0.7: return false
	return true

func _find_site(route_clearance: float, keep_from: Array) -> Variant:
	# Nearest qualifying grid point to the spawn, so a curious player meets it early.
	var spawn: Vector2 = world.settings.SPAWN
	var best: Variant = null
	var best_d := INF
	for ix in range(-22, 23):
		for iz in range(-22, 23):
			var p := Vector2(ix * 6.0, iz * 6.0)
			var d := p.distance_to(spawn)
			if d < best_d and _site_ok(p, route_clearance, keep_from):
				best = p
				best_d = d
	return best

func _place_dangers() -> void:
	var g = world.generator
	var hz = _find_site(HAZARD_ROUTE_CLEARANCE, [])
	if hz != null:
		hazard = Hazard.new()
		hazard.build()
		hazard.position = Vector3(hz.x, g.height_at(hz), hz.y)
		hazard.player = world.player
		hazard.health = health
		hazard.active_check = combat_active
		world.add_child(hazard)
	var tr = _find_site(TURRET_ROUTE_CLEARANCE, [hz] if hz != null else [])
	if tr != null:
		turret = Turret.new()
		turret.build()
		turret.position = Vector3(tr.x, g.height_at(tr) - 0.05, tr.y)
		turret.player = world.player
		turret.health = health
		turret.active_check = combat_active
		world.add_child(turret)
	placement = {"hazard": hz, "turret": tr, "hazard_route_clearance": HAZARD_ROUTE_CLEARANCE, "turret_route_clearance": TURRET_ROUTE_CLEARANCE}

# ------------------------------------------------------------ fall damage
func _physics_process(delta: float) -> void:
	if auto_return_left > 0.0:
		auto_return_left -= delta
		if auto_return_left <= 0.0: return_after_downed()
	if world == null or not world.ready_for_play or downed: return
	var p: CharacterBody3D = world.player
	var teleported := not last_position.is_finite() or p.global_position.distance_to(last_position) > 2.5
	last_position = p.global_position
	var grounded := p.is_on_floor()
	if teleported:
		was_airborne = not grounded
		last_vertical_speed = 0.0
		return
	if grounded and was_airborne:
		land(-last_vertical_speed)
	was_airborne = not grounded
	last_vertical_speed = p.velocity.y if not grounded else 0.0

## Applies fall damage for a landing at impact_speed m/s. Returns damage applied (0 if safe).
func land(impact_speed: float) -> float:
	if impact_speed <= SAFE_FALL_SPEED or not combat_active(): return 0.0
	var amount := (impact_speed - SAFE_FALL_SPEED) * FALL_DAMAGE_PER_MS
	return amount if health.damage(amount, "fall") else 0.0

## Called by the raid world instead of a silent respawn when the player leaves the map.
func out_of_bounds() -> void:
	if combat_active():
		health.invulnerable_left = 0.0
		health.damage(OUT_OF_BOUNDS_DAMAGE, "fall")
	last_position = Vector3.INF

# ----------------------------------------------------------------- downed
func _on_died(source: String) -> void:
	if downed: return
	downed = true
	world.downed = true
	var p: CharacterBody3D = world.player
	p.velocity = Vector3.ZERO
	if not world.raid_state.extraction_id.is_empty(): world._cancel_extraction()
	Outcome.record({"outcome": "downed", "map": world._map_name(), "source": source,
		"visited": world.raid_state.visited.size(), "searched": world.raid_state.searched.size(), "loot_persisted": false})
	world._start_modal("Downed · Raid failed")
	world._text("You were downed by the %s. The raid has failed and you are being recovered to the settlement." % source)
	world._scroll_text(world._summary_text())
	world._text("Raid loot is not persistent yet, so there is nothing to lose: keys and sample rolls from this raid are discarded and your settlement is unchanged. You return at full health.")
	var button: Button = world._button("Return to settlement now", return_after_downed)
	button.grab_focus()
	auto_return_left = AUTO_RETURN_SECONDS
	print("RAID_DOWNED ", JSON.stringify({"map": world._map_name(), "source": source}))

func return_after_downed() -> void:
	auto_return_left = -1.0
	if world != null and not world.returning: world._request_return()
