extends RefCounted
# Bounded review finish. Static presentation only, inside existing shop envelopes.
# No services, NPC transforms, counters, collision, lights, paths or saves change.
static func material(hex:String,rough=.9,metal=.0)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=Color(hex);m.roughness=rough;m.metallic=metal;return m
static func box(root:Node3D,n:String,p:Vector3,size:Vector3,m:Material)->MeshInstance3D:
 var node=MeshInstance3D.new();node.name=n;node.position=p;var mesh=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.material_override=m;root.add_child(node,true);return node
static func beam(root:Node3D,n:String,a:Vector3,b:Vector3,width:float,m:Material):
 var node=box(root,n,(a+b)/2,Vector3(width,width,a.distance_to(b)),m);node.basis=Basis.looking_at(b-a,Vector3.RIGHT if absf((b-a).normalized().y)>.99 else Vector3.UP);return node
static func label(root:Node3D,n:String,text:String,p:Vector3,size:float):
 var node=Label3D.new();node.name=n;node.text=text;node.position=p;node.font_size=32;node.pixel_size=size;node.modulate=Color('#f0dfb8');node.outline_modulate=Color('#302e28');node.outline_size=2;node.no_depth_test=false;root.add_child(node,true);return node
static func palette()->Dictionary:return {'wood':material('#685039'),'dark':material('#303b36'),'bronze':material('#9b7944',.64,.45),'linen':material('#cbbc99'),'teal':material('#426964'),'rust':material('#935743'),'leather':material('#65503b'),'stone':material('#bcaf97')}
static func group(root:Node3D,name:String)->Node3D:
 var node=Node3D.new();node.name=name;root.add_child(node,true);return node
static func seal(root:Node3D,builder):
 var bounds=AABB();var first=true;var triangles=0;var pieces=[]
 for mesh in root.find_children('*','MeshInstance3D',true,false):
  var b=(root.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb();bounds=b if first else bounds.merge(b);first=false
  triangles+=mesh.mesh.get_faces().size()/3;pieces.append({'name':str(mesh.name),'bounds':b})
 assert(root.find_children('*','CollisionObject3D',true,false).is_empty())
 assert(root.find_children('*','Light3D',true,false).is_empty())
 root.set_meta('review_budget',{'triangles':triangles,'bounds':bounds,'pieces':pieces,'new_collisions':0,'new_lights':0,'new_services':0,'all_quality_tiers':true})
 builder.batch_static(root)
 # Review labels share the same distance boundary as their physical backings.
 # Main trader/service signs are outside this bounded review root and unchanged.
 for mesh in root.find_children('*','GeometryInstance3D',true,false):
  if mesh is MeshInstance3D:mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  mesh.visibility_range_end=42;mesh.visibility_range_end_margin=4
static func apply(shop:Node3D,spec:Dictionary,builder):
 assert(not shop.has_node('MarketReviewFinish'))
 var r=group(shop,'MarketReviewFinish');var m=palette()
 if spec.id=='Psy':psy(r,m)
 elif spec.id=='Atlas':atlas(r,m)
 else:
  var notices=0
  for node in shop.get_children():
   if node is Label3D and node.text=='STARTER CLOTHING · MARKETPLACE PLANNED':node.text='PLAYER MARKETPLACE · PREVIEW';node.position.z=spec.depth/2-.7-.085;notices+=1
  assert(notices==1,'Keep the one original accurate Dan service notice in front of its plaque')
  dan_cards(shop,r,m)
  dan_market(r,m)
  shop.set_meta('service_status','player_marketplace_preview')
 side_role(r,spec,m)
 seal(r,builder)
 shop.set_meta('market_review_finish',{'ids':['MK04','MK11'] if spec.id=='Psy' else (['MK05','MK11'] if spec.id=='Atlas' else ['MK07','MK08','MK11']),'decorative_only':true})
static func psy(r:Node3D,m:Dictionary):
 # Existing slats already provide the counter recess/joinery. One quiet mat and
 # two straps occupy its far right end; hero gear and staff remain unobstructed.
 box(r,'Gear repair mat',Vector3(2.00,1.247,2.17),Vector3(.86,.014,.50),m.teal)
 for x in [1.76,2.05]:
  box(r,'Flat leather repair strap',Vector3(x,1.260,2.17),Vector3(.075,.012,.37),m.leather)
  for dx in [-.042,.042]:box(r,'Strap buckle side',Vector3(x+dx,1.272,2.30),Vector3(.012,.012,.075),m.bronze)
  for z in [2.267,2.333]:box(r,'Strap buckle end',Vector3(x,1.272,z),Vector3(.095,.012,.012),m.bronze)
static func atlas(r:Node3D,m:Dictionary):
 # A closed ledger complements the existing left parcel and right sorting tray.
 box(r,'Recovery ledger pages',Vector3(2.62,1.2745,2.64),Vector3(.31,.045,.32),m.linen)
 for y in [1.246,1.303]:box(r,'Recovery ledger cover',Vector3(2.62,y,2.64),Vector3(.34,.012,.35),m.teal)
 box(r,'Recovery ledger spine',Vector3(2.455,1.275,2.64),Vector3(.018,.065,.35),m.teal)
 for i in range(4):
  var x=-2.0+i*1.35
  box(r,'Locker number plate',Vector3(x,2.70,-2.789),Vector3(.23,.12,.012),m.dark)
  label(r,'Locker number '+str(i+1),'0'+str(i+1),Vector3(x,2.70,-2.78),.0018)
static func dan_cards(shop:Node3D,r:Node3D,m:Dictionary):
 # Remove both old template layers and their decorative pins/ink before batching.
 # The board, frame, heading and live/planned-service messages are retained.
 var removed=0
 for parent in [shop,shop.get_node('OfferingDetail')]:
  for node in parent.get_children():
   if not node is Node3D:continue
   var old=false
   for mesh in node.get_children():
    if not mesh is MeshInstance3D:continue
    var b=(shop.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb()
    if b.position.x>=-1.80 and b.end.x<=1.80 and b.position.y>=1.30 and b.end.y<=2.65 and b.position.z>=-2.83 and b.end.z<=-2.70:old=true
   if old:node.free();removed+=1
 assert(removed==54,'Exact two-layer notice template and ink/pins must be selected')
 # Five unequal papers aligned to a quiet two-row grid, with one deliberate gap.
 var cards=[[Vector2(-1.25,2.40),Vector2(.62,.35)],[Vector2(-.30,2.29),Vector2(.74,.56)],[Vector2(1.11,2.38),Vector2(.84,.40)],[Vector2(-1.16,1.64),Vector2(.78,.40)],[Vector2(.21,1.63),Vector2(.57,.32)]]
 for i in range(cards.size()):
  var p:Vector2=cards[i][0];var s:Vector2=cards[i][1]
  box(r,'Maintained notice paper',Vector3(p.x,p.y,-2.785),Vector3(s.x,s.y,.02),m.linen)
  box(r,'Notice pin',Vector3(p.x,p.y+s.y*.5-.03,-2.765),Vector3(.035,.035,.018),m.bronze)
  if i==1:
   box(r,'Current clothing note accent',Vector3(p.x,p.y+s.y*.5-.08,-2.769),Vector3(s.x-.08,.07,.008),m.teal)
   label(r,'Current clothing note','PLAYER\nLISTINGS',Vector3(p.x,p.y,-2.765),.00135)
  else:
   for j in range(2):box(r,'Neutral notice rule',Vector3(p.x-.03,p.y+.035-j*.075,-2.771),Vector3(s.x*(.64 if j==0 else .44),.012,.007),m.dark)
 r.set_meta('notice_cards',cards.size());r.set_meta('replaced_notice_parts',removed)
static func dan_market(r:Node3D,m:Dictionary):
 # Reachable objects retain Dan's existing face/scale and original counter.
 var p=Vector3(-1.5,1.27,2.13)
 box(r,'Compact listing ledger pages',p,Vector3(.48,.045,.38),m.linen)
 for y in [-.03,.03]:box(r,'Compact ledger cover',p+Vector3(0,y,0),Vector3(.52,.015,.42),m.teal)
 box(r,'Reachable stamp pad',Vector3(-.95,1.275,2.18),Vector3(.22,.055,.19),m.dark)
 box(r,'Listing stamp block',Vector3(-.66,1.28,2.16),Vector3(.14,.075,.14),m.wood)
 box(r,'Listing stamp grip',Vector3(-.66,1.36,2.16),Vector3(.065,.10,.065),m.bronze)
 # A lower side conversation shelf adds reach without raising/altering Dan.
 box(r,'Lower conversation shelf',Vector3(.65,.98,2.79),Vector3(1.05,.08,.34),m.wood)
 label(r,'Conversation shelf note','LISTINGS',Vector3(.65,.92,2.97),.0018)
static func tailor_clothing_display(r:Node3D,m:Dictionary):
 # Exact v094 folded garment geometry, now constructed only in TailorAtelier.
 # Core clothing cues remain visible at every material tier.
 var jacket=Vector3(-2.55,1.28,2.13)
 box(r,'Folded starter jacket body',jacket,Vector3(.72,.08,.43),m.teal)
 for side in [-1,1]:
  var sleeve=box(r,'Folded jacket sleeve',jacket+Vector3(side*.22,.055,.015),Vector3(.20,.04,.36),m.teal);sleeve.rotation.y=side*.13
  var collar=box(r,'Jacket folded collar',jacket+Vector3(side*.075,.065,-.13),Vector3(.12,.025,.15),m.linen);collar.rotation.y=side*.40
 box(r,'Jacket front seam',jacket+Vector3(0,.085,.03),Vector3(.014,.008,.24),m.dark)
 # A pair of boots replaces the left notions jars, away from the central interaction.
 for x in [-3.95,-3.52]:
  box(r,'Starter boot sole',Vector3(x,1.2575,2.13),Vector3(.23,.035,.38),m.dark)
  box(r,'Starter boot foot',Vector3(x,1.325,2.14),Vector3(.21,.10,.35),m.leather)
  box(r,'Starter boot ankle',Vector3(x,1.438,2.04),Vector3(.18,.22,.17),m.leather)
  box(r,'Boot top opening',Vector3(x,1.55,2.04),Vector3(.13,.008,.12),m.dark)
 for i in range(3):box(r,'Fabric sample swatch',Vector3(-2.75+i*.20,1.247,2.53),Vector3(.135,.014,.22),[m.linen,m.rust,m.teal][i])
 # Clothing service guidance now belongs to the tailor, not Dan.
static func side_role(r:Node3D,spec:Dictionary,m:Dictionary):
 var side=group(r,'Service side cluster');side.position=Vector3(spec.width/2-.13,0,-.45);side.rotation.y=PI/2
 # All wall-mounted clusters stay over existing plinth and away from feet/routes.
 box(side,'Wall mounted timber rail',Vector3(0,1.95,0),Vector3(1.22,.12,.05),m.wood)
 for x in [-.48,.48]:
  box(side,'Rail wall fixing',Vector3(x,1.95,.032),Vector3(.045,.06,.018),m.bronze)
 if spec.id=='Psy':
  for x in [-.32,.32]:
   beam(side,'Gear hook stem',Vector3(x,1.95,.03),Vector3(x,1.95,.09),.025,m.bronze)
   beam(side,'Gear hook lip',Vector3(x,1.95,.09),Vector3(x,2.00,.09),.025,m.bronze)
   for dx in [-.04,.04]:box(side,'Hanging gear strap',Vector3(x+dx,1.60,.075),Vector3(.035,.64,.016),m.leather)
   box(side,'Strap loop base',Vector3(x,1.287,.075),Vector3(.10,.035,.016),m.leather)
 elif spec.id=='Atlas':
  for x in [-.29,.29]:
   box(side,'Return storage envelope',Vector3(x,1.65,.065),Vector3(.43,.45,.07),m.teal)
   box(side,'Storage envelope flap',Vector3(x,1.84,.105),Vector3(.43,.09,.015),m.dark)
   box(side,'Blank storage tag',Vector3(x+.08,1.73,.116),Vector3(.09,.14,.009),m.linen)
 else:
  for i in range(3):
   var x=-.37+i*.37
   box(side,'Numbered parcel cubby',Vector3(x,1.60,.09),Vector3(.32,.46,.18),m.wood)
   box(side,'Parcel cubby opening',Vector3(x,1.60,.187),Vector3(.26,.37,.016),m.dark)
   label(side,'Parcel cubby number '+str(i+1),'0'+str(i+1),Vector3(x,1.86,.202),.0015)
static func cook(dressing:Node3D,builder):
 assert(not dressing.has_node('CookingReviewFinish'))
 var r=group(dressing,'CookingReviewFinish');var m=palette()
 # Empty lined ingredient basket occupies the verified free right-hand counter gap.
 # No food/steam is generated: live griddle samples remain state-controlled.
 var p=Vector3(1.35,.98,1.21)
 box(r,'Ingredient basket base',p+Vector3(0,.016,0),Vector3(.40,.032,.29),m.wood)
 for side in [-1,1]:
  box(r,'Basket end',p+Vector3(side*.19,.095,0),Vector3(.025,.16,.29),m.wood)
  box(r,'Basket woven lip',p+Vector3(0,.095,side*.135),Vector3(.40,.16,.02),m.wood)
  for y in [.045,.09,.135]:box(r,'Basket horizontal weave',p+Vector3(0,y,side*.147),Vector3(.39,.018,.009),m.linen)
 box(r,'Basket linen lining',p+Vector3(0,.036,0),Vector3(.35,.009,.25),m.linen)
 # End-grain bands cap, rather than replace or rescale, the accepted worktop.
 for side in [-1,1]:
  box(r,'Worktop dark end grain',Vector3(side*1.750,.91,1.21),Vector3(.012,.13,.42),m.dark)
  box(r,'Matte teal counter inset',Vector3(side*.86,.49,1.411),Vector3(1.38,.48,.012),m.teal)
  for dx in [-.63,.63]:
   for y in [.29,.69]:box(r,'Fascia bronze fixing',Vector3(side*.86+dx,y,1.422),Vector3(.025,.025,.012),m.bronze)
 # The existing PREP and COOK plaques remain the only station labels.
 for x in [-.425,.425]:
  for y in [1.00,1.11]:box(r,'Station plaque quiet rim',Vector3(x,y,1.394),Vector3(.35,.014,.014),m.dark)
  for dx in [-.17,.17]:box(r,'Station plaque end rim',Vector3(x+dx,1.055,1.394),Vector3(.014,.12,.014),m.dark)
 seal(r,builder)
 dressing.set_meta('market_review_finish',{'ids':['MK01','MK02'],'empty_ingredient_basket':true,'state_driven_food_unchanged':true})
static func rook(art:Node3D,builder,m:Dictionary):
 assert(not art.has_node('RookReviewFinish'))
 var r=group(art,'RookReviewFinish')
 # The original finished shop remains the benchmark. Two narrow side framing
 # bays and a rear sill complete its public orbit without changing its shell.
 for side in [-1,1]:
  for z in [-3.0,0.0,3.0]:
   box(r,'Side finishing timber stile',Vector3(side*3.711,2.17,z),Vector3(.045,3.12,.10),m.wood)
  box(r,'Side quiet timber sill',Vector3(side*3.712,.65,0),Vector3(.05,.10,6.10),m.wood)
  box(r,'Side eave finishing bead',Vector3(side*3.74,3.85,0),Vector3(.05,.065,6.35),m.wood)
 for x in [-3.48,0.0,3.48]:box(r,'Rear finishing timber stile',Vector3(x,2.05,-3.211),Vector3(.10,3.55,.045),m.wood)
 box(r,'Rear dressed footing',Vector3(0,.2525,-3.22),Vector3(7.3,.565,.12),m.stone)
 box(r,'Rear quiet timber sill',Vector3(0,.60,-3.23),Vector3(7.3,.09,.05),m.wood)
 box(r,'Rear eave finishing bead',Vector3(0,3.85,-3.23),Vector3(7.45,.065,.05),m.wood)
 # Wall-fixed spare battens are a useful supply-side cluster above foot level.
 var stack=group(r,'Rook side supply stack');stack.position=Vector3(3.76,0,-1.40);stack.rotation.y=PI/2
 for y in [.95,1.75]:
  box(stack,'Supply rack rail',Vector3(0,y,0),Vector3(1.20,.08,.05),m.wood)
  for x in [-.48,.48]:box(stack,'Supply rack support',Vector3(x,y,.065),Vector3(.055,.12,.16),m.bronze)
 for i in range(4):
  box(stack,'Stacked spare timber',Vector3(-.36+i*.24,1.39,.08),Vector3(.17,1.14+i%2*.15,.07),m.wood)
 box(stack,'Supply rack retaining band',Vector3(0,1.25,.13),Vector3(1.14,.055,.025),m.bronze)
 # Woven cloth edging replaces the visually metallic runner strip at source.
 seal(r,builder)
 art.set_meta('market_review_finish',{'ids':['MK09','MK10','MK11'],'retained_emblems':2,'stock_reused':true})

static func tailor_textile_rail(side:Node3D,m:Dictionary):
 box(side,'Wall mounted timber rail',Vector3(0,1.95,0),Vector3(1.22,.12,.05),m.wood)
 for x in [-.48,.48]:box(side,'Rail wall fixing',Vector3(x,1.95,.032),Vector3(.045,.06,.018),m.bronze)
 for i in range(3):
  var x=-.37+i*.37
  box(side,'Folded textile on rail',Vector3(x,1.57,.062),Vector3(.29,.70-i*.07,.045),[m.teal,m.linen,m.rust][i])
  box(side,'Textile lower hem',Vector3(x,1.24+i*.035,.09),Vector3(.29,.028,.01),m.linen)
