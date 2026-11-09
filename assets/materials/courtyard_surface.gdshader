shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Two analytic-gradient noise evaluations, no textures or screen reads.
// World scale in meters. Intended for selected limestone/bronze surfaces only.
uniform vec4 tint : source_color = vec4(0.48, 0.44, 0.36, 1.0);
uniform float metallic : hint_range(0.0,1.0) = 0.0;
uniform float roughness : hint_range(0.0,1.0) = 0.78;
uniform float variation : hint_range(0.0,1.0) = 0.26;
uniform float grain_scale : hint_range(1.0,80.0) = 20.0;
uniform float bump_strength : hint_range(0.0,0.5) = 0.055;
uniform float patina : hint_range(0.0,1.0) = 0.0;
varying vec3 material_world_position;
varying vec3 material_world_normal;

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
 material_world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 material_world_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);
}
void fragment() {
 vec4 fine=grain(material_world_position*grain_scale);
 vec4 broad=grain(material_world_position*2.1+vec3(4.3,7.1,2.9));
 float footprint=max(length(dFdx(material_world_position*grain_scale)),length(dFdy(material_world_position*grain_scale)));
 float fine_weight=1.0-smoothstep(0.20,0.70,footprint);
 float mottling=(fine.x-0.5)*0.45*fine_weight+(broad.x-0.5)*0.8;
 vec3 base=tint.rgb*(1.0+variation*mottling);
 float oxidation=patina*smoothstep(0.52,0.76,broad.x);
 ALBEDO=mix(base,base*vec3(0.36,0.72,0.65),oxidation);
 METALLIC=metallic*(1.0-oxidation*0.55);
 ROUGHNESS=clamp(roughness+(fine.x-0.5)*0.17+oxidation*0.12,0.22,0.96);
 vec3 n=normalize(material_world_normal);
 vec3 gradient=fine.yzw*fine_weight+broad.yzw*0.12;
 gradient-=n*dot(n,gradient);
 NORMAL=normalize(NORMAL-mat3(VIEW_MATRIX)*gradient*bump_strength);
}
