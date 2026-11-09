shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
void vertex() {
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y += sin(VERTEX.x*2.7-TIME*.65)*sin(VERTEX.z*3.2+TIME*.31)*.006;
}
void fragment() {
 float ripple=sin(world_position.x*3.8-TIME*.8+sin(world_position.z*2.3))*.5+.5;
 float crossing=sin(world_position.z*5.0+world_position.x*.38-TIME*.32)*.5+.5;
 float glint=pow(ripple*crossing,9.0)*.045;
 ALBEDO=mix(vec3(.075,.22,.235),vec3(.13,.34,.34),ripple*.30)+vec3(glint);
 ROUGHNESS=.31;
 METALLIC=.12;
 SPECULAR=.36;
}
