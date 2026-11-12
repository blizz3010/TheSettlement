extends SceneTree
const Contract = preload("res://raid/scripts/ship_contract.gd")
var failures := 0
class FakeWorld:
	extends RefCounted
	var allowed := true
	var save_ok := true
	var save_calls := 0
	var _character_slot := "slot_2"
	var character_appearance := {"name": "Test", "nested": {"value": 1}}
	func ship_can_embark(): return allowed
	func save_game(_notice):
		save_calls += 1
		return save_ok
func check(value: bool, description: String):
	if not value:
		push_error(description)
		failures += 1
func _initialize():
	var world = FakeWorld.new()
	var contract = Contract.new()
	world.allowed = false
	check(not contract.begin(world) and world.save_calls == 0, "Blocked/stale input cannot save or depart")
	world.allowed = true
	world.save_ok = false
	check(not contract.begin(world) and not contract.busy, "Save failure leaves transition retryable")
	world.save_ok = true
	check(contract.begin(world), "Successful departure")
	check(contract.binding.slot == "slot_2", "Exact character slot preserved")
	world.character_appearance.nested.value = 5
	check(contract.binding.appearance.nested.value == 1, "Appearance snapshot deeply copied")
	check(not contract.begin(world) and world.save_calls == 2, "Repeat activation cannot save or deploy twice")
	var legacy = Contract.new()
	world._character_slot = ""
	check(legacy.begin(world) and legacy.binding.slot == "", "Legacy binding retained")
	check(Contract.in_zone(Vector3(0, 1.28, 4.8)), "Pad boarding center accepted")
	check(not Contract.in_zone(Vector3(0, 0, 4.8)), "Ground beneath pad rejected")
	check(not Contract.in_zone(Vector3(0, 1.28, 0)), "Hull center rejected")
	check(not Contract.in_zone(Vector3(0, 1.28, 10)), "Ramp not prematurely accepted")
	print("Ship contract: ", "PASS" if failures == 0 else "FAIL", " (11 checks; test doubles, not rendered travel)")
	quit(1 if failures else 0)
