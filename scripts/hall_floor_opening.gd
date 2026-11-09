extends RefCounted
const FLOOR_MATERIALS=["Limestone_0","Limestone_1","Limestone_2","Limestone_3"]
static func floor_material(material:Material)->bool:
 return material!=null and material.resource_name in FLOOR_MATERIALS
# Local rectangular subtraction from only existing Hall floor triangles. GLB bytes stay untouched.
static func clip(poly:Array,axis:int,value:float,less:bool)->Array:
 var out=[]
 for i in range(poly.size()):
  var a=poly[i];var b=poly[(i+1)%poly.size()];var da=a.p[axis]-value;var db=b.p[axis]-value
  var ia=da<=0 if less else da>=0;var ib=db<=0 if less else db>=0
  if ia:out.append(a)
  if ia!=ib:
   var t=da/(da-db);out.append({'p':a.p.lerp(b.p,t),'n':a.n.lerp(b.n,t).normalized(),'uv':a.uv.lerp(b.uv,t),'color':a.color.lerp(b.color,t)})
 return out
static func cut_checkpoint(scene:Node3D,node:MeshInstance3D,startup_owner:Node,label:String)->bool:
 # A disposed/cancelled startup must never resume into saved mesh references.
 if not is_instance_valid(scene) or not is_instance_valid(node):return true
 if scene.is_queued_for_deletion() or node.is_queued_for_deletion():return true
 if startup_owner==null:return false
 if not is_instance_valid(startup_owner) or startup_owner.is_queued_for_deletion():return true
 var interrupted=await startup_owner._startup_checkpoint(label)
 if interrupted or not is_instance_valid(scene) or not is_instance_valid(node) or not is_instance_valid(startup_owner):return true
 return scene.is_queued_for_deletion() or node.is_queued_for_deletion() or startup_owner.is_queued_for_deletion()
static func select_hall(scene:Node3D,hole:Rect2)->Array:
 # Preselect exactly one target; never publish a first match before learning of another.
 if scene.has_meta('basement_floor_cut') or not is_finite(hole.position.x) or not is_finite(hole.position.y) or not is_finite(hole.size.x) or not is_finite(hole.size.y) or hole.size.x<=0 or hole.size.y<=0 or not Rect2(-9,-32,18,18).encloses(hole):
  push_error('Hall floor cut requires an intact mesh and a finite interior aperture');return []
 var targets=[]
 for node in scene.find_children('*','MeshInstance3D',true,false):
  if not node.mesh is ArrayMesh or node.mesh.get_surface_count()!=18:continue
  var bounds=node.global_transform*node.mesh.get_aabb()
  if bounds.position.z> -31 or bounds.end.z< -15:continue
  targets.append(node)
 if targets.size()!=1 or targets[0].name!='TownHall_Gallery_Runtime':
  push_error('Exactly one named, intact 18-surface Hall art mesh required; no mesh published');return []
 return targets
static func cut(scene:Node3D,hole:Rect2)->bool:
 var targets=select_hall(scene,hole)
 if targets.is_empty():return false
 for node in targets:
  var result=ArrayMesh.new();var changed=0
  for surface in range(node.mesh.get_surface_count()):
   var original_material=node.mesh.surface_get_material(surface)
   var eligible_floor_material=floor_material(original_material)
   # Exact non-floor arrays (including grain-axis COLOR) never enter clipping.
   if not eligible_floor_material:
    result.add_surface_from_arrays(node.mesh.surface_get_primitive_type(surface),node.mesh.surface_get_arrays(surface))
    result.surface_set_material(result.get_surface_count()-1,original_material)
    continue
   var a=node.mesh.surface_get_arrays(surface);var verts=a[Mesh.ARRAY_VERTEX];var idx=a[Mesh.ARRAY_INDEX];var normals=a[Mesh.ARRAY_NORMAL];var uvs=a[Mesh.ARRAY_TEX_UV];var colors=a[Mesh.ARRAY_COLOR]
   var count=idx.size() if idx!=null and idx.size()>0 else verts.size();var polys=[];var dirty=false
   for start in range(0,count,3):
    var poly=[];var floor_only=eligible_floor_material
    for j in range(3):
     var k=idx[start+j] if idx!=null and idx.size()>0 else start+j;var p=node.global_transform*verts[k]
     floor_only=floor_only and p.y>=-.001 and p.y<=.241
     poly.append({'p':p,'n':normals[k] if normals!=null else Vector3.UP,'uv':uvs[k] if uvs!=null else Vector2.ZERO,'color':colors[k] if colors!=null else Color.WHITE})
    var b=AABB(poly[0].p,Vector3.ZERO).expand(poly[1].p).expand(poly[2].p)
    var intersects=b.position.x<hole.end.x and b.end.x>hole.position.x and b.position.z<hole.end.y and b.end.z>hole.position.y
    if not floor_only or not intersects:polys.append(poly);continue
    dirty=true;changed+=1
    var middle=clip(clip(poly,0,hole.position.x,false),0,hole.end.x,true)
    for remaining in [clip(poly,0,hole.position.x,true),clip(poly,0,hole.end.x,false),clip(middle,2,hole.position.y,true),clip(middle,2,hole.end.y,false)]:
     if remaining.size()>=3:polys.append(remaining)
   if not dirty:result.add_surface_from_arrays(node.mesh.surface_get_primitive_type(surface),a)
   else:
    var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for poly in polys:
     for j in range(1,poly.size()-1):
      for v in [poly[0],poly[j],poly[j+1]]:
       st.set_normal(v.n);st.set_uv(v.uv);st.set_color(v.color);st.add_vertex(node.global_transform.affine_inverse()*v.p)
    st.commit(result)
   if result.get_surface_count()!=surface+1:
    push_error('Hall floor surface disappeared; no mesh published');return false
   result.surface_set_material(result.get_surface_count()-1,node.mesh.surface_get_material(surface))
  if changed<=0 or result.get_surface_count()!=18:
   push_error('Hall floor cut must change limestone triangles and retain 18 surfaces; no mesh published');return false
  for key in node.mesh.get_meta_list():result.set_meta(key,node.mesh.get_meta(key))
  node.mesh=result;scene.set_meta('basement_floor_cut',{'changed_floor_triangles':changed,'original_asset_untouched':true,'hole':hole,'floor_materials':FLOOR_MATERIALS})
 return true

# Opt-in loading successor scheduling. Original synchronous APIs above remain unchanged.
static func cut_staged(scene:Node3D,hole:Rect2,startup_owner:Node)->bool:
 var targets=select_hall(scene,hole)
 if targets.is_empty():return false
 for node in targets:
  var result=ArrayMesh.new();var changed=0
  var world_transform=node.global_transform
  var inverse_transform=world_transform.affine_inverse()
  for surface in range(node.mesh.get_surface_count()):
   var original_material=node.mesh.surface_get_material(surface)
   var eligible_floor_material=floor_material(original_material)
   # Exact non-floor arrays (including grain-axis COLOR) never enter clipping.
   if not eligible_floor_material:
    result.add_surface_from_arrays(node.mesh.surface_get_primitive_type(surface),node.mesh.surface_get_arrays(surface))
    result.surface_set_material(result.get_surface_count()-1,original_material)
    continue
   var a=node.mesh.surface_get_arrays(surface);var verts=a[Mesh.ARRAY_VERTEX];var idx=a[Mesh.ARRAY_INDEX];var normals=a[Mesh.ARRAY_NORMAL];var uvs=a[Mesh.ARRAY_TEX_UV];var colors=a[Mesh.ARRAY_COLOR]
   var count=idx.size() if idx!=null and idx.size()>0 else verts.size();var polys=[];var dirty=false
   # Eligibility only: untouched surfaces retain original arrays/material/order.
   var touches_opening=false
   for start in range(0,count,3):
    if startup_owner != null and start % 192 == 0:
     if await cut_checkpoint(scene,node,startup_owner,"hall floor surface eligibility"):return false
    var k0=idx[start] if idx!=null and idx.size()>0 else start
    var p0=world_transform*verts[k0]
    if not eligible_floor_material or not (p0.y>=-.001 and p0.y<=.241):continue
    var k1=idx[start+1] if idx!=null and idx.size()>0 else start+1
    var p1=world_transform*verts[k1]
    if not (p1.y>=-.001 and p1.y<=.241):continue
    var k2=idx[start+2] if idx!=null and idx.size()>0 else start+2
    var p2=world_transform*verts[k2]
    if not (p2.y>=-.001 and p2.y<=.241):continue
    var triangle_bounds=AABB(p0,Vector3.ZERO).expand(p1).expand(p2)
    if triangle_bounds.position.x<hole.end.x and triangle_bounds.end.x>hole.position.x and triangle_bounds.position.z<hole.end.y and triangle_bounds.end.z>hole.position.y:
     touches_opening=true;break
   if not touches_opening:
    result.add_surface_from_arrays(node.mesh.surface_get_primitive_type(surface),a)
    if startup_owner != null:
     if await cut_checkpoint(scene,node,startup_owner,"hall floor untouched surface committed"):return false
    result.surface_set_material(result.get_surface_count()-1,node.mesh.surface_get_material(surface))
    continue
   for start in range(0,count,3):
    if startup_owner != null and start % 192 == 0:
     if await cut_checkpoint(scene,node,startup_owner,"hall floor clipping triangles"):return false
    var poly=[];var floor_only=eligible_floor_material
    for j in range(3):
     var k=idx[start+j] if idx!=null and idx.size()>0 else start+j;var p=world_transform*verts[k]
     floor_only=floor_only and p.y>=-.001 and p.y<=.241
     poly.append({'p':p,'n':normals[k] if normals!=null else Vector3.UP,'uv':uvs[k] if uvs!=null else Vector2.ZERO,'color':colors[k] if colors!=null else Color.WHITE})
    var b=AABB(poly[0].p,Vector3.ZERO).expand(poly[1].p).expand(poly[2].p)
    var intersects=b.position.x<hole.end.x and b.end.x>hole.position.x and b.position.z<hole.end.y and b.end.z>hole.position.y
    if not floor_only or not intersects:polys.append(poly);continue
    dirty=true;changed+=1
    var middle=clip(clip(poly,0,hole.position.x,false),0,hole.end.x,true)
    for remaining in [clip(poly,0,hole.position.x,true),clip(poly,0,hole.end.x,false),clip(middle,2,hole.position.y,true),clip(middle,2,hole.end.y,false)]:
     if remaining.size()>=3:polys.append(remaining)
   if not dirty:result.add_surface_from_arrays(node.mesh.surface_get_primitive_type(surface),a)
   else:
    var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var polygon_index=0
    for poly in polys:
     if startup_owner != null and polygon_index % 64 == 0:
      if await cut_checkpoint(scene,node,startup_owner,"hall floor rebuilding polygons"):return false
     polygon_index+=1
     for j in range(1,poly.size()-1):
      for v in [poly[0],poly[j],poly[j+1]]:
       st.set_normal(v.n);st.set_uv(v.uv);st.set_color(v.color);st.add_vertex(inverse_transform*v.p)
    st.commit(result)
   if startup_owner != null:
    if await cut_checkpoint(scene,node,startup_owner,"hall floor surface committed"):return false
   if result.get_surface_count()!=surface+1:
    push_error('Hall floor surface disappeared; no mesh published');return false
   result.surface_set_material(result.get_surface_count()-1,node.mesh.surface_get_material(surface))
  if changed<=0 or result.get_surface_count()!=18:
   push_error('Hall floor cut must change limestone triangles and retain 18 surfaces; no mesh published');return false
  for key in node.mesh.get_meta_list():result.set_meta(key,node.mesh.get_meta(key))
  if startup_owner != null:
   if await cut_checkpoint(scene,node,startup_owner,"hall floor ready to publish"):return false
  node.mesh=result;scene.set_meta('basement_floor_cut',{'changed_floor_triangles':changed,'original_asset_untouched':true,'hole':hole,'floor_materials':FLOOR_MATERIALS})
 return true
