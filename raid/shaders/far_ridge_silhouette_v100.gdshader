shader_type spatial;
render_mode cull_disabled, specular_disabled;
// Low-detail layered ridge silhouettes for item 9 option B/C.
varying float scenic_distance;
varying float local_h;
void vertex(){
 scenic_distance=length((MODEL_MATRIX*vec4(VERTEX,1.0)).xz);
 local_h=VERTEX.y;
}
void fragment(){
 vec3 c=COLOR.rgb;
 c*=mix(.82,1.08,clamp(local_h/80.0,0.0,1.0));
 float haze=smoothstep(180.0,780.0,scenic_distance)*.72;
 ALBEDO=mix(c,vec3(.46,.56,.62),haze);
 ROUGHNESS=1.0;
}
