extends RefCounted
# UI translations of the existing world signs, not new world geometry.
# Rook: rook_shop_art.parcel() seven vertices/ten edges.
# Cook: west_trader's cream banner with a terracotta diamond (review cook-counter).
# Tailor: tailor_atelier's cream-rimmed indigo spool.
static var cache:Dictionary={}
static func texture(shop:String)->Texture2D:
 var key="cook" if shop in ["cook_vendor","cook_griddle"] else shop
 if cache.has(key):return cache[key]
 var shapes=""
 match key:
  "rook":
   shapes='<path d="M32 7 10 19 32 32 54 19 32 7 32 32 32 57 10 44 10 19 M32 57 54 44 54 19" fill="none" stroke="#d3b47a" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>'
  "cook":
   shapes='<path d="M12 6H52V58H12Z" fill="#d9ccb0"/><path d="M32 18 47 32 32 46 17 32Z" fill="#aa7647"/>'
  "tailor":
   shapes='<path d="M20 14H44V50H20Z" fill="#455478"/><path d="M20 21H44M20 27H44M20 33H44M20 39H44M20 45H44" fill="none" stroke="#7e8ba8" stroke-width="2"/><ellipse cx="32" cy="13" rx="18" ry="5" fill="#d9ccb0"/><ellipse cx="32" cy="51" rx="18" ry="5" fill="#d9ccb0"/>'
  _:return null
 var picture=Image.new()
 if picture.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'+shapes+'</svg>')!=OK:return null
 cache[key]=ImageTexture.create_from_image(picture)
 return cache[key]
