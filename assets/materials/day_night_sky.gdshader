shader_type sky;
#include "res://assets/materials/valley_celestials.gdshaderinc"
uniform vec3 sun_direction = vec3(0.0,1.0,0.0);
// Original cloud-bank layout retained; clearer spatial edges and restrained wisps.
// Lighting and rare meteor remain controlled by the unchanged active-play clock.
uniform vec3 zenith : source_color = vec3(0.24,0.40,0.58);
uniform vec3 horizon : source_color = vec3(0.76,0.77,0.73);
uniform float daylight : hint_range(0.0,1.0) = 1.0;
uniform float twilight : hint_range(0.0,1.0) = 0.0;
uniform float meteor_progress = -1.0;
float hash21(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
float clouds(vec2 p) {
 float n=0.0; float amplitude=0.57;
 for(int i=0;i<4;i++){ n+=noise2(p)*amplitude; p=mat2(vec2(1.65,1.2),vec2(-1.2,1.65))*p+7.1; amplitude*=0.46; }
 // Small zero-centred fine structure, without shifting the original bank coverage.
 n+=(noise2(p)-0.5)*0.022;
 return n;
}
void sky() {
 float y=max(EYEDIR.y,0.0);
 vec3 base=mix(horizon,zenith,pow(y,0.52));
 base=valley_celestials(EYEDIR,base,daylight,sun_direction);
 // Disc follows the real single directional light; never an independent second sun.
 float solar_angle=distance(EYEDIR,normalize(sun_direction));
 float solar_disc=1.0-smoothstep(0.010,0.013,solar_angle);
 float solar_glow=exp(-solar_angle*25.0)*0.16;
 base+=mix(vec3(1.0,0.77,0.42),vec3(1.0,0.35,0.11),twilight)*(solar_disc*1.4+solar_glow)*smoothstep(-0.025,0.025,EYEDIR.y);
 float celestial_clear=1.0-valley_body_mask(EYEDIR);
 vec2 p=EYEDIR.xz/(0.36+y)*5.2;
 float n=clouds(p*vec2(0.8,1.4));
 // Preserve the original density midpoint, but avoid a broad blurry transition.
 // Screen derivatives retain antialiasing as resolution/view direction changes.
 float edge=0.032+min(fwidth(n)*1.25,0.025);
 float mask=smoothstep(0.655-edge,0.655+edge,n)*smoothstep(0.02,0.13,y);
 mask*=1.0-smoothstep(0.65,0.98,y)*0.60;
 float w=noise2(p*vec2(1.0,2.0)+vec2(33.0,12.0));
 float wisps=smoothstep(0.73,0.92,w)*smoothstep(0.12,0.3,y)*(1.0-smoothstep(0.65,0.9,y))*0.07;
 vec3 cloud=mix(vec3(0.70,0.75,0.79),vec3(0.91,0.89,0.82),smoothstep(0.56,0.79,n));
 cloud *= mix(vec3(0.055,0.075,0.13),vec3(1.0),daylight);
 cloud += vec3(0.21,0.09,0.035)*twilight;
 vec3 result=mix(base,cloud,min(mask*0.85+wisps,0.9));
 // Fixed sparse star field, never tied to shader TIME, so test snapshots are repeatable.
 vec2 sp=EYEDIR.xz/(0.30+y)*135.0;
 vec2 cell=floor(sp);
 float star=(1.0-smoothstep(0.025,0.085,length(fract(sp)-vec2(0.5))));
 star*=step(0.989,hash21(cell))*smoothstep(0.08,0.35,y)*(1.0-daylight)*(1.0-mask);
 result+=vec3(0.56,0.64,0.80)*star*celestial_clear;
 if(meteor_progress>=0.0 && meteor_progress<=1.0){
  vec3 start=normalize(vec3(-0.45,0.63,-0.63));
  vec3 finish=normalize(vec3(0.36,0.42,-0.83));
  vec3 head=normalize(mix(start,finish,meteor_progress));
  float trail=0.0;
  for(int i=0;i<6;i++){
   float offset=float(i)*0.018;
   vec3 point=normalize(mix(start,finish,max(0.0,meteor_progress-offset)));
   trail=max(trail,(1.0-smoothstep(0.0015,0.0045,distance(EYEDIR,point)))*(1.0-float(i)/6.0));
  }
  result+=vec3(0.55,0.64,0.72)*trail*sin(meteor_progress*3.14159265)*(1.0-daylight)*(1.0-mask)*celestial_clear;
 }
 COLOR=result;
}
