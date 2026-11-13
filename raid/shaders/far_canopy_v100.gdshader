shader_type spatial;
render_mode cull_disabled, specular_disabled;
// Low-detail far tree clusters (TASKS item 9 style test). Opaque, untextured.
uniform float render_distance = 520.0;
uniform float fade_width = 60.0;
varying float scenic_distance;
varying float local_h;
void vertex(){
 vec3 root=MODEL_MATRIX[3].xyz;
 scenic_distance=length(root.xz);
 local_h=VERTEX.y;
 float d=distance(root,CAMERA_POSITION_WORLD);
 VERTEX*=1.0-smoothstep(render_distance-fade_width,render_distance,d);
}
void fragment(){
 vec3 c=COLOR.rgb;
 // Lighter crowns, darker skirts: reads as volume at a distance.
 c*=mix(.78,1.12,clamp(local_h,0.0,1.0));
 float haze=smoothstep(110.0,520.0,scenic_distance)*.55;
 ALBEDO=mix(c,vec3(.42,.52,.58),haze);
 ROUGHNESS=1.0;
}
