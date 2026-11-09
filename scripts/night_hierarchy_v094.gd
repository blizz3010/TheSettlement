extends Node
# Local practical hierarchy only. No environment, sun, clock or gameplay mutations.
var cycle:Node
var records:Array=[]
var last_daylight:float=-1.0
var result:Dictionary={}
static func apply(world:Node3D)->Dictionary:
 var existing=world.get_node_or_null('NightHierarchyV094')
 if existing!=null:return existing.result
 var controller=load('res://scripts/night_hierarchy_v094.gd').new()
 controller.name='NightHierarchyV094';world.add_child(controller)
 var outcome:Dictionary=controller.configure(world)
 if not outcome.get('ok',false):controller.queue_free()
 return outcome
func register(light:OmniLight3D,day:float,night:float,role:String):
 records.append({'node':light,'original_energy':light.light_energy,'day':day,'night':night,'role':role})
func practical(world:Node3D,label:String,position:Vector3,reach:float,night:float):
 var light=OmniLight3D.new();light.name=label;add_child(light)
 light.global_position=world.to_global(position);light.light_color=Color('#ffdaa4')
 light.omni_range=reach;light.omni_attenuation=1.3;light.shadow_enabled=false
 light.light_cull_mask=1 # Do not illuminate isolated inn interiors or Hall basement layer 4096.
 light.distance_fade_enabled=true;light.distance_fade_begin=26;light.distance_fade_length=10
 register(light,.10,night,'service');return light
func configure(world:Node3D)->Dictionary:
 cycle=world.get_node_or_null('DayNightCycle')
 if cycle==null:return {'ok':false,'reason':'Night hierarchy requires existing day/night controller'}
 for target in ['town_hall','TownHallLanternLights','MarketExpansion/PsyStand','MarketExpansion/AtlasStand','MarketExpansion/DanStand','RouteGardens']:
  if world.get_node_or_null(target)==null:return {'ok':false,'reason':'Night hierarchy missing '+target}
 # Add light at existing imported lantern cores, not floating fill lights.
 practical(world,'Reception lantern illumination',Vector3(3.4,1.65,-19),4.8,1.05)
 practical(world,'Plot desk lantern illumination',Vector3(4.3,1.65,-28),4.2,.85)
 for spec in [['Psy',8.0,7.0,2.7],['Atlas',7.0,8.0,2.35],['Dan',10.0,7.0,2.7]]:
  var shop=world.get_node('MarketExpansion/'+spec[0]+'Stand') as Node3D
  for side in [-1,1]:
   var local=Vector3(side*(float(spec[1])*.5-.7),float(spec[3]),float(spec[2])*.5-.7)
   var light=practical(world,spec[0]+' lantern '+str(side),world.to_local(shop.to_global(local)),float(spec[1])*.5+1.0,1.0)
   light.set_meta('authored_fixture_local',local)
 var ring_count=0;var route_count=0;var hall_count=0
 for n in world.get_children():
  if n is OmniLight3D and is_equal_approx(n.light_energy,1.5) and is_equal_approx(n.omni_range,3.0) and n.light_color.is_equal_approx(Color('#ffbc62')):
   register(n,.08,.55,'decorative_bed');ring_count+=1
 for n in world.get_node('RouteGardens').find_children('*','OmniLight3D',true,false):
  if n.name=='Warm practical' and is_equal_approx(n.omni_range,4.2) and n.light_color.is_equal_approx(Color('#ffd39a')):
   register(n,.12,.65,'route');route_count+=1
 for n in world.get_node('TownHallLanternLights').get_children():
  if n is OmniLight3D and is_equal_approx(n.position.z,-17.0):
   register(n,.35,1.05,'hall_entry');hall_count+=1
 if ring_count!=7 or route_count!=4 or hall_count!=2:
  # Exact authored identities must match before committing any existing energy changes.
  return {'ok':false,'reason':'Night hierarchy fixture identity changed','ring':ring_count,'route':route_count,'hall':hall_count}
 var garden_count=0
 if 'plaza_island_landscape' in world:
  var landscape=world.get('plaza_island_landscape')
  if landscape==null or not is_instance_valid(landscape.visual):return {'ok':false,'reason':'Authored garden lighting owner missing'}
  for light in landscape.visual.find_children('*','OmniLight3D',true,false):
   if str(landscape.visual.get_path_to(light)).begins_with('ShipRampGarden/'):continue
   register(light,light.light_energy*.15,light.light_energy,'garden_daylight');garden_count+=1
  if garden_count!=46:return {'ok':false,'reason':'Authored garden lighting count changed','garden_lights':garden_count}
 result={'garden_daylight_practicals':garden_count,'ok':true,'new_lights':8,'new_shadow_maps':0,'ring_beds':ring_count,'route_practicals':route_count,'entry_practicals':hall_count,'global_environment_changed':false,'clock_changed':false}
 update_lighting(true);set_meta('night_hierarchy_v094',result)
 return result
func update_lighting(force:bool=false):
 if not is_instance_valid(cycle):return
 var daylight:float=cycle.sample(cycle.elapsed_seconds/cycle.cycle_seconds).daylight
 if not force and absf(daylight-last_daylight)<.001:return
 last_daylight=daylight
 for row in records:
  if is_instance_valid(row.node):row.node.light_energy=lerpf(row.night,row.day,daylight)
func _process(_delta:float):update_lighting()
func _exit_tree():
 # Removing this optional finish while keeping the world alive restores prior practicals.
 for row in records:
  if is_instance_valid(row.node) and not is_ancestor_of(row.node):row.node.light_energy=row.original_energy
