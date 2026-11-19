extends RefCounted
## Queue item 4 (b), visual-pass 39/45: the Town Hall door corner wedge. Placeholder until the
## threshold geometry is measured in the before shots.
const NAME := "HallThresholdFinish"
static func install(world: Node3D) -> Dictionary:
	if world.has_node(NAME): world.get_node(NAME).free()
	return {"ok": true, "pieces": 0}
