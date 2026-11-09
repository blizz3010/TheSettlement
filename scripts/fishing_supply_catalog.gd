extends RefCounted
# Temporary basic-pole price. No inert bait stock is offered.
const ITEMS={
 'fishing_pole':{'name':'Basic fishing pole','price':25,'note':'Carry it, assign it to quick access in Inventory, then select that slot before casting at the marked northern stream spot.'}
}
static func row(id:String)->Dictionary:return ITEMS.get(id,{}).duplicate(true)
