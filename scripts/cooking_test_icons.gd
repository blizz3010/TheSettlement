extends RefCounted
# Code-native thumbnails matching the provisional griddle samples, not efficacy art.
static var cache:Dictionary={}
static func texture(recipe:String) -> Texture2D:
	if not recipe in ["glade_fillet","ember_leaf"]:return null
	if cache.has(recipe):
		var live=cache[recipe].get_ref()
		if live!=null:return live
	var shapes='<path d="M13 48Q24 19 66 29L84 47Q65 78 25 67Z" fill="#c88954" stroke="#e3bd8d" stroke-width="3"/><path d="M30 38 42 58M43 33 55 57M57 35 68 53" stroke="#754a31" stroke-width="5" stroke-linecap="round"/>' if recipe=="glade_fillet" else '<path d="M20 75Q4 32 29 14Q47 42 20 75ZM44 77Q24 30 48 9Q73 35 44 77ZM65 77Q48 35 78 20Q93 57 65 77Z" fill="#a5a052" stroke="#d4ca87" stroke-width="2"/><path d="M20 76 29 30M44 79 48 25M65 78 77 36" fill="none" stroke="#6e602e" stroke-width="3"/>'
	var svg='<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96">'+shapes+'</svg>'
	var image=Image.new()
	if image.load_svg_from_string(svg)!=OK:return null
	var result=ImageTexture.create_from_image(image);cache[recipe]=weakref(result);return result
