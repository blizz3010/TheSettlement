extends RefCounted
## Scene paths are allowlisted, never supplied by UI text or a save file.
const RAIDS := {
	"relay_ridge": {
		"name": "Relay Ridge",
		"subtitle": "Forest ridge exploration",
		"description": "Explore six sites among wooded ridges. Find keys and codes, search prototype caches, and reach either extraction beacon.",
		"scene": "res://raid/relay_ridge.tscn"
	},
	"cinder_basin": {
		"name": "Cinder Basin",
		"subtitle": "Volcanic salt basin",
		"description": "Pale salt flats, basalt spires and six desert-industrial sites. Explore a solar mirror array and a sealed archive with service-key, clearance-card, code and valve-sequence locks.",
		"scene": "res://raid/cinder_basin.tscn"
	}
}

static func contains(raid_id: String) -> bool:
	return RAIDS.has(raid_id)

static func scene_path(raid_id: String) -> String:
	return str(RAIDS.get(raid_id, {}).get("scene", ""))

static func display_name(raid_id: String) -> String:
	return str(RAIDS.get(raid_id, {}).get("name", "Unknown raid"))
