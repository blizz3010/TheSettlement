extends RefCounted
const Envelope=preload("res://scripts/settlement_envelope.gd")
const OuterTerrain=preload("res://scripts/settlement_outer_terrain.gd")
## Fresh-start transaction only: never replaces a live existing dome.
const RADIUS=Envelope.HORIZONTAL_RADIUS-Envelope.COLLISION_INSET
const SEGMENTS=128
static func legacy_shapes(scene:Node3D)->Array:
 if not is_instance_valid(scene) or scene.is_queued_for_deletion() or not scene.is_inside_tree() or scene.global_transform!=Transform3D.IDENTITY:return []
 if scene.has_node('DomeBoundary') or scene.has_node('SettlementOuterTerrain'):return []
 var journal=[]
 for center in [Vector3(-45.5,3,0),Vector3(45.5,3,0),Vector3(0,3,-45.5),Vector3(0,3,45.5)]:
  var expected=Vector3(1,6,92) if center.x!=0 else Vector3(92,6,1)
  var matches=[]
  for body in scene.get_children():
   if not body is StaticBody3D or body.is_queued_for_deletion() or body.transform!=Transform3D(Basis.IDENTITY,center) or body.get_child_count()!=1:continue
   var col=body.get_child(0)
   if not col is CollisionShape3D or col.is_queued_for_deletion() or col.transform!=Transform3D.IDENTITY or col.disabled:continue
   if not col.shape is BoxShape3D or col.shape.size!=expected:continue
   matches.append(col)
  if matches.size()!=1:return []
  journal.append(matches[0])
 return journal
static func prepare_boundary()->Node3D:
 var root=Node3D.new();root.name='DomeBoundary'
 var faces=PackedVector3Array()
 # A single double-sided static trimesh follows the same ellipsoidal dome
 # curve at each height, rather than becoming a separate vertical cylinder.
 var levels=[-.5,0.0,2.0,4.0,6.0,8.0,10.0,12.0]
 for i in range(SEGMENTS):
  var a=TAU*i/SEGMENTS;var b=TAU*(i+1)/SEGMENTS
  for j in range(levels.size()-1):
   var low:float=levels[j];var high:float=levels[j+1]
   var rl=radius_at(low);var rh=radius_at(high)
   var p=Vector3(cos(a)*rl,low,sin(a)*rl)
   var q=Vector3(cos(b)*rl,low,sin(b)*rl)
   var u=Vector3(cos(a)*rh,high,sin(a)*rh)
   var v=Vector3(cos(b)*rh,high,sin(b)*rh)
   faces.append_array(PackedVector3Array([p,u,q,q,u,v]))
 var body=StaticBody3D.new();body.name='EllipsoidalPerimeter';body.set_meta('audio_surface','metal');root.add_child(body)
 var col=CollisionShape3D.new();var shape=ConcavePolygonShape3D.new();shape.set_faces(faces);shape.backface_collision=true;col.shape=shape;body.add_child(col)
 root.set_meta('visible_radius',Envelope.HORIZONTAL_RADIUS)
 root.set_meta('collision_radius',RADIUS)
 root.set_meta('vertical_levels',levels.duplicate())
 return root

static func add_to(scene:Node3D)->Node3D:
 var before=legacy_shapes(scene)
 if before.size()!=4:return null
 # Prepare both additions without touching existing walls or terrain.
 var boundary=prepare_boundary()
 if boundary==null:return null
 var terrain=OuterTerrain.prepare()
 if terrain==null:boundary.free();return null
 # No await between revalidation and publication. Refuse stale/foreign state.
 var current=legacy_shapes(scene)
 if current!=before:
  boundary.free();terrain.free();return null
 var journal=[]
 for col in before:
  journal.append({'path':str(col.get_path()),'center':col.get_parent().position,'size':col.shape.size,'was_disabled':col.disabled})
 scene.add_child(terrain)
 scene.add_child(boundary)
 for col in before:col.disabled=true
 boundary.set_meta('replacement_journal',journal)
 boundary.set_meta('installation_scope','Fresh-start outer ground and boundary, not live replacement')
 return boundary

static func radius_at(y:float)->float:
 return Envelope.radius_at(y)
