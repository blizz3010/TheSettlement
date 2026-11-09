extends RefCounted
## Bounded imported-mesh reception relocation. Ambience only, never a new service.
const KEY='hall_reception_v098'
const WIDTH_SCALE=2.4/4.15
const MANIFEST=preload('res://assets/hall_v098/reception-components.json')
static func mapped(p:Vector3)->Vector3:return Vector3((p.x-5.0)*WIDTH_SCALE,p.y,p.z-3.0)
static func assembly(scene:Node3D)->Node3D:
 return scene.get_node_or_null('HallReceptionAssemblyV098')
static func apply(scene:Node3D,hall:MeshInstance3D)->Dictionary:
 if scene.has_meta(KEY):return {'ok':false,'reason':'Reception already committed'}
 var owner=assembly(scene)
 if owner==null:return {'ok':false,'reason':'Missing reception dressing assembly'}
 var matches=[]
 var holder=scene.get_node_or_null('TownHallCollision')
 if holder==null:return {'ok':false,'reason':'Missing Hall collision'}
 for body in holder.get_children():
  if body is StaticBody3D and body.position.is_equal_approx(Vector3(5,.82,-19)):matches.append(body)
 if matches.size()!=1:return {'ok':false,'reason':'Expected one original reception collider'}
 var body:StaticBody3D=matches[0]
 if body.get_child_count()!=1 or not body.get_child(0) is CollisionShape3D or not body.get_child(0).shape is BoxShape3D or not body.get_child(0).shape.size.is_equal_approx(Vector3(4.15,1.16,1.2)):
  return {'ok':false,'reason':'Original reception collider changed'}
 var records=MANIFEST.data.records
 if records.size()!=22:return {'ok':false,'reason':'Reception manifest changed'}
 var edits={};var selected={}
 for record in records:
  var s=int(record.surface)
  if not edits.has(s):edits[s]=hall.mesh.surface_get_arrays(s).duplicate(true);selected[s]={}
  var a=edits[s];var bounds=AABB();var first=true;var positions=PackedVector3Array()
  for raw in record.indices:
   var i=int(raw)
   if i<0 or i>=a[Mesh.ARRAY_VERTEX].size() or selected[s].has(i):return {'ok':false,'reason':'Invalid reception component indices'}
   selected[s][i]=true;positions.append(a[Mesh.ARRAY_VERTEX][i])
   var p=hall.global_transform*a[Mesh.ARRAY_VERTEX][i]
   if first:bounds=AABB(p,Vector3.ZERO);first=false
   else:bounds=bounds.expand(p)
  if hash(positions)!=int(record.vertex_hash):return {'ok':false,'reason':'Reception vertex fingerprint changed'}
  var lo=record.bounds.min;var hi=record.bounds.max
  if bounds.position.distance_to(Vector3(lo[0],lo[1],lo[2]))>.0002 or bounds.end.distance_to(Vector3(hi[0],hi[1],hi[2]))>.0002:
   return {'ok':false,'reason':'Reception component geometry changed'}
 # Commit only after all source components and collision have been validated.
 var packed=hall.mesh.get('_surfaces').duplicate();var before=hall.mesh
 for s in edits:
  var a=edits[s]
  for i in selected[s]:
   a[Mesh.ARRAY_VERTEX][i]=hall.global_transform.affine_inverse()*mapped(hall.global_transform*a[Mesh.ARRAY_VERTEX][i])
   var n=hall.global_basis*a[Mesh.ARRAY_NORMAL][i];n.x/=WIDTH_SCALE;a[Mesh.ARRAY_NORMAL][i]=(hall.global_basis.inverse()*n).normalized()
   var t=a[Mesh.ARRAY_TANGENT]
   if t!=null and t.size()>i*4+3:
    var v=hall.global_basis*Vector3(t[i*4],t[i*4+1],t[i*4+2]);v.x*=WIDTH_SCALE;v=(hall.global_basis.inverse()*v).normalized();t[i*4]=v.x;t[i*4+1]=v.y;t[i*4+2]=v.z
  var part=ArrayMesh.new();part.add_surface_from_arrays(hall.mesh.surface_get_primitive_type(s),a);part.surface_set_material(0,hall.mesh.surface_get_material(s));packed[s]=part.get('_surfaces')[0]
 var result=ArrayMesh.new();result.set('_surfaces',packed)
 for key in before.get_meta_list():result.set_meta(key,before.get_meta(key))
 hall.mesh=result
 var shape=body.get_child(0).shape.duplicate();shape.size=Vector3(2.4,1.16,1.2);body.get_child(0).shape=shape;body.position=Vector3(0,.82,-22);body.reparent(owner,true)
 body.name='Reception desk collision'
 var receipt={'ok':true,'root':owner,'mesh':hall.mesh,'before_mesh':before,'components':22,'selected':selected,'service':false,'desk_center':Vector3(0,.82,-22),'minimum_side_route':1.575,'plot_office_unchanged':true}
 owner.set_meta('role_scope','Reception ambience only; no interaction, quest or service')
 scene.set_meta(KEY,receipt);return receipt
