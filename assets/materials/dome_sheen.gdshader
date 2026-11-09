shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
// One transparent surface, not a screen-space reflection/refraction pass.
void fragment() {
 float grazing = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
 ALBEDO = mix(vec3(0.11, 0.19, 0.25), vec3(0.57, 0.75, 0.78), daylight);
 // Thin optical film, deliberately never an opaque or glowing bubble.
 ALPHA = mix(0.004, 0.008, daylight) + grazing * mix(0.025, 0.060, daylight);
}
