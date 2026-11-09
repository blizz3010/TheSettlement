shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint: source_color=vec4(1.0);
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){if(length((world_pos.xz-vec2(20.0,130.0))/vec2(100.0,75.0))<1.0){discard;}ALBEDO=COLOR.rgb*tint.rgb;ROUGHNESS=1.0;}
