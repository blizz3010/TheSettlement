extends SceneTree
## TASKS item 22, gear art E0: renders the T3 helmet / vest icons with the item 16 icon
## renderer into res://raid/assets/trader_icons/<id>.png. Needs a real display (Xvfb is fine).
const Renderer = preload("res://raid/scripts/trader_icon_renderer.gd")
func _initialize():
	_run.call_deferred()
func _run():
	var r = Renderer.new(); root.add_child(r)
	await process_frame
	var dir := ProjectSettings.globalize_path("res://raid/assets/trader_icons")
	for id in ["gear_helmet_t3", "gear_body_armor_t3"]:
		var img: Image = await r.render(id)
		var err := img.save_png(dir.path_join(id + ".png"))
		print("GEAR_ART_ICON ", id, " err=", err, " size=", img.get_size())
	r.queue_free()
	await process_frame
	quit(0)
