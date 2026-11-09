extends RefCounted
# Complements v094 repair mat and flat straps without replacing the hero gear or NPC.
static func apply(world:Node3D):
 var shop=world.get_node_or_null("MarketExpansion/PsyStand")
 if shop==null or shop.has_node("PsyBuckleTray"):return
 var root=Node3D.new();root.name="PsyBuckleTray";shop.add_child(root)
 var b=preload("res://scripts/market_review_finish.gd");var m=b.palette()
 b.box(root,"Buckle tray base",Vector3(2.68,1.257,2.17),Vector3(.35,.026,.38),m.dark)
 for side in [-1,1]:
  b.box(root,"Buckle tray side",Vector3(2.68+side*.168,1.292,2.17),Vector3(.014,.07,.38),m.wood)
  b.box(root,"Buckle tray end",Vector3(2.68,1.292,2.17+side*.183),Vector3(.35,.07,.014),m.wood)
 for i in range(2):
  var x=2.60+i*.16
  for dx in [-.045,.045]:b.box(root,"Loose buckle side",Vector3(x+dx,1.279,2.17),Vector3(.012,.015,.10),m.bronze)
  for dz in [-.046,.046]:b.box(root,"Loose buckle end",Vector3(x,1.279,2.17+dz),Vector3(.10,.015,.012),m.bronze)
 b.seal(root,preload("res://scripts/rook_shop_art.gd"))
 root.set_meta("service_available",false)
