shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Original analytic material. COLOR encodes the timber member's local long axis.
// No displacement, TIME, screen texture, UV rewrite or source-asset mutation.
uniform int kind = 1;
uniform vec4 tint : source_color = vec4(0.32,0.20,0.11,1.0);
uniform float roughness = 0.8;
uniform float metallic = 0.0;
varying vec3 local_position;
varying vec3 local_normal;
varying mat3 local_to_view_normal;
float hash31(vec3 p) {
 p = fract(p * 0.1031);
 p += dot(p, p.yzx + 33.33);
 return fract((p.x + p.y) * p.z);
}
vec4 grain(vec3 x) {
 vec3 p = floor(x), f = fract(x);
 vec3 u = f*f*(3.0-2.0*f), du = 6.0*f*(1.0-f);
 float a=hash31(p), b=hash31(p+vec3(1,0,0));
 float c=hash31(p+vec3(0,1,0)), d=hash31(p+vec3(1,1,0));
 float e=hash31(p+vec3(0,0,1)), f1=hash31(p+vec3(1,0,1));
 float g=hash31(p+vec3(0,1,1)), h=hash31(p+vec3(1,1,1));
 float k1=b-a, k2=c-a, k3=e-a, k4=a-b-c+d;
 float k5=a-c-e+g, k6=a-b-e+f1, k7=-a+b+c-d+e-f1-g+h;
 float value=a+k1*u.x+k2*u.y+k3*u.z+k4*u.x*u.y+k5*u.y*u.z+k6*u.x*u.z+k7*u.x*u.y*u.z;
 vec3 gradient=du*vec3(k1+k4*u.y+k6*u.z+k7*u.y*u.z,
 k2+k4*u.x+k5*u.z+k7*u.x*u.z,
 k3+k5*u.y+k6*u.x+k7*u.x*u.y);
 return vec4(value,gradient);
}
void vertex() {
 local_position=VERTEX;
 local_normal=NORMAL;
 local_to_view_normal=MODELVIEW_NORMAL_MATRIX;
}
vec3 grain_coordinates(vec3 p, vec3 axis) {
 if(axis.r>0.5) return p.yxz;
 if(axis.b>0.5) return p.xzy;
 return p;
}
vec3 undo_grain(vec3 p, vec3 axis) {
 if(axis.r>0.5) return p.yxz;
 if(axis.b>0.5) return p.xzy;
 return p;
}
void fragment() {
 vec3 p=local_position;
 vec3 n=normalize(local_normal);
 vec3 gradient;
 if(kind==1) {
  vec3 q=grain_coordinates(p, COLOR.rgb);
  vec4 broad=grain(q*vec3(8.0,0.65,8.0)+vec3(3.7,1.2,5.1));
  vec3 finepos=q*vec3(110.0,2.4,110.0)+vec3(broad.x*2.0,0.0,broad.x*2.0);
  vec4 fine=grain(finepos);
  float footprint=max(length(dFdx(finepos)),length(dFdy(finepos)));
  float near_weight=1.0-smoothstep(0.25,0.9,footprint);
  float tone=(broad.x-0.5)*0.44+(fine.x-0.5)*0.22*near_weight;
  ALBEDO=tint.rgb*(1.0+tone);
  ROUGHNESS=clamp(roughness+(fine.x-0.5)*0.1*near_weight,0.67,0.9);
  METALLIC=0.0;
  gradient=undo_grain(fine.yzw*vec3(1.0,0.06,1.0), COLOR.rgb)*0.065*near_weight;
 } else {
  vec4 broad=grain(p*5.0+vec3(4.3,2.7,6.2));
  vec3 finepos=p*42.0;
  vec4 fine=grain(finepos);
  float footprint=max(length(dFdx(finepos)),length(dFdy(finepos)));
  float near_weight=1.0-smoothstep(0.2,0.8,footprint);
  float oxidation=(kind==2 ? 0.34 : 0.07)*smoothstep(0.42,0.78,broad.x);
  vec3 base=tint.rgb*(1.0+(broad.x-0.5)*0.32+(fine.x-0.5)*0.14*near_weight);
  ALBEDO=mix(base,base*vec3(0.40,0.70,0.59),oxidation);
  METALLIC=metallic*(1.0-oxidation*0.5);
  ROUGHNESS=clamp(roughness+oxidation+(fine.x-0.5)*0.08*near_weight,0.35,0.88);
  gradient=fine.yzw*0.025*near_weight;
 }
 gradient-=n*dot(n,gradient);
 NORMAL=normalize(local_to_view_normal*(n-gradient));
}
