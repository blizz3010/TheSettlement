extends RefCounted
# Detached site candidate only. Caller must separately prove scenery/path clearance.
const Envelope=preload('res://scripts/settlement_envelope.gd')
const Architecture=preload('res://scripts/inn_architecture.gd')
const Structure=preload('res://scripts/inn_structure.gd')
const APPROACH=Rect2(2.6,32,3,11.2)
const DECK_Y=3.4 # Hypothesis; reject support that cannot fit, never level existing terrain.
const RISERS=20
const KNOWN_SHRUBS=[Rect2(-3.254361,40.039413,2.442696,2.575200),Rect2(-.037310,37.914478,2.426530,2.555237),Rect2(-4.738892,40.153835,2.781805,2.718220),Rect2(-9.279057,40.175484,2.139962,2.271457)]
static func sample_points()->Array[Vector2]:
 var points:Array[Vector2]=[]
 # Three samples across every tread boundary; caller binds to actual delivered/new triangles.
 for i in range(RISERS+1):
  var z=APPROACH.position.y+APPROACH.size.y*float(i)/RISERS
  for x in [APPROACH.position.x,APPROACH.get_center().x,APPROACH.end.x]:points.append(Vector2(x,z))
 for z in [Envelope.TERRACE.position.y+.16,Envelope.TERRACE.get_center().y,Envelope.TERRACE.end.y-.16]:
  for x in [-8.7,0.0,8.7]:points.append(Vector2(x,z))
 return points
static func fail(reason:String,root:Node3D=null)->Dictionary:
 if is_instance_valid(root):root.free()
 return {'ok':false,'reason':reason}
static func solid(parent:Node3D,label:String,at:Vector3,size:Vector3,mat:Material):
 var mesh=Architecture.box(parent,label,at,size,mat)
 var body=StaticBody3D.new();body.name=label+'Body';body.transform=mesh.transform
 var col=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=size;col.shape=shape;body.add_child(col);parent.add_child(body)
static func prepare(support:Array)->Dictionary:
 var points=sample_points()
 if support.size()!=points.size():return fail('Exact support sample set required')
 var heights=[]
 for i in range(points.size()):
  var row=support[i]
  if not row is Dictionary or not row.get('position') is Vector3:return fail('Malformed support row')
  var p:Vector3=row.position
  if not p.is_finite() or Vector2(p.x,p.z)!=points[i]:return fail('Support coordinate mismatch')
  # Provenance is retained, not certified here. No analytic fallback for old-world support.
  if str(row.get('source','')).is_empty():return fail('Missing support provenance')
  heights.append(p.y)
 if not Envelope.reservations_clear(APPROACH) or not Envelope.reservations_clear(Envelope.TERRACE):return fail('Reserved plot conflict')
 for shrub in KNOWN_SHRUBS:
  if APPROACH.intersects(shrub,true) or Envelope.TERRACE.intersects(shrub,true):return fail('Known retained shrub conflict')
 var base_y=heights[1]
 if maxf(absf(heights[0]-base_y),absf(heights[2]-base_y))>.03:return fail('Entry cross-slope requires redesign')
 var rise=(DECK_Y-base_y)/RISERS
 if rise<=0 or rise>.18:return fail('Measured riser height outside proposal')
 for i in range(RISERS):
  var top=base_y+(i+1)*rise
  for j in range(3):
   if maxf(heights[i*3+j],heights[(i+1)*3+j])>top-.02:return fail('Existing ground crosses stair solid')
 for i in range((RISERS+1)*3,heights.size()):
  if heights[i]>DECK_Y-.22:return fail('Ground crosses raised terrace')
 var root=Node3D.new();root.name='SettlementInnExpansion'
 var stone=Architecture.material('867f68');var wood=Architecture.material('594936');var bronze=Architecture.material('938064',.58)
 var terrace=Architecture.group(root,'TerraceAndApproach')
 # Terrace top is 2 cm below inn/veranda floor to avoid coplanar surfaces.
 solid(terrace,'TerraceDeck',Vector3(0,DECK_Y-.12,Envelope.TERRACE.get_center().y),Vector3(18,.20,17),stone)
 for i in range(RISERS):
  var top=base_y+(i+1)*rise
  var bottom=minf(minf(heights[i*3],heights[i*3+1]),heights[i*3+2])-.05
  var depth=APPROACH.size.y/RISERS
  var front=APPROACH.position.y+i*depth
  var back=APPROACH.position.y+(i+1)*depth
  # Deliberate 1/64 m construction joint at the existing paving edge only.
  if i==0:front=32.0+1.0/64.0
  if i==0:
   solid(terrace,'ApproachTread0',Vector3(APPROACH.get_center().x,(top+bottom)*.5,(front+back)*.5),Vector3(3,top-bottom,back-front),stone)
  else:
   solid(terrace,'ApproachTread'+str(i),Vector3(APPROACH.get_center().x,(top+bottom)*.5,APPROACH.position.y+(i+.5)*depth),Vector3(3,top-bottom,depth),stone)
  if i==0:
   var entry=terrace.get_node('ApproachTread0')
   var entry_bounds: AABB=entry.transform*entry.mesh.get_aabb()
   var entry_body=terrace.get_node('ApproachTread0Body')
   var entry_shape=entry_body.get_child(0).shape
   var collision_bounds=entry_body.transform*AABB(-entry_shape.size*.5,entry_shape.size)
   var gap=entry_bounds.position.z-32.0
   if gap<=0.0 or gap>.02 or collision_bounds!=entry_bounds:return fail('Actual entry joint bounds invalid',root)
   root.set_meta('paving_joint',{'paving_edge_z':32.0,'intended_gap':1.0/64.0,'actual_gap':gap,'visual_bounds':entry_bounds,'collision_bounds':collision_bounds})
  for x in [2.66,5.54]:
   solid(terrace,'RailPost'+str(i)+'_'+str(x),Vector3(x,top+.5,APPROACH.position.y+(i+.5)*depth),Vector3(.10,1,.10),bronze)
   # Stepped handrail segments remain within the reserved 3 m total footprint.
   solid(terrace,'RailCap'+str(i)+'_'+str(x),Vector3(x,top+1,APPROACH.position.y+(i+.5)*depth),Vector3(.12,.10,depth),wood)
 for i in range((RISERS+1)*3,heights.size()):
  var p=points[i];var bottom=heights[i]-.05;var top=DECK_Y-.22
  solid(terrace,'TerracePier'+str(i),Vector3(p.x,(bottom+top)*.5,p.y),Vector3(.32,top-bottom,.32),stone)
 # Perimeter guards leave only the exact north stair arrival open.
 solid(terrace,'NorthGuardWest',Vector3((-9+2.6)*.5,DECK_Y+.52,43.25),Vector3(11.6,1.04,.10),wood)
 solid(terrace,'NorthGuardEast',Vector3((5.6+9)*.5,DECK_Y+.52,43.25),Vector3(3.4,1.04,.10),wood)
 for x in [-8.95,8.95]:solid(terrace,'SideGuard'+str(x),Vector3(x,DECK_Y+.52,Envelope.TERRACE.get_center().y),Vector3(.10,1.04,17),wood)
 solid(terrace,'RearGuard',Vector3(0,DECK_Y+.52,Envelope.TERRACE.end.y-.05),Vector3(18,1.04,.10),wood)
 var inn=Structure.create()
 if inn==null:return fail('Architecture creation failed',root)
 inn.name='Inn';inn.position=Vector3(Envelope.INN_CENTER.x,DECK_Y,Envelope.INN_CENTER.y);root.add_child(inn)
 preload('res://scripts/inn_guest_finish_v094.gd').apply_approach(root)
 var rail_result=preload('res://scripts/inn_continuous_rails_v096.gd').apply(root,rise,APPROACH.size.y/RISERS)
 if not rail_result.get('ok',false):
  root.free();return rail_result
 root.set_meta('status','Detached unverified site candidate; no live installation or route acceptance')
 root.set_meta('support_samples',support.duplicate(true))
 return {'ok':true,'root':root,'riser_height':rise,'riser_count':RISERS,'total_approach_width':3.0,'between_rail_inner_faces':2.76,'site_clearance_verified':false}
