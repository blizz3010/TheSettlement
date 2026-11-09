extends RefCounted
## Detached additive ring; no original terrain or flora reconciliation calls.
const Terrain=preload('res://scripts/settlement_terrain.gd')
const Envelope=preload('res://scripts/settlement_envelope.gd')
static func cells()->Array[Vector2i]:
 var result:Array[Vector2i]=[]
 for z in range(-Envelope.TERRAIN_EXTENT,Envelope.TERRAIN_EXTENT):
  for x in range(-Envelope.TERRAIN_EXTENT,Envelope.TERRAIN_EXTENT):
   if x>=-Terrain.EXTENT and x<Terrain.EXTENT and z>=-Terrain.EXTENT and z<Terrain.EXTENT:continue
   # Keep complete cells intersecting the radius, including the boundary skirt.
   var nearest=Vector2(clampf(0,x,x+1),clampf(0,z,z+1))
   if nearest.length()<=Envelope.HORIZONTAL_RADIUS+1:result.append(Vector2i(x,z))
 return result
static func lattice_height(p:Vector2)->float:
 # Same a,b,c / b,d,c triangle interpolation, not analytic height between vertices.
 var x=floori(p.x);var z=floori(p.y);var u=p.x-x;var v=p.y-z
 var a=Terrain.height_at(x,z);var b=Terrain.height_at(x+1,z)
 var c=Terrain.height_at(x,z+1);var d=Terrain.height_at(x+1,z+1)
 return a+(b-a)*u+(c-a)*v if u+v<=1 else d+(c-d)*(1-u)+(b-d)*(1-v)
static func prepare()->Node3D:
 var root=Node3D.new();root.name='SettlementOuterTerrain'
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var faces=PackedVector3Array();var selected=cells()
 for cell in selected:
  var x=cell.x;var z=cell.y
  var a=Vector3(x,Terrain.height_at(x,z),z);var b=Vector3(x+1,Terrain.height_at(x+1,z),z)
  var c=Vector3(x,Terrain.height_at(x,z+1),z+1);var d=Vector3(x+1,Terrain.height_at(x+1,z+1),z+1)
  # Unlike the old relief overlay, the outer ring always supplies physical ground.
  for p in [a,b,c,b,d,c]:
   if not p.is_finite():root.free();return null
   st.set_normal(Terrain.normal_at(p.x,p.z));st.set_uv(Vector2(p.x,p.z)*.2)
   # Match original terrain vertex colors at shared lattice endpoints, including the stream bank.
   var color=Color(.225,.295,.185)*(.94+.045*sin(p.x*.23+p.z*.11))
   if absf(p.x)<43 and absf(p.z-Terrain.stream_z(p.x))<8.5:
    var wet=1.0-smoothstep(Terrain.stream_water_y(p.x)+.08,Terrain.stream_water_y(p.x)+.42,p.y)
    color=color.lerp(Color(.25,.23,.17),wet)
   st.set_color(color)
   st.add_vertex(p);faces.append(p)
 var mesh=st.commit()
 if mesh==null or faces.is_empty():root.free();return null
 var surface=MeshInstance3D.new();surface.name='GroundRelief';surface.mesh=mesh
 var mat=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=1
 surface.material_override=mat;surface.set_meta('terrain_turf',true);root.add_child(surface)
 var body=StaticBody3D.new();body.name='WalkableOuterGround';body.set_meta('audio_surface','grass');root.add_child(body)
 var col=CollisionShape3D.new();var shape=ConcavePolygonShape3D.new();shape.set_faces(faces);col.shape=shape;body.add_child(col)
 root.set_meta('cell_count',selected.size());root.set_meta('triangle_count',faces.size()/3)
 return root
