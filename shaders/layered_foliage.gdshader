shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool leaf_only=false;
void fragment(){
 vec4 sample_color=texture(albedo_texture,UV);
 float luminance=dot(sample_color.rgb,vec3(.2126,.7152,.0722));
 vec3 color=mix(sample_color.rgb,vec3(luminance),.25);
 if(leaf_only){color=mix(vec3(.12,.20,.05),vec3(.35,.48,.13),smoothstep(.025,.65,luminance));}
 ALBEDO=color*.7;
 ALPHA=sample_color.a;ALPHA_SCISSOR_THRESHOLD=.2;
 ROUGHNESS=.95;SPECULAR=.04;
}
