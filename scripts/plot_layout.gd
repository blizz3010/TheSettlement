extends RefCounted
# Authored translation only. Saved cell coordinates NEVER change when world layout changes.
const LEGACY_ORIGIN=Vector3(-16,0,-4)
const ORIGIN=Vector3(-26,3,13)
const STASH=Vector3(-14.5,3,20.8)
const STASH_YAW=0.0 # Authored front-porch facing; never serialized as a moved plot coordinate.
const BUILD_PLANE_Y=3.08
static func to_world(local:Vector3)->Vector3:return ORIGIN+local
static func to_local(world:Vector3)->Vector3:return world-ORIGIN
static func cell(cell:Vector2i)->Vector3:return to_world(Vector3(cell.x*2+1,.08,cell.y*2+1))

static func contains_home_position(world:Vector3,expanded:bool)->bool:
	# Same horizontal bounds as the marked8m/12m home plot. Ground/upper levels share it.
	if not world.is_finite():return false
	var local=to_local(world);var maximum=8.0 if expanded else 4.0
	return local.x>=-4.0 and local.z>=-4.0 and local.x<=maximum and local.z<=maximum
