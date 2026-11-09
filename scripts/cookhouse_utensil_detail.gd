extends RefCounted
# Existing Cookhouse board and serving tray only. No station, collider or gameplay edits.
const Controller=preload('res://scripts/rook_material_detail.gd')
const Builder=preload('res://scripts/rook_shop_art.gd')
static func apply(dressing:Node3D):
 assert(dressing.name=='WestCookingDressing' and dressing.has_node('PrepBoard') and dressing.has_node('ServingBowls'))
 assert(not dressing.has_node('MaterialDetail'))
 var m={};var c=Controller.configure(dressing,m)
 c.joinery=Node3D.new();c.joinery.name='HighJoinery';c.add_child(c.joinery)
 c.stock=Node3D.new();c.stock.name='MaxShopGoods';c.add_child(c.stock)
 utensils(c,c.stock,m)
 c.seal_groups(Builder)
 c.set_meta('role','Cookhouse');c.set_meta('new_services',0)

static func utensils(c,root:Node3D,m:Dictionary):
 # One wooden spoon rests beside the original herbs, wholly over the prep board.
 Builder.box(root,'Prep spoon handle',Vector3(-.56,1.037,1.18),Vector3(.018,.014,.16),m.wood)
 Builder.sphere(root,'Prep spoon bowl',Vector3(-.56,1.039,1.29),Vector3(.050,.018,.065),m.wood)
 # A compact holder occupies the clear back corner of the existing serving tray.
 var p=Vector3(.597,1.096,1.107)
 c.cylinder(root,'Utensil holder',p,.030,.16,m.jar_teal)
 c.cylinder(root,'Holder dark opening',p+Vector3(0,.081,0),.0285,.006,m.dark)
 for i in range(2):
  var x=p.x-.014+i*.028;var z=p.z-.012+i*.022
  Builder.box(root,'Serving tool handle',Vector3(x,1.211,z),Vector3(.014,.20,.014),m.wood)
  if i==0:Builder.sphere(root,'Serving spoon head',Vector3(x,1.321,z),Vector3(.035,.052,.015),m.wood)
  else:
   Builder.box(root,'Serving spatula head',Vector3(x,1.321,z),Vector3(.040,.060,.012),m.wood)
   for dx in [-.010,.010]:Builder.box(root,'Spatula narrow slot',Vector3(x+dx,1.326,z+.0065),Vector3(.004,.032,.001),m.dark)
