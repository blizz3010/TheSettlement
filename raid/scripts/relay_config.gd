extends Resource
## First-map development settings. Fixed gameplay layout, seeded natural variation.
@export var map_seed: int = 241107
@export_range(0.0, 12.0) var terrain_amplitude: float = 5.0
@export_range(0.0, 1.0) var tree_density: float = 0.66
@export_range(0.0, 1.0) var grass_density: float = 0.68
@export_range(0.0, 1.0) var shrub_density: float = 0.20
@export_range(0.0, 1.0) var rock_density: float = 0.17
const VERSION := 1
const HALF_SIZE := 192.0
const PLAY_HALF := 146.0
const CELL := 2.0
const CHUNK := 32.0
const SPAWN := Vector2(-122, 118)
const EXTRACTS := [Vector2(-124,-120), Vector2(126,92)]
# Loot quality is a tunable prototype band, not an item/economy promise.
func pois() -> Array:
	return [
		{"id":"camp", "name":"Survey Camp", "at":Vector2(-90,82), "radius":15.0, "loot":[1,2], "lock":"", "theme":Color("879b76")},
		{"id":"substation", "name":"West Substation", "at":Vector2(-83,0), "radius":18.0, "loot":[2,3], "lock":"key", "theme":Color("c39d60")},
		{"id":"relay", "name":"Relay Tower", "at":Vector2(0,-8), "radius":21.0, "loot":[4,5], "lock":"code", "theme":Color("d8a25d")},
		{"id":"bunker", "name":"Research Annex", "at":Vector2(84,-79), "radius":21.0, "loot":[4,5], "lock":"keycard", "theme":Color("71b4bf")},
		{"id":"yard", "name":"Salvage Yard", "at":Vector2(76,54), "radius":21.0, "loot":[2,4], "lock":"", "theme":Color("b77655")},
		{"id":"weather", "name":"Weather Station", "at":Vector2(-66,-86), "radius":18.0, "loot":[2,3], "lock":"puzzle", "theme":Color("a8bac4")},
	]
func routes() -> Array:
	# A perimeter loop provides two approaches to each extract, separate from the relay.
	return [
		[SPAWN,Vector2(-90,100),Vector2(-120,100),Vector2(-120,18),Vector2(-83,18),Vector2(-110,18),Vector2(-115,-40),Vector2(-66,-62),Vector2(-100,-62),Vector2(-115,-100),EXTRACTS[0]],
		[Vector2(-66,-62),Vector2(0,-60),Vector2(44,-52),Vector2(84,-55),Vector2(117,-44),Vector2(117,78),Vector2(76,78),EXTRACTS[1]],
		[Vector2(76,78),Vector2(0,112),Vector2(-90,100)],
		[Vector2(-83,18),Vector2(-40,26),Vector2(0,16),Vector2(40,30),Vector2(40,78),Vector2(76,78)],
		[Vector2(0,16),Vector2(32,16),Vector2(35,-52),Vector2(84,-55)],
		[Vector2(84,-55),Vector2(128,-55),Vector2(135,-15),Vector2(132,45),EXTRACTS[1]],
		[EXTRACTS[0],Vector2(-132,-58),Vector2(-120,18),Vector2(-83,18)],
	]
func valid() -> bool:
	return map_seed >= 0 and map_seed <= 2147483647 and is_finite(terrain_amplitude) and terrain_amplitude >= 0.0 and terrain_amplitude <= 12.0 and _density(tree_density) and _density(grass_density) and _density(shrub_density) and _density(rock_density)
func _density(v:float)->bool:
	return is_finite(v) and v>=0.0 and v<=1.0
