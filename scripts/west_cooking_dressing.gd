extends RefCounted
# Presentation only. Cookhouse service is separate; original colliders are untouched.
const KEY='west_cooking_dressing'
const Display=preload('res://scripts/trader_material_displays.gd')
static func fail(reason:String)->Dictionary:return {'ok':false,'reason':reason}
static func valid(world,shop,r:Dictionary)->bool:
 if not is_instance_valid(world) or not is_instance_valid(shop):return false
 if not world is Node3D or not shop is Node3D or world.is_queued_for_deletion() or shop.is_queued_for_deletion():return false
 if r.get('owner_id',0)!=world.get_instance_id() or r.get('shop_id',0)!=shop.get_instance_id():return false
 if not r.get('root') is WeakRef:return false
 var root=r.root.get_ref()
 if not is_instance_valid(root) or root.is_queued_for_deletion() or root.get_parent()!=world or root.transform!=shop.transform:return false
 if not r.get('hidden') is Array or r.hidden.size()!=3:return false
 for row in r.hidden:
  if not row is Dictionary or not row.get('node') is WeakRef:return false
  var node=row.node.get_ref()
  if not is_instance_valid(node) or node.is_queued_for_deletion() or node.get_parent()!=world.get_node_or_null('WestTraderMaterialExamples') or node.visible:return false
 return true
static func apply(world:Node3D,shop:Node3D)->Dictionary:
 if not is_instance_valid(world) or not is_instance_valid(shop) or world.is_queued_for_deletion() or shop.is_queued_for_deletion():return fail('West shop unavailable')
 if shop.get_parent()!=world or shop.name!='WestTraderFrontage' or shop.position.distance_to(Vector3(-7,0,2))>.001 or absf(shop.rotation.y-PI/2)>.001:return fail('Wrong west shop identity')
 if world.has_meta(KEY):
  var old=world.get_meta(KEY)
  if not old is Dictionary or not valid(world,shop,old):return fail('Foreign or stale cooking display')
  return {'ok':true,'reused':true}
 if world.has_node('WestCookingDressing'):return fail('Foreign cooking display root')
 var examples=world.get_node_or_null('WestTraderMaterialExamples')
 if examples==null or not examples is Node3D or examples.transform!=shop.transform:return fail('Material displays unavailable')
 var hidden=[]
 for name in ['IntakeLedger','ScrapSortingBin','WeighingScale']:
  var node=examples.get_node_or_null(name)
  if not node is Node3D or node.is_queued_for_deletion():return fail('Expected material display missing')
  hidden.append({'node':weakref(node),'visible':node.visible})
 var root=Node3D.new();root.name='WestCookingDressing';root.transform=shop.transform
 var wood=Display.material('78533a');var cream=Display.material('d9ccb0');var bronze=Display.material('997246',.55);var green=Display.material('61775a');var iron=Display.material('30443f')
 var prep=Display.group(root,'PrepBoard',Vector3(-.425,.98,1.21))
 Display.box(prep,'Cutting board',Vector3(0,.025,0),Vector3(.34,.05,.29),wood)
 # Fish display and herb rail are added by CookingPrepV095, leaving this board clear.
 Display.plaque(prep,'PREP',.17,.34,bronze)
 var bowls=Display.group(root,'ServingBowls',Vector3(.425,.98,1.21))
 Display.tray(bowls,.46,.32,bronze,wood)
 for i in range(2):
  Display.cylinder(bowls,'Bowl'+str(i),Vector3(-.10+i*.20,.105,0),.08,.11,cream)
  Display.cylinder(bowls,'Bowl inset'+str(i),Vector3(-.10+i*.20,.162,0),.065,.006,iron)
 Display.plaque(bowls,'COOK',.17,.34,bronze)
 # A single shop-side marker shares the griddle's timber/bronze palette.
 var side=Display.group(root,'CookingSidePlaque',Vector3(-1.36,1.48,.0))
 side.rotation.y=-PI/2
 Display.box(side,'Timber plaque',Vector3.ZERO,Vector3(.90,.28,.035),wood)
 Display.box(side,'Bronze header',Vector3(0,.105,.02),Vector3(.90,.025,.015),bronze)
 var label=Label3D.new();label.name='CookhouseSideLabel';label.text='COOKHOUSE';label.position=Vector3(0,0,.024);label.font_size=36;label.pixel_size=.0020;label.modulate=Color('f0dfb6');label.outline_size=2;side.add_child(label)
 # All preparation completed before altering the three owned presentation groups.
 world.add_child(root)
 preload('res://scripts/cookhouse_utensil_detail.gd').apply(root)
 preload('res://scripts/market_review_finish.gd').cook(root,load('res://scripts/rook_shop_art.gd'))
 preload('res://scripts/cooking_prep_detail.gd').apply(root)
 for row in hidden:row.node.get_ref().hide()
 var receipt={'owner_id':world.get_instance_id(),'shop_id':shop.get_instance_id(),'root':weakref(root),'hidden':hidden}
 world.set_meta(KEY,receipt)
 return {'ok':true,'reused':false}
static func restore(world,shop)->Dictionary:
 if not is_instance_valid(world) or not world is Node3D or world.is_queued_for_deletion() or not world.has_meta(KEY):return fail('No owned display')
 var receipt=world.get_meta(KEY)
 if not receipt is Dictionary or not valid(world,shop,receipt):return fail('Stale restore refused')
 for row in receipt.hidden:row.node.get_ref().visible=row.visible
 receipt.root.get_ref().free();world.remove_meta(KEY)
 return {'ok':true}
