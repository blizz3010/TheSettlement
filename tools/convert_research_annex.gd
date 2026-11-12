extends SceneTree
## Godot 4.6.3 supported GLTFDocument import, without an editor cache dependency.
## Run with --script res://tools/convert_research_annex.gd -- --out=/absolute/new.scn
## Original authoring archives and gameplay collision are never modified here.
func _initialize():
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output=arg.substr(6)
	if output.is_empty() or not output.is_absolute_path() or FileAccess.file_exists(output):
		push_error("Provide --out=/absolute/new.scn; output must not already exist.");quit(1);return
	var zip=ZIPReader.new()
	var code=zip.open("res://AUTHORING/ResearchAnnex/source/research_annex_final_b_models.zip")
	if code!=OK:push_error("Source archive unavailable");quit(1);return
	var bytes=zip.read_file("research_annex_assembled.glb");zip.close()
	var doc=GLTFDocument.new();var state=GLTFState.new()
	state.handle_binary_image=GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED
	code=doc.append_from_buffer(bytes,"",state)
	if code!=OK:push_error("GLTF load failed "+str(code));quit(1);return
	var art=doc.generate_scene(state);var packed=PackedScene.new()
	code=packed.pack(art)
	if code==OK:code=ResourceSaver.save(packed,output,ResourceSaver.FLAG_COMPRESS)
	print("ANNEX_CONVERSION ",JSON.stringify({"code":code,"meshes":state.get_meshes().size(),"textures":state.get_textures().size(),"output":output}))
	art.free();quit(0 if code==OK else 1)
