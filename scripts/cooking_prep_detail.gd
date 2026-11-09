extends Node3D
# CK03–04 bounded display only. No ground footprint, NPC, physics or light edits.
# Silhouette stock stays at Low; small labels, herb leaves and towel folds are optional.
var fine:Node3D
var quality=2
var materials={}
static func apply(dressing:Node3D):
 if dressing.has_node('CookingPrepV095'):return
 var detail=load('res://scripts/cooking_prep_detail.gd').new();detail.name='CookingPrepV095';dressing.add_child(detail)
 detail.build()
func material(key:String,color:String)->StandardMaterial3D:
 if materials.has(key):return materials[key]
 var m=StandardMaterial3D.new();m.albedo_color=Color(color);m.roughness=.88;materials[key]=m;return m
func mesh(parent:Node3D,id:String,geometry:Mesh,p:Vector3,s:Vector3,m:Material)->MeshInstance3D:
 var n=MeshInstance3D.new();n.name=id;n.mesh=geometry;n.position=p;n.scale=s;n.material_override=m;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(n);return n
func box(parent:Node3D,id:String,p:Vector3,s:Vector3,m:Material)->MeshInstance3D:return mesh(parent,id,BoxMesh.new(),p,s,m)
func label(id:String,value:String,p:Vector3):
 var text=Label3D.new();text.name=id;text.text=value;text.position=p;text.font_size=28;text.pixel_size=.0009;text.modulate=Color('f0dfb6');text.outline_size=2;fine.add_child(text)
func build():
 add_to_group('material_detail_quality')
 var wood=material('wood','78533a');var green=material('herb','647b56');var teal=material('jar','426964');var cream=material('cloth','d9ccb0');var iron=material('iron','30443f');var fish=material('fish','9aa994')
 fine=Node3D.new();fine.name='OptionalPrepDetail';add_child(fine)
 # Fish stays on the original board, not in the empty center handover strip.
 var body=mesh(self,'DisplayFish',SphereMesh.new(),Vector3(-.425,1.065,1.21),Vector3(.25,.045,.095),fish)
 body.set_meta('decorative_stock',true)
 var tail=box(self,'DisplayFishTail',Vector3(-.565,1.063,1.21),Vector3(.065,.012,.09),fish);tail.rotation.y=PI/4
 mesh(fine,'FishEye',SphereMesh.new(),Vector3(-.33,1.084,1.21),Vector3(.012,.008,.012),iron)
 # Two baskets: retain the accepted right-hand basket and add its left partner.
 var basket=Node3D.new();basket.name='LeftIngredientBasket';basket.position=Vector3(-1.35,.98,1.21);add_child(basket)
 box(basket,'BasketBottom',Vector3(0,.018,0),Vector3(.36,.036,.27),wood)
 for side in [-1,1]:
  box(basket,'BasketSide',Vector3(0,.09,side*.126),Vector3(.36,.15,.018),wood)
  box(basket,'BasketEnd',Vector3(side*.171,.09,0),Vector3(.018,.15,.27),wood)
 box(basket,'Lining',Vector3(0,.04,0),Vector3(.32,.010,.23),cream)
 # One shallow preparation shelf and three jars are over the existing staff-side
 # rear shelving footprint. No props reach the central service target (x=0,z=1.2).
 box(self,'PrepShelf',Vector3(1.15,1.30,-.35),Vector3(.82,.045,.21),wood)
 box(self,'ShelfBracket',Vector3(1.50,1.16,-.35),Vector3(.045,.28,.045),wood)
 box(self,'ShelfBrace',Vector3(1.30,1.19,-.35),Vector3(.40,.045,.045),wood)
 for i in range(3):
  var p=Vector3(.89+i*.26,1.425,-.35)
  var jar=CylinderMesh.new();jar.top_radius=.068;jar.bottom_radius=.068;jar.height=.20;jar.radial_segments=12
  mesh(self,'PantryJar'+str(i),jar,p,Vector3.ONE,teal)
  var lid=CylinderMesh.new();lid.top_radius=.074;lid.bottom_radius=.074;lid.height=.026;lid.radial_segments=12
  mesh(self,'PantryLid'+str(i),lid,p+Vector3(0,.114,0),Vector3.ONE,wood)
  label('PantryLabel'+str(i),['HERBS','SALT','OIL'][i],p+Vector3(0,0,.070))
 # A shallow herb rail occupies the existing rear wall. It is not harvestable.
 box(self,'HerbRail',Vector3(-1.13,1.82,-.48),Vector3(.72,.055,.055),wood)
 for i in range(3):
  for j in range(3):
   var leaf=mesh(fine,'HangingHerb',SphereMesh.new(),Vector3(-1.37+i*.24+(j-1)*.04,1.68,-.44),Vector3(.055,.22,.045),green);leaf.rotation.z=(j-1)*.20
 # Towel lies along the board's back edge, outside the handover zone.
 box(self,'FoldedTowel',Vector3(-.82,1.005,1.10),Vector3(.22,.04,.18),cream)
 for i in range(3):box(fine,'TowelFold',Vector3(-.89+i*.06,1.027,1.10),Vector3(.007,.004,.16),wood)
 for n in find_children('*','GeometryInstance3D',true,false):
  n.visibility_range_end=38;n.visibility_range_end_margin=4
 set_meta('cooking_prep_contract',{'ids':['CK03','CK04'],'new_colliders':0,'new_lights':0,'station_position_changed':false,'center_clear':true,'pantry_display_only':true,'basket_count_total':2,'jars':3})
 set_quality(preload('res://scripts/game_settings.gd').new().current_material_detail_quality(self))
func set_quality(value:int):
 quality=clampi(value,0,3)
 if is_instance_valid(fine):fine.visible=quality>=2
 set_meta('effective_quality',quality)
