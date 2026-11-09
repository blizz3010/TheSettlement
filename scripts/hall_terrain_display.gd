extends RefCounted
# Provisional render-only miniature; no plot-state/service data or collision.
const CENTER=Vector3(6.40,1.425,-28.02)
const SIZE=Vector2(1.20,.76)
static func mat(c:String,metallic=0.0):
 var m=StandardMaterial3D.new();m.albedo_color=Color(c);m.roughness=.78;m.metallic=metallic;return m
static func box(r,n,p,size,m):
 var v=MeshInstance3D.new();v.name=n;v.position=p;var b=BoxMesh.new();b.size=size;v.mesh=b;v.material_override=m;r.add_child(v)
static func channel(x:float)->float:return .065*sin(x*7.0)+.025
static func height(x:float,z:float)->float:
 var ridge=.16*exp(-pow((x+.29)/.22,2)-pow((z+.19)/.15,2))+.11*exp(-pow((x-.28)/.18,2)-pow((z+.20)/.13,2))
 var valley=1.0-exp(-pow((z-channel(x))/.055,2))
 return .030+ridge*valley
static func vertex(st,p,color):st.set_color(color);st.add_vertex(p)
static func groundpoint(x,z):return Vector3(x,height(x,z),z)
static func apply(world:Node3D)->Dictionary:
 if not is_instance_valid(world) or world.is_queued_for_deletion():return {'ok':false,'reason':'inactive-host'}
 if 'startup_cancel_requested' in world and world.startup_cancel_requested:return {'ok':false,'reason':'cancelled-host'}
 if world.has_node('HallTerrainDisplayPrototype'):
  var existing=world.get_node('HallTerrainDisplayPrototype')
  if not owned_valid(world,existing):return {'ok':false,'reason':'foreign-or-stale-display'}
  return {'ok':true,'root':existing,'existing':true}
 var r=Node3D.new();r.name='HallTerrainDisplayPrototype';r.position=CENTER
 var wood=mat('#574330');var bronze=mat('#92734c',.55);var paper=mat('#c3b591');var river=mat('#487e83')
 box(r,'Terrain exhibit timber tray',Vector3.ZERO,Vector3(SIZE.x,.04,SIZE.y),wood)
 for z in [-SIZE.y/2,SIZE.y/2]:box(r,'Bronze model rim',Vector3(0,.027,z),Vector3(SIZE.x+.03,.035,.025),bronze)
 for x in [-SIZE.x/2,SIZE.x/2]:box(r,'Bronze model rim',Vector3(x,.027,0),Vector3(.025,.035,SIZE.y),bronze)
 if not preload('res://scripts/settlement_miniature.gd').build(r):r.free();return {'ok':false,'reason':'invalid-settlement-survey-model'}
 # Incline only this owned exhibit; no desk, staff or service changes.
 if not incline_exhibit(r,wood):r.free();return {'ok':false,'reason':'invalid-inclined-exhibit'}
 # No interaction or physics nodes, no labels or lights. Commit one owned visual root.
 var stamp=visual_stamp(r)
 if stamp.is_empty():r.free();return {'ok':false,'reason':'invalid-generated-visual'}
 r.set_meta('terrain_display_owned',true);r.set_meta('terrain_display_owner',world.get_instance_id());r.set_meta('terrain_display_stamp',stamp);world.add_child(r)
 return {'ok':true,'root':r,'existing':false,'purpose':'Decorative terrain model only'}

# Lifecycle guards only; the accepted generator above retains exact geometry/materials.
static func visual_stamp(root:Node)->Array:
 if not root is Node3D or root.is_queued_for_deletion() or root.get_script()!=null or not root.visible or root.position!=CENTER or root.rotation!=Vector3.ZERO or root.scale!=Vector3.ONE:return []
 var rows=[]
 for child in root.get_children():
  if not child is MeshInstance3D or child.is_queued_for_deletion() or child.get_script()!=null or child.mesh==null or not child.material_override is StandardMaterial3D or child.get_child_count()!=0 or not child.visible:return []
  var arrays=[]
  if not (child.mesh is ArrayMesh or child.mesh is PrimitiveMesh):return []
  for surface in range(child.mesh.get_surface_count()):
   var primitive=child.mesh.surface_get_primitive_type(surface) if child.mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
   arrays.append([primitive,child.mesh.surface_get_arrays(surface)])
  var material=[]
  for prop in child.material_override.get_property_list():
   if int(prop.usage)&PROPERTY_USAGE_STORAGE:material.append([prop.name,child.material_override.get(prop.name)])
  rows.append([child,child.transform,child.mesh,child.material_override,child.layers,child.cast_shadow,child.transparency,child.mesh.get_aabb(),digest(arrays),digest(material)])
 if rows.size()!=11:return []
 return rows
static func owned_valid(world:Node3D,root:Node)->bool:
 if not is_instance_valid(root) or root.is_queued_for_deletion() or root.get_parent()!=world:return false
 if not root.get_meta('terrain_display_owned',false) or root.get_meta('terrain_display_owner',0)!=world.get_instance_id():return false
 var stamp=visual_stamp(root)
 return not stamp.is_empty() and stamp==root.get_meta('terrain_display_stamp',[])

static func digest(value)->String:
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(value));return hash.finish().hex_encode()


static func exhibit_bounds(r:Node3D)->AABB:
 var first=true;var bounds=AABB()
 for child in r.get_children():
  for vertex in child.mesh.get_faces():
   var point=child.transform*vertex
   if first:bounds=AABB(point,Vector3.ZERO);first=false
   else:bounds=bounds.expand(point)
 return bounds

static func incline_exhibit(r:Node3D,wood:Material)->bool:
 if r.get_child_count()!=10:return false
 var before=exhibit_bounds(r)
 var turn=Transform3D(Basis(Vector3.RIGHT,deg_to_rad(15.0)),Vector3.ZERO)
 for child in r.get_children():child.transform=turn*child.transform
 var rotated=exhibit_bounds(r)
 if rotated.size.z<=0.0:return false
 # Height rotates into depth. Fit actual vertices, not an assumed unchanged box.
 var depth_scale=minf(1.0,before.size.z/rotated.size.z)
 var fit=Transform3D(Basis.from_scale(Vector3(1,1,depth_scale)),Vector3(0,before.position.y+.008-rotated.position.y,before.get_center().z-rotated.get_center().z*depth_scale))
 for child in r.get_children():child.transform=fit*child.transform
 var after=exhibit_bounds(r)
 if after.position.x<before.position.x-.00001 or after.end.x>before.end.x+.00001 or after.position.z<before.position.z-.00001 or after.end.z>before.end.z+.00001 or after.end.y>.50:return false
 var top=[];var bottom=[]
 for point in [Vector3(-SIZE.x/2,-.02,-SIZE.y/2),Vector3(SIZE.x/2,-.02,-SIZE.y/2),Vector3(SIZE.x/2,-.02,SIZE.y/2),Vector3(-SIZE.x/2,-.02,SIZE.y/2)]:
  var transformed=fit*turn*point;top.append(transformed);bottom.append(Vector3(transformed.x,before.position.y,transformed.z))
 var center=Vector3.ZERO
 for point in top+bottom:center+=point/8.0
 var faces=[[top[0],top[1],top[2],top[3]],[bottom[3],bottom[2],bottom[1],bottom[0]]]
 for i in range(4):faces.append([bottom[i],bottom[(i+1)%4],top[(i+1)%4],top[i]])
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for face in faces:
  for indices in [[0,1,2],[0,2,3]]:
   var a=face[indices[0]];var b=face[indices[1]];var c=face[indices[2]]
   var cross=(b-a).cross(c-a)
   if cross.length_squared()<.0000000001:return false
   var outward=cross.normalized()
   if outward.dot((a+b+c)/3.0-center)<0:outward=-outward
   var points=[a,c,b] if cross.dot(outward)>0 else [a,b,c]
   for point in points:st.set_normal(outward);st.add_vertex(point)
 var wedge=MeshInstance3D.new();wedge.name='Inclined exhibit timber plinth';wedge.mesh=st.commit();wedge.material_override=wood;r.add_child(wedge)
 r.set_meta('inclined_exhibit',{'degrees':15.0,'original_bounds':before,'display_bounds':after,'depth_scale':depth_scale,'scope':'Decorative terrain study; not live plot map'})
 return true
