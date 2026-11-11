extends RefCounted
## Disposable raid-only prototype. Never reads/writes settlement inventory or saves.
var seed_value:int
var held:Dictionary={}
var notes:Dictionary={}
var clues:Dictionary={}
var unlocked:Dictionary={}
var searched:Dictionary={}
var switch_step:int=0
var visited:Dictionary={}
var active_seconds:=0.0
var extraction_id:=""
var extraction_seconds:=0.0
var extracted_at:=""
const EXTRACTION_DURATION:=8.0
const PUZZLE_ORDER=[2,1,3]
func _init(seed_number:int=241107):seed_value=seed_number
func code_for(poi_id:String)->String:
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+int(poi_id.hash())
	return "%04d"%rng.randi_range(0,9999)
func collect(poi:Dictionary)->String:
	match poi.lock:
		"key":held[poi.id+"_key"]=true;return "Found: substation maintenance key."
		"keycard":held[poi.id+"_card"]=true;return "Found: research access card."
		"code":notes[poi.id]=code_for(poi.id);return "Relay maintenance note: door code "+notes[poi.id]+". Kept in field notes (Tab)."
	clues[poi.id]="Weather log: restart relays WEST, NORTH, EAST (2, 1, 3)."
	return clues[poi.id]
func try_unlock(poi:Dictionary,code:String="")->bool:
	if unlocked.get(poi.id,false):return true
	var ok=false
	match poi.lock:
		"":ok=true
		"key":ok=held.get(poi.id+"_key",false)
		"keycard":ok=held.get(poi.id+"_card",false)
		"code":ok=code==code_for(poi.id)
		"puzzle":ok=switch_step==PUZZLE_ORDER.size()
	if ok:unlocked[poi.id]=true
	return ok
func flip_switch(number:int)->bool:
	if switch_step>=PUZZLE_ORDER.size():return true
	if number==PUZZLE_ORDER[switch_step]:switch_step+=1
	else:switch_step=1 if number==PUZZLE_ORDER[0] else 0
	return switch_step==PUZZLE_ORDER.size()
func search_cache(poi:Dictionary)->Dictionary:
	if searched.has(poi.id):return {"ok":false,"reason":"Already searched this raid."}
	if poi.lock!="" and not unlocked.get(poi.id,false):return {"ok":false,"reason":"Secure room is locked."}
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+int(poi.id.hash())+771
	var quality=rng.randi_range(poi.loot[0],poi.loot[1])
	searched[poi.id]=quality
	return {"ok":true,"quality":quality,"preview_only":true}

func visit(poi_id:String)->bool:
	if poi_id.is_empty() or visited.has(poi_id) or not extracted_at.is_empty():return false
	visited[poi_id]=true
	return true

func advance_active_time(delta:float):
	if is_finite(delta) and delta>0.0 and extracted_at.is_empty():active_seconds+=delta

func start_extraction(id:String)->bool:
	if id.is_empty() or not extraction_id.is_empty() or not extracted_at.is_empty():return false
	extraction_id=id
	extraction_seconds=0.0
	return true

func cancel_extraction()->bool:
	var was_active=not extraction_id.is_empty()
	extraction_id=""
	extraction_seconds=0.0
	return was_active

func advance_extraction(delta:float,eligible:bool)->bool:
	if extraction_id.is_empty():return false
	if not eligible:
		cancel_extraction()
		return false
	if not is_finite(delta) or delta<=0.0:return false
	extraction_seconds=minf(extraction_seconds+delta,EXTRACTION_DURATION)
	if extraction_seconds<EXTRACTION_DURATION:return false
	extracted_at=extraction_id
	extraction_id=""
	return true

func summary()->Dictionary:
	# Snapshot only. Nothing is committed to settlement saves or inventory.
	return {"seed":seed_value,"visited":visited.keys(),"searched":searched.duplicate(true),
		"active_seconds":active_seconds,"extracted_at":extracted_at,"preview_only":true}
