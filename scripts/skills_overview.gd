extends RefCounted
# Fresh values only: no references to gameplay state and no progression bookkeeping.
static func groups() -> Array:
	return [
		{"title":"Activities in this build", "rows":[
			["Construction", "Place, rotate and remove home building pieces. Structural building remains free during testing."],
			["Textiles", "Dan's starter outfit and limited free dye test are playable. Tailoring and textile skill progression are not implemented."],
			["Fishing", "First catch is a one-time starter request with a free test rod. Repeatable fishing and fishing skill progression are not enabled."]]},
		{"title":"Planned families — not playable skills", "rows":[
			["Food & gathering", "Cooking, foraging and resource processing."],
			["Care & equipment", "Medical care, weapon handling and gunsmithing."],
			["Making & learning", "Engineering, research and expanded textiles."],
			["Physical training", "Fitness and movement skills."]]},
		{"title":"Attribute concepts — not active stats", "rows":[
			["STR / INT / DEX", "Strength, intelligence and dexterity are design concepts only. No attribute values, bonuses or unlocks are applied."]]}
	]
