extends Node3D
# Decorative, deterministic southern meadow wildlife. No gameplay state dependencies.
const GROUND_Y := -0.05
const BIRD = preload("res://assets/wildlife/songbird.glb")
const SQUIRREL = preload("res://assets/wildlife/squirrel.glb")
var elapsed := 0.0
var animals: Array[Dictionary] = []
static func routes() -> Array:
 var result = [
  {"kind":"squirrel","points":[Vector3(-22,0,18),Vector3(-20,0,20),Vector3(-23,0,22)],"rest":3.0,"travel":5.0},
  {"kind":"squirrel","points":[Vector3(13,0,23),Vector3(15,0,25),Vector3(12,0,25)],"rest":4.0,"travel":5.0},
  {"kind":"bird","points":[Vector3(-21,0,21),Vector3(-19.7,0,22),Vector3(-21.5,0,23)],"rest":6.0,"travel":2.0},
  {"kind":"bird","points":[Vector3(-24,0,19),Vector3(-23,0,20),Vector3(-24.5,0,21)],"rest":8.0,"travel":2.0},
  {"kind":"bird","points":[Vector3(14,0,24),Vector3(12.8,0,23),Vector3(13.2,0,25)],"rest":7.0,"travel":2.0}
 ]
 for i in [0,2,3]:
  for j in range(result[i].points.size()):result[i].points[j]+=Vector3(0,0,9)
 return result
func _ready() -> void:
 name = "AmbientWildlife"
 process_mode = Node.PROCESS_MODE_ALWAYS # Live ESC must not freeze ambient world.
 for spec in routes():
  var root := Node3D.new();add_child(root);root.name = spec.kind+str(animals.size())
  var art = (BIRD if spec.kind=="bird" else SQUIRREL).instantiate();root.add_child(art)
  var player: AnimationPlayer
  for candidate in art.find_children("*","AnimationPlayer",true,false): player = candidate;break
  assert(player != null)
  player.get_animation("AmbientLoop").loop_mode=Animation.LOOP_LINEAR
  player.play("AmbientLoop")
  var wings: Array[Node3D] = []
  for candidate in art.find_children("Wing*","Node3D",true,false): wings.append(candidate)
  var item = spec.duplicate(true);item.merge({"root":root,"art":art,"anim":player,"wings":wings,"offset":float(animals.size())*1.9,"flying":false})
  animals.append(item)
 advance(0.0)
func _process(delta: float) -> void: advance(delta)
func advance(delta: float) -> void:
 elapsed += delta
 for item in animals:
  var duration: float = item.rest+item.travel
  var t: float = elapsed+item.offset
  var index: int = int(t/duration)%item.points.size()
  var local: float = fmod(t,duration)
  var progress: float = clampf((local-item.rest)/item.travel,0,1)
  var u: float = smoothstep(0.0,1.0,progress)
  var a: Vector3 = item.points[index];var b: Vector3 = item.points[(index+1)%item.points.size()]
  var animal: Node3D = item.root
  animal.position = a.lerp(b,u)
  animal.position.y = GROUND_Y - (0.014 if item.kind=="bird" else 0.013)
  var heading: float = atan2((b-a).x,(b-a).z) # GLB model front is +Z.
  animal.rotation.y = lerp_angle(animal.rotation.y,heading,minf(delta*4,1)) if delta>0 else heading
  var moving: bool = progress>0 and progress<1
  if item.kind=="bird":
   if moving:
    if not item.flying:item.anim.pause();item.flying=true
    animal.position.y += sin(progress*PI)*0.65
    # Short ground-to-ground flutter, not hovering or sustained high flight.
    for w in item.wings:
     w.rotation.z = (1 if w.position.x>0 else -1)*sin(progress*TAU*8)*0.85
   else:
    if item.flying:
     for w in item.wings:w.rotation=Vector3.ZERO
     item.anim.play("AmbientLoop");item.flying=false
    item.anim.speed_scale=0.7
  else:
   item.anim.speed_scale=1.7 if moving else 0.3
   if moving:animal.position.y += sin(progress*PI)*abs(sin(progress*TAU*6))*0.012
func positions_safe() -> bool:
 for index in range(animals.size()):
  var item=animals[index]
  var p: Vector3 = item.root.position
  if item.has("market_route_offset"):
   # Only an explicitly journaled rigid translation may leave the baseline meadow.
   var baseline=routes()[index].points
   var delta:Vector3=item.market_route_offset
   if baseline.size()!=item.points.size():return false
   for j in range(baseline.size()):
    if not (baseline[j]+delta).is_equal_approx(item.points[j]):return false
   var nearest=INF
   for j in range(item.points.size()):
    var a:Vector3=item.points[j];var b:Vector3=item.points[(j+1)%item.points.size()]
    nearest=minf(nearest,Vector2(p.x,p.z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(p.x,p.z),Vector2(a.x,a.z),Vector2(b.x,b.z))))
   if nearest>.02 or absf(p.x)>44 or absf(p.z)>44:return false
   if preload("res://scripts/market_landscape.gd").conflicts(AABB(p-Vector3(.45,.2,.45),Vector3(.9,1.5,.9))):return false
   continue
  # Two intentionally separated meadow rectangles; all known corridors north of z=14.
  var west := p.x>=-25 and p.x<=-19 and p.z>=27 and p.z<=32
  var east := p.x>=12 and p.x<=15 and p.z>=23 and p.z<=25
  if not (west or east):return false
 return true
