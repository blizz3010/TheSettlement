extends RefCounted
# Camera and overlays use the identical square world rectangle. No player camera copy.
static func setup(viewport:SubViewport,snapshot:Node3D,bounds:Rect2)->Camera3D:
 viewport.disable_3d=false;viewport.own_world_3d=true
 viewport.transparent_bg=false;viewport.msaa_3d=Viewport.MSAA_2X
 viewport.add_child(snapshot)
 var env=WorldEnvironment.new();var environment=Environment.new()
 environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("314b39")
 environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("fff4dd");environment.ambient_light_energy=.75
 environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.environment=environment;snapshot.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-65,-25,0);sun.light_color=Color("fff2d7");sun.light_energy=.8;sun.shadow_enabled=true;sun.directional_shadow_max_distance=250;snapshot.add_child(sun)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.size=bounds.size.y;camera.near=.1;camera.far=400
 camera.position=Vector3(bounds.get_center().x,150,bounds.get_center().y);camera.rotation.x=-PI/2
 snapshot.add_child(camera);camera.current=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
 return camera
