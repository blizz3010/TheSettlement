extends RefCounted
# Rook's source-owned prices and validated candidate model. No live mutations.
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Request = preload("res://scripts/request_state.gd")
const Catalog = preload("res://scripts/shop_catalog.gd")
const PRICES = Catalog.PRICES
const SELL_PRICES = Catalog.SELL_PRICES
const NAMES = Catalog.NAMES
var last_error := ""
func fail(reason:String) -> Dictionary:
	last_error=reason
	return {}
func candidate(item:String,plot,inventory,request,selling:=false,quantity:Variant=1) -> Dictionary:
	return quote_candidate("rook","sell" if selling else "buy",item,quantity,plot,inventory,request,{})
func quote_candidate(shop_id:String,action:String,item:String,quantity:Variant,plot,inventory,request,_context:Dictionary={}) -> Dictionary:
	last_error=""
	if shop_id!="rook" or not action in ["buy","sell"]:return fail("Choose Rook's Buy or Sell service.")
	if not quantity is int or quantity<1 or quantity>Inventory.CAPACITIES.carried:return fail("Choose a whole quantity from 1 to 8.")
	if not PRICES.has(item):return fail(Catalog.sale_reason(item,inventory) if action=="sell" else "This preview cannot be purchased.")
	var p=Plot.new();var i=Inventory.new();var r=Request.new()
	if not p.restore(plot.data()) or not i.restore(inventory.data()) or not r.restore(request.data()):return fail("Current save state is invalid. Nothing traded.")
	var selling=action=="sell"
	var price:int=SELL_PRICES[item] if selling else PRICES[item]
	var total:int=price*quantity
	if selling:
		if i.amount("carried",item)<quantity:return fail("Not enough carried units. Stash and Lockbox are never sold.")
		if p.credits>100000-total:return fail("Credit limit reached. Nothing sold.")
		p.credits+=total;i.carried[item]-=quantity
		if i.carried[item]==0:i.carried.erase(item)
	else:
		if p.credits<total:return fail("Not enough settlement credits. Nothing purchased.")
		if quantity>i.capacity("carried")-i.used("carried"):return fail("Bag full · make %d carried space." % (quantity-(i.capacity("carried")-i.used("carried"))))
		p.credits-=total;i.carried[item]=i.amount("carried",item)+quantity
	i.reconcile_hotbar()
	if not Plot.new().restore(p.data()) or not Inventory.new().restore(i.data()) or not Request.new().restore(r.data()):return fail("Trade validation failed. Nothing traded.")
	return {"plot":p,"inventory":i,"request":r,"receipt":{"catalogue_version":Catalog.VERSION,"shop_id":"rook","action":action,"item":item,"name":NAMES[item],"quantity":quantity,"unit_price":price,"total":total,"balance_after":p.credits,"carried_after":i.used("carried"),"capacity":i.capacity("carried")}}
