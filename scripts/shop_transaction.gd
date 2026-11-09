extends RefCounted
# Session-only authority. UI receives a receipt, never candidate ownership.
# A configured builder is trusted service code, never input from an item row.
const Supplies = preload("res://scripts/supplies_purchase.gd")
var last_error := ""
var serial:int=0
var _pending:Dictionary={}
var _builder:Callable
var _supplies=Supplies.new()
var _committing:=false
func _init(candidate_builder:Callable=Callable()):
	_builder=candidate_builder if candidate_builder.is_valid() else _supplies.quote_candidate
func pending_quote() -> Dictionary:
	if _pending.is_empty():return {}
	var receipt:Dictionary=_pending.receipt.duplicate(true)
	receipt["token"]=_pending.token
	return receipt
func cancel() -> void:
	_pending={}
func source_snapshot(plot,inventory,request,context:Dictionary={}) -> Dictionary:
	return {"plot":plot.data().duplicate(true),"inventory":inventory.data().duplicate(true),"request":request.data().duplicate(true),"context":context.duplicate(true)}
func current(plot,inventory,request,context:Dictionary={}) -> bool:
	return not _pending.is_empty() and _pending.source==source_snapshot(plot,inventory,request,context)
func select(shop_id:String,action:String,item:String,quantity:Variant,plot,inventory,request,context:Dictionary={}) -> Dictionary:
	last_error=""
	if _committing or not _pending.is_empty():last_error="Review or cancel the current selection.";return {}
	if not quantity is int or quantity<1 or quantity>100000:last_error="Choose a positive whole quantity.";return {}
	if not _builder.is_valid():last_error="This service is unavailable.";return {}
	var before=source_snapshot(plot,inventory,request,context)
	var candidate=_builder.call(shop_id,action,item,quantity,plot,inventory,request,context)
	if not valid_candidate(candidate,shop_id,action,item,quantity):
		last_error=_supplies.last_error if not _supplies.last_error.is_empty() else "This item or quantity is unavailable. Nothing traded."
		return {}
	if before!=source_snapshot(plot,inventory,request,context):last_error="State changed while reviewing. Try again.";return {}
	serial+=1
	_pending={"token":serial,"source":before,"receipt":candidate.receipt.duplicate(true)}
	return pending_quote()
func valid_candidate(candidate:Variant,shop_id:String,action:String,item:String,quantity:int) -> bool:
	if not candidate is Dictionary or not candidate.get("receipt") is Dictionary:return false
	for key in ["plot","inventory","request"]:
		if not candidate.has(key) or candidate[key]==null or not candidate[key].has_method("data"):return false
	var r:Dictionary=candidate.receipt
	if r.get("shop_id")!=shop_id or r.get("action")!=action or r.get("item")!=item or r.get("quantity")!=quantity:return false
	for key in ["unit_price","total","balance_after","carried_after","capacity"]:
		if not r.get(key) is int or r[key]<0:return false
	if r.total!=r.unit_price*quantity or r.balance_after>100000 or r.carried_after>r.capacity:return false
	return r.balance_after==candidate.plot.credits and r.carried_after==candidate.inventory.used("carried") and r.capacity==candidate.inventory.capacity("carried")
func confirm(token:Variant,plot,inventory,request,access:Callable,writer:Callable,context:Dictionary={}) -> Dictionary:
	last_error=""
	if _committing:last_error="Trade is already being saved.";return {}
	var intent:Dictionary=_pending
	_pending={} # Consume before any external callback. Replays and failed saves cannot grant.
	if intent.is_empty() or not token is int or token!=intent.token:last_error="Selection is no longer current.";return {}
	_committing=true
	var next:Dictionary=_commit(intent,plot,inventory,request,access,writer,context)
	_committing=false
	return next
func _commit(intent:Dictionary,plot,inventory,request,access:Callable,writer:Callable,context:Dictionary) -> Dictionary:
	if not access.is_valid() or access.call()!=true:last_error="Move back to the active shop. Nothing traded.";return {}
	if intent.source!=source_snapshot(plot,inventory,request,context):last_error="Your inventory, balance or progress changed. Review again.";return {}
	if not _builder.is_valid():last_error="This service is unavailable.";return {}
	var r:Dictionary=intent.receipt
	var candidate=_builder.call(r.shop_id,r.action,r.item,r.quantity,plot,inventory,request,context)
	if not valid_candidate(candidate,r.shop_id,r.action,r.item,r.quantity) or candidate.receipt!=r:last_error="Availability or price changed. Review again.";return {}
	# Recheck after candidate work: callbacks may observe mutable access/state.
	if not access.is_valid() or access.call()!=true or intent.source!=source_snapshot(plot,inventory,request,context):last_error="Shop access or state changed. Nothing traded.";return {}
	if not writer.is_valid() or writer.call(candidate)!=true:last_error="Trade was not saved. Nothing traded.";return {}
	return candidate # The host publishes only this successfully persisted complete candidate.
