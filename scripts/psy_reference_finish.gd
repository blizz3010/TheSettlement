extends RefCounted
# Selective Psy surface/display retention; no v2 canopy reshape or support movement.
static func side_panel(size:Vector3)->ArrayMesh:
 # Six broad boards per existing sidewall, consolidated into ONE surface, not twelve nodes.
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var count=6;var step=size.z/count
 for i in range(count):
  var board=BoxMesh.new();board.size=Vector3(size.x,size.y,step-.025)
  st.append_from(board,0,Transform3D(Basis.IDENTITY,Vector3(0,0,-size.z/2+(i+.5)*step)))
 return st.commit()
static func find_original_box(shop:Node3D,at:Vector3,size:Vector3)->Node3D:
 var matches=[]
 for child in shop.get_children():
  if not child is Node3D or not child.position.is_equal_approx(at):continue
  for mesh in child.get_children():
   if mesh is MeshInstance3D and mesh.mesh is BoxMesh and mesh.mesh.size.is_equal_approx(size):matches.append(child)
 assert(matches.size()==1,'Exact original geometry selector must resolve once')
 return matches[0]
static func retarget_support(node:Node3D,a:Vector3,b:Vector3):
 assert(node.find_children('*','CollisionObject3D',true,false).is_empty())
 node.position=(a+b)*.5;node.basis=Basis.looking_at(b-a,Vector3.UP)
 var mesh:MeshInstance3D=node.get_child(0);assert(mesh.mesh is BoxMesh)
 var size=mesh.mesh.size;mesh.mesh.size=Vector3(size.x,size.y,a.distance_to(b))
static func apply(shop:Node3D,spec:Dictionary,api,materials:Dictionary):
 assert(spec.id=='Psy' and not shop.has_meta('psy_selective_finish'))
 var started=Time.get_ticks_usec();var back:float=-spec.depth/2+.3
 var canopy:MeshInstance3D=shop.get_node('Rust red outfitter roof')
 var fabric=canopy.material_override.duplicate();assert(fabric is StandardMaterial3D)
 fabric.albedo_color=Color('935743');fabric.roughness=.94;canopy.material_override=fabric
 for x in [-spec.width/2+.25,spec.width/2-.25]:
  var side=find_original_box(shop,Vector3(x,1.35,-.5),Vector3(.18,2.5,spec.depth-1.6))
  var mesh:MeshInstance3D=side.get_child(0);mesh.mesh=side_panel(mesh.mesh.size)
 var display=Node3D.new();display.name='OutfitterDisplayBacking';shop.add_child(display)
 for x in [-2.0,0.0,2.0]:api.box(display,'Recessed gear bay',Vector3(x,1.62,back+.12),Vector3(1.88,2.12,.04),materials.dark,false)
 for x in [-3.0,-1.0,1.0,3.0]:api.box(display,'Display timber stile',Vector3(x,1.62,back+.18),Vector3(.10,2.22,.10),materials.wood,false)
 for y in [.51,2.73]:api.box(display,'Display bound edge',Vector3(0,y,back+.19),Vector3(6.1,.085,.09),materials.bronze,false)
 shop.set_meta('psy_selective_finish',{'rear_boxes':9,'sidewall_surfaces':2,'canvas_material_clones':1,'canopy_geometry_unchanged':true,'supports_unchanged':true,'new_colliders':0,'new_lights':0,'elapsed_ms':float(Time.get_ticks_usec()-started)/1000.0})
