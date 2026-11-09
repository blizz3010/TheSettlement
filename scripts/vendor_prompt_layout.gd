extends RefCounted
# Presentation only. Real service eligibility, LOS and dispatch remain authoritative.
const HINT_DISTANCE := 2.0
const SAFE_MARGIN := 16.0
const HOTBAR_GAP := 12.0
const MAX_WIDTH := 580.0
static func near_counter(player_position:Vector3,target:Vector3)->bool:
 if not player_position.is_finite() or not target.is_finite():return false
 return Vector2(player_position.x,player_position.z).distance_to(Vector2(target.x,target.z))<=HINT_DISTANCE
static func panel_rect(viewport:Vector2,bar:Rect2,text_height:float)->Rect2:
 var width=minf(MAX_WIDTH,maxf(0,viewport.x-2*SAFE_MARGIN))
 var bar_top=bar.position.y if bar.size.y>0 else viewport.y-72.0
 var bottom=clampf(bar_top-HOTBAR_GAP,SAFE_MARGIN,maxf(SAFE_MARGIN,viewport.y-SAFE_MARGIN))
 var height=minf(maxf(44.0,text_height+20.0),maxf(0,bottom-SAFE_MARGIN))
 return Rect2(Vector2((viewport.x-width)*.5,bottom-height),Vector2(width,height))
static func apply(scene):
 var panel:PanelContainer=scene.prompt_panel;var label:Label=scene.prompt
 panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var bar=Rect2()
 if is_instance_valid(scene.settlement_hud) and is_instance_valid(scene.settlement_hud.equipment):
  var actual:Rect2=scene.settlement_hud.equipment.get_global_rect()
  var inverse:Transform2D=scene.hud_root.get_global_transform().affine_inverse()
  var start:Vector2=inverse*actual.position;var end:Vector2=inverse*actual.end
  bar=Rect2(start,end-start)
 var width=minf(MAX_WIDTH,maxf(0,scene.hud_root.size.x-2*SAFE_MARGIN))
 var font:Font=label.get_theme_font('font');var font_size=label.get_theme_font_size('font_size')
 var text_height=font.get_multiline_string_size(label.text,HORIZONTAL_ALIGNMENT_CENTER,maxf(1,width-28),font_size).y
 # Label's actual wrapped minimum includes theme line spacing omitted by Font.
 label.size.x=maxf(1,width-28)
 text_height=maxf(text_height,label.get_minimum_size().y)
 var rect=panel_rect(scene.hud_root.size,bar,text_height)
 panel.offset_left=rect.position.x;panel.offset_right=rect.end.x
 panel.offset_top=rect.position.y;panel.offset_bottom=rect.end.y
