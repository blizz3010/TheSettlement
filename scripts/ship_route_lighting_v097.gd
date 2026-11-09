extends Node3D
# V96-06 / S02 reference-driven night successor. Real local illumination; never modifies global light,
# source art, physics, vegetation, saves or another practical's energy.
const Home=preload('res://scripts/home_finish_v094.gd')
const Cycle=preload('res://scripts/day_night_cycle.gd')
const EXTERIOR_LAYER=1 << 18
var exterior_bindings:Array=[]
var cycle:Node
var lights:Array[Light3D]=[]
var night_energies:Array[float]=[]
var last_daylight:float=-1.0
static func apply(pad:Node3D)->Dictionary:
 if not is_instance_valid(pad):return {'ok':false,'reason':'Missing ship'}
 if pad.has_node('ShipRouteLightingV097'):return readiness(pad)
 var world=pad.get_parent()
 if world==null or not world.has_node('DayNightCycle'):return {'ok':false,'reason':'Missing day/night owner'}
 var clock=world.get_node('DayNightCycle')
 if clock.get_script()!=Cycle:return {'ok':false,'reason':'Unexpected day/night owner'}
 if not pad.has_node('Art') or not pad.has_node('Collision/ApproachStub'):return {'ok':false,'reason':'Missing ship art or supported approach'}
 var owner=load('res://scripts/ship_route_lighting_v097.gd').new()
 owner.name='ShipRouteLightingV097';owner.cycle=clock
 owner.build()
 pad.add_child(owner)
 owner.bind_exteriors(pad)
 owner.update_lighting(true)
 var result=readiness(pad)
 pad.set_meta('ship_route_lighting_v097',result)
 return result
static func readiness(pad:Node3D)->Dictionary:
 if not is_instance_valid(pad):return {'ok':false,'reason':'Missing ship'}
 var owner=pad.get_node_or_null('ShipRouteLightingV097')
 if owner==null or owner.get_script()!=load('res://scripts/ship_route_lighting_v097.gd'):return {'ok':false,'reason':'Route lighting owner missing'}
 if owner.lights.size()!=4 or not is_instance_valid(owner.cycle):return {'ok':false,'reason':'Route lighting plan incomplete'}
 for light in owner.lights:
  if not is_instance_valid(light) or not light.visible or light.shadow_enabled or light.light_cull_mask!=EXTERIOR_LAYER:return {'ok':false,'reason':'Essential light unavailable'}
 if owner.exterior_bindings.is_empty():return {'ok':false,'reason':'Exterior light receivers missing'}
 for row in owner.exterior_bindings:
  if not is_instance_valid(row.node) or (row.node.layers & EXTERIOR_LAYER)==0:return {'ok':false,'reason':'Exterior receiver binding changed'}
 return {'ok':true,'new_lights':4,'shadow_maps':0,'quality_independent':true,'new_colliders':0,'global_environment_changed':false,'scope':'V96-06 broad hull/gear/pad illumination; native matched night acceptance outstanding','exterior_only_layer':EXTERIOR_LAYER}
func fixture(label:String,p:Vector3,size:Vector3,material:Material):
 Home.box(self,label,p,size,material)
func build():
 var metal=StandardMaterial3D.new();metal.albedo_color=Color('#384743');metal.metallic=.35;metal.roughness=.8
 var warm=StandardMaterial3D.new();warm.albedo_color=Color('#ffd4a0');warm.emission_enabled=true;warm.emission=Color('#ffd4a0');warm.emission_energy_multiplier=.6
 var cool=warm.duplicate();cool.albedo_color=Color('#c9dfe9');cool.emission=Color('#c9dfe9')
 # A cool wash reveals the major near hull plane. The softer warm service
 # pool reveals both landing contacts and the full pad instead of tiny bulbs.
 fixture('Ramp entry bollard',Vector3(1.76,.78,12.7),Vector3(.16,1.5,.16),metal)
 fixture('Warm entry lens',Vector3(1.76,1.54,12.7),Vector3(.19,.12,.19),warm)
 var entry=OmniLight3D.new();entry.name='Warm ramp entry';entry.position=Vector3(1.76,1.64,12.7);entry.light_color=Color('#ffdbac');entry.omni_range=9.0;entry.omni_attenuation=1.1
 add_child(entry);lights.append(entry);night_energies.append(1.25)
 var cool_at=Vector3(-5.65,4.6,3.6)
 fixture('Hull wash mast',Vector3(cool_at.x,2.89,cool_at.z),Vector3(.12,3.22,.12),metal)
 fixture('Hull wash housing',cool_at,Vector3(.42,.22,.24),metal)
 fixture('Hull wash lens',cool_at+Vector3(.06,-.06,-.13),Vector3(.30,.10,.04),cool)
 var wash=SpotLight3D.new();wash.name='Broad cool hull wash';wash.position=cool_at
 wash.basis=Basis.looking_at(Vector3(0,3.2,0)-cool_at,Vector3.UP)
 wash.light_color=Color('#d0e3ed');wash.spot_range=14;wash.spot_angle=72;wash.spot_attenuation=1.0;wash.spot_angle_attenuation=1.0
 add_child(wash);lights.append(wash);night_energies.append(2.5)
 var service_at=Vector3(5.65,3.2,-1.5)
 fixture('Service pool mast',Vector3(service_at.x,2.19,service_at.z),Vector3(.12,1.82,.12),metal)
 fixture('Service pool housing',service_at,Vector3(.34,.22,.34),metal)
 fixture('Service pool lens',service_at+Vector3(0,-.13,0),Vector3(.26,.10,.26),warm)
 var service=OmniLight3D.new();service.name='Warm gear and pad pool';service.position=service_at;service.light_color=Color('#ffdfb5');service.omni_range=12;service.omni_attenuation=1.0
 add_child(service);lights.append(service);night_energies.append(1.3)
 # The old entry light ended before the town-side connector. One modest pool
 # bridges that dark break; the light stays outside the 3.2m walking envelope.
 fixture('Approach bollard',Vector3(1.76,.82,23),Vector3(.14,1.58,.14),metal)
 fixture('Approach lens',Vector3(1.76,1.66,23),Vector3(.18,.10,.18),warm)
 var route=OmniLight3D.new();route.name='Town-side route pool';route.position=Vector3(1.76,1.73,23);route.light_color=Color('#ffdbac');route.omni_range=8;route.omni_attenuation=1.1
 add_child(route);lights.append(route);night_energies.append(.85)
 # Flush guidance stays on the ramp's existing side rails, not the walking lane.
 for side in [-1,1]:
  for z in [8.4,10.4,12.4]:
   var y=1.28+(z-7.4)/6.4*(.025-1.28)
   fixture('Low ramp edge guidance',Vector3(side*1.56,y+.12,z),Vector3(.045,.075,.34),warm)
 for light in lights:
  light.shadow_enabled=false;light.light_cull_mask=EXTERIOR_LAYER;light.distance_fade_enabled=false;light.light_energy=0
func update_lighting(force:bool=false):
 if not is_instance_valid(cycle):return
 var daylight:float=Cycle.sample(cycle.elapsed_seconds/cycle.cycle_seconds).daylight
 if not force and absf(daylight-last_daylight)<.001:return
 last_daylight=daylight
 for i in lights.size():lights[i].light_energy=lerpf(night_energies[i],0.0,daylight)
func _process(_delta:float):update_lighting()

func bind_exteriors(pad:Node3D):
 # Add one reserved light-receiver bit, leaving all prior visibility bits intact.
 # Adjacent shops, interiors, sky and distant vegetation never receive this wash.
 var roots=[pad]
 for name in ['LaunchpadApproach','ApproachPathFinish']:
  var node=pad.get_parent().get_node_or_null(name)
  if node!=null:roots.append(node)
 for owner in roots:
  for node in owner.find_children('*','GeometryInstance3D',true,false):
   exterior_bindings.append({'node':node,'layers':node.layers})
   node.layers|=EXTERIOR_LAYER
func _exit_tree():
 for row in exterior_bindings:
  if is_instance_valid(row.node) and row.node.layers==(row.layers | EXTERIOR_LAYER):row.node.layers=row.layers
