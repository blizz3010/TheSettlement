extends SceneTree
## TASKS item 22, gear PR F: renders the composite insert icon with the item 16 icon
## renderer into res://raid/assets/trader_icons/composite_insert.png. Needs a real
## display (Xvfb is fine).
const Renderer = preload("res://raid/scripts/trader_icon_renderer.gd")
func _initialize():
	_run.call_deferred()
func _run():
	var r = Renderer.new(); root.add_child(r)
	await process_frame
	var dir := ProjectSettings.globalize_path("res://raid/assets/trader_icons")
	for id in ["composite_insert"]:
		var img: Image = await r.render(id)
		var err := img.save_png(dir.path_join(id + ".png"))
		print("GEAR_PART_ICON ", id, " err=", err, " size=", img.get_size())
	r.queue_free()
	await process_frame
	quit(0)
