extends RefCounted
# Original editable, deterministic visual landscape accents. No gameplay or physics.
static func leaves(root:Node3D,n:String,centers:Array,material:Material,kind:String):
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(centers.size()):
  var p:Vector3=centers[i]
  for j in range(7):
   var a=j*TAU/7+i*.73;var outward=Vector3(cos(a),0,sin(a));var across=Vector3(-sin(a),0,cos(a))
   var height=.22+(i%3)*.055;var radius=.27;var width=.075
   if kind=='sedge':height=.38+(i%4)*.035;radius=.13;width=.027
   if kind=='rosette':height=.16+(i%3)*.035;radius=.32;width=.10
   var base=p+outward*.035;var mid=p+outward*radius*.58+Vector3.UP*height
   var tip=p+outward*radius+Vector3.UP*height*.58
   for v in [base,mid-across*width,mid+across*width,mid-across*width,tip,mid+across*width]:st.add_vertex(v)
 st.generate_normals();var mesh=MeshInstance3D.new();mesh.name=n;mesh.mesh=st.commit();mesh.material_override=material;root.add_child(mesh)
 return centers.size()*14
static func apply(root:Node3D,specs:Array,api,materials:Dictionary):
 var leaf=api.mat(Color('#607253'));leaf.cull_mode=BaseMaterial3D.CULL_DISABLED
 var dry=api.mat(Color('#99916b'));dry.cull_mode=BaseMaterial3D.CULL_DISABLED
 var soil=api.mat(Color('#4f5142'))
 var triangles=0
 for spec in specs:
  var shop=root.get_node(spec.id+'Stand');var garden=Node3D.new();garden.name='LocalMarketSurroundings';shop.add_child(garden)
  var front:float=spec.depth/2-.7
  var centers=[];var x:float=spec.width/2+.64
  if spec.id=='Psy':
   # Dry resilient rosettes in two open gravel pockets, not another pot.
   for i in range(12):centers.append(Vector3(x+(i%3-1)*.20,.09,-1.5+(i/3)*.72))
   triangles+=leaves(garden,'Outfitter dry herb rosettes',centers,leaf,'rosette')
   for i in range(5):api.box(garden,'Weathered herb bed stone',Vector3(x+.23*sin(i*1.7),.055,-1.7+i*.65),Vector3(.27,.10,.20),materials.stone)
  elif spec.id=='Atlas':
   # Narrow utility-side sedge strip leaves the western collection apron clear.
   x=-spec.width/2-.56
   api.box(garden,'Recovery garden soil',Vector3(x,.025,-.45),Vector3(.62,.045,2.5),soil)
   for i in range(12):centers.append(Vector3(x+(i%2-.5)*.24,.055,-1.55+(i/2)*.40))
   triangles+=leaves(garden,'Recovery soft sedge',centers,dry,'sedge')
   api.box(garden,'Recovery low stone garden edge',Vector3(x-.38,.08,-.45),Vector3(.12,.16,2.65),materials.stone)
  else:
   # One low limestone herb border on the side, outside the market approach.
   api.box(garden,'Marketplace herb soil',Vector3(x,.12,-.6),Vector3(.68,.16,2.7),soil)
   for side in [-1,1]:api.box(garden,'Herb border limestone rim',Vector3(x+side*.40,.14,-.6),Vector3(.12,.28,2.94),materials.stone)
   for z in [-2.01,.81]:api.box(garden,'Herb border limestone end',Vector3(x,.14,z),Vector3(.9,.28,.12),materials.stone)
   for i in range(14):centers.append(Vector3(x+(i%2-.5)*.28,.21,-1.78+(i/2)*.37))
   triangles+=leaves(garden,'Marketplace soft herb border',centers,leaf,'herb')
   # Existing practical style, one local shadow-free fill; no global exposure change.
   var light=OmniLight3D.new();light.name='Market awning warm reflected fill';shop.add_child(light);light.position=Vector3(0,2.65,front-.95)
   light.light_color=Color('#ffe5bc');light.light_energy=1.15;light.omni_range=5.0;light.omni_attenuation=1.3;light.shadow_enabled=false
   light.light_cull_mask=2
   for mesh in shop.get_node('OfferingDetail').find_children('*','MeshInstance3D',true,false):mesh.layers=mesh.layers|2
   light.set_meta('local_readability_fill',true)
   # Woven seam and short canvas tabs, not another sign or promised service.
   for i in range(12):api.box(garden,'Ochre awning woven seam',Vector3(-4.5+i*.82,3.49,front+.46),Vector3(.68,.035,.025),materials.cream)
  assert(garden.find_children('*','CollisionObject3D',true,false).is_empty())
 root.set_meta('surroundings_detail',{'plant_triangles':triangles,'new_collisions':0,'local_shadow_free_lights':1,'gameplay_changes':false})
