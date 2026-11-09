extends RefCounted
## TH01–TH07 retained finish plus bounded H02/H03 reception/civic successor.
## Actual Plot Office, stairs and save code remain unchanged.
const KEY='hall_review_finish_v094'
const SHADER=preload('res://shaders/hall_surface_finish.gdshader')
const BATCH=preload('res://scripts/hideout_terrace.gd')
const ARCH=preload('res://scripts/architecture_materials.gd')
const BASEMENT_LAYER=4096
static func mat(hex:String,metal=0.0)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=Color(hex);m.roughness=.84;m.metallic=metal;return m
static func box(r:Node3D,n:String,p:Vector3,s:Vector3,m:Material)->MeshInstance3D:
 var v=MeshInstance3D.new();v.name=n;v.position=p;var b=BoxMesh.new();b.size=s;v.mesh=b;v.material_override=m;r.add_child(v);return v
static func beam(r:Node3D,n:String,a:Vector3,b:Vector3,w:float,m:Material):
 var v=box(r,n,(a+b)*.5,Vector3(w,a.distance_to(b),w),m);v.basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()));return v
static func label(r:Node3D,n:String,text:String,p:Vector3,size:float,turn=0.0):
 var v=Label3D.new();v.name=n;v.text=text;v.position=p;v.pixel_size=size;v.font_size=32;v.outline_size=0;v.modulate=Color('#ded0aa');v.no_depth_test=false;v.billboard=BaseMaterial3D.BILLBOARD_DISABLED;v.rotation.y=turn;r.add_child(v);return v
static func crate_number(r:Node3D,p:Vector3,number:int,m:Material):
 # Tiny physical stencil on the west-facing tag, so the crates have readable inventory marks without UI labels.
 var segments={1:[1,2],2:[0,1,6,4,3],3:[0,1,6,2,3],4:[5,6,1,2],5:[0,5,6,2,3],6:[0,5,6,4,2,3],7:[0,1,2],8:[0,1,2,3,4,5,6],9:[0,1,2,3,5,6]}
 var points=[Vector2(0,.038),Vector2(-.026,.019),Vector2(-.026,-.019),Vector2(0,-.038),Vector2(.026,-.019),Vector2(.026,.019),Vector2(0,0)]
 for segment in segments[number]:
  var d=points[segment];var horizontal=segment in [0,3,6]
  box(r,'Crate number stencil',p+Vector3(-.254,.02+d.y,d.x),Vector3(.002,.006 if horizontal else .032,.042 if horizontal else .006),m)
static func solid(r:Node3D,n:String,p:Vector3,s:Vector3,journal:Array):
 var b=StaticBody3D.new();b.name=n;b.position=p;b.set_meta('audio_surface','wood');r.add_child(b)
 var c=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=s;c.shape=shape;b.add_child(c)
 journal.append({'name':n,'center':p,'size':s,'scope':'New bounded furnishing only; existing collision unchanged'})
static func bind_local_surfaces(hall:MeshInstance3D):
 for s in range(hall.mesh.get_surface_count()):
  var original=hall.mesh.surface_get_material(s)
  if original==null or not original is StandardMaterial3D:continue
  var name=original.resource_name
  if not (name.begins_with('Limestone_') or name=='Forged_Dark_Metal'):continue
  var finish=ShaderMaterial.new();finish.shader=SHADER;finish.resource_name='HallReview_'+name
  finish.set_shader_parameter('original_tint',original.albedo_color);finish.set_shader_parameter('original_roughness',original.roughness);finish.set_shader_parameter('original_metallic',original.metallic)
  finish.set_shader_parameter('finish_kind',1 if name=='Forged_Dark_Metal' else 0)
  hall.set_surface_override_material(s,finish)
static func author_books(hall:MeshInstance3D)->Array:
 # Modify eight individual books only. Four recessed volumes make small gaps; four neighbors lean into them.
 var targets=[Vector3(-7.77,4.2,-23.16),Vector3(-7.65,4.2,-23.16),Vector3(-7.28,4.655,-27.06),Vector3(-7.16,4.655,-27.06),Vector3(-6.83,4.655,-31.26),Vector3(-6.66,4.655,-31.26),Vector3(-4.4,5.109,-31.26),Vector3(-4.23,5.109,-31.26)]
 var all=[]
 for surface in range(13,17):
  var a=hall.mesh.surface_get_arrays(surface);var v=a[Mesh.ARRAY_VERTEX];var idx=a[Mesh.ARRAY_INDEX];var parents:Array[int]=[];var welded={}
  for i in v.size():
   parents.append(i);var p=v[i];var key=Vector3i(roundi(p.x*100000),roundi(p.y*100000),roundi(p.z*100000))
   if welded.has(key):ARCH.join(parents,i,welded[key])
   else:welded[key]=i
  for i in range(0,idx.size(),3):ARCH.join(parents,idx[i],idx[i+1]);ARCH.join(parents,idx[i],idx[i+2])
  var groups={}
  for i in v.size():
   var id=ARCH.find_root(parents,i);var p=hall.global_transform*v[i]
   if groups.has(id):groups[id].bounds=groups[id].bounds.expand(p);groups[id].indices.append(i)
   else:groups[id]={'surface':surface,'bounds':AABB(p,Vector3.ZERO),'indices':[i]}
  all.append_array(groups.values())
 var changes={};var journal=[];var selected=[]
 for ti in targets.size():
  var best=null;var dist=INF
  for g in all:
   if g in selected:continue
   var base=Vector3(g.bounds.get_center().x,g.bounds.position.y,g.bounds.get_center().z)
   var d=base.distance_to(targets[ti])
   if d<dist:best=g;dist=d
  if best==null or dist>.10:continue
  selected.append(best)
  var s=best.surface
  if not changes.has(s):changes[s]=hall.mesh.surface_get_arrays(s).duplicate(true)
  var a=changes[s];var pivot=Vector3(best.bounds.get_center().x,best.bounds.position.y,best.bounds.get_center().z)
  # Recess is inside the shelf. Lean is about the foot and limited to the newly opened neighbor gap.
  var turn=Basis(Vector3.FORWARD,deg_to_rad(9.0)) if ti%2 else Basis.IDENTITY
  var offset=Vector3(0,0,-.135) if ti%2==0 else Vector3.ZERO
  var minimum=INF
  for index in best.indices:minimum=minf(minimum,(pivot+turn*(hall.global_transform*a[Mesh.ARRAY_VERTEX][index]-pivot)+offset).y)
  var lift=Vector3(0,best.bounds.position.y-minimum,0)
  for index in best.indices:
   a[Mesh.ARRAY_VERTEX][index]=hall.global_transform.affine_inverse()*(pivot+turn*(hall.global_transform*a[Mesh.ARRAY_VERTEX][index]-pivot)+offset+lift)
   a[Mesh.ARRAY_NORMAL][index]=hall.global_basis.inverse()*turn*hall.global_basis*a[Mesh.ARRAY_NORMAL][index]
   var tangent=a[Mesh.ARRAY_TANGENT]
   if tangent!=null and tangent.size()>index*4+3:
    var d=turn*Vector3(tangent[index*4],tangent[index*4+1],tangent[index*4+2]);tangent[index*4]=d.x;tangent[index*4+1]=d.y;tangent[index*4+2]=d.z
  journal.append({'surface':s,'original_bounds':best.bounds,'vertices':best.indices.size(),'kind':'recess' if ti%2==0 else 'lean'})
 # Carry unchanged packed surface data verbatim instead of re-quantizing every imported normal.
 var packed=hall.mesh.get('_surfaces').duplicate()
 for s in changes:
  var edited=ArrayMesh.new();edited.add_surface_from_arrays(hall.mesh.surface_get_primitive_type(s),changes[s]);edited.surface_set_material(0,hall.mesh.surface_get_material(s))
  packed[s]=edited.get('_surfaces')[0]
 var result=ArrayMesh.new();result.set('_surfaces',packed)
 for key in hall.mesh.get_meta_list():result.set_meta(key,hall.mesh.get_meta(key))
 hall.mesh=result
 return journal
static func apply(scene:Node3D)->Dictionary:
 if not is_instance_valid(scene) or scene.is_queued_for_deletion():return {'ok':false,'reason':'Inactive Hall host'}
 if 'startup_cancel_requested' in scene and scene.startup_cancel_requested:return {'ok':false,'reason':'Cancelled Hall host'}
 if scene.has_meta(KEY):
  var prior=scene.get_meta(KEY)
  if not prior is Dictionary or not is_instance_valid(prior.get('root')) or prior.root.get_parent()!=scene:return {'ok':false,'reason':'Stale Hall finish receipt'}
  return prior
 if scene.has_node('HallReviewFinishV094') or not scene.has_node('HallBasementBlockout'):return {'ok':false,'reason':'Hall finish lifecycle mismatch'}
 var halls=scene.find_children('TownHall_Gallery_Runtime','MeshInstance3D',true,false)
 if halls.size()!=1 or halls[0].mesh.get_surface_count()!=18:return {'ok':false,'reason':'Expected retained Hall art'}
 var hall:MeshInstance3D=halls[0]
 var glazing=preload('res://scripts/hall_glazing_v097.gd').apply(hall)
 if not glazing.get('ok',false):return glazing
 var reception=preload('res://scripts/hall_reception_v098.gd').apply(scene,hall)
 if not reception.get('ok',false):return reception
 var r=Node3D.new();r.name='HallReviewFinishV094';scene.add_child(r)
 var exterior=Node3D.new();exterior.name='Exterior';r.add_child(exterior)
 var civic=Node3D.new();civic.name='CivicRoom';r.add_child(civic)
 var library=Node3D.new();library.name='Library';r.add_child(library)
 var basement=Node3D.new();basement.name='Cellar';r.add_child(basement)
 var stone=mat('#938875');var cap=mat('#a2957d');var joint=mat('#807967');var timber=mat('#624b35');var dark=mat('#45392d');var bronze=mat('#8e724b',.48);var rust=mat('#86523d');var paper=mat('#cabe9e');var ink=mat('#566458');var fabric=mat('#5e7068')
 var collision_journal=[]
 # TH01. A low foundation course, then quiet drainage slots along the original base, never a raised path curb.
 for x in [-9.025,9.025]:
  box(exterior,'Side foundation course',Vector3(x,.26,-23),Vector3(.07,.32,17.95),stone)
  box(exterior,'Side plinth cap',Vector3(x,.432,-23),Vector3(.08,.032,17.95),cap)
  box(exterior,'Flush perimeter drainage',Vector3(signf(x)*9.13,-.045,-23),Vector3(.18,.012,17.95),joint)
  for z in range(-31,-14):box(exterior,'Quiet drain slot',Vector3(signf(x)*9.13,-.038,z),Vector3(.105,.003,.023),dark)
 box(exterior,'Rear foundation course',Vector3(0,.26,-32.025),Vector3(18.0,.32,.07),stone)
 box(exterior,'Rear plinth cap',Vector3(0,.432,-32.025),Vector3(18.0,.032,.08),cap)
 box(exterior,'Rear flush drainage',Vector3(0,-.045,-32.13),Vector3(18.0,.012,.18),joint)
 for x in range(-8,9):box(exterior,'Rear drain slot',Vector3(x,-.038,-32.13),Vector3(.023,.003,.105),dark)
 for x in [-5.6,5.6]:
  box(exterior,'Front foundation course',Vector3(x,.26,-13.985),Vector3(6.60,.32,.05),stone)
  box(exterior,'Front plinth cap',Vector3(x,.432,-13.985),Vector3(6.60,.032,.065),cap)
 box(exterior,'Existing step dressed threshold',Vector3(0,.243,-14.18),Vector3(4.0,.006,.34),cap)
 for x in [-1.5,-.5,.5,1.5]:box(exterior,'Threshold inset joint',Vector3(x,.247,-14.18),Vector3(.008,.002,.33),joint)
 box(exterior,'Flush outer threshold',Vector3(0,.056,-13.90),Vector3(4.0,.006,.18),stone)
 # TH02. Reveal inside existing jambs; subordinate leaf welcome and refined existing planter collars.
 for x in [-2.30,2.30]:
  box(exterior,'Door jamb inner reveal',Vector3(x,2.32,-13.94),Vector3(.13,4.10,.08),timber)
  box(exterior,'Door jamb bronze shoe',Vector3(x,.51,-13.92),Vector3(.15,.42,.09),bronze)
 box(exterior,'Entry reveal lintel',Vector3(0,4.40,-13.94),Vector3(4.72,.13,.08),timber)
 box(exterior,'Small welcome plaque',Vector3(2.31,2.12,-13.88),Vector3(.30,.57,.035),rust)
 box(exterior,'Welcome leaf stem',Vector3(2.31,2.12,-13.855),Vector3(.015,.37,.008),paper)
 for y in [2.01,2.12,2.23]:
  for side in [-1,1]:
   var leaf=box(exterior,'Welcome leaf embroidery',Vector3(2.31+side*.06,y,-13.85),Vector3(.12,.026,.008),paper);leaf.rotation.z=side*.48
 for at in [Vector3(-3.7,0,-15.5),Vector3(7.8,0,-15.5)]:
  for dx in [-.362,.362]:box(exterior,'Entry planter rim',at+Vector3(dx,.874,0),Vector3(.045,.07,.77),timber)
  for dz in [-.362,.362]:box(exterior,'Entry planter rim',at+Vector3(0,.874,dz),Vector3(.68,.07,.045),timber)
  box(exterior,'Entry planter bronze base',at+Vector3(0,.286,0),Vector3(.735,.065,.735),bronze)
 # TH03. The existing Mara terrain display remains the only model. Furnish its east side bay.
 box(civic,'Survey bay woven inset',Vector3(6.20,.244,-25.70),Vector3(3.50,.004,3.35),fabric)
 for x in [4.52,7.88]:box(civic,'Survey inset border',Vector3(x,.247,-25.70),Vector3(.022,.002,3.20),paper)
 for z in [-27.29,-24.11]:box(civic,'Survey inset border',Vector3(6.20,.247,z),Vector3(3.36,.002,.022),paper)
 for z in [-26.20,-24.80]:
  for x in [7.50,8.02]:box(civic,'Survey bench leg',Vector3(x,.48,z),Vector3(.095,.48,.095),timber)
 box(civic,'Survey bench seat',Vector3(7.76,.75,-25.50),Vector3(.65,.10,1.80),timber)
 box(civic,'Survey bench back',Vector3(8.05,1.08,-25.50),Vector3(.09,.60,1.80),timber)
 box(civic,'Survey bench lower stretcher',Vector3(7.76,.40,-25.50),Vector3(.08,.08,1.55),dark)
 solid(civic,'Survey bench footprint',Vector3(7.77,.82,-25.50),Vector3(.70,1.16,1.85),collision_journal)
 # TH04. Calm main stone, warm flush borders and visible purlins between the major trusses.
 bind_local_surfaces(hall)
 for x in [-2.78,2.78]:box(civic,'Flush timber aisle border',Vector3(x,.242,-23),Vector3(.12,.003,17.45),timber)
 for x in [-7.6,-5.0,-1.5,1.5,5.0,7.6]:
  var y=6.2+(9.5-absf(x))*.9/6.5 if absf(x)>=3 else 9.0-absf(x)*1.9/3.0
  box(civic,'Ceiling longitudinal purlin',Vector3(x,y-.065,-23),Vector3(.09,.14,18.1),timber)
 # TH05. Reuse folio and ledgers on east end of welcome desk. Add only the missing stamp/tray/map cues.
 box(civic,'Reception sorting tray base',Vector3(6.15,1.42,-18.64),Vector3(.52,.035,.30),dark)
 for x in [5.90,6.40]:box(civic,'Reception tray edge',Vector3(x,1.455,-18.64),Vector3(.025,.05,.30),timber)
 for z in [-18.78,-18.50]:box(civic,'Reception tray edge',Vector3(6.15,1.455,z),Vector3(.52,.05,.025),timber)
 for i in range(3):box(civic,'Reception sorted papers',Vector3(6.13+i*.016,1.45+i*.005,-18.65),Vector3(.39,.004,.21),paper)
 box(civic,'Reception stamp base',Vector3(6.74,1.435,-18.68),Vector3(.15,.06,.13),bronze)
 box(civic,'Reception stamp handle',Vector3(6.74,1.515,-18.68),Vector3(.075,.11,.07),timber)
 # Existing large baked WELCOME plaque remains the single role label.
 for j in range(3):
  var line=box(civic,'Folio map contour',Vector3(5.36,1.447,-19.14+j*.09),Vector3(.23,.002,.008),ink);line.rotation.y=-.16+j*.14
 # TH06. One authored reading moment around the retained table and lantern; cap follows existing guard.
 var book_journal=author_books(hall)
 glazing['mesh']=hall.mesh
 reception['mesh']=hall.mesh
 box(library,'Reading open cover',Vector3(-4.57,4.545,-24.77),Vector3(.67,.025,.42),rust)
 for x in [-4.74,-4.40]:
  var page=box(library,'Reading open page',Vector3(x,4.567,-24.77),Vector3(.32,.025,.38),paper);page.rotation.z=.045 if x< -4.57 else -.045
 for z in [-24.89,-24.83,-24.77,-24.71]:box(library,'Reading line',Vector3(-4.42,4.587,z),Vector3(.23,.002,.006),ink)
 box(library,'Reading cloth marker',Vector3(-4.60,4.588,-24.73),Vector3(.035,.003,.49),fabric)
 box(library,'Reader personal note',Vector3(-4.94,4.54,-24.49),Vector3(.22,.007,.14),paper)
 for j in range(3):box(library,'Small note handwriting',Vector3(-4.94,4.545,-24.53+j*.028),Vector3(.14-j*.015,.002,.004),ink)
 box(library,'Gallery edge hand cap',Vector3(-3.25,4.755,-23),Vector3(.125,.055,15.60),timber)
 box(library,'Gallery front hand cap',Vector3(-5.8,4.755,-15.05),Vector3(5.2,.055,.125),timber)
 # TH07. Reuse two existing shelving frames, adding named stores within their original solid footprints.
 for zi in range(2):
  var z=-27.0 if zi==0 else -19.0
  for level in range(3):
   var y=-3.36+level*.55
   for dz in [-.72,.05,.72]:
    var p=Vector3(7.99,y+.20,z+dz)
    box(basement,'Labeled civic supply crate',p,Vector3(.47,.38,.57),timber)
    for offset in [-.20,.20]:box(basement,'Crate binding',p+Vector3(-.245,0,offset),Vector3(.016,.34,.035),bronze)
    box(basement,'Supply paper tag',p+Vector3(-.248,.02,0),Vector3(.008,.12,.23),paper)
    crate_number(basement,p,1+level*3+[-.72,.05,.72].find(dz),ink)
  var plate=box(basement,'Shelf bay plaque',Vector3(7.63,-1.56,z),Vector3(.025,.17,1.10),dark)
  label(basement,'Cellar shelf label','LINEN' if zi==0 else 'LANTERN PARTS',Vector3(7.608,-1.56,z),.0025,-PI/2)
 # Compact repair table occupies north perimeter, far beyond stair and central aisle.
 box(basement,'Repair table top',Vector3(-1.70,-2.60,-30.93),Vector3(2.35,.12,.72),timber)
 for x in [-2.70,-.70]:
  for z in [-31.18,-30.68]:box(basement,'Repair bench leg',Vector3(x,-3.03,z),Vector3(.11,.86,.11),timber)
 box(basement,'Repair table low shelf',Vector3(-1.70,-3.20,-30.93),Vector3(2.15,.07,.62),dark)
 box(basement,'Repair work mat',Vector3(-1.70,-2.534,-30.90),Vector3(1.10,.012,.49),fabric)
 box(basement,'Repair timber offcut',Vector3(-2.45,-2.50,-30.90),Vector3(.32,.07,.45),cap)
 box(basement,'Repair mallet head',Vector3(-1.52,-2.49,-30.86),Vector3(.23,.09,.10),timber)
 box(basement,'Repair mallet handle',Vector3(-1.52,-2.49,-31.06),Vector3(.035,.035,.39),bronze)
 solid(basement,'Repair table footprint',Vector3(-1.70,-3.0,-30.93),Vector3(2.35,1.0,.72),collision_journal)
 box(basement,'Repair bay plaque',Vector3(-1.70,-2.15,-31.37),Vector3(1.03,.20,.025),dark)
 label(basement,'Repair bay physical label','REPAIRS',Vector3(-1.70,-2.15,-31.35),.003)
 # Slightly darker cellar floor, isolated from shared courtyard material and existing lights.
 for m in scene.get_node('HallBasementBlockout').find_children('*','MeshInstance3D',true,false):
  if m.mesh is BoxMesh and m.mesh.size==Vector3(17.2,.24,17.2):
   var local=m.material_override.duplicate();local.set_shader_parameter('tint',Color('#827966'));local.set_shader_parameter('variation',.14);m.material_override=local
 # Carry the remaining desk-top additions with the same compact assembly.
 var desk_dressing=scene.get_node('HallReceptionAssemblyV098/DeskDressing')
 var moved_desk_details=0
 for child in civic.get_children():
  # Repeated Godot node names may become @MeshInstance3D IDs. Use the bounded
  # authored desk-top envelope, not a name prefix that misses repeated papers.
  if child is MeshInstance3D and child.position.x>=4.9 and child.position.x<=7.0 and child.position.y>=1.4 and child.position.y<=1.7 and child.position.z>= -19.4 and child.position.z<= -18.4:
   child.reparent(desk_dressing,false);moved_desk_details+=1
 reception['moved_desk_detail_meshes']=moved_desk_details
 preload('res://scripts/hall_civic_zones_v098.gd').add_to(scene)
 var source_meshes=r.find_children('*','MeshInstance3D',true,false).size()
 BATCH.batch_static_visuals(desk_dressing)
 for owner in [exterior,civic,library,basement]:BATCH.batch_static_visuals(owner)
 for v in basement.find_children('*','GeometryInstance3D',true,false):v.layers=BASEMENT_LAYER
 var receipt={'ok':true,'root':r,'review_ids':['TH01','TH02','TH03','TH04','TH05','TH06','TH07'],'source_meshes':source_meshes,'batches':r.find_children('*','MultiMeshInstance3D',true,false).size(),'new_lights':0,'new_collision_journal':collision_journal,'book_journal':book_journal,'existing_model_retained':true,'existing_architecture_collision_unchanged':true}
 scene.set_meta(KEY,receipt);return receipt
