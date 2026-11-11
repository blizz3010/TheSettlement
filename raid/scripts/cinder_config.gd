extends Resource
## Cinder Basin: a dry salt/volcanic basin. Fixed gameplay sites, seeded geology.
@export var map_seed:int=611204
@export_range(0.0,12.0) var terrain_amplitude:float=3.2
# Shared layer names retain tooling compatibility. Sparse juniper/yucca use tree;
# samphire uses grass; glassplume/bonebrush/agave use shrub. No woodland species.
@export_range(0.0,1.0) var tree_density:float=0.24
@export_range(0.0,1.0) var grass_density:float=0.14
@export_range(0.0,1.0) var shrub_density:float=0.16
@export_range(0.0,1.0) var rock_density:float=0.42
const VERSION:=2
const HALF_SIZE:=192.0
const PLAY_HALF:=146.0
const CELL:=2.0
const CHUNK:=32.0
const SPAWN:=Vector2(122,118)
const EXTRACTS:=[Vector2(-128,105),Vector2(122,-115)]
func pois()->Array:
	return [
		{"id":"caravan","name":"Siltway Caravan","at":Vector2(82,84),"radius":21.0,"loot":[1,2],"lock":"","theme":Color("ccaa72"),"forecourt":Vector2(82,108)},
		{"id":"glasskiln","name":"Glasskiln Works","at":Vector2(-88,30),"radius":45.0,"loot":[2,3],"lock":"key","theme":Color("d58652"),"forecourt":Vector2(-88,55),"room_offset":Vector2(-21,5)},
		{"id":"helion","name":"Helion Mirror Array","at":Vector2(-5,66),"radius":23.0,"loot":[4,5],"lock":"code","theme":Color("e2c875"),"forecourt":Vector2(-5,94),"panel_name":"Helion control panel"},
		{"id":"obsidian","name":"Obsidian Archive","at":Vector2(-69,-80),"radius":23.0,"loot":[4,5],"lock":"keycard","theme":Color("8ba1bd"),"forecourt":Vector2(-69,-56)},
		{"id":"sump","name":"Wreckwater Sump","at":Vector2(89,-12),"radius":23.0,"loot":[2,4],"lock":"","theme":Color("a5b89b"),"forecourt":Vector2(89,14)},
		{"id":"cistern","name":"Echo Cistern","at":Vector2(31,-84),"radius":22.0,"loot":[2,3],"lock":"puzzle","theme":Color("77b9b9"),"forecourt":Vector2(31,-60)},
	]
func routes()->Array:
	# Seven connected paths: northern industrial arc, southern caravan arc,
	# two cross-basin links and separate approaches to both extraction sites.
	return [
		[SPAWN,Vector2(82,108),Vector2(-5,94),Vector2(-88,55),Vector2(-122,55),EXTRACTS[0]],
		[Vector2(-88,55),Vector2(-126,55),Vector2(-130,8),Vector2(-120,-30),Vector2(-112,-56),Vector2(-69,-56),Vector2(31,-60),Vector2(118,-60),EXTRACTS[1]],
		[Vector2(31,-60),Vector2(62,-40),Vector2(62,14),Vector2(89,14),Vector2(125,45),SPAWN],
		[Vector2(-88,55),Vector2(-48,55),Vector2(-48,18),Vector2(-5,20),Vector2(43,25),Vector2(89,14)],
		[Vector2(-5,94),Vector2(24,94),Vector2(28,20),Vector2(4,-30),Vector2(31,-60)],
		[EXTRACTS[0],Vector2(-134,40),Vector2(-134,-32),Vector2(-112,-56)],
		[EXTRACTS[1],Vector2(136,-55),Vector2(134,15),Vector2(125,45)],
	]
func valid()->bool:
	return map_seed>=0 and map_seed<=2147483647 and is_finite(terrain_amplitude) and terrain_amplitude>=0 and terrain_amplitude<=12 and _density(tree_density) and _density(grass_density) and _density(shrub_density) and _density(rock_density)
func _density(value:float)->bool:return is_finite(value) and value>=0 and value<=1
