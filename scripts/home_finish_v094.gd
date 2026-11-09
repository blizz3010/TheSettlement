extends RefCounted
# HM01–HM03. Local visual finish only; original collision/plot coordinates unchanged.
const SHADER=preload('res://shaders/peripheral_surface_v094.gdshader')
static func finish_material(tint:Color,kind:int=0,contact:float=0.0)->ShaderMaterial:
 var m=ShaderMaterial.new();m.shader=SHADER;m.set_shader_parameter('tint',tint);m.set_shader_parameter('kind',kind);m.set_shader_parameter('contact',contact);return m
static func plot_material()->ShaderMaterial:return finish_material(Color(.225,.255,.155),1)
static func box(root:Node3D,label:String,at:Vector3,size:Vector3,material:Material)->MeshInstance3D:
 var n=MeshInstance3D.new();n.name=label;var m=BoxMesh.new();m.size=size;n.mesh=m;n.material_override=material;n.position=at;root.add_child(n);return n
static func bevel_step(size:Vector3)->ArrayMesh:
 # A 25mm stone arris within the inherited solid box, never an overhanging tread.
 var x=size.x/2;var y=size.y/2;var z=size.z/2;var b=.025
 var cross_section=[Vector2(-x,-y),Vector2(x,-y),Vector2(x,y-b),Vector2(x-b,y),Vector2(-x,y)]
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in cross_section.size():
  var a=cross_section[i];var c=cross_section[(i+1)%cross_section.size()]
  var aa=Vector3(a.x,a.y,-z);var ab=Vector3(a.x,a.y,z);var ca=Vector3(c.x,c.y,-z);var cb=Vector3(c.x,c.y,z)
  for p in [aa,ab,ca,ca,ab,cb]:st.add_vertex(p)
 for side in [-1,1]:
  for i in range(1,cross_section.size()-1):
   var tri=[cross_section[0],cross_section[i+1],cross_section[i]] if side==1 else [cross_section[0],cross_section[i],cross_section[i+1]]
   for p in tri:st.add_vertex(Vector3(p.x,p.y,z*side))
 st.generate_normals();return st.commit()
static func apply(scene:Node3D,terrace:Node3D)->Dictionary:
 assert(not scene.has_node('HomePreparedFinishV094'))
 var root=Node3D.new();root.name='HomePreparedFinishV094';scene.add_child(root)
 var wall=finish_material(Color(.345,.327,.275),0,1.0)
 var stone=finish_material(Color(.435,.407,.338),0,.65)
 var quiet=finish_material(Color(.385,.368,.306))
 var turf=finish_material(Color(.19,.235,.13),1)
 var step_count=0
 # Select material identities, not auto-generated duplicate node names. This keeps
 # all original batching groups and the ordered native foliage authority exact.
 var old_wall=terrace.get_node('Retaining terrace').get_child(0).material_override
 var old_cap=terrace.get_node('Perimeter paving').get_child(0).material_override
 var old_turf=terrace.get_node('Empty build turf').get_child(0).material_override
 for node in terrace.find_children('*','MeshInstance3D',true,false):
  var label=str(node.get_parent().name)
  if node.material_override==old_wall:node.material_override=wall
  elif node.material_override==old_cap:node.material_override=stone
  elif node.material_override==old_turf:node.material_override=turf
  if label.begins_with('Lower step') or label.begins_with('Upper step'):
   var size:Vector3=node.mesh.size
   var arris=MeshInstance3D.new();arris.name='Stone tread arris';arris.mesh=bevel_step(Vector3(.045,.035,size.z-.035));arris.material_override=quiet
   arris.position=node.global_position+Vector3(size.x*.5-.021,size.y*.5-.014,0);root.add_child(arris);step_count+=1
 for node in terrace.find_children('*','MultiMeshInstance3D',true,false):
  if node.name=='Retaining stone courses':node.material_override=stone
 # Fine joints only on existing top promenade; keep 12×12 build reserve untouched.
 for side in [-1,1]:
  for i in range(1,16):box(root,'Promenade joint',Vector3(-32+i,3.032,15+side*7),Vector3(.012,.003,1.92),quiet)
  for i in range(1,12):box(root,'Side promenade joint',Vector3(-24+side*7,3.032,9+i),Vector3(1.92,.003,.012),quiet)
 # Arrival sits east of x=-18 maximum build boundary, with no lip or collider.
 box(root,'Arrival threshold',Vector3(-16.75,3.033,15),Vector3(1.36,.006,2.95),quiet)
 for z in [13.65,16.35]:box(root,'Threshold inset',Vector3(-16.75,3.038,z),Vector3(1.20,.004,.035),stone)
 # Keep existing coping and bronze caps. Recessed drip course defines their underside.
 for z in [6.902,23.098]:box(root,'Coping drip shadow',Vector3(-24,2.79,z),Vector3(15.95,.025,.008),quiet)
 box(root,'West coping drip shadow',Vector3(-32.098,2.79,15),Vector3(.008,.025,15.95),quiet)
 # Low plinth fillet improves contact, within the original existing reserve margins.
 for z in [6.925,23.075]:box(root,'Base contact course',Vector3(-24,.12,z),Vector3(16,.16,.075),quiet)
 box(root,'West base contact course',Vector3(-32.075,.12,15),Vector3(.075,.16,16),quiet)
 # Tiny corner soil pockets give retained plants an anchored maintained setting.
 var soil=finish_material(Color(.16,.145,.105))
 for p in [Vector3(-16.7,-.037,6.2),Vector3(-29,-.037,23.7),Vector3(-19,-.037,23.7)]:
  var n=MeshInstance3D.new();n.name='Existing planting soil pocket';var m=CylinderMesh.new();m.top_radius=.60;m.bottom_radius=.60;m.height=.010;m.radial_segments=14;n.mesh=m;n.material_override=soil;n.position=p;root.add_child(n)
 var result={'ok':true,'beveled_treads':step_count,'build_reserve':Rect2(-30,9,12,12),'new_colliders':0,'new_lights':0,'original_plants_reused':true,'plot_state_unchanged':true}
 result.visual_batches=batch_visuals(root)
 assert(step_count==18);root.set_meta('home_finish_v094',result);return result

static func batch_visuals(root:Node3D)->int:
 # Only freshly authored visual-only meshes are combined, never imported art,
 # authoritative terrace batches, collision owners, or mounted text.
 var groups={}
 for n in root.find_children('*','MeshInstance3D',true,false):
  if n.mesh==null or n.mesh is TextMesh:continue
  var material=n.material_override
  var key=str(material.get_instance_id())+':'+str(n.cast_shadow)
  if not groups.has(key):
   var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);groups[key]={'st':st,'material':material,'shadow':n.cast_shadow}
  var transform=root.global_transform.affine_inverse()*n.global_transform
  for surface in n.mesh.get_surface_count():groups[key].st.append_from(n.mesh,surface,transform)
  n.free()
 for group in groups.values():
  var n=MeshInstance3D.new();n.name='Local finish batch';n.mesh=group.st.commit();n.material_override=group.material;n.cast_shadow=group.shadow;root.add_child(n)
 return groups.size()
