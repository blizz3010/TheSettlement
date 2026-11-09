shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
// Hall-only surface overrides. The source geometry, wall tint and roof exterior stay intact.
uniform vec4 original_tint : source_color = vec4(0.68,0.65,0.575,1.0);
uniform float original_roughness = 0.85;
uniform float original_metallic = 0.0;
uniform int finish_kind = 0;
uniform vec4 stone_tint : source_color = vec4(0.59,0.567,0.511,1.0);
uniform vec4 ceiling_tint : source_color = vec4(0.39,0.315,0.235,1.0);
varying vec3 finish_world;
varying vec3 finish_normal;
void vertex(){
 finish_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 finish_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);
}
void fragment(){
 vec3 tint=original_tint.rgb;
 float roughness=original_roughness;
 float metal=original_metallic;
 if(finish_kind==0 && finish_world.y<0.246 && finish_world.y>0.19){
  float soft=sin(finish_world.x*2.3+finish_world.z*1.7)*sin(finish_world.z*3.1)*0.008;
  tint=stone_tint.rgb+vec3(soft);roughness=0.87;metal=0.0;
 }
 if(finish_kind==1 && finish_world.y>5.8 && finish_normal.y< -0.15){
  float grain=sin(finish_world.z*16.0+sin(finish_world.x*4.0)*0.30)*0.015;
  float seam=1.0-smoothstep(0.008,0.018,abs(fract(finish_world.x*2.5)-0.5));
  tint=ceiling_tint.rgb*(1.0+grain-seam*0.07);roughness=0.88;metal=0.0;
 }
 ALBEDO=tint;ROUGHNESS=roughness;METALLIC=metal;
}
