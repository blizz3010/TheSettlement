extends RefCounted
# Source-owned catalogue. Never infer prices or eligibility from UI labels.
const VERSION = 1
const PRICES = {"timber":10,"stone":8,"metal":15}
const SELL_PRICES = {"timber":5,"stone":4,"metal":7}
const NAMES = {"timber":"Timber","stone":"Stone","metal":"Metal scrap"}
const STOCK = ["timber","stone","metal","crafting_guide","pickaxe_preview","scythe_preview","building_plans_preview"]
static func definition() -> Dictionary:
	return {"version":VERSION,"shop_id":"rook","title":"ROOK'S SUPPLIES","emblem":"⚒","role":"Materials for your home and workbench","tabs":["buy","sell"],"stock_ids":STOCK.duplicate(),"allowed_sell_categories":["Materials"],"sale_scope":"carried","help":"Buy materials or sell carried timber, stone and metal scrap."}
static func row(item:String, action:String, inventory) -> Dictionary:
	if not action in ["buy","sell"]:return {}
	if PRICES.has(item):
		var notes={"timber":"Workbench: 2 timber + 1 metal scrap. Lantern kit: 1 timber + 1 metal scrap at a workbench.","stone":"A raw building material. Structural building remains free in this playtest; buying stone is optional.","metal":"Use with timber to build your workbench and craft a lantern kit. Existing crafting knowledge is free."}
		return {"id":item,"name":NAMES[item],"category":"Materials","description":notes[item],"price":SELL_PRICES[item] if action=="sell" else PRICES[item],"owned":inventory.amount("carried",item),"enabled":true,"reason":"","icon":"res://assets/ui/inventory_"+item+".svg"}
	if action=="sell":return {}
	if item=="crafting_guide":return {"id":item,"name":"Free crafting guide","category":"Knowledge","description":"Already known, no purchase needed. Build a workbench at home with 2 carried timber + 1 metal scrap. At the bench, use 1 timber + 1 metal scrap to make a lantern kit. Structural pieces stay free.","price":null,"owned":0,"enabled":false,"reason":"Already known · read the guide here"}
	var names={"pickaxe_preview":"Pickaxe","scythe_preview":"Scythe","building_plans_preview":"Supply crate plan"}
	if not names.has(item):return {}
	var note="Preview only · tool use coming later"
	var description="A future gathering tool. Tool selection and gathering use are not implemented; this display cannot be purchased."
	if item=="scythe_preview":description="Requested long-handled gathering tool. The existing Harvest Sickle is a display, not a purchasable scythe. Tool selection and use must work before either is sold."
	if item=="building_plans_preview":note="Preview only · no new build outputs yet";description="Supply crate plan preview. No supply-crate container or build result is implemented, so this plan cannot be purchased. Existing building and lantern knowledge remain free."
	return {"id":item,"name":names[item],"category":"Plans" if item=="building_plans_preview" else "Tools","description":description,"price":null,"owned":0,"enabled":false,"reason":note}
static func rows(action:String,inventory) -> Array:
	var result:Array=[]
	for item in STOCK:
		var entry=row(item,action,inventory)
		if not entry.is_empty() and (action!="sell" or int(entry.owned)>0):result.append(entry)
	return result
static func sale_reason(item:String,inventory) -> String:
	if PRICES.has(item):return "" if inventory.amount("carried",item)>0 else "No carried units. Stash and Lockbox are never sold."
	if item=="stream_fish":return "Quest catch is protected."
	if inventory.equipment_owned.has(item):return "Clothing and equipment resale is unavailable; owned instances stay protected."
	return "Rook accepts only carried timber, stone and metal scrap."
