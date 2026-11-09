shader_type spatial;
render_mode cull_disabled;
// Opaque distant water avoids layered alpha sorting through dome. No emission/light.
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float bands=sin(world_pos.y*4.0+TIME*2.8)*0.045;
 ALBEDO=vec3(0.51,0.65,0.66)+bands;
 ROUGHNESS=0.88;
 SPECULAR=0.12;
}
