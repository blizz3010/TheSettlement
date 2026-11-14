extends Node
## Item 15b follow-up capture: the real in-game inventory panel (inventory_panel.gd ->
## equipment_controls.gd -> clothing_preview.gd), rendered standalone.
## env: IC_OUT, IC_TAG, IC_HOOK=1 (connect the adapter's hook), IC_EQUIP=1 (wear all five slots)
const InventoryPanel=preload("res://scripts/inventory_panel.gd")
const Inventory=preload("res://scripts/inventory_state.gd")
const Hook=preload("res://raid/scripts/inventory_model_hook.gd")

func _ready():
	get_tree().create_timer(200).timeout.connect(func():print("IC: watchdog");get_tree().quit(3))
	call_deferred("_run")

func _run():
	var out=OS.get_environment("IC_OUT");var tag=OS.get_environment("IC_TAG")
	DirAccess.make_dir_recursive_absolute(out)
	if OS.get_environment("IC_HOOK")=="1":get_tree().node_added.connect(Hook.on_node_added)
	var inv=Inventory.new()
	if OS.get_environment("IC_EQUIP")=="1":
		var dyes={"jacket":[.42,.30,.18,1.0],"pants":[.20,.24,.20,1.0],"gloves":[.30,.22,.14,1.0]}
		for slot in ["jacket","pants","gloves","boots","helmet"]:
			var def="helmet_basic" if slot=="helmet" else "basic_"+slot
			var id="ic_"+slot
			inv.equipment_owned[id]={"id":id,"definition_id":def,"variant_id":"basic","dyes":{"fabric":dyes[slot]} if dyes.has(slot) else {},"location":"equipped"}
			inv.equipment_slots[slot]=id
	var appearance={"name":"Settler","cheek":0.0,"hair":"hair_short02_v1","brows":"brow_009_v1","eyes":"eye_brown_v1","hair_tint":"natural"}
	var panel=InventoryPanel.new();add_child(panel)
	for i in 3:await get_tree().process_frame
	panel.render(inv,false,"",appearance)
	panel.show()
	for i in 8:await get_tree().process_frame
	var preview=panel.equipment_editor.character_preview
	print("IC: preview script ",preview.get_script().resource_path)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out+"/%s_panel.png"%tag)
	# Second render (as when the inventory refreshes) must keep the swapped preview.
	panel.render(inv,false,"",appearance)
	for i in 4:await get_tree().process_frame
	print("IC: after re-render ",panel.equipment_editor.character_preview.get_script().resource_path," rows=",panel.equipment_editor.equipment_row.get_child_count())
	var stage=panel.equipment_editor.character_preview
	stage.stretch=false;stage.get_child(0).size=Vector2i(540,640)
	var views=[["front",0.0],["three_quarter",35.0],["side",90.0]]
	for v in views:
		var sub:SubViewport=stage.get_child(0);sub.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		if stage.has_method("set_angle"):
			stage.set_angle(v[1])
			for i in 4:await get_tree().process_frame
			await RenderingServer.frame_post_draw
			sub.get_texture().get_image().save_png(out+"/%s_%s.png"%[tag,v[0]]);print("IC: saved ",tag," ",v[0]);continue
		var cam:Camera3D
		for n in stage.get_child(0).find_children("*","Camera3D",true,false):cam=n
		var target=Vector3(0,.95 if stage.get_script().resource_path.contains("clothing_preview") else .78,0)
		var a=deg_to_rad(v[1]);var dist=cam.position.distance_to(target)
		cam.position=target+Vector3(sin(a)*dist,(cam.position.y-target.y),cos(a)*dist);cam.look_at(target)
		for i in 4:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		sub.get_texture().get_image().save_png(out+"/%s_%s.png"%[tag,v[0]])
		print("IC: saved ",tag," ",v[0])
	get_tree().quit()
