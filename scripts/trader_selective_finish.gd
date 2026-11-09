extends RefCounted
const Psy=preload('res://scripts/psy_reference_finish.gd')
static func roof_underside(x:float,z:float,roofs:Array)->float:
 var heights=[]
 for roof in roofs:
  var mesh:MeshInstance3D=roof.get_child(0);var size:Vector3=mesh.mesh.size
  var n:Vector3=roof.basis.y.normalized();var plane:Vector3=roof.position-roof.basis.y*size.y*.5
  var y=(n.dot(plane)-n.x*x-n.z*z)/n.y
  var local:Vector3=roof.transform.affine_inverse()*Vector3(x,y,z)
  if absf(local.x)<=size.x*.5+.00001 and absf(local.z)<=size.z*.5+.00001:heights.append(y)
 assert(not heights.is_empty(),'Rear cloth edge must meet actual pitched roof underside')
 return heights.min()
static func apply(shop:Node3D,spec:Dictionary,api,materials:Dictionary):
 if spec.id=='Atlas':return # No demonstrated gain: leave original entire stand untouched.
 if spec.id=='Psy':Psy.apply(shop,spec,api,materials);return
 assert(spec.id=='Dan' and not shop.has_meta('dan_supported_cloth'))
 var started=Time.get_ticks_usec();var front:float=spec.depth/2-.7;var rear_z:float=front-1.5
 var roof_size=Vector3(sqrt(pow(spec.width/2,2)+pow(1.1,2)),.14,spec.depth-1)
 var roofs=[]
 for side in [-1,1]:roofs.append(Psy.find_original_box(shop,Vector3(side*spec.width/4,4.05+1.1/2,-.5),roof_size))
 var beam=Psy.find_original_box(shop,Vector3(0,3.7,front),Vector3(spec.width,.24,.25))
 var beam_mesh:MeshInstance3D=beam.get_child(0)
 assert(beam.basis==Basis.IDENTITY)
 var front_y:float=beam.position.y+beam_mesh.mesh.size.y*.5
 var front_z:float=beam.position.z+beam_mesh.mesh.size.z*.5
 var width:float=spec.width-.12
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var nx=16;var nz=6;var rear_heights=[]
 for ix in range(nx+1):rear_heights.append(roof_underside((float(ix)/nx-.5)*width,rear_z,roofs))
 for ix in range(nx):
  for iz in range(nz):
   var q=[]
   for ij in [Vector2(ix,iz),Vector2(ix+1,iz),Vector2(ix+1,iz+1),Vector2(ix,iz+1)]:
    var u=ij.x/nx;var v=ij.y/nz
    q.append(Vector3((u-.5)*width,lerpf(rear_heights[int(ij.x)],front_y,v)-sin(v*PI)*sin(u*PI)*.07,lerpf(rear_z,front_z,v)))
   for k in [0,2,1,0,3,2]:st.add_vertex(q[k])
 # Attached front hem hugs existing beam face; remains well above unchanged sign.
 for ix in range(nx):
  var a=Vector3((float(ix)/nx-.5)*width,front_y,front_z)
  var b=Vector3((float(ix+1)/nx-.5)*width,front_y,front_z)
  var da=Vector3(0,-.09,.003);var db=Vector3(0,-.09,.003)
  for p in [a,b,b+db,a,b+db,a+da]:st.add_vertex(p)
 st.generate_normals()
 var canopy:MeshInstance3D=shop.get_node('Ochre market cloth awning');canopy.mesh=st.commit()
 var fabric=canopy.material_override.duplicate();assert(fabric is StandardMaterial3D)
 fabric.albedo_color=Color('b49b6c');fabric.roughness=.94;fabric.cull_mode=BaseMaterial3D.CULL_DISABLED;canopy.material_override=fabric
 var attachments=[]
 for x in [-spec.width/2+.3,0.0,spec.width/2-.3]:
  var old_a=Vector3(x,3.95,rear_z);var old_b=Vector3(x,3.48,front+.45)
  var stay=Psy.find_original_box(shop,(old_a+old_b)*.5,Vector3(.065,.065,old_a.distance_to(old_b)))
  var a=Vector3(x,roof_underside(x,rear_z,roofs),rear_z);var b=Vector3(x,front_y,front_z)
  Psy.retarget_support(stay,a,b);attachments.append({'rear':a,'front':b})
 assert(canopy.mesh.get_aabb().position.y>=3.70)
 shop.set_meta('dan_supported_cloth',{'roof_contacts':rear_heights,'rear_z':rear_z,'front_y':front_y,'front_z':front_z,'stays':attachments,'triangles':224,'added_colliders':0,'added_lights':0,'new_services':0,'elapsed_ms':float(Time.get_ticks_usec()-started)/1000.0})
