shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// STAGED ROUTE-ONLY CANDIDATE. Not wired to Settlement.
// Low retains the original two analytic-gradient samples. Higher tiers add bounded,
// footprint-filtered mineral detail only on stone slab faces; no textures/displacement.
// World scale in meters. Intended for selected limestone/bronze surfaces only.
uniform vec4 tint : source_color = vec4(0.48, 0.44, 0.36, 1.0);
uniform float metallic : hint_range(0.0,1.0) = 0.0;
uniform float roughness : hint_range(0.0,1.0) = 0.78;
uniform float variation : hint_range(0.0,1.0) = 0.26;
uniform float grain_scale : hint_range(1.0,80.0) = 20.0;
uniform float bump_strength : hint_range(0.0,0.5) = 0.055;
uniform int detail_quality : hint_range(0,3) = 2;
uniform float patina : hint_range(0.0,1.0) = 0.0;
uniform float route_min_y = -10000.0;
uniform float route_max_y = 10000.0;
uniform float slab_meters = 1.0;
uniform float joint_width_meters = 0.025;
uniform vec4 joint_tint : source_color = vec4(0.24,0.23,0.20,1.0);
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
 // One-metre square limestone courses, aligned to existing integer-centred plaza tiles.
 // WORLD position preserves course scale/phase across rotated connector meshes.
 vec2 q=(material_world_position.xz+vec2(slab_meters*.5))/slab_meters;
 vec2 edge=min(fract(q),1.0-fract(q))*slab_meters;
 float distance_to_joint=min(edge.x,edge.y);
 float aa=max(fwidth(distance_to_joint),0.001);
 float joint=1.0-smoothstep(joint_width_meters*.5-aa,joint_width_meters*.5+aa,distance_to_joint);
 float top=smoothstep(.70,.95,abs(material_world_normal.y))*step(route_min_y,material_world_position.y)*step(material_world_position.y,route_max_y);
 float slab_variation=(hash31(vec3(floor(q),17.0))-.5)*.06;
 // Preserve the exact joint grid and world phase. Detail fades out at joints,
 // grazing/distant footprints and on non-stone or vertically gated batch faces.
 float detail_mask=top*(1.0-joint)*(1.0-smoothstep(0.05,0.30,metallic));
 float mineral=0.0;
 float micro_roughness=0.0;
 vec3 mineral_gradient=vec3(0.0);
 if (detail_quality>0) {
  vec3 mineral_position=material_world_position*vec3(3.6,2.0,5.1)+vec3(9.2,1.7,3.8);
  vec4 mineral_sample=grain(mineral_position);
  float stone_footprint=max(length(dFdx(mineral_position)),length(dFdy(mineral_position)));
  float stone_filter=1.0-smoothstep(0.22,0.85,stone_footprint);
  float strength=detail_quality==1 ? 0.025 : (detail_quality==2 ? 0.045 : 0.065);
  mineral=(mineral_sample.x-0.5)*strength*stone_filter;
  mineral_gradient=mineral_sample.yzw*strength*stone_filter;
  if (detail_quality>=2) {
   // Warped, quiet mineral ribbons rather than a new colored marble pattern.
   float phase=dot(material_world_position,vec3(6.3,1.5,3.7))+broad.x*5.0+mineral_sample.x*2.3;
   float phase_footprint=max(abs(dFdx(phase)),abs(dFdy(phase)));
   float vein_filter=1.0-smoothstep(0.18,0.80,phase_footprint);
   float vein=pow(0.5+0.5*sin(phase),8.0);
   mineral-=(vein-0.1964)*(detail_quality==3 ? 0.075 : 0.040)*vein_filter;
  }
  if (detail_quality==3) {
   vec3 micro_position=material_world_position*48.0;
   float micro_footprint=max(length(dFdx(micro_position)),length(dFdy(micro_position)));
   float micro_filter=1.0-smoothstep(0.12,0.55,micro_footprint);
   // Uniform quality branch plus footprint branch: no extra noise work at distance.
   if (micro_filter>0.0) {
    vec4 micro=grain(micro_position+vec3(3.7,12.1,6.5));
    mineral+=(micro.x-0.5)*0.035*micro_filter;
    micro_roughness=(micro.x-0.5)*0.045*micro_filter;
    mineral_gradient+=micro.yzw*0.025*micro_filter;
   }
  }
 }
 base*=1.0+mineral*detail_mask;
 ALBEDO=mix(base*(1.0+slab_variation*top),joint_tint.rgb,joint*top*.7);
 METALLIC=metallic*(1.0-oxidation*0.55);
 ROUGHNESS=clamp(roughness+(fine.x-0.5)*0.17+oxidation*0.12+micro_roughness*detail_mask,0.22,0.96);
 vec3 n=normalize(material_world_normal);
 vec3 gradient=fine.yzw*fine_weight+broad.yzw*0.12;
 gradient+=mineral_gradient*detail_mask;
 gradient-=n*dot(n,gradient);
 NORMAL=normalize(NORMAL-mat3(VIEW_MATRIX)*gradient*bump_strength);
}
