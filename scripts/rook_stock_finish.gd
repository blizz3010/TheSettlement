extends RefCounted
# Essential supply families, not inventory or collision. Existing tool wall stays intact.
static func apply(art:Node3D,m:Dictionary,b):
 var root=Node3D.new();root.name="RookStockIdentity";art.add_child(root)
 # Both rear corners are outside the clear center aisle and behind the transaction line.
 for row in range(4):
  for lane in range(3):b.box(root,"Bound timber stock",Vector3(-2.72+lane*.22,.15+row*.15,-2.52),Vector3(.19,.13,.77),m.wood)
 for x in [-2.78,-2.22]:b.box(root,"Timber retaining strap",Vector3(x,.385,-2.52),Vector3(.035,.60,.80),m.bronze)
 b.box(root,"Stone sorting bin floor",Vector3(2.62,.14,-2.48),Vector3(.91,.08,.79),m.wood)
 for side in [-1,1]:
  b.box(root,"Stone bin end",Vector3(2.62+side*.44,.29,-2.48),Vector3(.055,.30,.79),m.wood)
  b.box(root,"Stone bin lip",Vector3(2.62,.25,-2.48+side*.37),Vector3(.91,.22,.05),m.wood)
 for i in range(8):b.sphere(root,"Sorted rough stone",Vector3(2.34+(i%3)*.27,.28+(i/3)*.09,-2.70+(i%2)*.36),Vector3(.24,.18,.25),m.stone)
 b.box(root,"Open scrap sorting drawer",Vector3(2.62,.72,-2.62),Vector3(.88,.08,.52),m.dark)
 for side in [-1,1]:b.box(root,"Scrap drawer rim",Vector3(2.62+side*.43,.81,-2.62),Vector3(.035,.18,.52),m.bronze)
 for i in range(5):
  var scrap=b.box(root,"Metal offcut",Vector3(2.32+i*.14,.80+(i%2)*.03,-2.62),Vector3(.095,.055,.36),m.blade);scrap.rotation.y=(i-2)*.12
 b.box(root,"Scrap drawer label",Vector3(2.62,.79,-2.346),Vector3(.29,.12,.015),m.cloth)
 for x in [-2.52,2.62]:b.label(root,"Material stock label","TIMBER" if x<0 else "STONE / SCRAP",Vector3(x,.93,-2.22),22,.003,Color("e9dcc0"))
 # Replace the lower sample-row's first three crystal cells with the actual sold materials.
 var display=art.get_node("Mineral specimen wall")
 for mesh in display.get_children():
  if mesh is MeshInstance3D and str(mesh.name).begins_with("Faceted mineral specimen") and mesh.position.y<.7 and mesh.position.x<.3:mesh.free()
 for i in range(3):b.box(display,"Timber sample",Vector3(-1.95+i*.18,.65,.13),Vector3(.13,.19,.28),m.wood)
 for i in range(3):b.sphere(display,"Stone sample",Vector3(-1.06+i*.18,.65,.13),Vector3(.17,.20,.22),m.stone)
 for i in range(3):b.box(display,"Scrap sample",Vector3(-.19+i*.18,.63,.13),Vector3(.13,.12,.28),m.blade)
 for child in display.get_children():
  if child is Label3D and child.name=="Specimen wall title":child.text="SUPPLIES & MINERALS"
 # Preserve two broad work-plan rolls on the supported counter, without extra Max-only jars.
 for i in range(2):
  var roll=MeshInstance3D.new();roll.name="Rolled work plan";var mesh=CylinderMesh.new();mesh.top_radius=.055;mesh.bottom_radius=.055;mesh.height=.48;mesh.radial_segments=12;roll.mesh=mesh;roll.material_override=m.cloth;roll.position=Vector3(.22+i*.16,1.205,-1.57);roll.rotation.z=PI/2;root.add_child(roll)
 root.set_meta("all_quality_tiers",true)
 root.set_meta("stock_families",["timber","stone","metal"])
 assert(root.find_children("*","CollisionObject3D",true,false).is_empty())
