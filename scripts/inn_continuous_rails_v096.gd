extends RefCounted
# Continuous visual timber over the exact existing side-rail collision envelope.
# No tread, post, body, shape, path or clearance is changed. Every tier keeps it.
const HALF_HEIGHT=.14
const WIDTH=.12
static func sloped_box(size:Vector3,slope:float)->ArrayMesh:
 var source=BoxMesh.new();source.size=size
 var arrays=source.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 for i in vertices.size():
  vertices[i].y+=vertices[i].z*slope
  var n=normals[i];normals[i]=Vector3(n.x,n.y,n.z-slope*n.y).normalized()
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
static func box(parent:Node3D,label:String,p:Vector3,size:Vector3,mat:Material)->MeshInstance3D:
 var n=MeshInstance3D.new();n.name=label;n.position=p;var mesh=BoxMesh.new();mesh.size=size;n.mesh=mesh;n.material_override=mat;parent.add_child(n);return n
static func merge_parts(target:MeshInstance3D,parts:Array):
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 st.append_from(target.mesh,0,Transform3D.IDENTITY)
 for part in parts:
  st.append_from(part.mesh,0,target.transform.affine_inverse()*part.transform);part.free()
 target.mesh=st.commit()
static func fail(reason:String)->Dictionary:
 return {'ok':false,'stage':'inn_continuous_rails_v096','reason':reason}
static func valid_box(node:Node,size:Vector3,position:Vector3)->bool:
 return node is MeshInstance3D and node.mesh is BoxMesh and node.mesh.size.is_equal_approx(size) and node.position.is_equal_approx(position) and node.basis.is_equal_approx(Basis.IDENTITY)
static func valid_body(terrace:Node3D,visual:MeshInstance3D)->bool:
 var body=terrace.get_node_or_null(str(visual.name)+'Body')
 if not body is StaticBody3D or not body.transform.is_equal_approx(visual.transform) or body.get_child_count()!=1:return false
 var shape=body.get_child(0)
 return shape is CollisionShape3D and shape.shape is BoxShape3D and shape.shape.size.is_equal_approx(visual.mesh.size) and shape.transform.is_equal_approx(Transform3D.IDENTITY) and not shape.disabled and body.collision_layer==1 and body.collision_mask==1
static func preflight(site:Node3D,rise:float,depth:float)->Dictionary:
 if not is_instance_valid(site):return fail('Missing site owner')
 if not is_finite(rise) or rise<=0 or rise>.18 or not is_finite(depth) or not is_equal_approx(depth,.56):return fail('Unsupported rail rise or tread depth')
 var terrace=site.get_node_or_null('TerraceAndApproach')
 if not terrace is Node3D or not terrace.transform.is_equal_approx(Transform3D.IDENTITY):return fail('Terrace owner or transform changed')
 if terrace.has_node('ContinuousInnRailsV096'):return fail('Continuous rail owner already exists without a valid completion receipt')
 var originals=[]
 for n in terrace.get_children():
  if str(n.name).begins_with('RailCap') and not str(n.name).ends_with('Body'):originals.append(n)
 if originals.size()!=40:return fail('Exact forty legacy rail cap visuals required')
 var source=originals[0]
 if not source is MeshInstance3D or not source.material_override is ShaderMaterial:return fail('Missing finished timber material')
 var material=source.material_override
 if material.shader!=preload('res://shaders/inn_surface_v094.gdshader') or material.get_shader_parameter('tint')!=Color('644730'):return fail('Legacy rail material provenance changed')
 var expected=[];var ends=[]
 for x in [2.66,5.54]:
  for i in range(20):
   var suffix=str(i)+'_'+str(x).replace('.','_');var position=Vector3(x,3.4-(19-i)*rise+1,32+(i+.5)*depth)
   var cap=terrace.get_node_or_null('RailCap'+suffix);var post=terrace.get_node_or_null('RailPost'+suffix)
   if not valid_box(cap,Vector3(WIDTH,.10,depth),position):return fail('Legacy cap geometry changed: '+suffix)
   if cap.material_override!=material or not valid_body(terrace,cap):return fail('Legacy cap material or collider changed: '+suffix)
   if not valid_box(post,Vector3(.10,1,.10),position-Vector3(0,.5,0)) or not valid_body(terrace,post):return fail('Legacy post geometry or collider changed: '+suffix)
   expected.append(cap)
  ends.append({'x':x,'first':terrace.get_node('RailPost0_'+str(x).replace('.','_')),'last':terrace.get_node('RailPost19_'+str(x).replace('.','_'))})
 for cap in originals:
  if not cap in expected:return fail('Unexpected legacy rail cap')
 for spec in [['NorthGuardWest',Vector3(-3.2,3.92,43.25),Vector3(11.6,1.04,.10)],['NorthGuardEast',Vector3(7.3,3.92,43.25),Vector3(3.4,1.04,.10)]]:
  var guard=terrace.get_node_or_null(spec[0])
  if not valid_box(guard,spec[2],spec[1]) or not valid_body(terrace,guard):return fail('Landing guard geometry or collider changed: '+spec[0])
 return {'ok':true,'terrace':terrace,'originals':originals,'material':material,'ends':ends,'guard_top':terrace.get_node('NorthGuardWest').position.y+.52}
static func apply(site:Node3D,rise:float,depth:float)->Dictionary:
 if not is_instance_valid(site):return fail('Missing site owner')
 if site.has_meta('inn_continuous_rails_v096'):
  var receipt=site.get_meta('inn_continuous_rails_v096');var completed=site.get_node_or_null('TerraceAndApproach/ContinuousInnRailsV096')
  if receipt is Dictionary and receipt.get('ok',false) and completed is Node3D and completed.get_child_count()==40:return receipt
  return fail('Invalid continuous rail completion receipt')
 # Read every dependency before touching the source scene. Build off-tree, then
 # commit once all replacement spans and returns exist. Works in release builds.
 var plan=preflight(site,rise,depth)
 if not plan.get('ok',false):return plan
 var terrace=plan.terrace;var originals=plan.originals
 var root=Node3D.new();root.name='ContinuousInnRailsV096'
 var material=plan.material.duplicate()
 material.set_shader_parameter('grain_axis',2)
 var slope=rise/depth;var mesh=sloped_box(Vector3(WIDTH,HALF_HEIGHT*2,depth),slope)
 var rows=[]
 for old in originals:
  var n=MeshInstance3D.new();n.name=str(old.name).replace('RailCap','ConnectedSpan');n.transform=old.transform;n.mesh=mesh;n.material_override=material;root.add_child(n)
  rows.append({'span':str(n.name),'legacy_body':str(old.name)+'Body','center':old.position,'slope':slope,'depth':depth,'width':WIDTH,'half_height':HALF_HEIGHT})
 # The front ends return down and back into the first unchanged posts. The upper
 # ends return into the existing landing guard rather than stopping in space.
 for end in plan.ends:
  var x=end.x;var first=end.first;var last=end.last
  var start_z:float=first.position.z-depth*.5
  var start_y:float=first.position.y+.5-rise*.5
  var lower_nose=box(root,'Lower closed return '+str(x),Vector3(x,start_y-.06,start_z+.06),Vector3(WIDTH,.40,.12),material)
  var lower_butt=box(root,'Lower return to first post '+str(x),Vector3(x,start_y-.22,start_z+.17),Vector3(WIDTH,.08,.22),material)
  var end_z:float=last.position.z+depth*.5;var end_y:float=last.position.y+.5+rise*.5
  var guard_top:float=plan.guard_top;var bottom:float=guard_top-.10
  var upper_nose=box(root,'Landing returned joint '+str(x),Vector3(x,(end_y+HALF_HEIGHT+bottom)*.5,end_z+.045),Vector3(WIDTH,end_y+HALF_HEIGHT-bottom,.09),material)
  var upper_butt=box(root,'Landing guard butt '+str(x),Vector3(x,guard_top-.03,end_z+.045),Vector3(WIDTH,.14,.09),material)
  merge_parts(root.get_node('ConnectedSpan0_'+str(x).replace('.','_')),[lower_nose,lower_butt])
  merge_parts(root.get_node('ConnectedSpan19_'+str(x).replace('.','_')),[upper_nose,upper_butt])
 if root.get_child_count()!=40 or not root.find_children('*','CollisionObject3D',true,false).is_empty():
  root.free();return fail('Detached rail output failed validation')
 terrace.add_child(root)
 for old in originals:old.free()
 var report={'ok':true,'connected_spans':40,'end_return_parts':8,'rows':rows,'always_on':true,'collision_changes':false,'old_cap_meshes_removed':40,'retained_rail_cap_bodies':40,'nominal_width':3.0,'inner_clearance':2.76,'new_lights':0,'triangles':576,'draw_surfaces':40,'materials':1,'reason_for_section':'The continuous timber section encloses every unchanged horizontal cap collider; no invisible collision projects beyond the replacement rail.'}
 site.set_meta('inn_continuous_rails_v096',report);return report
