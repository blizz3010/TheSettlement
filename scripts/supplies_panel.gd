extends "res://scripts/shop_panel.gd"
# Thin Rook adapter; other professions reuse ShopPanel with their own definitions.
const Catalog=preload("res://scripts/shop_catalog.gd")
var selling:=false
func _ready():
	shop_definition=Catalog.definition()
	super._ready()
	name="SuppliesPanel"
func render(plot,inventory,_pending:String="",message:String="",pending_quote:Dictionary={}):
	action="sell" if selling else "buy"
	for key in tab_buttons:tab_buttons[key].button_pressed=key==action
	render_state(plot,inventory,Catalog.rows(action,inventory),pending_quote,message)
