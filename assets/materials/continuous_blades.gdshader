shader_type spatial;
render_mode cull_disabled, diffuse_burley;
varying float blade_height;
void vertex() {
 vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
 float distance_to_camera=distance(CAMERA_POSITION_WORLD.xz,origin.xz);
 float keep=1.0-smoothstep(16.0,24.0,distance_to_camera);
 blade_height=clamp(VERTEX.y/.105,0.0,1.0);
 VERTEX.y*=keep;
}
void fragment() {
 ALBEDO=COLOR.rgb*mix(.94,1.08,blade_height);
 ROUGHNESS=1.0; SPECULAR=.04;
}
