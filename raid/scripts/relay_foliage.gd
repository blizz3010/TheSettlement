extends RefCounted
## Woodland appearance; shared placement and collision contracts stay unchanged.
func build(parent:Node3D,generator)->Dictionary:
	return preload("res://raid/scripts/biome_foliage.gd").new().build(parent,generator,"relay")
