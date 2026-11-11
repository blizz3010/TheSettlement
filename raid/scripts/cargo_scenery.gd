extends RefCounted
## Closed visual scenery only. Bodies retain their authored simple solid boxes.
## +Z is the sealed door/front direction, and all source meshes are ground-centred.
const MODELS={
	"container_intact":[preload("res://raid/assets/cargo/cargo_container_intact_olive.glb"),preload("res://raid/assets/cargo/cargo_container_intact_sand.glb")],
	"container_dented":[preload("res://raid/assets/cargo/cargo_container_dented_olive.glb"),preload("res://raid/assets/cargo/cargo_container_dented_sand.glb")],
	"stack_large":[preload("res://raid/assets/cargo/cargo_stack_large_olive.glb"),preload("res://raid/assets/cargo/cargo_stack_large_sand.glb")],
	"stack_pallet":[preload("res://raid/assets/cargo/cargo_stack_pallet_olive.glb"),preload("res://raid/assets/cargo/cargo_stack_pallet_sand.glb")],
}
const SIZES={"container_intact":Vector3(3.5,2.4,5.0),"container_dented":Vector3(3.5,2.4,5.0),"stack_large":Vector3(2.2,2.2,2.8),"stack_pallet":Vector3(1.6,1.5,2.3)}
static func attach(body:Node3D,kind:String,sand:bool)->Node3D:
	var art=MODELS[kind][int(sand)].instantiate()
	art.name="CargoArt";art.position.y=-SIZES[kind].y*0.5
	art.set_meta("cargo_kind",kind);art.set_meta("sand_variant",sand)
	body.add_child(art)
	return art
