shader_type spatial;
// PR B (P2 "inn hillside is a uniform grass carpet"): unpinned copy of shaders/rook_ground_finish_v096.gdshader,
// installed on SettlementTerrain/GroundRelief only by raid/scripts/inn_hillside_finish.gd. Everything outside the
// inn hillside block below is byte-for-byte the original. The block has compact support (x -27..29, z 22..53)
// and adds three world-space patch fields: sun-dried tufts, darker clover/damp swales and a mid-scale mottle,
// plus a little more tone on the steeper rise toward the inn. inn_hill_variation 0 restores the original look.
render_mode diffuse_burley;
uniform bool stream_enabled = false;
uniform float inn_hill_variation : hint_range(0.0, 1.0) = 1.0;
varying vec3 world_position;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise2(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
// Sine-free hash (small operands) so raid/scripts/inn_hillside_finish.gd reproduces the same patch field
// on the CPU for the grass blade tint.
float hill_hash(vec2 p) { vec3 p3=fract(vec3(p.xyx)*.1031); p3+=dot(p3,p3.yzx+33.33); return fract((p3.x+p3.y)*p3.z); }
float hill_noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hill_hash(i),hill_hash(i+vec2(1,0)),f.x),mix(hill_hash(i+vec2(0,1)),hill_hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world_position.xz;
 float broad=noise2(p*.19)*.62+noise2(p*.71)*.38;
 float fine=noise2(p*10.0);
 // Filter fine detail at distance instead of sparkling high-frequency noise.
 float filter_amount=1.0-smoothstep(.06,.25,length(fwidth(p)));
 vec3 turf=mix(vec3(.105,.158,.068),vec3(.205,.259,.114),broad);
 turf*=1.0+(fine-.5)*.28*filter_amount;
 if (stream_enabled && abs(p.x)<42.5) {
  float course=-46.5+2.0*sin(p.x*.105)+.45*sin(p.x*.24);
  float water=.34-.0012*p.x;
  float near_channel=1.0-smoothstep(2.2,3.8,abs(p.y-course));
  float wet=near_channel*(1.0-smoothstep(.11,.52,world_position.y-water));
  float gravel=noise2(p*17.0);
  vec3 soil=mix(vec3(.105,.090,.063),vec3(.25,.22,.15),smoothstep(.14,.45,world_position.y-water));
  soil+=vec3(.06,.055,.045)*smoothstep(.60,.77,gravel)*filter_amount;
  turf=mix(turf,soil,wet);
 }
 // Local Rook lawn/soil transition, independent of blade density and quality.
 // Compact support: zero outside x=20..44, z=29..53; no water/path displacement.
 float local_mask=smoothstep(20.0,24.0,p.x)*(1.0-smoothstep(40.0,44.0,p.x))*smoothstep(29.0,33.0,p.y)*(1.0-smoothstep(49.0,53.0,p.y));
 float soil_patch=smoothstep(.38,.68,noise2(p*.26+vec2(7.4,2.1)));
 vec3 lawn=mix(vec3(.145,.197,.100),vec3(.215,.258,.145),broad);
 vec3 loam=mix(vec3(.175,.153,.111),vec3(.230,.211,.151),broad);
 vec3 finish=mix(lawn,loam,soil_patch*.32);
 finish*=1.0+(fine-.5)*.14*filter_amount;
 turf=mix(turf,finish,local_mask*.78);
 // P2B inn hillside patches (see header). hill_noise is mirrored in GDScript for the blade tint.
 float hill_mask=smoothstep(-27.0,-22.0,p.x)*(1.0-smoothstep(24.0,29.0,p.x))*smoothstep(22.0,27.0,p.y)*(1.0-smoothstep(49.0,53.0,p.y))*inn_hill_variation;
 if (hill_mask>0.0) {
  float dry=smoothstep(.80,.88,hill_noise(p*.115+vec2(3.1,9.7)));
  float clover=smoothstep(.64,.76,hill_noise(p*.205+vec2(11.3,4.2)))*(1.0-dry);
  float mottle=hill_noise(p*.62+vec2(1.7,5.3));
  float rise=smoothstep(.4,2.6,world_position.y);
  vec3 hill=turf*mix(.86,1.16,mottle);
  hill=mix(hill,vec3(.232,.226,.118)*(.9+.2*broad),dry*.58);
  hill=mix(hill,vec3(.074,.132,.066),clover*.50);
  hill*=mix(1.0,1.06,rise*(1.0-clover));
  turf=mix(turf,hill,hill_mask);
 }
 ALBEDO=turf; ROUGHNESS=.98; SPECULAR=.08;
}
