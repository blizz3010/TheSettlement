extends SceneTree
## TASKS item 22, PR D: renders the raid supply icons with the item 16 icon renderer into
## res://raid/assets/trader_icons/<id>.png. Needs a real display (Xvfb is fine).
const Renderer = preload("res://raid/scripts/trader_icon_renderer.gd")
const LootTable = preload("res://raid/scripts/raid_loot/loot_table.gd")
func _initialize():
	_run.call_deferred()
func _run():
	var r = Renderer.new(); root.add_child(r)
	await process_frame
	var dir := ProjectSettings.globalize_path("res://raid/assets/trader_icons")
	for id in LootTable.SUPPLIES:
		var img: Image = await r.render(str(id))
		var err := img.save_png(dir.path_join(str(id) + ".png"))
		print("SUPPLY_ICON ", id, " err=", err, " size=", img.get_size())
	r.queue_free()
	await process_frame
	quit(0)
