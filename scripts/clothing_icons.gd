extends RefCounted
# Basic garment silhouettes using committed fabric color; fixed grips/soles/hardware.
# UI thumbnails only, not armor or a substitute for the actual worn mesh preview.
const Inventory=preload("res://scripts/inventory_state.gd")
static var cache:Dictionary={}
static func texture(definition:Dictionary,entry:Dictionary)->Texture2D:
 if definition.get("id")=="helmet_basic" and entry.get("variant_id")=="basic":return preload("res://scripts/production_item_icons.gd").texture("helmet_basic")
 var slot:String=definition.get("category","")
 if not slot in ["jacket","gloves","pants","boots"] or entry.get("variant_id")!="basic":return null
 var rgba=entry.get("dyes",{}).get("fabric",Inventory.DEFAULT_FABRICS.get(slot,[.09,.10,.09,1.0]))
 var color=Color(rgba[0],rgba[1],rgba[2],rgba[3]).to_html(false)
 if slot=="boots":color="303b39"
 var key=slot+color
 if cache.has(key):
  var existing=cache[key].get_ref()
  if existing!=null:return existing
 var shapes={
  "jacket":'<path d="M30 14 39 10 48 20 57 10 66 14 85 46 72 54 64 39 66 84 30 84 32 39 24 54 11 46Z"/><path d="M39 10 36 27 48 20 60 27 57 10" fill="#89948b"/><path d="M48 23V83M34 36H42V49H34ZM54 36H62V49H54Z" fill="none" stroke="#b0ac95" stroke-width="2"/>',
  "pants":'<path d="M26 12H70L74 84H53L48 44 43 84H22Z"/><path d="M26 20H70M48 21V38M25 40H36V58H24M60 40H72L73 58H60" fill="none" stroke="#b0ac95" stroke-width="2"/><path d="M43 12H53V21H43Z" fill="#a19b7e"/>',
  "gloves":'<path d="M13 81 10 49 7 35 13 32 19 47 18 17 24 16 28 41 28 10 34 10 36 41 39 15 45 17 43 50 47 39 52 41 44 65 40 81Z"/><path d="M57 81 53 55 55 21 61 20 62 47 65 13 71 13 70 47 76 18 82 20 78 49 84 32 90 35 85 62 81 81Z"/><path d="M19 52H39V71H19ZM62 53H80V71H62Z" fill="#263331"/>',
  "boots":'<path d="M16 12H38L39 56 48 64V82H10V64L16 57ZM58 12H80L81 56 90 64V82H52V64L58 57Z"/><path d="M10 77H48V86H10ZM52 77H90V86H52Z" fill="#171f1e"/><path d="M20 27H34M20 35H34M62 27H76M62 35H76" stroke="#8f978b" stroke-width="3"/>'
 }
 var svg='<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><g fill="#'+color+'" stroke="#bcc4b4" stroke-width="1.5" stroke-linejoin="round">'+shapes[slot]+'</g></svg>'
 var image=Image.new()
 if image.load_svg_from_string(svg)!=OK:return null
 var result=ImageTexture.create_from_image(image);cache[key]=weakref(result);return result
