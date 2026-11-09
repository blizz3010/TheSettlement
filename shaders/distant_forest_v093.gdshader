shader_type spatial;
render_mode cull_disabled, specular_disabled;
// Opaque distant foliage. No texture, alpha blending, dynamic lights or per-frame script.
uniform float render_distance = 480.0;
uniform float fade_width = 55.0;
varying float scenic_distance;
void vertex() {
    vec3 root = MODEL_MATRIX[3].xyz;
    scenic_distance = length(root.xz);
    float distance_to_camera = distance(root, CAMERA_POSITION_WORLD);
    float keep = 1.0-smoothstep(render_distance-fade_width,render_distance,distance_to_camera);
    VERTEX *= keep;
}
void fragment() {
    // Restrained cool aerial perspective stays lit by the existing day/night world.
    float haze = smoothstep(140.0,520.0,scenic_distance)*0.30;
    ALBEDO = mix(COLOR.rgb,vec3(0.24,0.33,0.35),haze);
    ROUGHNESS = 1.0;
}
