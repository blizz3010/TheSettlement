extends RefCounted
const Art=preload('res://scripts/inn_architecture.gd')
const Front=preload('res://scripts/inn_front_v087.gd')
const Envelope=preload('res://scripts/settlement_envelope.gd')
const Joined=preload('res://scripts/inn_joined_decks_v098.gd')
const WATER_Y=.65
# Ellipse touches the inn's rear and expands into a large exterior lake.
const CENTER=Vector2(20,130)
const RADII=Vector2(100,75)
static func lake_distance(p:Vector2)->float:return ((p-CENTER)/RADII).length()
static func lowered(p:Vector3)->Vector3:
 var d=lake_distance(Vector2(p.x,p.z))
 if p.z<54 or d>=1:return p
 var t=smoothstep(1.0,.965,d)
 p.y=lerpf(p.y,WATER_Y-1.25,t)
 return p
static func solid(n:Node3D,label:String,p:Vector3,s:Vector3,m:Material):return Front.solid(n,label,p,s,m)
static func rail(n:Node3D,a:Vector3,b:Vector3):
 var wood=Art.material('59412b');var length=a.distance_to(b);var count=ceili(length/1.5)
 for i in range(count+1):
  var p=a.lerp(b,float(i)/count)
  solid(n,'BalustradePost',p+Vector3(0,.55,0),Vector3(.12,1.1,.12),wood)
 # Exact solid guard plus visually open balusters: transparent collider carries safety.
 var body=StaticBody3D.new();var col=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(length,1.1,.10);col.shape=shape;body.add_child(col);body.position=(a+b)*.5+Vector3(0,.55,0);body.rotation.y=-atan2(b.z-a.z,b.x-a.x);n.add_child(body)
 var cap=Art.box(n,'Handrail',(a+b)*.5+Vector3(0,1.1,0),Vector3(length,.10,.14),wood);cap.rotation.y=body.rotation.y
 for i in range(ceili(length/.24)):
  var p=a.lerp(b,(i+.5)/ceili(length/.24))
  Art.box(n,'Baluster',p+Vector3(0,.52,0),Vector3(.045,1,.045),wood)
static func deck(n:Node3D,label:String,r:Rect2):
 var wood=Art.material('806042')
 solid(n,label,Vector3(r.get_center().x,3.25,r.get_center().y),Vector3(r.size.x,.26,r.size.y),wood)
 for z in range(ceili(r.size.y/.22)):
  Art.box(n,'PlankJoint',Vector3(r.get_center().x,3.383,r.position.y+z*.22),Vector3(r.size.x,.006,.012),Art.material('513e2b'))
static func shore_height(p:Vector2,cache:Dictionary)->float:
 # Match the delivered one-metre triangle planes exactly before extending scenery.
 var x=floori(p.x);var z=floori(p.y);var u=p.x-x;var v=p.y-z
 var heights=[]
 for q in [Vector2i(x,z),Vector2i(x+1,z),Vector2i(x,z+1),Vector2i(x+1,z+1)]:
  if not cache.has(q):cache[q]=lowered(Vector3(q.x,preload('res://scripts/settlement_terrain.gd').height_at(q.x,q.y),q.y)).y
  heights.append(cache[q])
 var h=heights[0]+(heights[1]-heights[0])*u+(heights[2]-heights[0])*v if u+v<=1 else heights[3]+(heights[2]-heights[3])*(1-u)+(heights[1]-heights[3])*(1-v)
 # Join the unchanged original scenic apron at its actual radial extent.
 # Outside the lake shore, fade the extension into that same low apron plane.
 var r=p.length();var direction=p.normalized();var inner=45.0/maxf(absf(direction.x),absf(direction.y))
 var apron=lerpf(-.06,-3.4,clampf((r-inner)/(113.0-inner),0,1))
 var blend=smoothstep(70.0,112.0,r)*smoothstep(1.025,1.09,lake_distance(p))
 return lerpf(h,apron,blend)
static func add_shore_apron(parent:Node3D)->void:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var cache={};var count=0
 # Non-colliding continuation beyond the existing physical ring. A one-metre
 # coplanar overlap matches existing triangle planes, hiding its square-cell edge.
 for iz in range(88,432):
  for ix in range(-174,254):
   var p=Vector2(ix*.5,iz*.5);var d=lake_distance(p+Vector2(.25,.25))
   var radius=(p+Vector2(.25,.25)).length()
   var bank_band=d>=.96 and d<=1.07
   var shore_connector=radius<=113.0 and p.y>=44.0 and d>=.96
   if radius<64.5 or not (bank_band or shore_connector):continue
   var a=Vector3(p.x,shore_height(p,cache)+.006,p.y)
   var b=Vector3(p.x+.5,shore_height(p+Vector2(.5,0),cache)+.006,p.y)
   var c=Vector3(p.x,shore_height(p+Vector2(0,.5),cache)+.006,p.y+.5)
   var d3=Vector3(p.x+.5,shore_height(p+Vector2(.5,.5),cache)+.006,p.y+.5)
   for tri in [[a,b,c],[b,d3,c]]:
    var normal=(tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
    for v in tri:st.set_normal(normal);st.add_vertex(v)
   count+=1
 var mesh=MeshInstance3D.new();mesh.name='ContinuousShoreApron';mesh.mesh=st.commit();var material=ShaderMaterial.new();material.shader=preload('res://shaders/lake_bank_v089.gdshader');mesh.material_override=material;parent.add_child(mesh);mesh.set_meta('quad_count',count);mesh.set_meta('collision_changes',false)
static func adapt_backdrop(world:Node3D)->Dictionary:
 var backdrop=world.get_node_or_null('ValleyBackdrop')
 if backdrop==null:return {'present':false,'cut_surfaces':0,'removed_tree_instances':0}
 var surfaces=0;var removed=0
 for n in backdrop.get_children():
  if n is MeshInstance3D and n.material_override is StandardMaterial3D:
   n.set_meta('pre_lake_material',n.material_override)
   var cut=ShaderMaterial.new();cut.shader=preload('res://shaders/lake_scenery_cut_v088.gdshader');cut.set_shader_parameter('tint',n.material_override.albedo_color);n.material_override=cut;surfaces+=1
  elif n is MultiMeshInstance3D and str(n.name).begins_with('DistantTree'):
   var old=n.multimesh;var keep=[]
   for i in range(old.instance_count):
    var t=old.get_instance_transform(i)
    if lake_distance(Vector2(t.origin.x,t.origin.z))>=1:keep.append(i)
   var replacement=MultiMesh.new();replacement.transform_format=old.transform_format;replacement.use_colors=old.use_colors;replacement.use_custom_data=old.use_custom_data;replacement.mesh=old.mesh;replacement.instance_count=keep.size()
   for j in range(keep.size()):
    var i=keep[j];replacement.set_instance_transform(j,old.get_instance_transform(i))
    if old.use_colors:replacement.set_instance_color(j,old.get_instance_color(i))
    if old.use_custom_data:replacement.set_instance_custom_data(j,old.get_instance_custom_data(i))
   n.set_meta('pre_lake_multimesh',old);n.multimesh=replacement;removed+=old.instance_count-keep.size()
 return {'present':true,'cut_surfaces':surfaces,'removed_tree_instances':removed}
static func apply(world:Node3D)->Dictionary:
 if world.has_meta('inn_lake_v088'):return world.get_meta('inn_lake_v088')
 var site=world.get_node_or_null('SettlementInnExpansion');var outer=world.get_node_or_null('SettlementOuterTerrain')
 if site==null or outer==null:return {'ok':false,'reason':'Inn site and outer terrain required'}
 var inn=site.get_node_or_null('Inn');var terrain=outer.get_node_or_null('GroundRelief') as MeshInstance3D
 var oldbody=outer.get_node_or_null('WalkableOuterGround') as StaticBody3D
 var terrace=site.get_node_or_null('TerraceAndApproach')
 if inn==null or terrain==null or oldbody==null or terrace==null:return {'ok':false,'reason':'Expected site structure missing'}
 var east_label=''
 for n in terrace.get_children():
  if n is MeshInstance3D and str(n.name).begins_with('SideGuard') and n.position.x>8:east_label=str(n.name)
 if east_label.is_empty():return {'ok':false,'reason':'East guard missing'}
 for label in ['RearGuard','RearGuardBody',east_label,east_label+'Body']:
  if not terrace.has_node(label):return {'ok':false,'reason':'Expected terrace guard missing: '+label}
 if not inn.position.is_equal_approx(Vector3(0,3.4,52.7)):return {'ok':false,'reason':'Unexpected inn placement'}
 var deck_plan=Joined.prepare(terrace)
 if not deck_plan.get('ok',false):return deck_plan
 var front=Front.apply_to_inn(inn)
 if not front.ok:
  deck_plan.replacement.free();return front
 var root=Node3D.new();root.name='InnLakesideV088'
 # Preserve original resource and body; publish replacement only after building it.
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var faces=PackedVector3Array();var oldfaces=terrain.mesh.get_faces();var original=terrain.mesh.surface_get_arrays(0);var changed=0
 for i in range(0,oldfaces.size(),3):
  var tri=[lowered(oldfaces[i]),lowered(oldfaces[i+1]),lowered(oldfaces[i+2])]
  var normal=(tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
  for j in range(3):
   var p:Vector3=tri[j];if p!=oldfaces[i+j]:changed+=1
   var altered=tri[0]!=oldfaces[i] or tri[1]!=oldfaces[i+1] or tri[2]!=oldfaces[i+2]
   st.set_normal(normal if altered else original[Mesh.ARRAY_NORMAL][i+j])
   var color:Color=original[Mesh.ARRAY_COLOR][i+j]
   if p!=oldfaces[i+j]:color=color.lerp(Color(.25,.22,.16),1.0-smoothstep(.7,1.6,p.y))
   st.set_color(color);st.set_uv(original[Mesh.ARRAY_TEX_UV][i+j]);st.add_vertex(p);faces.append(p)
 var ground=MeshInstance3D.new();ground.name='LocalLakeBank';ground.mesh=st.commit();ground.material_override=terrain.material_override;root.add_child(ground)
 var body=StaticBody3D.new();body.name='LocalLakeBankCollision';var shape=ConcavePolygonShape3D.new();shape.set_faces(faces);var col=CollisionShape3D.new();col.shape=shape;body.add_child(col);root.add_child(body)
 var water=SurfaceTool.new();water.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(128):
  var a=TAU*i/128;var b=TAU*(i+1)/128
  for p in [CENTER,CENTER+Vector2(cos(b),sin(b))*RADII,CENTER+Vector2(cos(a),sin(a))*RADII]:water.set_normal(Vector3.UP);water.add_vertex(Vector3(p.x,WATER_Y,p.y))
 var wm=MeshInstance3D.new();wm.name='BroadExteriorLake';wm.mesh=water.commit();var mat=ShaderMaterial.new();mat.shader=preload('res://shaders/inn_lake_v088.gdshader');wm.material_override=mat;root.add_child(wm)
 Joined.build(root,deck,rail)
 var wood=Art.material('59412b')
 for x in [-8,-4,0,4,8]:
  Art.box(root,'RearTimberPile',Vector3(x,1.325,62.6),Vector3(.28,3.95,.28),wood)
  Front.lantern(root,Vector3(x,4.6,62.85))
 for z in [53.3,56.5,59.8]:Art.box(root,'EastTimberPile',Vector3(11.6,1.325,z),Vector3(.28,3.95,.28),wood)
 for x in [-8.7,0,8.7]:
  Art.box(root,'ExtendedRearSupport',Vector3(x,1.325,60),Vector3(.35,3.95,.35),wood)
 # Seating remains away from the rear passage and side-door arrival.
 for x in [-5,-1]:
  solid(root,'LakesideBenchSeat',Vector3(x,3.84,62),Vector3(2,.14,.52),wood)
  solid(root,'LakesideBenchBack',Vector3(x,4.22,61.8),Vector3(2,.65,.12),wood)
  for dx in [-.8,.8]:solid(root,'BenchLeg',Vector3(x+dx,3.6,62),Vector3(.12,.44,.45),wood)
 # Match the approved warm-window treatment on the lakeside rear facade.
 var rear=Node3D.new();rear.name='LakesideFacade';rear.position=inn.position;rear.rotation.y=PI;root.add_child(rear)
 for x in [-5.7,-2.2,2.2,5.7]:
  Front.window(rear,x,4.8,-6.02,1.6,1.5)
  Art.box(rear,'RearFlowerBox',Vector3(x,3.95,-6.18),Vector3(1.8,.28,.34),wood)
  Front.plant(rear,Vector3(x,4.10,-6.18),1.6)
 for x in [-6.7,0,6.7]:Front.lantern(rear,Vector3(x,2.25,-6.12))
 for x in [-7.8,6.6]:
  Art.box(root,'DeckPlanter',Vector3(x,3.66,62.1),Vector3(.65,.56,.65),wood)
  Front.plant(root,Vector3(x,3.94,62.1),.85)
 preload('res://scripts/inn_guest_finish_v094.gd').apply_lakeside(root,inn)
 # Retain all original ground/collision data for rollback and diagnostics.
 root.set_meta('original_ground_mesh',terrain.mesh);root.set_meta('modified_vertices',changed)
 Joined.commit(deck_plan,root)
 world.add_child(root);terrain.hide();oldbody.collision_layer=0;oldbody.collision_mask=0
 for label in ['RearGuard',east_label]:terrace.get_node(label).hide();terrace.get_node(label+'Body').collision_layer=0;terrace.get_node(label+'Body').collision_mask=0
 var result={'ok':true,'modified_outer_vertices':changed,'lake_area_m2':PI*RADII.x*RADII.y,'rear_balcony':Joined.REAR,'east_balcony':Joined.EAST,'water_y':WATER_Y,'dome_unchanged':true}
 add_shore_apron(root)
 result['backdrop']=adapt_backdrop(world)
 world.set_meta('inn_lake_v088',result);return result
