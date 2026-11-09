extends Node3D
## Provisional render-only coverage. No services, physics, or saves.
var actor_id := ""
var asset_path := ""
var idle_name := ""
var visual: Node3D
var animator: AnimationPlayer
var notifier: VisibleOnScreenNotifier3D
var on_screen := false
var activation_enabled := false

static func attach(parent: Node3D, id: String, asset: String, idle: String, feet: Vector3, yaw: float, uniform_scale: float = 1.0) -> Node3D:
 var name_key := "CoverageStudy_" + id
 if parent.has_node(name_key):
  var existing=parent.get_node(name_key)
  if existing.get_script()!=load("res://scripts/trader_coverage.gd"):return null
  if is_instance_valid(existing.visual):return existing
  parent.remove_child(existing);existing.queue_free()
 var actor = load("res://scripts/trader_coverage.gd").new()
 actor.name = name_key
 actor.actor_id = id
 actor.asset_path = asset
 actor.idle_name = idle
 actor.position = feet
 actor.rotation.y = yaw
 actor.scale = Vector3.ONE * uniform_scale
 actor.set_meta("art_status", "provisional coverage; identity and fit review pending")
 parent.add_child(actor)
 if not is_instance_valid(actor.visual):
  parent.remove_child(actor);actor.queue_free();return null
 return actor

func _ready() -> void:
 set_process(false)
 set_physics_process(false)
 if not ResourceLoader.exists(asset_path):return
 var packed=load(asset_path) as PackedScene
 if packed==null:return
 visual=packed.instantiate()
 if visual==null or not visual.find_children("*", "CollisionObject3D", true, false).is_empty():
  if visual!=null:visual.free()
  visual=null;return
 add_child(visual)
 var players=visual.find_children("*", "AnimationPlayer", true, false)
 if players.size()!=1:visual.queue_free();visual=null;return
 animator=players[0]
 if not animator.has_animation(idle_name):visual.queue_free();visual=null;return
 # Imported animations may be shared between instances; never mutate them.
 for library_name in animator.get_animation_library_list():
  var local=animator.get_animation_library(library_name).duplicate(true)
  animator.remove_animation_library(library_name);animator.add_animation_library(library_name,local)
 if actor_id=="Atlas":
  idle_name=load("res://scripts/atlas_idle.gd").install(animator)
  if idle_name.is_empty():visual.queue_free();visual=null;return
 elif actor_id in ["Rook","West"]:
  if not load("res://scripts/staff_role_materials.gd").apply_to(visual,actor_id):visual.queue_free();visual=null;return
 animator.get_animation(idle_name).loop_mode=Animation.LOOP_LINEAR
 animator.play(idle_name);animator.advance(0.0)
 notifier = VisibleOnScreenNotifier3D.new()
 notifier.aabb = AABB(Vector3(-.65,-.08,-.5),Vector3(1.3,2.2,1.0))
 notifier.screen_entered.connect(func():on_screen=true;_sync())
 notifier.screen_exited.connect(func():on_screen=false;_sync())
 add_child(notifier)
 visibility_changed.connect(_sync)
 _sync()

func _sync() -> void:
 if is_instance_valid(visual):
  visual.process_mode = Node.PROCESS_MODE_INHERIT if activation_enabled and on_screen and is_visible_in_tree() else Node.PROCESS_MODE_DISABLED

func set_activation_enabled(enabled: bool) -> void:
 activation_enabled=enabled
 _sync()

func _exit_tree() -> void:
 if is_instance_valid(animator): animator.stop()
