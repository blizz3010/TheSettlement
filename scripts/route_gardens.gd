extends RefCounted
# Original editable practical + deterministic approved-foliage composition.
# All transforms are world-space; source mesh AABBs are validated before installation.
const LAND=preload('res://scripts/market_landscape.gd')
const TERRACE=preload('res://scripts/hideout_terrace.gd')
const LAMPS=[Vector3(3.1,0,12.3),Vector3(34,0,12.8),Vector3(-14.6,0,-15),Vector3(-10.9,0,11.8)]
const TREES=[Vector3(40,0,2),Vector3(39,0,22),Vector3(-27,0,-4),Vector3(-20,0,-39)]
static func safe(b:AABB)->bool:
 # LAND already has .15m path shoulder; add .30m to meet .45m clearance.
 if not LAND._destination_safe(b.grow(.30)):return false
 # Existing trader fronts, original plot reserve and fountain plaza.
 for r in [AABB(Vector3(-10,-1,32.5),Vector3(8,12,7)),AABB(Vector3(-22,-1,-10),Vector3(16,12,16)),AABB(Vector3(6,-1,-7),Vector3(12,12,14)),AABB(Vector3(-7,-1,-7),Vector3(14,12,17))]:
  if b.intersects(r):return false
 return true
static func vec(v:Vector3)->Array:return [v.x,v.y,v.z]
static func bounds_record(b:AABB)->Dictionary:return {'position':vec(b.position),'size':vec(b.size)}
static func lamp(root:Node3D,p:Vector3,scene:Node3D,index:int,materials:Dictionary):
 var api=preload('res://scripts/market_expansion.gd')
 var h=Node3D.new();h.name='Waylamp%02d'%index;h.position=p;root.add_child(h)
 var wood=materials.wood;var bronze=materials.bronze;var stone=materials.stone;var glow=materials.glow
 api.box(h,'Cut stone socket',Vector3(0,.15,0),Vector3(.56,.3,.56),stone,true)
 api.box(h,'Timber upright',Vector3(0,1.25,0),Vector3(.18,2.2,.18),wood,true)
 for y in [.38,1.88,2.2]:api.box(h,'Bronze binding',Vector3(0,y,0),Vector3(.24,.09,.24),bronze)
 api.box(h,'Lantern lower rim',Vector3(0,2.29,0),Vector3(.46,.1,.46),bronze)
 api.box(h,'Amber opaque lamp core',Vector3(0,2.61,0),Vector3(.26,.54,.26),glow)
 for x in [-.19,.19]:
  for z in [-.19,.19]:api.box(h,'Lantern cage rib',Vector3(x,2.61,z),Vector3(.055,.6,.055),bronze)
 api.box(h,'Lantern cornice',Vector3(0,2.95,0),Vector3(.52,.12,.52),bronze)
 api.box(h,'Lantern cap',Vector3(0,3.05,0),Vector3(.32,.09,.32),bronze)
 api.box(h,'Cap finial',Vector3(0,3.15,0),Vector3(.09,.15,.09),bronze)
 # Four short-range practicals, never shadow maps or global exposure changes.
 var l=OmniLight3D.new();l.name='Warm practical';h.add_child(l);l.position=Vector3(0,2.58,0)
 l.light_color=Color('#ffd39a');l.light_energy=.65;l.omni_range=4.2;l.omni_attenuation=1.6;l.shadow_enabled=false
 l.distance_fade_enabled=true;l.distance_fade_begin=24;l.distance_fade_length=10
 return h
static func add_to(scene:Node3D):
 assert(not scene.has_node('RouteGardens'))
 var root=Node3D.new();root.name='RouteGardens';scene.add_child(root)
 var journal=[];var groups={};var triangles=0
 var api=preload('res://scripts/market_expansion.gd')
 var timber=api.mat(Color('#967752'));timber.resource_name='Oiled_Timber_Waylamp'
 var glow=api.mat(Color('#ffd58b'));glow.emission_enabled=true;glow.emission=Color('#ffc266');glow.emission_energy_multiplier=1.3
 var materials={'wood':preload('res://scripts/architecture_materials.gd').styled_material(timber),'bronze':scene.courtyard_material('waylamp_bronze',Color('#9b7944'),'bronze'),'stone':scene.courtyard_material('waylamp_stone',Color('#777362')),'glow':glow}
 for i in range(LAMPS.size()):
  var p:Vector3=LAMPS[i];var b=AABB(p-Vector3(.28,0,.28),Vector3(.56,3.3,.56))
  assert(safe(b),'Unsafe lamp '+str(p));lamp(root,p,scene,i,materials)
  journal.append({'kind':'lamp','at':vec(p),'bounds':bounds_record(b)})
 var assets=['kit/border_tree_a','kit/border_tree_b','groundcover/ground_grass_a','groundcover/ground_shrub_a','groundcover/ground_fern_a']
 for a in assets:groups[a]=[]
 for i in range(TREES.size()):groups[assets[i%2]].append(Transform3D(Basis(Vector3.UP,i*1.7),TREES[i]))
 # Low irregular ribbons outside path shoulders; no new soil discs or pots.
 var beds=[Vector3(3.4,0,11.2),Vector3(35,0,14.3),Vector3(34.9,0,12.5),Vector3(-15,0,-16),Vector3(-11.5,0,10.7)]
 for k in range(beds.size()):
  for i in range(38):
   var p= beds[k]+Vector3(sin(i*2.399)*(.5+(i%4)*.26),-.04,cos(i*2.399)*(.5+(i%7)*.45))
   var asset=assets[3 if i%9==0 else (4 if i%7==0 else 2)]
   groups[asset].append(Transform3D(Basis(Vector3.UP,i*.93).scaled(Vector3.ONE*(.8+(i%3)*.13)),p))
 var count=0;var rejected=0
 for asset in assets:
  var source=load('res://assets/'+asset+'.glb').instantiate();var nodes=source.find_children('*','MeshInstance3D',true,false)
  assert(nodes.size()==1 and nodes[0].transform.is_equal_approx(Transform3D.IDENTITY));var mesh=nodes[0].mesh;var accepted=[]
  for t in groups[asset]:
   var b:AABB=t*mesh.get_aabb()
   if not safe(b):rejected+=1;continue
   accepted.append(t);journal.append({'kind':asset,'origin':vec(t.origin),'basis':[vec(t.basis.x),vec(t.basis.y),vec(t.basis.z)],'bounds':bounds_record(b)})
  var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=accepted.size()
  for i in range(accepted.size()):mm.set_instance_transform(i,accepted[i])
  var batch=MultiMeshInstance3D.new();batch.name=asset.get_file();batch.multimesh=mm;batch.set_meta('source_transforms',accepted);batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(batch)
  count+=accepted.size();triangles+=mesh.get_faces().size()/3*accepted.size();source.free()
  if 'tree' in asset:
   for t in accepted:
    var body=StaticBody3D.new();body.name='Tree trunk';body.position=t.origin+Vector3(0,1.2,0);root.add_child(body)
    var c=CollisionShape3D.new();var shape=CylinderShape3D.new();shape.radius=.28;shape.height=2.4;c.shape=shape;body.add_child(c)
 # Merge repeated solid visuals by material while retaining real collision nodes.
 TERRACE.batch_static_visuals(root)
 root.set_meta('journal',journal);root.set_meta('budget',{'foliage_instances':count,'foliage_triangles':triangles,'rejected_unsafe_candidates':rejected,'foliage_batches':5,'lamp_triangles':672,'lamp_material_batches':4,'new_collision_shapes':12,'lights':4,'shadow_lights':0})
 return root
