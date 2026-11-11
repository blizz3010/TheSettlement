extends RefCounted
## Lightweight, non-colliding paint and local signs. No changes to model/state.
const PUBLIC=Color("8bc8cd")
const VAULT=Color("efcb86")
const EXIT=Color("b0d5ac")

static func location_hint(point:Vector3)->String:
	# Do not report an indoor floor across the forecourt or exterior stairs.
	if absf(point.x)>16.0 or point.z < -14.0 or point.z>15.5 or point.y<-.3 or point.y>9.2:return ""
	if absf(point.y)<.6:return "Level 1 / public hall"
	if absf(point.y-4.5)<.6:return "Level 2 / gallery"
	if absf(point.y-8.5)<.6:return "Level 3 / vault access"
	return "Stairs / between levels"

func build(world:Node3D,root:Node3D):
	var signs=Node3D.new();signs.name="ArchiveWayfinding";root.add_child(signs)
	_sign(world,signs,"LEVEL 1 / PUBLIC HALL\nVAULT: USE EAST STAIRS",Vector3(0,2.8,6.5),PUBLIC)
	_sign(world,signs,"EAST STAIRS / B\nLEVELS 2 + 3",Vector3(9.15,2.7,2.6),VAULT)
	_sign(world,signs,"LEVEL 1 / MAIN EXIT\nSOUTH THROUGH PUBLIC HALL",Vector3(10.8,2.7,-5.9),EXIT)
	_sign(world,signs,"LEVEL 2 / GALLERY\nVAULT: CONTINUE UP STAIRS B",Vector3(10.8,7.0,-5.9),PUBLIC)
	_sign(world,signs,"LEVEL 3 / VAULT\nLEAVE STAIRS TO THE NORTH",Vector3(10.8,11.0,-5.9),VAULT)
	_sign(world,signs,"VAULT ACCESS / WEST\nKEYCARD REQUIRED",Vector3(12.8,10.7,-7.65),VAULT)
	_sign(world,signs,"RETURN: EAST STAIRS B\nMAIN EXIT ON LEVEL 1",Vector3(3.5,10.7,-7.5),EXIT)
	# Flat arrows stay on verified horizontal landings and hall corridors.
	# No paint is laid across steps, railings, shelves or the locked threshold.
	for data in [
		[Vector3(0,.045,2.6),Vector2.RIGHT,VAULT],
		[Vector3(8.9,.045,2.6),Vector2.UP,VAULT],
		[Vector3(10.8,.125,-5.9),Vector2.RIGHT,VAULT],
		[Vector3(10.8,4.625,-5.9),Vector2.RIGHT,VAULT],
		[Vector3(13,8.625,-6.65),Vector2.UP,VAULT],
		[Vector3(11.5,8.545,-7.55),Vector2.LEFT,VAULT],
		[Vector3(3.5,8.545,-7.5),Vector2.RIGHT,EXIT],
		[Vector3(9.15,.045,1.3),Vector2.DOWN,EXIT],
		[Vector3(0,.045,7.5),Vector2.DOWN,EXIT]]:
		_arrow(world,signs,data[0],data[1],data[2])

func _sign(world:Node3D,parent:Node3D,text:String,at:Vector3,color:Color):
	world._label(parent,text,at,color,17)
	var label=parent.get_child(parent.get_child_count()-1) as Label3D
	label.name="LocalSign"
	label.visibility_range_end=18.0
	label.no_depth_test=false

func _arrow(world:Node3D,parent:Node3D,at:Vector3,direction:Vector2,color:Color):
	var arrow=Node3D.new();arrow.name="FloorArrow%d"%parent.get_child_count();arrow.position=at;arrow.rotation.y=-atan2(direction.y,direction.x);parent.add_child(arrow)
	# Local +X is the arrow's heading. Two short strokes make a chevron.
	for angle in [-PI/4.0,PI/4.0]:
		var stroke=world._box(arrow,Vector3(-.18,0,signf(angle)*.18),Vector3(.52,.012,.10),color,false)
		stroke.rotation.y=angle
