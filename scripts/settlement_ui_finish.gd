extends RefCounted
# Presentation only: do not alter services, interaction eligibility, save data or collisions.
static func apply(scene:Node3D):
 scene.controls.hide()
 for child in scene.hud_root.get_children():
  if child is Panel and child.anchor_top==1.0 and child.offset_top==-110.0:child.hide();child.set_meta("removed_controls_backing",true)
 for name in ["EastServiceLabel","WestServiceLabel"]:
  var label=scene.get_node_or_null(name)
  if label:label.set_meta("hide_service_caption",true);label.hide()
 for node in scene.find_children("*","Label3D",true,false):
  if node.text.begins_with("PLANNED SERVICE") or node.text=="PLAYER LEVEL 20 · PLANNED" or node.text=="ARMOR     •     HELMETS     •     GEAR":node.hide();node.set_meta("prototype_notice_hidden",true)
