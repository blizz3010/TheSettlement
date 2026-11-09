extends RefCounted
# Additive approved west-path destination. No existing service actor is moved.
const ANCHOR=Vector3(-27.25,0,-4)
const FOOTPRINT=Rect2(-29.5,-6.4,4.5,4.8)
const GRADE=Rect2(-30,-7,5,6)
const FORECOURT=Rect2(-25,-6.4,1.0,4.8)
const CLEARANCE=Rect2(-29.6,-6.5,5.6,5.0)
const TARGET=Vector3(-26.05,1.5,-4)
const Builder=preload("res://scripts/market_expansion.gd")
static func accessible(world,player)->bool:
 if not is_instance_valid(player) or not world.has_node("TailorAtelier"):return false
 var p=player.global_position
 if p.x< -25.75 or p.x> -23.35 or p.z< -5.2 or p.z> -2.8 or absf(p.y)>.6:return false
 var eye=p+Vector3(0,1.5,0)
 if eye.distance_to(TARGET)>2.8:return false
 var q=PhysicsRayQueryParameters3D.create(eye,TARGET);q.exclude=[player.get_rid()]
 return world.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
static func bounds_clear()->bool:
 var b=AABB(Vector3(GRADE.position.x,-1,GRADE.position.y),Vector3(GRADE.size.x,8,GRADE.size.y))
 if preload("res://scripts/hideout_terrace.gd").conflicts(b):return false
 for r in preload("res://scripts/local_terrain_layers.gd").EXTRA_RESERVES:
  if GRADE.intersects(r):return false
 return true
static func plan_site(world)->Dictionary:
 if not bounds_clear():return {"ok":false,"reason":"Tailor overlaps a reserved footprint"}
 var trees=[]
 for spec in [["RouteGardens/border_tree_a",1,Vector2(-27,-4),Vector2(-35.2,-3.8)],["NaturalBorder/border_tree_a",11,Vector2(-27.90753,-8.309244),Vector2(-34.6,-10.5)]]:
  var batch=world.get_node_or_null(spec[0])
  if not batch is MultiMeshInstance3D or not batch.has_meta("source_transforms"):return {"ok":false,"reason":"Tailor tree authority missing"}
  var tree_validation=validate_batch_source(batch,true)
  if not tree_validation.ok:return tree_validation
  var transforms:Array=batch.get_meta("source_transforms").duplicate();var index:int=spec[1]
  if index>=transforms.size() or transforms.size()!=batch.multimesh.instance_count:return {"ok":false,"reason":"Tailor tree count changed"}
  var old:Transform3D=transforms[index]
  if Vector2(old.origin.x,old.origin.z).distance_to(spec[2])>.0001:return {"ok":false,"reason":"Tailor tree identity changed"}
  var next=old;next.origin.x=spec[3].x;next.origin.z=spec[3].y
  next.origin.y=preload("res://scripts/settlement_terrain.gd").height_at(next.origin.x,next.origin.z)
  var aabb=next*batch.multimesh.mesh.get_aabb()
  if GRADE.intersects(Rect2(Vector2(aabb.position.x,aabb.position.z),Vector2(aabb.size.x,aabb.size.z))) or preload("res://scripts/hideout_terrace.gd").conflicts(aabb):return {"ok":false,"reason":"Relocated tree is not clear"}
  transforms[index]=next
  var previous:MultiMesh=batch.multimesh;var mm=MultiMesh.new();mm.transform_format=previous.transform_format;mm.use_colors=previous.use_colors;mm.use_custom_data=previous.use_custom_data;mm.mesh=previous.mesh;mm.instance_count=previous.instance_count
  var buffer:PackedFloat32Array=previous.buffer
  var native_verified=not buffer.is_empty()
  if native_verified:mm.buffer=buffer
  else:
   # Physics fixtures use authored source transforms; no native buffer proof claimed.
   for i in transforms.size():mm.set_instance_transform(i,transforms[i])
  mm.set_instance_transform(index,next);mm.visible_instance_count=previous.visible_instance_count
  if native_verified:
   var after:PackedFloat32Array=mm.buffer;var stride=int(buffer.size()/previous.instance_count)
   if stride<12 or after.size()!=buffer.size():return {"ok":false,"reason":"Relocated tree buffer changed size"}
   for i in previous.instance_count:
    if i!=index and after.slice(i*stride,(i+1)*stride).to_byte_array()!=buffer.slice(i*stride,(i+1)*stride).to_byte_array():return {"ok":false,"reason":"Unrelated tree buffer row changed"}
   if after.slice(index*stride+12,(index+1)*stride).to_byte_array()!=buffer.slice(index*stride+12,(index+1)*stride).to_byte_array():return {"ok":false,"reason":"Relocated tree color/custom data changed"}
  trees.append({"batch":batch,"index":index,"old":old,"next":next,"transforms":transforms,"path":spec[0],"multimesh":mm,"source_multimesh":previous,"native_buffers_verified":native_verified,"source_buffer_sha256":buffer.to_byte_array().hex_encode().sha256_text() if native_verified else ""})
 if not world.get_node("NaturalBorder").find_children("*","CollisionShape3D",true,false).is_empty():return {"ok":false,"reason":"NaturalBorder gained unreviewed colliders"}
 var trunks=[]
 for body in world.get_node("RouteGardens").get_children():
  if body is StaticBody3D and Vector2(body.position.x,body.position.z).distance_to(Vector2(-27,-4))<.001:trunks.append(body)
 if trunks.size()!=1:return {"ok":false,"reason":"Tailor source trunk identity changed"}
 var surface=world.get_node_or_null("SettlementTerrain/GroundRelief")
 var shape_node=world.get_node_or_null("SettlementTerrain/WalkableRelief/CollisionShape3D")
 # Generated collision names are intentionally not assumed.
 var ground=world.get_node_or_null("SettlementTerrain/WalkableRelief")
 if ground==null or surface==null:return {"ok":false,"reason":"Tailor terrain unavailable"}
 var shapes=ground.find_children("*","CollisionShape3D",true,false)
 if shapes.size()!=1 or not shapes[0].shape is ConcavePolygonShape3D:return {"ok":false,"reason":"Tailor terrain collision changed"}
 shape_node=shapes[0]
 var arrays=surface.mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate();var changed=0;var changed_indices=[]
 for i in vertices.size():
  var p=vertices[i]
  if p.x>=GRADE.position.x and p.x<=GRADE.end.x and p.z>=GRADE.position.y and p.z<=GRADE.end.y and p.y>-.05:
   vertices[i].y=-.05;changed+=1;changed_indices.append(i)
 if changed==0:return {"ok":false,"reason":"Tailor terrain grading authority changed"}
 arrays[Mesh.ARRAY_VERTEX]=vertices
 # Preserve every original channel and vertex order. Recalculate only normals
 # whose finite-difference neighborhood intersects the bounded grade transition.
 var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL].duplicate();var normal_changes=0;var normal_indices=[]
 for i in vertices.size():
  var p=vertices[i]
  if GRADE.grow(1.0).has_point(Vector2(p.x,p.z)) or p.x==GRADE.end.x+1 or p.z==GRADE.end.y+1:
   if p.x<GRADE.position.x-1 or p.x>GRADE.end.x+1 or p.z<GRADE.position.y-1 or p.z>GRADE.end.y+1:continue
   var normal=Vector3(graded_height(p.x-.25,p.z)-graded_height(p.x+.25,p.z),.5,graded_height(p.x,p.z-.25)-graded_height(p.x,p.z+.25)).normalized()
   if not normals[i].is_equal_approx(normal):normals[i]=normal;normal_changes+=1;normal_indices.append(i)
 arrays[Mesh.ARRAY_NORMAL]=normals
 # Godot re-encodes packed normals/tangents when round-tripping arrays.
 # Start from the exact serialized surface dictionary and patch ONLY authorized
 # position bytes and selected normal bytes. Attributes/materials/LOD metadata
 # and every unrelated normal/tangent byte remain the original representation.
 var raw_surfaces=surface.mesh.get("_surfaces").duplicate(true)
 if raw_surfaces.size()!=1:return {"ok":false,"reason":"Unexpected terrain surface count"}
 var encoded=ArrayMesh.new();encoded.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var original_bytes:PackedByteArray=raw_surfaces[0].vertex_data.duplicate()
 var prepared_bytes:PackedByteArray=encoded.get("_surfaces")[0].vertex_data
 var format=surface.mesh.surface_get_format(0);var count=vertices.size()
 var position_offset=RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_VERTEX)
 var position_stride=RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
 var normal_offset=RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_NORMAL)
 var normal_stride=RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)
 var tangent_offset=RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_TANGENT)
 if position_stride!=12 or normal_stride!=8 or tangent_offset-normal_offset!=4 or encoded.surface_get_format(0)!=format:return {"ok":false,"reason":"Unsupported terrain buffer format"}
 var patched=original_bytes.duplicate()
 for index in changed_indices:
  var bytes=PackedVector3Array([vertices[index]]).to_byte_array();var offset=position_offset+index*position_stride
  for j in 12:patched[offset+j]=bytes[j]
 for index in normal_indices:
  var offset=normal_offset+index*normal_stride
  for j in 4:patched[offset+j]=prepared_bytes[offset+j]
 raw_surfaces[0].vertex_data=patched
 var mesh=ArrayMesh.new();mesh.set("_surfaces",raw_surfaces)
 # Visual terrain has prior rounding that is not present in baseline collision.
 # Patch the original collision faces directly so unrelated physics triangles,
 # their order, winding, multiplicity and shape settings remain byte exact.
 var original_faces:PackedVector3Array=shape_node.shape.get_faces()
 var collision_faces=original_faces.duplicate();var collision_indices=[]
 for i in collision_faces.size():
  var point=collision_faces[i]
  if point.x>=GRADE.position.x and point.x<=GRADE.end.x and point.z>=GRADE.position.y and point.z<=GRADE.end.y and point.y>-.05:
   collision_faces[i].y=-.05;collision_indices.append(i)
 var shape=shape_node.shape.duplicate();shape.set_faces(collision_faces)
 return {"ok":true,"trees":trees,"trunks":trunks,"surface":surface,"mesh":mesh,"source_mesh":surface.mesh,"shape_node":shape_node,"shape":shape,"source_shape":shape_node.shape,"changed":changed,"normal_changes":normal_changes,"position_indices":changed_indices,"normal_indices":normal_indices,"collision_indices":collision_indices,"original_collision_sha256":original_faces.to_byte_array().hex_encode().sha256_text(),"patched_collision_sha256":collision_faces.to_byte_array().hex_encode().sha256_text(),"original_vertex_buffer_sha256":original_bytes.hex_encode().sha256_text(),"patched_vertex_buffer_sha256":patched.hex_encode().sha256_text()}
static func commit_site(plan:Dictionary)->Dictionary:
 # No yielding after complete site+grass validation through the paired commits.
 var journal=[]
 for row in plan.trees:
  row.batch.multimesh=row.multimesh;row.batch.set_meta("source_transforms",row.transforms)
  journal.append({"path":row.path,"index":row.index,"before":row.old,"after":row.next,"count_unchanged":true,"native_buffers_verified":row.native_buffers_verified,"source_buffer_sha256":row.source_buffer_sha256,"colors_custom_data_prefix_preserved":true})
 plan.trunks[0].position=plan.trees[0].next.origin+Vector3(0,1.2,0)
 plan.surface.mesh=plan.mesh;plan.shape_node.shape=plan.shape
 return {"ok":true,"tree_relocations":journal,"terrain_vertices_graded":plan.changed,"terrain_normals_changed":plan.normal_changes,"normal_rect":GRADE.grow(1.0),"original_uv_color_tangent_channels_retained":true,"position_indices":plan.position_indices,"normal_indices":plan.normal_indices,"collision_indices":plan.collision_indices,"original_collision_sha256":plan.original_collision_sha256,"patched_collision_sha256":plan.patched_collision_sha256,"original_vertex_buffer_sha256":plan.original_vertex_buffer_sha256,"patched_vertex_buffer_sha256":plan.patched_vertex_buffer_sha256,"grade_rect":GRADE,"terrain_bounds_unchanged":plan.surface.mesh.get_aabb().size.x==108.0,"trunks_relocated":1,"natural_border_had_no_trunk_colliders":true,"home_and_future_reserves_clear":true}
static func cylinder(root:Node3D,n:String,p:Vector3,r:float,h:float,m:Material)->MeshInstance3D:
 var node=MeshInstance3D.new();node.name=n;node.position=p;var mesh=CylinderMesh.new();mesh.top_radius=r;mesh.bottom_radius=r;mesh.height=h;mesh.radial_segments=16;node.mesh=mesh;node.material_override=m;root.add_child(node);return node
static func add_to(world,site_plan:Dictionary={})->Dictionary:
 if world.has_node("TailorAtelier"):return world.get_node("TailorAtelier").get_meta("site_result",{"ok":false,"reason":"Foreign tailor node"})
 var plan=plan_site(world) if site_plan.is_empty() else site_plan
 if not plan.get("ok",false):return plan
 var prepared=commit_site(plan)
 # Retain immutable preimage resources for independent native acceptance. These
 # are runtime-only references, never serialized into gameplay save data.
 var evidence_trees=[]
 for row in plan.trees:evidence_trees.append({"path":row.path,"index":row.index,"source":row.source_multimesh,"before":row.old,"after":row.next})
 world.set_meta("tailor_site_evidence",{"trees":evidence_trees,"source_mesh":plan.source_mesh,"source_shape":plan.source_shape,"trunk":plan.trunks[0]})
 var r=Node3D.new();r.name="TailorAtelier";world.add_child(r);r.position=ANCHOR;r.rotation.y=PI/2
 var m=preload("res://scripts/market_review_finish.gd").palette()
 var indigo=Builder.mat(Color("455478"));var cream=Builder.mat(Color("d6c9aa"));var stone=world.courtyard_material("tailor_stone",Color("a99b80"))
 Builder.box(r,"Atelier floor",Vector3(0,.005,0),Vector3(4.8,.11,4.5),stone,true)
 Builder.box(r,"Clear forecourt",Vector3(0,.005,2.75),Vector3(4.8,.11,1.0),stone,true)
 Builder.box(r,"Rear cream wall",Vector3(0,1.55,-2.17),Vector3(4.8,3.0,.16),cream,true)
 for x in [-2.30,2.30]:
  Builder.box(r,"Side timber wall",Vector3(x,1.45,-.25),Vector3(.15,2.8,3.75),m.wood,true)
  Builder.box(r,"Entry timber post",Vector3(x,1.45,2.10),Vector3(.14,2.8,.14),m.wood,true)
 Builder.box(r,"Indigo canvas awning",Vector3(0,2.95,.2),Vector3(4.8,.12,4.5),indigo)
 Builder.box(r,"Low scalloped valance",Vector3(0,2.80,2.22),Vector3(4.8,.24,.07),indigo)
 Builder.box(r,"Tailor sign backing",Vector3(0,2.48,2.20),Vector3(2.65,.40,.06),m.dark)
 var sign=Builder.label(r,"TAILOR & DYES",Vector3(0,2.49,2.245),27);sign.name="TailorIdentitySign";sign.pixel_size=.0045
 # Large spool emblem and curtain remain visible at every quality.
 for y in [2.25,2.70]:cylinder(r,"Spool emblem rim",Vector3(-1.83,y,2.23),.22,.07,cream)
 cylinder(r,"Spool emblem thread",Vector3(-1.83,2.475,2.23),.14,.42,indigo)
 Builder.box(r,"Cream side curtain",Vector3(2.17,1.55,1.5),Vector3(.07,2.3,1.05),cream)
 for x in [-1.90,-1.38]:
  cylinder(r,"Broad entry cloth roll",Vector3(x,.65,1.75),.20,1.20,indigo if x< -1.5 else cream)
  cylinder(r,"Cloth roll core",Vector3(x,1.265,1.75),.065,.05,m.wood)
 Builder.box(r,"Customer conversation counter",Vector3(.55,.58,.85),Vector3(2.2,1.05,.58),m.wood,true)
 Builder.box(r,"Counter top",Vector3(.55,1.13,.85),Vector3(2.3,.10,.68),stone,true)
 Builder.box(r,"Cutting table",Vector3(-1.20,1.14,-.4),Vector3(1.95,.20,1.05),m.wood,true)
 for x in [-1.95,-.45]:
  for z in [-.8,0]:Builder.box(r,"Cutting table leg",Vector3(x,.55,z),Vector3(.10,1.1,.10),m.wood,true)
 # Existing v094 folded garments are relocated, not retained at Dan.
 var clothes=Node3D.new();clothes.name="RelocatedStarterClothingDisplay";r.add_child(clothes);clothes.position=Vector3(2.2,0,-2.6)
 preload("res://scripts/market_review_finish.gd").tailor_clothing_display(clothes,m)
 # Reuse the v094 textile rail at the left interior wall.
 var rail=Node3D.new();rail.name="RelocatedTextileRail";r.add_child(rail);rail.position=Vector3(-2.18,0,-.75);rail.rotation.y=PI/2
 preload("res://scripts/market_review_finish.gd").tailor_textile_rail(rail,m)
 # Optional visual owners are constructed once; all collision remains on the essential shell.
 var medium=Node3D.new();medium.name="TailorMediumDetails";r.add_child(medium)
 var high=Node3D.new();high.name="TailorHighDetails";r.add_child(high)
 # Existing six small fabric bolts and three notions jars move off Dan's counter.
 for side in [-1,1]:
  for i in 3:
   var p=Vector3(-1.72+i*.28,1.55+(0.45 if side>0 else 0.0),-1.92)
   cylinder(medium,"Relocated wrapped fabric bolt",p,.105,.38,m.teal if side<0 else m.rust)
   cylinder(medium,"Relocated bolt linen band",p,.107,.10,cream)
   cylinder(medium,"Relocated fabric roll core",p+Vector3(0,.196,0),.041,.016,m.wood)
 for y in [1.33,1.78]:Builder.box(r,"Fabric bolt shelf",Vector3(-1.43,y,-1.92),Vector3(1.15,.06,.42),m.wood)
 Builder.box(r,"Notions shelf",Vector3(1.59,1.25,.05),Vector3(.95,.08,.32),m.wood)
 for i in 3:
  var p=Vector3(1.34+i*.25,1.42,.05)
  cylinder(medium,"Relocated glazed notions jar",p,.085,.25,m.teal if i%2 else m.rust)
  cylinder(medium,"Relocated jar bronze lid",p+Vector3(0,.14,0),.075,.025,m.bronze)
  Builder.box(high,"Relocated jar paper band",p+Vector3(0,0,.086),Vector3(.09,.10,.008),cream)
 # Dress form at center rear, separate from the original existing NPC cast.
 cylinder(r,"Mannequin weighted base",Vector3(0,.13,-1.35),.30,.14,m.dark)
 cylinder(r,"Mannequin stand",Vector3(0,.67,-1.35),.045,1.0,m.bronze)
 Builder.box(r,"Cream mannequin torso",Vector3(0,1.45,-1.35),Vector3(.48,.70,.25),cream)
 Builder.sphere(r,Vector3(0,1.96,-1.35),Vector3(.22,.28,.22),m.wood)
 Builder.box(r,"Washable dye tray",Vector3(1.62,.14,-1.15),Vector3(1.02,.08,1.1),stone)
 cylinder(r,"Dye basin stand",Vector3(1.62,.47,-1.15),.30,.55,m.wood)
 cylinder(r,"Dye basin",Vector3(1.62,.87,-1.15),.43,.24,m.bronze)
 cylinder(r,"Indigo dye surface",Vector3(1.62,.995,-1.15),.37,.015,indigo)
 Builder.box(r,"Shallow thread shelf",Vector3(1.13,2.04,-2.02),Vector3(1.85,.09,.28),m.wood)
 for i in 6:
  var p=Vector3(.40+i*.28,2.17,-2.01)
  cylinder(high,"Thread spool",p,.075,.18,cream if i%2==0 else indigo)
  for dy in [-.10,.10]:cylinder(high,"Thread spool rim",p+Vector3(0,dy,0),.09,.025,m.wood)
 var actor=preload("res://scripts/trader_coverage.gd").attach(r,"Tailor","res://assets/npc_coverage/ProvisionalStaff.glb","Staff_SubtleIdle_Provisional",Vector3(.70,.055,-.30),0.0,1.0)
 # Static provisional coverage stays quiescent during startup; existing actors are untouched.
 preload("res://scripts/tailor_frontage_v097.gd").install(r,medium,high)
 r.set_meta("service_role","tailor_clothing_craft_dye");r.set_meta("essential_all_quality_tiers",true);r.set_meta("site_result",prepared)
 return prepared
static func lattice_height(x:int,z:int)->float:
 if x>=GRADE.position.x and x<=GRADE.end.x and z>=GRADE.position.y and z<=GRADE.end.y:return -.05
 return preload("res://scripts/settlement_terrain.gd").height_at(x,z)
static func graded_height(x:float,z:float)->float:
 var ix=floori(x);var iz=floori(z);var u=x-ix;var v=z-iz
 var a=lattice_height(ix,iz);var b=lattice_height(ix+1,iz);var c=lattice_height(ix,iz+1);var d=lattice_height(ix+1,iz+1)
 return a+(b-a)*u+(c-a)*v if u+v<=1 else d+(c-d)*(1-u)+(b-d)*(1-v)
static func validate_batch_source(batch,required:bool=false)->Dictionary:
 var mm=batch.multimesh
 if mm==null or mm.transform_format!=MultiMesh.TRANSFORM_3D:return {"ok":false,"reason":"Tailor requires 3D instance transforms: "+str(batch.name)}
 if not batch.has_meta("source_transforms"):
  return {"ok":false,"reason":"Tailor source transforms missing: "+str(batch.name)} if required else {"ok":true}
 var source=batch.get_meta("source_transforms")
 if not source is Array or source.size()!=mm.instance_count:return {"ok":false,"reason":"Tailor source transform count/type changed: "+str(batch.name)}
 for value in source:
  if not value is Transform3D:return {"ok":false,"reason":"Tailor source transform entry changed: "+str(batch.name)}
 return {"ok":true}
static func boundary_bytes(mm)->PackedByteArray:
 # A count-zero MultiMesh is a real empty historical witness; some native
 # backends report errors if asked for its nonexistent GPU instance buffer.
 return PackedByteArray() if mm.instance_count==0 else mm.buffer.to_byte_array()
static func optional_source_transforms(batch):
 # Object.get_meta(key, null) still reports an error when the key is absent.
 # Legacy native grass legitimately has no authored transform metadata.
 return batch.get_meta("source_transforms") if batch.has_meta("source_transforms") else null
static func visible_survivors(previous_visible:int,keep:Array)->int:
 if previous_visible<0:return -1
 var count=0
 for index in keep:
  if index<previous_visible:count+=1
 return count
static func plan_grass(world)->Dictionary:
 if world.has_meta("tailor_grass_finish"):return {"ok":true,"prepared":[],"result":world.get_meta("tailor_grass_finish")}
 var prepared=[];var journal=[];var removed_total=0;var grounded_total=0;var boundary=[];var before_counts={"all":0,"near":0,"far":0}
 for batch in world.find_children("*","MultiMeshInstance3D",true,false):
  var label=str(batch.name).to_lower()
  if not ("grass" in label or label.begins_with("lawnchunk_") or label.begins_with("groundnear_") or label.begins_with("groundfar_")):continue
  var old=batch.multimesh
  if old==null or old.mesh==null:continue
  var path=str(world.get_path_to(batch));var kind="near" if label.begins_with("groundnear_") else ("far" if label.begins_with("groundfar_") else "other")
  before_counts.all+=old.instance_count
  if kind!="other":before_counts[kind]+=old.instance_count
  boundary.append({"path":path,"count":old.instance_count,"kind":kind,"sha256":boundary_bytes(old).hex_encode().sha256_text()})
  # Empty survivors remain historical witnesses even though no trim work remains.
  if old.instance_count==0:continue
  var b=batch.global_transform*batch.get_aabb()
  if not GRADE.grow(1.1).intersects(Rect2(Vector2(b.position.x,b.position.z),Vector2(b.size.x,b.size.z))):continue
  var validation=validate_batch_source(batch)
  if not validation.ok:return validation
  var buffer:PackedFloat32Array=old.buffer
  if buffer.is_empty() or buffer.size()%old.instance_count!=0:return {"ok":false,"reason":"Native grass buffers required for tailor clearance"}
  var stride=int(buffer.size()/old.instance_count)
  if stride!=12+(4 if old.use_colors else 0)+(4 if old.use_custom_data else 0):return {"ok":false,"reason":"Tailor grass buffer format changed"}
  var next_buffer=PackedFloat32Array();var keep=[];var moved=[];var removed=[]
  for i in old.instance_count:
   var t:Transform3D=old.get_instance_transform(i);var world_t=batch.global_transform*t
   var foot=Vector2(world_t.origin.x,world_t.origin.z)
   var bounds=world_t*old.mesh.get_aabb()
   if CLEARANCE.intersects(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))):removed.append(i);continue
   var row=buffer.slice(i*stride,(i+1)*stride)
   if GRADE.grow(1.0).has_point(foot):
    var terrain=preload("res://scripts/settlement_terrain.gd")
    var delta=graded_height(foot.x,foot.y)-terrain.height_at(foot.x,foot.y)
    if absf(delta)>.00001:
     var local_delta=batch.global_transform.basis.inverse()*Vector3(0,delta,0)
     # MultiMesh TRANSFORM_3D is three float32 rows, origin at 3/7/11.
     row[3]+=local_delta.x;row[7]+=local_delta.y;row[11]+=local_delta.z;moved.append(i)
   keep.append(i);next_buffer.append_array(row)
  if removed.is_empty() and moved.is_empty():continue
  var next=MultiMesh.new();next.transform_format=old.transform_format;next.use_colors=old.use_colors;next.use_custom_data=old.use_custom_data;next.mesh=old.mesh;next.instance_count=keep.size();next.buffer=next_buffer
  next.visible_instance_count=visible_survivors(old.visible_instance_count,keep)
  if next.buffer.to_byte_array()!=next_buffer.to_byte_array():return {"ok":false,"reason":"Tailor grass buffer did not persist exactly"}
  # Every retained, ungrounded row stays byte exact; outside-transition changes fail closed.
  for j in keep.size():
   if not keep[j] in moved and next_buffer.slice(j*stride,(j+1)*stride).to_byte_array()!=buffer.slice(keep[j]*stride,(keep[j]+1)*stride).to_byte_array():return {"ok":false,"reason":"Tailor retained grass row changed"}
  prepared.append({"batch":batch,"old":old,"next":next,"keep":keep,"moved":moved,"source_transforms":optional_source_transforms(batch),"visible_before":old.visible_instance_count})
  removed_total+=removed.size();grounded_total+=moved.size()
  journal.append({"path":str(world.get_path_to(batch)),"removed":removed.size(),"grounded":moved.size(),"before":old.instance_count,"after":next.instance_count,"visible_before":old.visible_instance_count,"visible_after":next.visible_instance_count,"unchanged_rows_byte_exact":true,"removed_indices":removed,"grounded_indices":moved,"source_buffer_sha256":buffer.to_byte_array().hex_encode().sha256_text(),"result_buffer_sha256":next_buffer.to_byte_array().hex_encode().sha256_text()})
 for row in prepared:
  if row.batch.multimesh!=row.old:return {"ok":false,"reason":"Grass changed during tailor preparation"}
 var result={"ok":true,"removed":removed_total,"grounded":grounded_total,"journal":journal,"removal_rect":CLEARANCE,"grounding_rect":GRADE.grow(1.0),"before_counts":before_counts,"boundary":boundary}
 return {"ok":true,"prepared":prepared,"result":result}
static func commit_grass(world,plan:Dictionary)->Dictionary:
 for row in plan.prepared:
  if row.batch.has_meta("source_transforms"):
   var source:Array=row.batch.get_meta("source_transforms");var next_meta=[]
   for index in row.keep:
    var t:Transform3D=source[index]
    if index in row.moved:
     var foot=row.batch.global_transform*t.origin
     t.origin+=row.batch.global_transform.basis.inverse()*Vector3(0,graded_height(foot.x,foot.z)-preload("res://scripts/settlement_terrain.gd").height_at(foot.x,foot.z),0)
    next_meta.append(t)
   row.batch.set_meta("source_transforms",next_meta)
  row.batch.multimesh=row.next
 var evidence=[]
 for row in plan.prepared:evidence.append({"path":str(world.get_path_to(row.batch)),"source":row.old,"source_transforms":row.source_transforms,"visible_before":row.visible_before})
 world.set_meta("tailor_grass_evidence",evidence)
 world.set_meta("tailor_history_evidence",{"rook":var_to_bytes(world.get_meta("rook_centered_approach",{})).hex_encode().sha256_text(),"contacts":var_to_bytes(world.get_meta("paths_gardens_v094",{})).hex_encode().sha256_text()})
 world.set_meta("tailor_grass_finish",plan.result);return plan.result
static func finish(world)->Dictionary:
 # Check the actual login spawn, not obsolete saved logout coordinates.
 if world.has_method("prepare_town_hall_login") and world.town_hall_login_requested:
  var login=world.prepare_town_hall_login()
  if not login.get("ok",false):return login
 # Old saves standing in new solid fixtures fail safely, without a save rewrite.
 if is_instance_valid(world.player):
  var p=world.player.global_position;var foot=Vector2(p.x,p.z)
  if FOOTPRINT.has_point(foot) and p.x< -25.95:return {"ok":false,"reason":"Saved position overlaps the new tailor. Move onto the west path in the previous build, save, then retry."}
  for tree in [Vector2(-35.2,-3.8),Vector2(-34.6,-10.5)]:
   if foot.distance_to(tree)<.65:return {"ok":false,"reason":"Saved position overlaps a relocated tailor-side tree. Move onto a clear path in the previous build, save, then retry."}
 if world.has_node("TailorAtelier") and world.has_meta("tailor_grass_finish"):return {"ok":true,"site":world.get_node("TailorAtelier").get_meta("site_result"),"grass":world.get_meta("tailor_grass_finish")}
 var site_plan=plan_site(world)
 if not site_plan.get("ok",false):return site_plan
 var grass_plan=plan_grass(world)
 if not grass_plan.get("ok",false):return grass_plan
 # Both complete proposals are validated before any existing terrain/tree/grass mutation.
 var result=add_to(world,site_plan)
 if not result.get("ok",false):return result
 var grass=commit_grass(world,grass_plan)
 return {"ok":true,"site":result,"grass":grass}
