extends RefCounted
# Pure all-or-nothing candidate. UI labels never set recipe inputs or prices.
const Catalog=preload('res://scripts/cooking_catalog.gd')
const Inventory=preload('res://scripts/inventory_state.gd')
const Plot=preload('res://scripts/plot_state.gd')
const Request=preload('res://scripts/request_state.gd')
var last_error=''
func candidate(shop_id:String,action:String,item:String,quantity:Variant,plot,inventory,request,_context:Dictionary={})->Dictionary:
 last_error=''
 if not quantity is int or quantity<1 or quantity>8:last_error='Choose a whole quantity from 1 to 8.';return {}
 var allowed=(shop_id=='cook_vendor' and action in ['buy','sell'] and item=='river_fish') or (shop_id=='cook_griddle' and action=='craft' and item==Catalog.STARTER)
 if not allowed:last_error='That cooking action is unavailable. No items or credits changed.';return {}
 var next_plot=Plot.new();var bag=Inventory.new();var next_request=Request.new()
 if not next_plot.restore(plot.data()) or not bag.restore(inventory.data()) or not next_request.restore(request.data()):last_error='Current save state is invalid.';return {}
 var unit_price=0
 if action=='buy':
  unit_price=Catalog.FISH_BUY
  if next_plot.credits<quantity*unit_price:last_error='Not enough settlement credits.';return {}
  if bag.used('carried')+quantity>bag.capacity('carried'):last_error='Bag full · make room for that quantity.';return {}
  next_plot.credits-=quantity*unit_price
  bag.carried['river_fish']=bag.amount('carried','river_fish')+quantity
  bag.format_version=maxi(9,bag.format_version)
 elif action=='sell':
  unit_price=Catalog.FISH_SELL
  if bag.amount('carried','river_fish')<quantity:last_error='Not enough carried ordinary river fish.';return {}
  if next_plot.credits>100000-quantity*unit_price:last_error='Credit limit reached.';return {}
  next_plot.credits+=quantity*unit_price
  take(bag,'river_fish',quantity)
 else:
  if not bag.knows_recipe(item):last_error='Recipe not learned.';return {}
  if bag.amount('carried','river_fish')<quantity:last_error='Needs carried ordinary river fish. Quest stream fish is protected.';return {}
  # Consume only on a detached candidate, then check the ENTIRE resulting bag.
  # A full bag can cook 1->1 without demanding a temporary extra carried slot.
  take(bag,'river_fish',quantity)
  bag.carried[Catalog.OUTPUT]=bag.amount('carried',Catalog.OUTPUT)+quantity
  bag.format_version=10
 if bag.used('carried')>bag.capacity('carried'):last_error='There is no room for the complete result. Nothing consumed.';return {}
 bag.reconcile_hotbar()
 if not Inventory.new().restore(bag.data()) or not Plot.new().restore(next_plot.data()) or not Request.new().restore(next_request.data()):last_error='Cooking transaction validation failed.';return {}
 return {'plot':next_plot,'inventory':bag,'request':next_request,'receipt':{'shop_id':shop_id,'action':action,'item':item,'quantity':quantity,'unit_price':unit_price,'total':quantity*unit_price,'balance_after':next_plot.credits,'carried_after':bag.used('carried'),'capacity':bag.capacity('carried')}}
static func take(bag,item:String,quantity:int):
 bag.carried[item]-=quantity
 if bag.carried[item]==0:bag.carried.erase(item)
