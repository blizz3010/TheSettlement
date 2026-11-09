shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool vertex_mode=false;
void fragment(){
 vec4 c=vertex_mode ? COLOR : texture(albedo_texture,UV);
 float leaf=smoothstep(.015,.12,c.g-max(c.r,c.b));
 float l=dot(c.rgb,vec3(.2126,.7152,.0722));
 ALBEDO=mix(c.rgb,mix(vec3(.35,.065,.13),vec3(.91,.48,.59),clamp(l*2.0,0.0,1.0)),leaf);
 ALPHA=c.a;ALPHA_SCISSOR_THRESHOLD=.2;ROUGHNESS=.95;SPECULAR=.04;
}
