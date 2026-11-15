extends RefCounted
## Pending purchase intent for pole and bait. Same surface as the pinned transaction, plus quantity.
const Purchase = preload("res://raid/scripts/fishing_supply_purchase_ext.gd")
var serial := 0
var pending := {}
var last_error := ""

func select(item: String, plot, inventory, quantity: int = 1) -> int:
	last_error = ""
	if not pending.is_empty():
		last_error = "Review or cancel the current selection."
		return 0
	var purchase := Purchase.new()
	var next: Dictionary = purchase.candidate(item, plot, inventory, quantity)
	if next.is_empty():
		last_error = purchase.last_error
		return 0
	serial += 1
	pending = {
		"token": serial,
		"item": item,
		"quantity": quantity,
		"plot": plot.data().duplicate(true),
		"inventory": inventory.data().duplicate(true),
		"receipt": next.receipt.duplicate(true),
	}
	return serial

func cancel() -> void:
	pending = {}

func confirm(token: int, plot, inventory, access: Callable, writer: Callable) -> Dictionary:
	last_error = ""
	var intent: Dictionary = pending
	pending = {}
	if intent.is_empty() or token != intent.token:
		last_error = "Selection is no longer current."
		return {}
	if not access.is_valid() or not bool(access.call()):
		last_error = "Move back to the fishing trader."
		return {}
	if plot.data() != intent.plot or inventory.data() != intent.inventory:
		last_error = "Your inventory or balance changed. Review again."
		return {}
	var purchase := Purchase.new()
	var next: Dictionary = purchase.candidate(intent.item, plot, inventory, int(intent.quantity))
	if next.is_empty():
		last_error = purchase.last_error
		return {}
	# The pinned controller's writer is func(plot, inventory) -> bool.
	if not writer.is_valid() or not bool(writer.call(next.plot, next.inventory)):
		last_error = "Purchase was not saved. Nothing granted."
		return {}
	return next
