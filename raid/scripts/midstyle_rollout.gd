extends RefCounted
## Item 12 rollout of the item 11 pass 3 mid-stylized look (PR #10, awaiting Michael's OK to merge).
## Swaps the art of four raid prop families for Blender remodels in assets/midstyle_rollout,
## built by tools/blender_midstyle/build_rollout.py:
##  * weather-station relay lever  (puzzle_controls.gd)  relay_lever_weather_station.gltf
##  * loot caches, both palettes   (raid_props.gd)       loot_cache_{woodland,saltflat}.gltf
##  * cargo containers and stacks  (cargo_scenery.gd)    cargo_*.gltf
## Each remodel keeps the original's node names (Relay_Lever, Relay_Indicator, Cache_Lid,
## Cache_Latch ...), pivots and outer bounds, so the existing motion, lamp and lid code drives it
## unchanged. Render-only: bodies, collision, targets and puzzle state are untouched.
## Off by default so the asset contract tests (which attach props without a settlement) keep the
## original GLBs. The ship settlement (ship_settlement_preview.gd) turns it on together with
## midstyle_swap.gd; that settlement is the world of the normal game start (raid/play_title.tscn,
## project main_scene since #9) and of the opt-in review entry, so raids launched from it use the remodels.
static var enabled := false
const DIR := "res://assets/midstyle_rollout/"
const RELAY := DIR + "relay_lever_weather_station.gltf"
const CACHE := {false: DIR + "loot_cache_woodland.gltf", true: DIR + "loot_cache_saltflat.gltf"}
const CARGO := {
	"container_intact": [DIR + "cargo_container_intact_olive.gltf", DIR + "cargo_container_intact_sand.gltf"],
	"container_dented": [DIR + "cargo_container_dented_olive.gltf", DIR + "cargo_container_dented_sand.gltf"],
	"stack_large": [DIR + "cargo_stack_large_olive.gltf", DIR + "cargo_stack_large_sand.gltf"],
	"stack_pallet": [DIR + "cargo_stack_pallet_olive.gltf", DIR + "cargo_stack_pallet_sand.gltf"],
}

## Returns the remodel when the rollout is on and the file imported, else the original scene.
static func pick(original: PackedScene, path: String) -> PackedScene:
	if not enabled or not ResourceLoader.exists(path): return original
	var packed := load(path) as PackedScene
	return packed if packed != null else original

static func relay(original: PackedScene) -> PackedScene: return pick(original, RELAY)
static func cache(original: PackedScene, saltflat: bool) -> PackedScene: return pick(original, CACHE[saltflat])
static func cargo(original: PackedScene, kind: String, sand: bool) -> PackedScene:
	return pick(original, CARGO[kind][int(sand)]) if CARGO.has(kind) else original
