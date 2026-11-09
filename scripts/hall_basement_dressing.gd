extends RefCounted
# Original decorative architectural fittings; no inventory, interaction, or assigned bays.
const F=preload('res://scripts/hall_basement_finish.gd')
static func add_to(scene:Node3D):
 var r=Node3D.new();r.name='HallBasementDressing';scene.add_child(r)
 var timber=F.plain(Color('#66503a'));var bronze=F.plain(Color('#96754c'),.6);var rust=F.plain(Color('#803e2b'));var cream=F.plain(Color('#c3ae7b'))
 var journal=[]
 for z in [-27.0,-19.0]:
  # Two shallow, intentionally empty shelving frames. Entire footprint is solid to the capsule.
  var at=Vector3(7.98,-2.55,z);var size=Vector3(.68,1.90,2.5)
  var body=StaticBody3D.new();body.name='Empty wall shelving '+str(int(-z));body.position=at;body.set_meta('audio_surface','wood');r.add_child(body)
  var shape=BoxShape3D.new();shape.size=size;var col=CollisionShape3D.new();col.shape=shape;body.add_child(col)
  journal.append({'name':body.name,'center':[at.x,at.y,at.z],'size':[size.x,size.y,size.z],'purpose':'Noninteractive empty shelf footprint; no functional storage'})
  for dz in [-1.18,1.18]:
   for x in [7.70,8.25]:
    F.box(r,'Shelf timber upright',Vector3(x,-2.55,z+dz),Vector3(.10,1.9,.10),timber)
    F.box(r,'Shelf bronze foot',Vector3(x,-3.39,z+dz),Vector3(.12,.18,.12),bronze)
  for y in [-3.40,-2.85,-2.30,-1.65]:
   F.box(r,'Empty shelf',Vector3(7.98,y,z),Vector3(.65,.08,2.48),timber)
   F.box(r,'Shelf bronze lip',Vector3(7.655,y,z),Vector3(.018,.035,2.44),bronze)
  for dz in [-1.17,1.17]:F.beam(r,Vector3(8.27,-3.3,z-dz),Vector3(8.27,-1.75,z+dz),.045,bronze)
 # A single wall-bound rust textile echoes the approved leaf motif. No text or service promise.
 F.box(r,'Rust textile',Vector3(1.85,-2.02,-31.36),Vector3(1.18,1.72,.035),rust)
 for x in [1.29,2.41]:F.box(r,'Textile woven edge',Vector3(x,-2.02,-31.335),Vector3(.025,1.68,.008),cream)
 F.box(r,'Textile bronze hanging bar',Vector3(1.85,-1.13,-31.33),Vector3(1.36,.06,.07),bronze)
 F.box(r,'Leaf stem',Vector3(1.85,-2.02,-31.33),Vector3(.035,.94,.012),cream)
 for y in [-2.33,-2.10,-1.87]:
  for side in [-1,1]:
   var leaf=F.box(r,'Woven leaf',Vector3(1.85+side*.14,y,-31.323),Vector3(.30,.085,.012),cream);leaf.rotation.z=side*.50
 # A short closed utility accent is flush to the north wall, away from the stair aperture.
 F.box(r,'Bronze utility conduit',Vector3(5.7,-1.23,-31.35),Vector3(3.2,.09,.08),bronze)
 for x in [4.15,7.25]:
  F.box(r,'Utility down return',Vector3(x,-1.52,-31.35),Vector3(.09,.65,.08),bronze)
  F.box(r,'Utility wall clamp',Vector3(x,-1.63,-31.30),Vector3(.17,.08,.04),cream)
 # Thin north-wall relief envelope covers textile/conduit projection, avoiding uncollided solid trim.
 var backing=StaticBody3D.new();backing.name='North wall relief backing';backing.position=Vector3(4.25,-2.02,-31.34);r.add_child(backing)
 var backing_shape=BoxShape3D.new();backing_shape.size=Vector3(6.2,1.85,.13);var backing_col=CollisionShape3D.new();backing_col.shape=backing_shape;backing.add_child(backing_col)
 journal.append({'name':backing.name,'center':[4.25,-2.02,-31.34],'size':[6.2,1.85,.13],'purpose':'Thin wall-bound textile and utility relief coverage'})
 r.set_meta('new_collision_journal',journal)
 preload('res://scripts/hideout_terrace.gd').batch_static_visuals(r)
 for v in r.find_children('*','GeometryInstance3D',true,false):v.layers=4096
