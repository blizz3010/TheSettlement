shader_type spatial;
// MultiMesh enables instancing. "render_by_instance" is not a Godot 4 mode.
render_mode diffuse_toon, specular_disabled, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.12, 0.28, 0.055, 1.0);
uniform vec4 tip_color : source_color = vec4(0.52, 0.69, 0.18, 1.0);
uniform vec2 wind_direction = vec2(1.0, 0.35); // World XZ direction.
uniform float wind_strength : hint_range(0.0, 2.0, 0.01) = 0.25; // World units.
uniform float wind_speed : hint_range(0.0, 10.0, 0.01) = 1.8;
uniform float wind_frequency : hint_range(0.01, 5.0, 0.01) = 0.55;
uniform float blade_height : hint_range(0.01, 5.0, 0.01) = 1.0; // Unscaled mesh height.
uniform float color_variation : hint_range(0.0, 0.5, 0.01) = 0.12;

varying float height_mask;
varying float instance_tint;

void vertex() {
    // Required UV layout: root UV.y = 1, tip UV.y = 0.
    float h = clamp(1.0 - UV.y, 0.0, 1.0);
    height_mask = h;
    instance_tint = 1.0 + (INSTANCE_CUSTOM.r * 2.0 - 1.0) * color_variation;

    // MODEL_MATRIX includes this MultiMesh instance's transform.
    vec3 root_world = MODEL_MATRIX[3].xyz;
    vec2 direction = wind_direction / max(length(wind_direction), 0.0001);
    float phase = dot(root_world.xz, direction) * wind_frequency - TIME * wind_speed;
    float gust = 0.55 + 0.30 * sin(phase)
        + 0.15 * sin(phase * 0.53 + dot(root_world.xz, vec2(-direction.y, direction.x)) * 0.27);

    // Project the common world wind onto this blade's terrain tangent plane.
    vec3 up_world = normalize(MODEL_MATRIX[1].xyz);
    vec3 wind_world = vec3(direction.x, 0.0, direction.y);
    wind_world -= up_world * dot(wind_world, up_world);
    wind_world *= wind_strength * gust * mix(0.8, 1.0, INSTANCE_CUSTOM.g);
    vec3 bend_local = inverse(mat3(MODEL_MATRIX)) * wind_world;
    VERTEX += bend_local * h * h; // Exactly zero displacement at the root.

    // Analytic normal correction for the quadratic bend. Requires UV.y to vary
    // linearly from 1 to 0 over local Y = 0 to blade_height.
    vec3 slope = bend_local * (2.0 * h / max(blade_height, 0.0001));
    NORMAL = normalize(vec3(NORMAL.x, NORMAL.y - dot(slope, NORMAL), NORMAL.z));
}

void fragment() {
    ALBEDO = mix(base_color.rgb, tip_color.rgb, height_mask) * instance_tint;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
    // cull_disabled already flips back-face normals in Godot 4.
    // Do not flip NORMAL again using FRONT_FACING.
}
