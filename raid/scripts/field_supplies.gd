extends RefCounted
## Visual-only, exact-scale field supplies. Credentials and text stay in raid_state.
const STANDS=[preload("res://raid/assets/field_supplies/supply_stand_woodland.glb"),preload("res://raid/assets/field_supplies/supply_stand_saltflat.glb")]
const PICKUPS={
	"key":[preload("res://raid/assets/field_supplies/maintenance_key_woodland.glb"),preload("res://raid/assets/field_supplies/maintenance_key_saltflat.glb")],
	"keycard":[preload("res://raid/assets/field_supplies/access_card_woodland.glb"),preload("res://raid/assets/field_supplies/access_card_saltflat.glb")],
	"code":[preload("res://raid/assets/field_supplies/clipboard_woodland.glb"),preload("res://raid/assets/field_supplies/clipboard_saltflat.glb")],
	"puzzle":[preload("res://raid/assets/field_supplies/maintenance_logbook_woodland.glb"),preload("res://raid/assets/field_supplies/maintenance_logbook_saltflat.glb")],
}
const DECK_HEIGHT:=0.792
const STAND_GROUND:=0.03
const PICKUP_CENTRE:=0.9

static func attach_stand(body:Node3D,saltflat:bool)->Node3D:
	var art=STANDS[int(saltflat)].instantiate()
	art.name="SupplyStandArt";art.position.y=-0.4;body.add_child(art)
	return art

static func attach_pickup(body:Node3D,kind:String,saltflat:bool)->Node3D:
	var art=PICKUPS[kind][int(saltflat)].instantiate()
	art.name="FieldSupplyArt"
	# Stand foot follows the existing collider bottom; pickups touch the inset
	# deck, not the 8 mm higher rim. No rotation or scale correction is required.
	art.position.y=STAND_GROUND+DECK_HEIGHT-PICKUP_CENTRE
	body.add_child(art);body.set_meta("supply_kind",kind)
	return art

static func collect(body:Node3D):
	if body.get_meta("collected",false):return
	body.set_meta("collected",true)
	body.hide()
	# Hiding also excludes this target from _nearest_target immediately. Defer
	# shape removal safely when called from the production input/physics loop.
	for shape in body.find_children("*","CollisionShape3D",true,false):
		shape.set_deferred("disabled",true)
