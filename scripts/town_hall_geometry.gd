extends RefCounted
const ANCHOR=Vector3(0,0,-23)
const FLOOR_TOP=.24
static func add_box(root:Node3D,label:String,center:Vector3,size:Vector3):
 var body=StaticBody3D.new();body.name=label;body.position=center;body.set_meta("audio_surface","stone" if label=="Level floor" else "wood");root.add_child(body)
 var c=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=size;c.shape=shape;body.add_child(c)
 return body
static func build(scene:Node3D):
 var holder=Node3D.new();holder.name="TownHallCollision";scene.add_child(holder)
 add_box(holder,"Level floor",Vector3(0,.12,-23),Vector3(18,.24,18))
 add_box(holder,"west wall",Vector3(-8.8,3.34,-23),Vector3(0.4,6.2,18))
 add_box(holder,"east wall",Vector3(8.8,3.34,-23),Vector3(0.4,6.2,18))
 add_box(holder,"rear wall",Vector3(0,3.34,-31.8),Vector3(18,6.2,0.4))
 add_box(holder,"front bay",Vector3(-7.1,3.34,-14.2),Vector3(2.75,6.2,0.4))
 add_box(holder,"front bay",Vector3(-3.9,3.34,-14.2),Vector3(2.75,6.2,0.4))
 add_box(holder,"front bay",Vector3(3.9,3.34,-14.2),Vector3(2.75,6.2,0.4))
 add_box(holder,"front bay",Vector3(7.1,3.34,-14.2),Vector3(2.75,6.2,0.4))
 add_box(holder,"front column",Vector3(-8.7,3.34,-14.2),Vector3(0.45,6.2,0.45))
 add_box(holder,"front column",Vector3(-5.5,3.34,-14.2),Vector3(0.45,6.2,0.45))
 add_box(holder,"front column",Vector3(-2.3,3.34,-14.2),Vector3(0.45,6.2,0.45))
 add_box(holder,"front column",Vector3(2.3,3.34,-14.2),Vector3(0.45,6.2,0.45))
 add_box(holder,"front column",Vector3(5.5,3.34,-14.2),Vector3(0.45,6.2,0.45))
 add_box(holder,"front column",Vector3(8.7,3.34,-14.2),Vector3(0.45,6.2,0.45))
 add_box(holder,"nave column",Vector3(-3,3.6449999999999996,-14.5),Vector3(0.25,6.81,0.25))
 add_box(holder,"nave column",Vector3(-3,3.6449999999999996,-18.7),Vector3(0.25,6.81,0.25))
 add_box(holder,"nave column",Vector3(-3,3.6449999999999996,-23),Vector3(0.25,6.81,0.25))
 add_box(holder,"nave column",Vector3(-3,3.6449999999999996,-27.3),Vector3(0.25,6.81,0.25))
 add_box(holder,"nave column",Vector3(-3,3.6449999999999996,-31.5),Vector3(0.25,6.81,0.25))
 add_box(holder,"nave column",Vector3(3,3.6449999999999996,-14.5),Vector3(0.25,6.81,0.25))
 add_box(holder,"nave column",Vector3(3,3.6449999999999996,-18.7),Vector3(0.25,6.81,0.25))
 add_box(holder,"nave column",Vector3(3,3.6449999999999996,-23),Vector3(0.25,6.81,0.25))
 add_box(holder,"nave column",Vector3(3,3.6449999999999996,-27.3),Vector3(0.25,6.81,0.25))
 add_box(holder,"nave column",Vector3(3,3.6449999999999996,-31.5),Vector3(0.25,6.81,0.25))
 add_box(holder,"welcome desk",Vector3(5,0.82,-19),Vector3(4.15,1.16,1.2))
 add_box(holder,"Mara desk",Vector3(5.5,0.82,-28),Vector3(3.35,1.16,1.2))
 add_box(holder,"bookcase",Vector3(-7.0,4.65075,-31.3),Vector3(2.53,2.0215,0.55))
 add_box(holder,"bookcase",Vector3(-4.4,4.65075,-31.3),Vector3(2.53,2.0215,0.55))
 add_box(holder,"bookcase",Vector3(-7.4,4.65075,-23.2),Vector3(1.8216,2.0215,0.55))
 add_box(holder,"bookcase",Vector3(-7.4,4.65075,-27.1),Vector3(1.8216,2.0215,0.55))
 add_box(holder,"reading table",Vector3(-4.4,4.075,-24.8),Vector3(1.8,0.87,0.9))
 add_box(holder,"reading chair",Vector3(-4.4,4.1975,-23.8),Vector3(0.65,1.115,0.65))
 add_box(holder,"reading table",Vector3(-4.4,4.075,-28.8),Vector3(1.8,0.87,0.9))
 add_box(holder,"reading chair",Vector3(-4.4,4.1975,-27.8),Vector3(0.65,1.115,0.65))
 add_box(holder,"planter",Vector3(-3.7,0.5525,-15.5),Vector3(0.72,0.625,0.72))
 add_box(holder,"planter",Vector3(7.8,0.5525,-15.5),Vector3(0.72,0.625,0.72))
 add_box(holder,"planter",Vector3(7.8,0.5525,-30.8),Vector3(0.72,0.625,0.72))
 add_box(holder,"planter",Vector3(-7.8,0.5525,-29.5),Vector3(0.72,0.625,0.72))
 preload("res://scripts/hall_gallery.gd").add_to(scene,holder)
 # Front lintel and glazing above 4.4m entry leave passage unobstructed.
 add_box(holder,"Entry upper frame",Vector3(0,5.25,-14.2),Vector3(4.6,1.7,.48))
 for segment in [[-9.5,-3.0,6.2,7.1],[-3.0,0.0,7.1,9.0],[0.0,3.0,9.0,7.1],[3.0,9.5,7.1,6.2]]:
  var points=PackedVector3Array()
  for depth in [-9.5,9.5]:
   for extra in [0.0,.16]:
    points.append(Vector3(segment[0],segment[2]+extra,-23-depth))
    points.append(Vector3(segment[1],segment[3]+extra,-23-depth))
  var body=StaticBody3D.new();body.name="Roof slab";holder.add_child(body)
  var shape=ConvexPolygonShape3D.new();shape.points=points
  var col=CollisionShape3D.new();col.shape=shape;body.add_child(col)
 # Bounded warm light at authored interior lantern fixtures, no global exposure changes.
 var lamps=Node3D.new();lamps.name="TownHallLanternLights";scene.add_child(lamps)
 for at in [Vector3(-3,4.75,-17),Vector3(3,4.75,-17),Vector3(-3,4.75,-23),Vector3(3,4.75,-23),Vector3(-3,4.75,-29),Vector3(3,4.75,-29)]:
  var light=OmniLight3D.new();light.position=at;light.light_color=Color(1,.66,.35);light.light_energy=.7;light.omni_range=5.5;light.shadow_enabled=false;lamps.add_child(light)
 preload('res://scripts/hall_welcome_detail.gd').add_to(scene)
 if not preload('res://scripts/hall_basement_blockout.gd').add_to(scene):
  push_error('Hall basement preparation failed; aborting startup')
  scene.request_startup_cancel()
  return null
 preload('res://scripts/hall_basement_finish.gd').add_to(scene)
 preload('res://scripts/hall_basement_dressing.gd').add_to(scene)
 preload("res://scripts/hall_lantern_mounts.gd").add_to(scene)
 var review_finish=preload("res://scripts/hall_review_finish.gd").apply(scene)
 if not review_finish.get("ok",false):
  push_error("Hall review finish failed: "+str(review_finish))
  scene.request_startup_cancel()
  return null
 return holder

# Opt-in loading successor scheduling. Original synchronous APIs above remain unchanged.
static func build_staged(scene:Node3D):
 var startup_owner:Node=scene
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 01"): return null
 var holder=Node3D.new();holder.name="TownHallCollision";scene.add_child(holder)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 02"): return null
 add_box(holder,"Level floor",Vector3(0,.12,-23),Vector3(18,.24,18))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 03"): return null
 add_box(holder,"west wall",Vector3(-8.8,3.34,-23),Vector3(0.4,6.2,18))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 04"): return null
 add_box(holder,"east wall",Vector3(8.8,3.34,-23),Vector3(0.4,6.2,18))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 05"): return null
 add_box(holder,"rear wall",Vector3(0,3.34,-31.8),Vector3(18,6.2,0.4))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 06"): return null
 add_box(holder,"front bay",Vector3(-7.1,3.34,-14.2),Vector3(2.75,6.2,0.4))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 07"): return null
 add_box(holder,"front bay",Vector3(-3.9,3.34,-14.2),Vector3(2.75,6.2,0.4))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 08"): return null
 add_box(holder,"front bay",Vector3(3.9,3.34,-14.2),Vector3(2.75,6.2,0.4))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 09"): return null
 add_box(holder,"front bay",Vector3(7.1,3.34,-14.2),Vector3(2.75,6.2,0.4))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 10"): return null
 add_box(holder,"front column",Vector3(-8.7,3.34,-14.2),Vector3(0.45,6.2,0.45))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 11"): return null
 add_box(holder,"front column",Vector3(-5.5,3.34,-14.2),Vector3(0.45,6.2,0.45))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 12"): return null
 add_box(holder,"front column",Vector3(-2.3,3.34,-14.2),Vector3(0.45,6.2,0.45))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 13"): return null
 add_box(holder,"front column",Vector3(2.3,3.34,-14.2),Vector3(0.45,6.2,0.45))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 14"): return null
 add_box(holder,"front column",Vector3(5.5,3.34,-14.2),Vector3(0.45,6.2,0.45))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 15"): return null
 add_box(holder,"front column",Vector3(8.7,3.34,-14.2),Vector3(0.45,6.2,0.45))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 16"): return null
 add_box(holder,"nave column",Vector3(-3,3.6449999999999996,-14.5),Vector3(0.25,6.81,0.25))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 17"): return null
 add_box(holder,"nave column",Vector3(-3,3.6449999999999996,-18.7),Vector3(0.25,6.81,0.25))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 18"): return null
 add_box(holder,"nave column",Vector3(-3,3.6449999999999996,-23),Vector3(0.25,6.81,0.25))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 19"): return null
 add_box(holder,"nave column",Vector3(-3,3.6449999999999996,-27.3),Vector3(0.25,6.81,0.25))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 20"): return null
 add_box(holder,"nave column",Vector3(-3,3.6449999999999996,-31.5),Vector3(0.25,6.81,0.25))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 21"): return null
 add_box(holder,"nave column",Vector3(3,3.6449999999999996,-14.5),Vector3(0.25,6.81,0.25))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 22"): return null
 add_box(holder,"nave column",Vector3(3,3.6449999999999996,-18.7),Vector3(0.25,6.81,0.25))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 23"): return null
 add_box(holder,"nave column",Vector3(3,3.6449999999999996,-23),Vector3(0.25,6.81,0.25))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 24"): return null
 add_box(holder,"nave column",Vector3(3,3.6449999999999996,-27.3),Vector3(0.25,6.81,0.25))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 25"): return null
 add_box(holder,"nave column",Vector3(3,3.6449999999999996,-31.5),Vector3(0.25,6.81,0.25))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 26"): return null
 add_box(holder,"welcome desk",Vector3(5,0.82,-19),Vector3(4.15,1.16,1.2))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 27"): return null
 add_box(holder,"Mara desk",Vector3(5.5,0.82,-28),Vector3(3.35,1.16,1.2))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 28"): return null
 add_box(holder,"bookcase",Vector3(-7.0,4.65075,-31.3),Vector3(2.53,2.0215,0.55))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 29"): return null
 add_box(holder,"bookcase",Vector3(-4.4,4.65075,-31.3),Vector3(2.53,2.0215,0.55))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 30"): return null
 add_box(holder,"bookcase",Vector3(-7.4,4.65075,-23.2),Vector3(1.8216,2.0215,0.55))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 31"): return null
 add_box(holder,"bookcase",Vector3(-7.4,4.65075,-27.1),Vector3(1.8216,2.0215,0.55))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 32"): return null
 add_box(holder,"reading table",Vector3(-4.4,4.075,-24.8),Vector3(1.8,0.87,0.9))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 33"): return null
 add_box(holder,"reading chair",Vector3(-4.4,4.1975,-23.8),Vector3(0.65,1.115,0.65))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 34"): return null
 add_box(holder,"reading table",Vector3(-4.4,4.075,-28.8),Vector3(1.8,0.87,0.9))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 35"): return null
 add_box(holder,"reading chair",Vector3(-4.4,4.1975,-27.8),Vector3(0.65,1.115,0.65))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 36"): return null
 add_box(holder,"planter",Vector3(-3.7,0.5525,-15.5),Vector3(0.72,0.625,0.72))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 37"): return null
 add_box(holder,"planter",Vector3(7.8,0.5525,-15.5),Vector3(0.72,0.625,0.72))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 38"): return null
 add_box(holder,"planter",Vector3(7.8,0.5525,-30.8),Vector3(0.72,0.625,0.72))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 39"): return null
 add_box(holder,"planter",Vector3(-7.8,0.5525,-29.5),Vector3(0.72,0.625,0.72))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 40"): return null
 preload("res://scripts/hall_gallery.gd").add_to(scene,holder)
 # Front lintel and glazing above 4.4m entry leave passage unobstructed.
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 41"): return null
 add_box(holder,"Entry upper frame",Vector3(0,5.25,-14.2),Vector3(4.6,1.7,.48))
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 42"): return null
 for segment in [[-9.5,-3.0,6.2,7.1],[-3.0,0.0,7.1,9.0],[0.0,3.0,9.0,7.1],[3.0,9.5,7.1,6.2]]:
  var points=PackedVector3Array()
  for depth in [-9.5,9.5]:
   for extra in [0.0,.16]:
    points.append(Vector3(segment[0],segment[2]+extra,-23-depth))
    points.append(Vector3(segment[1],segment[3]+extra,-23-depth))
  var body=StaticBody3D.new();body.name="Roof slab";holder.add_child(body)
  var shape=ConvexPolygonShape3D.new();shape.points=points
  var col=CollisionShape3D.new();col.shape=shape;body.add_child(col)
 # Bounded warm light at authored interior lantern fixtures, no global exposure changes.
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 43"): return null
 var lamps=Node3D.new();lamps.name="TownHallLanternLights";scene.add_child(lamps)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 44"): return null
 for at in [Vector3(-3,4.75,-17),Vector3(3,4.75,-17),Vector3(-3,4.75,-23),Vector3(3,4.75,-23),Vector3(-3,4.75,-29),Vector3(3,4.75,-29)]:
  var light=OmniLight3D.new();light.position=at;light.light_color=Color(1,.66,.35);light.light_energy=.7;light.omni_range=5.5;light.shadow_enabled=false;lamps.add_child(light)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 45"): return null
 preload('res://scripts/hall_welcome_detail.gd').add_to(scene)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 46"): return null
 var basement_ok=false
 if startup_owner != null:
  basement_ok=await preload('res://scripts/hall_basement_blockout.gd').add_to_staged(scene,startup_owner)
 else:
  basement_ok=preload('res://scripts/hall_basement_blockout.gd').add_to(scene)
 if not basement_ok:
  if not scene.startup_cancel_requested:push_error('Hall basement preparation failed; aborting startup')
  scene.request_startup_cancel()
  return null
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 47"): return null
 preload('res://scripts/hall_basement_finish.gd').add_to(scene)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 48"): return null
 preload('res://scripts/hall_basement_dressing.gd').add_to(scene)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 49"): return null
 preload("res://scripts/hall_lantern_mounts.gd").add_to(scene)
 if startup_owner != null:
  if await startup_owner._startup_checkpoint("hall step 50"): return null
 var review_finish=preload("res://scripts/hall_review_finish.gd").apply(scene)
 if not review_finish.get("ok",false):
  push_error("Hall review finish failed: "+str(review_finish))
  scene.request_startup_cancel()
  return null
 return holder
