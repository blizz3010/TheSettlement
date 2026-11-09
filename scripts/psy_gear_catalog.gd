extends RefCounted
# First real equipment slice: cosmetic only. Prices are prototype shop values.
const ITEM="helmet_basic"
const BUY_PRICE=24
const SELL_PRICE=12
static func definition()->Dictionary:
 return {"shop_id":"psy","title":"PSY · GEAR & ARMOR","emblem":"◇","role":"Basic helmet available · Other gear coming later","tabs":["buy","sell"],"help":"Buy a cosmetic helmet, equip it in Inventory, or sell an unequipped carried helmet. No protection or extra capacity.","sale_help":"Only unequipped carried basic helmets are accepted. Worn gear, other equipment, Stash and Lockbox are protected."}
static func rows(inventory,action:String)->Array:
 var result:Array=[]
 if action=="sell":
  for id in inventory.equipment_owned:
   var entry=inventory.equipment_owned[id]
   if entry.definition_id==ITEM and entry.location=="carried":
    result.append({"id":id,"icon_item":ITEM,"name":"Basic helmet · "+id,"category":"Carried helmets","description":"Sell this exact carried helmet for 12 credits. Equipped and stored helmets are not eligible.","price":SELL_PRICE,"owned":1,"enabled":true,"max_quantity":1,"space_per_unit":1,"reason":""})
  return result
 var count=0
 for entry in inventory.equipment_owned.values():
  if entry.definition_id==ITEM and entry.location=="carried":count+=1
 result.append({"id":ITEM,"name":"Basic helmet","category":"Available gear","description":"Cosmetic visor helmet matching Psy's counter display. Buy, carry, equip in Inventory and save. One carried unit when unequipped. No armor, damage reduction, visor function or capacity bonus. Resale: 12 credits, carried and unequipped only.","price":BUY_PRICE,"owned":count,"enabled":true,"max_quantity":1,"space_per_unit":1,"reason":""})
 for row in preload("res://scripts/trader_preview_catalog.gd").rows("psy","gear"):
  if row.id!=ITEM:result.append(row)
 return result
