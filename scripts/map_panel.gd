extends VBoxContainer
# Candidate full_map replacement only. Host retains M/Escape, modal and focus policy.
const View=preload("res://scripts/map_view.gd")
const Snapshot=preload("res://scripts/map_scene_snapshot.gd")
const Provider=preload("res://scripts/map_world_provider.gd")
var scene:Node3D
var view:Control
var note:Label
var survey_revision=-1
var construction_revision=-1
var survey_count=0
func current_survey_revision()->int:
 # Authored editors/adapters can bump this metadata. Initialization is a separate epoch.
 var epoch=[scene.get_meta("map_revision",0),scene.get("world_initialized"),scene.get("world_activated")]
 # Bounded readiness probes also invalidate when delayed services publish after activation.
 for path in ["SettlementInnExpansion/Inn/RoofRemovableForCutaway","InnLakesideV088/BroadExteriorLake","TailorAtelier/Atelier floor","LaunchpadShip/Art"]:
  var node=scene.get_node_or_null(path)
  epoch.append(node.get_instance_id() if is_instance_valid(node) else 0)
 return hash(epoch)
func current_construction_revision()->int:
 var pieces=scene.get("pieces")
 if not is_instance_valid(pieces):return 0
 # refresh_plot replaces children; IDs also detect same-count edits. No world walk.
 var ids=[]
 for child in pieces.get_children():ids.append(child.get_instance_id())
 return hash(ids)
func setup(world:Node3D):
 scene=world
 var tools=HFlowContainer.new();add_child(tools)
 for spec in [["+",func():view.zoom_button(1.25)],["−",func():view.zoom_button(.8)],["Fit",func():view.fit_button()],["You are here",func():view.locate_player()],["Place marker",func():view.begin_place()],["Mark center",func():view.add_at_center()],["Remove selected",func():view.remove_selected()]]:
  var button=Button.new();button.text=spec[0];button.pressed.connect(spec[1]);tools.add_child(button)
 var filter=OptionButton.new()
 for title in ["All","Services","Places"]:filter.add_item(title)
 filter.item_selected.connect(func(index):view.filter_places(filter.get_item_text(index)));tools.add_child(filter)
 note=Label.new();note.text="Session markers • Wheel: zoom • Middle drag / arrow keys: pan";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(note)
 view=View.new();view.input_allowed=Callable(self,"input_allowed");view.size_flags_vertical=Control.SIZE_EXPAND_FILL;view.size_flags_horizontal=Control.SIZE_EXPAND_FILL;add_child(view)
 visibility_changed.connect(func():
  if is_instance_valid(view):reset_gestures())
 # Survey is deferred until world initialization completes.
func refresh_geometry():
 if not is_instance_valid(scene) or not is_instance_valid(view):return
 var revision=current_survey_revision()
 if survey_revision!=revision:
  var survey=Provider.survey(scene);var snapshot=Snapshot.snapshot(scene)
  for missing in snapshot.get_meta("map_snapshot").missing:
   if not missing in survey.missing:survey.missing.append(missing)
  view.set_survey(survey,snapshot);survey_revision=revision;survey_count+=1
  note.text="Session markers • Wheel: zoom • Middle drag / arrows: pan • Gold: places • Mint: you" if view.layers.missing.is_empty() else "Map incomplete: "+", ".join(view.layers.missing)
 var build_revision=current_construction_revision()
 if construction_revision!=build_revision:
  view.construction_rows=Provider.construction(scene);construction_revision=build_revision;view.redraw_map()
func _process(_delta):
 if not is_instance_valid(scene):return
 # Prepare once when startup settles, including while the map is closed.
 if scene.get("world_initialized") and (not scene.staged_startup or scene.world_activated) and survey_revision!=current_survey_revision():refresh_geometry()
 if not is_visible_in_tree() or not is_instance_valid(scene.player):return
 if construction_revision!=current_construction_revision():refresh_geometry()
 view.update_player(Vector2(scene.player.global_position.x,scene.player.global_position.z),scene.player.rotation.y)
func _exit_tree():
 if is_instance_valid(view):view.markers.dispose()

func reset_gestures():
 if is_instance_valid(view):view.dragging=false;view.add_mode=false;view.redraw_map()
func _notification(what):
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:reset_gestures()

func input_allowed()->bool:
 if not is_instance_valid(scene) or scene.is_queued_for_deletion() or scene.startup_cancel_requested or not scene.world_initialized or not scene.cooking_window_focused:return false
 if scene.staged_startup and not scene.world_activated:return false
 if not is_instance_valid(scene.settlement_hud) or not scene.settlement_hud.full.visible:return false
 for panel in [scene.options_panel,scene.inventory_panel,scene.build_wheel,scene.dialog,scene.request_panel,scene.supplies_panel,scene.workbench_panel,scene.clothing_panel,scene.quest_journal,scene.skills_panel]:
  if is_instance_valid(panel) and panel.visible:return false
 return not scene.fishing_session.active() and not (is_instance_valid(scene.cooking_test) and scene.cooking_test.is_open())
