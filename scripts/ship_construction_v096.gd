extends Node3D
# S01/S02/S03/Q01: bounded source-owned construction finish. No collision,
# navigation, saved-state, global lighting or imported-resource mutation.
const Settings=preload("res://scripts/game_settings.gd")
const Nozzle=preload("res://scripts/ship_nozzle_geometry_v096.gd")
const Home=preload("res://scripts/home_finish_v094.gd")
var quality=2
var core:Node3D
var high:Node3D
var ultra:Node3D
var materials:Dictionary={}
var source_mesh:Mesh
var adapted_mesh:Mesh
var nozzle_evidence:Dictionary={}
var local_glass:StandardMaterial3D
static func failure(pad:Node3D,reason:String)->Dictionary:
 var result={"ok":false,"reason":reason}
 if is_instance_valid(pad):pad.set_meta("ship_construction_v096",result)
 return result
static func runtime_target(pad:Node3D)->MeshInstance3D:
 var art=pad.get_node_or_null("Art")
 if not art is Node3D:return null
 var targets=art.find_children("LaunchpadShip_Runtime","MeshInstance3D",true,false)
 return targets[0] if targets.size()==1 else null
static func readiness(world:Node)->Dictionary:
 var pad=world.get_node_or_null("LaunchpadShip")
 if not pad is Node3D:return {"ok":false,"reason":"Required ship owner is absent."}
 var state=pad.get_meta("ship_construction_v096",{})
 if not state is Dictionary or not state.get("ok",false):return {"ok":false,"reason":str(state.get("reason","Required construction did not finish.")) if state is Dictionary else "Invalid construction state."}
 var owner=pad.get_node_or_null("ShipConstructionV096")
 if not owner is Node3D or owner.get_script()!=load("res://scripts/ship_construction_v096.gd"):return {"ok":false,"reason":"Required construction controller is absent."}
 for key in ["EssentialConstruction","HighServiceDetail","UltraFasteners"]:
  var group=owner.get_node_or_null(key)
  if not group is Node3D or group.is_queued_for_deletion() or group.get_child_count()==0:return {"ok":false,"reason":"Required construction group is absent: "+key}
 if owner.get_meta("ship_construction_v096",{}).get("ok",false)!=true or owner.source_mesh==null or owner.adapted_mesh==null or owner.local_glass==null:return {"ok":false,"reason":"Prepared construction state is unavailable."}
 if owner.core!=owner.get_node("EssentialConstruction") or owner.high!=owner.get_node("HighServiceDetail") or owner.ultra!=owner.get_node("UltraFasteners"):return {"ok":false,"reason":"Construction group binding changed."}
 if owner.is_queued_for_deletion() or not is_instance_valid(owner.core) or not owner.core.visible:return {"ok":false,"reason":"Essential construction is unavailable."}
 var target=runtime_target(pad)
 if target==null or target.mesh!=owner.adapted_mesh or target.material_override!=null or target.material_overlay!=null or target.get_active_material(6)!=owner.local_glass:return {"ok":false,"reason":"Prepared ship mesh/material binding changed."}
 return {"ok":true}
static func apply(pad:Node3D)->Dictionary:
 if pad.has_node("ShipConstructionV096"):return {"ok":false,"reason":"Ship construction already applied."}
 var target=runtime_target(pad)
 if target==null:return failure(pad,"Exact ship Art/runtime mesh absent.")
 if not target.mesh is ArrayMesh or target.mesh.get_surface_count()!=10:return failure(pad,"Exact ship mesh contract absent.")
 # Validate the complete material plan before attaching or publishing anything.
 # Whole-instance overrides/overlays would hide the planned nozzle/glass surfaces.
 if target.material_override!=null or target.material_overlay!=null:return failure(pad,"Unexpected whole-ship material override or overlay.")
 var original_glass=target.get_active_material(6)
 if not original_glass is StandardMaterial3D:return failure(pad,"Cockpit material must be StandardMaterial3D.")
 var glass=original_glass.duplicate() as StandardMaterial3D
 if glass==null:return failure(pad,"Could not prepare a local cockpit material.")
 glass.resource_name="Local petrol cockpit construction V096";glass.albedo_color=Color(.09,.235,.255);glass.metallic=.18;glass.roughness=.24
 # A low, bloom-independent cabin reflection cue, not an emitted scene light.
 glass.emission_enabled=true;glass.emission=Color(.035,.09,.10);glass.emission_energy_multiplier=.30
 var overrides=[]
 for index in target.mesh.get_surface_count():overrides.append(target.get_surface_override_material(index))
 var prepared=Nozzle.prepare(target.mesh)
 if not prepared.get("ok",false):return failure(pad,str(prepared.get("reason","Nozzle preparation failed.")))
 var controller=load("res://scripts/ship_construction_v096.gd").new();controller.name="ShipConstructionV096"
 controller.transform=pad.global_transform.affine_inverse()*target.global_transform;pad.add_child(controller)
 controller.source_mesh=target.mesh;controller.adapted_mesh=prepared.mesh;controller.local_glass=glass
 controller.nozzle_evidence={"counts":prepared.counts,"removed":prepared.removed,"lod_removed":prepared.lod_removed,"source_sha":prepared.source_sha,"removed_triangles":prepared.removed_triangles}
 controller.build(prepared,target)
 if not controller.built_plan_valid():
  controller.free();return failure(pad,"Construction geometry plan did not finish.")
 # Publish only after all source/material checks and replacement geometry pass.
 target.mesh=prepared.mesh
 for index in overrides.size():target.set_surface_override_material(index,overrides[index])
 target.set_surface_override_material(6,glass)
 controller.add_to_group("material_detail_quality")
 controller.set_quality(Settings.new().current_material_detail_quality(controller))
 var result=controller.get_meta("ship_construction_v096");pad.set_meta("ship_construction_v096",result);return result
func built_plan_valid()->bool:
 for row in [[core,1248,5],[high,576,3],[ultra,1344,2]]:
  var group=row[0]
  if not is_instance_valid(group) or group.get_child_count()!=row[2]:return false
  var count=0
  for node in group.get_children():
   if not node is MeshInstance3D or node.mesh==null or node.mesh.get_surface_count()!=1:return false
   count+=node.mesh.get_faces().size()/3
  if count!=row[1]:return false
 return true
func material(key:String,color:Color,metallic:float,roughness:float)->StandardMaterial3D:
 if materials.has(key):return materials[key]
 var m=StandardMaterial3D.new();m.resource_name="Ship "+key+" V096";m.albedo_color=color;m.metallic=metallic;m.roughness=roughness;materials[key]=m;return m
func mesh(parent:Node3D,label:String,geometry:Mesh,at:Vector3,m:Material)->MeshInstance3D:
 var node=MeshInstance3D.new();node.name=label;node.mesh=geometry;node.position=at;node.material_override=m;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node);return node
func box(parent:Node3D,label:String,at:Vector3,size:Vector3,m:Material)->MeshInstance3D:
 var shape=BoxMesh.new();shape.size=size;return mesh(parent,label,shape,at,m)
func beam(parent:Node3D,label:String,a:Vector3,b:Vector3,width:float,height:float,m:Material)->MeshInstance3D:
 var n=box(parent,label,(a+b)*.5,Vector3(width,height,a.distance_to(b)),m)
 var up=Vector3.RIGHT if absf((b-a).normalized().dot(Vector3.UP))>.99 else Vector3.UP
 n.basis=Basis.looking_at(b-a,up);return n
func cylinder(parent:Node3D,label:String,at:Vector3,radius:float,length:float,axis:Vector3,m:Material,sides:int=12)->MeshInstance3D:
 var shape=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=length;shape.radial_segments=sides;shape.rings=1
 var n=mesh(parent,label,shape,at,m)
 n.quaternion=Quaternion(Vector3.UP,axis.normalized());return n
func build(prepared:Dictionary,target:MeshInstance3D):
 core=Node3D.new();core.name="EssentialConstruction";add_child(core)
 high=Node3D.new();high.name="HighServiceDetail";add_child(high)
 ultra=Node3D.new();ultra.name="UltraFasteners";add_child(ultra)
 var graphite=target.mesh.surface_get_material(1);var bronze=target.mesh.surface_get_material(3)
 var cavity=material("dark nozzle interior",Color(.048,.063,.066),.24,.84)
 var alloy=material("brushed alloy",Color(.34,.37,.36),.72,.36)
 var gasket=material("petrol gasket",Color(.075,.11,.115),.12,.82)
 var status=material("quiet amber status",Color(.37,.29,.14),.1,.55)
 status.emission_enabled=true;status.emission=Color(.38,.25,.09);status.emission_energy_multiplier=.65
 # Low owns the complete parked engine identity: open concentric lips, bounded
 # tapered interior and a closed dark back wall. No firing material or effect.
 for engine in 2:
  var center:Vector3=Nozzle.CENTERS[engine]
  for kind in ["outer_front","bronze_front","bronze_back"]:
   var ring_center=Vector3(prepared.caps[str(engine)+"/"+kind][0].x,center.y,center.z)
   mesh(core,"Engine%d_%s"%[engine,kind],Nozzle.ring(prepared.caps[str(engine)+"/"+kind],ring_center,Vector3.LEFT if kind=="bronze_back" else Vector3.RIGHT),Vector3.ZERO,graphite if kind=="outer_front" else bronze)
  mesh(core,"Engine%dClosedRecess"%engine,Nozzle.cavity(center,prepared.caps[str(engine)+"/bronze_front"][0].x,prepared.caps[str(engine)+"/bronze_back"][0].x),Vector3.ZERO,cavity)
  # Small close-range attachment heads, within the existing nozzle envelope.
  for index in 4:
   var angle=TAU*float(index)/4+PI*.25
   cylinder(ultra,"EngineLipFixing",Vector3(4.743,center.y+cos(angle)*.48,center.z+sin(angle)*.48),.022,.014,Vector3.RIGHT,alloy,8)
  # Inner guide ribs are recessed, never glowing or projecting past the mouth.
  for index in 4:
   var angle=TAU*float(index)/4+PI*.25
   beam(high,"RecessedNozzleRib",Vector3(4.62,center.y+cos(angle)*.206,center.z+sin(angle)*.206),Vector3(4.73,center.y+cos(angle)*.264,center.z+sin(angle)*.264),.014,.014,graphite)
 # Four all-tier ankle joints reinforce, rather than replace, the original legs.
 for x in [-2.58,2.82]:
  for side in [-1,1]:
   var ankle=Vector3(x,1.50,side*1.74)
   cylinder(core,"LandingAnkleHousing",ankle,.115,.36,Vector3.RIGHT,graphite)
   for end in [-1,1]:cylinder(core,"LandingAnkleCap",ankle+Vector3(end*.184,0,0),.083,.015,Vector3.RIGHT,alloy)
   # Clevis anchors are measured against the retained graphite leg faces.
   var a=Vector3(-2.73597,1.73516,side*1.77953) if x<0 else Vector3(2.94721,1.39381,side*1.80371)
   var b=Vector3(-2.93499,2.67,side*1.03712) if x<0 else Vector3(2.75491,2.31107,side*1.01664)
   var outward=Vector3(-.03 if x<0 else .03,0,0)
   for anchor in [a,b]:box(high,"GearRodClevis",anchor+outward*.5,Vector3(.10,.12,.12),graphite)
   a+=outward;b+=outward
   beam(high,"GearHydraulicRod",a,b,.045,.045,alloy)
   beam(high,"GearHydraulicSleeve",a.lerp(b,.47),b,.075,.075,graphite)
   for offset in [-.045,.045]:
    for rise in [-.045,.045]:cylinder(ultra,"AnkleServiceFixing",ankle+Vector3(-.197,rise,offset),.012,.010,Vector3.RIGHT,bronze,8)
 # Fine rebates follow the exact existing central cockpit panes. The imported
 # glass, surrounding primary frames and silhouette remain present at Low.
 for side in [-1,1]:
  var points=[Vector3(-4.15,3.684,side*.14),Vector3(-4.15,3.684,side*.55),Vector3(-3.3,3.991,side*.67),Vector3(-2.5,4.28,side*.79),Vector3(-1.3,4.312,side*.79),Vector3(-1.3,4.312,side*.14)]
  for index in points.size():
   var a:Vector3=cockpit_inset(points[index],side);var b:Vector3=cockpit_inset(points[(index+1)%points.size()],side)
   beam(high,"CockpitGasketRebate",a,b,.019,.014,gasket)
  for x in [-3.3,-2.5]:
   var y=3.991 if x==-3.3 else 4.28;var z=.67 if x==-3.3 else .79
   cylinder(ultra,"CockpitFrameFixing",Vector3(x,y+.030,side*z),.014,.009,Vector3.UP,alloy,8)
 # Source-owned service hatch lips lie on the existing graphite hatch outlines,
 # not a new decorative panel pattern across the hull.
 for side in [-1,1]:
  var low_y=3.52 if side==1 else 2.84
  var high_y=3.80 if side==1 else 3.11
  var z=side*2.173
  var points=[Vector3(-2.18,low_y,z),Vector3(-1.32,low_y+.018,z),Vector3(-1.32,high_y,z),Vector3(-2.18,high_y-.018,z)]
  for index in points.size():beam(high,"ExistingHatchLip",points[index],points[(index+1)%points.size()],.014,.014,alloy)
  box(core,"QuietServiceStatus",Vector3(.9,3.34,side*2.154),Vector3(.20,.018,.008),status)
  # Two small metal clamp shoes explain the existing bronze side rails as
  # hardware while retaining their warm finish and exact original geometry.
  for p in [Vector3(-.2876,2.8568,side*2.6890),Vector3(.3932,2.7852,side*3.1436)]:box(high,"BronzeRailClamp",p,Vector3(.095,.055,.16),alloy)
 var budgets={}
 for group in [core,high,ultra]:
  var triangles=0
  for node in group.find_children("*","MeshInstance3D",true,false):triangles+=node.mesh.get_faces().size()/3
  var batches=Home.batch_visuals(group)
  for node in group.find_children("*","MeshInstance3D",true,false):
   node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   if group!=core:node.visibility_range_end=20.0 if group==high else 14.0;node.visibility_range_end_margin=2.0
  budgets[str(group.name)]={"triangles":triangles,"surfaces":batches,"range_end":0 if group==core else (20 if group==high else 14),"range_margin":0 if group==core else 2}
 set_meta("ship_construction_v096",{"ok":true,"ids":["S01","S02","S03","Q01"],"source_sha":prepared.source_sha,"removed_cap_triangles":212,"recess_depth_m":.164925,"groups":budgets,"new_colliders":0,"new_lights":0,"imported_asset_unchanged":true,"collision_unchanged":true,"quality_distance_policy":"Initial tuning only; native measurements pending","visual_acceptance":false,"performance_measured":false})
func cockpit_inset(point:Vector3,side:int)->Vector3:
 var planar=Vector2(point.x,point.z)
 planar+=(Vector2(-2.8,side*.45)-planar).normalized()*.035
 var y=3.684+(planar.x+4.15)*(.596/1.65) if planar.x< -2.5 else 4.28+(planar.x+2.5)*(.032/1.2)
 return Vector3(planar.x,y+.008,planar.y)
func set_quality(value:int):
 quality=clampi(value,0,3)
 if is_instance_valid(high):high.visible=quality>=2
 if is_instance_valid(ultra):ultra.visible=quality>=3
 set_meta("effective_quality",quality)
