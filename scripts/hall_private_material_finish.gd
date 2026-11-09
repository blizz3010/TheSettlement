extends RefCounted
# Instance-only finish for the retained Hall root after production styling/floor cut.
const EXPECTED_SHADER='res://assets/materials/architecture_surface.gdshader'
const TARGETS={'Reference_Oiled_Timber_0':1,'Reference_Oiled_Timber_1':1,'Reference_Weathered_Bronze':2}
const KEY='hall_private_material_finish'
static func fail(reason:String)->Dictionary:return {'ok':false,'reason':reason}
static func snapshot(m:ShaderMaterial)->Dictionary:
 return {'name':m.resource_name,'kind':m.get_shader_parameter('kind'),'tint':m.get_shader_parameter('tint'),'roughness':m.get_shader_parameter('roughness'),'metallic':m.get_shader_parameter('metallic')}
static func receipt_valid(root:Node3D,r:Dictionary)->bool:
 if not is_instance_valid(root) or root.is_queued_for_deletion():return false
 if r.get('owner_id',0)!=root.get_instance_id() or not r.get('mesh_node') is WeakRef:return false
 var node=r.mesh_node.get_ref()
 if not is_instance_valid(node) or not node is MeshInstance3D or not root.is_ancestor_of(node):return false
 if node.mesh!=r.get('mesh') or node.mesh==null or node.mesh.get_surface_count()!=18:return false
 if not r.get('originals') is Dictionary or not r.get('private') is Dictionary or not r.get('expected') is Dictionary or not r.get('before') is Dictionary:return false
 if r.originals.size()!=3 or r.private.size()!=3 or r.expected.size()!=3 or r.before.size()!=3:return false
 for s in r.originals:
  if not s is int or s<0 or s>=18 or not r.private.has(s) or not r.expected.has(s) or not r.before.has(s):return false
  var original=r.originals[s];var private=r.private[s]
  if not original is ShaderMaterial or not private is ShaderMaterial or private==original:return false
  if private.shader!=original.shader or private.shader==null or private.shader.resource_path!=EXPECTED_SHADER:return false
  if node.get_surface_override_material(s)!=private or snapshot(private)!=r.expected[s] or snapshot(original)!=r.before[s]:return false
 return true
static func apply(root:Node3D)->Dictionary:
 if not is_instance_valid(root) or root.is_queued_for_deletion():return fail('Retained Hall root unavailable')
 if root.has_meta(KEY):
  var previous=root.get_meta(KEY)
  if not previous is Dictionary or not receipt_valid(root,previous):return fail('Foreign or stale Hall finish receipt')
  return {'ok':true,'receipt':previous,'reused':true}
 var matches=[]
 for child in root.find_children('*','MeshInstance3D',true,false):
  if child.mesh!=null and child.mesh.get_surface_count()==18:matches.append(child)
 if matches.size()!=1:return fail('Exact Hall 18-surface mesh unresolved')
 var hall:MeshInstance3D=matches[0]
 var originals={};var private={};var expected={};var before_all={};var names={};var journal=[]
 for s in range(18):
  var active=hall.get_active_material(s)
  if active==null or not TARGETS.has(active.resource_name):continue
  if names.has(active.resource_name):return fail('Duplicate Hall target identity')
  names[active.resource_name]=true
  if not active is ShaderMaterial or active.shader==null or active.shader.resource_path!=EXPECTED_SHADER:return fail('Hall shader identity changed')
  var kind=TARGETS[active.resource_name];var base=hall.mesh.surface_get_material(s)
  if not base is StandardMaterial3D:return fail('Hall source material type changed')
  var before=snapshot(active);var tint=base.albedo_color.darkened(.48 if kind==1 else .36)
  if before.kind!=kind or before.tint!=tint:return fail('Hall original parameters changed')
  if not (before.roughness is float or before.roughness is int) or not (before.metallic is float or before.metallic is int):return fail('Hall scalar parameters malformed')
  if not is_equal_approx(before.roughness,.80 if kind==1 else .64) or not is_equal_approx(before.metallic,0.0 if kind==1 else .68):return fail('Hall original roughness/metallic changed')
  var copy=active.duplicate() as ShaderMaterial
  if copy==null or copy==active or copy.shader!=active.shader:return fail('Private Hall material duplication failed')
  copy.set_shader_parameter('tint',tint*(Color(1.18,1.10,1.03,1) if kind==1 else Color(1.10,1.06,1.0,1)))
  copy.set_shader_parameter('roughness',.74 if kind==1 else .52)
  originals[s]=active;private[s]=copy;expected[s]=snapshot(copy);before_all[s]=before
  journal.append({'surface':s,'name':active.resource_name,'before':before,'after':expected[s]})
 if originals.size()!=3 or names.size()!=3:return fail('Expected exactly two timber and one bronze targets')
 # No writes occurred before every target was checked and privately prepared.
 var receipt={'owner_id':root.get_instance_id(),'mesh_node':weakref(hall),'mesh':hall.mesh,'originals':originals,'private':private,'expected':expected,'before':before_all,'journal':journal}
 for s in private:hall.set_surface_override_material(s,private[s])
 root.set_meta(KEY,receipt)
 return {'ok':true,'receipt':receipt,'reused':false}
static func restore(root:Node3D,receipt:Dictionary)->Dictionary:
 if not receipt_valid(root,receipt):return fail('Refusing stale/foreign Hall restore')
 if not root.has_meta(KEY) or root.get_meta(KEY)!=receipt:return fail('Hall receipt ownership changed')
 var hall:MeshInstance3D=receipt.mesh_node.get_ref()
 # Validate every member before restoring any material.
 for s in receipt.originals:hall.set_surface_override_material(s,receipt.originals[s])
 root.remove_meta(KEY)
 return {'ok':true}
