extends RefCounted
const Catalog=preload("res://scripts/psy_gear_catalog.gd")
const Inventory=preload("res://scripts/inventory_state.gd")
const Plot=preload("res://scripts/plot_state.gd")
const Request=preload("res://scripts/request_state.gd")
var last_error=""
func reject(message:String)->Dictionary:
 last_error=message;return {}
func quote_candidate(shop_id:String,action:String,item:String,quantity:int,plot,inventory,request,_context:Dictionary={})->Dictionary:
 last_error=""
 if shop_id!="psy" or quantity!=1 or action not in ["buy","sell"]:return reject("Choose one supported helmet transaction.")
 var p=Plot.new();var i=Inventory.new();var r=Request.new()
 if not p.restore(plot.data()) or not i.restore(inventory.data()) or not r.restore(request.data()):return reject("Current save state is invalid.")
 var price=Catalog.BUY_PRICE
 if action=="buy":
  if item!=Catalog.ITEM:return reject("This gear is preview only. Nothing purchased.")
  if i.used("carried")>=i.capacity("carried"):return reject("Bag full · make one carried space.")
  if p.credits<price:return reject("Not enough credits.")
  var number=1
  while i.equipment_owned.has("psy_helmet_"+str(number)):number+=1
  var id="psy_helmet_"+str(number)
  i.equipment_owned[id]={"id":id,"definition_id":Catalog.ITEM,"variant_id":"basic","dyes":{},"location":"carried"}
  p.credits-=price
 else:
  if not i.equipment_owned.has(item):return reject("That helmet is no longer carried.")
  var entry=i.equipment_owned[item]
  if entry.definition_id!=Catalog.ITEM or entry.location!="carried":return reject("Only unequipped carried basic helmets can be sold.")
  price=Catalog.SELL_PRICE
  if p.credits+price>100000:return reject("Credit limit reached. Nothing sold.")
  i.equipment_owned.erase(item);p.credits+=price
 i.format_version=maxi(i.format_version,10);i.reconcile_hotbar()
 if not Inventory.new().restore(i.data()) or not Plot.new().restore(p.data()):return reject("Equipment transaction failed validation.")
 return {"plot":p,"inventory":i,"request":r,"receipt":{"shop_id":"psy","action":action,"item":item,"name":"Basic helmet","quantity":1,"unit_price":price,"total":price,"balance_after":p.credits,"carried_after":i.used("carried"),"capacity":i.capacity("carried")}}
