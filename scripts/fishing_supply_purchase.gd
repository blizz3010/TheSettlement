extends RefCounted
# Pure candidate builder. Never writes files or publishes live state.
const Catalog=preload('res://scripts/fishing_supply_catalog.gd')
const Plot=preload('res://scripts/plot_state.gd')
const Inventory=preload('res://scripts/inventory_state.gd')
var last_error=''
func candidate(item:String,plot,inventory)->Dictionary:
 last_error=''
 var row=Catalog.row(item)
 if row.is_empty():last_error='Choose a listed fishing supply.';return {}
 var next_plot=Plot.new();var next_inventory=Inventory.new()
 if not next_plot.restore(plot.data()) or not next_inventory.restore(inventory.data()):last_error='Invalid current state. Nothing purchased.';return {}
 if next_plot.credits<row.price:last_error='Not enough credits. Nothing purchased.';return {}
 if next_inventory.used('carried')>=next_inventory.capacity('carried'):last_error='Carried inventory is full. Nothing purchased.';return {}
 next_inventory.format_version=maxi(next_inventory.format_version,9)
 next_plot.credits-=row.price
 next_inventory.carried[item]=next_inventory.amount('carried',item)+1
 next_inventory.reconcile_hotbar()
 if not Plot.new().restore(next_plot.data()) or not Inventory.new().restore(next_inventory.data()):last_error='Purchase validation failed.';return {}
 return {'plot':next_plot,'inventory':next_inventory,'item':item,'price':row.price}
