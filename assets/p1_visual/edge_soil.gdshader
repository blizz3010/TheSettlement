shader_type spatial;
// Queue item 4 (b): soil / gravel lip where grass meets paving, and the wet bank at the lake.
// Colour comes from world-space noise so overlapping lip patches shade identically (no seams).
render_mode cull_back, depth_draw_opaque;
uniform vec3 soil_a : source_color = vec3(0.36, 0.29, 0.21);
uniform vec3 soil_b : source_color = vec3(0.47, 0.40, 0.31);
uniform vec3 grit : source_color = vec3(0.62, 0.60, 0.55);
uniform float grit_amount = 0.35;
uniform float wet = 0.0;
uniform float edge_fade = 0.6;
varying vec3 wpos;
varying float vfade;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vfade = COLOR.a;
}
void fragment() {
	vec2 p = wpos.xz;
	float n = vnoise(p * 3.1) * 0.6 + vnoise(p * 9.7) * 0.3 + vnoise(p * 23.0) * 0.1;
	vec3 c = mix(soil_a, soil_b, n);
	float g = step(1.0 - grit_amount * 0.5, vnoise(p * 41.0)) * (0.6 + 0.4 * vnoise(p * 90.0));
	c = mix(c, grit * (0.8 + 0.4 * vnoise(p * 70.0)), g);
	c *= mix(1.0, 0.55, wet);
	// soften toward the lawn: the outer rim (COLOR.a -> 0) darkens slightly like soil under blades
	c *= mix(0.78, 1.0, smoothstep(0.0, edge_fade, vfade));
	ALBEDO = c;
	ROUGHNESS = mix(0.93, 0.35, wet) - g * 0.1;
	SPECULAR = mix(0.35, 0.6, wet);
	float h1 = vnoise(p * 9.7 + vec2(0.05, 0.0)) - vnoise(p * 9.7 - vec2(0.05, 0.0));
	float h2 = vnoise(p * 9.7 + vec2(0.0, 0.05)) - vnoise(p * 9.7 - vec2(0.0, 0.05));
	NORMAL_MAP = vec3(0.5 - h1 * 0.6, 0.5 - h2 * 0.6, 1.0);
	NORMAL_MAP_DEPTH = 0.6;
}
