extends RefCounted
# SH01–SH02. Reuses the two imported service crates. No ship mesh, collision,
# ramp, beacon light or saved-state changes. One MK12-reviewed local paint override.
const Home=preload('res://scripts/home_finish_v094.gd')
static func mat(c:Color,metal:float=0.0)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=c;m.roughness=.87;m.metallic=metal;return m
static func arc(root:Node3D,label:String,inner:float,outer:float,y:float,material:Material,start:float=0.0,end:float=TAU):
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var count=ceili((end-start)/TAU*96)
 for i in count:
  var a=lerpf(start,end,float(i)/count);var b=lerpf(start,end,float(i+1)/count)
  var aa=Vector3(cos(a)*inner,y,sin(a)*inner);var ab=Vector3(cos(a)*outer,y,sin(a)*outer)
  var ba=Vector3(cos(b)*inner,y,sin(b)*inner);var bb=Vector3(cos(b)*outer,y,sin(b)*outer)
  for p in [aa,ba,ab,ba,bb,ab]:st.set_normal(Vector3.UP);st.add_vertex(p)
 var n=MeshInstance3D.new();n.name=label;n.mesh=st.commit();n.material_override=material;root.add_child(n);return n
static func beam(root:Node3D,label:String,a:Vector3,b:Vector3,width:float,height:float,material:Material):
 # Cable endpoints and midpoint are pad-local; keep orientation local too.
 # look_at_from_position uses world coordinates and moves translated parents' beams.
 var n=Home.box(root,label,(a+b)*.5,Vector3(width,height,a.distance_to(b)),material)
 n.basis=Basis.looking_at(b-a,Vector3.UP)
 return n
static func apply(pad:Node3D)->Dictionary:
 assert(not pad.has_node('ServicedPadFinishV094'))
 var paint=apply_reviewed_paint(pad)
 var root=Node3D.new();root.name='ServicedPadFinishV094';pad.add_child(root)
 var graphite=mat(Color(.17,.205,.20),.35)
 var seam=mat(Color(.245,.26,.24))
 var stone=Home.finish_material(Color(.39,.385,.335))
 var ochre=mat(Color(.52,.37,.15))
 # Maintain the imported crate positions, adding restraint bands and a single tag.
 for p in [Vector3(-5,1.29,-4.7),Vector3(-4,1.29,-5.8)]:
  for x in [-.34,.34]:
   Home.box(root,'Cargo restraint',p+Vector3(x,.729,0),Vector3(.045,.012,.80),graphite)
   Home.box(root,'Crate strap face',p+Vector3(x,.36,.405),Vector3(.045,.72,.012),graphite)
  Home.box(root,'Cargo foot contact',p+Vector3(0,-.002,0),Vector3(1.13,.006,.84),seam)
 Home.box(root,'Service crate identification',Vector3(-5,1.79,-4.288),Vector3(.42,.18,.012),ochre)
 # Cable is retained entirely at the north-west service edge, not across the ramp.
 var cable=[Vector3(-5.48,1.31,-4.38),Vector3(-6.12,1.31,-4.38),Vector3(-6.52,1.31,-3.66),Vector3(-6.52,1.31,-1.28)]
 for i in range(cable.size()-1):beam(root,'Secured service cable',cable[i],cable[i+1],.033,.026,graphite)
 for z in [-3.3,-2.1,-1.3]:Home.box(root,'Cable retaining clip',Vector3(-6.52,1.332,z),Vector3(.095,.025,.055),ochre)
 # Four small pad alignment brackets, outside the hull and all four support shoes.
 for x in [-5.9,5.9]:
  for z in [-3.4,3.4]:
   Home.box(root,'Pad alignment marking',Vector3(x,1.286,z),Vector3(.44,.006,.055),ochre)
   Home.box(root,'Pad alignment return',Vector3(x-signf(x)*.20,1.286,z-signf(z)*.18),Vector3(.055,.006,.40),ochre)
 # Landing shoe gaskets add contact only; the imported silhouette remains exact.
 for x in [-2.58,2.82]:
  for z in [-1.8,1.8]:Home.box(root,'Landing support contact',Vector3(x,1.285,z),Vector3(1.14,.008,.69),seam)
 # Narrow outer maintenance curb, with a deliberate opening for the whole ramp.
 arc(root,'Ground maintenance border',8.015,8.24,-.032,stone,0,1.35)
 arc(root,'Ground maintenance border',8.015,8.24,-.032,stone,1.79,TAU)
 arc(root,'Deck maintenance edge',7.18,7.31,1.286,stone,0,1.34)
 arc(root,'Deck maintenance edge',7.18,7.31,1.286,stone,1.80,TAU)
 for i in 16:
  var a=TAU*i/16
  if sin(a)>.97:continue
  var p=Vector3(cos(a)*8.004,.64,sin(a)*8.004)
  var n=Home.box(root,'Pad perimeter panel joint',p,Vector3(.014,.88,.008),seam);n.rotation.y=-a+PI*.5
 var result={'ok':true,'existing_service_crates':2,'new_crates':0,'support_contacts':4,'ramp_clear':true,'hull_paint':paint,'new_colliders':0,'new_lights':0}
 result.visual_batches=Home.batch_visuals(root)
 root.set_meta('ship_pad_finish_v094',result);return result

static func apply_reviewed_paint(pad:Node3D)->Dictionary:
 var matches=[]
 for node in pad.get_node('Art').find_children('*','MeshInstance3D',true,false):
  for surface in node.mesh.get_surface_count():
   var source=node.mesh.surface_get_material(surface)
   if source is StandardMaterial3D and source.resource_name=='Ivory ceramic painted hull':matches.append([node,surface,source])
 assert(matches.size()==1,'Expected one original ship paint surface')
 var node:MeshInstance3D=matches[0][0];var surface:int=matches[0][1];var source:StandardMaterial3D=matches[0][2]
 assert(surface==5 and node.name=='LaunchpadShip_Runtime')
 assert(source.albedo_color.is_equal_approx(Color(.6872172,.6689225,.6262097,1)))
 assert(is_equal_approx(source.metallic,.30) and is_equal_approx(source.roughness,.78))
 var original_color=source.albedo_color
 var local=source.duplicate() as StandardMaterial3D
 local.resource_name='Reviewed warm ivory paint V094';local.albedo_color=source.albedo_color.darkened(.24);local.metallic=.08;local.roughness=.86
 node.set_surface_override_material(surface,local)
 assert(source.albedo_color==original_color and is_equal_approx(source.metallic,.30) and is_equal_approx(source.roughness,.78))
 return {'surface':surface,'albedo_scale':.76,'metallic':.08,'roughness':.86,'source_unchanged':true,'diagnosis':'Native sun/shade fixture MK12'}
