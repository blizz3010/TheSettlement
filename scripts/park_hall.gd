extends RefCounted
## Selected A: compact Hall-route park. No save schema, economy or service additions.
const Grade=preload('res://scripts/park_hall_grade.gd')
const Terrain=preload('res://scripts/settlement_terrain.gd')
const Seats=preload('res://scripts/seat_interaction.gd')
const BENCHES=[{'name':'ParkBenchNorth','at':Vector3(-16.65,.18,-21.3),'yaw':PI/2}, {'name':'ParkBenchSouth','at':Vector3(-17,.18,-17.3),'yaw':0.0}]
const TREE_AT=Vector2(-20.3,-19.4)
const TREE_SCALE=.45
const SHRUBS=[Vector2(-20.45,-21.7),Vector2(-20.55,-17.35),Vector2(-21.4,-20.7)]
static func _bounds2(bounds:AABB)->Rect2:
 return Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))
static func _hits_paving(bounds:AABB)->bool:
 for r in Grade.PAVING:
  if _bounds2(bounds).intersects(r.grow(.10)):return true
 return false
static func prepare(scene:Node3D):
 if scene.has_meta('park_existing_tree_audit'):return
 # Fail closed rather than move an existing tree or hide a trunk to make space.
 var removed=[];var trees=[]
 for col in scene.find_children('*','CollisionShape3D',true,false):
  if col.disabled or col.shape==null:continue
  var shape=col.shape;var bounds=AABB()
  if shape is BoxShape3D:bounds=col.global_transform*AABB(-shape.size*.5,shape.size)
  elif shape is CylinderShape3D:bounds=col.global_transform*AABB(Vector3(-shape.radius,-shape.height*.5,-shape.radius),Vector3(shape.radius*2,shape.height,shape.radius*2))
  else:continue
  if bounds.end.y>.2 and bounds.size.x<60 and bounds.size.z<60:
   assert(not _hits_paving(bounds),'Existing obstacle intersects park paving '+str(col.get_path()))
 for holder_name in ['NaturalBorder','SouthernGroundcover','WalkwayPlanting','RouteGardens']:
  var holder=scene.get_node_or_null(holder_name)
  if holder==null:continue
  for batch in holder.find_children('*','MultiMeshInstance3D',true,false):
   var is_tree='tree' in str(batch.name).to_lower()
   var transforms=batch.get_meta('source_transforms',[])
   for i in range(batch.multimesh.instance_count):
    var t=batch.multimesh.get_instance_transform(i);var p=batch.to_global(t.origin);var q=Vector2(p.x,p.z)
    if is_tree:
     assert(q.distance_to(TREE_AT)>.85,'New park tree too close to original trunk')
     if Grade.inside(q):
      assert(absf(Terrain.park_surface_height(q)-Terrain.pre_park_mesh_height(q))<.001,'Park grade would move existing tree '+str(batch.get_path())+' '+str(q))
      assert(Grade.paving_distance(q)>.65,'Existing tree would occupy park path '+str(q))
     trees.append({'path':str(batch.get_path()),'index':i,'at':p});continue
    var bounds=batch.global_transform*t*batch.multimesh.mesh.get_aabb()
    if not _hits_paving(bounds):continue
    # Remove only low planting now occupied by the explicitly approved path/pads.
    # Keep index/type/origin and a journal, never relocate plants into a reserve.
    removed.append({'batch':str(batch.get_path()),'index':i,'transform':t})
    t.basis=Basis.IDENTITY.scaled(Vector3.ZERO);batch.multimesh.set_instance_transform(i,t)
    if transforms.size()>i:transforms[i]=t
   if not transforms.is_empty():batch.set_meta('source_transforms',transforms)
 for node in scene.get_node('ReferenceFoliage').get_children():
  if not str(node.name).begins_with('Tree'):continue
  var p:Vector3=node.global_position;var q=Vector2(p.x,p.z)
  assert(q.distance_to(TREE_AT)>.85,'New tree would crowd original near trunk')
  if Grade.inside(q):
   assert(absf(Terrain.park_surface_height(q)-Terrain.pre_park_mesh_height(q))<.001,'Park grade would move original near tree')
   assert(Grade.paving_distance(q)>.65,'Original near tree intersects path')
  trees.append({'path':str(node.get_path()),'at':p})
 scene.set_meta('park_existing_tree_audit',trees);scene.set_meta('park_low_plant_clearance',removed)

static func _add_face(st:SurfaceTool,faces:PackedVector3Array,points:Array):
 for p in points:st.add_vertex(p);faces.append(p)
static func _paving(root:Node3D,scene:Node3D):
 var xs=[-18.2,-18.1,-17.0,-15.9,-15.8,-12.9]
 var zs=[-22.3,-21.3,-20.3,-20.0,-18.95,-17.8,-17.7,-16.95]
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var faces=PackedVector3Array()
 for i in range(xs.size()-1):
  for j in range(zs.size()-1):
   var center=Vector2((xs[i]+xs[i+1])*.5,(zs[j]+zs[j+1])*.5)
   if not Grade.paved(center):continue
   var a=Vector3(xs[i],Grade.paving_top(Vector2(xs[i],zs[j])),zs[j])
   var b=Vector3(xs[i+1],Grade.paving_top(Vector2(xs[i+1],zs[j])),zs[j])
   var c=Vector3(xs[i],Grade.paving_top(Vector2(xs[i],zs[j+1])),zs[j+1])
   var d=Vector3(xs[i+1],Grade.paving_top(Vector2(xs[i+1],zs[j+1])),zs[j+1])
   _add_face(st,faces,[a,b,c,b,d,c])
   var aa=Vector3(a.x,-.07,a.z);var bb=Vector3(b.x,-.07,b.z);var cc=Vector3(c.x,-.07,c.z);var dd=Vector3(d.x,-.07,d.z)
   _add_face(st,faces,[aa,cc,bb,bb,cc,dd])
   for edge in [[a,b,aa,bb,Vector2(0,-.001)],[b,d,bb,dd,Vector2(.001,0)],[d,c,dd,cc,Vector2(0,.001)],[c,a,cc,aa,Vector2(-.001,0)]]:
    var middle:Vector3=(edge[0]+edge[1])*.5
    if Grade.paved(Vector2(middle.x,middle.z)+edge[4]):continue
    _add_face(st,faces,[edge[0],edge[2],edge[1],edge[1],edge[2],edge[3]])
 st.generate_normals();var mesh=MeshInstance3D.new();mesh.name='JoinedParkStone';mesh.mesh=st.commit()
 mesh.material_override=scene.courtyard_material('paving',Color(.46,.44,.38,1));root.add_child(mesh)
 var body=StaticBody3D.new();body.name='ParkPavingCollision';body.set_meta('audio_surface','stone');root.add_child(body)
 var col=CollisionShape3D.new();var shape=ConcavePolygonShape3D.new();shape.set_faces(faces);col.shape=shape;body.add_child(col)
 var polygons=[]
 for r in Grade.PAVING:polygons.append(Grade.polygon(r))
 root.set_meta('paving_polygons',polygons);root.set_meta('paving_triangles',faces.size()/3)

static func _bench(root:Node3D,spec:Dictionary):
 var bench=Node3D.new();bench.name=spec.name;bench.position=spec.at;bench.rotation.y=spec.yaw;root.add_child(bench)
 var art=load('res://assets/kit/plaza_bench.glb').instantiate();bench.add_child(art)
 preload('res://scripts/architecture_materials.gd').apply(art)
 var manifest=JSON.parse_string(FileAccess.get_file_as_string('res://assets/source/plaza_bench_v019/manifest.json'))
 var body=StaticBody3D.new();body.name='MemberCollision';bench.add_child(body)
 for member in manifest.members:
  var col=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(member.size[0],member.size[1],member.size[2]);col.shape=shape
  col.position=Vector3(member.position[0],member.position[1],member.position[2]);body.add_child(col)
 Seats.register_bench(bench)

static func _plant(root:Node3D,file:String,name:String,p:Vector2,scale_factor:float)->Node3D:
 var plant=load('res://assets/kit/'+file+'.glb').instantiate();plant.name=name;plant.scale=Vector3.ONE*scale_factor;root.add_child(plant)
 var mesh:MeshInstance3D=plant.find_children('*','MeshInstance3D',true,false)[0]
 # Asset min-y is retained; place the visible lowest roots ON exact final triangles.
 plant.position=Vector3(p.x,Terrain.park_surface_height(p)-mesh.mesh.get_aabb().position.y*scale_factor,p.y)
 var bounds=plant.global_transform*mesh.mesh.get_aabb()
 assert(Grade.ENVELOPE.encloses(_bounds2(bounds)),'New plant canopy outside selected A')
 assert(not _hits_paving(bounds),'New plant canopy crosses path/pad')
 return plant
static func add_to(scene:Node3D)->Node3D:
 if scene.has_node('HallRoutePark'):return scene.get_node('HallRoutePark')
 var root=Node3D.new();root.name='HallRoutePark';scene.add_child(root)
 _paving(root,scene)
 for spec in BENCHES:_bench(root,spec)
 var tree=_plant(root,'border_tree_a','ParkAlienTree',TREE_AT,TREE_SCALE)
 var body=StaticBody3D.new();body.name='ParkAlienTreeTrunk';body.position=Vector3(TREE_AT.x,Terrain.park_surface_height(TREE_AT)+.55,TREE_AT.y);root.add_child(body)
 var col=CollisionShape3D.new();var trunk=CylinderShape3D.new();trunk.radius=.126;trunk.height=1.1;col.shape=trunk;body.add_child(col)
 for i in range(SHRUBS.size()):_plant(root,'border_shrub_a','ParkAlienShrub%d'%i,SHRUBS[i],.48)
 var tree_mask=PackedVector2Array()
 for i in range(16):tree_mask.append(TREE_AT+Vector2(cos(i*TAU/16),sin(i*TAU/16))*.25)
 root.set_meta('grass_exclusion_polygons',[tree_mask])
 root.set_meta('scope','Selected A; no centerpiece, overlook, inventory or layout relocation')
 root.set_meta('new_benches',2);root.set_meta('new_trees',1);root.set_meta('new_shrubs',3)
 var triangles=0
 for mesh in root.find_children('*','MeshInstance3D',true,false):triangles+=mesh.mesh.get_faces().size()/3
 root.set_meta('source_budget',{'triangles':triangles,'meshes':root.find_children('*','MeshInstance3D',true,false).size(),'collision_shapes':root.find_children('*','CollisionShape3D',true,false).size()})
 assert(root.get_meta('paving_triangles')==164,'Known joined-paving source budget')
 assert(triangles<=6600 and root.get_meta('source_budget').meshes<=27,'Bounded park render source budget')
 assert(root.get_meta('source_budget').collision_shapes==24,'Two approved benches, one trunk, one paved surface')
 return root
