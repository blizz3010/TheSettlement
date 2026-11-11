extends RefCounted
## Pure transition contract: no scene, save format, reward or profile mutation.
var busy := false
var binding: Dictionary = {}

func begin(world) -> bool:
	if busy or not world.ship_can_embark(): return false
	busy = true
	if not world.save_game(false):
		busy = false
		return false
	binding = {"slot": str(world._character_slot), "appearance": world.character_appearance.duplicate(true)}
	return true

static func in_zone(local_position: Vector3) -> bool:
	return Vector2(local_position.x, local_position.z - 4.8).length() <= 1.7 and absf(local_position.y - 1.28) <= 0.65
