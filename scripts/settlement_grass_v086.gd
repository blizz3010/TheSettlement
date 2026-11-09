extends Node3D
# Baked additive ground coverage; no runtime spawning, physics, or save writes.
# Detailed and ten-triangle representations cross-fade by vertex height, no alpha.
const DENSITY=[.30,.65,1.0,1.0]
const NEAR=[Vector2(9,14),Vector2(13,19),Vector2(18,24),Vector2(24,31)]
const FAR=[22.0,35.0,55.0,85.0]
var quality=2
func _ready():
 add_to_group('plaza_grass_quality')
 set_quality(load('res://scripts/game_settings.gd').new().current_grass_quality(self))
func set_quality(value:int):
 quality=clampi(value,0,3)
 var touched={}
 for child in get_children():
  if not child is MultiMeshInstance3D:continue
  var near=child.get_meta('near_lod',true)
  var ratio=1.0 if child.get_meta('edge_seam',false) else DENSITY[quality]
  child.multimesh.visible_instance_count=int(child.multimesh.instance_count*ratio)
  # Actual instance bounds plus six-metre chunk allowance prevent centre culling.
  child.visibility_range_begin=0.0 if near else maxf(0,NEAR[quality].x-6.0)
  child.visibility_range_end=(NEAR[quality].y if near else FAR[quality])+6.0
  child.visibility_range_end_margin=0
  var material=child.material_override
  if not touched.has(material):
   material.set_shader_parameter('near_start',NEAR[quality].x)
   material.set_shader_parameter('near_end',NEAR[quality].y)
   material.set_shader_parameter('far_end',FAR[quality])
   touched[material]=true
