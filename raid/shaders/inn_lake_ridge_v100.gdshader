shader_type spatial;
render_mode cull_disabled;
// Copy of distant_terrain_v094 for the reshaped MiddleRidge (TASKS item 10).
// No lake-ellipse discard: the ridge mesh is now lowered under the water instead.
uniform int terrain_band = 0;
uniform vec4 original_tint : source_color = vec4(1.0);
varying vec3 wp;
varying vec3 wn;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;wn=normalize(mat3(MODEL_MATRIX)*NORMAL);}
void fragment(){
 float radius=length(wp.xz);
 float north=dot(normalize(wp.xz),vec2(0.0,-1.0));
 float weight=smoothstep(0.6156614753,0.7660444431,north)*smoothstep(70.0,84.0,radius);
 ALBEDO=COLOR.rgb*original_tint.rgb;ROUGHNESS=1.0;SPECULAR=.5;
 if(weight>0.0){
 float broad=noise(wp.xz*.026)*.65+noise(wp.xz*.071)*.35;
 float grain=noise(wp.xz*.42);
 float ridges=noise(wp.xz*.041+vec2(wp.y*.075,-wp.y*.05));
 float slope=1.0-abs(wn.y);
 vec3 forest=mix(vec3(.055,.09,.063),vec3(.12,.17,.105),broad);
 forest*=.88+grain*.20;
 vec3 rock=mix(vec3(.18,.205,.19),vec3(.31,.34,.29),broad*.82+ridges*.18);
 float exposed=smoothstep(.15,.48,slope)*.82+smoothstep(.69,.88,broad)*.6;
 vec3 ground=mix(forest,rock,clamp(exposed,0.0,1.0));
 if(terrain_band==2){
  ground=mix(vec3(.21,.29,.34),vec3(.39,.445,.46),broad*.82+ridges*.18);
  float snow=smoothstep(99.0,141.0,wp.y+noise(wp.xz*.047)*20.0-ridges*12.0)*(1.0-smoothstep(.45,.83,slope));
  ground=mix(ground,vec3(.66,.72,.74),snow*.8);
 }
 float aerial=smoothstep(130.0,780.0,radius)*.64;
 ground=mix(ground,vec3(.34,.43,.49),aerial);
 ALBEDO=mix(COLOR.rgb*original_tint.rgb,ground,weight);
 SPECULAR=.5*(1.0-weight);
 }
}
