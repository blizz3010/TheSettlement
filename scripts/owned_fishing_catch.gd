extends RefCounted
# Repeatable ordinary fish is separate from the invariant one-time quest fish.
const Inventory=preload('res://scripts/inventory_state.gd')
const Fishing=preload('res://scripts/fishing_state.gd')
const ITEM='river_fish'
static func can_cast(inventory,fishing)->bool:
 return inventory.amount('carried','fishing_pole')>0 and inventory.format_version>=9 and fishing.valid_inventory(inventory) and inventory.used('carried')<inventory.capacity('carried')
static func candidate(inventory,fishing)->Dictionary:
 if not can_cast(inventory,fishing):return {}
 # An active uncaught starter request still receives exactly its own quest fish.
 if fishing.status=='active' and not fishing.caught:return fishing.candidate('catch',inventory)
 var bag=Inventory.new();var progress=Fishing.new()
 if not bag.restore(inventory.data()) or not progress.restore(fishing.data()):return {}
 bag.carried[ITEM]=bag.amount('carried',ITEM)+1
 if not Inventory.new().restore(bag.data()) or not progress.valid_inventory(bag):return {}
 return {'inventory':bag,'fishing':progress}
