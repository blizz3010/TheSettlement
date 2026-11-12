extends SceneTree
const Config=preload("res://raid/scripts/relay_config.gd")
const Generator=preload("res://raid/scripts/relay_generator.gd")
const State=preload("res://raid/scripts/raid_state.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func run():
	var config=Config.new();var a=Generator.new(config);var b=Generator.new(config)
	check(config.valid(),"default config accepted")
	var invalid=Config.new();invalid.terrain_amplitude=NAN;check(not invalid.valid(),"NaN rejected")
	invalid=Config.new();invalid.tree_density=1.2;check(not invalid.valid(),"out of range density rejected")
	var counts={}
	for kind in ["tree","grass","shrub","rock"]:
		var placements=a.placements(kind);counts[kind]=placements.size()
		check(placements==b.placements(kind),kind+" deterministic transforms")
		var legal=true
		for p in placements:
			var point=Vector2(p.position.x,p.position.z)
			legal=legal and not a.reserved(point,2.0 if kind=="tree" else 0.8 if kind=="rock" else 0.0) and a.slope_at(point)<=0.48 and is_equal_approx(p.position.y,a.height_at(point))
		check(legal,kind+" excludes routes, POIs, steep slopes and outer boundary")
	var sparse=Config.new();sparse.grass_density=0.1
	check(Generator.new(sparse).placements("tree")==a.placements("tree"),"grass density does not change trees")
	check(Generator.new(sparse).placements("grass").size()<counts.grass,"grass density reduces grass")
	var different=Config.new();different.map_seed+=1
	check(Generator.new(different).placements("tree")!=a.placements("tree"),"different seed changes placement")
	var zero=Config.new();zero.grass_density=0;check(Generator.new(zero).placements("grass").is_empty(),"zero density removes layer")
	var top=0;var ids={};var lock_types={}
	for poi in config.pois():
		check(not ids.has(poi.id),"unique POI "+poi.id);ids[poi.id]=true
		check(poi.loot[0]>=1 and poi.loot[0]<=poi.loot[1] and poi.loot[1]<=5,"valid loot range "+poi.id)
		if poi.loot[1]==5:top+=1
		if poi.lock!="":lock_types[poi.lock]=true
		check(is_equal_approx(a.height_at(poi.at+Vector2(9,7)),a.height_at(poi.at)),"flat POI footprint "+poi.id)
	check(top==2,"exactly two top-tier POIs")
	check(lock_types.has_all(["key","keycard","code","puzzle"]),"all requested lock types represented")
	var route_grade=0.0;var flat_routes=true
	for route in config.routes():
		for i in range(route.size()-1):
			var start:Vector2=route[i];var end:Vector2=route[i+1]
			for step in range(ceili(start.distance_to(end))):
				var p=start.move_toward(end,step);var q=start.move_toward(end,step+1)
				var grade=absf(a.height_at(q)-a.height_at(p))/maxf(p.distance_to(q),0.001)
				if grade>route_grade:route_grade=grade
				if grade>0.7:print("STEEP ",p," grade ",grade)
				for poi in config.pois():
					if absf(p.x-poi.at.x)<7 and absf(p.y-poi.at.y)<6:flat_routes=false;print("FOOTPRINT ",poi.id," ",p)
	check(route_grade<0.7,"route terrain under 35 degree grade")
	check(flat_routes,"routes avoid building footprints")
	for seed_number in [0,1,241107,2147483647]:
		var state=State.new(seed_number)
		for poi in config.pois():
			if poi.lock!="":check(not state.search_cache(poi).ok,"locked cache refuses before unlock "+poi.id)
			if poi.lock in ["key","keycard"]:
				check(not state.try_unlock(poi),"missing credential denied "+poi.id)
				state.collect(poi);check(state.try_unlock(poi),"matching credential accepted "+poi.id)
			elif poi.lock=="code":
				var code=state.code_for(poi.id);check(code.length()==4 and code.is_valid_int(),"four digit code")
				check(not state.try_unlock(poi,"wrong"),"wrong code denied");state.collect(poi)
				check(state.notes[poi.id]==code and state.try_unlock(poi,code),"note matches accepted code")
			elif poi.lock=="puzzle":
				state.collect(poi);check(state.clues.has(poi.id),"weather clue retained in field notes")
				state.flip_switch(1);check(state.switch_step==0 and not state.try_unlock(poi),"wrong puzzle sequence stays locked")
				for n in [2,1,3]:state.flip_switch(n)
				check(state.try_unlock(poi),"correct puzzle sequence unlocks")
			var loot=state.search_cache(poi);check(loot.ok and loot.quality>=poi.loot[0] and loot.quality<=poi.loot[1],"loot roll within POI band "+poi.id)
			check(not state.search_cache(poi).ok,"cache cannot be searched twice "+poi.id)
		check(State.new(seed_number).held.is_empty(),"new raid resets credentials")
	print("RELAY_CONTRACTS ",JSON.stringify({"checks":checks,"failures":failures,"counts":counts,"max_route_grade":route_grade}))
	quit(0 if failures.is_empty() else 1)
