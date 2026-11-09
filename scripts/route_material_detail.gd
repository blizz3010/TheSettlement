extends Node
# Owns only explicitly registered route materials. No scene-wide scans, geometry,
# settings writes or per-frame work. Detached baked edges synchronize on tree entry.
const Settings=preload('res://scripts/game_settings.gd')
var materials:Array[ShaderMaterial]=[]
var quality:int=2

static func bind(owner:Node,material:ShaderMaterial):
 var controller=owner.get_node_or_null('RouteMaterialDetail')
 if controller==null:
  controller=load('res://scripts/route_material_detail.gd').new()
  controller.name='RouteMaterialDetail'
  owner.add_child(controller)
 controller.register_material(material)
 return controller

func _enter_tree():
 add_to_group('material_detail_quality')
 set_quality(Settings.new().current_material_detail_quality(self))

func register_material(material:ShaderMaterial):
 if not materials.has(material):materials.append(material)
 # Read the live preview, not just disk, for materials created after settings apply.
 set_quality(Settings.new().current_material_detail_quality(self))

func set_quality(value:int):
 quality=clampi(value,0,3)
 for material in materials:material.set_shader_parameter('detail_quality',quality)
 set_meta('effective_quality',quality)
