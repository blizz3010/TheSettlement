extends RefCounted
# One local job; only committed active-play seconds count, never wall-clock time.
var status := "idle"
var recipe := ""
var remaining := 0
func data() -> Dictionary:
	return {"version":1,"status":status,"recipe":recipe,"remaining":remaining}
func restore(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 4: return false
	var v = value.get("version"); var seconds = value.get("remaining")
	if not (v is int or v is float) or v != 1: return false
	if not (seconds is int or seconds is float) or not is_finite(float(seconds)) or seconds != floor(seconds): return false
	if not value.get("status") is String or not value.get("recipe") is String: return false
	if value.status == "idle":
		if value.recipe != "" or seconds != 0: return false
	elif value.status == "working":
		if value.recipe != "lantern" or seconds < 1 or seconds > 10: return false
	elif value.status == "ready":
		if value.recipe != "lantern" or seconds != 0: return false
	else: return false
	status = value.status; recipe = value.recipe; remaining = int(seconds)
	return true
