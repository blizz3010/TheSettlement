extends RefCounted
## Raid session ledger. Never reads/writes settlement inventory or saves itself.
## TASKS item 13: caches hold real loot (raid_loot/loot_table.gd). Taken loot sits
## in the raid haul until extraction; the settlement applies it on return
## (raid_loot_install.gd). Downed or abandoned raids lose the haul.
const LootTable=preload("res://raid/scripts/raid_loot/loot_table.gd")
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
var cache_contents:Dictionary={}
var haul:Dictionary={}
var haul_capacity:int=LootTable.HAUL_BASE_CAPACITY
## PR D: raid-only supplies (field dressings) per cache, and the rig quick-use slots.
var cache_supplies:Dictionary={}
var quick_capacity:int=0
var quick_slots:Array=[]
var supplies_used:int=0
## Gear PR F: found gear pieces and composite inserts per cache ({key: n}).
var cache_gear:Dictionary={}
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
	# Same seeded RNG, drawn after the quality roll, so bands are unchanged.
	cache_contents[poi.id]=LootTable.roll(rng,quality)
	# PR D: drawn after the items, so the item roll for a seed is unchanged.
	cache_supplies[poi.id]=LootTable.roll_supplies(rng,quality)
	# Gear PR F: drawn after the supplies, so item and supply rolls for a seed are unchanged.
	cache_gear[poi.id]=LootTable.roll_gear(rng,quality)
	return {"ok":true,"quality":quality,"items":cache_contents[poi.id].duplicate(true),"supplies":cache_supplies[poi.id].duplicate(),"gear":cache_gear[poi.id].duplicate(),"preview_only":false}

## Gear PR F: found gear and parts left in a cache.
func gear_in(poi_id:String)->Dictionary:
	return cache_gear.get(poi_id,{}).duplicate()

## Everything takeable into the haul from one cache: gear first, then items.
func cache_loot(poi_id:String)->Dictionary:
	var all:=gear_in(poi_id)
	for id in cache_contents.get(poi_id,{}):all[id]=int(cache_contents[poi_id][id])
	return all

func supplies_in(poi_id:String)->Dictionary:
	return cache_supplies.get(poi_id,{}).duplicate()

## Anything left to take (items or supplies)?
func cache_has_anything(poi_id:String)->bool:
	return LootTable.units(cache_contents.get(poi_id,{}))+LootTable.units(cache_supplies.get(poi_id,{}))+LootTable.units(cache_gear.get(poi_id,{}))>0

func quick_space()->int:return maxi(0,quick_capacity-quick_slots.size())

func _pull_supply(poi_id:String,id:String)->bool:
	if not extracted_at.is_empty() or not cache_supplies.has(poi_id):return false
	var box:Dictionary=cache_supplies[poi_id]
	if int(box.get(id,0))<=0:return false
	box[id]=int(box[id])-1
	if int(box[id])<=0:box.erase(id)
	return true

## Moves one supply from a cache into a free rig quick-use slot.
func stow_supply(poi_id:String,id:String)->bool:
	if quick_space()<=0 or int(cache_supplies.get(poi_id,{}).get(id,0))<=0:return false
	if not _pull_supply(poi_id,id):return false
	quick_slots.append(id)
	return true

## Takes one supply out of a cache to use right away. Returns true when taken.
func use_supply_from_cache(poi_id:String,id:String)->bool:
	if not _pull_supply(poi_id,id):return false
	supplies_used+=1
	return true

## Empties quick-use slot index (0-based). Returns the supply id or "".
func use_quick(index:int)->String:
	if not extracted_at.is_empty() or index<0 or index>=quick_slots.size():return ""
	var id:String=quick_slots[index]
	quick_slots.remove_at(index)
	supplies_used+=1
	return id

func cache_items(poi_id:String)->Dictionary:
	return cache_contents.get(poi_id,{}).duplicate(true)

func haul_units()->int:return LootTable.units(haul)
func haul_space()->int:return maxi(0,haul_capacity-haul_units())
func haul_value()->int:return LootTable.total_value(haul)
## Gear PR F: does one more of this id fit in the haul?
func fits(item:String)->bool:return haul_space()>=LootTable.unit_size(item)
## Found gear (and parts) currently in the haul.
func haul_gear()->Dictionary:
	var out:={}
	for id in haul:
		if LootTable.is_gear(str(id)) or LootTable.is_part(str(id)):out[id]=int(haul[id])
	return out

## Moves up to qty (all if qty<1) of one item from a searched cache into the haul.
## Returns how many were taken. Frozen once extracted.
## Gear PR F: gear pieces take LootTable.unit_size units each.
func take_from_cache(poi_id:String,item:String,qty:int=-1)->int:
	if not extracted_at.is_empty():return 0
	var box:Dictionary
	if int(cache_gear.get(poi_id,{}).get(item,0))>0:box=cache_gear[poi_id]
	elif cache_contents.has(poi_id):box=cache_contents[poi_id]
	else:return 0
	var available:=int(box.get(item,0))
	var n:=mini(available,haul_space()/LootTable.unit_size(item))
	if qty>0:n=mini(n,qty)
	if n<=0:return 0
	box[item]=available-n
	if int(box[item])<=0:box.erase(item)
	haul[item]=int(haul.get(item,0))+n
	return n

## Takes the most valuable items first (found gear included) until the haul is full. Returns {item: n}.
func take_all(poi_id:String)->Dictionary:
	var taken:={}
	if not cache_contents.has(poi_id) and not cache_gear.has(poi_id):return taken
	for item in LootTable.by_value(cache_loot(poi_id).keys()):
		var n:=take_from_cache(poi_id,str(item))
		if n>0:taken[item]=n
	return taken

## Drops haul items. They are left behind in this raid and not recoverable.
func drop_from_haul(item:String,qty:int=1)->int:
	if not extracted_at.is_empty() or qty<1:return 0
	var have:=int(haul.get(item,0))
	var n:=mini(have,qty)
	if n<=0:return 0
	haul[item]=have-n
	if int(haul[item])<=0:haul.erase(item)
	return n

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
	# Snapshot only. The settlement commits the haul after a successful extraction.
	return {"seed":seed_value,"visited":visited.keys(),"searched":searched.duplicate(true),
		"active_seconds":active_seconds,"extracted_at":extracted_at,"haul":haul.duplicate(true),
		"haul_units":haul_units(),"haul_capacity":haul_capacity,"haul_value":haul_value(),
		"quick_slots":quick_slots.duplicate(),"supplies_used":supplies_used,"haul_gear":haul_gear(),"preview_only":false}
