extends RefCounted
# One-shot additions, installed before the loading gate releases the player.
static func material(hex:String,emission:bool=false)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=Color(hex);m.roughness=.85
 if emission:m.emission_enabled=true;m.emission=Color(hex);m.emission_energy_multiplier=.8
 return m
static func box(parent:Node3D,label:String,p:Vector3,s:Vector3,m:Material):
 var n=MeshInstance3D.new();n.name=label;n.position=p;var b=BoxMesh.new();b.size=s;n.mesh=b;n.material_override=m;parent.add_child(n);return n
static func apply(world:Node3D)->Dictionary:
 if world.has_meta('approved_gardens_v086'):return world.get_meta('approved_gardens_v086')
 var controller=world.get('plaza_island_landscape')
 if controller==null or not is_instance_valid(controller.visual):return {'ok':false,'reason':'Landscape not ready'}
 var source=controller.visual.get_node_or_null('ShipRampGarden')
 if source==null:return {'ok':false,'reason':'Approved platform light source missing'}
 var source_lights=[]
 for lamp in source.get_children():
  if str(lamp.name).begins_with('PlatformWallLight'):source_lights.append(lamp)
 if source_lights.size()!=4:return {'ok':false,'reason':'Expected four platform wall light fixtures'}
 var packed=load('res://assets/approved_gardens_v086.scn') as PackedScene
 if packed==null:return {'ok':false,'reason':'Approved garden bake missing'}
 var garden=packed.instantiate();controller.visual.add_child(garden)
 var lights=0
 # Match the already approved south-side fixtures exactly on the north side.
 if source!=null:
  for lamp in source_lights:
   var copied=lamp.duplicate() as Node3D
   copied.name='North'+str(lamp.name);source.add_child(copied)
   var old=lamp.global_position;var delta=old-Vector3(22,0,-16)
   copied.global_position=Vector3(old.x,old.y,-32-old.z)
   copied.global_basis=Basis(Vector3.UP,2*atan2(delta.z,delta.x))*lamp.global_basis
   lights+=1
 var result={'ok':true,'planting':garden.get_meta('approved_gardens_manifest',{}),'matched_north_platform_lights':lights,'inn_facade_details':false,'no_save_changes':true}
 world.set_meta('approved_gardens_v086',result);print('APPROVED_GARDENS_V086_READY ',result);return result
