extends "res://raid/scripts/raid_state.gd"
## Same disposable credentials/loot/extraction, a distinct valve puzzle and lore.
const VALVE_ORDER:=[3,1,2]
func collect(poi:Dictionary)->String:
	match poi.lock:
		"key":held[poi.id+"_key"]=true;return "Found: glasskiln service key."
		"keycard":held[poi.id+"_card"]=true;return "Found: Obsidian Archive clearance card."
		"code":notes[poi.id]=code_for(poi.id);return "Helion calibration note: control code "+notes[poi.id]+". Kept in field notes (Tab)."
	clues[poi.id]="Cistern service log: bleed STEAM, then PRIME, then RETURN (3, 1, 2). The sealed reservoir archive opens when all three valves agree."
	return clues[poi.id]
func flip_switch(number:int)->bool:
	if switch_step>=VALVE_ORDER.size():return true
	if number==VALVE_ORDER[switch_step]:switch_step+=1
	else:switch_step=1 if number==VALVE_ORDER[0] else 0
	return switch_step==VALVE_ORDER.size()
