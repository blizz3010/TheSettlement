extends RefCounted
# Deliberately station-local TEST data, not Inventory, Craft1 or saved gameplay.
const PANTRY_COUNT=4
const TRAY_LIMIT=4
var pantry:Dictionary={"test_fish_portion":PANTRY_COUNT,"test_flora_portion":PANTRY_COUNT}
var tray:Dictionary={"test_glade_fillet":0,"test_ember_leaf":0}
var pending:Dictionary={}
var revision:int=0
var disposed:bool=false
var last_error:String=""
static func recipes() -> Dictionary:
	return {
		"glade_fillet":{"name":"Pan-Seared Glade Fillet","input":"test_fish_portion","output":"test_glade_fillet","steps":["Sear test fish","Turn test fillet","Finish sample"],"detail":"Sear one TEST fish portion, turn it, then finish a browned fillet inspection sample."},
		"ember_leaf":{"name":"Toasted Ember Leaf","input":"test_flora_portion","output":"test_ember_leaf","steps":["Spread test flora","Toast test leaves","Finish sample"],"detail":"Spread one TEST flora portion, toast it, then finish a crisp leaf inspection sample."}
	}
func snapshot() -> Dictionary:
	return {"pantry":pantry.duplicate(true),"tray":tray.duplicate(true),"pending":pending.duplicate(true),"revision":revision,"disposed":disposed}
func valid() -> bool:
	if pantry.size()!=2 or tray.size()!=2:return false
	for id in ["test_fish_portion","test_flora_portion"]:
		if not pantry.has(id) or not pantry[id] is int or pantry[id]<0 or pantry[id]>PANTRY_COUNT:return false
	for id in ["test_glade_fillet","test_ember_leaf"]:
		if not tray.has(id) or not tray[id] is int or tray[id]<0 or tray[id]>TRAY_LIMIT:return false
	if tray_used()>TRAY_LIMIT:return false
	if not pending.is_empty():
		if pending.size()!=2 or not pending.has("recipe") or not pending.has("step"):return false
		if not pending.recipe is String or not recipes().has(pending.recipe) or not pending.step is int or pending.step<0 or pending.step>2:return false
	return true
func accept(expected:int) -> bool:
	last_error=""
	if disposed:last_error="This test station session has ended.";return false
	if not valid():last_error="Invalid test fixture state; close this station session.";return false
	if expected!=revision:last_error="The test view changed. Review the current station.";return false
	return true
func tray_used() -> int:
	return int(tray.get("test_glade_fillet",0))+int(tray.get("test_ember_leaf",0))
func review(recipe:String,expected:int) -> bool:
	if not accept(expected):return false
	if not recipes().has(recipe):last_error="Unknown test recipe.";return false
	if not pending.is_empty():last_error="Cancel the current preparation first.";return false
	var selected=recipes()[recipe]
	if pantry[selected.input]<1:last_error="No matching TEST portion remains. Explicitly reset test samples to restock.";return false
	pending={"recipe":recipe,"step":0};revision+=1;return true
func advance(expected:int) -> bool:
	if not accept(expected):return false
	if pending.is_empty():last_error="Choose a test recipe first.";return false
	if int(pending.step)>=2:last_error="Preparation is reviewed. Use Finish once.";return false
	pending.step=int(pending.step)+1;revision+=1;return true
func finish(expected:int) -> bool:
	if not accept(expected):return false
	if pending.is_empty() or int(pending.step)!=2:last_error="Complete the two preparation steps before Finish.";return false
	var recipe=recipes()[pending.recipe]
	# Build the WHOLE resulting transaction before publishing either side.
	var next_pantry=pantry.duplicate(true);var next_tray=tray.duplicate(true)
	if int(next_pantry[recipe.input])<1:last_error="The TEST portion is no longer available. Nothing consumed.";return false
	next_pantry[recipe.input]-=1;next_tray[recipe.output]+=1
	var used=int(next_tray.test_glade_fillet)+int(next_tray.test_ember_leaf)
	if used>TRAY_LIMIT:last_error="Inspection tray full (4 TEST samples). Nothing consumed. Explicitly reset test samples to continue.";return false
	pantry=next_pantry;tray=next_tray;pending={};revision+=1;return true
func cancel(expected:int) -> bool:
	if not accept(expected):return false
	pending={};revision+=1;return true
func reset_test_samples(expected:int) -> bool:
	if not accept(expected):return false
	pantry={"test_fish_portion":PANTRY_COUNT,"test_flora_portion":PANTRY_COUNT}
	tray={"test_glade_fillet":0,"test_ember_leaf":0};pending={};revision+=1;return true
func dispose():
	pantry={};tray={};pending={};disposed=true;revision+=1
