extends Node3D
# T01/T02: bounded stall-only visual owner. Never owns collision, stock or actors.
const Art=preload("res://scripts/market_review_finish.gd")
const Signs=preload("res://scripts/market_signage.gd")
const Settings=preload("res://scripts/game_settings.gd")
var medium:Node3D
var high:Node3D
var ultra:Node3D
var quality:int=2

static func install(stall:Node3D,medium_group:Node3D,high_group:Node3D):
 if stall.has_node("TailorFrontageQuality"):return stall.get_node("TailorFrontageQuality")
 var owner=load("res://scripts/tailor_frontage_v097.gd").new()
 owner.name="TailorFrontageQuality";owner.medium=medium_group;owner.high=high_group
 stall.add_child(owner)
 owner.build(stall)
 owner.add_to_group("material_detail_quality")
 owner.set_quality(Settings.new().current_material_detail_quality(stall))
 return owner

func build(stall:Node3D):
 var m=Art.palette();var indigo=Art.material("#455478");var cream=m.linen
 indigo.cull_mode=BaseMaterial3D.CULL_DISABLED
 # Remove only two old noncolliding visual slabs, keeping the established posts.
 for path in ["Indigo canvas awning","Low scalloped valance"]:
  var old=stall.get_node(path)
  assert(old.find_children("*","CollisionShape3D",true,false).is_empty())
  old.free()
 var essentials=Art.group(self,"EssentialFrontage")
 # Six low-poly cloth bays. Raised rear edge and a slight center sag, not simulation.
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 6:
  var x0=-2.4+i*.8;var x1=x0+.8
  var a=Vector3(x0,3.12,-2.05);var b=Vector3(x1,3.12,-2.05)
  var c=Vector3(x0,2.94,2.45);var d=Vector3(x1,2.94,2.45)
  var center=Vector3((x0+x1)/2,2.94,.20)
  for tri in [[a,center,b],[b,center,d],[d,center,c],[c,center,a]]:
   for v in tri:st.add_vertex(v)
 st.generate_normals()
 var canopy=MeshInstance3D.new();canopy.name="Pitched indigo cloth canopy";canopy.mesh=st.commit();canopy.material_override=indigo;essentials.add_child(canopy)
 # Six restrained scallops with an actual bound hem. All above the customer view.
 for i in 6:
  var x=-2.0+i*.8
  var hem=Signs.profile(essentials,"Finished canvas valance",[Vector2(-.40,.08),Vector2(.40,.08),Vector2(.40,-.08),Vector2(.24,-.14),Vector2(-.24,-.14),Vector2(-.40,-.08)],.025,indigo)
  hem.position=Vector3(x,2.86,2.43)
  Art.beam(essentials,"Cream bound hem",Vector3(x-.24,2.72,2.45),Vector3(x+.24,2.72,2.45),.018,cream)
 for x in [-2.30,2.30]:
  Art.beam(essentials,"Awning timber support",Vector3(x,2.84,2.10),Vector3(x,3.11,-2.10),.075,m.wood)
  Art.beam(essentials,"Canvas corner tie",Vector3(x,2.86,2.10),Vector3(x,2.94,2.43),.025,m.bronze)
 # Existing sign name stays stable for interaction/acceptance inspectors.
 var sign=stall.get_node("TailorIdentitySign")
 sign.font=preload("res://assets/fonts/DejaVuSerif.ttf");sign.font_size=40;sign.pixel_size=.0047;sign.outline_size=2
 for y in [2.25,2.71]:Art.box(essentials,"Sign oiled timber frame",Vector3(0,y,2.235),Vector3(2.82,.065,.10),m.wood)
 for x in [-1.39,1.39]:Art.box(essentials,"Sign brass binding",Vector3(x,2.48,2.29),Vector3(.055,.48,.035),m.bronze)
 for x in [-1.05,1.05]:Art.box(essentials,"Sign suspension",Vector3(x,2.75,2.21),Vector3(.045,.16,.05),m.bronze)
 Art.beam(essentials,"Spool emblem needle",Vector3(-2.10,2.19,2.43),Vector3(-1.57,2.78,2.43),.027,m.bronze)
 # Oiled counter edge and a quiet contrasting inset; no new countertop obstacles.
 Art.box(essentials,"Counter timber nosing",Vector3(.55,1.12,1.205),Vector3(2.32,.07,.035),m.wood)
 Art.box(essentials,"Counter indigo inset",Vector3(.55,.66,1.15),Vector3(1.80,.58,.035),indigo)
 # Frame the exposed panel; swatches sit against its exterior, not in the entry.
 for x in [-2.39,2.39]:
  for y in [.30,2.55]:Art.box(essentials,"Side panel cross rail",Vector3(x,y,-.25),Vector3(.05,.07,3.70),m.bronze)
 Art.box(essentials,"Exterior sample rail",Vector3(-2.41,1.76,.35),Vector3(.07,.07,1.32),m.wood)
 for i in 3:Art.box(essentials,"Large woven sample",Vector3(-2.425,1.46,-.10+i*.45),Vector3(.025,.52,.32),[cream,indigo,m.teal][i])
 # Hero half-form is always retained, away from the actor and clear center sightline.
 Art.box(essentials,"Hero indigo waistcoat",Vector3(0,1.43,-1.19),Vector3(.49,.62,.045),indigo)
 for side in [-1,1]:
  Art.beam(essentials,"Hero cream lapel",Vector3(side*.18,1.76,-1.15),Vector3(side*.055,1.43,-1.15),.055,cream)
  Art.box(essentials,"Hero shoulder",Vector3(side*.29,1.70,-1.35),Vector3(.20,.13,.27),indigo)
 # Permanent folded cloth cue on the cutting table, never the customer counter.
 for i in 3:Art.box(essentials,"Folded cloth stack",Vector3(-1.35,1.27+i*.065,-.43),Vector3(.64,.06,.43),[indigo,cream,m.teal][i])
 # A small always-present pair of color pots sits beside the basin on its tray.
 for i in 2:
  var p=Vector3(1.25+i*.22,.30,-1.52)
  Art.box(essentials,"Dye sample pot",p,Vector3(.16,.22,.16),[indigo,m.rust][i])
  Art.box(essentials,"Dye sample lid",p+Vector3(0,.12,0),Vector3(.17,.025,.17),m.bronze)
 # Physical work fixture attached to the front crossbar; actual local illumination.
 Art.box(essentials,"Lamp support crossbar",Vector3(0,2.91,1.28),Vector3(4.6,.07,.07),m.wood)
 Art.beam(essentials,"Lamp stem",Vector3(.45,2.91,1.28),Vector3(.45,2.57,1.28),.035,m.bronze)
 var glow=Art.material("#ffd99a");glow.emission_enabled=true;glow.emission=Color("#ffcf8a");glow.emission_energy_multiplier=.45
 Art.box(essentials,"Work lamp warm glass",Vector3(.45,2.52,1.28),Vector3(.20,.16,.20),glow)
 Art.box(essentials,"Work lamp hood",Vector3(.45,2.62,1.28),Vector3(.31,.045,.31),m.bronze)
 var light=OmniLight3D.new();light.name="EssentialWarmWorkLight";light.position=Vector3(.45,2.46,1.50);light.light_color=Color("#ffdcaa");light.light_energy=1.25;light.omni_range=4.8;light.omni_attenuation=1.3;light.shadow_enabled=false
 add_child(light)
 ultra=Art.group(self,"TailorUltraDetails")
 # Fine stitches only at Ultra; a bounded distance removes tiny geometry far away.
 for i in 10:Art.box(ultra,"Waistcoat stitch",Vector3(-.19+i*.042,1.19,-1.16),Vector3(.018,.012,.009),cream)
 for i in 7:Art.box(high,"Counter joinery pin",Vector3(-.30+i*.28,1.125,1.23),Vector3(.025,.025,.012),m.bronze)
 # Material-local batches, no actor or collision traversal and no world-wide merge.
 for group in [essentials,medium,high,ultra]:
  preload("res://scripts/rook_shop_art.gd").batch_static(group)
  for mesh in group.find_children("*","MeshInstance3D",true,false):
   mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   if group==ultra:mesh.visibility_range_end=14.0;mesh.visibility_range_end_margin=2.0
 set_meta("scope",{"ids":["T01","T02"],"added_colliders":0,"added_lights":1,"shadows":false,"static_batches_only":true})

func set_quality(value:int):
 quality=clampi(value,0,3)
 medium.visible=quality>=1;high.visible=quality>=2;ultra.visible=quality>=3
 set_meta("quality",quality)

func geometry_counts()->Dictionary:
 # Geometry count, not renderer draw calls: headless cannot establish GPU submission.
 var count=0;var surfaces=0;var triangles=0
 for node in get_parent().find_children("*","MeshInstance3D",true,false):
  if node.mesh==null or not node.is_visible_in_tree():continue
  count+=1;surfaces+=node.mesh.get_surface_count();triangles+=node.mesh.get_faces().size()/3
 return {"quality":quality,"visible_mesh_nodes":count,"visible_mesh_surfaces":surfaces,"visible_mesh_triangles":triangles,"native_draw_calls_measured":false}
