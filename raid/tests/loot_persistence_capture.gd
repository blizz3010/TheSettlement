extends SceneTree
## Manual rendered capture for TASKS item 13 (raid loot persistence; not in the suite).
## Run on Xvfb with a disposable XDG profile:
## XDG_DATA_HOME=/tmp/x xvfb-run -a godot --rendering-driver opengl3 --path . --script res://raid/tests/loot_persistence_capture.gd
## Env LOOT_OUT=<abs dir> (default raid/screenshots/loot_persistence). Timings are llvmpipe, relative only.
const LootTable = preload("res://raid/scripts/raid_loot/loot_table.gd")
const HaulStore = preload("res://raid/scripts/raid_loot/raid_loot_store.gd")
const LootService = preload("res://raid/scripts/raid_loot/raid_loot_service.gd")
const SalvagePanel = preload("res://raid/scripts/raid_loot/atlas_salvage_panel.gd")
const ShopTransaction = preload("res://scripts/shop_transaction.gd")
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Request = preload("res://scripts/request_state.gd")
const Outcome = preload("res://raid/scripts/raid_outcome.gd")
var out := ""
var scene
var cam: Camera3D

func _initialize():
	call_deferred("run")

func shot(name: String):
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("LOOT_SHOT ", name)

func ground(p: Vector2) -> Vector3:
	return Vector3(p.x, scene.generator.height_at(p) + 0.08, p.y)

func _target(id: String) -> Dictionary:
	for t in scene.targets:
		if t.kind == "cache" and t.poi.id == id: return t
	return {}

func _frame_ms(frames: int) -> float:
	var t := Time.get_ticks_usec()
	for i in frames: await process_frame
	return (Time.get_ticks_usec() - t) / 1000.0 / frames

func run():
	out = OS.get_environment("LOOT_OUT").strip_edges()
	if out.is_empty(): out = ProjectSettings.globalize_path("res://raid/screenshots/loot_persistence")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1440, 900)
	DisplayServer.window_set_size(Vector2i(1440, 900))
	scene = load("res://raid/relay_ridge.tscn").instantiate()
	root.add_child(scene)
	while not scene.is_raid_ready(): await process_frame
	scene.return_requested.connect(func(): pass)
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	scene.health_controller.set_physics_process(false)
	# The high-quality Relay Tower cache (code door opened for the shot).
	var t := _target("relay")
	scene.raid_state.unlocked["relay"] = true
	scene._open_door("relay")
	var cp: Vector3 = t.node.global_position
	var view := cp + Vector3(2.2, 0, 2.6)
	view.y = cp.y
	scene.player.position = view
	cam = Camera3D.new(); cam.fov = 70; cam.far = 500; scene.add_child(cam); cam.current = true
	cam.global_position = view + Vector3(0, 1.62, 0); cam.look_at(cp + Vector3(0, 0.3, 0))
	for i in 20: await process_frame
	var ms_before := await _frame_ms(60)
	scene._interact(t)
	await shot("01_cache_loot_panel")
	var all: Button = null
	for b in scene.modal.find_children("*", "Button", true, false):
		if b.text == "Take all that fits": all = b
	if all != null: all.pressed.emit()
	await shot("02_cache_after_take_all")
	# Fill the rest of the haul from a second cache, then show the HUD.
	scene._close_modal()
	var yard := _target("yard")
	scene.raid_state.search_cache(yard.poi)
	scene.raid_state.take_all("yard")
	scene._process(0.016)
	scene.toast.text = ""
	await shot("03_hud_haul_full")
	var ms_after := await _frame_ms(60)
	scene._field_notes()
	await shot("04_field_notes_haul")
	scene._haul_panel()
	await shot("05_manage_haul_drop")
	scene.raid_state.extracted_at = "extract1"
	Outcome.last = {}
	scene._extraction_complete()
	await shot("06_extraction_results_haul_home")
	var outcome: Dictionary = Outcome.peek()
	print("LOOT_OUTCOME ", JSON.stringify(outcome))
	# Downed screen on the same ledger (haul lost).
	scene.raid_state.extracted_at = ""
	Outcome.last = {}
	scene.modal.hide()
	scene.health_controller._on_died("sentry turret")
	await shot("07_downed_haul_lost")
	print("LOOT_FRAME_MS ", JSON.stringify({"relay_view_before_ms": snappedf(ms_before, 0.01), "relay_view_haul_ms": snappedf(ms_after, 0.01), "note": "llvmpipe, relative only"}))
	scene.queue_free()
	for i in 3: await process_frame
	await settlement_panels(outcome.get("haul", {}))
	quit(0)

func settlement_panels(haul: Dictionary):
	var layer := CanvasLayer.new(); root.add_child(layer)
	var bg := ColorRect.new(); bg.color = Color("26332c"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.add_child(bg)
	var plot := Plot.new(); var inv := Inventory.new(); var req := Request.new()
	inv.carried = {"stone": 5}
	inv.stash = {"timber": 10, "stone": 10, "metal": 4}
	var svc := LootService.new()
	var store := HaulStore.new()
	if haul.is_empty(): haul = {"metal": 2, "salvage_capacitor": 1, "salvage_sensor": 2}
	haul = haul.duplicate()
	haul["timber"] = int(haul.get("timber", 0)) + 3  # show the overflow path too
	var dep: Dictionary = svc.deposit(plot, inv, req, store, {"haul": haul, "raid_uid": "capture"})
	print("LOOT_RETURN_NOTE ", dep.receipt.message)
	store.restore(dep.haul)
	plot = dep.plot; inv = dep.inventory
	var panel := SalvagePanel.new(); layer.add_child(panel)
	panel.configure(preload("res://raid/scripts/raid_loot/raid_loot_install.gd").ATLAS_DEFINITION)
	panel.bind_haul(store)
	panel.action = "salvage"
	for k in panel.tab_buttons: panel.tab_buttons[k].button_pressed = k == "salvage"
	panel.render_board(plot, inv, null, {}, "")
	panel.show()
	var first_sell := ""
	for r in panel.rows:
		if str(r.id).begins_with("sell:"): first_sell = str(r.id); break
	if not first_sell.is_empty():
		panel._select_item(first_sell)
		panel.quantity.value = int(panel._selected_row().max_quantity)
		panel._update_summary()
	await shot("08_atlas_salvage_tab")
	var tx := ShopTransaction.new(svc.quote_candidate)
	var ctx := {"haul": store.data()}
	var q := tx.select("atlas", "salvage", first_sell, int(panel.quantity.value), plot, inv, req, ctx)
	panel.render_board(plot, inv, null, q, "")
	await shot("09_atlas_salvage_review")
	var done: Dictionary = tx.confirm(q.token, plot, inv, req, func(): return true, func(_c): return true, ctx)
	store.restore(done.haul)
	panel.render_board(done.plot, done.inventory, null, {}, "Saved. Sold %s for %d credits." % [q.name, int(q.earned)])
	await shot("10_atlas_after_sale")
	layer.queue_free()
	await process_frame
