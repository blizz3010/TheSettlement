extends RefCounted
# Static selected face from the creator mesh; procedural equipped body remains provisional.
const Draft=preload('res://scripts/character_preview/creator_draft.gd')
const SOURCE='res://models/Appearance-Proof.glb'
const CUT_Y=1.30
const FIT=Transform3D(Basis(Vector3(1.2,0,0),Vector3(0,1.2,0),Vector3(0,0,1.2)),Vector3(0,.12,0))
static func relative(node:Node3D,root:Node3D)->Variant:
 var t=node.transform;var parent=node.get_parent()
 while parent!=root:
  if not parent is Node3D:return null
  t=parent.transform*t;parent=parent.get_parent()
 return root.transform*t
static func interpolate(a:Dictionary,b:Dictionary,t:float)->Dictionary:
 return {'p':a.p.lerp(b.p,t),'n':a.n.lerp(b.n,t).normalized(),'uv':a.uv.lerp(b.uv,t),'color':a.color.lerp(b.color,t)}
static func clip(poly:Array)->Array:
 var result=[]
 for i in poly.size():
  var a=poly[i];var b=poly[(i+1)%poly.size()];var ai=a.p.y>=CUT_Y;var bi=b.p.y>=CUT_Y
  if ai:result.append(a)
  if ai!=bi:result.append(interpolate(a,b,(CUT_Y-a.p.y)/(b.p.y-a.p.y)))
 return result
static func prepare(value:Dictionary)->Dictionary:
 var validator=Draft.new()
 if not validator.valid(value) or value.name!=value.name.strip_edges():return {'ok':false,'reason':'Invalid selected appearance'}
 var packed=load(SOURCE) as PackedScene
 if packed==null:return {'ok':false,'reason':'Creator model unavailable'}
 var raw=packed.instantiate()
 if not raw is Node3D:
  if raw!=null:raw.free()
  return {'ok':false,'reason':'Invalid creator root'}
 var meshes={}
 for m in raw.find_children('*','MeshInstance3D',true,false):
  if meshes.has(str(m.name)):raw.free();return {'ok':false,'reason':'Duplicate creator mesh name'}
  meshes[str(m.name)]=m
 var selected=['ProofBody',str(value.brows),str(value.eyes)]
 if value.hair!='none':selected.append(str(value.hair))
 for name in selected:
  if not meshes.has(name):raw.free();return {'ok':false,'reason':'Selected creator mesh missing'}
 var body=meshes.ProofBody
 var cheek=body.find_blend_shape_by_name('probe_cheek_volume_v1')
 if cheek<0:raw.free();return {'ok':false,'reason':'Creator cheek shape missing'}
 body.set_blend_shape_value(cheek,float(value.cheek))
 var root=Node3D.new();root.name='SelectedCharacterHead'
 var total=0;var skin=Color('d8d3c8');var bounds=AABB();var has_bounds=false
 for name in selected:
  var source=meshes[name]
  if not source.mesh is ArrayMesh:root.free();raw.free();return {'ok':false,'reason':'Creator mesh type changed'}
  var mesh=source.bake_mesh_from_current_blend_shape_mix() if source.get_blend_shape_count()>0 else source.mesh
  if mesh==null:root.free();raw.free();return {'ok':false,'reason':'Creator blend bake unavailable'}
  var t=relative(source,raw)
  if t==null or t.basis.determinant()<=.0001:root.free();raw.free();return {'ok':false,'reason':'Creator transform invalid'}
  var output=ArrayMesh.new();var count=0
  for surface in mesh.get_surface_count():
   if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:root.free();raw.free();return {'ok':false,'reason':'Creator topology unsupported'}
   var material=source.get_active_material(surface)
   if not material is StandardMaterial3D:root.free();raw.free();return {'ok':false,'reason':'Creator material unsupported','mesh':name,'surface':surface}
   if name=='ProofBody':skin=material.albedo_color
   var arrays=mesh.surface_get_arrays(surface);var vertices=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var uvs=arrays[Mesh.ARRAY_TEX_UV];var colors=arrays[Mesh.ARRAY_COLOR];var indices=arrays[Mesh.ARRAY_INDEX]
   if normals==null or normals.size()!=vertices.size():root.free();raw.free();return {'ok':false,'reason':'Creator normals unavailable'}
   if material.normal_enabled and (uvs==null or uvs.size()!=vertices.size()):root.free();raw.free();return {'ok':false,'reason':'Normal-mapped creator UV unavailable','mesh':name,'surface':surface}
   var order=indices if indices!=null and not indices.is_empty() else range(vertices.size())
   var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);var emitted=0
   for i in range(0,order.size(),3):
    var triangle=[]
    for j in range(3):
     var index=order[i+j]
     triangle.append({'p':t*vertices[index],'n':(t.basis.inverse().transposed()*normals[index]).normalized(),'uv':uvs[index] if uvs!=null and uvs.size()==vertices.size() else Vector2.ZERO,'color':colors[index] if colors!=null and colors.size()==vertices.size() else Color.WHITE})
    var polygon=clip(triangle) if name=='ProofBody' else triangle
    for j in range(1,polygon.size()-1):
     for v in [polygon[0],polygon[j],polygon[j+1]]:
      var point=FIT*v.p
      if not point.is_finite() or point.y<1.6799 or point.y>2.05:root.free();raw.free();return {'ok':false,'reason':'Selected head bounds changed'}
      if not has_bounds:bounds=AABB(point,Vector3.ZERO);has_bounds=true
      else:bounds=bounds.expand(point)
      tool.set_normal(v.n);tool.set_uv(v.uv);tool.set_color(v.color);tool.add_vertex(point);emitted+=1
   if emitted>0:
    if material.normal_enabled:tool.generate_tangents()
    tool.set_material(Draft.tinted_material(material,value) if name in ["hair_short02_v1","hair_bob01_v1"] else material.duplicate())
    var previous=output.get_surface_count()
    if tool.commit(output)==null or output.get_surface_count()!=previous+1:root.free();raw.free();return {'ok':false,'reason':'Head surface construction failed'}
    count+=emitted
  if count==0:root.free();raw.free();return {'ok':false,'reason':'Selected mesh empty after separation'}
  var node=MeshInstance3D.new();node.name=name;node.mesh=output;root.add_child(node);total+=count
 raw.free()
 if not has_bounds or bounds.size.x>.4 or bounds.size.z>.42:root.free();return {'ok':false,'reason':'Selected head envelope too wide'}
 root.set_meta('appearance',value.duplicate(true));root.set_meta('cut_y',CUT_Y);root.set_meta('bounds',bounds)
 return {'ok':true,'root':root,'skin':skin,'vertices':total,'bounds':bounds,'scope':'Static creator head/selected features with provisional procedural equipped body; no skeletal clothing fit claim'}
