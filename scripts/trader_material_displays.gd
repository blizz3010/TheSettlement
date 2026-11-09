extends RefCounted
# Offering-specific visual merchandising only. Both existing counters still trade
# all three actual material categories; no stock, interaction, collision or state.
static func material(color:String,metallic:=0.0)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=Color(color);m.metallic=metallic;m.roughness=.72;return m
static func box(root:Node3D,n:String,p:Vector3,size:Vector3,m:Material)->MeshInstance3D:
 var node=MeshInstance3D.new();node.name=n;node.position=p
 var mesh=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.material_override=m;root.add_child(node);return node
static func cylinder(root:Node3D,n:String,p:Vector3,r:float,h:float,m:Material)->MeshInstance3D:
 var node=MeshInstance3D.new();node.name=n;node.position=p
 var mesh=CylinderMesh.new();mesh.top_radius=r;mesh.bottom_radius=r;mesh.height=h;mesh.radial_segments=12
 node.mesh=mesh;node.material_override=m;root.add_child(node);return node
static func tray(root:Node3D,w:float,d:float,bronze:Material,wood:Material):
 box(root,'Tray base',Vector3(0,.018,0),Vector3(w,.036,d),wood)
 for side in [-1,1]:
  box(root,'Tray end',Vector3(side*(w/2-.012),.06,0),Vector3(.024,.09,d),bronze)
  box(root,'Tray lip',Vector3(0,.06,side*(d/2-.012)),Vector3(w,.09,.024),bronze)
static func plaque(root:Node3D,text:String,z:float,width:float,bronze:Material):
 box(root,'Category plaque',Vector3(0,.075,z),Vector3(width,.12,.012),bronze)
 var label=Label3D.new();label.name='DisplayLabel';label.text=text;label.font_size=32;label.pixel_size=.0014
 label.position=Vector3(0,.075,z+.009);label.modulate=Color('f4e5bc');label.outline_size=2
 root.add_child(label)
static func group(root:Node3D,n:String,p:Vector3)->Node3D:
 var node=Node3D.new();node.name=n;node.position=p;root.add_child(node);return node
static func add_to_counter(shop:Node3D,west:bool)->void:
 var displays=Node3D.new();displays.name='WestTraderMaterialExamples' if west else 'EastTraderMaterialExamples'
 shop.get_parent().add_child(displays);displays.transform=shop.transform
 displays.set_meta('visual_only',true);displays.set_meta('accepted_categories',['timber','stone','metal_scrap'])
 displays.set_meta('presentation','material_intake' if west else 'retail_samples')
 var bronze=material('997246',.55);var wood=material('78533a');var cream=material('d9ccb0')
 var stone=material('a8afa1');var metal=material('687e7c',.65);var dark=material('30443f')
 if west:
  # Narrow existing gaps between the unchanged counter's cases. No timber pile.
  var scale=group(displays,'WeighingScale',Vector3(-1.39,.98,1.21))
  box(scale,'Scale foot',Vector3(0,.035,0),Vector3(.46,.07,.32),dark)
  cylinder(scale,'Scale stem',Vector3(0,.18,0),.045,.25,bronze)
  cylinder(scale,'Weighing pan',Vector3(0,.325,0),.20,.035,bronze)
  cylinder(scale,'Pan inset',Vector3(0,.346,0),.17,.008,metal)
  plaque(scale,'WEIGH',.17,.34,bronze)
  var ledger=group(displays,'IntakeLedger',Vector3(-.425,.98,1.21))
  box(ledger,'Ledger leather',Vector3(0,.025,0),Vector3(.34,.05,.29),wood)
  box(ledger,'Ledger pages',Vector3(0,.057,-.005),Vector3(.30,.014,.26),cream)
  box(ledger,'Ledger spine',Vector3(-.145,.065,0),Vector3(.035,.025,.29),bronze)
  for i in range(4):box(ledger,'Receipt rule',Vector3(.02,.066,-.075+i*.045),Vector3(.20,.003,.006),dark)
  plaque(ledger,'INTAKE',.17,.34,bronze)
  var sorter=group(displays,'ScrapSortingBin',Vector3(.425,.98,1.21))
  tray(sorter,.46,.32,bronze,wood)
  box(sorter,'Sorting divider',Vector3(0,.09,0),Vector3(.018,.12,.28),bronze)
  # Left bay holds existing scrap-category examples; right bay is visibly empty.
  for i in range(3):
   var scrap=box(sorter,'Sorted scrap',Vector3(-.11,.08+i*.023,-.03+i*.04),Vector3(.14,.022,.10),metal)
   scrap.rotation.y=-.25+i*.18
  plaque(sorter,'SORT',.17,.34,bronze)
 else:
  var timber=group(displays,'TimberRetailSamples',Vector3(-1.08,.98,.65))
  tray(timber,.50,.34,bronze,wood)
  # Three small flat cut samples, not the old strapped timber bundle.
  for i in range(3):
   box(timber,'Cut timber sample',Vector3(-.15+i*.15,.075,0),Vector3(.12,.05,.25),wood)
   box(timber,'Timber sample band',Vector3(-.15+i*.15,.102,.055),Vector3(.121,.004,.025),cream)
  plaque(timber,'TIMBER',.18,.42,bronze)
  var stones=group(displays,'StoneRetailSamples',Vector3(-.36,.98,.65))
  tray(stones,.50,.34,bronze,wood)
  for i in range(3):
   var sample=box(stones,'Stone sample',Vector3(-.15+i*.15,.10,0),Vector3(.11,.12,.15),stone)
   sample.rotation.y=.12*i;sample.rotation.z=.08*(i-1)
  plaque(stones,'STONE',.18,.42,bronze)
  var metals=group(displays,'MetalRetailSamples',Vector3(.36,.98,.65))
  tray(metals,.50,.34,bronze,wood)
  for i in range(3):box(metals,'Metal offcut sample',Vector3(-.15+i*.15,.08,0),Vector3(.12,.07,.21),metal)
  plaque(metals,'SCRAP',.18,.42,bronze)
