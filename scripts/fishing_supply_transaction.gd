extends RefCounted
# Pending purchase intent only. Host must supply live access and atomic whole-save writer.
const Purchase=preload('res://scripts/fishing_supply_purchase.gd')
var serial=0
var pending={}
var last_error=''
func select(item:String,plot,inventory)->int:
 last_error=''
 if not pending.is_empty():last_error='Review or cancel the current selection.';return 0
 var purchase=Purchase.new();var next=purchase.candidate(item,plot,inventory)
 if next.is_empty():last_error=purchase.last_error;return 0
 serial+=1;pending={'token':serial,'item':item,'plot':plot.data().duplicate(true),'inventory':inventory.data().duplicate(true)}
 return serial
func cancel():pending={}
func confirm(token:int,plot,inventory,access:Callable,writer:Callable)->Dictionary:
 last_error=''
 var intent=pending;pending={} # Consume before access, validation or write; replay never trades.
 if intent.is_empty() or token!=intent.token:last_error='Selection is no longer current.';return {}
 if not access.is_valid() or not bool(access.call()):last_error='Move back to the fishing trader.';return {}
 if plot.data()!=intent.plot or inventory.data()!=intent.inventory:last_error='Your inventory or balance changed. Review again.';return {}
 var purchase=Purchase.new();var next=purchase.candidate(intent.item,plot,inventory)
 if next.is_empty():last_error=purchase.last_error;return {}
 if not writer.is_valid() or not bool(writer.call(next.plot,next.inventory)):last_error='Purchase was not saved. Nothing granted.';return {}
 return next # Only the caller publishes this successfully saved candidate.
