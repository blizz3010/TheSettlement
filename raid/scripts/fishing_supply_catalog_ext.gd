extends RefCounted
## Item 16: Fishing Supplies stock. The pinned catalog only sells the pole.
## bait_portion is already a legal inventory id, so it can be bought without a schema change.
const Base = preload("res://scripts/fishing_supply_catalog.gd")
const ITEMS := {
	"fishing_pole": {"name": "Basic fishing pole", "price": 25, "note": "Carry it, assign it to quick access in Inventory, then select that slot before casting at the marked northern stream spot.", "max_quantity": 1, "space_per_unit": 1},
	"bait_portion": {"name": "Bait portion", "price": 4, "note": "A carried tin of bait. It is not required to cast in this build; catch rates are unchanged. One carried unit each.", "max_quantity": 8, "space_per_unit": 1},
}

static func definition() -> Dictionary:
	return {"shop_id": "fishing", "title": "FISHING SUPPLIES", "emblem": "⌁", "role": "Fishing gear · pole and bait", "tabs": ["buy"], "help": "Carry the pole, assign it to quick access in Inventory, then select its slot. Cast at the northern stream. Bait is optional in this build; ordinary fish and the one-time quest catch stay separate."}

static func row(id: String) -> Dictionary:
	return ITEMS.get(id, {}).duplicate(true)

static func rows(inventory, _action: String = "buy") -> Array:
	var result: Array = []
	for item in ITEMS:
		var spec: Dictionary = ITEMS[item]
		result.append({
			"id": item,
			"name": spec.name,
			"category": "Fishing",
			"description": spec.note,
			"price": int(spec.price),
			"owned": inventory.amount("carried", item),
			"enabled": true,
			"reason": "",
			"max_quantity": int(spec.max_quantity),
			"space_per_unit": int(spec.space_per_unit),
		})
	return result
