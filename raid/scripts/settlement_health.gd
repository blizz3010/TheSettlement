extends RefCounted
## Settlement side of health: the settlement player gets the same health component,
## regenerating, so the existing HUD vitals bar (settlement_hud.gd) has a live source.
## A raid that ended downed is reported once, and health is reset to full on return.
const Health = preload("res://raid/scripts/health_component.gd")
const Outcome = preload("res://raid/scripts/raid_outcome.gd")
const REGEN_PER_SECOND := 5.0
const REGEN_DELAY := 4.0

static func attach(player: Node) -> Node:
	if player == null or player.get("vitals") == null: return null
	var existing := player.get_node_or_null("Health")
	if existing != null: return existing
	var health := Health.new()
	health.name = "Health"
	health.regen_per_second = REGEN_PER_SECOND
	health.regen_delay = REGEN_DELAY
	player.add_child(health)
	health.bind(player.vitals, 100.0)
	return health

## Consumes the last raid outcome. Returns the message to show ("" if none).
static func on_return(health: Node) -> String:
	var outcome := Outcome.take()
	if health != null: health.reset()
	if outcome.get("outcome", "") != "downed": return ""
	return "Recovered from %s after being downed by the %s. Raid failed; raid loot does not persist yet, so nothing was lost. Health restored." % [outcome.get("map", "the raid"), outcome.get("source", "unknown")]
