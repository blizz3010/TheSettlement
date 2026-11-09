shader_type spatial;
render_mode diffuse_burley;
uniform bool stream_enabled = false;
varying vec3 world_position;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise2(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
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
 ALBEDO=turf; ROUGHNESS=.98; SPECULAR=.08;
}
