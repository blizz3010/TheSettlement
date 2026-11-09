extends RefCounted
## Shallow northern-edge stream, no swimming/damage/save systems.
const Terrain=preload('res://scripts/settlement_terrain.gd')
const HALF_LENGTH=42.5
const STEP=.5
static func bank_offset(x:float,side:float)->float:
 var lo=0.0;var hi=8.5;var water=Terrain.stream_water_y(x)
 # Find the first bank crossing. A second low area beyond the bank can be a
 # protected town foundation, so the full search interval is not monotonic.
 var found=false
 for i in range(1,171):
  var d=i*.05
  if Terrain.height_at(x,Terrain.stream_z(x)+side*d)>=water:
   lo=d-.05;hi=d;found=true;break
 if not found:return 0.0 # Clipped endpoint under its outcrop, never flood a reserve.
 for i in range(18):
  var mid=(lo+hi)*.5
  if Terrain.height_at(x,Terrain.stream_z(x)+side*mid)<water:lo=mid
  else:hi=mid
 return (lo+hi)*.5
static func add_to(scene:Node3D)->Node3D:
 if scene.has_node('NorthernStream'):return scene.get_node('NorthernStream')
 assert(scene.has_node('SettlementTerrain'),'Stream requires the matching carved terrain first')
 var root=Node3D.new();root.name='NorthernStream';scene.add_child(root)
 var rows=[]
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(int(HALF_LENGTH*2/STEP)+1):
  var x=-HALF_LENGTH+i*STEP
  var left=Vector3(x,Terrain.stream_water_y(x),Terrain.stream_z(x)-bank_offset(x,-1))
  var right=Vector3(x,Terrain.stream_water_y(x),Terrain.stream_z(x)+bank_offset(x,1))
  rows.append([left,right])
 for i in range(rows.size()-1):
  for p in [rows[i][0],rows[i+1][0],rows[i][1],rows[i+1][0],rows[i+1][1],rows[i][1]]:
   st.set_normal(Vector3.UP);st.set_uv(Vector2(p.x,p.z));st.add_vertex(p)
 var water=MeshInstance3D.new();water.name='ShallowFlow';water.mesh=st.commit()
 var mat=ShaderMaterial.new();mat.shader=preload('res://assets/materials/settlement_stream.gdshader');water.material_override=mat
 water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(water)
 root.set_meta('water_triangle_count',(rows.size()-1)*2)
 root.set_meta('depth_metres',.20)
 root.set_meta('endpoint_description','Both channel ends screened under natural outcrops beyond the playable dome perimeter; not an authored river map beyond the settlement')
 # Low clustered outcrops obscure clipped channel ends outside the playable dome.
 # No new obstacle colliders inside the playable area and no fake inaccessible bridge.
 var rockmat=StandardMaterial3D.new();rockmat.albedo_color=Color(.29,.32,.26);rockmat.roughness=1.0
 for side in [-1,1]:
  var at=Vector3(side*42.0,1.0,Terrain.stream_z(side*42.0))
  for j in range(5):
   var rock=MeshInstance3D.new();rock.name='Outer spring outcrop'
   var mesh=SphereMesh.new();mesh.radius=1;mesh.height=2;mesh.radial_segments=10;mesh.rings=5
   rock.mesh=mesh;rock.material_override=rockmat
   rock.position=at+Vector3((j-2)*.65,.3 if j==2 else -.15,sin(j*2.4)*1.3)
   rock.scale=Vector3(1.3+(j%2)*.4,1.2+(j%3)*.3,1.6+(j%2)*.2)
   rock.rotation=Vector3(.17*j,.71*j,-.11*j)
   root.add_child(rock)
 add_bank_pebbles(root)
 root.set_meta('collision_shapes',0)
 return root

static func add_bank_pebbles(root:Node3D):
 # Reuse only the original Grey_rock surface, not the trader's wooden tray.
 var source=load('res://assets/trader_display/stone_ore_tray.glb').instantiate()
 var nodes=source.find_children('*','MeshInstance3D',true,false)
 assert(nodes.size()==1 and nodes[0].mesh.get_surface_count()==3)
 var original:Mesh=nodes[0].mesh
 var stone=ArrayMesh.new();stone.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,original.surface_get_arrays(2))
 var material=original.surface_get_material(2).duplicate();assert(material.resource_name.begins_with('Grey_rock'))
 # Damp neutral stones: don't turn reused light trader ore into bright white shore markers.
 material.albedo_color=Color(.27,.29,.25);material.roughness=.95
 var base=stone.get_aabb().position.y
 var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=stone;mm.instance_count=28
 var rng=RandomNumberGenerator.new();rng.seed=520147
 var anchors=[]
 for i in range(28):
  var x=rng.randf_range(-31,31);var side=-1.0 if i%2 else 1.0
  var z=Terrain.stream_z(x)+side*(bank_offset(x,side)+rng.randf_range(.22,.95))
  var scale=rng.randf_range(.55,.95)
  var p=Vector3(x,Terrain.height_at(x,z)-base*scale-.025,z)
  var transform=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale),p)
  mm.set_instance_transform(i,transform);anchors.append(p)
 var batch=MultiMeshInstance3D.new();batch.name='Grounded bank pebbles';batch.multimesh=mm;batch.material_override=material
 batch.visibility_range_end=42;batch.visibility_range_end_margin=7;root.add_child(batch)
 root.set_meta('pebble_anchors',anchors);root.set_meta('pebble_triangles',stone.get_faces().size()/3*28)
 source.free()

# Optional budgeted coroutine path; synchronous construction above is unchanged.
static func add_to_staged(scene:Node3D)->Node3D:
 if scene.has_node('NorthernStream'):return scene.get_node('NorthernStream')
 assert(scene.has_node('SettlementTerrain'),'Stream requires the matching carved terrain first')
 var root=Node3D.new();root.name='NorthernStream';scene.add_child(root)
 var rows=[]
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(int(HALF_LENGTH*2/STEP)+1):
  if await scene._startup_checkpoint("stream bank row %d"%i):return null
  var x=-HALF_LENGTH+i*STEP
  var left=Vector3(x,Terrain.stream_water_y(x),Terrain.stream_z(x)-bank_offset(x,-1))
  var right=Vector3(x,Terrain.stream_water_y(x),Terrain.stream_z(x)+bank_offset(x,1))
  rows.append([left,right])
 for i in range(rows.size()-1):
  if i%16==0 and await scene._startup_checkpoint("stream surface row %d"%i):return null
  for p in [rows[i][0],rows[i+1][0],rows[i][1],rows[i+1][0],rows[i+1][1],rows[i][1]]:
   st.set_normal(Vector3.UP);st.set_uv(Vector2(p.x,p.z));st.add_vertex(p)
 if await scene._startup_checkpoint("stream surface commit"):return null
 var water=MeshInstance3D.new();water.name='ShallowFlow';water.mesh=st.commit()
 if await scene._startup_checkpoint("stream surface committed"):return null
 var mat=ShaderMaterial.new();mat.shader=preload('res://assets/materials/settlement_stream.gdshader');water.material_override=mat
 water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(water)
 root.set_meta('water_triangle_count',(rows.size()-1)*2)
 root.set_meta('depth_metres',.20)
 root.set_meta('endpoint_description','Both channel ends screened under natural outcrops beyond the playable dome perimeter; not an authored river map beyond the settlement')
 # Low clustered outcrops obscure clipped channel ends outside the playable dome.
 # No new obstacle colliders inside the playable area and no fake inaccessible bridge.
 var rockmat=StandardMaterial3D.new();rockmat.albedo_color=Color(.29,.32,.26);rockmat.roughness=1.0
 for side in [-1,1]:
  var at=Vector3(side*42.0,1.0,Terrain.stream_z(side*42.0))
  for j in range(5):
   if await scene._startup_checkpoint("stream outcrop %d/%d"%[side,j]):return null
   var rock=MeshInstance3D.new();rock.name='Outer spring outcrop'
   var mesh=SphereMesh.new();mesh.radius=1;mesh.height=2;mesh.radial_segments=10;mesh.rings=5
   rock.mesh=mesh;rock.material_override=rockmat
   rock.position=at+Vector3((j-2)*.65,.3 if j==2 else -.15,sin(j*2.4)*1.3)
   rock.scale=Vector3(1.3+(j%2)*.4,1.2+(j%3)*.3,1.6+(j%2)*.2)
   rock.rotation=Vector3(.17*j,.71*j,-.11*j)
   root.add_child(rock)
 await add_bank_pebbles_staged(root,scene)
 if scene.startup_cancel_requested:return null
 root.set_meta('collision_shapes',0)
 return root


static func add_bank_pebbles_staged(root:Node3D,scene:Node3D):
 # Reuse only the original Grey_rock surface, not the trader's wooden tray.
 var source=load('res://assets/trader_display/stone_ore_tray.glb').instantiate()
 var nodes=source.find_children('*','MeshInstance3D',true,false)
 assert(nodes.size()==1 and nodes[0].mesh.get_surface_count()==3)
 var original:Mesh=nodes[0].mesh
 var stone=ArrayMesh.new();stone.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,original.surface_get_arrays(2))
 var material=original.surface_get_material(2).duplicate();assert(material.resource_name.begins_with('Grey_rock'))
 # Damp neutral stones: don't turn reused light trader ore into bright white shore markers.
 material.albedo_color=Color(.27,.29,.25);material.roughness=.95
 var base=stone.get_aabb().position.y
 var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=stone;mm.instance_count=28
 var rng=RandomNumberGenerator.new();rng.seed=520147
 var anchors=[]
 for i in range(28):
  if await scene._startup_checkpoint("stream pebble %d"%i):
   source.free()
   return
  var x=rng.randf_range(-31,31);var side=-1.0 if i%2 else 1.0
  var z=Terrain.stream_z(x)+side*(bank_offset(x,side)+rng.randf_range(.22,.95))
  var scale=rng.randf_range(.55,.95)
  var p=Vector3(x,Terrain.height_at(x,z)-base*scale-.025,z)
  var transform=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale),p)
  mm.set_instance_transform(i,transform);anchors.append(p)
 var batch=MultiMeshInstance3D.new();batch.name='Grounded bank pebbles';batch.multimesh=mm;batch.material_override=material
 batch.visibility_range_end=42;batch.visibility_range_end_margin=7;root.add_child(batch)
 root.set_meta('pebble_anchors',anchors);root.set_meta('pebble_triangles',stone.get_faces().size()/3*28)
 source.free()
