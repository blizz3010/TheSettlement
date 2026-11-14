extends Node
## Item 15b capture driver: real character-select panel on an isolated profile.
## env: SC_OUT=<dir> SC_TAG=<before|after> SC_ADAPTER=1 (use the fix adapter) SC_DIAG=1
const Session=preload("res://scripts/character_profiles/title_session.gd")
const Rules=preload("res://scripts/character_profiles/experimental_rules.gd")
const SelectPanel=preload("res://scripts/character_profiles/selection_panel.gd")
const Store=preload("res://scripts/character_profiles/profile_store.gd")
const Fresh=preload("res://scripts/character_profiles/new_gameplay.gd")

func _ready():
	get_tree().create_timer(240).timeout.connect(func():print("SC: watchdog");get_tree().quit(3))
	call_deferred("_run")

func _adapter_panel():
	var path="res://raid/scripts/character_select_panel_fixed.gd"
	if OS.get_environment("SC_ADAPTER")=="1" and ResourceLoader.exists(path):
		return load(path)
	return SelectPanel

func _run():
	var out=OS.get_environment("SC_OUT");var tag=OS.get_environment("SC_TAG")
	if tag.is_empty():tag="shot"
	DirAccess.make_dir_recursive_absolute(out)
	var session=Session.new();session.rules=Rules.data()
	var state=session.inspect()
	print("SC: state ",state.screen)
	if state.screen=="create":
		var appearance={"name":"Settler","cheek":0.0,"hair":"hair_short02_v1","brows":"brow_009_v1","eyes":"eye_brown_v1","hair_tint":"natural"}
		var r=session.create_character("slot_1",appearance,{"str":7,"int":7,"dex":7},[],state.bytes,false)
		print("SC: create ",r.get("ok",false)," ",r.get("reason",""))
		session.cancel()
	var panel=_adapter_panel().new();panel.session=session
	add_child(panel)
	for i in 6:await get_tree().process_frame
	var stage=panel.preview
	print("SC: preview visible ",stage.visible," note=",panel.preview_note.text)
	if OS.get_environment("SC_DIAG")=="1":_diag(stage)
	for view in [["front",0.0],["three_quarter",35.0],["side",90.0]]:
		stage.set_angle(view[1])
		for i in 4:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out+"/%s_%s_screen.png"%[tag,view[0]])
		var sub:SubViewport=stage.get_child(0)
		sub.get_texture().get_image().save_png(out+"/%s_%s.png"%[tag,view[0]])
		print("SC: saved ",tag," ",view[0])
	get_tree().quit()

func _diag(stage):
	for n in stage.stage.find_children("*","MeshInstance3D",true,false):
		if not n.is_visible_in_tree():continue
		var b=n.global_transform*n.get_aabb()
		print("SC: mesh %-32s y %.3f..%.3f x %.3f..%.3f z %.3f..%.3f"%[str(n.get_path()).get_file() if n.get_parent()!=stage.stage else n.name,b.position.y,b.end.y,b.position.x,b.end.x,b.position.z,b.end.z])
