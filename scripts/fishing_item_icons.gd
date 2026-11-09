extends RefCounted
# Two owned vector icons, decoded directly so a new SVG import is not required.
static var cache:Dictionary={}
static func texture(item:String)->Texture2D:
	if not item in ["fishing_pole","river_fish"]:return null
	if cache.has(item):return cache[item]
	var path="res://assets/ui/inventory_"+item+".svg"
	if not FileAccess.file_exists(path):return null
	var image=Image.new()
	if image.load_svg_from_string(FileAccess.get_file_as_string(path))!=OK:return null
	var result=ImageTexture.create_from_image(image);cache[item]=result;return result
