extends RefCounted
static func add_box(root:Node3D,label:String,center:Vector3,size:Vector3):
 var b=StaticBody3D.new();b.name=label;b.position=center;root.add_child(b)
 var c=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size;c.shape=box;b.add_child(c);return b
static func add_to(scene:Node3D,holder:Node3D):
 var boxes=[{"name": "Upper library north floor", "center": [-5.8, 3.52, -26.5], "size": [5.2, 0.24, 9.4]}, {"name": "Upper east circulation", "center": [-3.9, 3.52, -19.2], "size": [1.4, 0.24, 5.2]}, {"name": "Upper stair arrival", "center": [-5.8, 3.52, -15.8], "size": [5.2, 0.24, 1.6]}, {"name": "Gallery stair lower00", "center": [-7.375, 0.325, -16.865], "size": [1.65, 0.17000000000000004, 0.33]}, {"name": "Gallery stair upper00", "center": [-5.525, 2.025, -19.835], "size": [1.65, 0.16999999999999993, 0.33]}, {"name": "Gallery stair lower01", "center": [-7.375, 0.41000000000000003, -17.195], "size": [1.65, 0.3400000000000001, 0.33]}, {"name": "Gallery stair upper01", "center": [-5.525, 2.11, -19.505], "size": [1.65, 0.33999999999999986, 0.33]}, {"name": "Gallery stair lower02", "center": [-7.375, 0.495, -17.525], "size": [1.65, 0.51, 0.33]}, {"name": "Gallery stair upper02", "center": [-5.525, 2.1950000000000003, -19.175], "size": [1.65, 0.5100000000000002, 0.33]}, {"name": "Gallery stair lower03", "center": [-7.375, 0.5800000000000001, -17.855], "size": [1.65, 0.68, 0.33]}, {"name": "Gallery stair upper03", "center": [-5.525, 2.2800000000000002, -18.845], "size": [1.65, 0.6800000000000002, 0.33]}, {"name": "Gallery stair lower04", "center": [-7.375, 0.665, -18.185], "size": [1.65, 0.8500000000000001, 0.33]}, {"name": "Gallery stair upper04", "center": [-5.525, 2.365, -18.515], "size": [1.65, 0.8500000000000001, 0.33]}, {"name": "Gallery stair lower05", "center": [-7.375, 0.75, -18.515], "size": [1.65, 1.02, 0.33]}, {"name": "Gallery stair upper05", "center": [-5.525, 2.45, -18.185], "size": [1.65, 1.02, 0.33]}, {"name": "Gallery stair lower06", "center": [-7.375, 0.8350000000000001, -18.845], "size": [1.65, 1.1900000000000002, 0.33]}, {"name": "Gallery stair upper06", "center": [-5.525, 2.535, -17.855], "size": [1.65, 1.19, 0.33]}, {"name": "Gallery stair lower07", "center": [-7.375, 0.92, -19.175], "size": [1.65, 1.36, 0.33]}, {"name": "Gallery stair upper07", "center": [-5.525, 2.62, -17.525], "size": [1.65, 1.3599999999999999, 0.33]}, {"name": "Gallery stair lower08", "center": [-7.375, 1.005, -19.505], "size": [1.65, 1.53, 0.33]}, {"name": "Gallery stair upper08", "center": [-5.525, 2.705, -17.195], "size": [1.65, 1.5299999999999998, 0.33]}, {"name": "Gallery stair lower09", "center": [-7.375, 1.09, -19.835], "size": [1.65, 1.7000000000000002, 0.33]}, {"name": "Gallery stair upper09", "center": [-5.525, 2.79, -16.865], "size": [1.65, 1.7000000000000002, 0.33]}, {"name": "Gallery turning landing", "center": [-6.45, 1.82, -20.8], "size": [3.5, 0.24, 1.6]}, {"name": "Gallery guard collider", "center": [-3.25, 4.19, -23], "size": [0.08, 1.1, 15.6]}, {"name": "Stairwell north guard", "center": [-6.45, 4.19, -21.8], "size": [3.5, 1.1, 0.08]}, {"name": "Upper stairwell east guard", "center": [-4.65, 4.19, -19.25], "size": [0.08, 1.1, 5.1]}, {"name": "Gallery front guard", "center": [-5.8, 4.19, -15.05], "size": [5.2, 1.1, 0.08]}]
 for item in boxes:
  var a=item.center;var z=item.size
  # Shared stair: preserve every tread top; both flights use the proven .17 m profile.
  if item.name.begins_with("Gallery stair upper") or item.name.begins_with("Gallery stair lower"):
   a=a.duplicate();z=z.duplicate();a[1]=a[1]+z[1]*.5-.085;z[1]=.17
  var body=add_box(holder,item.name,Vector3(a[0],a[1],a[2]),Vector3(z[0],z[1],z[2]));body.set_meta("audio_surface","wood")
 # Honest slim underside: two timber edge stringers, exact mesh-matching convexes.
 for x in [-6.27,-4.78]:
  var b=StaticBody3D.new();b.name="Upper flight stringer west" if x < -5 else "Upper flight stringer east";b.set_meta("audio_surface","wood");holder.add_child(b)
  var pts=PackedVector3Array()
  for end in [[-20.0,1.94],[-16.7,3.64],[-16.7,3.44],[-20+.20*3.3/1.7,1.94]]:
   for offset in [-.06,.06]:pts.append(Vector3(x+offset,end[1],end[0]))
  var shape=ConvexPolygonShape3D.new();shape.points=pts
  var col=CollisionShape3D.new();col.shape=shape;b.add_child(col)
 # Lower flight now uses the same honest narrow supports as the upper flight.
 for x in [-8.12,-6.63]:
  var b=StaticBody3D.new();b.name="Lower flight stringer west" if x < -7 else "Lower flight stringer east";b.set_meta("audio_surface","wood");holder.add_child(b)
  var pts=PackedVector3Array()
  for end in [[-16.7,.24],[-20.0,1.94],[-20.0,1.74],[-16.7-.20*3.3/1.7,.24]]:
   for offset in [-.06,.06]:pts.append(Vector3(x+offset,end[1],end[0]))
  var shape=ConvexPolygonShape3D.new();shape.points=pts
  var col=CollisionShape3D.new();col.shape=shape;b.add_child(col)
 # Continuous sloping rail barriers; narrow visual posts are not sufficient collision.
 for r in [[-8.15,-16.7,-20,.24,1.94],[-6.5,-16.7,-20,.24,1.94],[-6.35,-20,-16.7,1.94,3.64],[-4.75,-20,-16.7,1.94,3.64]]:
  var b=StaticBody3D.new();b.name="Gallery stair guard";holder.add_child(b)
  var pts=PackedVector3Array()
  for end in [0,1]:
   var z=r[1+end];var y=r[3+end]
   for x in [r[0]-.04,r[0]+.04]:
    pts.append(Vector3(x,y,z));pts.append(Vector3(x,y+1.1,z))
  var shape=ConvexPolygonShape3D.new();shape.points=pts
  var col=CollisionShape3D.new();col.shape=shape;b.add_child(col)
 # Turning-landing outer guard; central flight divider ends before turn area.
 add_box(holder,"Landing north guard",Vector3(-6.45,2.49,-21.55),Vector3(3.5,1.1,.08))
 add_box(holder,"Landing west guard",Vector3(-8.15,2.49,-20.8),Vector3(.08,1.1,1.6))
 # Four connected paths around current hall; no plot or pad relocation.
 var paths=Node3D.new();paths.name="HallSurroundPaths";scene.add_child(paths)
 var mat=StandardMaterial3D.new();mat.albedo_color=Color(.39,.35,.27);mat.roughness=1
 for spec in [[-11.5,-21.6,2.8,21.5],[11.5,-21.6,2.8,21.5],[0,-33.35,25.8,2],[0,-11.4,25.8,2.8]]:
  var center=Vector3(spec[0],.015,spec[1]);var size=Vector3(spec[2],.13,spec[3])
  var body=add_box(paths,"Stone path",center,size);body.set_meta("audio_surface","stone")
  var mesh=MeshInstance3D.new();var cube=BoxMesh.new();cube.size=size;mesh.mesh=cube;mesh.material_override=mat;body.add_child(mesh)
 scene.set_meta("hall_gallery",{"floor":3.64,"stair_risers":20,"rise":.17,"run":.33,"clear_flight_width":1.57,"min_upper_headroom":2.56})
