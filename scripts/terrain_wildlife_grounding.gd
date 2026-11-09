extends Node
## Runs after existing wildlife animation: retains its flutter offset and timing.
const Terrain=preload('res://scripts/settlement_terrain.gd')
func _ready():
 name='WildlifeTerrainGrounding'
 process_priority=100
 process_mode=Node.PROCESS_MODE_ALWAYS
func _process(_delta:float):
 var animals=get_parent().get_parent().get_node_or_null('AmbientWildlife')
 if animals==null:return
 for item in animals.animals:
  var animal:Node3D=item.root
  animal.position.y+=Terrain.height_at(animal.position.x,animal.position.z)-Terrain.BASE_Y
