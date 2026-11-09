extends RefCounted
# Purely visual support for the two demonstrated floating-fixture pairs.
# Original gold core retained; no emission/light, physics, NPC or service change.
static func add_one(shop:Node3D,spec:Dictionary,x:float,api,bronze:Material,glow:Material):
 var front:float=spec.depth/2-.7
 if spec.id!='Dan' and spec.id!='Atlas':
  # Preserve the praised Psy frontage exactly; shared original audited, not redesigned.
  api.box(shop,'Warm practical',Vector3(x,2.7,front),Vector3(.16,.42,.16),glow)
  return
 # Atlas core previously intersects the sign's projected lower edge (y2.67).
 # Lower only Atlas center35cm: cap top2.605 leaves6.5cm visible clearance.
 var y:float=2.35 if spec.id=='Atlas' else 2.7
 var root=Node3D.new();root.name='Supported market lantern left' if x<0 else 'Supported market lantern right';shop.add_child(root)
 api.box(root,'Original warm core',Vector3(x,y,front),Vector3(.16,.42,.16),glow)
 for side in [-1,1]:api.box(root,'Bronze lantern cap',Vector3(x,y+side*.2325,front),Vector3(.23,.045,.23),bronze)
 for dx in [-.10,.10]:
  for dz in [-.10,.10]:api.box(root,'Bronze lantern corner rail',Vector3(x+dx,y,front+dz),Vector3(.025,.42,.025),bronze)
 var cap_top:float=y+.255;var beam_contact:float=3.595
 api.box(root,'Lantern suspension stem',Vector3(x,(cap_top+beam_contact)/2,front),Vector3(.04,beam_contact-cap_top,.04),bronze)
 # Front beam is centered3.7 with24cmheight: underside3.58. Plate overlaps it15mm.
 api.box(root,'Lantern beam mounting plate',Vector3(x,3.575,front),Vector3(.14,.04,.14),bronze)
 root.set_meta('support_contacts',{'core_y':y,'top_cap_y':cap_top,'stem_top':beam_contact,'beam_underside':3.58,'no_new_lights':true,'no_collision':true,'role':spec.id})
