extends RefCounted
# S01 wearing surfaces only. Shapes, source polygons and grass authority unchanged.
const Paving=preload('res://scripts/paving_edges.gd')
const JOINT=Paving.PLAZA_JOINT
const TILE_TOP=.031
const BASE_TOP=.027
const RAMP_SKIN=.004
static func fail(reason:String)->Dictionary:return {'ok':false,'reason':reason}
static func merge_union(polys:Array)->Array:
 var out=[]
 for source in polys:
  var current:PackedVector2Array=source;var i=0
  while i<out.size():
   var merged=Geometry2D.merge_polygons(current,out[i])
   if merged.size()==1:
    current=merged[0];out.remove_at(i);i=0
   else:i+=1
  out.append(current)
 return out
static func flat(parent:Node3D,label:String,polys:Array,y:float,material:Material)->MeshInstance3D:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for poly in polys:
  var indices=Geometry2D.triangulate_polygon(poly)
  for index in indices:
   var p=poly[index];st.set_normal(Vector3.UP);st.set_uv(p);st.add_vertex(Vector3(p.x,y,p.y))
 var n=MeshInstance3D.new();n.name=label;n.mesh=st.commit();n.material_override=material;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(n);return n
static func ramp_y(z:float)->float:return .025+maxf(13.8-z,0.0)*(1.255/6.4)
static func ramp_strip(parent:Node3D,label:String,x:float,start:float,end:float,material:Material)->MeshInstance3D:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var cuts=[start]
 if start<13.8 and end>13.8:cuts.append(13.8)
 cuts.append(end)
 for i in range(cuts.size()-1):
  var a=Vector3(-x,ramp_y(cuts[i])+RAMP_SKIN,cuts[i]);var b=Vector3(x,a.y,a.z)
  var c=Vector3(-x,ramp_y(cuts[i+1])+RAMP_SKIN,cuts[i+1]);var d=Vector3(x,c.y,c.z)
  var normal=(c-a).cross(b-a).normalized()
  for p in [a,b,c,b,d,c]:st.set_normal(normal);st.set_uv(Vector2(p.x,p.z));st.add_vertex(p)
 var n=MeshInstance3D.new();n.name=label;n.mesh=st.commit();n.material_override=material;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(n);return n
static func apply(world:Node3D,approach:Node3D,stone:Material)->Dictionary:
 if approach.has_node('ShipApproachFinishV100'):return approach.get_meta('ship_approach_finish_v100',fail('Missing finish receipt'))
 var ship=world.get_node_or_null('LaunchpadShip')
 if ship==null or not world.global_transform.is_equal_approx(Transform3D.IDENTITY) or not ship.position.is_equal_approx(Vector3(22,0,-16)) or not ship.basis.is_equal_approx(Basis.IDENTITY):return fail('Expected ship/world transform')
 var stub=ship.get_node_or_null('Collision/ApproachStub');var ramp=ship.get_node_or_null('Collision/Accessible solid ramp')
 if not stub is StaticBody3D or not ramp is StaticBody3D or stub.get_child_count()==0 or ramp.get_child_count()==0 or not stub.get_child(0) is CollisionShape3D or not ramp.get_child(0) is CollisionShape3D:return fail('Expected supported approach and ramp')
 if not stub.position.is_equal_approx(Vector3(0,-.015,16.3)) or not stub.get_child(0).shape is BoxShape3D or not stub.get_child(0).shape.size.is_equal_approx(Vector3(3.2,.08,5)):return fail('Stub geometry changed')
 if not ramp.transform.is_equal_approx(Transform3D.IDENTITY) or not ramp.get_child(0).transform.is_equal_approx(Transform3D.IDENTITY) or not stub.basis.is_equal_approx(Basis.IDENTITY) or not stub.get_child(0).transform.is_equal_approx(Transform3D.IDENTITY):return fail('Support transforms changed')
 var connector_root=world.get_node_or_null('LaunchpadApproach')
 if connector_root==null:return fail('Connector support missing')
 for i in range(3):
  var body=connector_root.get_node_or_null('StoneConnector%d'%i)
  if not body is StaticBody3D or body.get_child_count()<2 or not body.get_child(0) is CollisionShape3D or not body.get_child(0).shape is BoxShape3D:return fail('Connector boxes changed')
  var col=body.get_child(0);var half=col.shape.size*.5
  for x in [-half.x,half.x]:
   for z in [-half.z,half.z]:
    if not is_equal_approx((col.global_transform*Vector3(x,half.y,z)).y,.025):return fail('Connector walking level changed')
 var shape=ramp.get_child(0).shape
 if not shape is ConvexPolygonShape3D or shape.points.size()!=8:return fail('Ramp support changed')
 for p in shape.points:
  if not is_equal_approx(absf(p.x),1.6) or not (is_equal_approx(p.z,7.4) or is_equal_approx(p.z,13.8)) or not (is_zero_approx(p.y) or is_equal_approx(p.y,ramp_y(p.z))):return fail('Ramp vertices changed')
 var source:Array=approach.get_meta('footprints',[]).duplicate()
 if source.size()<3:return fail('Original completed connector footprints required')
 # Stop stone at the deliberately bent threshold's outside edge (13.90 local).
 source.append(PackedVector2Array([Vector2(20.4,-2.1),Vector2(23.6,-2.1),Vector2(23.6,2.8),Vector2(20.4,2.8)]))
 var united=merge_union(source)
 if united.size()!=1:return fail('Connector and stub must form one supported visual union')
 var root=Node3D.new();root.name='ShipApproachFinishV100'
 var mortar=StandardMaterial3D.new();mortar.albedo_color=Color('#514f45');mortar.roughness=1
 flat(root,'Recessed stone joints',united,BASE_TOP,mortar)
 var bounds=Rect2(united[0][0],Vector2.ZERO)
 for p in united[0]:bounds=bounds.expand(p)
 var tiles=[]
 # Same one-metre world grid and 12mm joints as SupportedPlazaTiles.
 for x in range(floori(bounds.position.x)-1,ceili(bounds.end.x)+1):
  for z in range(floori(bounds.position.y)-1,ceili(bounds.end.y)+1):
   var half=(1.0-JOINT)*.5;var cell=PackedVector2Array([Vector2(x-half,z-half),Vector2(x+half,z-half),Vector2(x+half,z+half),Vector2(x-half,z+half)])
   tiles.append_array(Geometry2D.intersect_polygons(cell,united[0]))
 flat(root,'Matching clipped stone courses',tiles,TILE_TOP,stone)
 var ramp_root=Node3D.new();ramp_root.name='RampWearingSurface';ramp_root.position=ship.position;root.add_child(ramp_root)
 var non_slip=ShaderMaterial.new();non_slip.shader=preload('res://shaders/ship_ramp_surface_v100.gdshader')
 ramp_strip(ramp_root,'Recessed non-slip ramp',1.48,7.5,13.7,non_slip)
 var edge=StandardMaterial3D.new();edge.albedo_color=Color('#756d52');edge.metallic=.45;edge.roughness=.8
 ramp_strip(ramp_root,'Bent landing threshold',1.50,13.7,13.9,edge)
 # The existing stone border remains visible inside the original rail envelope.
 approach.add_child(root)
 ramp.set_meta('pre_approach_surface_v100',ramp.get_meta('audio_surface','stone'));ramp.set_meta('audio_surface','metal')
 var result={'ok':true,'new_colliders':0,'new_lights':0,'source_footprints_changed':false,'stone_module_m':1.0,'joint_m':JOINT,'stone_skin_max_m':.006,'ramp_skin_m':RAMP_SKIN,'tile_fragments':tiles.size(),'draw_surfaces':4,'ramp_audio_surface':'metal','threshold':'13.70 to 13.90 pad-local, bent at original ramp foot'}
 root.set_meta('source_union',united);root.set_meta('stone_tiles',tiles);approach.set_meta('ship_approach_finish_v100',result);return result
