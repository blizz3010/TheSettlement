extends RefCounted
const Catalog=preload("res://scripts/tailor_catalog.gd")
const Inventory=preload("res://scripts/inventory_state.gd")
const Plot=preload("res://scripts/plot_state.gd")
const Request=preload("res://scripts/request_state.gd")
var last_error=""
func reject(reason:String)->Dictionary:
 last_error=reason;return {}
func unique_id(inventory,definition:String)->String:
 var suffix=1
 while inventory.equipment_owned.has("tailor_"+definition+"_"+str(suffix)):suffix+=1
 return "tailor_"+definition+"_"+str(suffix)
func add_garment(inventory,definition:String):
 var id=unique_id(inventory,definition)
 inventory.equipment_owned[id]={"id":id,"definition_id":definition,"variant_id":"basic","dyes":{},"location":"carried"}
func quote_candidate(shop_id:String,action:String,item:String,quantity:int,plot,inventory,request,_context:Dictionary={})->Dictionary:
 last_error=""
 if shop_id!="tailor" or action not in ["buy","sell","craft"] or quantity<1 or quantity>99:return reject("Choose a valid tailoring transaction.")
 var next_plot=Plot.new();var next_inventory=Inventory.new();var next_request=Request.new()
 if not next_plot.restore(plot.data()) or not next_inventory.restore(inventory.data()) or not next_request.restore(request.data()):return reject("Current save state is invalid. Nothing changed.")
 var price=0;var title=Catalog.NAMES.get(item,"")
 if action=="craft":
  if not Catalog.PATTERNS.has(item) or quantity!=1:return reject("Choose one supported garment recipe.")
  if not inventory.knows_recipe(item):return reject("Learn this pattern in Shop first.")
  var recipe=Catalog.PATTERNS[item]
  if inventory.amount("carried","cloth_linen")<recipe.cloth or inventory.amount("carried","thread_spool")<1:return reject("Missing carried linen cloth or thread spool.")
  next_inventory.carried["cloth_linen"]-=recipe.cloth
  next_inventory.carried["thread_spool"]-=1
  if next_inventory.carried["cloth_linen"]==0:next_inventory.carried.erase("cloth_linen")
  if next_inventory.carried["thread_spool"]==0:next_inventory.carried.erase("thread_spool")
  add_garment(next_inventory,recipe.output)
  title=Catalog.NAMES[recipe.output]
 elif action=="sell":
  if not Catalog.MATERIALS.has(item):return reject("Only carried linen cloth and thread are accepted. Clothing is protected from sale.")
  if inventory.amount("carried",item)<quantity:return reject("Not enough carried material. Nothing sold.")
  price=1;next_plot.credits+=quantity
  next_inventory.carried[item]-=quantity
  if next_inventory.carried[item]==0:next_inventory.carried.erase(item)
 elif Catalog.GARMENTS.has(item):
  price=Catalog.GARMENTS[item]
  for i in quantity:add_garment(next_inventory,item)
 elif Catalog.MATERIALS.has(item):
  price=Catalog.MATERIALS[item]
  next_inventory.carried[item]=inventory.amount("carried",item)+quantity
 elif Catalog.PATTERNS.has(item):
  if quantity!=1:return reject("Learn one pattern at a time.")
  if inventory.knows_recipe(item):return reject("Already learned. No duplicate charge.")
  price=Catalog.PATTERNS[item].price;next_inventory.recipe_unlocks.append(item)
 else:return reject("This item is preview only. Nothing purchased.")
 if action=="buy":next_plot.credits-=price*quantity
 if next_plot.credits<0:return reject("Not enough settlement credits.")
 if next_plot.credits>100000:return reject("Credit limit reached. Nothing sold.")
 if next_inventory.used("carried")>next_inventory.capacity("carried"):return reject("Carried inventory is full. Make room before confirming.")
 next_inventory.format_version=maxi(next_inventory.format_version,10)
 next_inventory.reconcile_hotbar()
 if not Plot.new().restore(next_plot.data()) or not Inventory.new().restore(next_inventory.data()):return reject("Tailoring transaction failed validation. Nothing changed.")
 return {"plot":next_plot,"inventory":next_inventory,"request":next_request,"receipt":{"shop_id":"tailor","action":action,"item":item,"name":title,"quantity":quantity,"unit_price":price,"total":price*quantity,"balance_after":next_plot.credits,"carried_after":next_inventory.used("carried"),"capacity":next_inventory.capacity("carried")}}
