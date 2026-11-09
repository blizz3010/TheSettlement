shader_type spatial;
render_mode cull_disabled;
uniform float wind_strength : hint_range(0.0,1.0) = 1.0;
uniform float phase_offset = 0.0;
uniform float study_time = -1.0;
varying float leaf_mask;
varying float palette;
varying float palette_weight;
mat3 rot_x(float a){float c=cos(a);float s=sin(a);return mat3(vec3(1,0,0),vec3(0,c,s),vec3(0,-s,c));}
mat3 rot_z(float a){float c=cos(a);float s=sin(a);return mat3(vec3(c,s,0),vec3(-s,c,0),vec3(0,0,1));}
void vertex(){
 leaf_mask=step(.5,UV2.y);palette=INSTANCE_CUSTOM.y;palette_weight=INSTANCE_CUSTOM.z;
 if(UV2.y>.5){
  vec3 hinge=vec3(UV.x,UV.y,UV2.x);
  if(UV2.y>1.5){VERTEX=hinge+(VERTEX-hinge)*palette_weight;}
  if(wind_strength>0.0){
   float t=study_time>=0.0?study_time:TIME;
   float phase=phase_offset+INSTANCE_CUSTOM.x+dot(hinge,vec3(1.71,.37,1.13));
   mat3 bend=rot_z(.008*sin(t*1.73+phase*1.39)*wind_strength)*rot_x(.016*sin(t*1.15+phase)*wind_strength);
   VERTEX=hinge+bend*(VERTEX-hinge);NORMAL=bend*NORMAL;
  }
 }
}
void fragment(){
 vec3 color=COLOR.rgb;
 if(leaf_mask>.5){
  float tone=clamp(COLOR.g*3.0,.35,1.0);
  vec3 leaf=color*vec3(1.08,1.20,.9);
  if(palette>.5&&palette<1.5){leaf=mix(leaf,vec3(.33,.28,.07)*tone,.52);}
  else if(palette>1.5&&palette<2.5){leaf=vec3(.36,.055,.10)*tone;}
  else if(palette>2.5){leaf=vec3(.55,.52,.35)*tone;}
  color=mix(color,leaf,palette_weight);
 }
 ALBEDO=color;ROUGHNESS=.86;
}
