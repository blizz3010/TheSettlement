extends RefCounted
## Salt-basin plants and basalt, never woodland trees. No new imported assets.
func build(parent:Node3D,generator)->Dictionary:
	return preload("res://raid/scripts/biome_foliage.gd").new().build(parent,generator,"cinder")
