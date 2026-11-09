shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D albedo_texture:source_color,filter_linear_mipmap;
uniform bool vertex_mode=true;
uniform int palette_mode=0;
uniform vec4 accent:source_color=vec4(0.64,0.51,0.68,1.0);
uniform vec2 cluster_center=vec2(0.0);
uniform float cluster_radius=2.2;
uniform float leaf_value=1.0;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec4 source=vertex_mode ? COLOR : texture(albedo_texture,UV);
 vec3 c=source.rgb;
 float leaf=smoothstep(0.015,0.06,c.g-max(c.r,c.b));
 float flower=(1.0-leaf)*max(smoothstep(0.40,0.56,c.b),smoothstep(0.65,0.82,c.r));
 float cluster=1.0-smoothstep(cluster_radius,cluster_radius+1.3,distance(world_position.xz,cluster_center));
 float value=dot(c,vec3(0.2126,0.7152,0.0722));
 vec3 quiet=vec3(0.50,0.54,0.42)*clamp(value*1.15,0.65,1.0);
 vec3 petals=mix(quiet,accent.rgb*clamp(value*1.25,0.62,1.0),cluster);
 vec3 foliage=mix(c,c*vec3(0.93,0.96,1.03),0.65)*leaf_value;
 ALBEDO=mix(foliage,petals,flower*0.82);
 if(palette_mode==2){
  vec3 blossom=mix(vec3(0.36,0.12,0.17),vec3(0.82,0.49,0.58),clamp(value*2.0,0.0,1.0));
  ALBEDO=mix(c,blossom,smoothstep(0.015,0.12,c.g-max(c.r,c.b)));
 }
 ALPHA=source.a;ALPHA_SCISSOR_THRESHOLD=0.2;
 ROUGHNESS=0.95;SPECULAR=0.08;
}
