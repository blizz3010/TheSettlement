extends RefCounted
# Visual samples only. No inventory, interaction, physics or persistence dependencies.
static func prop(root:Node3D,file:String,n:String,p:Vector3,yaw=0.0):
 var node=load('res://assets/market_detail/'+file+'.glb').instantiate();node.name=n;root.add_child(node);node.position=p;node.rotation.y=yaw
 node.set_meta('art_sample_only',true)
 return node
static func apply(shop:Node3D,spec:Dictionary,api,materials:Dictionary):
 var holder=Node3D.new();holder.name='OfferingDetail';shop.add_child(holder)
 var front:float=spec.depth/2-.7;var back:float=-spec.depth/2+.3
 var wood=materials.wood;var bronze=materials.bronze;var dark=materials.dark;var cream=materials.cream
 if spec.id=='Psy':
  # Hero physical visor helmet on the counter; varied vest and pack on the backwall.
  prop(holder,'psy_visor_helmet','Bronze framed visor helmet',Vector3(-2.1,1.22,front-.60),.12)
  prop(holder,'psy_field_vest','Layered field vest',Vector3(0,1.18,back+.68))
  prop(holder,'psy_expedition_pack','Strapped expedition pack',Vector3(2.0,1.095,back+.7),-.12)
  prop(holder,'psy_visor_helmet','Side shelf helmet',Vector3(-2.0,1.53,back+.68),-.15)
  for x in [-2.0,2.0]:
   api.box(holder,'Gear display shelf',Vector3(x,1.49 if x<0 else 1.08,back+.67),Vector3(1.1,.09,.68),wood)
   for side in [-1,1]:api.box(holder,'Shelf bronze cleat',Vector3(x+side*.4,1.37 if x<0 else .96,back+.45),Vector3(.08,.24,.30),bronze)
  api.box(holder,'Vest hanger hook',Vector3(0,2.28,back+.59),Vector3(.08,.18,.16),bronze)
  api.box(holder,'Vest hanger crosspiece',Vector3(0,2.2,back+.57),Vector3(.59,.07,.10),wood)
 elif spec.id=='Atlas':
  prop(holder,'atlas_returns','Tagged return parcels',Vector3(-1.35,1.24,front-.62))
  # Low utility status windows and real latch housings distinguish the lockers.
  for i in range(4):
   var x=-2.0+i*1.35
   api.box(holder,'Locker recessed slot',Vector3(x,2.18,back+.90),Vector3(.48,.065,.025),dark)
   api.box(holder,'Locker collection seal',Vector3(x+.29,1.57,back+.92),Vector3(.12,.17,.055),bronze)
   for y in [1.18,1.28,1.38]:api.box(holder,'Locker lower vent',Vector3(x,y,back+.90),Vector3(.56,.024,.02),dark)
 else:
  prop(holder,'dan_consignment','Consignment inspection set',Vector3(-1.2,1.24,front-.62))
  # Varied physical listing cards; decorative layout, no item names, prices or live data.
  var heights=[.36,.48,.40,.50,.32,.43];var tilts=[-.06,.035,-.04,.025,-.035,.05];var i=0
  for x in [-1.25,0,1.25]:
   for y in [1.65,2.35]:
    var card=api.box(holder,'Pinned varied listing',Vector3(x,y,back+.435),Vector3(.64+(i%2)*.12,heights[i],.025),cream);card.rotation.z=tilts[i]
    api.box(holder,'Listing pin',Vector3(x,y+heights[i]/2-.035,back+.46),Vector3(.045,.045,.025),bronze)
    for line in range(3):api.box(holder,'Listing handwritten rule',Vector3(x-.05,y+.07-line*.075,back+.455),Vector3(.42-(line%2)*.1,.018,.012),dark)
    i+=1
  for side in [-1,1]:
   var x=side*3.4
   api.box(holder,'Closed cubby parcel',Vector3(x,.78,back+1.0),Vector3(.56,.23,.30),wood)
   api.box(holder,'Parcel securing band',Vector3(x,.78,back+1.16),Vector3(.07,.24,.025),bronze)
   for j in range(3):api.box(holder,'Cubby ledger spine',Vector3(x-.23+j*.18,1.48,back+.94),Vector3(.12,.30,.30),cream if j==1 else wood)
 var meshes=holder.find_children('*','MeshInstance3D',true,false);var triangles=0;var surfaces=0
 for mesh in meshes:
  triangles+=mesh.mesh.get_faces().size()/3;surfaces+=mesh.mesh.get_surface_count()
 assert(holder.find_children('*','CollisionObject3D',true,false).is_empty())
 holder.set_meta('detail_budget',{'triangles_before_batch':triangles,'surfaces_before_batch':surfaces,'physics':false,'functional_stock':false})
