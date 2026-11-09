extends RefCounted
# Small owned vector silhouettes, decoded at runtime without missing import data.
const ITEMS=['cooked_griddle_fish','cloth_linen','thread_spool','helmet_basic','armor_basic_vest','backpack_basic','rig_basic']
static var cache={}
static func texture(item:String)->Texture2D:
 if not ITEMS.has(item):return null
 if cache.has(item):return cache[item]
 var shapes=''
 if item=='cooked_griddle_fish':
  shapes='<ellipse cx="32" cy="39" rx="27" ry="17" fill="#ddd0ac"/><path d="M15 35 Q27 18 45 31 L56 25 L54 45 L45 39 Q27 49 15 35Z" fill="#c98b56" stroke="#754e36" stroke-width="3"/><path d="M26 27 L30 41 M34 26 L38 41 M41 29 L45 38" stroke="#754e36" stroke-width="3"/>'
 elif item=='cloth_linen':
  shapes='<path d="M12 14 L49 10 L55 48 L19 55 L10 45Z" fill="#d8c8a4" stroke="#8c805f" stroke-width="3"/><path d="M13 40 L50 35 M17 48 L52 42 M23 14 L27 38" stroke="#a69773" stroke-width="2"/>'
 elif item=='thread_spool':
  shapes='<path d="M23 13 L41 13 L41 51 L23 51Z" fill="#cab88e"/><path d="M18 18 L46 18 L46 46 L18 46Z" fill="#667b67"/><path d="M18 23 L46 23 M18 29 L46 29 M18 35 L46 35 M18 41 L46 41" stroke="#c7ccb2" stroke-width="2"/><ellipse cx="32" cy="12" rx="15" ry="5" fill="#a58250"/><ellipse cx="32" cy="51" rx="15" ry="5" fill="#a58250"/>'
 else:
  var gear={
   'helmet_basic':'<path d="M10 36 Q10 10 32 10 Q54 10 54 36 L49 49 H39 L36 36 H15Z" fill="#637d79"/><path d="M13 32 H50 V40 H16Z" fill="#d0b77d"/><path d="M19 33 H46 V38 H19Z" fill="#283e43"/>',
   'armor_basic_vest':'<path d="M18 9 H26 L32 20 L38 9 H46 L53 51 L32 56 L11 51Z" fill="#637d79"/><path d="M18 29 H29 V42 H18ZM35 29 H46 V42 H35Z" fill="#b4a17c"/>',
   'backpack_basic':'<rect x="15" y="13" width="34" height="43" rx="9" fill="#637d79"/><path d="M25 14 V8 H39 V14 M20 25 H44 M21 36 H43 V49 H21Z" fill="none" stroke="#d0b77d" stroke-width="4"/>',
   'rig_basic':'<path d="M17 8 H24 V33 H40 V8 H47 V54 H17Z" fill="#637d79"/><path d="M14 34 H29 V49 H14ZM35 34 H50 V49 H35Z" fill="#b4a17c"/>'}
  shapes=gear.get(item,'')
 var image=Image.new()
 if image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'+shapes+'</svg>')!=OK:return null
 cache[item]=ImageTexture.create_from_image(image)
 return cache[item]
