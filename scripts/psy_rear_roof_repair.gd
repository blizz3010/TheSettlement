extends RefCounted
# Close the raised outfitter canopy's rear gap without altering existing solids.
static func add_to(scene:Node3D):
 var shop=scene.get_node('MarketExpansion/PsyStand')
 assert(not shop.has_node('RearRoofRepair'))
 var api=preload('res://scripts/market_expansion.gd')
 var repair=Node3D.new();repair.name='RearRoofRepair';shop.add_child(repair)
 var timber=preload('res://scripts/market_wall_finish.gd').wood()
 var cream=api.mat(Color('#c9bc98'))
 var bronze=scene.courtyard_material('market_bronze',Color('#9b7944'),'bronze')
 # Old rear posts end at 3.75. New caps meet the beam underside at 4.325.
 for x in [-3.75,3.75]:
  api.box(repair,'Rear post extension',Vector3(x,4.04,-3.2),Vector3(.2,.60,.2),timber)
  api.box(repair,'Rear extension join',Vector3(x,3.75,-3.2),Vector3(.23,.10,.23),bronze)
 # Existing rear sheet ends at 3.50. Overlap by 1 cm; reach the raised beam.
 api.box(repair,'Rear upper wall infill',Vector3(0,3.91,-3.2),Vector3(7.6,.84,.18),cream,true)
 # Broad uprights carry the original rear-wall bay rhythm into the infill.
 for x in [-3.7,-8.0/6.0,8.0/6.0,3.7]:
  api.box(repair,'Rear upper bay upright',Vector3(x,3.92,-3.34),Vector3(.16,.84,.16),timber)
 repair.set_meta('repair_journal',{'original_solids_changed':0,'new_colliders':1,'post_old_top':3.75,'post_new_top':4.34,'wall_old_top':3.5,'wall_new_top':4.33,'beam_bottom':4.325})
 preload('res://scripts/shop_surround_detail.gd').finish_repair(shop,repair)
 return repair
