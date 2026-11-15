extends Node
## Player health: max HP, damage with brief invulnerability, heal, optional regen, death.
## Drives the existing player vitals (scripts/player_vitals.gd) through set_values(),
## so the settlement HUD bar and the raid health HUD both follow it.
## Runtime only: nothing here is written to settlement saves.
signal damaged(amount: float, source: String, current: float)
signal healed(amount: float, current: float)
signal died(source: String)
signal revived

var vitals: RefCounted
var max_hp := 100.0
## Seconds of immunity after a hit (hit flash runs for the same window).
var invulnerability_seconds := 0.6
## HP per second after regen_delay seconds without damage. 0 disables regen.
var regen_per_second := 0.0
var regen_delay := 3.0
var invulnerable_left := 0.0
var since_damage := 0.0
var dead := false
var last_source := ""
var hits_taken := 0

func bind(target_vitals: RefCounted, maximum: float = 100.0) -> bool:
	if target_vitals == null or not target_vitals.has_method("set_values"): return false
	if not is_finite(maximum) or maximum <= 0.0: return false
	vitals = target_vitals
	max_hp = maximum
	return reset()

func current() -> float:
	return vitals.current if vitals != null else 0.0

func fraction() -> float:
	return current() / max_hp if max_hp > 0.0 else 0.0

func is_invulnerable() -> bool:
	return invulnerable_left > 0.0

## Returns true only when the hit landed (alive, not in i-frames, positive finite amount).
func damage(amount: float, source: String = "unknown") -> bool:
	if dead or vitals == null or not is_finite(amount) or amount <= 0.0: return false
	if invulnerable_left > 0.0: return false
	var next := maxf(0.0, vitals.current - amount)
	if not vitals.set_values(next, max_hp): return false
	invulnerable_left = invulnerability_seconds
	since_damage = 0.0
	last_source = source
	hits_taken += 1
	damaged.emit(amount, source, next)
	if next <= 0.0:
		dead = true
		died.emit(source)
	return true

## Returns the HP actually restored. The dead are not healed; use reset().
func heal(amount: float) -> float:
	if dead or vitals == null or not is_finite(amount) or amount <= 0.0: return 0.0
	var before: float = vitals.current
	vitals.set_values(minf(max_hp, before + amount), max_hp)
	var restored: float = vitals.current - before
	if restored > 0.0: healed.emit(restored, vitals.current)
	return restored

## Full HP, alive, no i-frames. Used on settlement return and on bind.
func reset() -> bool:
	if vitals == null: return false
	dead = false
	invulnerable_left = 0.0
	since_damage = 0.0
	var ok: bool = vitals.set_values(max_hp, max_hp)
	revived.emit()
	return ok

func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	invulnerable_left = maxf(0.0, invulnerable_left - delta)
	since_damage += delta
	if regen_per_second > 0.0 and not dead and since_damage >= regen_delay and current() < max_hp:
		heal(regen_per_second * delta)

func _physics_process(delta: float) -> void:
	tick(delta)
