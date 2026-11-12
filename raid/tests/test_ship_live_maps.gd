extends SceneTree
## Real host and generated maps. Only the final title/save reload is replaced.
const Catalog = preload("res://raid/scripts/raid_catalog.gd")
var checks := 0
var failures: Array = []
var map_results: Array = []

class ObservedHost:
	extends "res://raid/scripts/ship_transition.gd"
	var restores := 0
	var restored_binding: Dictionary = {}
	func _restore_title():
		restores += 1
		restored_binding = binding.duplicate(true)
		if is_instance_valid(raid): raid.free()
		raid = null

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize(): call_deferred("run")

func create_host(raid_id: String):
	var host = ObservedHost.new()
	host.raid_id = raid_id
	host.binding = {"slot": "slot_2", "appearance": {"name": "Isolated flow test", "nested": {"value": 2}}}
	root.add_child(host)
	return host

func test_map(raid_id: String):
	var host = create_host(raid_id)
	check(host.cover.visible and Catalog.display_name(raid_id) in host.status.text, raid_id + ": cover names chosen destination before load")
	host.open_raid()
	var selected = host.raid
	check(is_instance_valid(selected) and selected.scene_file_path == Catalog.scene_path(raid_id), raid_id + ": host adds selected real scene")
	check(host.cover.visible and not selected.is_raid_ready() and not selected.player.enabled, raid_id + ": initial readiness barrier protects controls")
	host.open_raid()
	check(host.raid == selected, raid_id + ": repeated open retains a single live raid")
	await physics_frame
	check(not selected.is_raid_ready() and not selected.player.enabled, raid_id + ": first physics tick keeps loading barrier")
	await physics_frame
	check(selected.is_raid_ready() and selected.player.enabled, raid_id + ": second physics tick validates collision and activates map")
	var deadline := Time.get_ticks_msec() + 60000
	while is_instance_valid(host.raid) and (not host.raid.is_raid_ready() or host.cover.visible) and Time.get_ticks_msec() < deadline:
		await process_frame
	var ready: bool = is_instance_valid(host.raid) and host.raid.is_raid_ready() and not host.cover.visible
	check(ready, raid_id + ": actual generation reaches readiness and host uncovers")
	if ready:
		check(selected.get_raid_failure().is_empty(), raid_id + ": no generation failure")
		check(selected.player.enabled and selected.player.camera.current, raid_id + ": active production player/camera")
		check(selected.generator.pois.size() == 6 and selected.targets.filter(func(target): return target.kind == "extract").size() == 2, raid_id + ": complete map destinations and extraction targets")
		selected._request_return()
		check(host.returning and host.restores == 0, raid_id + ": real map signal immediately begins deferred host return")
		selected._request_return()
		host.return_to_settlement()
		await process_frame
		check(host.restores == 1 and host.returning, raid_id + ": real map return signal reaches host exactly once")
		check(host.restored_binding == host.binding, raid_id + ": return retains exact bound character snapshot")
		check(not is_instance_valid(host.raid), raid_id + ": raid released at intercepted title restore")
	map_results.append({"id": raid_id, "ready": ready, "restores": host.restores})
	host.free()
	await preload("res://raid/tests/audio_shutdown.gd").drain(self)

	# Cancel during the real map's yielded initialization. The title restore is
	# intercepted, not the map generator, host loop, or cancellation callback.
	for elapsed_ticks in [0, 1]:
		host = create_host(raid_id)
		host.open_raid()
		if elapsed_ticks == 1: await physics_frame
		check(host.cover.visible and not host.raid.is_raid_ready(), raid_id + ": cancellation starts while covered at tick " + str(elapsed_ticks))
		host.return_button.pressed.emit()
		host.return_button.pressed.emit()
		await process_frame
		await process_frame
		check(host.restores == 1 and host.returning and not is_instance_valid(host.raid), raid_id + ": loading cancellation releases real map once")
		host.open_raid()
		check(not is_instance_valid(host.raid) and host.restores == 1, raid_id + ": stale open cannot restart cancelled trip")
		host.free()
		await preload("res://raid/tests/audio_shutdown.gd").drain(self)

func run():
	for raid_id in Catalog.RAIDS:
		await test_map(raid_id)
	print("SHIP_LIVE_MAP_TESTS ", JSON.stringify({"checks": checks, "failures": failures, "maps": map_results, "scope": "Real host, both actual generated maps, readiness, duplicate input, return signals and loading cancellation; title restoration intercepted, no settlement save/reload or native/rendered acceptance"}))
	quit(0 if failures.is_empty() else 1)
