extends SceneTree
func _initialize():
	var config=preload("res://raid/scripts/relay_config.gd").new();var gen=preload("res://raid/scripts/relay_generator.gd").new(config)
	var data={"seed":config.map_seed,"extent":146,"heights":[],"pois":[],"routes":[],"trees":[],"spawn":[config.SPAWN.x,config.SPAWN.y],"extracts":[]}
	for z in range(-146,147,2):
		var row=[]
		for x in range(-146,147,2):row.append(gen.height_at(Vector2(x,z)))
		data.heights.append(row)
	for poi in gen.pois:data.pois.append({"id":poi.id,"name":poi.name,"at":[poi.at.x,poi.at.y],"radius":poi.radius,"loot":poi.loot,"lock":poi.lock})
	for route in gen.routes:
		var line=[]
		for p in route:line.append([p.x,p.y])
		data.routes.append(line)
	for p in config.EXTRACTS:data.extracts.append([p.x,p.y])
	for p in gen.placements("tree"):data.trees.append([p.position.x,p.position.z])
	var path=ProjectSettings.globalize_path("res://../layout-data.json");var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close()
	quit()
