extends RefCounted
# Transient, accessible state machine. A bite never expires; one press retrieves.
var phase := "idle"
var elapsed := 0.0
var serial := 0
var token := 0
var inventory_snapshot:Dictionary = {}
func active() -> bool: return phase!="idle"
func begin(inventory) -> int:
	if active(): return 0
	serial+=1;token=serial;phase="casting";elapsed=0.0
	inventory_snapshot=inventory.data().duplicate(true)
	return token
func advance(delta:float) -> void:
	if not active() or phase in ["bite","resolve"]: return
	elapsed+=maxf(delta,0.0)
	if phase=="casting" and elapsed>=0.7:phase="waiting";elapsed=0.0
	elif phase=="waiting" and elapsed>=2.0:phase="bite";elapsed=0.0
	elif phase=="retrieving" and elapsed>=1.2:phase="resolve";elapsed=0.0
func retrieve() -> bool:
	if phase!="bite":return false
	phase="retrieving";elapsed=0.0;return true
func claim(expected:int, inventory) -> bool:
	if phase!="resolve" or token!=expected or inventory.data()!=inventory_snapshot:return false
	# Consume authority before attempting persistence; failed writes require a new cast.
	phase="idle";token=0;inventory_snapshot={};return true
func cancel() -> void:
	phase="idle";elapsed=0.0;token=0;inventory_snapshot={}
func hint(key:String) -> String:
	match phase:
		"casting":return "Casting your selected fishing pole… • Esc cancels"
		"waiting":return "Waiting for a bite… • No bait or durability cost • Esc cancels"
		"bite":return "BITE!  %s Retrieve once • No time limit • Esc cancels"%key
		"retrieving":return "Retrieving… • No button-mashing • Esc cancels"
	return ""
