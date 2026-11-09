extends RefCounted
# Original display-only meshes authored from user's pick/axe/sickle reference sheet.
# No item IDs, harvesting logic, prices, stock, durability or equip behavior.
static func extrude(root:Node3D,n:String,points:PackedVector2Array,depth:float,m:Material)->MeshInstance3D:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_color(Color(0,1,0,1))
 var triangles=Geometry2D.triangulate_polygon(points)
 assert(triangles.size()==(points.size()-2)*3,'Every custom tool silhouette needs a complete triangulated face: '+n)
 for side in [-1.0,1.0]:
  for i in range(0,triangles.size(),3):
   var ids=[triangles[i+2],triangles[i+1],triangles[i]] if side>0 else [triangles[i],triangles[i+1],triangles[i+2]]
   for idx in ids:st.add_vertex(Vector3(points[idx].x,points[idx].y,side*depth/2))
 for i in range(points.size()):
  var a=points[i];var b=points[(i+1)%points.size()]
  for p in [Vector3(b.x,b.y,depth/2),Vector3(b.x,b.y,-depth/2),Vector3(a.x,a.y,-depth/2),Vector3(a.x,a.y,depth/2),Vector3(b.x,b.y,depth/2),Vector3(a.x,a.y,-depth/2)]:st.add_vertex(p)
 st.generate_normals();var mesh=MeshInstance3D.new();mesh.name=n;mesh.mesh=st.commit();mesh.material_override=m;root.add_child(mesh);return mesh
static func make(root:Node3D,kind:String,api,m:Dictionary)->Node3D:
 var t=Node3D.new();t.name=kind+' reference display only';root.add_child(t)
 # Long asymmetric silhouette and curved wood grip distinguish hand tools from guns.
 var handle=extrude(t,'Wrapped wood handle',PackedVector2Array([Vector2(-.09,.05),Vector2(.05,.04),Vector2(.10,.34),Vector2(.05,.75),Vector2(-.03,1.18),Vector2(-.14,1.18),Vector2(-.06,.72),Vector2(-.02,.35)]),.105,m.wood)
 for i in range(10):
  var y=.10+i*.035;var band=api.box(t,'Woven grip wrap',Vector3(.0,y,.0),Vector3(.16,.020,.125),m.wrap);band.rotation.z=-.12
 api.box(t,'Bronze butt cap',Vector3(-.015,.06,0),Vector3(.20,.095,.15),m.bronze)
 api.box(t,'Bronze grip collar',Vector3(.015,.48,0),Vector3(.18,.085,.15),m.bronze)
 api.box(t,'Riveted head housing',Vector3(-.06,1.20,0),Vector3(.26,.28,.16),m.bronze)
 api.box(t,'Inset dark panel',Vector3(-.06,1.22,.086),Vector3(.115,.19,.018),m.dark)
 api.box(t,'Cyan power insert',Vector3(-.06,1.22,.10),Vector3(.046,.14,.018),m.cyan)
 for x in [-.15,.035]:
  for y in [1.11,1.30]:api.sphere(t,'Housing rivet',Vector3(x,y,.09),Vector3(.028,.028,.018),m.edge)
 if kind=='Mining pick':
  extrude(t,'Long tapered mining point',PackedVector2Array([Vector2(-.16,1.33),Vector2(-.47,1.36),Vector2(-.77,1.26),Vector2(-.98,1.13),Vector2(-.67,1.17),Vector2(-.38,1.16),Vector2(-.15,1.14)]),.11,m.blade)
  extrude(t,'Worn pick cutting bevel',PackedVector2Array([Vector2(-.98,1.13),Vector2(-.77,1.26),Vector2(-.47,1.36),Vector2(-.58,1.29),Vector2(-.79,1.20)]),.116,m.edge)
  api.box(t,'Square rear hammer',Vector3(.23,1.22,0),Vector3(.28,.20,.18),m.blade)
  api.box(t,'Hammer striking face',Vector3(.38,1.22,0),Vector3(.045,.25,.21),m.edge)
 elif kind=='Woodcutting axe':
  extrude(t,'Broad wedge axe blade',PackedVector2Array([Vector2(-.17,1.35),Vector2(-.70,1.57),Vector2(-.79,1.31),Vector2(-.75,1.02),Vector2(-.60,.85),Vector2(-.37,1.08),Vector2(-.15,1.13)]),.105,m.blade)
  extrude(t,'Axe silver sharpened edge',PackedVector2Array([Vector2(-.70,1.57),Vector2(-.79,1.31),Vector2(-.75,1.02),Vector2(-.60,.85),Vector2(-.64,1.10),Vector2(-.67,1.35)]),.112,m.edge)
  api.box(t,'Axe rear socket',Vector3(.14,1.22,0),Vector3(.18,.18,.17),m.blade)
 else:
  var outer=PackedVector2Array();var inner=PackedVector2Array()
  for i in range(15):
   var a=deg_to_rad(8+i*11.0);outer.append(Vector2(-.44,1.23)+Vector2(cos(a),sin(a))*.58)
  # One shared outer tip, not repeated coincident vertices in the polygon.
  for i in range(13,-1,-1):
   var a=deg_to_rad(8+i*11.0);inner.append(Vector2(-.44,1.23)+Vector2(cos(a),sin(a))*(.42 if i<13 else .52))
  outer.append_array(inner);extrude(t,'Crescent harvest sickle blade',outer,.09,m.blade)
  var edge=PackedVector2Array()
  for i in range(14):
   var a=deg_to_rad(8+i*11.0);edge.append(Vector2(-.44,1.23)+Vector2(cos(a),sin(a))*.42)
  for i in range(13,-1,-1):
   var a=deg_to_rad(8+i*11.0);edge.append(Vector2(-.44,1.23)+Vector2(cos(a),sin(a))*.47)
  extrude(t,'Inner sickle cutting bevel',edge,.096,m.edge)
 # Small pale scratches are authored marks, not copied raster textures.
 for i in range(4):
  var mark=api.box(t,'Blade wear scratch',Vector3(-.25-i*.07,1.27+i*.015,.06),Vector3(.05,.008,.005),m.edge);mark.rotation.z=.3
 t.set_meta('reference','09-gathering-tools-concept-v2');t.set_meta('functional',false)
 return t
