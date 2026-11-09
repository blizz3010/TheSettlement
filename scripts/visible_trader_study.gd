extends Node3D
# Render-only rough study. No service registration, interaction target, collision or save state.
const SPECS = {
 "Dan": {"asset":"res://assets/traders_wip/Dan-PlacementStudy.glb", "idle":"Dan_SubtleIdle_WIP"},
 "Psy": {"asset":"res://assets/traders_wip/Psy-PlacementStudy.glb", "idle":"Psy_QuietIdle_WIP"}
}
var character_id := ""
var visual: Node3D
var animator: AnimationPlayer
var notifier: VisibleOnScreenNotifier3D
var on_screen := false

static func attach_to_market(market: Node3D) -> void:
 for id in SPECS:
  var stand := market.get_node_or_null(str(id) + "Stand")
  if stand == null or stand.has_node("VisibleTraderStudy"): continue
  var actor = load("res://scripts/visible_trader_study.gd").new()
  actor.name = "VisibleTraderStudy"
  actor.character_id = str(id)
  actor.position = Vector3(0, 0.12, 0.8)
  actor.set_meta("art_status", "rough editable WIP; likeness review pending")
  stand.add_child(actor)

func _ready() -> void:
 set_process(false)
 set_physics_process(false)
 var spec: Dictionary = SPECS[character_id]
 visual = load(spec.asset).instantiate()
 visual.name = "CharacterVisual"
 # Asset contract forbids physics children; fail closed rather than risk interaction rays.
 for node in visual.find_children("*", "CollisionObject3D", true, false):
  push_error("Render-only character unexpectedly contains collision: " + str(node))
  visual.free()
  visual = null
  return
 add_child(visual)
 var players := visual.find_children("*", "AnimationPlayer", true, false)
 assert(players.size() == 1)
 animator = players[0]
 animator.play(spec.idle)
 animator.advance(0.0)
 visual.process_mode = Node.PROCESS_MODE_DISABLED
 notifier = VisibleOnScreenNotifier3D.new()
 notifier.name = "IdleVisibilityGate"
 # Covers body and the authored small idle, not a navigation or physics volume.
 notifier.aabb = AABB(Vector3(-0.65, -0.08, -0.45), Vector3(1.3, 1.8, 0.9))
 notifier.screen_entered.connect(_screen_entered)
 notifier.screen_exited.connect(_screen_exited)
 add_child(notifier)
 visibility_changed.connect(_sync_idle)
 _sync_idle()

func _screen_entered() -> void:
 on_screen = true
 _sync_idle()

func _screen_exited() -> void:
 on_screen = false
 _sync_idle()

func _sync_idle() -> void:
 if is_instance_valid(visual):
  visual.process_mode = Node.PROCESS_MODE_INHERIT if on_screen and is_visible_in_tree() else Node.PROCESS_MODE_DISABLED

func _exit_tree() -> void:
 if is_instance_valid(animator): animator.stop()
