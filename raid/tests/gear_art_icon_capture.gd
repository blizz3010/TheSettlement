extends SceneTree
## TASKS item 22, gear art E0/E1: renders tiered gear icons with the item 16 icon renderer into
## res://raid/assets/trader_icons/<id>.png. Needs a real display (Xvfb is fine).
## Ids from the user args (`-- gear_helmet_t1 gear_body_armor_t1`), else every GearArt id.
const Renderer = preload("res://raid/scripts/trader_icon_renderer.gd")
const GearArt = preload("res://raid/scripts/gear_tiers/gear_art.gd")
func _initialize():
	_run.call_deferred()
func _run():
	var r = Renderer.new(); root.add_child(r)
	await process_frame
	var dir := ProjectSettings.globalize_path("res://raid/assets/trader_icons")
	var ids: Array = Array(OS.get_cmdline_user_args())
	if ids.is_empty(): ids = GearArt.ids()
	for id in ids:
		var img: Image = await r.render(id)
		var err := img.save_png(dir.path_join(id + ".png"))
		print("GEAR_ART_ICON ", id, " err=", err, " size=", img.get_size())
	r.queue_free()
	await process_frame
	quit(0)
