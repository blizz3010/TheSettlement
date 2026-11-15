extends RefCounted
## In-process hand-off from a finished raid to the next settlement load.
## Nothing here is saved; it only lets the settlement say what happened.
static var last: Dictionary = {}

static func record(outcome: Dictionary) -> void:
	last = outcome.duplicate(true)

static func take() -> Dictionary:
	var result := last
	last = {}
	return result
