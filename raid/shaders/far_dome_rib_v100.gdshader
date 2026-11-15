shader_type spatial;
render_mode cull_disabled, specular_disabled;
// Option C dome ribs: thicker than the pinned 5.5 cm boxes so they read as
// structure instead of flickering hairlines. Opaque, with a slight darkening
// at distance so they sit in the sky rather than popping.
uniform vec4 rib_color : source_color = vec4(0.58, 0.77, 0.75, 1.0);
uniform float fade_start = 40.0;
uniform float fade_end = 95.0;
varying float view_d;
void vertex(){
 view_d=distance((MODEL_MATRIX*vec4(VERTEX,1.0)).xyz,CAMERA_POSITION_WORLD);
}
void fragment(){
 float fade=1.0-smoothstep(fade_start,fade_end,view_d);
 ALBEDO=rib_color.rgb*mix(0.72,1.0,fade);
 ROUGHNESS=0.62;
}
