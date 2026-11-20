shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// PR B (P2 "lime lollipop plaza trees"): Quaternius Leaves_NormalTree_C.png averages RGB (88,123,0), a pure
// lime with no blue, so an albedo multiply cannot reach a natural green. This remaps the texel's luminance
// onto a mid foliage green (keeping part of the original hue and the full leaf mask), close to Artie's
// plaza_tree leaf (85,111,78) and the darker gardens around it. Only the plaza CommonTree crowns use it.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float alpha_scissor = 0.5;
uniform vec3 tone : source_color = vec3(0.30, 0.43, 0.21);
uniform float keep_hue = 0.35;
uniform float darken = 0.86;
void fragment() {
 vec4 t = texture(albedo_tex, UV) * albedo_tint;
 float l = dot(t.rgb, vec3(0.30, 0.59, 0.11));
 vec3 g = tone * (l / 0.39);
 ALBEDO = mix(g, t.rgb, keep_hue) * darken;
 ROUGHNESS = 0.85; SPECULAR = 0.25;
 ALPHA = t.a;
 ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
}
