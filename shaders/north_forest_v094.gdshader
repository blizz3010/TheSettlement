shader_type spatial;
render_mode cull_disabled, specular_disabled;
// Opaque distant foliage. No texture, alpha blending, dynamic lights or per-frame script.
uniform float render_distance = 480.0;
uniform float fade_width = 55.0;
varying float scenic_distance;
varying vec3 tree_local;
void vertex() {
    tree_local=VERTEX;
    vec3 root = MODEL_MATRIX[3].xyz;
    scenic_distance = length(root.xz);
    float distance_to_camera = distance(root, CAMERA_POSITION_WORLD);
    float keep = 1.0-smoothstep(render_distance-fade_width,render_distance,distance_to_camera);
    float north=dot(normalize(root.xz),vec2(0.0,-1.0));
    keep*=smoothstep(0.6156614753,0.7660444431,north);
    VERTEX *= keep;
}
void fragment() {
    // Restrained cool aerial perspective stays lit by the existing day/night world.
    float haze = smoothstep(140.0,520.0,scenic_distance)*0.30;
    float fine=sin(tree_local.x*83.0+sin(tree_local.z*51.0))*sin(tree_local.y*71.0);
    float filter_amount=1.0-smoothstep(.012,.045,length(fwidth(tree_local)));
    float leafy=step(COLOR.r*1.08,COLOR.g);
    float shade=mix(1.0,mix(.65,1.0,smoothstep(.25,1.0,tree_local.y)),leafy);
    vec3 foliage=COLOR.rgb*shade*(1.0+fine*.07*filter_amount*leafy);
    ALBEDO = mix(foliage,vec3(0.29,0.39,0.43),haze);
    ROUGHNESS = 1.0;
}
