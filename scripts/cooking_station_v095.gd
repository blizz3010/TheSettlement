extends Node3D
signal opened
signal closed
const ShopPanel=preload("res://scripts/shop_panel.gd")
const Transaction=preload("res://scripts/shop_transaction.gd")
const Candidate=preload("res://scripts/cooking_candidate.gd")
const Catalog=preload("res://scripts/cooking_catalog.gd")
const Codec=preload("res://scripts/save_codec.gd")
var host_world
var panel
var actor:Node3D
var tray_visual:Node3D
var blocked_by_other_modal=false
var host_bound=false
var host_access:Callable
var own_collider:StaticBody3D
var service='craft'
var builder=Candidate.new()
var transaction=Transaction.new(builder.candidate)
var source:Dictionary={}
var disposing=false
func _ready():
 name="CampfireGriddle"
 build_visual()
 # The world HUD is created later on layer 1. Keep this modal and its scrim
 # explicitly above it, independent of sibling creation order.
 var canvas=CanvasLayer.new();canvas.layer=2;add_child(canvas)
 panel=ShopPanel.new();canvas.add_child(panel)
 panel.closed.connect(close_panel)
 panel.cancelled.connect(cancel)
 panel.review_requested.connect(review)
 panel.confirmed.connect(confirm)
 panel.tab_changed.connect(change_tab)
 panel.configure(Catalog.definition(service))
func snapshot()->Dictionary:
 return {'fishing':host_world.fishing.data(),'craft':host_world.craft.data(),'onboarding':host_world.onboarding.data()}
func active()->bool:
 return not disposing and is_instance_valid(host_world) and not host_world.is_queued_for_deletion() and host_world.world_initialized and not host_world.startup_cancel_requested
func vendor_access(who:Node3D)->bool:
 if not active() or not is_instance_valid(who):return false
 var p=who.global_position
 var target=Vector3(-5.8,1.3,2)
 if p.x < -5.7 or p.x > -3.1 or absf(p.z-2)>1.45 or absf(p.y)>0.6:return false
 var eye=p+Vector3(0,1.3,0)
 if eye.distance_to(target)>2.8:return false
 var ray=PhysicsRayQueryParameters3D.create(eye,target)
 if who is CollisionObject3D:ray.exclude=[who.get_rid()]
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func can_open(who:Node3D,mode:String='craft')->bool:
 if disposing or blocked_by_other_modal or not is_instance_valid(who) or not is_inside_tree() or not active():return false
 if host_bound and not host_access.is_valid():return false
 if host_access.is_valid() and not host_access.call():return false
 if not who.is_inside_tree() or who.is_queued_for_deletion():return false
 if mode=='vendor':return vendor_access(who)
 if who.global_position.distance_to(global_position)>1.8:return false
 var ray=PhysicsRayQueryParameters3D.create(who.global_position+Vector3(0,1.2,0),global_position+Vector3(0,.75,0))
 var excluded:Array[RID]=[]
 if who is CollisionObject3D:excluded.append(who.get_rid())
 if is_instance_valid(own_collider):excluded.append(own_collider.get_rid())
 ray.exclude=excluded
 return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func can_continue()->bool:
 return panel.visible and can_open(actor,service)
func try_open(who:Node3D)->bool:return open_service(who,'craft')
func try_open_vendor(who:Node3D)->bool:return open_service(who,'vendor')
func open_service(who:Node3D,mode:String)->bool:
 if panel.visible or not can_open(who,mode):return false
 service=mode;actor=who;transaction.cancel()
 panel.action='craft' if mode=='craft' else 'buy'
 panel.selected_item='';panel.search.text='';panel.quantity.value=1
 panel.configure(Catalog.definition(service));render();panel.show();panel.close_button.grab_focus();opened.emit();return true
func render(message:String=''):
 if not active():return
 source=transaction.source_snapshot(host_world.state,host_world.inventory,host_world.request,snapshot())
 panel.render_state(host_world.state,host_world.inventory,Catalog.rows(panel.action,host_world.inventory),transaction.pending_quote(),message)
func review(item:String,quantity:int,action:String):
 if not can_continue():close_panel();return
 if action!=panel.action:return
 var quote=transaction.select(Catalog.definition(service).shop_id,action,item,quantity,host_world.state,host_world.inventory,host_world.request,snapshot())
 render((builder.last_error if not builder.last_error.is_empty() else transaction.last_error) if quote.is_empty() else '')
 if not quote.is_empty():panel.cancel_button.grab_focus()
func confirm(writer_override=null)->bool:
 if not can_continue():close_panel();return false
 var quote=transaction.pending_quote()
 if quote.is_empty():return false
 var writer=func(candidate):return host_world.save_payload(Codec.encode(candidate.plot,candidate.inventory,candidate.request,host_world.craft,host_world.onboarding,host_world.fishing),false,writer_override)
 var next=transaction.confirm(quote.token,host_world.state,host_world.inventory,host_world.request,can_continue,writer,snapshot())
 if next.is_empty():render(transaction.last_error);return false
 host_world.state=next.plot;host_world.inventory=next.inventory;host_world.request=next.request
 preload("res://scripts/approved_settlement_audio.gd").emit_for(host_world,"item_pickup" if panel.action=="craft" else "confirm_buy")
 var result='Prepared %d griddle fish display sample%s · carried and saved. Cannot be eaten or sold.'%[quote.quantity,'' if quote.quantity==1 else 's'] if panel.action=='craft' else ('Bought' if panel.action=='buy' else 'Sold')+' %d river fish · saved locally.'%quote.quantity
 render(result);return true
func cancel():
 transaction.cancel();render('Cancelled. Ingredients, items and credits kept.')
func change_tab(_action:String):transaction.cancel();render()
func close_panel():
 transaction.cancel();source={}
 if not is_instance_valid(panel) or not panel.visible:return
 panel.hide();actor=null;closed.emit()
func _process(_delta:float):
 if not is_instance_valid(panel) or not panel.visible:return
 if not can_continue():close_panel();return
 if source!=transaction.source_snapshot(host_world.state,host_world.inventory,host_world.request,snapshot()):
  var had_quote=not transaction.pending_quote().is_empty();transaction.cancel()
  render('State changed. Review a new selection.' if had_quote else '')
func _unhandled_input(event:InputEvent):
 if is_instance_valid(panel) and panel.visible and event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_ESCAPE or event.keycode==KEY_ESCAPE):
  close_panel();get_viewport().set_input_as_handled()
func _exit_tree():
 disposing=true;transaction.cancel();actor=null

func material(color:Color) -> StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.9;return m
func part(mesh:Mesh,pos:Vector3,size:Vector3,color:Color,parent:Node3D=null) -> MeshInstance3D:
 var item=MeshInstance3D.new();item.mesh=mesh;item.position=pos;item.scale=size;item.material_override=material(color);(self if parent==null else parent).add_child(item);return item
func build_visual():
 # Same .9m footprint and existing session/collider; visuals only.
 var iron=Color("303638");var bronze=Color("8e714a");var wood=Color("73543b")
 var rim=CylinderMesh.new();rim.top_radius=.44;rim.bottom_radius=.42;rim.height=.10;rim.radial_segments=24
 part(rim,Vector3(0,.71,0),Vector3.ONE,iron)
 var cooktop=CylinderMesh.new();cooktop.top_radius=.385;cooktop.bottom_radius=.385;cooktop.height=.012;cooktop.radial_segments=24
 part(cooktop,Vector3(0,.767,0),Vector3.ONE,Color("192221"))
 for x in [-.29,.29]:
  for z in [-.29,.29]:
   part(BoxMesh.new(),Vector3(x,.34,z),Vector3(.075,.68,.075),iron)
   part(BoxMesh.new(),Vector3(x,.035,z),Vector3(.11,.07,.11),bronze)
 for z in [-.29,.29]:part(BoxMesh.new(),Vector3(0,.17,z),Vector3(.64,.055,.055),iron)
 part(BoxMesh.new(),Vector3(0,.17,0),Vector3(.60,.035,.53),wood)
 var box=CylinderMesh.new();box.top_radius=.30;box.bottom_radius=.24;box.height=.22;box.radial_segments=16
 part(box,Vector3(0,.55,0),Vector3.ONE,iron)
 for x in [-.14,0,.14]:
  var logmesh=CylinderMesh.new();logmesh.top_radius=.055;logmesh.bottom_radius=.055;logmesh.height=.40;logmesh.radial_segments=8
  var logpart=part(logmesh,Vector3(x,.245,0),Vector3.ONE,wood);logpart.rotation.x=PI/2
 part(BoxMesh.new(),Vector3(0,.57,.335),Vector3(.40,.15,.025),bronze)
 var sign=Label3D.new();sign.name="AttachedGriddlePlaque";sign.text="GRIDDLE";sign.position=Vector3(0,.57,.350);sign.font_size=28;sign.pixel_size=.0013;sign.modulate=Color("f0dfb6");sign.outline_size=2;add_child(sign)
 # Attached preparation detail stays within the existing .9m station footprint.
 part(BoxMesh.new(),Vector3(0,.43,-.335),Vector3(.48,.025,.025),bronze)
 for x in [-.16,.16]:
  part(BoxMesh.new(),Vector3(x,.35,-.355),Vector3(.018,.15,.018),wood)
  part(BoxMesh.new(),Vector3(x,.265,-.355),Vector3(.065,.045,.012),iron)
 part(BoxMesh.new(),Vector3(.19,.20,.09),Vector3(.17,.025,.24),Color("c5b99a"))
 # Compact shelter: supports remain inside the already blocked griddle cylinder.
 for x in [-.29,.29]:
  part(BoxMesh.new(),Vector3(x,1.51,-.29),Vector3(.055,1.64,.055),wood)
 part(BoxMesh.new(),Vector3(0,2.30,-.29),Vector3(.68,.14,.07),bronze)
 part(BoxMesh.new(),Vector3(0,2.39,0),Vector3(.98,.08,.96),wood)
 # Shallow canvas shelter above the unchanged timber frame. No new obstruction
 # below the existing 2.35 m canopy underside or outside its .98 x .96 footprint.
 var pitch=atan2(.16,.46)
 var panel_length=sqrt(.46*.46+.16*.16)
 for side in [-1,1]:
  var canvas=part(BoxMesh.new(),Vector3(side*.23,2.47,0),Vector3(panel_length,.025,.90),Color("c8b58e"))
  canvas.name="CanvasRoofLeft" if side<0 else "CanvasRoofRight"
  canvas.rotation.z=-side*pitch
 var ridge=part(BoxMesh.new(),Vector3(0,2.555,0),Vector3(.035,.025,.92),bronze)
 ridge.name="ShelterRidgeBinding"
 part(BoxMesh.new(),Vector3(0,2.31,.43),Vector3(.86,.14,.035),bronze)
 var cook_label=Label3D.new();cook_label.name="CookingCanopyLabel";cook_label.text="";cook_label.position=Vector3(0,2.31,.452);cook_label.font_size=40;cook_label.pixel_size=.0022;cook_label.modulate=Color("f5e8c8");cook_label.outline_size=2;add_child(cook_label)
 # Small shelf is below the cooktop and inside the same cylinder footprint.
 part(BoxMesh.new(),Vector3(0,.43,-.25),Vector3(.48,.035,.20),wood)
 tray_visual=Node3D.new();tray_visual.position=Vector3(0,.78,0);add_child(tray_visual)
