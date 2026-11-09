extends Node
## Cosmetic active-play lighting only. No wall-clock, save, economy or weather state.
const DEFAULT_CYCLE_SECONDS := 24.0 * 60.0
const METEOR_SECONDS := 1.5
var cycle_seconds:float = DEFAULT_CYCLE_SECONDS
var elapsed_seconds:float = 0.0
var environment:Environment
var sun:DirectionalLight3D
var sky_material:ShaderMaterial
var original_environment:Environment
var original_sun:Dictionary

static func add_to(scene:Node3D, duration:float = DEFAULT_CYCLE_SECONDS)->Node:
 assert(not scene.has_node('DayNightCycle'))
 var env_node:WorldEnvironment
 var sun_node:DirectionalLight3D
 for child in scene.get_children():
  if child is WorldEnvironment:env_node=child
  if child is DirectionalLight3D and sun_node==null:sun_node=child
 assert(env_node!=null and env_node.environment!=null and sun_node!=null,'Day/night needs existing world sky and sun')
 var controller=load('res://scripts/day_night_cycle.gd').new()
 controller.name='DayNightCycle'
 controller.cycle_seconds=maxf(duration,60.0)
 controller.original_environment=env_node.environment
 controller.environment=env_node.environment.duplicate(false)
 controller.sun=sun_node
 controller.original_sun={'rotation':sun_node.rotation,'color':sun_node.light_color,'energy':sun_node.light_energy}
 controller.sky_material=ShaderMaterial.new()
 controller.sky_material.shader=load('res://assets/materials/day_night_sky.gdshader')
 var sky=Sky.new();sky.sky_material=controller.sky_material
 controller.environment.sky=sky
 env_node.environment=controller.environment
 scene.add_child(controller)
 controller.apply_lighting()
 return controller

static func sample(phase:float)->Dictionary:
 var p=fposmod(phase,1.0)
 var elevation=cos(p*TAU)
 var daylight=smoothstep(-0.16,0.32,elevation)
 var twilight=(1.0-smoothstep(0.02,0.36,absf(elevation)))
 # Approved 004: readable near-neutral day, warm shoulder before twilight.
 # Same clock, illumination energies, local lamps, night and meteor timing.
 var golden=(1.0-smoothstep(0.18,0.62,elevation))*smoothstep(-0.10,0.20,elevation)
 var sunlight=Color('fff6ed').lerp(Color('ffc77f'),golden*.80).lerp(Color('ff8242'),twilight*.50)
 return {'phase':p,'elevation':elevation,'daylight':daylight,'twilight':twilight,'golden_hour':golden,'sun_color':sunlight,
  'zenith':Color(0.018,0.029,0.065).lerp(Color(0.24,0.40,0.58),daylight),
  'horizon':Color(0.055,0.078,0.13).lerp(Color(0.76,0.77,0.73),daylight).lerp(Color(0.55,0.25,0.13),twilight*0.48).lerp(Color(0.83,0.69,0.53),golden*0.20),
  'ambient':Color(0.40,0.48,0.65).lerp(Color('bfd7df'),daylight),
  'ambient_energy':lerpf(0.24,0.32,daylight),'sun_energy':0.78*daylight}

func meteor_progress()->float:
 # One subtle event in every third night, not a constant shower or a random save effect.
 var night_index=int(floor(elapsed_seconds/cycle_seconds))
 if night_index%3!=0:return -1.0
 var offset=fposmod(elapsed_seconds,cycle_seconds)-cycle_seconds*0.53
 if offset<0.0 or offset>METEOR_SECONDS:return -1.0
 return offset/METEOR_SECONDS

func _process(delta:float)->void:
 advance(delta)

func advance(seconds:float)->void:
 if not is_finite(seconds) or seconds<0.0:return
 elapsed_seconds+=seconds
 apply_lighting()

func apply_lighting()->void:
 if environment==null or sun==null:return
 var state=sample(elapsed_seconds/cycle_seconds)
 environment.ambient_light_color=state.ambient
 environment.ambient_light_energy=state.ambient_energy
 sun.light_energy=state.sun_energy
 sun.light_color=state.sun_color
 # Original midday direction retained; continuous rotation reaches the horizon at dusk/dawn.
 sun.rotation=Vector3(original_sun.rotation.x*cos(state.phase*TAU),original_sun.rotation.y+state.phase*TAU,0.0)
 sky_material.set_shader_parameter('sun_direction',sun.global_basis.z.normalized())
 sky_material.set_shader_parameter('zenith',Vector3(state.zenith.r,state.zenith.g,state.zenith.b))
 sky_material.set_shader_parameter('horizon',Vector3(state.horizon.r,state.horizon.g,state.horizon.b))
 sky_material.set_shader_parameter('daylight',state.daylight)
 sky_material.set_shader_parameter('twilight',state.twilight)
 sky_material.set_shader_parameter('meteor_progress',meteor_progress())
