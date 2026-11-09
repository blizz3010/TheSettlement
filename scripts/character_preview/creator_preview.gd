extends SubViewportContainer
# A provisional head/shoulder preview, separate from the inventory mannequin.
const Appearance=preload("res://scripts/character_preview/creator_draft.gd")
var source:PackedScene
var model:Node3D
var ready_ok=false
var turn=0.0
var viewport:SubViewport
var shown_appearance:Dictionary={}
func _ready():
 stretch=true;size_flags_horizontal=Control.SIZE_EXPAND_FILL;size_flags_vertical=Control.SIZE_EXPAND_FILL;custom_minimum_size=Vector2(260,200)
 viewport=SubViewport.new();viewport.size=Vector2i(720,720);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(viewport)
 resized.connect(redraw_preview);visibility_changed.connect(func():call_deferred("redraw_preview"))
 var stage=Node3D.new();viewport.add_child(stage)
 var environment=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("172c29");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("ced9cc");e.ambient_light_energy=.6;environment.environment=e;stage.add_child(environment)
 var key=DirectionalLight3D.new();key.rotation_degrees=Vector3(-25,-30,0);key.light_energy=1.3;stage.add_child(key)
 var fill=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-5,135,0);fill.light_color=Color("9fb9c5");fill.light_energy=.3;stage.add_child(fill)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.86;camera.position=Vector3(0,1.40,4);stage.add_child(camera);camera.look_at(Vector3(0,1.40,0));camera.current=true
 if source==null:return
 var raw=source.instantiate()
 if raw==null:return
 if not raw is Node3D:raw.free();return
 model=raw;stage.add_child(model)
 var names={};var morphs=0
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  names[str(mesh.name)]=true
  if mesh.find_blend_shape_by_name("probe_cheek_volume_v1")>=0:morphs+=1
 for name in ["hair_short02_v1","hair_bob01_v1","brow_009_v1","brow_001_v1","eye_brown_v1","eye_blue_v1"]:
  if not names.has(name):model.queue_free();model=null;return
 ready_ok=morphs>0
 if not ready_ok:model.queue_free();model=null
func available()->bool:
 return ready_ok and is_instance_valid(model) and not model.is_queued_for_deletion() and model.is_inside_tree()
func show_draft(value:Dictionary)->bool:
 if not available():return false
 var visible_appearance={"cheek":value.cheek,"hair":value.hair,"brows":value.brows,"eyes":value.eyes,"hair_tint":value.get("hair_tint","natural")}
 if visible_appearance==shown_appearance:return true
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  var i=mesh.find_blend_shape_by_name("probe_cheek_volume_v1")
  if i>=0:mesh.set_blend_shape_value(i,float(value.cheek))
  if str(mesh.name) in ["hair_short02_v1","hair_bob01_v1"]:
   mesh.visible=str(mesh.name)==value.hair
   var tint=value.get("hair_tint","natural")
   if mesh.get_meta("applied_hair_tint","")!=tint:
    for surface in mesh.mesh.get_surface_count():
     var key="original_hair_material_%d"%surface
     if not mesh.has_meta(key):mesh.set_meta(key,mesh.get_active_material(surface))
     var original=mesh.get_meta(key) as StandardMaterial3D
     if original!=null:mesh.set_surface_override_material(surface,Appearance.tinted_material(original,value))
    mesh.set_meta("applied_hair_tint",tint)
  if str(mesh.name) in ["brow_009_v1","brow_001_v1"]:mesh.visible=str(mesh.name)==value.brows
  if str(mesh.name) in ["eye_brown_v1","eye_blue_v1"]:mesh.visible=str(mesh.name)==value.eyes
 shown_appearance=visible_appearance.duplicate(true);redraw_preview()
 return true
func redraw_preview():
 if is_instance_valid(viewport):viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
func set_turn(degrees:float):
 var next_turn=clampf(degrees,-45,45)
 if is_equal_approx(turn,next_turn):return
 turn=next_turn
 if is_instance_valid(model):model.rotation_degrees.y=turn;redraw_preview()
func _exit_tree():ready_ok=false
