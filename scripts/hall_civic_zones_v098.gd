extends RefCounted
## Fixed civic wayfinding and two bounded furnishings, present at every quality tier.
static func material(color:String)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=Color(color);m.roughness=.84;return m
static func box(r:Node3D,n:String,p:Vector3,s:Vector3,m:Material):
 var v=MeshInstance3D.new();v.name=n;v.position=p;var b=BoxMesh.new();b.size=s;v.mesh=b;v.material_override=m;r.add_child(v);return v
static func label(r:Node3D,n:String,text:String,p:Vector3,size:float):
 var v=Label3D.new();v.name=n;v.text=text;v.position=p;v.pixel_size=size;v.font_size=32;v.outline_size=0;v.modulate=Color('#e0d4b6');r.add_child(v);return v
static func solid(r:Node3D,n:String,p:Vector3,s:Vector3):
 var b=StaticBody3D.new();b.name=n;b.position=p;b.set_meta('audio_surface','wood');r.add_child(b)
 var c=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=s;c.shape=shape;b.add_child(c)
static func add_to(scene:Node3D):
 var assembly=scene.get_node('HallReceptionAssemblyV098')
 var zones=Node3D.new();zones.name='HallCivicZonesV098';scene.add_child(zones)
 var wood=material('#624b35');var dark=material('#45392d');var fabric=material('#5e7068');var paper=material('#cabe9e');var ink=material('#566458')
 # 2.6 m screen: 1.575 m clear to the existing nave column faces on each side.
 box(assembly,'Low reception screen',Vector3(0,.765,-23.8),Vector3(2.6,1.05,.12),fabric)
 box(assembly,'Screen timber cap',Vector3(0,1.30,-23.8),Vector3(2.6,.06,.15),wood)
 solid(assembly,'Low screen collision',Vector3(0,.78,-23.8),Vector3(2.6,1.08,.15))
 # Compact supported desk sign. Existing single leaf crest remains on the front.
 box(assembly,'Welcome sign',Vector3(.45,1.60,-21.70),Vector3(1.30,.24,.04),dark)
 for x in [-.08,.98]:box(assembly,'Welcome sign support',Vector3(x,1.47,-21.70),Vector3(.035,.14,.035),wood)
 label(assembly,'Reception label','WELCOME',Vector3(.45,1.60,-21.674),.0036)
 # Old desk bay becomes a seated waiting destination, within its old footprint.
 box(zones,'Waiting bench seat',Vector3(5,.72,-19),Vector3(2.10,.12,.60),wood)
 box(zones,'Waiting bench back',Vector3(5,1.04,-19.25),Vector3(2.10,.60,.10),wood)
 for x in [4.12,5.88]:
  for z in [-18.78,-19.22]:box(zones,'Waiting bench leg',Vector3(x,.45,z),Vector3(.10,.42,.10),wood)
 solid(zones,'Waiting bench collision',Vector3(5,.79,-19),Vector3(2.10,1.10,.65))
 # Noticeboard shares the existing wall planting bay; no new floor obstruction.
 var board=Node3D.new();board.name='Waiting notices';board.position=Vector3(8.45,1.90,-19);board.rotation.y=-PI/2;zones.add_child(board)
 box(board,'Noticeboard frame',Vector3.ZERO,Vector3(1.80,.95,.08),dark)
 box(board,'Noticeboard inset',Vector3(0,0,.047),Vector3(1.66,.81,.012),fabric)
 label(board,'Noticeboard title','TOWN NOTICES',Vector3(0,.29,.061),.0027)
 for x in [-.51,0,.51]:
  box(board,'Pinned notice',Vector3(x,-.10,.06),Vector3(.38,.42,.008),paper)
  for y in [-.03,-.11,-.19]:box(board,'Notice ink',Vector3(x,y,.066),Vector3(.27,.009,.003),ink)
 # Plot Office's existing desk, actor, model and interaction target remain exact.
 var plot=Node3D.new();plot.name='Plot Office sign';zones.add_child(plot)
 box(plot,'Plot sign board',Vector3(5.5,2.14,-31.10),Vector3(2.40,.55,.08),dark)
 for x in [4.40,6.60]:box(plot,'Plot sign post',Vector3(x,1.07,-31.10),Vector3(.07,1.66,.07),wood)
 label(plot,'Plot Office label','PLOT OFFICE',Vector3(5.5,2.18,-31.047),.005)
 label(plot,'Plot Office subtitle','Plots & settlement plans',Vector3(5.5,1.98,-31.047),.0022)
 # Gallery signage stays on its existing front guard, not the stair opening.
 box(zones,'Gallery wayfinding plaque',Vector3(-5.80,4.59,-14.96),Vector3(2.35,.25,.035),dark)
 label(zones,'Gallery reading label','RECORDS & READING',Vector3(-5.80,4.59,-14.936),.0032)
 # Bounded task light at the moved lamp; real illumination, no shadows.
 var light=OmniLight3D.new();light.name='Reception task light';light.position=Vector3(-.925,1.70,-22)
 light.light_color=Color(1,.72,.43);light.light_energy=.45;light.omni_range=2.3;light.shadow_enabled=false;assembly.add_child(light)
 light.set_meta('role_scope','Bounded reception task illumination')
 preload('res://scripts/hideout_terrace.gd').batch_static_visuals(zones)
 # Keep assembly children separate from imported mesh and actual service actors.
 zones.set_meta('scope',{'plot_service_unchanged':true,'reception_service':false,'added_bench':1,'new_lights':1,'minimum_central_clearance':1.575})
