shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform bool falling = false;
varying vec3 local_pos;
void vertex() { local_pos=VERTEX; }
void fragment() {
 float t=TIME;
 float wave=sin(local_pos.x*16.0+t*1.3)*sin(local_pos.z*19.0-t*1.0);
 if(falling) {
  float streak=sin(local_pos.x*67.0+local_pos.z*61.0+sin(local_pos.y*9.0+t*5.0));
  float flow=sin(local_pos.y*37.0+t*9.0);
  ALBEDO=mix(vec3(0.07,0.28,0.29),vec3(0.48,0.67,0.64),smoothstep(0.1,1.0,streak)*0.7+flow*0.08);
  ALPHA=0.54+0.18*streak+0.06*flow;
  ROUGHNESS=0.20; METALLIC=0.05;
 } else {
  ALBEDO=mix(vec3(0.035,0.19,0.20),vec3(0.07,0.32,0.33),wave*0.25+0.5);
  NORMAL=normalize(NORMAL+vec3(sin(local_pos.x*13.0+t)*0.045,cos(local_pos.z*17.0-t)*0.045,0.0));
  ALPHA=1.0; ROUGHNESS=0.18; METALLIC=0.20;
 }
 SPECULAR=0.65;
}
