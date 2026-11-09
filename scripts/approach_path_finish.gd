extends RefCounted
# Bounded v050 approach repair: retain all existing bodies/transforms/state.
static func apply(scene:Node3D)->Node3D:
 assert(not scene.has_node('ApproachPathFinish'))
 var root=Node3D.new();root.name='ApproachPathFinish';scene.add_child(root)
 var approach=scene.get_node('LaunchpadApproach')
 var api=preload('res://scripts/market_expansion.gd')
 var stone=scene.courtyard_material('paving',Color(.46,.44,.38,1))
 var polygons=[];var ends=[];var journal=[]
 for i in range(3):
  var body=approach.get_node('StoneConnector%d'%i)
  var mesh=body.get_child(1) as MeshInstance3D
  assert(mesh!=null and mesh.mesh is BoxMesh)
  mesh.material_override=stone
  var polygon=api.paving_footprint(mesh.mesh,mesh.global_transform)
  polygons.append(polygon)
  var width:float=mesh.mesh.size.x;var length:float=mesh.mesh.size.z
  var caps=[]
  for z in [-length/2,length/2]:
   var cap=PackedVector2Array()
   for x in [-width/2,width/2]:
    var p=mesh.to_global(Vector3(x,0,z));cap.append(Vector2(p.x,p.z))
   caps.append(cap)
  ends.append(caps)
  journal.append({'node':str(body.get_path()),'change':'existing courtyard paving material only','footprint':polygon})
 # Basis.looking_at puts destination at local -Z: preceding destination cap
 # and following origin cap enclose only the missing outside corner wedges.
 for i in range(2):
  var points=PackedVector2Array();points.append_array(ends[i][0]);points.append_array(ends[i+1][1])
  var gaps=[Geometry2D.convex_hull(points)]
  for existing in [polygons[i],polygons[i+1]]:
   var remainder=[]
   for gap in gaps:remainder.append_array(Geometry2D.clip_polygons(gap,existing))
   gaps=remainder
  for gap in gaps:
   if gap.size()<3:continue
   var indices=Geometry2D.triangulate_polygon(gap)
   if indices.is_empty():continue
   var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
   for j in range(0,indices.size(),3):
    # Godot front faces use clockwise winding; explicit normal remains UP.
    for k in [0,1,2]:
     var p=gap[indices[j+k]];st.set_normal(Vector3.UP);st.add_vertex(Vector3(p.x,.025,p.y))
   var mesh=MeshInstance3D.new();mesh.name='CornerFill%d'%i;mesh.mesh=st.commit();mesh.material_override=stone;root.add_child(mesh)
   polygons.append(gap)
   journal.append({'node':str(mesh.get_path()),'change':'bounded missing corner top, no collider','footprint':gap})
 var market=scene.get_node('MarketExpansion');var all:Array=market.get_meta('paving_polygons').duplicate();all.append_array(polygons)
 for body in scene.find_children('*','StaticBody3D',true,false):
  if body.has_meta('audio_ground_regions'):body.set_meta('market_paving_polygons',all)
 root.set_meta('footprints',polygons);root.set_meta('journal',journal)
 var finish=preload('res://scripts/ship_approach_finish_v100.gd').apply(scene,root,stone)
 root.set_meta('ship_approach_finish_v100',finish)
 return root
