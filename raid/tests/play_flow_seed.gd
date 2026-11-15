extends SceneTree
## Capture setup only: creates two disposable settlers in the current (scratch) XDG profile
## so the normal-launch capture shows a returning player's select screen.
const Session = preload("res://scripts/character_profiles/title_session.gd")
const Rules = preload("res://scripts/character_profiles/experimental_rules.gd")
func _initialize():
	var session = Session.new(); session.rules = Rules.data()
	var state = session.inspect()
	print("SEED: state ", state.screen)
	if state.screen == "create":
		var r1 = session.create_character("slot_1", {"name":"Settler","cheek":0.0,"hair":"hair_short02_v1","brows":"brow_009_v1","eyes":"eye_brown_v1","hair_tint":"natural"}, {"str":7,"int":7,"dex":7}, [], state.bytes, false)
		session.cancel()
		var r2 = session.create_character("slot_2", {"name":"Wren","cheek":0.6,"hair":"hair_bob01_v1","brows":"brow_001_v1","eyes":"eye_blue_v1","hair_tint":"copper"}, {"str":5,"int":11,"dex":9}, ["methodical","restless"], session.inspect().bytes, false)
		session.cancel()
		print("SEED: created ", r1.get("ok", false), " ", r2.get("ok", false))
	quit()
