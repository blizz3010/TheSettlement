extends "res://scripts/shop_panel.gd"
# The shared shell displays the specialist transaction's receipt; it never commits.
const Catalog=preload("res://scripts/fishing_supply_catalog.gd")
signal selected(item:String)
func _ready():
 super._ready()
 name="FishingSupplyPanel"
 configure({"shop_id":"fishing","title":"FISHING SUPPLIES","emblem":"⌁","role":"Fishing pole · 25 credits · no bait required","tabs":["buy"],"help":"Carry the pole, assign it to quick access in Inventory, then select its slot. Cast at the northern stream. Ordinary fish and the one-time quest catch stay separate."})
 review_requested.connect(_review_pole)
func _review_pole(item:String,count:int,mode:String):
 if mode=="buy" and count==1 and not Catalog.row(item).is_empty():selected.emit(item)
func render(plot,inventory,pending:String,message:String=""):
 var offered=[]
 for item in Catalog.ITEMS:
  var row=Catalog.row(item)
  offered.append({"id":item,"name":row.name,"category":"Fishing","description":"Carry this pole, assign it to quick access in Inventory and select its slot before casting at the northern stream. No bait is needed.\n\nThe first purchase preserves a backup of your earlier save. Quest catch progress stays separate from ordinary river fish.","price":int(row.price),"owned":inventory.amount("carried",item),"enabled":true,"reason":"","max_quantity":1})
 var receipt={};var row=Catalog.row(pending)
 if not row.is_empty():receipt={"token":0,"shop_id":"fishing","action":"buy","item":pending,"name":row.name,"quantity":1,"unit_price":row.price,"total":row.price,"balance_after":plot.credits-row.price,"carried_after":inventory.used("carried")+1,"capacity":inventory.capacity("carried")}
 render_state(plot,inventory,offered,receipt,message)
