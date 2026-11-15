shader_type spatial;
render_mode cull_disabled, specular_disabled;
// Low-detail layered ridge silhouettes for item 9 option B.
// COLOR.a is the crest fraction (0 at the foot, 1 at the skyline) so the
// band edges can haze into the aerial backdrop instead of reading as walls.
varying float scenic_distance;
varying float crest;
void vertex(){
	scenic_distance = length((MODEL_MATRIX * vec4(VERTEX, 1.0)).xz);
	crest = COLOR.a;
}
void fragment(){
	vec3 c = COLOR.rgb;
	c *= mix(0.88, 1.10, crest);
	vec3 air = vec3(0.50, 0.60, 0.66);
	float dist_haze = smoothstep(160.0, 820.0, scenic_distance);
	float foot_blend = smoothstep(0.35, 0.0, crest) * 0.82;
	float haze = clamp(dist_haze * mix(0.88, 0.50, crest) + foot_blend, 0.0, 0.94);
	ALBEDO = mix(c, air, haze);
	ROUGHNESS = 1.0;
}
