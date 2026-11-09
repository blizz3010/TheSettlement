shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// One outward rear-wall face only. Shared cream and global exposure are untouched.
uniform vec4 exterior_tint : source_color = vec4(.694,.643,.541,1.0);
uniform vec4 original_tint : source_color = vec4(.776,.733,.631,1.0);
varying vec3 local_position;
varying vec3 local_normal;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2(vec2 p) {
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1.0,0.0)),f.x),mix(hash21(i+vec2(0.0,1.0)),hash21(i+vec2(1.0,1.0)),f.x),f.y);
}
void vertex() { local_position=VERTEX;local_normal=NORMAL; }
void fragment() {
 bool exterior=local_normal.z>.5;
 vec2 p=local_position.xy;
 vec2 fine=p*45.0;
 float filtered=1.0-smoothstep(.18,.75,length(fwidth(fine)));
 float broad=.965+noise2(p*2.2)*.055;
 float trowel=1.0+(noise2(fine)-.5)*.035*filtered;
 ALBEDO=exterior ? exterior_tint.rgb*broad*trowel : original_tint.rgb;
 ROUGHNESS=exterior ? .96 : .88;
 SPECULAR=exterior ? .12 : .5;
 METALLIC=0.0;
}
